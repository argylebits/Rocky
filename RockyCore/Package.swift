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
    dependencies: [
        .package(url: "https://github.com/vapor/sqlite-nio.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RockyCore",
            dependencies: [
                .product(name: "SQLiteNIO", package: "sqlite-nio"),
            ]
        ),
        .testTarget(
            name: "RockyCoreTests",
            dependencies: ["RockyCore"]
        ),
    ]
)