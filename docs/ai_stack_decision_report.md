# AI Stack Decision Report

## Current Truth

Epistemos no longer carries a separate DeepSeek reasoner lane.

The live target architecture is now:

- Apple Intelligence for the lightest native tasks
- one Qwen local text lane for local chat, synthesis, and routing-adjacent work
- Rust-native retrieval and reranking as the long-term search path
- optional experimental MoE kept isolated and manual-only
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
  -> GRDB FTS + Rust graph search + prepared retrieval seams
  -> future Rust-native BGE runtime
```

## Decisions Locked Before Phase 5

1. No DeepSeek runtime path.
2. No prepared reasoner role in the live manifest.
3. No UI that implies a separate heavy reasoner exists.
4. No tool-calling contract until retrieval and runtime stabilization are actually closed.
5. Retrieval remains the main unfinished architecture item in Phase 4.5.

## Current Model Roles

- `router_primary`: prepared Qwen router
- `router_fallback`: smaller prepared Qwen router
- `retriever_primary`: BGE-M3 asset slot
- `reranker_primary`: BGE reranker slot
- `experimental_moe`: manual-only experimental lane

## Phase 4.5 Focus

The remaining work before Phase 5 is:

1. finish the Rust-native BGE retrieval/runtime path
2. keep the single local Qwen path honest and stable
3. keep streaming/UI smooth under heavy local generation
4. harden memory residency and readiness behavior around the single local text lane

## Rejected Alternatives

- bringing back a dedicated heavy reasoner before Phase 5
- replacing DeepSeek with another large local model immediately
- treating old worker instability as a reason to move every future model into the UI process

## Shipping Bias

The shipping bias is now simple:

- fewer live model roles
- less hidden routing
- less memory contention
- cleaner retrieval boundaries
- deterministic orchestration later, on top of a smaller and more honest local stack
