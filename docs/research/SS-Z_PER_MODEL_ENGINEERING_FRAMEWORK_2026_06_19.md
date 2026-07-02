---
id: 0EEF47DF-7EB9-4BCA-A315-C34B7F29E406
title: SS-Z_PER_MODEL_ENGINEERING_FRAMEWORK_2026_06_19
---

# SS-Z — Per-model bespoke engineering framework (modernized, non-clashing) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the PER-MODEL-FRAMEWORK ledger item. Owner: *"a custom
bespoke engineering framework for each local + cloud model, modernized, non-clashing; all models utilize my
skills with the robust tool-call of LFM or a combination of tool-callers; use GitHub repos if they solve it."*
Cross-refs SS-W (the crash), SS-H (skills sharing), SS-Y (determinism).

## Headline
Per-model config is **badly scattered + partly outdated**, split across **two disconnected model universes that
don't share a config shape**: the MLX lane (`LocalTextModelID`, ~60 cases) carries rich per-model config (ctx
window, reasoning cap, tool tier) via giant `switch self` ladders; the **GGUF lane** (`GemmaQATRuntimeCandidate`
— the ACTUAL Chat-engine local path, incl. the newly-added LFM2.5/VibeThinker/MoE/12B-2bit) carries **NONE of
it** (no ctx window, no chat template, no tool-call dialect, no sampling defaults). There is **no single
per-model profile anywhere.** The SS-W crash falls straight out of this gap.

