import Foundation
import Testing

/// Source-guard suite that proves the Core/App Store boundary stays direct
/// and in-process. Test-only: this file never imports or instantiates the
/// production types it audits — it reads their source and asserts on the
/// load-bearing strings. Failures here mean a future patch eroded the
/// boundary; fix the production file, do not relax the assertion.
///
/// Doctrine §7 lane: Core open — MAS/Core vs Pro capability symbol
/// separation. Sister gates: MCPBridgeTests and ToolTierBridge runtime tests.
@Suite("Core/MAS Boundary Source Guard")
struct CoreMASBoundarySourceGuardTests {

    @Test("Retired LocalAgent gateway policy stays deleted")
    func retiredLocalAgentGatewayPolicyStaysDeleted() throws {
        let url = try sourceMirrorURL(for: "Epistemos/LocalAgent/LocalAgentGatewayPolicy.swift")
        #expect(!FileManager.default.fileExists(atPath: url.path),
                "LocalAgentGatewayPolicy.swift belongs to the retired local-agent gateway stack and must not be restored")
    }

    // MARK: - ToolTierBridge

    @Test("ToolTierBridge Core App Store allowlist contains only in-process tools")
    func toolTierBridgeCoreAllowlistIsInProcess() throws {
        let source = try loadToolTierBridgeSource()

        #expect(source.contains("coreAppStoreAllowedToolNames: Set<String>"),
                "ToolTierBridge must expose the Core App Store tool allowlist as a set")

        let allowlist = try sliceBetween(
            in: source,
            startMarker: "coreAppStoreAllowedToolNames: Set<String> = [",
            endMarker: "]"
        )

        // These are the only tools a sandboxed App Store build can satisfy
        // without subprocess, CLI, MCP, or browser-use. Anything else added
        // here without a corresponding capability gate is Pro leakage.
        for required in ["vault.search", "vault.read", "vault.write", "vault.list",
                         "file.read", "file.write", "file.patch", "file.search",
                         "system.todo", "graph.query", "memory.curated", "eidos.query",
                         "web.search", "web.extract", "web.crawl",
                         "note.template", "note.linker", "clarify.ask"] {
            #expect(allowlist.contains("\"\(required)\""),
                    "Core App Store allowlist must include \(required)")
        }

        // Hard-block tools that absolutely cannot ride the App Store sandbox.
        // If any of these strings appear inside the allowlist literal block,
        // someone tried to smuggle Pro capability into Core.
        for forbidden in ["bash", "shell_exec", "browser_use", "computer_use",
                          "docker", "mcp_call", "cli_passthrough",
                          "delegate_task", "intelligence.mixture_of_minds",
                          "note_template", "note_linker", "clarify",
                          "skills.list", "skills.view", "skills.manage", "skills",
                          ] {
            #expect(!allowlist.contains("\"\(forbidden)\""),
                    "Core App Store allowlist must NOT contain \(forbidden) — that is a Pro/Research capability")
        }
    }

    @Test("ToolTierBridge distribution enum encodes the three-tier ship model")
    func toolTierBridgeDistributionEnumPresent() throws {
        let source = try loadToolTierBridgeSource()

        #expect(source.contains("enum Distribution: Sendable"),
                "ToolTierBridge must declare the Distribution enum")
        #expect(source.contains("case currentBuild"),
                "Distribution must declare currentBuild")
        #expect(source.contains("case coreAppStore"),
                "Distribution must declare coreAppStore")
        #expect(source.contains("case proResearch"),
                "Distribution must declare proResearch")
    }

    @Test("ToolTierBridge detects App Store / MAS_SANDBOX builds via compile flags")
    func toolTierBridgeDetectsAppStoreBuild() throws {
        let source = try loadToolTierBridgeSource()

        // The Core/Pro split has to be detectable at compile time, otherwise a
        // single build would have to ship both feature sets and gate at
        // runtime — exactly the architecture this gate exists to prevent.
        #expect(source.contains("EPISTEMOS_APP_STORE"),
                "ToolTierBridge must check the EPISTEMOS_APP_STORE compile flag")
        #expect(source.contains("MAS_SANDBOX"),
                "ToolTierBridge must check the MAS_SANDBOX compile flag")
        #expect(source.contains("APP_SANDBOX_CONTAINER_ID"),
                "ToolTierBridge must fall back to the App Sandbox container env var at runtime")
        #expect(source.contains("private static var isCoreAppStoreBuild: Bool"),
                "ToolTierBridge must expose the App Store detection as a single source of truth")
    }

    @Test("ToolTierBridge owns the runtime executor via a single surfacedTools gate")
    func toolTierBridgeOwnsRuntimeExecutorGate() throws {
        let source = try loadToolTierBridgeSource()

        #expect(source.contains("static func surfacedTools("),
                "ToolTierBridge must expose surfacedTools as the single tool-list gate")
        #expect(source.contains("static func isSurfacedToolName("),
                "ToolTierBridge must expose isSurfacedToolName for per-tool gating")
        #expect(source.contains("static func resolvedDistribution("),
                "ToolTierBridge must expose resolvedDistribution so the gate is reproducible from any caller")
    }

    // MARK: - MCPBridge

    @Test("MCPBridge policy-denies tools/call before dispatch")
    func mcpBridgeDeniesUnsurfacedToolsCall() throws {
        let source = try loadMCPBridgeSource()

        #expect(source.contains("private func policyGateResponse("),
                "MCPBridge must expose the policy gate before dispatch")
        #expect(source.contains("case \"tools/call\":"),
                "MCPBridge policy gate must intercept tools/call requests")
        #expect(source.contains("ToolSurfacePolicy.isSurfacedToolName("),
                "MCPBridge must consult ToolSurfacePolicy before allowing a tools/call to dispatch")
        #expect(source.contains("recordToolCallPolicyDenial("),
                "MCPBridge must record provenance for every policy denial")

        // The denial branch must short-circuit with a JSON-RPC error and never
        // fall through to the actual dispatch. The error code -32601 is "Method
        // not found" per JSON-RPC 2.0; pinning it here keeps the wire contract
        // stable for any consumer.
        let toolsCallBranch = try sliceBetween(
            in: source,
            startMarker: "case \"tools/call\":",
            endMarker: "default:"
        )
        #expect(toolsCallBranch.contains("Self.jsonRpcError("),
                "MCPBridge must respond with a JSON-RPC error when a tool is not surfaced")
        #expect(toolsCallBranch.contains("code: -32601"),
                "MCPBridge denial must use JSON-RPC error code -32601 (Method not found) for unsurfaced tools")
    }

    @Test("MCPBridge tags every policy denial with toolCallDenied provenance")
    func mcpBridgeRecordsToolCallDeniedProvenance() throws {
        let source = try loadMCPBridgeSource()

        let denialFn = try sliceBetween(
            in: source,
            startMarker: "private func recordToolCallPolicyDenial(",
            endMarker: "private func nextPolicyGateToolCallID()"
        )
        #expect(denialFn.contains(".toolCallRequested"),
                "MCPBridge must emit a toolCallRequested event so the timeline is complete")
        #expect(denialFn.contains(".toolCallDenied"),
                "MCPBridge must emit a toolCallDenied event so downstream filters can reason about it")
        #expect(denialFn.contains("status: .denied"),
                "MCPBridge denial must carry status: .denied so storage classifies it correctly")
        #expect(denialFn.contains("\"source\": \"mcp_bridge_policy_gate\""),
                "MCPBridge denial metadata must tag the source as mcp_bridge_policy_gate")
        #expect(denialFn.contains("\"surface\": \"omega_dispatch\""),
                "MCPBridge denial metadata must tag the surface as omega_dispatch")
        #expect(denialFn.contains("\"policy\": \"tool_surface\""),
                "MCPBridge denial metadata must tag the policy as tool_surface")
        #expect(denialFn.contains(#""policy_gate":"tool_surface""#),
                "MCPBridge denial argumentsJSON must record the policy_gate marker for offline audit")
    }

    @Test("MCPBridge resolves distribution names deterministically for storage")
    func mcpBridgeResolvesDistributionNamesDeterministically() throws {
        let source = try loadMCPBridgeSource()

        let namer = try sliceBetween(
            in: source,
            startMarker: "private static func policyGateDistributionName(",
            endMarker: "private static func jsonRpcSuccess("
        )
        #expect(namer.contains("\"current_build\""),
                "Distribution name mapping must emit current_build")
        #expect(namer.contains("\"core_app_store\""),
                "Distribution name mapping must emit core_app_store")
        #expect(namer.contains("\"pro_research\""),
                "Distribution name mapping must emit pro_research")
    }

    // MARK: - Cross-file invariants

    @Test("Boundary policy files do not host their own Touch ID prompts")
    func boundaryFilesContainNoLAContextUsage() throws {
        // Sovereign Gate doctrine: only Epistemos/Sovereign/SovereignGate.swift
        // may instantiate LAContext. These three boundary files have no
        // business prompting for biometrics — they are routing/policy code.
        for relativePath in [
            "Epistemos/Bridge/ToolTierBridge.swift",
            "Epistemos/Omega/MCPBridge.swift",
        ] {
            let source = try loadMirroredSourceTextFile(relativePath)
            #expect(!source.contains("LAContext("),
                    "\(relativePath) must NOT instantiate LAContext — Sovereign Gate is the single owner")
            #expect(!source.contains("canEvaluatePolicy"),
                    "\(relativePath) must NOT call canEvaluatePolicy — Sovereign Gate is the single owner")
            #expect(!source.contains("evaluatePolicy"),
                    "\(relativePath) must NOT call evaluatePolicy — Sovereign Gate is the single owner")
        }
    }

    @Test("Boundary policy files do not spawn subprocesses themselves")
    func boundaryFilesDoNotSpawnSubprocesses() throws {
        // Subprocess orchestration belongs in the Rust agent_core (Pro/Research
        // only). These three Swift boundary files must remain pure routing /
        // policy / FFI surfaces — not process launchers.
        for relativePath in [
            "Epistemos/Bridge/ToolTierBridge.swift",
            "Epistemos/Omega/MCPBridge.swift",
        ] {
            let source = try loadMirroredSourceTextFile(relativePath)
            #expect(!source.contains("Process()"),
                    "\(relativePath) must NOT instantiate Foundation.Process — orchestration belongs in Rust")
            #expect(!source.contains("Subprocess("),
                    "\(relativePath) must NOT use swift-subprocess directly — orchestration belongs in Rust")
        }
    }

    @Test("Retired native channel automation paths stay deleted")
    func retiredNativeChannelAutomationPathsStayDeleted() throws {
        let retiredFiles = [
            "Epistemos/Omega/iMessageDriver/IMessageDriverService.swift",
            "Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift",
            "Epistemos/Omega/iMessageDriver/IMessageNativeSetupDoctor.swift",
            "Epistemos/Omega/Channels/ChannelRegistryState.swift",
            "Epistemos/Omega/Channels/DriverChannelControlPlane.swift",
            "Epistemos/Views/Settings/IMessageDriverSettingsView.swift",
            "Epistemos/Views/Settings/ChannelsSettingsView.swift",
        ]

        for relativePath in retiredFiles {
            let url = try sourceMirrorURL(for: relativePath)
            #expect(!FileManager.default.fileExists(atPath: url.path),
                    "\(relativePath) is retired with the old native channel/message-driver stack and must not be restored")
        }

        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        #expect(!bootstrap.contains("ChannelRegistryState"))
        #expect(!bootstrap.contains("IMessageDriverService"))
        #expect(!bootstrap.contains("IMessageChannelAdapter"))

        let environment = try loadMirroredSourceTextFile("Epistemos/App/AppEnvironment.swift")
        #expect(!environment.contains(".environment(bootstrap.channelRegistry)"))
        #expect(!environment.contains(".environment(bootstrap.iMessageDriver)"))

        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        #expect(!settings.contains(".channels"))
        #expect(!settings.contains(".iMessageDriver"))
        #expect(!settings.contains("ChannelsSettingsView"))
        #expect(!settings.contains("IMessageDriverSettingsView"))

        let project = try loadMirroredSourceTextFile("Epistemos.xcodeproj/project.pbxproj")
        #expect(project.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"$(inherited) DEBUG EPISTEMOS_APP_STORE MAS_SANDBOX"),
                "Epistemos-AppStore Debug must define both EPISTEMOS_APP_STORE and MAS_SANDBOX")
        #expect(project.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"$(inherited) EPISTEMOS_APP_STORE MAS_SANDBOX"),
                "Epistemos-AppStore Release must define both EPISTEMOS_APP_STORE and MAS_SANDBOX")
    }

    // MARK: - Helpers

    private func loadToolTierBridgeSource() throws -> String {
        try loadMirroredSourceTextFile("Epistemos/Bridge/ToolTierBridge.swift")
    }

    private func loadMCPBridgeSource() throws -> String {
        try loadMirroredSourceTextFile("Epistemos/Omega/MCPBridge.swift")
    }

    /// Returns the substring of `source` between the first occurrence of
    /// `startMarker` and the next occurrence of `endMarker`. Throws if either
    /// marker is missing — that means the source has drifted in a way the
    /// test wasn't designed to detect, and the assertion list needs an update.
    private func sliceBetween(
        in source: String,
        startMarker: String,
        endMarker: String
    ) throws -> String {
        guard let startRange = source.range(of: startMarker) else {
            Issue.record("Source did not contain expected start marker: \(startMarker)")
            throw SourceSliceError.missingStartMarker(startMarker)
        }
        let afterStart = source[startRange.upperBound...]
        guard let endRange = afterStart.range(of: endMarker) else {
            Issue.record("Source did not contain expected end marker after start: \(endMarker)")
            throw SourceSliceError.missingEndMarker(endMarker)
        }
        return String(afterStart[..<endRange.lowerBound])
    }

    private enum SourceSliceError: Error {
        case missingStartMarker(String)
        case missingEndMarker(String)
    }
}
