#if EPISTEMOS_EXPERIMENTAL
import Foundation
import Observation
import os.signpost

extension Sig {
    /// Experimental-surface perf channel (§16): cold_open / spa_ready / warm_reopen
    /// intervals, filterable in Instruments alongside the io.epistemos.core categories.
    /// Mirrors `Sig.agentSurface` (ProAgentPerf).
    nonisolated public static let experimentalSurface = OSSignposter(
        subsystem: "io.epistemos.core", category: "experimental_surface")
}

/// Measurement producer for docs/perf-budgets.toml `[experimental_surface]` — the
/// numbers behind the §16 "opens instantly" perf gate. Values are milliseconds of the
/// most recent occurrence this process; nil = not yet exercised (honest, never faked).
/// Enforcement (feeding these into check-perf-budgets.sh) is the remaining §16 wiring;
/// this is the OSSignposter/measurement half.
@MainActor
@Observable
final class ExperimentalPerfMetrics {
    static let shared = ExperimentalPerfMetrics()

    /// supervisor.start() -> .running (backend spawned + healthz OK). Budget: cold_open_ms_max 1500.
    private(set) var coldOpenMs: Double?
    /// WKWebView load -> navigation didFinish (SPA painted). Budget: exp_first_paint_ms_max 1000.
    private(set) var spaReadyMs: Double?
    /// Agent-room re-entry while the backend is already warm. Budget: warm_reopen_ms_max 100.
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
