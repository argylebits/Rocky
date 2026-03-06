// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RockyCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "RockyCore", targets: ["RockyCore"]),
    ],
    targets: [
        .target(
            name: "RockyCore"
        ),
        .testTarget(
            name: "RockyCoreTests",
            dependencies: ["RockyCore"]
        ),
    ]
)