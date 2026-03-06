// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RockyCLI",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../RockyCore"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "RockyCLI",
            dependencies: [
                "RockyCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "RockyCLITests",
            dependencies: ["RockyCLI"]
        ),
    ]
)