# AI Stack Decision Report

## Current State

Epistemos is still on a mixed Apple Intelligence + in-process MLX architecture.

Current live stack:

- SwiftUI shell and orchestration live in [`Epistemos/App/`](/Users/jojo/Epistemos/Epistemos/App)
- chat routing lives in [`TriageService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift)
- prompt assembly and streaming entry points live in [`PipelineService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/PipelineService.swift)
- local inference runs in-process through [`MLXInferenceService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift)
- model catalog and installs are Qwen-only in [`LocalModelInfrastructure.swift`](/Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift)
- runtime/model selection state lives in [`InferenceState.swift`](/Users/jojo/Epistemos/Epistemos/State/InferenceState.swift)
- retrieval is already partly native:
  - GRDB/FTS in [`SearchIndexService.swift`](/Users/jojo/Epistemos/Epistemos/Sync/SearchIndexService.swift)
  - query assembly in [`QueryRuntime.swift`](/Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift)
  - Rust graph search and semantic search in [`graph-engine/src/lib.rs`](/Users/jojo/Epistemos/graph-engine/src/lib.rs)
  - Apple `NLEmbedding` bridge in [`EmbeddingService.swift`](/Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift)

There is no sidecar client, no OpenAI-compatible local serving boundary, no BGE integration, and no role-based model registry yet.

## Artifact Inventory

### Present on disk

Trained adapters:

- DeepSeek DPO:
  - `/Users/jojo/Downloads/deepseek/deepseek-r1-persona-math-dpo/final_adapter`
  - verified base model: `deepseek-ai/DeepSeek-R1-Distill-Llama-8B`
- DeepSeek SFT:
  - `/Users/jojo/Downloads/deepseek/deepseek-r1-persona-math-sft/final_adapter`
- Qwen router 4B:
  - `/Users/jojo/Downloads/Qwen/qwen-router-4b-sft/final_adapter`
  - verified base model: `Qwen/Qwen3-4B`
- Qwen router small:
  - `/Users/jojo/Downloads/Qwen/qwen-router-sft/final_adapter`
  - verified base model: `Qwen/Qwen3-0.6B`

Currently installed stock local models:

- `mlx-community/Qwen3.5-0.8B-4bit`
- `mlx-community/Qwen3.5-2B-4bit`
- `mlx-community/Qwen3.5-4B-4bit`

Install manifest:

- [`install-state.json`](/Users/jojo/Library/Application%20Support/Epistemos/Models/manifests/install-state.json)

### Missing locally

- experimental MoE runtime artifact:
  - `mlx-community/Qwen3-30B-A3B-4bit`
- optional second reasoner:
  - `DeepSeek-R1-Distill-Qwen-14B`
- retrieval models:
  - `BAAI/bge-m3`
  - `BAAI/bge-reranker-v2-m3`
- any normalized fused/converted artifacts for your trained DeepSeek or Qwen adapters

## Current-State Architecture Map

```text
User
  -> SwiftUI views
  -> @Observable state
  -> PipelineService / TriageService
  -> Apple Intelligence OR in-process LocalMLXClient
  -> MLXInferenceService

Retrieval today:
User query
  -> QueryRuntime / SearchIndexService / GraphState.hybridSearch
  -> GRDB FTS + Rust graph search + Apple NLEmbedding vectors
  -> Context assembly in Swift
```

This architecture has two hard limits:

1. heavy model execution is still coupled to the app process
2. retrieval quality is bottlenecked by Apple `NLEmbedding` instead of a purpose-built retrieval stack

## Hard Blockers

1. Trained adapters are not deployable artifacts yet.
   - they are PEFT LoRA adapters
   - they must be merged into their exact base models before MLX conversion

2. The app’s local model registry is family-based, not role-based.
   - it assumes local text model = stock Qwen tier
   - it has no concept of reasoner vs router vs experimental MoE

3. There is no sidecar abstraction.
   - all local LLM execution is still in-process
   - the app has no local SSE client / health checks / model lifecycle boundary

4. Retrieval is already partly Rust-native, but the embedding model is wrong for the target quality bar.
   - current semantic retrieval depends on `NLEmbedding`
   - no reranker exists

5. The current app still resolves “local” around the stock Qwen install flow.
   - even after stripping prompt-steering, the runtime architecture still centers Qwen as the main local model

## Memory-Risk Map

Target machine: around 18 GB unified memory.

Safe-to-feasible on this machine:

- stock Qwen 4B in-process MLX: feasible
- trained Qwen 4B router via sidecar: feasible
- DeepSeek R1 Distill Llama 8B 4-bit via sidecar: feasible with disciplined context and TTL
- BGE-M3 + reranker, if kept outside the main UI process and bounded: feasible

Not acceptable as default resident path:

- large MoE as always-hot resident model
- multi-heavy-model in-process execution
- unbounded context / prompt accumulation
- UI-process execution of heavy reasoner + retrieval inference together

## Recommended V1 Stack

### Chosen architecture

Use a sidecar-first local text stack with native retrieval.

Role map:

- router:
  - trained `Qwen/Qwen3-4B` adapter, converted to MLX
- main reasoner:
  - trained `DeepSeek-R1-Distill-Llama-8B` DPO adapter, merged and converted to MLX
- retriever:
  - `BAAI/bge-m3`
- reranker:
  - `BAAI/bge-reranker-v2-m3`
- experimental tier:
  - `mlx-community/Qwen3-30B-A3B-4bit`, manual only, never auto-routed on the 18 GB target

### Chosen serving boundary

Use an OpenAI-compatible local MLX sidecar for text models.

Why:

- keeps heavy inference out of the Swift UI process
- gives the app one stable client contract: local HTTP + SSE
- preserves a native app shell
- keeps room for later model swaps without rewriting orchestration

### Chosen retrieval boundary

Keep retrieval and reranking inside the Rust-adjacent native path.

Why:

- the graph engine already owns high-value note/graph semantics
- moving note corpora through Python subprocesses would be a regression
- retrieval should stay close to CRDT / graph / block kernels, not bolted on from the side

## Sidecar Candidate Ranking

### 1. `mlx-openai-server`

Primary recommendation for V1.

Why it ranks first:

- focused OpenAI-compatible local server for MLX text models
- explicit streaming support
- supports custom chat templates and parser selection
- narrower runtime surface than a fully general omni server

### 2. official `mlx_lm.server`

Fallback minimal baseline.

Why it ranks second:

- closest to upstream `mlx-lm`
- low conceptual overhead
- good fallback if community server features drift

Why it is not first:

- less opinionated multi-model lifecycle tooling than the best focused sidecar candidates

### 3. `mlxengine`

Good experimental/future option, not the V1 default.

Why it ranks third:

- broader multimodal/omni scope than the current shipping problem needs
- useful later for expanded local stack features

Why it is not first:

- V1 needs a stable text-serving boundary more than a broad omni runtime

### 4. keep everything in-process

Rejected for V1.

Reason:

- wrong memory boundary on the target hardware
- preserves the exact coupling we are trying to remove

## Rejected Alternatives

### All-MLX in-process local stack

Rejected because the app already shows the downside of tight runtime coupling. Even with stripped prompt policy, heavy local inference still competes with the UI process.

### Router in-process, reasoner via sidecar

Rejected for V1 because it fractures the local stack across two serving contracts. The codebase is cleaner if all text generation crosses one client abstraction.

### More training before integration

Rejected because it is not the bottleneck.

What you already have is enough for a strong V1:

- trained DeepSeek DPO
- trained Qwen router
- pretrained BGE-M3
- pretrained BGE reranker

The missing work is artifact normalization and runtime integration.

## Artifact Normalization Plan

### Reasoner

1. verify adapter provenance against `adapter_config.json`
2. fetch the exact base model
3. merge the PEFT adapter into the base model
4. copy/audit tokenizer and chat-template files
5. convert the merged Hugging Face artifact into MLX 4-bit
6. register output path in a machine-readable manifest

### Router

Same flow as the reasoner, but with:

- primary router = Qwen 4B adapter
- fallback router = Qwen 0.6B adapter

### Retrieval assets

1. download `BAAI/bge-m3`
2. download `BAAI/bge-reranker-v2-m3`
3. keep them as source assets first
4. wire actual Rust-native execution in the next phase after artifact setup is locked

## Retrieval Plan

V1 retrieval should not replace the current Rust graph/query stack. It should tighten it.

Plan:

1. keep GRDB FTS and graph search working
2. add BGE-M3 embeddings as a higher-quality semantic layer
3. add reranking before final context assembly
4. keep final context assembly in Swift/Rust boundary code, not Python
5. feed curated evidence to DeepSeek, not raw vault sprawl

## Benchmark Plan

Before rollout gates are opened, benchmark:

- DeepSeek cold load
- DeepSeek warm reuse
- Qwen router TTFT
- retrieval latency without reranker
- retrieval latency with reranker
- retrieval + reasoner round-trip
- cancellation mid-stream
- memory pressure when reasoner and retrieval run back-to-back

## STATE_BLOCK

```text
chosen_architecture = sidecar-first local text serving + native retrieval
chosen_sidecar = mlx-openai-server
chosen_reasoner = deepseek-ai/DeepSeek-R1-Distill-Llama-8B + local DPO adapter
chosen_router = Qwen/Qwen3-4B + local router adapter
chosen_retriever = BAAI/bge-m3
chosen_reranker = BAAI/bge-reranker-v2-m3
missing_artifacts = [
  fused DeepSeek runtime artifact,
  fused Qwen router runtime artifact,
  BGE-M3 local asset snapshot,
  BGE reranker local asset snapshot,
  Qwen3-30B-A3B experimental artifact
]
top_5_risks = [
  base-model mismatch during adapter fusion,
  tokenizer/chat-template drift after merge/convert,
  keeping old Qwen-only assumptions alive in app state,
  blocking the UI thread with local inference,
  over-scoping MoE before DeepSeek path is stable
]
first_implementation_steps = [
  add model manifest,
  add artifact prep scripts,
  add sidecar client abstraction,
  normalize DeepSeek first,
  normalize router second
]
```

## Sources

Official and primary sources guiding this decision:

- `mlx-lm`: https://github.com/ml-explore/mlx-lm
- `mlx-openai-server`: https://github.com/cubist38/mlx-openai-server
- `mlxengine`: https://github.com/justrach/mlxengine
- DeepSeek base model: https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Llama-8B
- Qwen 4B base model: https://huggingface.co/Qwen/Qwen3-4B
- BGE-M3: https://huggingface.co/BAAI/bge-m3
- BGE reranker: https://huggingface.co/BAAI/bge-reranker-v2-m3
- experimental MoE target: https://huggingface.co/mlx-community/Qwen3-30B-A3B-4bit
- local research inputs:
  - [`macOS AI Integration Brief.md`](/Users/jojo/Downloads/macOS%20AI%20Integration%20Brief.md)
  - [`Mac LLM Optimization for Large Models.md`](/Users/jojo/Downloads/Mac%20LLM%20Optimization%20for%20Large%20Models.md)
