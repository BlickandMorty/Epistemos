import Testing

/// Source-guard suite that proves the Core/App Store boundary stays direct
/// and in-process. Test-only: this file never imports or instantiates the
/// production types it audits — it reads their source and asserts on the
/// load-bearing strings. Failures here mean a future patch eroded the
/// boundary; fix the production file, do not relax the assertion.
///
/// Doctrine §7 lane: Core open — MAS/Core vs Pro capability symbol
/// separation. Sister gates: HermesGatewayPolicyTests, MCPBridgeTests,
/// ToolTierBridge runtime tests.
@Suite("Core/MAS Boundary Source Guard")
struct CoreMASBoundarySourceGuardTests {

    // MARK: - HermesGatewayPolicy

    @Test("HermesGatewayPolicy keeps deterministic local substrate Core-direct")
    func hermesPolicyKeepsLocalSubstrateDirect() throws {
        let source = try loadHermesGatewayPolicySource()

        // The local substrate branch must be Core-tier, direct route, no
        // network, no subprocess. If any of these flip, Core would start
        // routing local answers through the Hermes gateway — the exact
        // architectural drift this gate prevents.
        #expect(source.contains("case .deterministicLocalSubstrate:"),
                "HermesGatewayPolicy must enumerate the deterministic local substrate surface")

