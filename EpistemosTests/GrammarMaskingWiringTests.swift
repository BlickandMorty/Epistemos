import Testing
import Foundation
@testable import Epistemos

#if canImport(MLXLMCommon)
/// SS-Y slice 5c — the flag-gated `generate()` wiring decision, witnessed WITHOUT a
/// live model: the real grammar-masking processor is selected ONLY when the masking
/// flag is ON AND a matcher built from the model tokenizer; otherwise the existing
/// soft-guidance path (byte-for-byte unchanged). The live end-to-end behavior (a real
/// model emits grammar-valid tool calls with the flag on) is PENDING OWNER
/// VERIFICATION — see docs/research/SS-Y_MASKED_LOGIT_STATUS_2026_06_20.md.
@Suite("SS-Y generate() wiring (slice 5c)")
struct GrammarMaskingWiringTests {

    @Test("grammar masking is selected ONLY when the flag is ON and a matcher is present")
    func processorSelectionGating() {
        // OFF → soft-guidance (existing path), regardless of matcher availability.
        #expect(
            MLXConstrainedGenerator.selectProcessorKind(flagEnabled: false, matcherPresent: false)
                == .softGuidance
        )
        #expect(
            MLXConstrainedGenerator.selectProcessorKind(flagEnabled: false, matcherPresent: true)
                == .softGuidance
        )
        // ON but no matcher (couldn't build from the model) → soft-guidance fallback
        // (honest — no fake masking when a real matcher isn't constructable).
        #expect(
            MLXConstrainedGenerator.selectProcessorKind(flagEnabled: true, matcherPresent: false)
                == .softGuidance
        )
        // ON + a matcher present → real grammar masking.
        #expect(
            MLXConstrainedGenerator.selectProcessorKind(flagEnabled: true, matcherPresent: true)
                == .grammarMasked
        )
    }

    @Test("the masking flag is default-OFF, so generate() keeps the existing path")
    func flagDefaultsOff() {
        // EPISTEMOS_GRAMMAR_MASK_V0 is unset in the test environment → masking OFF →
        // no RustGrammarMaskedLogitProcessor is ever constructed by default.
        #expect(RustGrammarMaskedLogitProcessor.flagEnabled == false)
    }
}
#endif
