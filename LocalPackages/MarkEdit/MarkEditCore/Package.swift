// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MarkEditCore",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "MarkEditCore",
      targets: ["MarkEditCore"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "MarkEditCore",
      path: "Sources",
      exclude: [
        "Extensions/WebKit+Extension.swift",
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),

    .testTarget(
      name: "MarkEditCoreTests",
      dependencies: ["MarkEditCore"],
      path: "Tests",
      resources: [
        .process("Files"),
      ]
    ),
  ]
)
