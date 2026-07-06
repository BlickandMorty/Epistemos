---
name: june-local-context-budgeting
description: Use when changing MAS June local prompt assembly, Prompt Forge profiles, conversation history folding, GGUF reply budgets, local model catalog context windows, or any local-lane behavior that must adapt to smaller context models without loading model bytes or faking local tools.
---

# June Local Context Budgeting

## Purpose

Use this skill when a June change touches what a local model is asked to read or produce. The rule is: local context is not one bucket. A 2K TinyLlama row, 4K Apple Foundation Models row, 8K Phi row, 16K Qwen row, and 32K long-doc row each need different prompt, history, citation, and reply envelopes.

Compose this skill with:

- `june-local-model-oom-guard` for memory residency, single-flight GGUF generation, and no eager model loading.
- `june-streaming-thinking-boundary` when local think-tag parsing or stream buffers are nearby.
- `june-prompt-forge` when the user-facing upgraded prompt or vault citations are affected.

Do not use this skill to advertise tools on local models, preload GGUF bytes for sizing, silently route local prompts to cloud, or hide context overflow behind a generic generation error.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `Epistemos/JuneAgent/JuneAgentGateway.swift`
4. `Epistemos/JuneAgent/JunePromptForge.swift`
5. `Epistemos/QuickChat/GGUFModelCatalog.swift`
6. `Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift`
7. `EpistemosTests/AppStoreJuneHardeningTests.swift`

## Method

1. Start from the selected model ID.
   - Resolve `JuneModelID.appleFM`, `JuneModelID.localGGUF`, and exact `GGUFModelCatalog.entry(id:)` rows.
   - Use the row's declared context window as the local budget source.
   - Treat unknown local IDs conservatively, not generously.

2. Budget every local input surface from that window.
   - Prompt Forge: cap user input, scanned files, citation count, and excerpt length per local context tier.
   - History folding: cap message count, total transcript characters, and per-message characters per local context tier.
   - GGUF generation: cap reply tokens per local context tier before `LocalGGUFQuickChatBackend.stream`.
   - Context compiler: pass bounded context limits and still consume only relative citations.

3. Keep cloud and local separate.
   - Cloud may keep richer history/citations when configured.
   - Local rows stay chat-tier and compact; context budgeting never implies function calling.
   - If the prompt still overflows, surface `exceededContextWindow` honestly before model bytes load.

4. Preserve the OOM boundary.
   - Do not run a local model while validating source budget changes.
   - Prefer parser-only Swift checks and source guards first.
   - Defer native App Store builds and runtime model probes to deliberate checkpoints on a quiet machine.

## Review Checklist

- Local history budget is selected-model-aware, not a fixed "local" constant.
- GGUF `maxNewTokens` is derived from the same local context budget.
- Prompt Forge local profiles remain smaller than cloud profiles.
- The pre-load GGUF context fit check still sees the full formatted prompt.
- Local rows do not expose `supportsFunctionCalling`.
- Tests/source guards prove the budget seam and no default-unbounded streams.
- Verification notes explicitly state whether any local model was loaded.
