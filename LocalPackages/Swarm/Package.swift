// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

// Epistemos-vendored, CORE-ONLY fork of Swarm (https://github.com/christopherkarani/Swarm, MIT).
//
// This is a hard core-only trim for the Epistemos Chat surface. Every cloud/sidecar
// path is physically removed from the source tree, NOT merely env-flag-gated, so
// NO HIDDEN SIDECAR can ever be reintroduced by a build flag:
//   - Providers/Conduit        (deleted — external Conduit package + cloud providers)
//   - Integration/{Wax,Membrane}, Internal/GraphRuntime (deleted — Wax/Hive/Membrane deps)
//   - Tools/Web                 (deleted — SwiftSoup web scraping)
//   - Memory/{ContextCoreMemory,DefaultAgentMemory}.swift (deleted — ContextCore dep)
//   - Workflow durable checkpoint/codec/engine (deleted — HiveCore dep)
//   - SwarmMCP / SwarmOpenTelemetry / SwarmMembrane products (dropped — Epistemos hosts
//     MCP via the Rust omega-mcp crate; telemetry via OSLog)
//
// Remaining dependency closure: swift-syntax (the @Tool macro plugin) + swift-log only.
// swift-syntax range is kept at the upstream 600.0.0..<603.0.0 to dodge the 600.0.1
// MacroSupport prebuilt landmine documented upstream. Inference is supplied by Epistemos's
// in-process EpistemosInProcessProvider (MLX / agent_core Rust-FFI) injected per-Agent.

let package = Package(
    name: "Swarm",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
    ],
    products: [
        .library(name: "Swarm", targets: ["Swarm"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"603.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.12.0"),
    ],
    targets: [
        .macro(
            name: "SwarmMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "Swarm",
            dependencies: [
                "SwarmMacros",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
