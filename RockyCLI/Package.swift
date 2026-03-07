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
            ],
            plugins: [
                .plugin(name: "VersionPlugin"),
            ]
        ),
        .testTarget(
            name: "RockyCLITests",
            dependencies: ["RockyCLI"]
        ),
        .executableTarget(
            name: "VersionGen"
        ),
        .plugin(
            name: "VersionPlugin",
            capability: .buildTool(),
            dependencies: ["VersionGen"]
        ),
    ]
)
