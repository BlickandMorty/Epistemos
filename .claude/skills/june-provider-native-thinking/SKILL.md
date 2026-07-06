---
name: june-provider-native-thinking
description: Use when adding, auditing, or hardening MAS June provider-native reasoning/thinking support across model picker rows, agent_core provider slugs, request controls, stream parsers, and capability labels without faking local tools or exposing private raw chain-of-thought.
---

# June Provider Native Thinking

## Purpose

Use this skill when June's UI/model catalog says a cloud model can think, reason, or expose reasoning controls. The core rule: the claim must reach the actual provider request and stream parser. A picker badge is not enough; a selected row must map to the right `agent_core` provider slug, instantiate the right native model, send the provider's documented thinking/reasoning controls, and preserve only the allowed visible thinking delta.

Compose this skill with:

- `june-streaming-thinking-boundary` for bounded streams and thinking-delta event shape.
- `june-local-model-oom-guard` when local rows, local thinking labels, or lower-context prompt budgets are nearby.
- `june-native-capability-bridge` when the fix crosses June web/native/Rust boundaries.

Do not use this skill to add subprocesses, stdio MCP, OpenCode/CLI passthroughs, terminal/code tools, or fake local function-calling. MAS local rows remain chat-tier unless a deterministic local tool lane is actually admitted.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `Epistemos/State/InferenceState.swift`
4. `Epistemos/JuneAgent/JuneAgentGateway.swift`
5. `Epistemos/Goose/GooseInProcessACPServer.swift`
6. `agent_core/src/bridge.rs`
7. The touched provider file in `agent_core/src/providers/`
8. `EpistemosTests/AppStoreJuneHardeningTests.swift`

## Method

1. Start from the Swift truth table.
   - Read `CloudTextModelID.supportedOperatingModes`, `supportsNativeReasoningEffortControl`, context windows, and provider gates.
   - Keep `CloudModelProvider.supportsAgentTier` honest; do not promote providers to June agent tier just because they have chat thinking.
   - Local rows stay compact-context chat rows unless real local-native thinking is proven.

2. Trace the selected row to `agent_core`.
   - Check `GooseInProcessACPServer.agentCoreSlug(forSelectedModel:providerID:)`.
   - Check `JuneAgentGateway.agentCoreProviderName`.
   - Check `agent_core/src/bridge.rs` preview and instantiate arms.
   - A model-specific row must not collapse to a legacy or lower-capability alias if the UI claims native reasoning.
   - Provider families with separate chat/reasoner aliases need explicit slugs (for example DeepSeek `deepseek-reasoner` -> `deepseek_reasoner`, not generic `deepseek` chat).

3. Patch provider request controls from primary docs.
   - OpenAI Responses: use model-specific native constructors and `reasoning` summary controls only for reasoning-capable models; filter raw private reasoning text.
   - Claude: preserve thinking blocks and signatures.
   - Gemini: request thought summaries and stream thought parts/signatures as thinking deltas.
   - OpenAI-compatible providers: implement provider-specific request extensions such as Kimi `thinking` and Z.AI/GLM `thinking` / `reasoning_effort` when documented.
   - DeepSeek: select the reasoning model alias for thinking/pro/agent rows and preserve streamed `reasoning_content`; the chat alias remains non-thinking.
   - If a provider lacks a documented control, preserve returned `reasoning` / `reasoning_content` deltas but do not invent controls.

4. Preserve only the allowed visible stream.
   - Emit provider-visible summaries/deltas through `StreamEvent::ThinkingDelta`.
   - Do not show private raw chain-of-thought fields when provider docs distinguish raw reasoning from visible summaries.
   - Keep text, thinking, tool, approval, and completion channels separate.

5. Source-guard the full seam.
   - Add focused provider tests with a shared filter, e.g. `provider_native_thinking`, so one low-memory Rust checkpoint covers the batch.
   - Add App Store source guards that require picker-to-slug routing, native constructors/request fields, stream parser preservation, Swift capability labels aligned to Rust request extensions, and local capability honesty.
   - Update `JUNE_MAS_CONNECTION_AUDIT.md` with the source fix and runtime proof gap.

## Verification

- Targeted web validation uses primary provider docs for any current API/model claim.
- Focused Rust test: `CARGO_BUILD_JOBS=1 CARGO_INCREMENTAL=0 cargo test --manifest-path agent_core/Cargo.toml provider_native_thinking --lib`.
- Lightweight Swift parser check for touched Swift/source-guard files before any native App Store build.
- `git diff --check` plus a direct trailing-whitespace check for untracked source guard files.
- Runtime proof later: a configured MAS build transcript showing `thinking.delta` from a selected provider-native thinking model, with local rows still tool-free.
