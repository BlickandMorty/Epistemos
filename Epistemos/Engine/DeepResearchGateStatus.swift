import Foundation

/// DeerFlow slice 5b (visible surface) — the honest Swift-side status of the
/// multi-agent deep-research run (agent_core `deep_research`, gated by
/// `EPISTEMOS_DEEP_RESEARCH_V0`). Reads the SAME env flag the in-process Rust
/// `deep_research::deep_research_enabled()` reads, with the SAME opt-in truth
/// table, so the surface reflects exactly what the runtime does. Mirrors
/// `EmlRerankGateStatus` / `DeterministicSchemaGateStatus`.
nonisolated enum DeepResearchGateStatus {
    static let flagName = "EPISTEMOS_DEEP_RESEARCH_V0"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ rawValue: String?) -> Bool {
        guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(normalized)
    }

    /// Honest-capability gate for the run itself: deep research spawns isolated
    /// sub-agent LOOPS that use web/tools, which is a CLOUD capability (per
    /// CLAUDE.md, local models get fast/thinking/research — not agentic
    /// tool-using sub-agents). So `DeepResearchService.run` refuses anything but
    /// a recognized cloud provider. This is an explicit ALLOWLIST (not a
    /// denylist) so deep research can NEVER silently run on a route the user
    /// didn't pick — owner priority #1 (no hidden GPT route). The strings match
    /// `ChatCoordinator.resolveRustProviderName` (claude_*, openai_*, gemini_*,
    /// zai/glm, kimi_*, minimax, deepseek, perplexity); local resolves to
    /// `ollama`/`mlx`/`gguf`/`apple`, all of which return false.
    static func isCloudProvider(_ providerName: String) -> Bool {
        let normalized = providerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        let cloudPrefixes = [
            "claude", "anthropic", "openai", "gpt", "gemini", "google",
            "zai", "glm", "kimi", "minimax", "deepseek", "perplexity", "sonar",
        ]
        return cloudPrefixes.contains { normalized.hasPrefix($0) }
    }

    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "Deep research: ON (Pro)",
                detail: "A query can spin a multi-agent deep-research run: the lead decomposes it into sub-questions, isolated sub-agents research them IN PARALLEL, and a reporter synthesizes one answer that cites each [sub-question id]. Pro-only — it spawns cloud sub-agent loops."
            )
        }
        return Status(
            isActive: false,
            headline: "Deep research: off (opt-in)",
            detail: "Set \(flagName)=1 to enable multi-agent deep research (planner → parallel sub-agents → cited synthesis). Pro-only; off by default → the normal single-agent path."
        )
    }
}
