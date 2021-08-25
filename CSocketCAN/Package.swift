// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CSocketCAN",
    products: [
        .library(
            name: "CSocketCAN",
            targets: ["CSocketCAN"]),
    ],
    targets: [
	.systemLibrary(name: "CSocketCAN"),
    ]
)
