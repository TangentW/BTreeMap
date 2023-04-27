// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BTreeMap",
    products: [
        .library(
            name: "BTreeMap",
            targets: ["BTreeMap"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BTreeMap",
            dependencies: []),
        .testTarget(
            name: "BTreeMapTests",
            dependencies: ["BTreeMap"]),
    ]
)
