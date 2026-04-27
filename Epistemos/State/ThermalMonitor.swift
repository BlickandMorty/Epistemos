import Foundation
import Combine
import OSLog

// MARK: - W9.29 — Thermal-aware throttling
//
// Wraps `ProcessInfo.thermalState` (App Store-safe; no private APIs)
// in an @Observable so the agent loop + MLX inference + cloud-API
// dispatchers can preemptively throttle BEFORE the OS hardware-
// throttle kicks in.
//
// Why this matters on Apple Silicon (research dossier §W9.29):
// thermal throttle on MLX inference is the dominant UX killer —
// the user sees responses slow from 60 tok/s to 8 tok/s with no
// warning. Preemptive throttle = lower peak load, longer sustained
// throughput, no cliff.
//
// Integrates with PowerGate.shouldDefer() (already gates background
// work at thermal ≥ serious) by exposing the live state stream so
// the foreground agent loop can call `shouldThrottle(for:)` per
// inference call to scale `maxTokens` / batch size dynamically.
//
// This file is the SWIFT side. The Rust side wires it via
// `agent_core::circuit_breaker::CircuitBreaker` — a thermal event
// records a synthetic failure on the breaker so cloud-API call
// rates back off in lockstep.

@MainActor
@Observable
public final class ThermalMonitor {

    public static let shared = ThermalMonitor()

    private let log = Logger(subsystem: "com.epistemos", category: "ThermalMonitor")

    public private(set) var thermalState: ProcessInfo.ThermalState
    public private(set) var lastTransitionAt: Date

    private init() {
        self.thermalState = ProcessInfo.processInfo.thermalState
        self.lastTransitionAt = Date()
        startObserving()
    }

    // No deinit — singleton lives for app lifetime; NotificationCenter
    // observers auto-clean when the receiver is dealloc'd, which never
    // happens for `shared`.

    private func startObserving() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let new = ProcessInfo.processInfo.thermalState
                if new != self.thermalState {
                    self.log.info(
                        "thermal transition \(self.thermalState.rawValue, privacy: .public) → \(new.rawValue, privacy: .public)"
                    )
                    self.thermalState = new
                    self.lastTransitionAt = Date()
                }
            }
        }
    }

    // MARK: - Throttle hints for callers

    /// Returns the recommended response-token budget multiplier
    /// for an inference call given the current thermal state.
    /// Conservative back-off matches the perf agent's spec: cut
    /// budget HALF at .serious, QUARTER at .critical so sustained
    /// inference doesn't crater the foreground UI.
    public func tokenBudgetMultiplier() -> Double {
        Self.tokenBudgetMultiplier(for: thermalState)
    }

    /// Nonisolated static counterpart of `tokenBudgetMultiplier()`. Reads
    /// `ProcessInfo.processInfo.thermalState` directly (Sendable + thread-safe)
    /// so callers in `nonisolated` contexts (e.g. `LocalMLXRequest` inference
    /// requests) can consult the same scaling table without crossing the
    /// MainActor boundary. Single source of truth — if this table changes,
    /// the @MainActor instance method changes with it.
    public nonisolated static func currentTokenBudgetMultiplier() -> Double {
        tokenBudgetMultiplier(for: ProcessInfo.processInfo.thermalState)
    }

    /// Pure helper. Sendable input, Sendable output, no isolation needed.
    /// Both the @MainActor instance method and the nonisolated static
    /// surface route through this so the policy lives in one place.
    public nonisolated static func tokenBudgetMultiplier(
        for state: ProcessInfo.ThermalState
    ) -> Double {
        switch state {
        case .nominal: return 1.0
        case .fair: return 0.85
        case .serious: return 0.5
        case .critical: return 0.25
        @unknown default: return 0.5
        }
    }

    /// Returns true if the caller should outright skip a deferrable
    /// inference call (best for cosmetic "ambient recall" passes
    /// that the user didn't explicitly request).
    public func shouldSkipDeferrable() -> Bool {
        thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }

    /// Returns true if the call site should record a synthetic
    /// failure against its circuit breaker — useful when MLX
    /// inference itself starts taking 4× the expected wall-clock
    /// time without hitting any logical error.
    public func shouldThrottle(for purpose: ThrottlePurpose) -> Bool {
        switch (purpose, thermalState) {
        case (.userFacingInference, .critical): return true
        case (.userFacingInference, _): return false
        case (.backgroundBatch, .serious), (.backgroundBatch, .critical): return true
        case (.backgroundBatch, _): return false
        case (.cloudCall, .critical): return true
        case (.cloudCall, _): return false
        }
    }
}

public enum ThrottlePurpose: Sendable {
    /// Foreground response generation — only throttle on critical.
    case userFacingInference
    /// Background batches (vault index, Night Brain, FSRS sweep) —
    /// throttle on serious or critical.
    case backgroundBatch
    /// Cloud API request — throttle on critical (network is rarely
    /// the actual hot path; thermal-throttled networking still works
    /// at full speed).
    case cloudCall
}
