import Foundation
import os

/// Thin Swift wrapper around the Rust NightBrain live-scheduler FFI
/// (commit b0d229be). Exposes the four canonical entry points
/// — register / list / run / preempt+reset — as a clean Swift surface
/// other parts of the app can drive without touching UniFFI directly.
///
/// Exposes the Rust NightBrain scheduler registry follow-up flagged
/// after the b118d361 pass. Before this wrapper, AppBootstrap called
/// the FFI directly once at startup but the rest of the app had no
/// surface to:
///
/// - Trigger an ad-hoc live run (e.g. from the Provenance Console
///   diagnostics row's "Run NightBrain pass now" button)
/// - Snapshot the live registered task names for status UI
/// - Preempt an in-flight run (e.g. when the user starts typing or
///   thermal pressure flips)
///
/// Determinism: every method is a pure FFI passthrough; no caching,
/// no state. Idempotent (matches the Rust singleton's contract).
///
/// MAS gate: gated `#if canImport(agent_coreFFI)` so MAS test builds
/// without the FFI module link cleanly.
final class NightBrainLiveRegistry: Sendable {
    nonisolated static let shared = NightBrainLiveRegistry()

    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "NightBrainLiveRegistry"
    )

    nonisolated private init() {}

    /// Idempotently register all 10 canonical NightBrain tasks against
    /// the process-global Rust scheduler. Safe to call multiple times;
    /// re-registering a name is a no-op. Returns the names that ended
    /// up registered (the union of any pre-existing registrations +
    /// the canonical set).
    @discardableResult
    nonisolated func registerCanonicalTasks() -> [String] {
        #if canImport(agent_coreFFI)
        let registered = nightbrainRegisterCanonicalTasks()
        Self.log.debug(
            "registerCanonicalTasks: \(registered.count, privacy: .public) names"
        )
        return registered
        #else
        return []
        #endif
    }

    /// Snapshot the live scheduler's currently-registered task names.
    /// Cheap; no execution. Intended for diagnostics UI.
    nonisolated func registeredTaskNames() -> [String] {
        #if canImport(agent_coreFFI)
        return nightbrainLiveRegisteredTaskNames()
        #else
        return []
        #endif
    }

    /// Trigger an ad-hoc live execution of every registered task.
    /// Returns per-task outcome strings ("name:status:items_processed").
    /// Honours cooperative cancellation via `preempt()`.
    ///
    /// Today the canonical live tasks are NoOp implementations (see
    /// Rust nightbrain::live::NoOpTask). They report `skipped` rather
    /// than `complete` until real bodies replace them incrementally
    /// without changing this surface.
    nonisolated func runRegisteredTasks() -> [String] {
        #if canImport(agent_coreFFI)
        let outcomes = nightbrainRunLiveRegisteredTasks()
        Self.log.debug(
            "runRegisteredTasks: \(outcomes.count, privacy: .public) outcomes"
        )
        return outcomes
        #else
        return []
        #endif
    }

    /// Cancel any in-flight live tasks. Idempotent.
    nonisolated func preempt() {
        #if canImport(agent_coreFFI)
        nightbrainPreemptLiveScheduler()
        #endif
    }

    /// Reset the cancellation token so the next admission window can
    /// run. Pair with `preempt()` (e.g. preempt when user starts
    /// typing, reset when they go idle again).
    nonisolated func reset() {
        #if canImport(agent_coreFFI)
        nightbrainResetLiveScheduler()
        #endif
    }
}
