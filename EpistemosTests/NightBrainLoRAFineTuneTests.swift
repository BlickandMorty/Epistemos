import Testing
import Foundation
@testable import Epistemos

/// DATA + FINETUNE part (4) — locks the honest, owner-controllable gate + decision
/// for Night Brain's native idle LoRA fine-tune: OFF by default, Pro + idle + AC +
/// a real data delta + a cadence cap, with the first failing gate surfaced as the
/// reason (so the Night Brain log can always say WHY it didn't train).
@Suite("Night Brain LoRA fine-tune gate")
struct NightBrainLoRAFineTuneTests {

    @Test("flag truth table + honest status")
    func gateStatus() {
        for on in ["1", "true", "On", " yes "] { #expect(NightBrainLoRAGateStatus.isEnabled(on)) }
        for off in ["0", "false", "", nil] { #expect(!NightBrainLoRAGateStatus.isEnabled(off)) }
        let active = NightBrainLoRAGateStatus.status(environment: [NightBrainLoRAGateStatus.flagName: "1"])
        #expect(active.isActive)
        #expect(active.headline.contains("ON"))
        let off = NightBrainLoRAGateStatus.status(environment: [:])
        #expect(!off.isActive)
        #expect(off.detail.contains(NightBrainLoRAGateStatus.flagName))
    }

    private func base(
        enabled: Bool = true, isPro: Bool = true, isIdle: Bool = true, onAC: Bool = true,
        newExamples: Int = 100, lastDays: Int? = nil
    ) -> NightBrainLoRAFineTuneDecision.Inputs {
        .init(
            enabled: enabled, isPro: isPro, isIdle: isIdle, onACPower: onAC,
            newExampleCount: newExamples, minNewExamples: 50,
            daysSinceLastFineTune: lastDays, minDaysBetween: 7
        )
    }

    @Test("all gates pass → run")
    func runsWhenEligible() {
        #expect(NightBrainLoRAFineTuneDecision.evaluate(base()) == .run)
        // Never fine-tuned + plenty of new data → runs.
        #expect(NightBrainLoRAFineTuneDecision.evaluate(base(lastDays: nil)) == .run)
        // Past the cadence cap → runs.
        #expect(NightBrainLoRAFineTuneDecision.evaluate(base(lastDays: 30)) == .run)
    }

    @Test("each gate fails to its own honest reason, in order")
    func gatesSkipWithReasons() {
        func reason(_ i: NightBrainLoRAFineTuneDecision.Inputs) -> String {
            if case let .skip(r) = NightBrainLoRAFineTuneDecision.evaluate(i) { return r }
            return "RAN"
        }
        #expect(reason(base(enabled: false)).contains("off"))
        #expect(reason(base(isPro: false)).contains("Pro"))
        #expect(reason(base(isIdle: false)).contains("idle"))
        #expect(reason(base(onAC: false)).contains("AC power"))
        #expect(reason(base(newExamples: 10)).contains("new vault examples"))
        #expect(reason(base(lastDays: 2)).contains("min 7d"))
    }

    @Test("gate order: flag is checked before everything (off wins even if all else fails)")
    func flagCheckedFirst() {
        let allBad = NightBrainLoRAFineTuneDecision.Inputs(
            enabled: false, isPro: false, isIdle: false, onACPower: false,
            newExampleCount: 0, minNewExamples: 50, daysSinceLastFineTune: 0, minDaysBetween: 7
        )
        guard case let .skip(r) = NightBrainLoRAFineTuneDecision.evaluate(allBad) else {
            Issue.record("expected skip")
            return
        }
        #expect(r.contains(NightBrainLoRAGateStatus.flagName))  // flag reason wins
    }

    @Test("NightBrainService wires the LoRA fine-tune as a soft, flag-gated, injected job")
    func nightBrainWiresLoRAJob() throws {
        let svc = try loadMirroredSourceTextFile("Epistemos/State/NightBrainService.swift")
        // The Job case exists (runs in the idle pipeline via Job.allCases).
        #expect(svc.contains(#"case nativeKnowledgeAdapterFineTune = "native_knowledge_adapter_fine_tune""#))
        // An OPTIONAL injected provider (like cloudKnowledgeJob) → soft, not a hard
        // dependency, so missingDependency never blocks the pipeline on it.
        #expect(svc.contains("private let loraFineTuneJob: (@Sendable () async throws -> Void)?"))
        #expect(svc.contains("loraFineTuneJob: (@Sendable () async throws -> Void)? = nil"))
        // Flag-gated soft-skip: returns (never throws) when off or unwired.
        #expect(svc.contains("guard NightBrainLoRAGateStatus.status().isActive, let loraFineTuneJob else {"))
        #expect(svc.contains("try await loraFineTuneJob()"))
    }
}
