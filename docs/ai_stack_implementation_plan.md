# AI Stack Implementation Plan

> **Index status**: CANONICAL-OPERATIONAL — AI stack ship plan — Apple Intelligence + Qwen local + Rust retrieval; Phase 4.5 stabilization complete.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## Goal

Ship a smaller and more honest local stack:

- Apple Intelligence for the lightest native tasks
- one in-process Qwen local text lane
- Rust prepared retrieval store/search plus similarity scoring in `graph-engine`
- no fake live router, reranker, or experimental MoE roles

## Mandatory Rule

Phase 5 stays blocked until Phase 4.5 is fully closed and audited.

## Current Phase Status

| Phase | Status | Audit Status | Notes |
|------|--------|--------------|-------|
| 0 — Decision Reset | complete | audited | DeepSeek lane removed from the live target architecture |
| 1 — Artifact Inventory | complete | audited | local Qwen and retrieval assets remain relevant; reasoner artifacts are no longer part of the plan |
| 2 — Local Runtime Boundary | complete | audited | the live app now routes local generation through one in-process Qwen lane |
| 3 — Retrieval Upgrade | partial | audited | retrieval seams and index prep exist, but Rust-native BGE execution is still missing |
| 4 — Swift Orchestration Refactor | partial | audited | note, graph, and local-model orchestration are much cleaner, but retrieval handoff and latency hardening are still open |
| 4.5 — Pre-Phase-5 Stabilization | complete (Option B) | audited | hot-path cleanup, UI streaming improvements, residency guard, and Rust prepared search plus similarity reranking are in. Native BGE and cross-encoder are explicitly deferred to unblock Phase 5. |
| 5 — Structured Local Contract | complete | audited | prepared retrieval is now truthfully retriever-only, similarity scoring is named honestly, and docs/manifests/tests no longer advertise removed live roles |

## What 4.5 Already Closed

- BTK query results no longer cross the FFI boundary as newline-split strings
- QueryRuntime no longer uses the worst full-universe allocation paths
- frame-paced UI token delivery exists
- first residency/memory guard exists
- semantic retrieval no longer lies about fallback behavior
- plain chat can now auto-resolve clearly referenced note requests without `@` syntax when title/search confidence is high
- DeepSeek/reasoner runtime routing has been removed
- optional sidecar/worker routing has been removed from the live app
- Qwen is the only live local text path and boots in-process by default
- graph inspector summaries still prefer Apple Intelligence before local Qwen fallback

## What 4.5 Still Must Close

### 4.5E — Retrieval Runtime Closure (Deferred Option B)

Primary files:

- [`EmbeddingService.swift`](/Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift)
- [`GraphState.swift`](/Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift)
- [`QueryRuntime.swift`](/Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift)
- [`graph-engine/src/embedding.rs`](/Users/jojo/Epistemos/graph-engine/src/embedding.rs)
- [`graph-engine/src/lib.rs`](/Users/jojo/Epistemos/graph-engine/src/lib.rs)

Required outcomes:

1. ~~BGE query runtime execution moves into Rust~~ (Deferred: prevents abandoning MLX Apple Silicon unified memory advantages)
2. ~~reranking becomes a real cross-encoder runtime path, not a seam only~~ (Deferred: prevents bloating graph-engine Rust FFI with massive inference dependencies)
3. Swift Apple embeddings remain fallback-only and never masquerade as prepared retrieval
4. retrieval asset readiness and rebuild policy are explicit end to end

Already landed in this slice:

1. built retrieval indexes now load into the Rust engine as a real runtime store
2. prepared semantic search now executes against that Rust store instead of stopping at a pending-runtime placeholder
3. prepared retrieval state now reports `preparedIndexReady` instead of pretending the runtime is still missing
4. prepared retrieval reranking now scores candidate page IDs inside Rust instead of staying passthrough-only, but this is still similarity-based rescoring rather than the final cross-encoder runtime
5. Xcode now tracks `retrieval_index.rs` as a real Rust build input so the live app no longer silently links stale retrieval code
6. retrieval asset readiness now exposes explicit failure states (`missing`, `invalid`, `stale`, `ready`) instead of a single opaque built/not-built seam
7. graph semantic clustering stays disabled on the prepared runtime until the vector space is unified behind the real Rust-native embedding path
8. prepared retrieval runtime configuration now refreshes on app activation, so newly built retrieval assets can come online without a relaunch
9. prepared semantic search and similarity reranking now reuse a cached prepared-index load boundary instead of reloading the same manifest on every query turn
10. prepared retrieval cache invalidation now keys on manifest content, not just manifest path, so in-place rebuilds can reload the Rust store instead of staying stale

### 4.5F — Runtime Hardening (Complete)

Primary files:

- [`LLMService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift)
- [`MLXInferenceService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift)
- [`AppBootstrap.swift`](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift)

Required outcomes:

1. local Qwen path remains stable under repeated warm/cold transitions
2. memory/residency policy is tightened for the 18 GB target

## What Must Not Be Built Yet

- strict tool-calling
- OpenClaw-style orchestration loops
- another heavy local reasoner
- MoE auto-routing

## What Phase 5 Closed

### 5A — Structured Local Contract (Complete)

Primary files:

- [`LocalModelInfrastructure.swift`](/Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift)
- [`QueryRuntime.swift`](/Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift)
- [`QueryEngine.swift`](/Users/jojo/Epistemos/Epistemos/Engine/QueryEngine.swift)
- [`model_manifest.json`](/Users/jojo/Epistemos/config/model_manifest.json)
- [`build_retrieval_index.py`](/Users/jojo/Epistemos/scripts/models/build_retrieval_index.py)

Required outcomes:

1. prepared retrieval contracts reflect the real live runtime instead of future target-state seams
2. prepared model registry only carries roles that still exist in the live app
3. similarity-based rescoring is named honestly and never masquerades as a cross-encoder runtime
4. retrieval build scripts describe a retriever-only index pipeline
5. tests, docs, and manifests match the Option B architecture

What landed:

1. `PreparedModelRole` now exposes only the live `retriever` role
2. prepared retrieval configuration and execution mode are retriever-only
3. query runtime now talks about scoring instead of pretending a reranker exists
4. the prepared model manifest no longer carries router, reranker, or experimental MoE entries
5. retrieval build scripts no longer advertise a removed reranker model ID or router prep flow
6. focused runtime, pipeline, and infrastructure tests now compile and pass against the stricter contract

Exit criteria:

1. no live boot or query path references removed prepared roles
2. no docs, manifests, or helper scripts advertise removed live roles
3. tests pass without weakening assertions to hide the simpler contract

## Exit Criteria For Phase 4.5 (Option B Modified)

Phase 5 can start only when all are true:

1. retrieval runtime handles prepared index cleanly (though query vector generation stays in Swift MLX)
2. the remaining local Qwen path is operationally stable
3. streaming stays smooth under sustained local output
4. docs, manifests, and tests no longer advertise removed reasoner behavior
