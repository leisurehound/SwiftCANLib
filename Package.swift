// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

//  Copyright 2021 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import PackageDescription

#if os(macOS) || os(tvOS) || os(iOS)  // can seem to add this #if in the targets array which is where the only different is.
let package = Package(
    name: "SwiftCANLib",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(name: "SwiftCANLibExample", targets: ["SwiftCANLibExample"]),
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
        .target(name: "mockcanhelpers",
            dependencies: [],
            exclude: ["SwiftCANLib", "canhelpers"],
            cSettings: [.headerSearchPath("Internal"),]),
        .target(
            name: "SwiftCANLib",
            dependencies: ["mockcanhelpers",],
            exclude: ["canhelpers","Example","mockcanhelpers"]
          ),
        .target(
          name: "SwiftCANLibExample",
          dependencies: ["SwiftCANLib"],
          path: "./Sources/SwiftCANLib/Example"
        ),
        .testTarget(
            name: "SwiftCANLibTests",
            dependencies: ["SwiftCANLib"]),
    ]
)
#else // linux
let package = Package(
    name: "SwiftCANLib",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(name: "SwiftCANLibExample", targets: ["SwiftCANLibExample"]),
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
            exclude: ["SwiftCANLib", "mockcanhelpers"],
            cSettings: [.headerSearchPath("Internal"),]
        ),
        .target(
            name: "SwiftCANLib",
            dependencies: ["canhelpers",],
            exclude: ["canhelpers","Example","mockcanhelpers"]
          ),
        .target(
          name: "SwiftCANLibExample",
          dependencies: ["SwiftCANLib"],
          path: "./Sources/SwiftCANLib/Example"
        ),
        .testTarget(
            name: "SwiftCANLibTests",
            dependencies: ["SwiftCANLib"]),
    ]
)
#endif
