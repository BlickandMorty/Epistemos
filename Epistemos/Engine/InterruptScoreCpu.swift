// InterruptScoreCpu.swift
//
// V6.2 canonical `u_t` (interrupt score) computation, Swift CPU path.
//
// Per `docs/fusion/helios v6.2.md` §1.4 Falsifier 6:
//
//   "Adopt Swift CPU-fallback as the canonical implementation,
//    dispatched on `DispatchQueue` with QoS `.userInteractive`.
//    Reasoning: at this dispatch granularity the Metal command-encoder
//    setup cost (~50–150 µs even for empty encoders, per WWDC20
//    timing data) dominates the actual arithmetic; CPU is faster
//    end-to-end. Keep a `.metal` shadow implementation behind a
//    feature flag for batch-amortised computation when ≥ 64 tokens
//    are processed in one go (the speech / dictation lane)."
//
// Target performance: P99 < 100 µs per call on the expected path.
// Achieved through: pure arithmetic, no allocations, no locks, no
// heap traffic, weights resolved at compile time via `static let`.
//
// The 30-task calibration corpus (§1.5) classifies tokens into
// LOW (u_t < 0.25), MED (0.25 ≤ u_t < 0.65), HIGH (u_t ≥ 0.65)
// buckets. This module exposes that bucket function so call sites
// can route based on the V6.2-canonical thresholds.

import Foundation
import os

// MARK: - Inputs

/// V6.2 InterruptScore inputs — five signals combined into the per-token
/// u_t value. Each component is clamped to [0, 1] at construction so
/// callers don't have to defend the contract at the call site.
///
/// Per V6.2 §1.4:
///   u_t = α·H + β·WBO + γ·Sheaf + δ·ToolNeed + ε·ConnectomeAlarm
nonisolated public struct InterruptScoreInputs: Sendable, Equatable {
    /// H: per-token surprise / entropy signal. Higher = more
    /// uncertain next-token distribution.
    public let entropy: Float
    /// WBO: Witnessed-Bayes-Outcome confidence delta. Higher = a
    /// claim just shifted enough that the runtime should re-check
    /// downstream witnesses.
    public let witnessedBayesOutcome: Float
    /// Sheaf: residual-claim coherence signal. Higher = the local
    /// sheaf of claims/evidence has incoherent edges that warrant
    /// re-audit before continuing emission.
    public let sheafResidual: Float
    /// ToolNeed: predicted tool-call necessity. Higher = the model
    /// is about to need a tool (web fetch, code execution, etc.).
    public let toolNeed: Float
    /// ConnectomeAlarm: route-divergence alarm from the routing
    /// layer. Higher = the current generation has diverged from
    /// the planned route enough to warrant Controller-plane
    /// intervention.
    public let connectomeAlarm: Float

    /// All-zero inputs. Useful as a neutral default for tests + as
    /// a sentinel for the "no signal yet" case at start of a turn.
    public static let zero = InterruptScoreInputs(
        entropy: 0,
        witnessedBayesOutcome: 0,
        sheafResidual: 0,
        toolNeed: 0,
        connectomeAlarm: 0
    )

    /// All-one inputs. Useful as the upper-bound sanity check.
    public static let maximal = InterruptScoreInputs(
        entropy: 1,
        witnessedBayesOutcome: 1,
        sheafResidual: 1,
        toolNeed: 1,
        connectomeAlarm: 1
    )

    /// Clamps every component to [0, 1] so the downstream weighted-sum
    /// stays in [0, 1] regardless of caller input. Sub-zero inputs
    /// (numerical noise) become 0; super-one inputs (unbounded
    /// surprise sources) become 1. This is a contract enforcement,
    /// not a normalization.
    public init(
        entropy: Float,
        witnessedBayesOutcome: Float,
        sheafResidual: Float,
        toolNeed: Float,
        connectomeAlarm: Float
    ) {
        self.entropy = Self.clamp01(entropy)
        self.witnessedBayesOutcome = Self.clamp01(witnessedBayesOutcome)
        self.sheafResidual = Self.clamp01(sheafResidual)
        self.toolNeed = Self.clamp01(toolNeed)
        self.connectomeAlarm = Self.clamp01(connectomeAlarm)
    }

    @inline(__always)
    private static func clamp01(_ x: Float) -> Float {
        // Manual clamp instead of x.clamped(to: 0...1) so we avoid the
        // ClosedRange allocation/closure overhead on the hot path.
        // NaN: produce 0 (the safe default for an unconfident signal).
        guard x.isFinite else { return 0 }
        if x < 0 { return 0 }
        if x > 1 { return 1 }
        return x
    }
}

