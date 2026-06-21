import Foundation

/// SUBSTRATE STAGE-2 promotion readiness (owner 2026-06-21: "STAGE-2 LIVE flip if parityRate is
/// solid"). The authoritative-lane flip itself already exists
/// (`RuntimeRouterShadow.authoritativeLane`, behind `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`), and the
/// rollout precondition is described as "parityRate near-100%" — but nothing measured "solid"
/// rigorously. This operationalizes it: parity must clear BOTH a sample floor and a rate floor
/// before arming the flip is safe.
///
/// Pure → fully headless-testable. The inputs (`parityObservations` / `parityRate`) are
/// observe-only metrics accumulated at runtime while STAGE-1b is armed, so the verdict is `nil`
/// of parity → `.notReady` until the app has actually run armed. Consumed by
/// `RuntimeRouterHealthRow` to show a precise green-light instead of an eyeballed percentage.
enum RuntimeRouterStage2Readiness {

    /// Minimum observed turns before the agreement rate is statistically meaningful.
    static let minObservations = 50
    /// Minimum router-vs-live agreement to promote — near-100% by design, so the armed-and-DIFFERENT
    /// case the flip introduces stays vanishingly rare (a near-no-op rollout).
    static let minParityRate = 0.98

    enum Verdict: Equatable {
        case ready
        case notReady(reason: String)

        var isReady: Bool { self == .ready }
    }

    /// Evaluate STAGE-2 readiness from the observe-only parity metrics.
    static func evaluate(parityObservations: Int, parityRate: Double?) -> Verdict {
        guard parityObservations > 0, let rate = parityRate else {
            return .notReady(
                reason: "no parity observed yet — arm STAGE-1b (EPISTEMOS_RUNTIMEROUTER_LIVE_V0) and use the app"
            )
        }
        if parityObservations < minObservations {
            return .notReady(reason: "\(parityObservations)/\(minObservations) parity samples — gather more before promoting")
        }
        if rate < minParityRate {
            let pct = Int((rate * 100).rounded())
            return .notReady(
                reason: "parity \(pct)% < \(Int(minParityRate * 100))% — router still diverges from the live path; do NOT promote"
            )
        }
        return .ready
    }

    /// Convenience for the health row / diagnostics.
    static func isReady(parityObservations: Int, parityRate: Double?) -> Bool {
        evaluate(parityObservations: parityObservations, parityRate: parityRate).isReady
    }

    /// Short, owner-facing readiness label.
    static func summary(parityObservations: Int, parityRate: Double?) -> String {
        switch evaluate(parityObservations: parityObservations, parityRate: parityRate) {
        case .ready:
            return "READY to promote — parity solid"
        case .notReady(let reason):
            return "not ready — \(reason)"
        }
    }
}
