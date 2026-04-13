// swift-tools-version: 6.1

import PackageDescription

let llamaVersion = "b6871"

let package = Package(
    name: "GGUFRuntimeBridge",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "GGUFRuntimeBridge",
            targets: ["GGUFRuntimeBridge"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
            checksum: "ac657d70112efadbf5cd1db5c4f67eea94ca38556ada9e7442d5a5a461010d6f"
        ),
        .target(
            name: "GGUFRuntimeBridge",
            dependencies: [
                "llama",
            ]
        ),
    ]
)
