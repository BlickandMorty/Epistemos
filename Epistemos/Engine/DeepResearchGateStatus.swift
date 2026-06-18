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
