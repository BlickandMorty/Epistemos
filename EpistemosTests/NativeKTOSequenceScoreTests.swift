import Testing
import Foundation

@testable import Epistemos

// SS-LS 1b brick 4 — the pure sequence-scoring core of the native KTO loop,
// unit-witnessed without a model. KTOTrainer's Python path is untouched by this brick.
@Suite("Native KTO sequence score (SS-LS 1b)")
struct NativeKTOSequenceScoreTests {

    @Test("sequence log-prob sums per-token log-probs over the completion mask only")
    func sequenceLogProbSumsCompletion() {
        // prompt = positions 0,1 (excluded); completion = 2,3.
        #expect(
            NativeKTOSequenceScore.sequenceLogProb(
                perTokenLogProbs: [-1, -2, -3, -4], completionMask: [false, false, true, true]
            ) == -7
        )
        // all masked out → 0; mismatched lengths → 0.
        #expect(NativeKTOSequenceScore.sequenceLogProb(perTokenLogProbs: [-1, -2], completionMask: [false, false]) == 0)
        #expect(NativeKTOSequenceScore.sequenceLogProb(perTokenLogProbs: [-1, -2, -3], completionMask: [true]) == 0)
    }

    @Test("log-ratio is policy minus reference")
    func logRatioSubtracts() {
        #expect(NativeKTOSequenceScore.logRatio(policyLogProb: -5, referenceLogProb: -8) == 3)
        #expect(NativeKTOSequenceScore.logRatio(policyLogProb: -8, referenceLogProb: -5) == -3)
    }

    @Test("completion mask excludes the prompt tokens, includes the completion")
    func completionMaskShape() {
        #expect(NativeKTOSequenceScore.completionMask(promptTokenCount: 2, totalTokenCount: 5)
            == [false, false, true, true, true])
        // no prompt ⇒ all completion; prompt >= total ⇒ all prompt; empty ⇒ [].
        #expect(NativeKTOSequenceScore.completionMask(promptTokenCount: 0, totalTokenCount: 3)
            == [true, true, true])
        #expect(NativeKTOSequenceScore.completionMask(promptTokenCount: 9, totalTokenCount: 3)
            == [false, false, false])
        #expect(NativeKTOSequenceScore.completionMask(promptTokenCount: 1, totalTokenCount: 0).isEmpty)
    }
}