// MARK: - Compute

/// V6.2 canonical InterruptScore CPU computation.
///
/// Usage:
///
///     let u = InterruptScoreCpu.compute(InterruptScoreInputs(
///         entropy: 0.6,
///         witnessedBayesOutcome: 0.4,
///         sheafResidual: 0.2,
///         toolNeed: 0.1,
///         connectomeAlarm: 0.0
///     ))
///     // u ≈ 0.305 → MEDIUM bucket
///     let bucket = InterruptScoreCpu.bucket(u)
///
/// Dispatch contract: callers MUST run `compute` on a high-QoS queue
/// (`.userInteractive`) per V6.2 §1.4. The function itself is
/// `@inlinable` + `@inline(__always)` so call sites that already run
/// on the right queue pay zero indirection cost.
// `nonisolated` so the enum's static members + nested types are
// callable from nonisolated contexts (the unstructured Task inside
// StreamingDelegate.onComplete). The compute is pure arithmetic;
// MainActor isolation was implicit from the module default and
// never load-bearing.
nonisolated public enum InterruptScoreCpu {
    // V6.2 §1.4 canonical weights. The sum is exactly 1.0:
    //   0.30 + 0.25 + 0.20 + 0.15 + 0.10 = 1.00
    // This means the output u_t is guaranteed to land in [0, 1]
    // whenever every input is in [0, 1] — which is enforced by
    // `InterruptScoreInputs.init` above. The `weightsSumToOne` test
    // locks the invariant so a future weight tweak forces an
    // explicit doctrine update.

    /// α — entropy coefficient (the noisiest signal, weighted
    /// heaviest per V6.2 calibration corpus §1.5).
    public static let alpha: Float = 0.30
    /// β — Witnessed-Bayes-Outcome coefficient.
    public static let beta: Float = 0.25
    /// γ — sheaf-residual coefficient.
    public static let gamma: Float = 0.20
    /// δ — ToolNeed coefficient.
    public static let delta: Float = 0.15
    /// ε — ConnectomeAlarm coefficient (the smallest, but still
    /// load-bearing as the Controller-plane veto signal).
    public static let epsilon: Float = 0.10

    /// LOW/MED boundary per V6.2 §1.5: u_t < 0.25 is the
    /// "boilerplate / continuation / format" zone.
    public static let lowMediumThreshold: Float = 0.25

    /// MED/HIGH boundary per V6.2 §1.5: u_t ≥ 0.65 is the
    /// "novel theorem / tool call / OOD prompt" zone where the
    /// Controller plane should consider re-routing or escalating.
    public static let mediumHighThreshold: Float = 0.65

    /// Compute u_t. P99 < 100 µs requirement: pure arithmetic,
    /// no allocations, no locks, no branches on the hot path.
    /// Result is guaranteed in [0, 1].
    @inlinable
    @inline(__always)
    public static func compute(_ inputs: InterruptScoreInputs) -> Float {
        let u = alpha * inputs.entropy
              + beta * inputs.witnessedBayesOutcome
              + gamma * inputs.sheafResidual
              + delta * inputs.toolNeed
              + epsilon * inputs.connectomeAlarm
        // Output clamp defends against tiny FP drift past 1.0 from
        // the multi-term sum (e.g. weights summing to 1.00000001
        // through normal rounding) so the bucket function below
        // doesn't classify 0.9999999 vs 1.0000001 differently.
        if u < 0 { return 0 }
        if u > 1 { return 1 }
        return u
    }

    /// Classify a u_t value into one of the three V6.2 §1.5 buckets.
    @inlinable
    public static func bucket(_ u: Float) -> Bucket {
        if u < lowMediumThreshold { return .low }
        if u < mediumHighThreshold { return .medium }
        return .high
    }

    /// V6.2 §1.5 three-bucket classification: 27 of the 30
    /// calibration tasks land in LOW or MED on M2 Pro 16 GB; 3 are
    /// explicitly tier-moved (HIGH → workstation/cloud).
    public enum Bucket: String, Sendable, CaseIterable {
        /// u_t < 0.25 — boilerplate, completion, formatting.
        /// Safe to keep generating without interrupt.
        case low
        /// 0.25 ≤ u_t < 0.65 — multi-step reasoning, cross-file
        /// refactor, retrieval QA. The mid-zone where most of the
        /// real product workload lives.
        case medium
        /// u_t ≥ 0.65 — novel theorem, OOD prompt, tool call,
        /// agentic multi-hop. The Controller plane should consider
        /// re-routing or escalating before continuing.
        case high
    }
}

