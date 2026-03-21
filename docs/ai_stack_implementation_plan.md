# AI Stack Implementation Plan

## Goal

Ship a smaller and more honest local stack before Phase 5:

- Apple Intelligence for the lightest native tasks
- one Qwen local text lane
- Rust-native BGE retrieval and reranking
- experimental MoE isolated and manual-only

## Mandatory Rule

Phase 5 stays blocked until Phase 4.5 is fully closed and audited.

## Current Phase Status

| Phase | Status | Audit Status | Notes |
|------|--------|--------------|-------|
| 0 — Decision Reset | complete | audited | DeepSeek lane removed from the live target architecture |
| 1 — Artifact Inventory | partial | audited | router and retrieval assets remain relevant; reasoner artifacts are no longer part of the plan |
| 2 — Local Runtime Boundary | complete | audited | the live app now routes local generation through one in-process Qwen lane |
| 3 — Retrieval Upgrade | partial | audited | retrieval seams and index prep exist, but Rust-native BGE execution is still missing |
| 4 — Swift Orchestration Refactor | partial | audited | routing is much cleaner, but strict JSON router contract is not started |
| 4.5 — Pre-Phase-5 Stabilization | partial | audited | hot-path cleanup, UI streaming improvements, residency guard, DeepSeek removal, and Rust prepared-index search plus similarity reranking are in; native BGE/cross-encoder closure is still open |
| 5 — Router Contract | not started | not audited | blocked on 4.5 completion |

## What 4.5 Already Closed

- BTK query results no longer cross the FFI boundary as newline-split strings
- QueryRuntime no longer uses the worst full-universe allocation paths
- frame-paced UI token delivery exists
- first residency/memory guard exists
- semantic retrieval no longer lies about fallback behavior
- plain chat can now auto-resolve clearly referenced note requests without `@` syntax when title/search confidence is high
- DeepSeek/reasoner runtime routing has been removed
- optional sidecar/worker routing has been removed from the live app
- Qwen now boots in-process by default

## What 4.5 Still Must Close

### 4.5E — Retrieval Runtime Closure

Primary files:

- [`EmbeddingService.swift`](/Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift)
- [`GraphState.swift`](/Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift)
- [`QueryRuntime.swift`](/Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift)
- [`graph-engine/src/embedding.rs`](/Users/jojo/Epistemos/graph-engine/src/embedding.rs)
- [`graph-engine/src/lib.rs`](/Users/jojo/Epistemos/graph-engine/src/lib.rs)

Required outcomes:

1. BGE runtime execution moves into Rust
2. reranking becomes a real runtime path, not a seam only
3. Swift Apple embeddings remain fallback-only and never masquerade as prepared retrieval
4. retrieval asset readiness and rebuild policy are explicit

Already landed in this slice:

1. built retrieval indexes now load into the Rust engine as a real runtime store
2. prepared semantic search now executes against that Rust store instead of stopping at a pending-runtime placeholder
3. prepared retrieval state now reports `preparedIndexReady` instead of pretending the runtime is still missing
4. prepared retrieval reranking now scores candidate page IDs inside Rust instead of staying passthrough-only
5. Xcode now tracks `retrieval_index.rs` as a real Rust build input so the live app no longer silently links stale retrieval code
6. retrieval asset readiness now exposes explicit failure states (`missing`, `invalid`, `stale`, `ready`) instead of a single opaque built/not-built seam

### 4.5F — Runtime Hardening

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

## Exit Criteria For Phase 4.5

Phase 5 can start only when all are true:

1. retrieval runtime is Rust-native enough that Swift no longer owns the real embedding path
2. the remaining local Qwen path is operationally stable
3. streaming stays smooth under sustained local output
4. docs, manifests, and tests no longer advertise removed reasoner behavior