## Per-model config surface today (≥4 disjoint places)
1. **MLX** — `LocalTextModelID` mega-enum in `State/InferenceState.swift`: `maxContextTokens` ladder `:708-763`
   (hardcoded literal per model — **the owner's "context window in a file is a mess"**); `reasoningTokenCap`
   `:506+` (doctrine-only, **live enforcement deferred** `:493-501`); `agentToolTier` `:1212-1269`; `canActAs
   Agent`/`canRunLocalAgentLoop` `:471-480`.
2. **GGUF** — `GemmaQATRuntimeCandidate` struct `Engine/LocalModelInfrastructure.swift:452-646` (id/repo/SHA/
   `minimumRecommendedMemoryGB`/family/summary + proof-artifacts) — **ZERO inference config** (no ctx, no chat
   template, no dialect, no sampling). `LocalModelDescriptor:82-135` likewise none.
3. **Tier mapping** — `EpistemosFoundationLineup.swift:68-220` (Fast/Think/Code → model + effort thresholds).
4. **Cloud** — `CloudModelProvider` `InferenceState.swift:1281-1388` (`supportsAgentTier:1347`, `supportsChat
   ToolAttachment:1362`); cloud `maxContextTokens` a SEPARATE ladder `:1927+`.

## Chat template (the crash) + tool-call dialect per model
- **GGUF chat template = the SS-W crash.** `agent_core/src/providers/gguf_cli.rs:244-270` builds the `llama-cli`
  command with `--offline/--model/--prompt/--predict/--ctx-size/--temp/--seed/--single-turn/--simple-io` and
  **NO `--chat-template` and NO `--jinja`** (comments `:182-185,209-214` confirm it deliberately passes raw text
  to `--prompt` + relies on the model's EMBEDDED template). = the SS-W abort: when `common_chat_templates_apply`
  throws on a model whose embedded template can't be applied, there is **no explicit-template fallback**.
- **Context window hardcoded** `DEFAULT_CTX_SIZE=4096` (`gguf_cli.rs:32`) for EVERY GGUF model; the Swift FFI
  (`Bridge/LocalGgufRuntimeBridge.swift:171-189`) doesn't even pass ctx_size → a 128K model and a ~2K
  VibeThinker both get 4096. **Outdated/wrong by construction.**
- **Prompt format one-size-fits-all** — `LocalAgent/LocalAgentPromptBuilder.swift:65-110` + its Rust twin
  `agent_core/src/agent_runtime/prompt_format.rs:42-117` emit a single **Nous-Hermes/ChatML** preamble +
  `<tool_call>{…}</tool_call>` XML for ALL models. No Gemma function-calling, no LFM2, no Qwen-native form.
- **Tool-call dialect map EXISTS but is DEAD code** — `LocalToolGrammar.NativeToolGrammar` (`LocalToolGrammar
  .swift:27-124`) enumerates Qwen/Hermes/DeepSeek/Llama3.3/Mistral/Phi4 + `nativeGrammar(forModelID:)`, but the
  comment `:17-26` says it's a **pure-additive shim NOT wired into `ToolCallingPlan`**; `buildToolCallingPlan
  :163-235` still hardcodes the canonical `<tool_call>` grammar. **No Gemma/LFM2/VibeThinker cases** (the actual
  shipped GGUF models). Rust parser uniform too (`agent_runtime/function_call.rs:4-181`, only `<tool_call>`/JSON).
- **Schema-constrained decoding IS wired (the honest path, = SS-Y hook):** `GgufCliProvider.with_json_schema`→
  `--json-schema` GBNF (`gguf_cli.rs:139-159`), plumbed through `bridge.rs:1331,1349-1352` + FFI (`LocalGguf
  RuntimeBridge.swift:177`); MLX side `LocalToolGrammar.buildToolCallingPlan/buildJsonOutputPlan` (GBNF
  `:163-269`). **This is the right per-model tool-call substrate** — forcing valid JSON makes dialect moot.

## Skills access per model
Skills reach the model **only via the system prompt**, local-loop-shaped: `LocalAgentPromptBuilder.merging
SkillContent`/`proceduralMemoryBlock` (`:43,128-164`) folds `SkillManifest` into the prompt. **BUT the GGUF path
bypasses this builder entirely** — `run_local_gguf_generation_inner` (`bridge.rs:1325-1368`) takes only a flat
`system_prompt` + `build_prompt` forwards just the last user turn; loop explicitly bypassed (`bridge.rs:1271`).
Cloud: skills ride the builder for tool-enabled providers (gate `supportsChatToolAttachment:1362`, all 7 true
since the cloud-tools flip `:1375`). **Gap (= SS-H keystone):** small local models drop to `readOnly` tier
(`:1218-1220`) + the GGUF lane has no tool loop → smallest models effectively **can't call skills as executable
tools**, only receive them as prompt text.

## Outdated/messy config (verified)
- GGUF ctx hardcoded 4096 for all (`gguf_cli.rs:32`). · `reasoningTokenCap` not enforced (`:493-501`). ·
  `NativeToolGrammar` dialect map dead (`:17-26`). · Two parallel universes (MLX rich vs GGUF config-poor); new
  LFM2.5/MoE/12B-2bit/VibeThinker live only in the config-poor GGUF enum (`LocalModelInfrastructure.swift
  :424-436,651+`). · VibeThinker "~2K native context" is PROSE only (`:599`), not a field → 4096 default likely
  overruns it. · MLX `maxContextTokens` literals hand-maintained → drift as models are added.

## Modernized non-clashing design — ONE capability profile per model
Introduce a single source of truth `ModelCapabilityProfile { contextWindow; promptFormat (embedded|explicit
jinja path|builtin name); toolCallDialect (wire NativeToolGrammar for real + add Gemma/LFM2); samplingDefaults
(temp/top-p/stop); capabilityTier (unify LocalAgentToolTier + agentToolTier); skillsEnabled (one gate local+
cloud, = SS-H) }`. Both universes resolve to it: `GemmaQATRuntimeCandidate.capabilityProfile` +
`LocalTextModelID.capabilityProfile` + a cloud variant. **Non-clashing:** additive (proof-artifact/memory-gate
fields untouched), **Chat-first** (Act/Work keep their existing gates until proven).

**Use proven OSS (owner's "if a repo solves it, use it"):**
- **Chat template:** llama.cpp already owns this. Stop relying on the embedded template; pass **`--jinja
  --chat-template-file <model>.jinja`** (the `.jinja` is ALREADY downloaded per the descriptor globs
  `LocalModelInfrastructure.swift:642`). **Fixes the SS-W crash with ~zero bespoke code.** For a broken embedded
  template, fall back to a named built-in (`--chat-template gemma`).
- **Tool-call:** keep the GBNF `--json-schema` path (`gguf_cli.rs:139`, SS-Y) as the PRIMARY mechanism — forced
  valid JSON makes dialect differences moot; reserve `NativeToolGrammar` for native-syntax-preferred models;
  minja/llama.cpp's own tool-call parsers cover per-dialect parse.
- **Avoid clash:** do NOT fork the prompt builders — have them READ `toolCallDialect`/`promptFormat` from the
  profile instead of hardcoding Hermes.

## Ordered plan (chat-first)
1. **[S] Fix the crash (SS-W) directly** — add `--jinja --chat-template-file` (or named built-in) to
   `gguf_cli.rs:244-270` from the already-downloaded `.jinja`; add per-model ctx_size across FFI (replace
   hardcoded 4096 `:32`; thread through `LocalGgufRuntimeBridge.swift:171`). Highest value, smallest diff.
2. **[S] Wire the dead dialect map** — plumb `NativeToolGrammar` into `ToolCallingPlan` (`LocalToolGrammar.swift
   :126-235`) + add Gemma/LFM2/VibeThinker cases (the shim already exists).
3. **[M] Define `ModelCapabilityProfile`** + add `.capabilityProfile` to `GemmaQATRuntimeCandidate` (ctx/
   promptFormat/dialect/sampling/tier/skills); make `LocalAgentPromptBuilder` + `gguf_cli` read it.
4. **[M] Unify tool tiers + skills gate** behind the profile (`InferenceState.swift:1193,1212`) so small local +
   GGUF models have ONE honest skills-access answer (SS-H).
5. **[L] Migrate MLX ladders** (`maxContextTokens:708`, `reasoningTokenCap:506`, `agentToolTier:1212`) to resolve
   from the profile — collapse the two universes into one source of truth; enforce `reasoningTokenCap` live.

## Unverified
Individual staleness of each MLX `maxContextTokens` literal (shape verified, per-model currency not); whether
VibeThinker's 4096 ctx actually overruns its ~2K window at runtime (config mismatch verified, effect not); exact
SS-W stack trace inferred from gguf_cli.rs + the brief.

Key files: `Engine/LocalModelInfrastructure.swift:452-646,651+` · `Engine/EpistemosFoundationLineup.swift
:68-220` · `State/InferenceState.swift:708-763,506+,1193-1278,1281-1388` · `agent_core/src/providers/gguf_cli
.rs:32,139-159,182-270` (**crash path**) · `agent_core/src/bridge.rs:1271-1421` · `LocalAgent/LocalAgentPrompt
Builder.swift:43-164` + `agent_core/src/agent_runtime/prompt_format.rs:42-117` · `LocalAgent/LocalToolGrammar
.swift:17-124,163-269` · `agent_core/src/agent_runtime/function_call.rs:4-181` · `Bridge/LocalGgufRuntimeBridge
.swift:109-189`. Cross-refs: SS-W, SS-H, SS-Y.
