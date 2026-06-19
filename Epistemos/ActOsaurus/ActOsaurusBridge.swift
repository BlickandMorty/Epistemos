import Foundation

// Osaurus Act import — Seam A bridge (P3.0). The protocol Act drives against the
// vendored Osaurus substrate, using the vendored `ServerHealth` enum. Pro-only
// (`#if !EPISTEMOS_APP_STORE`) — the whole Osaurus seam (server/VM/relay) is outside
// the MAS sandbox. The INERT stub is the default until S3 links OsaurusCore + wires
// the runtime behind the no-hidden-fallback bar; the real conformer is the growth
// point. REAL APIs ONLY — nothing here claims a runtime it doesn't have.
#if !EPISTEMOS_APP_STORE

/// The seam Act drives against Osaurus.
protocol ActOsaurusBridge: Sendable {
    /// Current health of the Osaurus local server (the vendored `ServerHealth`).
    func serverHealth() -> ServerHealth
    /// True only when a real Osaurus runtime is wired AND live. Honest gate — never
    /// reports live for the inert seam.
    var isLive: Bool { get }
}

/// INERT default — the seam exists + compiles + reports `ServerHealth.stopped`, and
/// is not live. The honest state until S3 vendors+links OsaurusCore and wires the
/// runtime. NEVER silently routes anything.
struct InertActOsaurusBridge: ActOsaurusBridge {
    func serverHealth() -> ServerHealth { .stopped }
    var isLive: Bool { false }
}

/// The real conformer's growth point (S3+: link OsaurusCore, drive the local
/// server). Today it delegates to the inert stub so the type exists end-to-end
/// WITHOUT claiming a runtime it doesn't have (no fake "running"). When OsaurusCore
/// is linked, this drives the actual server; until then it is honestly inert.
struct OsaurusActBridge: ActOsaurusBridge {
    private let backing = InertActOsaurusBridge()
    func serverHealth() -> ServerHealth { backing.serverHealth() }
    var isLive: Bool { false }
}

/// Resolves the bridge for the current flag — honest, never a hidden route. Armed
/// only when the flag is on; even then inert until the runtime lands (S3+).
enum ActOsaurusBridgeFactory {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ActOsaurusBridge {
        ActOsaurusGateStatus.isEnabled(environment[ActOsaurusGateStatus.flagName])
            ? OsaurusActBridge()
            : InertActOsaurusBridge()
    }
}

#endif
