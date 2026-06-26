// swift-tools-version: 6.2
import PackageDescription

// AgentClone — a vendored, library-form clone of the "Agent!" macOS app.
//
// This package wraps the ENTIRE Agent! app source tree (copied verbatim under
// Sources/AgentClone) as a single library product so Epistemos can mount its
// real UI (`ContentView`) as the Chat surface.
//
// Dependency URLs + pinned versions mirror the app's
// Agent.xcodeproj/.../swiftpm/Package.resolved exactly (10 Agent* packages;
// their transitive deps — AXorcist, Commander, swift-syntax, swift-log — are
// resolved automatically by SwiftPM and need not be listed here).
let package = Package(
    name: "AgentClone",
    platforms: [
        // Matches the app's MACOSX_DEPLOYMENT_TARGET = 26.4 (Agent.xcodeproj),
        // which several FoundationModels APIs (e.g. SystemLanguageModel.tokenCount)
        // require. .v26 (== 26.0) is too low for those, so we pin the exact target.
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "AgentClone",
            targets: ["AgentClone"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/macOS26/AgentAccess.git", exact: "2.10.4"),
        .package(url: "https://github.com/macOS26/AgentAudit.git", exact: "1.2.0"),
        .package(url: "https://github.com/macOS26/AgentColorSyntax.git", exact: "1.2.1"),
        .package(url: "https://github.com/macOS26/AgentD1F.git", exact: "1.0.3"),
        .package(url: "https://github.com/macOS26/AgentEventBridges.git", exact: "1.1.0"),
        .package(url: "https://github.com/macOS26/AgentLLM.git", exact: "1.0.1"),
        .package(url: "https://github.com/macOS26/AgentMCP.git", exact: "1.6.1"),
        .package(url: "https://github.com/macOS26/AgentSwift.git", exact: "1.1.1"),
        .package(url: "https://github.com/macOS26/AgentTerminalNeo.git", exact: "1.37.2"),
        .package(url: "https://github.com/macOS26/AgentTools.git", exact: "2.53.5")
    ],
    targets: [
        .target(
            name: "AgentClone",
            dependencies: [
                .product(name: "AgentAccess", package: "AgentAccess"),
                .product(name: "AgentAudit", package: "AgentAudit"),
                .product(name: "AgentColorSyntax", package: "AgentColorSyntax"),
                .product(name: "AgentD1F", package: "AgentD1F"),
                // AgentEventBridges package vends its product as "XcodeScriptingBridge".
                .product(name: "XcodeScriptingBridge", package: "AgentEventBridges"),
                .product(name: "AgentLLM", package: "AgentLLM"),
                .product(name: "AgentMCP", package: "AgentMCP"),
                .product(name: "AgentSwift", package: "AgentSwift"),
                .product(name: "AgentTerminalNeo", package: "AgentTerminalNeo"),
                .product(name: "AgentTools", package: "AgentTools")
            ],
            // App-packaging files that are NOT part of library compilation.
            exclude: [
                "Info.plist",
                "Agent.entitlements",
                "LaunchAgents",
                "LaunchDaemons",
                // Byte-identical duplicate of Sound/StartupTwentiethAnniversaryMac.wav.
                // The app's Copy-Resources phase bundled the sound only once; SwiftPM
                // flattens .process resources by basename, so we keep one copy.
                "UX/Sound"
            ],
            resources: [
                // SDEFService loads these with `subdirectory: "SDEFs"`, so the
                // directory layout MUST be preserved verbatim → .copy.
                .copy("SDEFs"),
                // Startup sound loaded via Bundle.url(forResource:...).
                .process("Sound"),
                // App icon + asset catalog.
                .process("UX/Assets.xcassets"),
                .copy("UX/AppIcon.icon"),
                // In-app help bundle + color-syntax prompt doc + root JSON fixtures.
                .copy("Resources/Agent.help"),
                .process("ColorSyntax/SystemPrompt+Tools"),
                .process("send_message_input.json"),
                .process("send_message_output.json"),
                .process("send_image_input.json"),
                .process("send_image_output.json")
            ]
        ),
        .testTarget(
            name: "AgentCloneTests",
            dependencies: ["AgentClone"]
        )
    ]
)
