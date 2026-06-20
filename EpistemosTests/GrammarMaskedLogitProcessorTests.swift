import Testing
import Foundation
@testable import Epistemos

#if canImport(MLXLMCommon)
/// SS-Y slice 5b — the grammar-masking `LogitProcessor`'s masking logic, witnessed
/// via the pure host-independent `maskedLogits` helper (the same logic `process`
/// applies to the MLX logits). Proves it MASKS invalid tokens when ON and is a
/// strict NO-OP when OFF. (Which tokens are allowed is cargo-witnessed in the Rust
/// `grammar::` tests; this witnesses the logit masking.)
@Suite("SS-Y grammar-masked LogitProcessor (slice 5b)")
struct GrammarMaskedLogitProcessorTests {

    @Test("masks disallowed token logits to -inf when ON, keeps the allowed ones")
    func masksWhenEnabled() {
        let logits: [Float] = [10, 20, 30, 40]
        // allowed {0, 2} -> keep logits[0]/logits[2]; tokens 1 and 3 are masked out.
        let masked = RustGrammarMaskedLogitProcessor.maskedLogits(
            logits, allowedTokenIDs: [0, 2], enabled: true
        )
        #expect(masked[0] == 10)
        #expect(masked[2] == 30)
        #expect(masked[1] == -Float.greatestFiniteMagnitude)
        #expect(masked[3] == -Float.greatestFiniteMagnitude)
    }

    @Test("is a strict no-op when OFF — logits unchanged (existing path preserved)")
    func noOpWhenDisabled() {
        let logits: [Float] = [10, 20, 30, 40]
        let out = RustGrammarMaskedLogitProcessor.maskedLogits(
            logits, allowedTokenIDs: [0, 2], enabled: false
        )
        #expect(out == logits)
    }

    @Test("an empty allowed-set leaves logits unchanged (no corruption on matcher error)")
    func noOpWhenNoConstraint() {
        let logits: [Float] = [10, 20, 30, 40]
        let out = RustGrammarMaskedLogitProcessor.maskedLogits(
            logits, allowedTokenIDs: [], enabled: true
        )
        #expect(out == logits)
    }

    @Test("the grammar-masking flag is default-OFF (existing path unchanged by default)")
    func flagDefaultsOff() {
        // EPISTEMOS_GRAMMAR_MASK_V0 is unset in the test environment → masking OFF.
        #expect(RustGrammarMaskedLogitProcessor.flagEnabled == false)
    }
}
#endif
