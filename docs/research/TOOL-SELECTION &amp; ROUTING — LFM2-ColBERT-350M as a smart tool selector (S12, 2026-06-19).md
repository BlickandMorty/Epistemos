---
id: EA40302C-B0A7-4985-B549-E8279FC0B3BF
title: TOOL-SELECTION &amp; ROUTING — LFM2-ColBERT-350M as a smart tool selector (S12, 2026-06-19)
---

# TOOL-SELECTION &amp; ROUTING — LFM2-ColBERT-350M as a smart tool selector (S12, 2026-06-19)

Read-only research (subagent), code-grounded + cited. Feeds DEEP_PLAN_AUDIT_HUB.

## What Epistemos does today (and its limits)

The live tool selector is **lexical, deterministic, flag-OFF** — `agent_core/src/tool_preflight.rs`:  
`select_tools(query,candidates,max)` (`:79`) tokenizes (≥3-char, 40-word stoplist) and scores  
name-hit=3/keyword=2/desc=1, returns top-k with score&gt;0 (honest-empty); `query_needs_tools` (`:218`)  
= the auto-route boolean. Feeds `preflight_dispatch_grammar` (`:262`, MLX/llguidance) +  
`preflight_dispatch_json_schema` (`:293`, GGUF). **It IS wired into Swift** (corrects "never called"):  
`SchemaPreflightToolNarrowing.swift:52` + `PipelineService.swift:440/:508`. This is the P8.2  
RAG-preflight ("tight footprint ~3-5 tools"). **Limits:** no semantics (synonyms/paraphrase/  
cross-lingual all miss), stopword/≥3-char drops meaningful short terms, alphabetical tie-break,  
`query_needs_tools` brittle as an auto-route gate. The SHAPE is right; the SCORER is the weak link  
— and the doctrine comment (`:11-13`) explicitly reserves the seam: "the semantic/embedding  
preflight replaces `score` without changing this deterministic contract."

## Where LFM2-ColBERT-350M fits

It's a **late-interaction (ColBERT) RETRIEVER, NOT a generator** — encodes query+doc per-token
(128-dim) and scores by MaxSim; 350M, LFM2 backbone, 32k ctx; LFM2.5-ColBERT (~2026-06-19) adds
11 languages, p50 &lt;10ms with pre-computed doc embeddings. **Map retrieval→tool-selection:** each
tool/skill = a "document" (its name+desc+keywords, the exact `ToolCandidate` fields); pre-compute
the catalog's per-token embeddings once (tiny — dozens of tools), encode the query at turn time,
MaxSim → ranked top-k. **Cleanest possible drop-in:** keep `select_tools`'s signature + all three
downstream pipelines byte-identical; swap ONLY the inner `score` (`:56`) behind a `ToolScorer { lexical | colbert }`
trait, flag-selected. The Swift wiring doesn't change (ColBERT lives entirely under the FFI).

**How it runs:** GGUF/llama.cpp embeddings lane (`LiquidAI/LFM2-ColBERT-350M-GGUF`, Q4_K_M 228MB…Q8_0 378MB).
**No-hidden-sidecar means an in-process embedding FFI (return token vectors, MaxSim in Rust), NOT a
spawned `llama-server`** — Pro-gated until the in-process proof. No MLX ColBERT build exists today
(Safetensors+GGUF only) → GGUF is the proven path. It's a NEW small-model lane (~250MB retriever the
owner installs, role=retriever, NOT generation), beside the existing `EmbeddingService` (today Apple-NL
single-vector — ColBERT's token-level MaxSim strictly outperforms on terse-query↔short-desc + multilingual).

## STOP-REINVENTING check

- **A REAL upgrade, but SECOND-ORDER.** The lexical selector is "good enough" to ship the tight-footprint
thesis; the #1 blocker is NOT selection quality — it's that **chats never ENTER the tool loop** (S1/S4).
**Selection quality only matters once tool calls fire**, so ColBERT is correctly ordered AFTER the
loop-entry fixes, not before.
- **No overlap with Osaurus/Hermes** — neither ships a learned tool/skill retriever (both do in-context
tool choice over the full list). So ColBERT is a genuinely NEW retrieval layer Epistemos owns — the rare
"import a real new engine" case, not "wire what exists." Also a real upgrade over Apple-NL embeddings.

## Composition + as a stack model

Strictly downstream of loop-entry (produces no tool calls itself). As a stack model: a catalog
entry flagged role=retriever/embedder (excluded from `TriageService.preferredAutomaticLocalModel:636`
— it can't generate); ~250MB, within the 16GB budget; downloads via HF HubClient (mind the D2 staging
purge for large models). **High leverage: the SAME installed retriever can power BOTH tool/skill
selection AND vault RAG** (upgrade `EmbeddingService`/the RRF semantic arm) — one install, two consumers.

## Gating, honesty, ordered plan

On-device only (no network). Sandbox-safe IF in-process FFI embedding (no subprocess); a spawned
server is MAS-forbidden → **Pro-gated first**, promote to MAS only after the in-process proof +
ProvenanceGate. Honesty: when ColBERT off/uninstalled, fall back to lexical (surface "lexical vs
semantic selection", never silent); keep honest-empty.
Order: (1) land S4 loop-entry fixes [prereq — ColBERT inert without it]; (2) flip
`EPISTEMOS_SCHEMA_PREFLIGHT_V0`+`AUTO_TOOL_ROUTE_V0` with the LEXICAL scorer, verify visible tool
boxes in-app (kills flag-OFF=not-done); (3) add `ToolScorer` trait (lexical default, no behavior change);
(4) add in-process ColBERT GGUF embedding FFI + Rust MaxSim + catalog pre-compute, `colbert` scorer behind
a flag; (5) catalog entry role=retriever, Pro-gate + provenance + rollback; (6) A/B vs lexical, promote
toward MAS after no-subprocess proof; (7) bonus: point EmbeddingService/RRF semantic arm at the same retriever.

## License + provenance

**License = "LFM Open License v1.0"** (Liquid's own; NOT MIT/Apache — commercial beyond it routes through
Liquid sales). Run `F-ProprietaryCompression-ProvenanceGate` (quarantine + license review) before weights/  
logic enter product; don't commit weights. First-party LiquidAI GGUF + llama.cpp; base Oct-2025, 2.5 ~June-2026.

Key files: `agent_core/src/tool_preflight.rs` (score swap point `:56`, flags `:162/206/316`, pipelines `:262/293`) · `agent_core/src/grammar/mod.rs` (`dispatch_schema_for_tools:29`, reused) · `Epistemos/LocalAgent/SchemaPreflightToolNarrowing.swift` · `Epistemos/Engine/PipelineService.swift:440/508` · `Epistemos/Engine/TriageService.swift:636` (exclude retriever) · `Epistemos/Graph/EmbeddingService.swift` (RAG upgrade target) · `Epistemos/State/InferenceState.swift:61-70` + `Epistemos/Engine/LocalModelInfrastructure.swift:791/1260` (LFM2.5 generators present, ColBERT retriever ABSENT = the gap). Sources: huggingface.co/LiquidAI/LFM2-ColBERT-350M(-GGUF), LFM2.5-ColBERT-350M-GGUF, liquid.ai/blog.