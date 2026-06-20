# SS-Y — Masked Logit Processor: Status (2026-06-20)

Real grammar-constrained decoding for local tool calls: mask invalid tokens so a
local model can only emit grammar-valid tool-call JSON ("guaranteed-valid local tool
calls > cloud"). Built on the vendored **llguidance 1.7.5** engine (already an
`agent_core` dependency).

## Slice ledger (each gated + committed)

| Slice | Commit | What | Witness |
|---|---|---|---|
| 1 | `92fdc0dbc` | masking core — `grammar::tool_dispatch_matcher` | cargo `--lib` |
| 2 | `322707ef4` | step API — `allowed_token_ids` + streaming mask→consume | cargo `--lib` |
| 3 | `58f698a9b` | real multi-byte tokenizer — `tool_dispatch_matcher_with_vocab` | cargo `--lib` |
| 4 | `ddb53bbff` + `d1d8e604b` | FFI seam — `grammar/ffi.rs` (`grammar_matcher_*`, out-param ABI) | cargo `--lib` |
| 5a | `2274a2452` | Swift bindings — `RustGrammarMatcher` (`@_silgen_name`) | compile + link |
| 5b | `8c0cf870b` | masking `LogitProcessor` + default-OFF flag + masks-ON/no-op-OFF test | compile + pure `maskedLogits` + Rust mirror |
| 5c | _this_ | flag-gated `generate()` wiring + selection test | compile + gating test |

All behind **`EPISTEMOS_GRAMMAR_MASK_V0`** (default-OFF) and
`MLXConstrainedGenerator.isFullyConstraining` stays **`false`** → the live generation
path is byte-for-byte unchanged.

## ⚠️ PENDING OWNER VERIFICATION — the live end-to-end witness

**Not yet verified, do NOT claim it works:** that with the flag ON, a real local
model + the masking `LogitProcessor` actually emits grammar-valid tool calls the
pipeline can parse. This needs a real model generating (the app-hosted Swift test
bundle crash-loops headless; runtime is Xcode / the running app). To verify: set
`EPISTEMOS_GRAMMAR_MASK_V0=1`, run a local-model tool-calling generation, confirm the
output is grammar-valid and parses.

**Known open item surfaced during 5c — tool-call FORMAT alignment.** The matcher
constrains to `{"name": <tool>, "input": <schema>}` (the SS-Y dispatch grammar), but
the Swift `MLXConstrainedGenerator` pipeline's `CompiledGrammar` uses a *different*
format (`{"type","tool","arguments"}` single / `[{"description","agent","tool",
"arguments","risk"}]` planning), and the pre-existing `JSONSchemaLogitProcessor` never
enforced any format (soft-EOS only). So when the flag is ON the masking will currently
constrain to the matcher's format, which may not match the pipeline parser. Aligning
the grammar to the consumer's format (or pointing SS-Y at the `LocalAgentLoop`
`<tool_call>{"name","arguments"}` path) is the next decision before the flag flips on
for real. Until then `generate()` falls back to soft-guidance whenever a matcher can't
be built (honest — no fake masking).

## Next

1. Owner decides the canonical tool-call format SS-Y should enforce + the target path.
2. Align the Rust grammar to that format (cargo-witnessed) + the Swift `tools_json`.
3. Live witness (flag ON, real model) → only then flip `isFullyConstraining = true`.
