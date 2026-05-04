// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EpistenosSwift",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EpistenosKit", targets: ["EpistenosKit"]),
        .executable(name: "EpistenosApp", targets: ["EpistenosApp"]),
        .library(name: "EpistenosXPC", targets: ["EpistenosXPC"]),
    ],
    dependencies: [
        // helios_ffi is provided by the UniFFI-generated Swift bindings + Rust static lib.
        // In production this is a binaryTarget or a local swift package produced by
        // `cargo build` + `uniffi-bindgen-swift`.
    ],
    targets: [
        .target(
            name: "EpistenosKit",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "EpistenosApp",
            dependencies: [
                "EpistenosKit",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "EpistenosXPC",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "EpistenosKitTests",
            dependencies: ["EpistenosKit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
