---
name: june-local-model-oom-guard
description: Use when changing MAS June local model loading, GGUF/llama.cpp execution, Apple Foundation Models fallback, local prompt budgets, model picker behavior, or memory-pressure handling on constrained Macs.
---

# June Local Model OOM Guard

## Purpose

Use this skill whenever June's local lane might load, retain, switch, stream, download, or prompt a local model. The goal is simple: local privacy must never mean surprise memory pressure. On 16 GB machines, June should prefer cloud-agentic work by default, keep local chat honest and compact, and run at most one heavy GGUF generation at a time.

Do not use this skill to make local models tool-capable without a proven deterministic grammar/tool lane, to preload models for picker display, to run multiple local engines, or to hide a cloud fallback behind a local row.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `Epistemos/JuneAgent/JuneAgentGateway.swift`
4. `Epistemos/JuneAgent/JunePromptForge.swift`
5. `Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift`
6. `Epistemos/QuickChat/AppleFMQuickChatBackend.swift`
7. `Epistemos/QuickChat/GGUFModelCatalog.swift`

## Method

1. Prove no eager load.
   - Picker/catalog rendering may inspect metadata and installed files.
   - Model bytes load only on explicit local generation or explicit download/install flow.
   - Download-on-select must still pass the RAM gate first; an oversized row may be visible with honest blocked copy, but must not start moving GGUF bytes.
   - Cloud-first default must not silently load local GGUF.

2. Keep local prompts compact.
   - Use selected-model context windows, not cloud-scale assumptions.
   - Limit Prompt Forge citations, excerpts, history, and reply budget for local rows.
   - Surface `exceededContextWindow` honestly rather than swapping models or expanding context.

3. Enforce one heavy local generation.
   - GGUF/llama.cpp routes must be single-flight unless a future runtime proves safe parallelism with memory counters.
   - A concurrent request returns honest busy copy.
   - Cancellation must call the local engine's cancel path.

4. Make memory pressure authoritative.
   - Real memory-pressure handlers may unload warm GGUF state.
   - If pressure arrives during generation, cancel generation and unload after the engine exits; avoid racing unload against inference.
   - Do not unload on tab/view disappear when the perf doctrine requires warm retention.

5. Guard local capability truth.
   - Local rows stay chat/compact-context unless a deterministic tool lane is actually admitted.
   - Local thinking is shown only when the stream actually emits think/reasoning tags or a native local model has proven reasoning deltas.
   - Do not claim "agentic" on a local model to satisfy UI affordances.

6. Validate without loading models first.
   - Run source guards for no eager load, bounded streams, single-flight GGUF, RAM gate, and compact Prompt Forge profiles.
   - Check process RSS before any native build/test.
   - Defer runtime local-model tests to a deliberate checkpoint, and run only one local model process at a time.

## Review Checklist

- No picker/session/bootstrap path loads GGUF bytes.
- Oversized GGUF rows are blocked before download/selection as well as before load.
- GGUF generation is single-flight and cancellation-aware.
- Memory pressure unload is balanced with active-generation cancellation.
- RAM gates use current physical-memory headroom before load.
- Local prompt/context budgets are smaller than cloud budgets.
- Local rows do not expose tool/function-calling capability.
- No local model runtime is launched during ordinary source/test validation.