        let localBranch = try sliceBetween(
            in: source,
            startMarker: "case .deterministicLocalSubstrate:",
            endMarker: "case .localPromptFormatting:"
        )
        #expect(localBranch.contains("tier: .core"),
                "Deterministic local substrate must remain Core-tier")
        #expect(localBranch.contains("route: .directSubstrate"),
                "Deterministic local substrate must use the direct route, not the Hermes gateway")
        #expect(localBranch.contains("requiresNetwork: false"),
                "Deterministic local substrate must not require network")
        #expect(localBranch.contains("requiresSubprocess: false"),
                "Deterministic local substrate must not require a subprocess")
        #expect(localBranch.contains("preservesDirectSubstratePath: true"),
                "Deterministic local substrate must preserve the direct substrate path")
        #expect(localBranch.contains("evidenceReturn: .none"),
                "Deterministic local substrate must not require structured evidence — it IS the evidence")
    }

    @Test("HermesGatewayPolicy keeps local prompt formatting Core in-process")
    func hermesPolicyKeepsLocalPromptInProcess() throws {
        let source = try loadHermesGatewayPolicySource()

        #expect(source.contains("case .localPromptFormatting:"),
                "HermesGatewayPolicy must enumerate the local prompt formatting surface")

        let promptBranch = try sliceBetween(
            in: source,
            startMarker: "case .localPromptFormatting:",
            endMarker: "case .cloudProvider,"
        )
        #expect(promptBranch.contains("tier: .core"),
                "Local prompt formatting must remain Core-tier")
        #expect(promptBranch.contains("route: .inProcessLocalPrompt"),
                "Local prompt formatting must route in-process — never via the Hermes gateway")
        #expect(promptBranch.contains("requiresNetwork: false"),
                "Local prompt formatting must not require network")
        #expect(promptBranch.contains("requiresSubprocess: false"),
                "Local prompt formatting must not require a subprocess")
        #expect(promptBranch.contains("preservesDirectSubstratePath: true"),
                "Local prompt formatting must preserve the direct substrate path")
    }

    @Test("HermesGatewayPolicy routes every cloud provider through the Hermes gateway")
    func hermesPolicyRoutesCloudProvidersThroughGateway() throws {
        let source = try loadHermesGatewayPolicySource()

        // The whole point of the gateway is that cloud providers do not get
        // their own architecture. They share one Pro/Research-only route with
        // structured evidence return. If a future patch peels off (say) an
        // OpenAI-specific direct path, this assertion is what catches it.
        #expect(source.contains("case .cloudProvider,"),
                "HermesGatewayPolicy must enumerate the cloud provider surfaces")

        let cloudBranch = try sliceBetween(
            in: source,
            startMarker: "case .cloudProvider,",
            endMarker: "case .cliDelegation:"
        )
        #expect(cloudBranch.contains(".openAIProvider,"),
                "OpenAI must share the cloud provider branch, not a bespoke one")
        #expect(cloudBranch.contains(".anthropicProvider,"),
                "Anthropic must share the cloud provider branch, not a bespoke one")
        #expect(cloudBranch.contains(".googleProvider,"),
                "Google must share the cloud provider branch, not a bespoke one")
        #expect(cloudBranch.contains(".openAICompatibleProvider,"),
                "OpenAI-compatible providers must share the cloud provider branch")
        #expect(cloudBranch.contains(".codexAccountProvider:"),
                "Codex account provider must share the cloud provider branch")
        #expect(cloudBranch.contains("tier: .proResearch"),
                "Cloud providers must be Pro/Research-only — never Core/App Store")
        #expect(cloudBranch.contains("route: .hermesGateway"),
                "Cloud providers must route through the Hermes gateway, not direct")
        #expect(cloudBranch.contains("requiresNetwork: true"),
                "Cloud providers must declare they require network")
        #expect(cloudBranch.contains("preservesDirectSubstratePath: false"),
                "Cloud providers cannot claim to preserve the direct substrate path")
        #expect(cloudBranch.contains("evidenceReturn: .structuredEvidenceProvenance"),
                "Cloud providers must return structured evidence provenance, not free-form output")
    }

    @Test("HermesGatewayPolicy keeps every external surface gateway-bound")
    func hermesPolicyKeepsExternalSurfacesGatewayBound() throws {
        let source = try loadHermesGatewayPolicySource()

        // CLI / MCP / Hermes subprocess / browser / Docker / explicit external
        // side effects all share the gateway too. Any patch that gives one of
        // them its own route is a Pro architecture splinter.
        for surface in ["cliDelegation", "mcpWebTool", "hermesSubprocess",
                        "browserComputerUse", "dockerDevcontainer",
                        "explicitExternalSideEffect"] {
            #expect(source.contains("case .\(surface):"),
                    "HermesGatewayPolicy must enumerate the \(surface) surface")
        }

        // Spot-check that each external surface declares Pro/Research tier and
        // hermesGateway route. We slice the file from each case marker forward
        // and assert the branch contents.
        for (surface, nextMarker) in [
            ("cliDelegation", "case .mcpWebTool:"),
            ("mcpWebTool", "case .hermesSubprocess:"),
            ("hermesSubprocess", "case .browserComputerUse:"),
            ("browserComputerUse", "case .dockerDevcontainer:"),
            ("dockerDevcontainer", "case .explicitExternalSideEffect:"),
        ] {
            let branch = try sliceBetween(
                in: source,
                startMarker: "case .\(surface):",
                endMarker: nextMarker
            )
            #expect(branch.contains("tier: .proResearch"),
                    "\(surface) must declare Pro/Research tier")
            #expect(branch.contains("route: .hermesGateway"),
                    "\(surface) must route through the Hermes gateway")
            #expect(branch.contains("evidenceReturn: .structuredEvidenceProvenance"),
                    "\(surface) must return structured evidence provenance")
        }
    }

    @Test("HermesGatewayPolicy preserves the human-readable boundary lines")
    func hermesPolicyPreservesBoundaryLines() throws {
        let source = try loadHermesGatewayPolicySource()

        // These two strings are the prose the policy uses to explain itself in
        // logs, settings UI, and Codex deliberation briefs. If a refactor
        // drops them, downstream code that pattern-matches on them silently
        // breaks.
        #expect(source.contains("externalTierBoundaryLine"),
                "HermesGatewayPolicy must export externalTierBoundaryLine")
        #expect(source.contains(
            "Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only."
        ), "externalTierBoundaryLine prose must remain stable for log/UI consumers")

        #expect(source.contains("localCoreBoundaryLine"),
                "HermesGatewayPolicy must export localCoreBoundaryLine")
        #expect(source.contains(
            "Local Hermes-family prompt formatting may stay Core-safe only when it runs in-process over local context."
        ), "localCoreBoundaryLine prose must remain stable for log/UI consumers")
    }

    @Test("HermesGatewayPolicy isAllowedInCoreAppStoreBuild requires the full Core invariant")
    func hermesPolicyCoreAllowanceRequiresFullInvariant() throws {
        let source = try loadHermesGatewayPolicySource()

        // The Core gate is a conjunction of four conditions. Loosening any one
        // of them silently widens the App Store allowlist. The body is small
        // enough to assert verbatim.
        let body = try sliceBetween(
            in: source,
            startMarker: "static func isAllowedInCoreAppStoreBuild",
            endMarker: "static func route(for surface: Surface)"
        )
        #expect(body.contains("decision.tier == .core"),
                "Core allowance must require Core tier")
        #expect(body.contains("!decision.requiresNetwork"),
                "Core allowance must reject network-requiring surfaces")
        #expect(body.contains("!decision.requiresSubprocess"),
                "Core allowance must reject subprocess-requiring surfaces")
        #expect(body.contains("decision.preservesDirectSubstratePath"),
                "Core allowance must require the direct substrate path")
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
        for required in ["vault_search", "vault_read", "vault_write",
                         "read_file", "write_file", "patch", "search_files",
                         "todo", "graph_query", "memory",
                         "web_search", "web_extract", "web_crawl"] {
            #expect(allowlist.contains("\"\(required)\""),
                    "Core App Store allowlist must include \(required)")
        }

        // Hard-block tools that absolutely cannot ride the App Store sandbox.
        // If any of these strings appear inside the allowlist literal block,
        // someone tried to smuggle Pro capability into Core.
        for forbidden in ["bash", "shell_exec", "browser_use", "computer_use",
                          "docker", "mcp_call", "cli_passthrough",
                          "hermes_subprocess"] {
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
            "Epistemos/LocalAgent/HermesGatewayPolicy.swift",
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
            "Epistemos/LocalAgent/HermesGatewayPolicy.swift",
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

    // MARK: - Helpers

    private func loadHermesGatewayPolicySource() throws -> String {
        try loadMirroredSourceTextFile("Epistemos/LocalAgent/HermesGatewayPolicy.swift")
    }

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
