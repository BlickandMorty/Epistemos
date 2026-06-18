import Foundation

/// P8.5 (visible determinism) — the honest Swift-side status of the P8.1
/// deterministic schema gate (`agent_core` ToolRegistry.execute). The gate runs
/// in-process via the Rust FFI and reads the SAME `EPISTEMOS_SCHEMA_GATE_V1`
/// env flag this helper reads, so the surface reflects exactly what the runtime
/// enforces — never a fake claim. Surfacing the determinism is the app's edge,
/// not hidden plumbing.
///
/// Pure + `nonisolated` so the flag→status mapping is unit-testable without the
/// view (and the truth table stays in lockstep with Rust's `schema_gate_enabled`:
/// "1" / "true" / "yes" / "on" → active, anything else → off).
nonisolated enum DeterministicSchemaGateStatus {
    /// The env flag, mirrored from `registry.rs` `schema_gate_enabled()`.
    static let flagName = "EPISTEMOS_SCHEMA_GATE_V1"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    /// Whether the flag string enables the gate — byte-identical to the Rust
    /// side's accepted set.
    static func isEnabled(_ rawValue: String?) -> Bool {
        guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(normalized)
    }

    /// The honest status for the current process environment (defaults to the
    /// live `ProcessInfo` env — the same one the in-process Rust gate sees).
    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "Schema gate: ON",
                detail: "Every tool call's arguments are validated against the tool's typed input schema before the tool runs — malformed arguments are rejected (\"at {path}: {err}\") with no side effect. Deterministic + verifiable tool execution."
            )
        }
        return Status(
            isActive: false,
            headline: "Schema gate: off (opt-in)",
            detail: "Set \(flagName)=1 to enforce typed-schema validation of every tool call's arguments before execution. Off by default for zero behavior change until promoted."
        )
    }
}
