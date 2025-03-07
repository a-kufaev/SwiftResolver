// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftResolver",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftResolver",
            targets: ["SwiftResolver"]
        )
    ],
    targets: [
        .target(
            name: "SwiftResolver",
            path: "Sources"
        ),
        .testTarget(
            name: "SwiftResolverTests",
            dependencies: ["SwiftResolver"],
            path: "Tests"
        )
    ]
)