// MARK: - Dispatch helper

// MARK: - Bucket conversion to AnswerPacket schema

// `nonisolated extension` so `sampleTurnBucket` + `answerPacketBucket`
// can be called from the unstructured `Task { … }` inside
// `StreamingDelegate.onComplete`. Without this the module's default
// MainActor isolation would make these static methods MainActor-bound
// even though their implementation has zero MainActor-required work.
nonisolated extension InterruptScoreCpu {
    /// Bridge from the internal `Bucket` enum to the wire-level
    /// `InterruptBucket` field on `AnswerPacket`. Keeps the two enum
    /// shapes orthogonal: this engine module owns the compute, the
    /// AnswerPacket schema owns the wire form + an `.unavailable`
    /// sentinel for packets that didn't sample u_t.
    @inlinable
    nonisolated public static func answerPacketBucket(
        for bucket: Bucket
    ) -> InterruptBucket {
        switch bucket {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }

    /// Sample a coarse u_t bucket from runtime signals available at
    /// `StreamingDelegate.onComplete`. V6.2 second-wiring (2026-05-12):
    /// WBO is now live (sampled from the Rust ClaimLedger event delta);
    /// sheafResidual + connectomeAlarm remain at 0 until their substrate
    /// hooks land.
    ///
    /// Heuristics (acknowledged as crude — V6.2 §1.5 calibration corpus
    /// will refine when the full signal set is wired):
    ///
    ///   - entropy ≈ `outputTokens / 500` (longer outputs averaged
    ///     more next-token uncertainty over the turn). Clamped to
    ///     [0, 1] by the inputs constructor.
    ///   - WBO = `WBOSubstrateObserver.shared.sampleAndAdvance()` — see
    ///     that observer for delta semantics; first call returns 0
    ///     (priming), subsequent calls return `clamp01(eventDelta /
    ///     WBOSubstrateObserver.scaleEvents)`.
    ///   - toolNeed = 1.0 when stopReason == "tool_use" (the agent
    ///     is requesting a tool — a strong runtime signal of HIGH
    ///     u_t turns per V6.2 §1.5 task 21-23). Otherwise 0.
    ///
    /// Returns `.unavailable` only if `outputTokens == 0` (the turn
    /// produced no signal at all — degenerate). All other cases
    /// return a real bucket so the audit channel carries actionable
    /// signal even at this wiring stage.
    nonisolated public static func sampleTurnBucket(
        stopReason: String,
        inputTokens: Int,
        outputTokens: Int
    ) -> InterruptBucket {
        guard outputTokens > 0 else { return .unavailable }
        let _ = inputTokens // reserved for a future "input-side
                            // entropy" component once the model
                            // surfaces it via FFI

        let entropy = Float(outputTokens) / 500.0
        let toolNeed: Float = stopReason == "tool_use" ? 1.0 : 0.0
        let wbo = WBOSubstrateObserver.shared.sampleAndAdvance()
        let inputs = InterruptScoreInputs(
            entropy: entropy,
            witnessedBayesOutcome: wbo,
            sheafResidual: 0,
            toolNeed: toolNeed,
            connectomeAlarm: 0
        )
        let u = compute(inputs)
        return answerPacketBucket(for: bucket(u))
    }
}

// MARK: - WBO Substrate Observer (V6.2 §1.4 substrate hook 2026-05-12)
//
// Process-global observer of the Rust `ClaimLedger.events_since(0).len()`
// counter. Each call to `sampleAndAdvance()` returns the WBO (witnessed-
// Bayes-outcome) signal for the just-completed turn — i.e. how many
// new evidence_committed / claim_committed / claim_status_changed /
// retraction events have been emitted since the previous sample.
//
// Doctrine reference: V6.2 §1.4 calls for WBO to be the per-turn
// confidence delta on the witnessed evidence set. The closest active-
// app analog is the ledger's event count: every claim/evidence/retraction
// event represents one unit of witnessed-state shift. Using the delta as
// WBO turns the ledger into a live confidence-shift sampler without
// needing a per-claim confidence field on the Rust side.
//
// Behavior:
//   1. First call after process start "primes" the baseline by recording
//      the current event count and returning 0. This avoids reporting a
//      spurious WBO=1.0 on the first emit when the ledger may have
//      decades of legacy events from a long-running session.
//   2. Each subsequent call computes `delta = max(0, now - last)`,
//      stores `now`, and returns `min(1.0, Float(delta) / scaleEvents)`.
//      `scaleEvents = 8` saturates at WBO=1.0 when 8+ events fire in a
//      single turn (a busy retrieval / tool-call turn).
//   3. If the underlying FFI returns `.empty` (e.g. the legacy ledger
//      isn't linked into this build), `eventCount == 0` and the delta
//      stays at 0 forever — graceful degradation.
//
// Thread-safety: `OSAllocatedUnfairLock` over a tiny `(initialized,
// lastCount)` state. All access goes through `sampleAndAdvance()` or
// `resetForTesting()`; both methods take the lock once and release.
nonisolated final class WBOSubstrateObserver: Sendable {
    /// 8 events per turn saturates WBO at 1.0. A typical retrieval-heavy
    /// agentic turn commits 3-6 events (one per evidence + one per claim
    /// + one per retraction); 8+ marks "definitely an evidentially
    /// active turn." See V6.2 §1.5 calibration task 21-23 for the
    /// tool-call-heavy expected range.
    public static let scaleEvents: Float = 8.0

    /// Process-global singleton. Wrapped in a lock so concurrent
    /// `sampleAndAdvance()` calls (e.g. two parallel chat turns) cannot
    /// double-count or lose updates.
    public static let shared = WBOSubstrateObserver()

    private struct State: Sendable {
        var initialized: Bool
        var lastEventCount: UInt64
    }

    private let lock = OSAllocatedUnfairLock<State>(
        initialState: State(initialized: false, lastEventCount: 0)
    )

    /// Callback used to read the live event count. Defaults to the live
    /// Rust ledger client; tests replace it with a controlled stub.
    private let readEventCount: @Sendable () -> UInt64

    /// Initializer used in production reads the live `RustProvenanceLedgerClient`.
    public init() {
        self.readEventCount = {
            RustProvenanceLedgerClient.summary().eventCount
        }
    }

    /// Test-only initializer that lets a unit test drive the event-count
    /// source deterministically without invoking the Rust FFI.
    public init(readEventCount: @escaping @Sendable () -> UInt64) {
        self.readEventCount = readEventCount
    }

    /// Sample WBO for the just-completed turn. See type-level doc.
    /// Returns a value in `[0, 1]` clamped by `InterruptScoreInputs`'s
    /// constructor regardless of any underlying drift.
    public func sampleAndAdvance() -> Float {
        let now = readEventCount()
        return lock.withLock { state in
            // Priming: first call records the baseline, returns 0.
            guard state.initialized else {
                state.initialized = true
                state.lastEventCount = now
                return 0
            }
            let delta: UInt64 = now > state.lastEventCount
                ? now - state.lastEventCount
                : 0
            state.lastEventCount = now
            let wbo = Float(delta) / Self.scaleEvents
            // `InterruptScoreInputs.init` will re-clamp, but doing it
            // here keeps the returned value self-consistent for tests.
            if wbo < 0 { return 0 }
            if wbo > 1 { return 1 }
            return wbo
        }
    }

    /// Test-only reset of the priming state. Lets repeated test cases
    /// observe deterministic first-call behavior without spinning up a
    /// fresh observer.
    public func resetForTesting() {
        lock.withLock { state in
            state.initialized = false
            state.lastEventCount = 0
        }
    }
}

/// Convenience wrapper that hops to `.userInteractive` QoS per
/// V6.2 §1.4 dispatch contract. Use this when the caller is not
/// already on a high-QoS queue. When the caller IS on
/// `.userInteractive` already, call `InterruptScoreCpu.compute`
/// directly to avoid the (tiny) queue-hop cost.
///
/// Returns the computed u_t synchronously. Backed by a single
/// global serial queue — this is a synchronous block, not an
/// async dispatch — because the V6.2 budget (< 100 µs P99) is
/// tight enough that `DispatchQueue.global(qos: .userInteractive)
/// .sync` adds measurable overhead vs `DispatchQueue.sync` on a
/// dedicated queue with pre-set QoS.
public enum InterruptScoreDispatch {
    private static let queue = DispatchQueue(
        label: "com.epistemos.interruptScore",
        qos: .userInteractive
    )

    /// Compute u_t synchronously on the dedicated `.userInteractive`
    /// queue. Use only when you are NOT already on a high-QoS queue.
    public static func computeOnUserInteractive(
        _ inputs: InterruptScoreInputs
    ) -> Float {
        queue.sync {
            InterruptScoreCpu.compute(inputs)
        }
    }
}
