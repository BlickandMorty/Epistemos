import Foundation

/// P5.H (visible determinism) — the honest Swift-side status of the EML vault
/// re-rank (`agent_core` storage/vault.rs, gated by `EPISTEMOS_EML_RERANK_V1`).
/// The re-rank runs in-process via the Rust FFI and reads the SAME env flag this
/// helper reads, so the surface reflects exactly what the runtime does. Mirrors
/// `DeterministicSchemaGateStatus` (the schema-gate surface) — same opt-in
/// truth table as Rust's `vault::eml_rerank_enabled` ("1"/"true"/"yes"/"on").
nonisolated enum EmlRerankGateStatus {
    static let flagName = "EPISTEMOS_EML_RERANK_V1"

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
                headline: "EML re-rank: ON",
                detail: "Vault search results are re-ranked by the EML energy eml(-ln(bm25+ε), excerpt-coverage) — fusing lexical BM25 with how much of the query the snippet actually covers (smaller energy = better). A deterministic, no-model retrieval re-rank."
            )
        }
        return Status(
            isActive: false,
            headline: "EML re-rank: off (opt-in)",
            detail: "Set \(flagName)=1 to re-rank vault search by the EML BM25+coverage fusion. Off by default for zero behavior change until promoted."
        )
    }
}
