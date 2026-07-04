#if !EPISTEMOS_APP_STORE
import Foundation
import Observation
import os.signpost

extension Sig {
    /// Agent-surface perf channel (doctrine §4): cold_open / spa_ready /
    /// warm_reopen intervals, filterable in Instruments alongside the
    /// existing io.epistemos.core categories.
    nonisolated public static let agentSurface = OSSignposter(subsystem: "io.epistemos.core", category: "agent_surface")
}

/// Measurement producer for docs/perf-budgets.toml [agent_surface] — the
/// owner-visible numbers behind the "opens instantly" contract. Values are
/// milliseconds of the most recent occurrence; nil = not yet exercised this
/// process (honest, never faked).
@MainActor
@Observable
final class ProAgentPerfMetrics {
    static let shared = ProAgentPerfMetrics()

    /// start() -> .running (web + opencode healthy). Budget: cold_open_ms_max 1500.
    private(set) var coldOpenMs: Double?
    /// SPA load driven -> render probe "ready". Budget: pro_first_paint_ms_max 1000 (server warm).
    private(set) var spaReadyMs: Double?
    /// Tab-return fast path duration. Budget: warm_reopen_ms_max 100.
    private(set) var warmReopenMs: Double?
    private(set) var lastUpdated: Date?

    func recordColdOpen(milliseconds: Double) {
        coldOpenMs = milliseconds
        lastUpdated = Date()
    }

    func recordSpaReady(milliseconds: Double) {
        spaReadyMs = milliseconds
        lastUpdated = Date()
    }

    func recordWarmReopen(milliseconds: Double) {
        warmReopenMs = milliseconds
        lastUpdated = Date()
    }
}
#endif
