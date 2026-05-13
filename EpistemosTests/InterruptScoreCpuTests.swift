import Testing
import Foundation
@testable import Epistemos

@Suite("InterruptScoreCpu — V6.2 canonical Swift CPU u_t")
struct InterruptScoreCpuTests {

    // MARK: - V6.2 canonical weights

    @Test("V6.2 canonical weights sum to exactly 1.0")
    func weightsSumToOne() {
        // Per V6.2 §1.4 + §1.5: α=0.30, β=0.25, γ=0.20, δ=0.15, ε=0.10.
        // The sum must be 1.0 so a fully-saturated input vector yields
        // u_t = 1.0 exactly. If any weight is tuned, the others must
        // move in lockstep — this test breaks to force the doctrine
        // update.
        let sum = InterruptScoreCpu.alpha
                + InterruptScoreCpu.beta
                + InterruptScoreCpu.gamma
                + InterruptScoreCpu.delta
                + InterruptScoreCpu.epsilon
        #expect(abs(sum - 1.0) < 1e-6,
            "V6.2 weights must sum to 1.0 — got \(sum)")
    }

    @Test("V6.2 canonical weights match doctrine values")
    func weightsMatchDoctrine() {
        // Doctrine pin per V6.2 §1.4 Falsifier 6. If any of these
        // change without an accompanying V6.2 doctrine note, the
        // active app has silently drifted from canon.
        #expect(InterruptScoreCpu.alpha == 0.30)
        #expect(InterruptScoreCpu.beta == 0.25)
        #expect(InterruptScoreCpu.gamma == 0.20)
        #expect(InterruptScoreCpu.delta == 0.15)
        #expect(InterruptScoreCpu.epsilon == 0.10)
    }

    @Test("V6.2 §1.5 LOW/MED/HIGH bucket thresholds match doctrine")
    func bucketThresholdsMatchDoctrine() {
        #expect(InterruptScoreCpu.lowMediumThreshold == 0.25)
        #expect(InterruptScoreCpu.mediumHighThreshold == 0.65)
    }

    // MARK: - Compute correctness

    @Test("Zero inputs yield u_t = 0")
    func zeroInputsYieldZero() {
        let u = InterruptScoreCpu.compute(.zero)
        #expect(u == 0)
    }

    @Test("Maximal inputs yield u_t = 1")
    func maximalInputsYieldOne() {
        let u = InterruptScoreCpu.compute(.maximal)
        #expect(abs(u - 1.0) < 1e-6,
            "fully-saturated inputs must yield u_t ≈ 1, got \(u)")
    }

    @Test("Hand-calculated mixed input matches weighted sum")
    func mixedInputMatchesHandCalculation() {
        // entropy=0.6, WBO=0.4, sheaf=0.2, toolNeed=0.1, connectome=0.0
        // = 0.30*0.6 + 0.25*0.4 + 0.20*0.2 + 0.15*0.1 + 0.10*0.0
        // = 0.18 + 0.10 + 0.04 + 0.015 + 0
        // = 0.335
        let inputs = InterruptScoreInputs(
            entropy: 0.6,
            witnessedBayesOutcome: 0.4,
            sheafResidual: 0.2,
            toolNeed: 0.1,
            connectomeAlarm: 0.0
        )
        let u = InterruptScoreCpu.compute(inputs)
        #expect(abs(u - 0.335) < 1e-6,
            "weighted sum mismatch: expected 0.335, got \(u)")
        #expect(InterruptScoreCpu.bucket(u) == .medium,
            "u=0.335 must classify as .medium per V6.2 §1.5")
    }

    @Test("Negative input components clamp to zero")
    func negativeInputsClampToZero() {
        let inputs = InterruptScoreInputs(
            entropy: -0.5,
            witnessedBayesOutcome: -10.0,
            sheafResidual: -0.001,
            toolNeed: 0.0,
            connectomeAlarm: 0.0
        )
        let u = InterruptScoreCpu.compute(inputs)
        #expect(u == 0)
    }

    @Test("Super-one input components clamp to one")
    func superOneInputsClampToOne() {
        let inputs = InterruptScoreInputs(
            entropy: 5.0,
            witnessedBayesOutcome: 10.0,
            sheafResidual: 1.0001,
            toolNeed: 999.0,
            connectomeAlarm: 100.0
        )
        let u = InterruptScoreCpu.compute(inputs)
        #expect(abs(u - 1.0) < 1e-6)
    }

    @Test("NaN inputs decay to zero (safe-by-default contract)")
    func nanInputsDecayToZero() {
        let inputs = InterruptScoreInputs(
            entropy: .nan,
            witnessedBayesOutcome: .infinity,
            sheafResidual: 0.5,
            toolNeed: -.infinity,
            connectomeAlarm: 0.0
        )
        // entropy=NaN → 0; WBO=+inf → 0 (not finite, decays to 0);
        // sheaf=0.5 → 0.5; toolNeed=-inf → 0; connectome=0 → 0.
        // u_t = 0.20 * 0.5 = 0.10
        let u = InterruptScoreCpu.compute(inputs)
        #expect(abs(u - 0.10) < 1e-6,
            "NaN/Inf inputs must decay to 0 per safe-by-default contract; got u=\(u)")
    }

    // MARK: - Bucket boundaries

    @Test("Bucket boundaries match V6.2 §1.5 thresholds")
    func bucketBoundaries() {
        // Just below LOW/MED — LOW.
        #expect(InterruptScoreCpu.bucket(0.0) == .low)
        #expect(InterruptScoreCpu.bucket(0.24) == .low)
        #expect(InterruptScoreCpu.bucket(0.2499) == .low)
        // At LOW/MED — MED.
        #expect(InterruptScoreCpu.bucket(0.25) == .medium)
        #expect(InterruptScoreCpu.bucket(0.5) == .medium)
        #expect(InterruptScoreCpu.bucket(0.6499) == .medium)
        // At MED/HIGH — HIGH.
        #expect(InterruptScoreCpu.bucket(0.65) == .high)
        #expect(InterruptScoreCpu.bucket(0.9) == .high)
        #expect(InterruptScoreCpu.bucket(1.0) == .high)
    }

    // MARK: - V6.2 §1.4 P99 latency budget

    /// V6.2 §1.4 Falsifier 6: u_t per token must be < 100 µs on the
    /// expected path. We run 10,000 trials, sort, and check P99.
    /// Budget: 100 µs = 100,000 ns. We give ourselves 5× headroom
    /// (500 µs) in CI to account for noisy laptops + Xcode test
    /// harness overhead; the real-world P99 should be well inside
    /// 100 µs on a quiet `.userInteractive` queue.
    @Test("u_t computation P99 < 500 µs (5× V6.2 budget for CI headroom)")
    func p99LatencyWithinBudget() {
        let iterations = 10_000
        var nanos = [UInt64](repeating: 0, count: iterations)
        let inputs = InterruptScoreInputs(
            entropy: 0.6,
            witnessedBayesOutcome: 0.4,
            sheafResidual: 0.2,
            toolNeed: 0.1,
            connectomeAlarm: 0.0
        )

        // Warm up so the first-call JIT/branch-predictor cost
        // doesn't dominate the histogram.
        for _ in 0..<256 {
            _ = InterruptScoreCpu.compute(inputs)
        }

        for i in 0..<iterations {
            let t0 = DispatchTime.now()
            _ = InterruptScoreCpu.compute(inputs)
            let t1 = DispatchTime.now()
            nanos[i] = t1.uptimeNanoseconds &- t0.uptimeNanoseconds
        }

        nanos.sort()
        let p99 = nanos[Int(Double(iterations) * 0.99) - 1]
        let p50 = nanos[iterations / 2]

        // 500 µs = 500,000 ns. The V6.2 hard budget is 100,000 ns;
        // we give a 5× margin so this test stays green on CI under
        // load. If P99 ever blows past 500 µs, the implementation
        // has acquired allocations / locks / heap traffic — investigate.
        let p99Budget: UInt64 = 500_000
        #expect(p99 < p99Budget,
            "u_t P99 budget exceeded: got \(p99) ns, budget \(p99Budget) ns (p50=\(p50) ns)")
    }

    @Test("Dispatch helper produces the same value as direct compute")
    func dispatchHelperMatchesDirectCompute() {
        let inputs = InterruptScoreInputs(
            entropy: 0.7,
            witnessedBayesOutcome: 0.3,
            sheafResidual: 0.6,
            toolNeed: 0.2,
            connectomeAlarm: 0.5
        )
        let direct = InterruptScoreCpu.compute(inputs)
        let viaDispatch = InterruptScoreDispatch.computeOnUserInteractive(inputs)
        #expect(direct == viaDispatch)
    }

    // MARK: - V6.2 §1.5 calibration-corpus spot checks

    @Test("Boilerplate-zone inputs classify as LOW")
    func boilerplateZoneClassifiesAsLow() {
        // Function continuation / brace closing — low entropy, low
        // sheaf residual, no tool need, no connectome alarm.
        let inputs = InterruptScoreInputs(
            entropy: 0.1,
            witnessedBayesOutcome: 0.05,
            sheafResidual: 0.0,
            toolNeed: 0.0,
            connectomeAlarm: 0.0
        )
        let u = InterruptScoreCpu.compute(inputs)
        #expect(InterruptScoreCpu.bucket(u) == .low,
            "boilerplate u=\(u) must classify as .low per V6.2 §1.5 task 1-7")
    }

    @Test("Novel-theorem-zone inputs classify as HIGH")
    func novelTheoremZoneClassifiesAsHigh() {
        // Novel theorem authoring — high entropy, high sheaf
        // residual (the prover-input claim graph is incoherent
        // until the proof closes), high tool need (mathlib lookup
        // probable).
        let inputs = InterruptScoreInputs(
            entropy: 0.9,
            witnessedBayesOutcome: 0.7,
            sheafResidual: 0.8,
            toolNeed: 0.6,
            connectomeAlarm: 0.4
        )
        let u = InterruptScoreCpu.compute(inputs)
        #expect(InterruptScoreCpu.bucket(u) == .high,
            "novel-theorem u=\(u) must classify as .high per V6.2 §1.5 task 20")
    }

    @Test("Inputs struct equality is structural")
    func inputsEqualityIsStructural() {
        let a = InterruptScoreInputs(
            entropy: 0.5,
            witnessedBayesOutcome: 0.5,
            sheafResidual: 0.5,
            toolNeed: 0.5,
            connectomeAlarm: 0.5
        )
        let b = InterruptScoreInputs(
            entropy: 0.5,
            witnessedBayesOutcome: 0.5,
            sheafResidual: 0.5,
            toolNeed: 0.5,
            connectomeAlarm: 0.5
        )
        let c = InterruptScoreInputs(
            entropy: 0.5,
            witnessedBayesOutcome: 0.5,
            sheafResidual: 0.6,  // different
            toolNeed: 0.5,
            connectomeAlarm: 0.5
        )
        #expect(a == b)
        #expect(a != c)
    }
}
