// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Spot",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Spot",
            dependencies: ["Sparkle"],
            path: "Sources/Spot"
        ),
        .testTarget(name: "SpotTests", dependencies: ["Spot"], path: "Tests/SpotTests"),
    ]
)
