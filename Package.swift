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
//        .package(url: "https://github.com/mergesort/Bodega", Version(1, 0, 0))
        .package(url: "https://github.com/mergesort/Bodega", branch: "main")
    ],
    targets: [
        .target(
            name: "Boutique",
            dependencies: [.byName(name: "Bodega")]
        ),
        .testTarget(
            name: "BoutiqueTests",
            dependencies: ["Boutique"]
        ),
    ]
)

