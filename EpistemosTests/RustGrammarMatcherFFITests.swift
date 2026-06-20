import Testing
import Foundation
@testable import Epistemos

/// SS-Y slice 5a — the Swift `@_silgen_name` bindings for the agent_core grammar
/// masking matcher (`agent_core/src/grammar/ffi.rs`) round-trip correctly. The
/// masking engine itself is witnessed in Rust (the `grammar::` cargo tests); these
/// prove the cross-language seam: build → compute_mask → consume → free → release,
/// and a real masking decision through the FFI. No generation-path touch.
@Suite("SS-Y grammar matcher FFI (slice 5a)")
struct RustGrammarMatcherFFITests {

    @Test("the grammar matcher FFI round-trips from Swift and masks correctly")
    func grammarMatcherFFIRoundTripsAndMasks() throws {
        // A 1-char ByteLevel vocab ('{' -> token 0, '<eos>' -> token 1) is enough to
        // witness the seam + a real masking decision: at the start of a tool-call
        // object only '{' is grammar-valid; once consumed, another '{' is masked out
        // (the grammar then expects a key string).
        let tokenizerJSON =
            #"{"added_tokens":[{"id":1,"content":"<eos>","special":true}],"decoder":{"type":"ByteLevel"},"model":{"vocab":{"{":0}}}"#
        let toolsJSON = #"[{"name":"x","schema":{"type":"object"}}]"#

        let matcher = try #require(
            RustGrammarMatcher(tokenizerJSON: tokenizerJSON, toolsJSON: toolsJSON, eosTokenID: 1),
            "grammar_matcher_new must build a handle from a valid tokenizer.json"
        )

        // The mask round-trips through the FFI: '{' (token 0) is allowed at the start.
        let atStart = matcher.allowedTokenIDs()
        #expect(atStart.contains(0), "'{' must be grammar-valid at the start of a tool call")

        // Consume advances the matcher; '{' is accepted, then the mask changes — a
        // second '{' is masked out (the grammar now expects a key string).
        #expect(matcher.consume(0), "consuming '{' must be accepted")
        let afterBrace = matcher.allowedTokenIDs()
        #expect(!afterBrace.contains(0), "after '{', another '{' must be masked out")
    }

    @Test("a malformed tokenizer.json returns nil, not a crash")
    func grammarMatcherRejectsBadTokenizerJSON() {
        let matcher = RustGrammarMatcher(
            tokenizerJSON: "not json at all",
            toolsJSON: #"[{"name":"x","schema":{"type":"object"}}]"#,
            eosTokenID: 0
        )
        #expect(matcher == nil, "an invalid tokenizer.json must return nil, not crash")
    }
}
