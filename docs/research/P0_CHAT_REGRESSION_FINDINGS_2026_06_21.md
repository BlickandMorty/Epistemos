# P0 LIVE-CHAT REGRESSION — findings + classification (2026-06-21)

Two symptoms (flag `EPISTEMOS_ACT_OSAURUS_V0` OFF): (A) every query → "I can't assist with that request";
(B) chat TITLE leaks raw `<think>` + the title-gen meta-prompt (VibeThinker 3B Reasoning GGUF).

## Classification (per the owner's shared-vs-chat-only directive cb4f63347)

### (B) `<think>` LEAK → SHARED inference-output layer → FIXED (`c9184b4e6`)
`String.strippingThinkingBlocks()` (Engine/Extensions.swift — the stripper behind `UserFacingModelOutput`,
used by ACT + Note chat + Graph chat + title-gen) handled CLOSED `<think>…</think>` + orphan closing tags,
but left an **UNCLOSED** opening `<think>` (a reasoning model cut off mid-think by the token budget) UNTOUCHED
→ raw reasoning leaked. **Fixed:** strip from an unclosed opening reasoning tag to the end (keep pre-think
text); model-agnostic. Regression test added (43/43). Shared → every surface benefits.
- The main-chat `ChatCoordinator.generateChatTitle` (maxTokens:30, no stripper) is on the DELETION path →
  deliberately NOT polished (owner: don't polish the dying chat surface). It will inherit the shared stripper
  only if it routes through it; the kept surfaces (note/graph chat, act) get the fix via the shared layer.

### (A) ANSWER REFUSAL → SHARED, but needs RUNTIME bisection (NOT act-injection)
- The exact string "I can't assist with that request" is **NOT** hardcoded anywhere — it is the **model's
  actual output**; the app only DETECTS it (`TriageService.isRefusalResponse`, line 1056).
- My act-routing injection is **flag-off-byte-identical** (verified): `SharedActInference.actStreamIfArmed/
  actTextIfArmed` return nil when not armed → the original MLX path runs unchanged. NOT the cause.
- The local baseline system prompts (`localMLXBaselineSystemPrompt` etc.) are reasonable — not refusal-inducing.
- ⇒ All local models genuinely refusing every query points to **GGUF generation / chat-template / stop-handling**,
  the OWNER'S PRIME SUSPECT: the **dual-MLX→vmlx consolidation `f884eb0b7`**. This needs a RUNTIME bisect —
  load a local model, send a query, compare raw output before/after `f884eb0b7` — which can't be done in the
  headless test harness (no loaded model). RECOMMENDED: run the model on the dev machine with
  `git stash` / checkout `f884eb0b7^` and diff the raw generation (chat template, stop sequences, tokenizer)
  against current `vmlx`. Likely culprits: stop-sequence handling, the GGUF chat template, or `/no_think`
  interaction with reasoning models.

### BISECT result (f884eb0b7 Swift diff examined)
The ONLY substantive generation-path Swift changes in f884eb0b7 (the rest is the vendored mlx-c C++):
1. **Tokenizer loader → vmlx `#huggingFaceTokenizerLoader()`** on `LLMModelFactory/VLMModelFactory.loadContainer`
   (the **MLX** path, `MLXInferenceService`). **PRIME REMAINING SUSPECT:** if this loader doesn't apply the
   model's **chat template** (jinja `tokenizer_config.json` → special tokens / role wrapping) the way
   mlx-swift-lm did implicitly, MLX models receive a MALFORMED prompt → garbage/refusal. RUNTIME CHECK: load an
   MLX model, log the fully-formatted prompt string fed to `generate()`, confirm it has the correct
   chat-template special tokens (`<start_of_turn>`, `<|im_start|>`, etc.). If missing → the loader/template
   wiring is the regression.
2. `decode(tokens:)` → `decode(tokenIds:)` — benign label rename.
3. KIVI scheme param dropped — unrelated.
NOTE on model paths: VibeThinker is **GGUF** (`LocalGGUFClient`, NOT `MLXInferenceService`) — f884eb0b7 didn't
touch the GGUF path, so the GGUF `<think>` leak (symptom B, fixed) and a possible MLX chat-template refusal
(symptom A) may be TWO distinct causes. The refusal needs the runtime prompt-string check above to pin which
path/model is failing.

## Done this pass
- (B) shared `<think>`-leak fix + regression test — committed `c9184b4e6`, 43/43.
- (A) classified + narrowed to the runtime GGUF-generation bisect (f884eb0b7); act-injection cleared.
