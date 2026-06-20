import Testing
import Foundation

@testable import Epistemos

// SS-LS 1b brick 6 — the native KTO trainer composes the verified bricks. The loop
// itself needs a live model (its convergence is PENDING OWNER VERIFICATION), so this
// is a structural witness that the native path is wired from the unit-witnessed
// pieces, with the correctness-critical reference-before-LoRA ordering.
@Suite("Native KTO trainer wiring (SS-LS 1b)")
struct NativeKTOTrainerTests {

    @Test("the trainer composes the verified bricks and computes the reference before LoRA")
    func wiresVerifiedBricks() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/KnowledgeFusion/Alignment/NativeKTOTrainer.swift"
        )
        #expect(src.contains("NativeKTOSequenceScore.nextTokenTraining"))         // brick 5
        #expect(src.contains("kto.mlxBatchLoss(logratios:"))                      // brick 3
        #expect(src.contains("crossEntropy(logits:"))                            // per-token logπ
        #expect(src.contains("valueAndGrad(model: context.model)"))               // gradient step
        #expect(src.contains("LoRATrain.saveLoRAWeights(model: context.model"))   // save adapter

        // The FROZEN reference log-probs must be taken from the base model BEFORE LoRA
        // is attached — otherwise the log-ratio collapses and KTO can't learn.
        guard
            let refIdx = src.range(of: "let refLP = seqLogProbs(baseModel)")?.lowerBound,
            let loraIdx = src.range(of: "LoRAContainer.from(model: context.model")?.lowerBound
        else {
            Issue.record("trainer missing the reference-then-LoRA ordering")
            return
        }
        #expect(refIdx < loraIdx, "the frozen reference must be computed before LoRA is attached")
    }
}
