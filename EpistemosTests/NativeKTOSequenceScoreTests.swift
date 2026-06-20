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

    @Test("next-token tensors shift inputs/targets and mask only the completion targets")
    func nextTokenTraining() {
        // fullIds = [p0,p1, c0,c1], prompt length 2.
        let (inputs, targets, mask) = NativeKTOSequenceScore.nextTokenTraining(
            promptTokenCount: 2, fullIds: [10, 11, 20, 21]
        )
        #expect(inputs == [10, 11, 20])   // fullIds[0..<3]
        #expect(targets == [11, 20, 21])  // fullIds[1..<4]
        // target 0 (=11, prompt) not scored; targets 1,2 (=20,21, completion) scored.
        #expect(mask == [false, true, true])

        // No prompt ⇒ every target is completion.
        let (i2, t2, m2) = NativeKTOSequenceScore.nextTokenTraining(promptTokenCount: 0, fullIds: [5, 6])
        #expect(i2 == [5]); #expect(t2 == [6]); #expect(m2 == [true])

        // < 2 tokens ⇒ nothing to predict.
        let (i3, t3, m3) = NativeKTOSequenceScore.nextTokenTraining(promptTokenCount: 1, fullIds: [7])
        #expect(i3.isEmpty); #expect(t3.isEmpty); #expect(m3.isEmpty)
    }
}
