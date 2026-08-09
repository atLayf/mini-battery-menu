// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MiniBatteryMenu",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MiniBatteryMenu",
            path: "Sources/MiniBatteryMenu",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
