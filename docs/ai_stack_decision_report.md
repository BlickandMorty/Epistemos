# AI Stack Decision Report

> **Index status**: CANONICAL-OPERATIONAL — AI stack decision report (companion to ai_stack_implementation_plan).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## Current Truth

Epistemos no longer carries a separate DeepSeek reasoner lane.

The live target architecture is now:

- Apple Intelligence for the lightest native tasks
- one Qwen local text lane for local chat, synthesis, and routing-adjacent work
- Swift-owned query embeddings feeding a Rust prepared retrieval store/search path
- Rust similarity scoring for prepared retrieval candidate rescoring
- in-process local serving as the default boot path for Qwen

## Why DeepSeek Was Removed

The previous heavy-reasoner split created the wrong tradeoff for the 18 GB target:

- too much unified-memory pressure
- unstable optional worker startup and health behavior
- extra routing complexity before deterministic orchestration existed
- more stale UI/state than product value

The app is easier to stabilize with one real local text model than with a router-plus-reasoner split that was not operationally solid.

## Current Runtime Map

```text
User
  -> SwiftUI views
  -> @Observable state
  -> PipelineService / TriageService
  -> Apple Intelligence OR local Qwen
  -> MLXInferenceService by default

Retrieval
  -> QueryRuntime / SearchIndexService / GraphState
  -> GRDB FTS + Rust graph search + prepared retrieval runtime
  -> Swift query embeddings + Rust cosine-similarity scoring
```

## Decisions Locked

1. No DeepSeek runtime path.
2. No prepared reasoner role in the live manifest.
3. No UI that implies a separate heavy reasoner exists.
4. No fake router, reranker, or experimental MoE role in the live prepared-model contract.
5. No tool-calling contract until a later phase explicitly introduces it.

## Current Model Roles

- `retriever_primary`: BGE-M3 asset slot

No other prepared live roles remain in the manifest.

## Current Boundaries

The contract now stays locked to:

1. Apple Intelligence first for the lightest native tasks
2. one in-process Qwen lane for local text generation
3. Swift-owned query embeddings
4. Rust prepared retrieval storage/search plus similarity scoring
5. no semantic clustering on the prepared runtime until the vector space is unified

Current behavior that stays locked while 4.5 continues:

- graph summaries try Apple Intelligence first, then fall back to local Qwen
- graph semantic clustering stays off on the prepared runtime until the semantic vector space is fully unified

## Rejected Alternatives

- bringing back a dedicated heavy reasoner before Phase 5
- replacing DeepSeek with another large local model immediately
- treating old worker instability as a reason to move every future model into the UI process
- pretending similarity rescoring is already a real cross-encoder runtime

## Shipping Bias

The shipping bias is now simple:

- fewer live model roles
- less hidden routing
- less memory contention
- cleaner retrieval boundaries
- deterministic orchestration later, on top of a smaller and more honest local stack
