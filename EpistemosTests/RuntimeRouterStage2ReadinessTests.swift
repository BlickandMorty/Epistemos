import Testing
import Foundation

@testable import Epistemos

// SUBSTRATE STAGE-2 (owner 2026-06-21: "STAGE-2 LIVE flip if parityRate is solid"). The
// authoritative-lane flip already exists (RuntimeRouterShadow.authoritativeLane, behind
// EPISTEMOS_RUNTIMEROUTER_LIVE_V0); this gate operationalizes "solid" so the flip is a rigorous,
// observable decision rather than an eyeballed percentage. Pure → headless-testable; the live
// parity metrics that feed it accumulate only while STAGE-1b is armed.
@Suite("SUBSTRATE STAGE-2 — promotion readiness gate")
struct RuntimeRouterStage2ReadinessTests {

    @Test("no parity observed → not ready (must arm STAGE-1b first)")
    func noParity() {
        let verdict = RuntimeRouterStage2Readiness.evaluate(parityObservations: 0, parityRate: nil)
        #expect(!verdict.isReady)
        if case .notReady(let reason) = verdict { #expect(reason.contains("no parity observed")) }
    }

    @Test("too few samples → not ready even at 100% rate")
    func tooFewSamples() {
        let verdict = RuntimeRouterStage2Readiness.evaluate(parityObservations: 10, parityRate: 1.0)
        #expect(!verdict.isReady)
        if case .notReady(let reason) = verdict { #expect(reason.contains("samples")) }
    }

    @Test("enough samples but low parity → not ready (router still diverges)")
    func lowParity() {
        let verdict = RuntimeRouterStage2Readiness.evaluate(parityObservations: 100, parityRate: 0.90)
        #expect(!verdict.isReady)
        if case .notReady(let reason) = verdict { #expect(reason.contains("diverges")) }
    }

    @Test("enough samples + solid parity → ready to promote")
    func ready() {
        #expect(RuntimeRouterStage2Readiness.evaluate(parityObservations: 100, parityRate: 0.99).isReady)
    }

    @Test("the boundary: exactly at the sample + rate floors is ready; just under is not")
    func boundary() {
        #expect(RuntimeRouterStage2Readiness.isReady(parityObservations: 50, parityRate: 0.98))
        #expect(!RuntimeRouterStage2Readiness.isReady(parityObservations: 49, parityRate: 1.0))
        #expect(!RuntimeRouterStage2Readiness.isReady(parityObservations: 100, parityRate: 0.979))
    }

    @Test("the health row surfaces the readiness verdict (precise green-light, not a guess)")
    func healthRowWiring() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/RuntimeRouterHealthRow.swift")
        #expect(src.contains("RuntimeRouterStage2Readiness"))
        #expect(src.contains("stage2ReadinessRow"))
    }
}
