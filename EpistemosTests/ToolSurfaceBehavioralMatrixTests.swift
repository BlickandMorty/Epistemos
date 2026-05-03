import Testing
@testable import Epistemos

/// Behavioral matrix for `ToolSurfacePolicy.isSurfacedToolName` —
/// complements the source-text guards in
/// `CoreMASBoundarySourceGuardTests` by actually exercising the API.
///
/// Doctrine §7 lane: Core open — MAS/Core vs Pro capability symbol
/// separation. Sister suite: `CoreMASBoundarySourceGuardTests` (source
/// reads), `HermesGatewayPolicyTests` (per-surface decisions).
///
/// What this catches that source-text guards miss:
///   - Logic bugs where the allowlist literal is correct but the gate
///     function does the wrong comparison (case sensitivity, empty
///     string handling, distribution resolution).
///   - Pro/Research-only tool names accidentally getting surfaced under
///     a coreAppStore distribution because the gate forgot to filter.
@Suite("Tool Surface Behavioral Matrix")
nonisolated struct ToolSurfaceBehavioralMatrixTests {

    // MARK: - Core App Store allowlist round-trip

    @Test("every Core App Store allowlist entry surfaces under coreAppStore distribution")
    func everyCoreAllowlistEntrySurfaces() {
        for toolName in ToolSurfacePolicy.coreAppStoreAllowedToolNames {
            #expect(ToolSurfacePolicy.isSurfacedToolName(toolName, distribution: .coreAppStore),
                    "Allowlisted tool \(toolName) must be surfaced under .coreAppStore distribution")
        }
    }

    @Test("Core App Store allowlist is case-insensitive at the gate")
    func coreAllowlistIsCaseInsensitive() {
        // The gate canonicalizes via `lowercased()` — verify a couple of
        // mixed-case spellings still pass. If a future refactor swaps in
        // case-sensitive matching, callers that use uppercased tool names
        // would silently break.
        #expect(ToolSurfacePolicy.isSurfacedToolName("VAULT_SEARCH", distribution: .coreAppStore))
        #expect(ToolSurfacePolicy.isSurfacedToolName("Vault_Read", distribution: .coreAppStore))
        #expect(ToolSurfacePolicy.isSurfacedToolName("Web_Search", distribution: .coreAppStore))
    }

    // MARK: - Pro/Research-only tool names must NOT surface under Core

    @Test("Pro/Research tool names are blocked under coreAppStore distribution")
    func proResearchToolNamesAreBlockedUnderCore() {
        // The full set of forbidden-in-Core tool names per doctrine §7 + the
        // hard forbidden list. A Core build that surfaces any of these is a
        // P0 leakage.
        let forbiddenInCore: [String] = [
            "bash",
            "shell_exec",
            "browser_use",
            "browser",
            "computer_use",
            "computer",
            "docker",
            "devcontainer",
            "mcp_call",
            "mcp",
            "cli_passthrough",
            "claude_code_cli",
            "codex_cli",
            "gemini_cli",
            "kimi_cli",
            "hermes_subprocess",
        ]

        for toolName in forbiddenInCore {
            #expect(!ToolSurfacePolicy.isSurfacedToolName(toolName, distribution: .coreAppStore),
                    "Tool \(toolName) must NOT surface under Core App Store — that is Pro/Research leakage")
        }
    }

    @Test("Pro/Research tool names CAN surface under proResearch distribution")
    func proResearchToolNamesSurfaceUnderProResearch() {
        // Sanity: the gate doesn't blanket-block these names — they're Pro/Research-only,
        // not always-blocked. The default behavior in `isSurfacedToolName` is to allow
        // anything that doesn't match the special cases (think, image_generate). So a
        // Pro/Research distribution should let them through.
        for toolName in ["bash", "shell_exec", "browser_use", "computer_use", "docker"] {
            #expect(ToolSurfacePolicy.isSurfacedToolName(toolName, distribution: .proResearch),
                    "Tool \(toolName) must be available under .proResearch distribution — they are Pro tier, not always-forbidden")
        }
    }

    // MARK: - `think` is always blocked from the surfaced list

    @Test("think tool is always blocked from the surfaced list regardless of distribution")
    func thinkToolIsAlwaysBlocked() {
        // `think` is an internal scratchpad tool — it's deliberately not
        // surfaced to user-facing planning lists in any distribution.
        for distribution in [
            ToolSurfacePolicy.Distribution.coreAppStore,
            .proResearch,
            .currentBuild,
        ] {
            #expect(!ToolSurfacePolicy.isSurfacedToolName("think", distribution: distribution),
                    "`think` must never be surfaced — it is an internal scratchpad in distribution \(distribution)")
        }
    }

    // MARK: - surfacedTools filter parity

    @Test("surfacedTools filter mirrors isSurfacedToolName for every input")
    func surfacedToolsFilterMirrorsIsSurfacedToolName() {
        // Build a small synthetic tool list mixing allowed + forbidden +
        // never-surfaced names. Verify the array filter and the per-name
        // check agree on every entry.
        let synthetic: [OmegaToolDefinition] = [
            tool("vault_search"),
            tool("vault_read"),
            tool("bash"),
            tool("computer_use"),
            tool("think"),
            tool("web_search"),
            tool("docker"),
        ]

        for distribution in [
            ToolSurfacePolicy.Distribution.coreAppStore,
            .proResearch,
        ] {
            let filtered = ToolSurfacePolicy.surfacedTools(synthetic, distribution: distribution)
            let filteredNames = Set(filtered.map(\.name))

            for tool in synthetic {
                let perName = ToolSurfacePolicy.isSurfacedToolName(tool.name, distribution: distribution)
                let inFilter = filteredNames.contains(tool.name)
                #expect(perName == inFilter,
                        "surfacedTools and isSurfacedToolName disagree for \(tool.name) under \(distribution): per-name=\(perName), inFilter=\(inFilter)")
            }
        }
    }

    @Test("surfacedTools under coreAppStore yields strict subset of proResearch result")
    func coreSurfacedToolsAreSubsetOfProResearch() {
        // Core is a tighter sieve than Pro/Research. Any tool surfaced in
        // Core must also be surfaced in Pro/Research. The reverse does not
        // hold — Pro/Research can surface bash/computer_use while Core
        // cannot.
        let synthetic: [OmegaToolDefinition] = [
            tool("vault_search"),
            tool("vault_read"),
            tool("vault_write"),
            tool("read_file"),
            tool("write_file"),
            tool("patch"),
            tool("search_files"),
            tool("todo"),
            tool("graph_query"),
            tool("memory"),
            tool("web_search"),
            tool("web_extract"),
            tool("web_crawl"),
            tool("bash"),
            tool("shell_exec"),
            tool("browser_use"),
            tool("computer_use"),
            tool("docker"),
            tool("mcp_call"),
            tool("cli_passthrough"),
            tool("hermes_subprocess"),
        ]

        let coreSet = Set(ToolSurfacePolicy.surfacedTools(synthetic, distribution: .coreAppStore).map(\.name))
        let proSet = Set(ToolSurfacePolicy.surfacedTools(synthetic, distribution: .proResearch).map(\.name))

        #expect(coreSet.isSubset(of: proSet),
                "Core surfaced set must be a subset of Pro/Research surfaced set — got core=\(coreSet) pro=\(proSet)")
        #expect(coreSet != proSet,
                "Pro/Research must surface strictly more tools than Core — otherwise the tier distinction is performative")

        // Specifically, the Pro/Research extras must include the doctrine-forbidden-in-Core set.
        let extras = proSet.subtracting(coreSet)
        for forbidden in ["bash", "shell_exec", "browser_use", "computer_use",
                          "docker", "mcp_call", "cli_passthrough", "hermes_subprocess"] {
            #expect(extras.contains(forbidden),
                    "Pro/Research-only set must include \(forbidden) among the Core extras — got \(extras)")
        }
    }

    // MARK: - resolvedDistribution semantics

    @Test("resolvedDistribution preserves explicit Core or Pro choice")
    func resolvedDistributionPreservesExplicitChoice() {
        // The explicit cases (.coreAppStore, .proResearch) must round-trip
        // unchanged regardless of build mode. Only .currentBuild may be
        // remapped at runtime.
        #expect(ToolSurfacePolicy.resolvedDistribution(.coreAppStore) == .coreAppStore)
        #expect(ToolSurfacePolicy.resolvedDistribution(.proResearch) == .proResearch)
    }

    // MARK: - Helpers

    private func tool(_ name: String) -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: name,
            agent: "fixture",
            description: "fixture tool \(name)",
            argumentsExample: "{}",
            schemaJson: "{}",
            destructive: false,
            requiresConfirmation: false
        )
    }
}
