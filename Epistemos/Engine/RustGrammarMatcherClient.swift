import Foundation

// MARK: - RustGrammarMatcherClient
//
// SS-Y slice 5a — Swift consumer for the agent_core grammar masking matcher FFI
// (`agent_core/src/grammar/ffi.rs`). Mirrors the proven RopeFFIClient /
// RustShadowFFIClient `@_silgen_name` direct-binding pattern: a `nonisolated`
// final class owns exactly one `Arc<GrammarMatcherHandle>` strong reference,
// released in `deinit`.
//
// The grammar matcher hard-constrains tool-call generation: `allowedTokenIDs()`
// returns the grammar-valid next tokens (the MLX `LogitProcessor` keeps those and
// masks every other logit to -inf), and `consume(_:)` feeds the sampled token back.
//
// This is the FFI seam ONLY — the masking `LogitProcessor` that uses it lands behind
// a default-OFF flag in slice 5b, so nothing here changes the generation path.
//
// ## Why no UniFFI
//
// agent_core uses raw `extern "C"` exports for handle types (rope_handle.rs,
// epistemos-shadow, …), not `#[derive(uniffi::Object)]`. This stays in lane:
// `@_silgen_name` direct binding. The Rust side is refcounted + `Mutex`-guarded, so
// the calls are thread-safe; Swift holds one strong reference.
//
// ## Linkage
//
// agent_core is linked into the app target unconditionally (it's the agent runtime);
// the `grammar_matcher_*` symbols resolve like the other `*_handle_*` exports. A
// build without them would fail loudly with "undefined symbol _grammar_matcher_new".

@_silgen_name("grammar_matcher_new")
nonisolated func grammar_matcher_new(
    _ tokenizerJSON: UnsafePointer<CChar>?,
    _ toolsJSON: UnsafePointer<CChar>?,
    _ eosTokenID: UInt32
) -> UnsafeRawPointer?

@_silgen_name("grammar_matcher_retain")
nonisolated func grammar_matcher_retain(_ handle: UnsafeRawPointer)

@_silgen_name("grammar_matcher_release")
nonisolated func grammar_matcher_release(_ handle: UnsafeRawPointer)

@_silgen_name("grammar_matcher_compute_mask")
nonisolated func grammar_matcher_compute_mask(
    _ handle: UnsafeRawPointer,
    _ outIDs: UnsafeMutablePointer<UnsafeMutablePointer<UInt32>?>
) -> Int

@_silgen_name("grammar_matcher_free_mask")
nonisolated func grammar_matcher_free_mask(_ ids: UnsafeMutablePointer<UInt32>?, _ len: Int)

@_silgen_name("grammar_matcher_consume_token")
nonisolated func grammar_matcher_consume_token(_ handle: UnsafeRawPointer, _ token: UInt32) -> Bool

/// Swift wrapper around an Arc-refcounted grammar `Matcher` handle from agent_core.
/// Owns one strong reference; releases it in `deinit`.
nonisolated final class RustGrammarMatcher: @unchecked Sendable {

    /// Opaque pointer to the Rust `GrammarMatcherHandle`. Never dereferenced from
    /// Swift — passed back into FFI calls as-is.
    private let handle: UnsafeRawPointer

    /// Build a tool-dispatch grammar matcher over a model's tokenizer.
    ///
    /// - `tokenizerJSON`: the model's `tokenizer.json` content (the matcher masks
    ///   over the model's own tokens).
    /// - `toolsJSON`: a JSON array `[{"name": String, "schema": Object}, ...]` of the
    ///   available tools' input schemas.
    /// - `eosTokenID`: the model's end-of-sequence token id.
    ///
    /// Returns nil if the tokenizer/tools fail to parse or the grammar fails to build.
    init?(tokenizerJSON: String, toolsJSON: String, eosTokenID: UInt32) {
        let opt: UnsafeRawPointer? = tokenizerJSON.withCString { tj in
            toolsJSON.withCString { tl in
                grammar_matcher_new(tj, tl, eosTokenID)
            }
        }
        guard let raw = opt else { return nil }
        self.handle = raw
    }

    deinit {
        grammar_matcher_release(handle)
    }

    /// The grammar-valid next token ids at the current step. The `LogitProcessor`
    /// keeps these and masks all other logits to -inf, so only a grammar-valid token
    /// can be sampled. Empty if the matcher is in an error state.
    func allowedTokenIDs() -> [UInt32] {
        var ids: UnsafeMutablePointer<UInt32>? = nil
        let count = grammar_matcher_compute_mask(handle, &ids)
        guard let p = ids, count > 0 else { return [] }
        defer { grammar_matcher_free_mask(p, count) }
        return Array(UnsafeBufferPointer(start: p, count: count))
    }

    /// Feed the sampled token back to the matcher, advancing its state. Returns true
    /// if the token was grammar-valid (it always is when sampled from a masked
    /// distribution); false signals an invalid token or a matcher error.
    @discardableResult
    func consume(_ token: UInt32) -> Bool {
        grammar_matcher_consume_token(handle, token)
    }
}
