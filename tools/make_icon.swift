#!/usr/bin/env swift
// Draws the Mini Battery Menu app icon into an .iconset directory.
// Usage: swift tools/make_icon.swift <output.iconset>

import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "MiniBatteryMenu.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size

    let inset = s * 0.098
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = rect.width * 0.2237

    ctx.saveGState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1),
    ])!.draw(in: rect, angle: -90)
    ctx.restoreGState()

    // Bolt, centred, drawn from a normalised path.
    let points: [(CGFloat, CGFloat)] = [
        (0.56, 1.00), (0.16, 0.52), (0.42, 0.52), (0.36, 0.00),
        (0.80, 0.50), (0.53, 0.50),
    ]
    let boltHeight = rect.height * 0.52
    let boltWidth = boltHeight * 0.64
    let originX = rect.midX - boltWidth / 2
    let originY = rect.midY - boltHeight / 2

    let bolt = NSBezierPath()
    for (index, point) in points.enumerated() {
        let p = CGPoint(x: originX + point.0 * boltWidth, y: originY + point.1 * boltHeight)
        index == 0 ? bolt.move(to: p) : bolt.line(to: p)
    }
    bolt.close()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 0.85, blue: 0.40, alpha: 1),
        NSColor(calibratedRed: 0.99, green: 0.60, blue: 0.20, alpha: 1),
    ])!
    ctx.saveGState()
    bolt.addClip()
    gradient.draw(in: bolt.bounds, angle: -90)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (size, name) in [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
                     (128, "128x128"), (256, "128x128@2x"), (256, "256x256"),
                     (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")] {
    let rep = drawIcon(size: CGFloat(size))
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
print("wrote \(out)")
