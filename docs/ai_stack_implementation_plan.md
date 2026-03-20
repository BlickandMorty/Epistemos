# AI Stack Implementation Plan

## Goal

Replace the current stock-Qwen-centric local path with a role-based local AI stack:

- Apple Intelligence remains available for the lightest work
- trained Qwen becomes the narrow router
- trained DeepSeek DPO becomes the heavy synthesizer
- BGE-M3 + reranker become the retrieval backbone
- experimental MoE stays opt-in and isolated

## Phase Order

## Phase 0: Discovery and Decision

Completed in this repo revision.

Deliverables:

- [`ai_stack_decision_report.md`](/Users/jojo/Epistemos/docs/ai_stack_decision_report.md)
- this implementation plan
- [`ai_stack_risks.md`](/Users/jojo/Epistemos/docs/ai_stack_risks.md)

## Phase 1: Artifact Inventory and Normalization

Deliverables added in this phase:

- [`model_manifest.json`](/Users/jojo/Epistemos/config/model_manifest.json)
- [`prepare_reasoner.sh`](/Users/jojo/Epistemos/scripts/models/prepare_reasoner.sh)
- [`prepare_router.sh`](/Users/jojo/Epistemos/scripts/models/prepare_router.sh)
- [`prepare_retrieval_assets.sh`](/Users/jojo/Epistemos/scripts/models/prepare_retrieval_assets.sh)

Goals:

1. lock exact base-model provenance
2. make merged MLX artifacts reproducible
3. create one canonical path for all prepared local AI assets

### Reasoner normalization

Input:

- DeepSeek DPO adapter from `~/Downloads/deepseek/.../final_adapter`

Output:

- merged Hugging Face artifact
- converted MLX artifact under `~/Library/Application Support/Epistemos/PreparedModels`

### Router normalization

Input:

- primary router: Qwen 4B adapter
- fallback router: Qwen 0.6B adapter

Output:

- merged Hugging Face artifacts
- converted MLX artifacts under the same prepared-model root

### Retrieval asset setup

Input:

- `BAAI/bge-m3`
- `BAAI/bge-reranker-v2-m3`

Output:

- local asset snapshots under the prepared-model root
- no Rust runtime wiring yet in this phase

## Phase 2: Sidecar Serving Boundary

Primary target:

- `mlx-openai-server`

Files to add or change:

- new local sidecar client service under `Epistemos/Engine/`
- new health/state registry in `Epistemos/State/`
- bootstrap wiring in [`AppBootstrap.swift`](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift)

Required abstractions:

1. `LocalLLMServing`
   - start/stop/health/model list

2. `LocalLLMClient`
   - chat completion
   - streaming completion
   - cancellation

3. `PreparedModelRegistry`
   - reads normalized prepared artifacts
   - resolves by role, not just by family

### Non-goals for Phase 2

- no retrieval refactor yet
- no MoE auto-routing
- no router JSON contract yet

The sidecar boundary comes before orchestration changes so the app stops being an inference host first.

## Phase 3: Retrieval and Reranking Upgrade

Goal:

keep the current native retrieval skeleton, but replace the weakest semantic layer.

Targets:

- preserve existing GRDB FTS and Rust graph search
- add BGE-M3 as the semantic retriever
- add BGE reranker before final context assembly

Preferred shape:

1. canonical chunk source from notes/blocks/pages
2. embeddings stored in a native index or native-compatible representation
3. reranking applied only to top-k candidates
4. final context assembly returns ranked block/page evidence

Initial file targets:

- [`QueryRuntime.swift`](/Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift)
- [`QueryEngine.swift`](/Users/jojo/Epistemos/Epistemos/Engine/QueryEngine.swift)
- [`EmbeddingService.swift`](/Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift)
- [`graph-engine/src/lib.rs`](/Users/jojo/Epistemos/graph-engine/src/lib.rs)
- likely new Rust modules for retrieval assets / ranking

## Phase 4: Swift Orchestration Refactor

Goal:

turn the app into a neutral orchestrator with role-based model routing.

Key changes:

1. Replace Qwen-only local model assumptions in [`InferenceState.swift`](/Users/jojo/Epistemos/Epistemos/State/InferenceState.swift)
2. Split model choice by role:
   - router
   - reasoner
   - experimental MoE
3. Add sidecar-backed local client path beside Apple Intelligence
4. Keep current UI responsive with async streaming only

Likely files:

- [`InferenceState.swift`](/Users/jojo/Epistemos/Epistemos/State/InferenceState.swift)
- [`LocalModelInfrastructure.swift`](/Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift)
- [`LLMService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift)
- [`TriageService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift)
- [`PipelineService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/PipelineService.swift)
- main/mini/note chat surfaces that expose the model picker

## Phase 5: Router Contract

The trained Qwen router must stop behaving like a freeform chat model.

Contract target:

```json
{
  "intent": "chat|retrieve|research|math|soar|tool",
  "needs_retrieval": true,
  "reasoning_depth": "light|medium|deep",
  "target_model": "router|reasoner",
  "tool": null,
  "notes_scope": "current_note|vault|graph|none",
  "confidence": 0.0
}
```

Rules:

- strict schema validation
- retries only for invalid JSON
- no semantic “helpful” retries
- no visible freeform router prose in the user UI

## Phase 6: Performance and Memory Hardening

Goals:

- pin router hot when safe
- keep reasoner warm only when justified
- unload heavy model on TTL
- never auto-load MoE on the target machine

Metrics to add:

- router TTFT
- reasoner TTFT
- stream tok/s
- reasoner cold-load ms
- retrieval ms
- rerank ms
- cancellation latency
- sidecar health failures

## Phase 7: Experimental MoE Lane

Model:

- `mlx-community/Qwen3-30B-A3B-4bit`

Rules:

- feature-flagged
- manual selection only
- no default routing to it
- no auto-residency on the 18 GB target
- benchmark gates before wider exposure

## Implementation Boundaries

### Keep in app shell

- UI
- query/cancellation state
- Apple Intelligence bridge
- context assembly
- vault/graph/note integration

### Move behind sidecar boundary

- heavy text generation
- router generation once normalized
- model load/unload lifecycle
- tokenizer/template-sensitive text serving

### Keep native/Rust-adjacent

- retrieval corpus ownership
- graph relationships
- semantic search / rerank path
- evidence assembly inputs

## Success Criteria

The implementation is ready for the next phase only if all of these are true:

1. DeepSeek artifact can be reproduced from source adapter + base model
2. Qwen router artifact can be reproduced from source adapter + base model
3. local sidecar path can stream without blocking the UI process
4. the app can route by model role rather than Qwen family
5. retrieval stays native
6. MoE remains isolated

## Immediate Next Changes After This Plan

1. run the artifact prep scripts and verify outputs
2. add the sidecar client abstraction and health checks
3. register DeepSeek as the primary local reasoner
4. register Qwen router as the primary local router
5. leave stock Qwen fallback intact until sidecar path is stable
