// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Boutique",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "Boutique",
            targets: ["Boutique"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mergesort/Bodega.git", exact: Version(2, 1, 3)),
        .package(url: "https://github.com/apple/swift-collections", from: Version(1, 0, 3)),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: Version(1, 0, 0)),
        .package(url: "https://github.com/pointfreeco/swift-perception", from: Version(1, 2, 2)),
    ],
    targets: [
        .target(
            name: "Boutique",
            dependencies: [
                .byName(name: "Bodega"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "Perception", package: "swift-perception")
            ],
            exclude: [
                "../../Images",
                "../../Performance Profiler",
            ],
            swiftSettings: [
                .define("ENABLE_TESTABILITY", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "BoutiqueTests",
            dependencies: ["Boutique"]
        ),
    ]
)
