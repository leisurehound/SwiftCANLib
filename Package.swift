// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCANLib",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftCANLib",
            targets: ["SwiftCANLib"]),
    ],
    dependencies: [
//      .package(path: "./CSocketCAN"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "canhelpers",
            dependencies: [],
            exclude: ["SwiftCANLib"],
            cSettings: [.headerSearchPath("Internal"),]
        ),
        .target(
            name: "SwiftCANLib",
            dependencies: ["canhelpers",
 //                          "CSocketCAN",
            ],
            exclude: ["canhelpers"]
          ),
        .testTarget(
            name: "SwiftCANLibTests",
            dependencies: ["SwiftCANLib"]),
    ]
)
