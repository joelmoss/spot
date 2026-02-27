// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Spot",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Spot", path: "Sources/Spot")
    ]
)
