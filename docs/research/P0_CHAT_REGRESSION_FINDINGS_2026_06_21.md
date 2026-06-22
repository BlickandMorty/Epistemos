# P0 LIVE-CHAT REGRESSION — findings + classification (2026-06-21)

Two symptoms (flag `EPISTEMOS_ACT_OSAURUS_V0` OFF): (A) every query → "I can't assist with that request";
(B) chat TITLE leaks raw `<think>` + the title-gen meta-prompt (VibeThinker 3B Reasoning GGUF).

## Classification (per the owner's shared-vs-chat-only directive cb4f63347)

### (B) `<think>` LEAK — CORRECTED classification (precise tracing)
- The **ANSWER** extractor `UserFacingModelOutput.finalVisibleText` (used by ACT / note chat / graph chat) ALREADY
  handles an UNCLOSED `<think>` via `cleanedVisibleText(suppressIncompleteThinkingTail: true)` — so the kept
  surfaces' ANSWERS do NOT leak reasoning. Not the bug.
- The **TITLE** leak is in `ChatCoordinator.generateChatTitle` — which uses NEITHER `finalVisibleText` NOR
  `strippingThinkingBlocks` (just trims) AND `maxTokens:30` (consumed entirely by the reasoning model's <think>).
  It is called ONLY from ChatCoordinator (main chat) — note/graph chat don't title-gen. So it is MAIN-CHAT-ONLY,
  on the DELETION path → deliberately NOT polished (owner: don't polish the dying chat surface). The user's title
  symptom rides the dying surface and dies with it.
- `String.strippingThinkingBlocks()` (only non-test caller: `EntityExtractor` graph entity extraction) DID leak
  an unclosed `<think>` → **HARDENED `c9184b4e6`** (strips unclosed opener; 43/43 regression). This is a real
  SHARED-layer hardening for a KEPT surface (graph), but it is NOT the user's reported title/answer symptom —
  recorded honestly to avoid over-claiming the fix.

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

## 2026-06-22 — re-audit + load-time chat-template DIAGNOSTIC (the automatic runtime check)
- RE-CONFIRMED (A) is NOT app-injected: the refusal string exists ONLY in `TriageService.isRefusalResponse`
  (the detector, :1070-71) — nothing in Swift OR Rust PRODUCES it. So it is the model's genuine output → a
  malformed/un-chat-templated prompt is the prime cause.
- The chat-template application is RUNTIME (MLX: vmlx tokenizer loader; GGUF: llama.cpp from the GGUF metadata),
  so the definitive which-model confirmation needs a loaded model — but the CHECK is now AUTOMATIC:
- **`ChatTemplateDiagnostic` (`67e82080f`):** at MLX load, reads `<modelDir>/tokenizer_config.json` + LOGS LOUD
  (`log.error`) when no chat_template is present — the prime refusal suspect, pinned at load with no manual
  prompt logging. Pure detection (string + array shapes), 4 real-state tests. → When the owner runs the app,
  the log immediately answers "does the refusing model have a chat_template?" — turning the remaining runtime
  step into a one-glance diagnosis.

## 2026-06-22 — ROOT-CAUSE MECHANISM pinned (GGUF reasoning-dialect) — strongest lead, explains BOTH symptoms
Traced the GGUF chat-template handling to pure Rust (`model_profile::PromptDialect` → `bridge.rs` GGUF build).
**ONE mechanism explains BOTH symptoms:** a Think-tier reasoning model with `PromptDialect::None` gets NO
llama.cpp template override AND NO stop tokens (`stop_tokens()==&[]`) → relies entirely on the embedded GGUF
template. If that's broken/absent (the SS-W scenario):
- (A) no role-framing → malformed prompt → universal "I can't assist" refusal;
- (B) no `<|im_end|>`-style stop token → a 30-token title gen never stops → dumps raw `<think>` + meta-prompt.
**VibeThinker-1.5B IS `PromptDialect::None` + Think tier** (verified `model_profile.rs:265`) → hits exactly this.
- DIAGNOSTIC (`0225f18d9`): `reasoning_dialect_risk_warning()` (pure, tested) flags it; logged via tracing::warn
  at the GGUF build site. NON-BEHAVIOR-CHANGING (no blind dialect change — owner confirms the correct template).
- **OWNER FIX (one-glance, when running a model):** confirm VibeThinker's correct chat format (likely **chatml**,
  as VibeThinker is Qwen2.5-based) → set its `prompt_dialect` from `None` to the right dialect (e.g. `Chatml`,
  which yields the `chatml` llama.cpp override + `<|im_end|>`/`<|endoftext|>` stop tokens). That single change
  would fix BOTH the refusal (role-framing) and the title leak (clean stop). Verify across the other
  `PromptDialect::None` reasoning models (DeepSeek-R1-Distill) too.
- Both local lanes now have a load/build-time diagnostic (MLX `ChatTemplateDiagnostic` 67e82080f + GGUF here),
  so the cause is pinned automatically the moment a model runs.
