// swift-tools-version: 5.9
// Package.swift for PocketPadShared

import PackageDescription

let package = Package(
    name: "PocketPadShared",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "PocketPadShared",
            targets: ["PocketPadShared"]
        ),
    ],
    targets: [
        .target(
            name: "PocketPadShared",
            path: "Sources"
        ),
    ]
)
