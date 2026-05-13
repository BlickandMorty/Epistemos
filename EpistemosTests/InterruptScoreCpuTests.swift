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

    // MARK: - V6.2 #4: AnswerPacket bucket sampling at emit time

    @Test("Bucket→InterruptBucket bridge maps all three values")
    func bucketBridgeMapsAllValues() {
        #expect(InterruptScoreCpu.answerPacketBucket(for: .low) == .low)
        #expect(InterruptScoreCpu.answerPacketBucket(for: .medium) == .medium)
        #expect(InterruptScoreCpu.answerPacketBucket(for: .high) == .high)
    }

    @Test("sampleTurnBucket returns .unavailable when no tokens produced")
    func sampleReturnsUnavailableForZeroOutput() {
        let bucket = InterruptScoreCpu.sampleTurnBucket(
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 0
        )
        #expect(bucket == .unavailable,
            "zero-output turn must yield .unavailable, not a default bucket")
    }

    @Test("sampleTurnBucket: short boilerplate response → LOW")
    func sampleShortResponseClassifiesAsLow() {
        // Reset the WBO observer so the priming contract holds for this
        // test — without this, a non-zero WBO contribution from an
        // earlier-running test could nudge a borderline bucket.
        WBOSubstrateObserver.shared.resetForTesting()
        // 20 output tokens → entropy ≈ 0.04 (very low).
        // toolNeed = 0 (no tool call). WBO primes to 0.
        // u_t ≈ 0.30 * 0.04 = 0.012 → LOW (< 0.25).
        let bucket = InterruptScoreCpu.sampleTurnBucket(
            stopReason: "end_turn",
            inputTokens: 30,
            outputTokens: 20
        )
        #expect(bucket == .low,
            "short response with no tool call must classify as LOW; got \(bucket)")
    }

    @Test("sampleTurnBucket: tool_use stop reason boosts toward HIGH")
    func sampleToolUseBoostsBucket() {
        // Reset the WBO observer so the first call below primes WBO=0
        // and subsequent calls also stay at 0 (no event activity in the
        // test ledger between immediate samples).
        WBOSubstrateObserver.shared.resetForTesting()
        // 100 output tokens → entropy ≈ 0.20.
        // toolNeed = 1.0 (tool_use stop).
        // u_t = 0.30 * 0.20 + 0.15 * 1.0 = 0.06 + 0.15 = 0.21 — still LOW.
        let lowBucket = InterruptScoreCpu.sampleTurnBucket(
            stopReason: "tool_use",
            inputTokens: 50,
            outputTokens: 100
        )
        // Same response WITHOUT tool_use: u_t = 0.06 only.
        let lowerBucket = InterruptScoreCpu.sampleTurnBucket(
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 100
        )
        // Both are LOW at this token-count, but ordering must hold:
        // tool_use never produces a STRICTLY-LOWER bucket than end_turn
        // for the same token volume. Stronger assertion: a longer
        // response with a tool_use stop should land at MEDIUM.
        #expect(lowBucket == .low || lowBucket == .medium)
        #expect(lowerBucket == .low)
        _ = lowerBucket // explicit-use clarification

        // Long response with tool_use → MEDIUM territory.
        // 500 output tokens → entropy ≈ 1.0 (clamped).
        // u_t = 0.30 + 0.15 = 0.45 — MEDIUM.
        let medBucket = InterruptScoreCpu.sampleTurnBucket(
            stopReason: "tool_use",
            inputTokens: 50,
            outputTokens: 500
        )
        #expect(medBucket == .medium,
            "long tool_use response must classify as MEDIUM; got \(medBucket)")
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

    // MARK: - V6.2 §1.4 WBO substrate hook (2026-05-12)

    @Test("WBO observer: first call primes baseline and returns 0")
    func wboObserverPrimesOnFirstCall() {
        // Hand-roll a controlled observer so we don't touch .shared and
        // don't depend on the live Rust ledger surface.
        let stub = WBOStubCounter(initial: 42)  // pretend the ledger has been active for a while
        let observer = WBOSubstrateObserver(readEventCount: { stub.value })
        // First call must return 0 even though the underlying count is 42.
        // This is the priming contract: we never report a "huge delta"
        // just because the process attached to a long-running ledger.
        let first = observer.sampleAndAdvance()
        #expect(first == 0,
            "WBO first call must prime the baseline and return 0, got \(first)")
        // No external change between calls → delta 0 → still 0.
        let second = observer.sampleAndAdvance()
        #expect(second == 0,
            "Second sample with no event activity must remain 0, got \(second)")
    }

    @Test("WBO observer: per-turn delta of N events yields WBO ≈ N/8")
    func wboObserverDeltaScalesByEightEvents() {
        // Variable-driven stub lets us advance the simulated event count
        // between samples just as the live ledger would.
        let stub = WBOStubCounter(initial: 100)
        let observer = WBOSubstrateObserver(readEventCount: { stub.value })

        // Prime.
        _ = observer.sampleAndAdvance()
        #expect(stub.value == 100)

        // 4 events fire → delta 4, WBO ≈ 4/8 = 0.5.
        stub.value = 104
        let half = observer.sampleAndAdvance()
        #expect(abs(half - 0.5) < 1e-6,
            "WBO with 4-event delta must be 0.5, got \(half)")

        // 0 events fire → delta 0, WBO = 0.
        let zero = observer.sampleAndAdvance()
        #expect(zero == 0,
            "WBO with no new events must be 0, got \(zero)")

        // 8 events fire → delta 8, WBO = 1.0 (saturation).
        stub.value = 112
        let saturated = observer.sampleAndAdvance()
        #expect(abs(saturated - 1.0) < 1e-6,
            "WBO with 8-event delta must saturate at 1.0, got \(saturated)")

        // 100 events fire → delta 100, WBO clamped at 1.0.
        stub.value = 212
        let clamped = observer.sampleAndAdvance()
        #expect(clamped == 1.0,
            "WBO with 100-event delta must clamp to 1.0, got \(clamped)")
    }

    @Test("WBO observer: ledger going backwards reads as zero delta")
    func wboObserverGuardAgainstBackwardsLedger() {
        // Defensive: if the underlying ledger ever resets (e.g. test
        // teardown, integrity rebuild) the observer must read 0, not a
        // huge negative cast.
        let stub = WBOStubCounter(initial: 50)
        let observer = WBOSubstrateObserver(readEventCount: { stub.value })

        // Prime at 50.
        _ = observer.sampleAndAdvance()
        // Ledger "resets" to 10.
        stub.value = 10
        let postReset = observer.sampleAndAdvance()
        #expect(postReset == 0,
            "Backwards ledger must read as 0 WBO (not a negative cast or huge delta), got \(postReset)")

        // From 10, advance to 18 → delta 8 → WBO 1.0.
        stub.value = 18
        let recovered = observer.sampleAndAdvance()
        #expect(abs(recovered - 1.0) < 1e-6,
            "After backwards-ledger handling, WBO must resume measuring delta from new baseline; got \(recovered)")
    }

    @Test("WBO scale constant matches doctrine value")
    func wboScaleConstantMatchesDoctrine() {
        // 8 events saturates WBO at 1.0 — see V6.2 §1.4 substrate-hook
        // commentary. A future calibration may move this; the test
        // breaks to force a doctrine update.
        #expect(WBOSubstrateObserver.scaleEvents == 8.0)
    }

    @Test("WBO observer: resetForTesting re-primes baseline")
    func wboObserverResetForTestingReprimesBaseline() {
        let stub = WBOStubCounter(initial: 200)
        let observer = WBOSubstrateObserver(readEventCount: { stub.value })
        _ = observer.sampleAndAdvance()  // prime at 200
        stub.value = 204
        let nonZero = observer.sampleAndAdvance()
        #expect(nonZero > 0)

        observer.resetForTesting()
        stub.value = 1_000  // huge jump, but the next call re-primes
        let zeroAgain = observer.sampleAndAdvance()
        #expect(zeroAgain == 0,
            "resetForTesting() must clear the baseline so the next call re-primes and returns 0; got \(zeroAgain)")
    }

    // MARK: - V6.2 §1.4 sheafResidual substrate hook (2026-05-12)

    @Test("Sheaf residual: empty DAG yields zero residual")
    func sheafResidualEmptyDagYieldsZero() {
        // No nodes → no incoherence to measure. Returns 0 (V6.2 §1.4
        // "no signal yet" sentinel).
        let observer = SheafResidualSubstrateObserver(readStats: {
            RustCognitiveDagStats(
                nodeCount: 0,
                edgeCount: 0,
                contradictsEdgeCount: 0,
                merkleRootHex: String(repeating: "0", count: 64),
                schemaVersion: 1
            )
        })
        #expect(observer.sample() == 0,
            "empty DAG must report 0 sheafResidual")
    }

    @Test("Sheaf residual: contradicts/node = 0.5 saturates at 1.0")
    func sheafResidualSaturatesAtHalfNodeCount() {
        // SaturationRatio = 0.5 — once contradicts edges reach half the
        // node count, the residual reads 1.0 (clearly incoherent).
        let observer = SheafResidualSubstrateObserver(readStats: {
            RustCognitiveDagStats(
                nodeCount: 100,
                edgeCount: 200,
                contradictsEdgeCount: 50,
                merkleRootHex: String(repeating: "a", count: 64),
                schemaVersion: 1
            )
        })
        let residual = observer.sample()
        #expect(abs(residual - 1.0) < 1e-6,
            "contradicts/node = 0.5 must saturate sheafResidual at 1.0, got \(residual)")
    }

    @Test("Sheaf residual: contradicts/node = 0.25 yields ~0.5")
    func sheafResidualLinearMidpoint() {
        // 25 contradicts / 100 nodes = 0.25 ratio.
        // 0.25 / saturationRatio (0.5) = 0.5.
        let observer = SheafResidualSubstrateObserver(readStats: {
            RustCognitiveDagStats(
                nodeCount: 100,
                edgeCount: 200,
                contradictsEdgeCount: 25,
                merkleRootHex: String(repeating: "a", count: 64),
                schemaVersion: 1
            )
        })
        let residual = observer.sample()
        #expect(abs(residual - 0.5) < 1e-6,
            "contradicts/node = 0.25 must yield sheafResidual ≈ 0.5, got \(residual)")
    }

    @Test("Sheaf residual: contradicts above half-node count clamps to 1.0")
    func sheafResidualClampsAboveSaturation() {
        // Pathological case: every node is in a contradiction.
        // ratio = 2.0; normalized = 4.0; must clamp to 1.0.
        let observer = SheafResidualSubstrateObserver(readStats: {
            RustCognitiveDagStats(
                nodeCount: 10,
                edgeCount: 100,
                contradictsEdgeCount: 20,
                merkleRootHex: String(repeating: "a", count: 64),
                schemaVersion: 1
            )
        })
        #expect(observer.sample() == 1.0,
            "overflow contradicts must clamp sheafResidual to 1.0")
    }

    @Test("Sheaf residual: zero contradicts on a populated graph yields 0")
    func sheafResidualNoContradictsYieldsZero() {
        // A coherent claim graph: many nodes, many edges, but zero
        // Contradicts edges. sheafResidual must read 0 (no incoherence).
        let observer = SheafResidualSubstrateObserver(readStats: {
            RustCognitiveDagStats(
                nodeCount: 100,
                edgeCount: 500,
                contradictsEdgeCount: 0,
                merkleRootHex: String(repeating: "a", count: 64),
                schemaVersion: 1
            )
        })
        #expect(observer.sample() == 0,
            "no contradicts → zero residual on a populated graph")
    }

    @Test("Sheaf residual: saturation constant matches doctrine value")
    func sheafResidualSaturationConstantMatchesDoctrine() {
        // 0.5 = "half of all nodes participate in a contradiction edge"
        // saturates sheafResidual at 1.0. Doctrine pin; if a future
        // calibration moves this, the test breaks to force a doctrine
        // update.
        #expect(SheafResidualSubstrateObserver.saturationRatio == 0.5)
    }

    @Test("Sheaf residual: stateless — same input produces same output across calls")
    func sheafResidualStateless() {
        // Unlike WBO, sheafResidual is stateless. Calling it N times
        // against the same stats must produce N identical values.
        let stub = WBOStubCounter(initial: 0)  // unused; just to make a unique closure-capture
        _ = stub
        let observer = SheafResidualSubstrateObserver(readStats: {
            RustCognitiveDagStats(
                nodeCount: 40,
                edgeCount: 80,
                contradictsEdgeCount: 8,
                merkleRootHex: String(repeating: "c", count: 64),
                schemaVersion: 1
            )
        })
        let r1 = observer.sample()
        let r2 = observer.sample()
        let r3 = observer.sample()
        #expect(r1 == r2 && r2 == r3,
            "stateless observer must produce identical output across repeated calls; got \(r1), \(r2), \(r3)")
        // 8 / 40 = 0.2 ratio; / 0.5 saturation = 0.4 normalized.
        #expect(abs(r1 - 0.4) < 1e-6,
            "8 contradicts / 40 nodes must yield sheafResidual = 0.4, got \(r1)")
    }

    @Test("RustCognitiveDagStats decodes contradicts_edge_count when present")
    func dagStatsDecodesContradictsField() throws {
        // Forward-compat JSON with the new field present.
        let json = #"{"node_count":10,"edge_count":20,"contradicts_edge_count":3,"merkle_root_hex":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","schema_version":1}"#
        let stats = try JSONDecoder().decode(
            RustCognitiveDagStats.self,
            from: Data(json.utf8)
        )
        #expect(stats.contradictsEdgeCount == 3)
        #expect(stats.nodeCount == 10)
    }

    @Test("RustCognitiveDagStats decodes legacy JSON without contradicts_edge_count")
    func dagStatsLegacyDecodesAsZeroContradicts() throws {
        // Backward-compat: pre-2026-05-12 JSON had no contradicts_edge_count.
        // decodeIfPresent must default it to 0 so the bridge stays usable
        // across a phased Rust ↔ Swift rollout.
        let json = #"{"node_count":10,"edge_count":20,"merkle_root_hex":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","schema_version":1}"#
        let stats = try JSONDecoder().decode(
            RustCognitiveDagStats.self,
            from: Data(json.utf8)
        )
        #expect(stats.contradictsEdgeCount == 0,
            "legacy JSON without contradicts_edge_count must decode as 0")
        #expect(stats.nodeCount == 10)
    }

    @Test("sampleTurnBucket: integration path does not crash with WBO observer wired")
    func sampleTurnBucketIntegrationDoesNotRegress() {
        // Smoke test that the .shared observer path runs end-to-end
        // and produces a real bucket. The exact bucket depends on the
        // live Rust ledger state; we only assert the return is non-nil
        // and one of the four valid wire values. Existing per-bucket
        // assertions are above.
        WBOSubstrateObserver.shared.resetForTesting()
        let bucket = InterruptScoreCpu.sampleTurnBucket(
            stopReason: "end_turn",
            inputTokens: 100,
            outputTokens: 120
        )
        let valid: Set<InterruptBucket> = [.low, .medium, .high, .unavailable]
        #expect(valid.contains(bucket),
            "sampleTurnBucket must return one of {low, medium, high, unavailable}; got \(bucket)")
    }
}

/// Tiny mutable counter used as a controlled stand-in for the live Rust
/// ledger event count in the WBO observer tests. Lives in test scope only.
///
/// `nonisolated final class … @unchecked Sendable` so the @Sendable
/// closure passed to `WBOSubstrateObserver.init(readEventCount:)` can
/// read `value` without tripping the module-default-MainActor isolation
/// rule. The tests mutate `value` from the test scope only, never
/// concurrently — `@unchecked Sendable` reflects the cooperative single-
/// writer contract.
nonisolated private final class WBOStubCounter: @unchecked Sendable {
    var value: UInt64
    init(initial: UInt64) {
        self.value = initial
    }
}
