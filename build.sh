#!/bin/bash
# Builds "Mini Battery Menu.app" and installs it. Usage: ./build.sh [--no-install]
set -euo pipefail
cd "$(dirname "$0")"

# Executable and SwiftPM target name; the bundle gets the spaced display name.
BIN_NAME="MiniBatteryMenu"
DISPLAY_NAME="Mini Battery Menu"
BUNDLE_ID="ai.layf.minibatterymenu"
VERSION="1.0"
BUILD_DIR="build"
APP="$BUILD_DIR/$DISPLAY_NAME.app"

if [ -w "/Applications" ]; then INSTALL_DIR="/Applications"; else INSTALL_DIR="$HOME/Applications"; fi

echo "==> Compiling"
swift build -c release

echo "==> Assembling $DISPLAY_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN_NAME" "$APP/Contents/MacOS/$BIN_NAME"

echo "==> Icon"
rm -rf "$BUILD_DIR/$BIN_NAME.iconset"
if swift tools/make_icon.swift "$BUILD_DIR/$BIN_NAME.iconset" >/dev/null 2>&1; then
  iconutil -c icns "$BUILD_DIR/$BIN_NAME.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
else
  echo "    (icon generation skipped)"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$BIN_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 James Layfield. MIT licensed.</string>
</dict>
</plist>
PLIST

echo "==> Signing (ad hoc)"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

if [ "${1:-}" != "--no-install" ]; then
  echo "==> Installing to $INSTALL_DIR"
  pkill -x "$BIN_NAME" 2>/dev/null || true
  sleep 0.4
  rm -rf "$INSTALL_DIR/$DISPLAY_NAME.app"
  cp -R "$APP" "$INSTALL_DIR/$DISPLAY_NAME.app"
  echo "==> Launching"
  open "$INSTALL_DIR/$DISPLAY_NAME.app"
fi

echo "Done."
