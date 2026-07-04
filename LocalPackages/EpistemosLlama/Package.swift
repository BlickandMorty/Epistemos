// swift-tools-version: 5.9
// EpistemosLlama — the MAS-legal embedded llama.cpp lane (Plan 1-MAS §2.1 / §11 R1).
//
// The `llama` binaryTarget is a PINNED upstream XCFramework (release b9870,
// sha256-verified) fetched into Binary/ by scripts/fetch-llama-xcframework.sh.
// It is never committed. Run that script once per checkout before building
// anything that depends on this package.
//
// MAS rules honored here: in-process linked library only — no subprocess, no
// server, no JIT. The upstream framework embeds its Metal library in the
// binary (__ggml_metallib section), so there is no metallib path resolution
// inside the sandbox.

import PackageDescription

let package = Package(
    name: "EpistemosLlama",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "EpistemosLlama", targets: ["EpistemosLlama"]),
        .executable(name: "llama-spike", targets: ["LlamaSpike"]),
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            path: "Binary/llama.xcframework"
        ),
        .target(
            name: "EpistemosLlama",
            dependencies: ["llama"],
            path: "Sources/EpistemosLlama"
        ),
        .executableTarget(
            name: "LlamaSpike",
            dependencies: ["EpistemosLlama"],
            path: "Sources/LlamaSpike"
        ),
    ]
)
