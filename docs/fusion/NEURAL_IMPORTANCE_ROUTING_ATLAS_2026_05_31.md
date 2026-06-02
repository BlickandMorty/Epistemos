---
state: candidate-canon
created_on: 2026-05-31
source_prompt: deep research + creative brainstorm for important weights / parameter routing
status: architecture doctrine; speculative mechanisms require local falsifiers
---

# Neural Importance Routing Atlas

## Core claim

The next breakthrough is not merely choosing a model. It is choosing the right
neural support set for the current task:

> **The best local route is the smallest active set whose marginal utility
> survives verification under the memory budget.**

For Epistemos, an "important parameter" is not globally important. It is
important relative to:

- the user's task;
- the current evidence graph;
- the controller's hidden state;
- the KV/cache state;
- the selected adapters;
- the available memory budget;
- the verifier stack; and
- the cost of waking the unit.

Therefore the target architecture is a `NeuralImportanceAtlas`: a living map
from task signatures to useful heads, MLP channels, weight blocks, LoRA rank
slices, KV pages, adapters, experts, kernels, and verifier tools.

Eidos is the front door into this atlas. Eidos should turn the user query and
retrieved evidence into a typed `EidosRoutePrior`; the atlas should use that
prior to choose neural support candidates. The model should not be asked to
invent its own hidden parameter route.

## The law

### L10-Candidate: Counterfactual Utility Law

A neural unit should be hot only when its expected verifier-improving marginal
utility is greater than its memory, latency, and interference cost.

```text
U(u | q, S) =
  E[VerifierScore(q, S + u) - VerifierScore(q, S)]
  - lambda_memory * HotBytes(u)
  - lambda_latency * WakeCost(u)
  - lambda_risk * MutationOrDriftRisk(u)
  - lambda_noise * Interference(u, S)
```

Where:

- `u` is a selectable unit: head, MLP row block, adapter rank slice, KV page,
  expert block, kernel, evidence packet, or verifier.
- `q` is the task signature.
- `S` is the already-selected active support set.
- `VerifierScore` is task-dependent: citation correctness, Lean/schema pass,
  code test pass, exact recall, math answer, or human-accepted mutation.

This law supersedes raw saliency. A high-magnitude weight can be irrelevant
for a task; a small adapter slice can be decisive; a KV token can be useful
only because it prevents a false citation.

## Research signals to combine

| Research line | Signal extracted | Epistemos interpretation |
|---|---|---|
| AWQ | activation statistics identify salient weight channels; protect a tiny fraction of weights | Static saliency prior for `WeightBlockImportance`. |
| Wanda / SparseGPT | weight magnitude times activation norm; limited second-order correction | Cheap offline pruning/importance score for blocks. |
| SpQR | isolate quantization-sensitive outlier weights | Outlier preservation and mixed-codec page layout. |
| DejaVu | predict input-dependent attention heads and MLP parameters | Runtime contextual sparsity predictor. |
| PowerInfer | hot neurons follow activation locality, while cold neurons vary by input | Hot-rent prior plus cold fallback. |
| Apple LLM in a Flash | windowing + row-column bundling reduce flash transfers and make reads contiguous | Coactivation bundle packing for ColdStore. |
| Apple ANE/Core ML transformer guidance | ANE wants supported compiled graph shapes, channels-first/4D layouts, fewer reshapes, fewer copies, and chunked attention | ANE lane for scout/router/classifier blocks, not arbitrary custom kernels. |
| MLX / Metal / MPS | Apple Silicon unified-memory tensor runtime and custom GPU compute surfaces | Execution lane for custom KV, PageGather, block-scan, quantized matmul, and graph kernels. |
| H2O / SnapKV / PyramidKV / StreamingLLM | token/KV importance via heavy hitters, sinks, recency, pyramidal budgets | KV page importance and eviction policy. |
| MHA2MLA / TransMLA | low-rank latent KV compression | First-class `LatentKVPage` objects. |
| S-LoRA / LoRAX / PEFT Arrow | many adapters can be paged/routed; token-wise adapter routing is possible | Adapter bank as a ColdStore organ. |
| X-LoRA / MoLoRA / LORAUTER | query/task-aware adapter composition | TaskSignature-to-adapter routing. |
| TransformerLens / SAE Lens / Goodfire-style SAEs | activations can be decomposed into features/circuits | Feature/circuit priors, not product truth without ablation. |
| Quest / SparQ / MInference | query-aware or dynamic sparse attention selects the cache/history pages worth fetching | Eidos/TaskSignature-conditioned KV and prompt-page lookup. |
| LayerSkip | early exit and self-speculative decoding expose useful layer checkpoints | `EarlyExitCheckpoint` and `SelfSpeculativeCheckpoint` candidates. |
| Mixture-of-Depths | dynamic token/layer compute budgets | `DepthBudgetGate` candidate under visible runtime policy. |
| Mamba-2 / SSD | semiseparable state-space duality gives a cheap controller family | Helper SSM lane for route, interrupt, and memory decisions. |
| Titans / test-time memory | neural memory can update during inference | Session-local memory lane only; never silent durable weight mutation. |

## Apple Silicon execution split

The Apple-hardware breakthrough is not "put everything on the ANE." The
correct split is a heterogenous route:

| Lane | What belongs there | What does not belong there |
|---|---|---|
| ANE / Core ML | compiled scout models, task classifiers, embedding reducers, saliency predictors, small adapter routers, distilled verifier heads | arbitrary Rust kernels, arbitrary Metal shaders, live Python control flow, unverified private ANE paths |
| MLX / MPS / Metal | custom tensor execution, KV paging kernels, PageGather, block scan, quantized matmul, coactivation bundle unpacking, graph kernels | proof search, high-level route governance, note mutation authority |
| Rust substrate kernel | memory maps, UAS addresses, residency plans, hot-rent ledger, scheduler, FFI, zero-copy ownership discipline | proof invention, UI policy, hidden model judgment |
| Lean / schema workers | `AnswerPacket`, route-card schema, theorem status, proof artifacts, falsifier contracts, build-time generated types | latency-critical token generation or per-token route decisions |
| Swift app shell | user-visible state, consent, mutation review, note graph, inspector surfaces | hidden architecture authority |

This matters because the ANE is powerful but constrained. Treat it as a
compiled neural appliance for small, stable, high-value subgraphs. Let it
answer questions like:

- "Which route class is this task?"
- "Which adapter family should wake?"
- "Which KV pages are likely needed?"
- "Is this claim likely citation-bound, proof-bound, code-bound, or chat-only?"

Do not ask the ANE to be the whole local LLM substrate. The custom substrate
work belongs in Rust plus Metal/MLX, with Lean supervising semantics and
SCOPE-Rex supervising admission.

### Candidate hardware route

```text
User task
  -> Swift builds TaskSignature
  -> Rust kernel queries NeuralImportanceAtlas
  -> Core ML / ANE scout predicts route family
  -> Rust solves memory-budgeted active-set plan
  -> SCOPE-Rex admits ParamRouteCard
  -> MLX/Metal executes selected controller + KV/weight/adapters
  -> Lean/schema/tests/citation verifiers check the result
  -> HotRentLedger updates residency
```

The hard rule is that every lane must be measured separately. If an ANE scout
adds transfer overhead greater than the route savings, it should be removed or
batched. If a Metal kernel wins only on tiny cache-resident inputs, it is not a
ColdStore proof. If Lean proves a schema but the runtime ignores the schema
hash, the proof does not govern the app.

## App-owned ColdStore

The model should not merely "live somewhere on disk." For Pro research builds,
Epistemos should promote model files, adapters, KV snapshots, activation
sketches, and page bundles into an app-owned substrate store.

Current local precedent:

- `NoteFileStorage` already keeps managed note bodies in Application Support.
- `LocalModelPaths` already installs local models under the app's Application
  Support model root.
- `SSMStateService` already persists MLX prompt-cache / compressed-context
  artifacts under `ssm_cache`.
- `AppGroupContainer` already defines a shared root, blob directory, mmap arena,
  provenance DB, vault index DB, temp directory, and log directory for shared
  substrate state.

This does **not** make storage physically as fast as RAM. The win is that the
app controls layout, indexing, warming, eviction, and copy boundaries.

### `AppColdStore` tiers

| Tier | Location class | Contents | Rule |
|---|---|---|---|
| Durable atlas | Application Support / App Group root | installed models, packed weight pages, adapter banks, manifests, hashes, licenses | Required to operate; never purge silently. |
| Warm cache | Caches directory or app cache subroot | decoded page bundles, coactivation packs, ANE scout outputs, reusable prompt/KV summaries | Regenerable; may be evicted. |
| Hot runway | mmap arena / resident buffers / Metal heaps | active weight pages, active KV strip, active adapters, route scratch | Strict byte budget; no unbounded growth. |
| Staging | app staging root | downloads, repacks, verification temp files | Must be atomic and discardable on failure. |

SwiftData should not store giant weight/KV blobs. It should store manifests,
route cards, hashes, provenance, and user-visible state. The large bytes live
as files whose layout is chosen for the scheduler.

### Why this can be faster

App ownership can improve effective speed by:

1. Repacking Hugging Face / MLX snapshots into page-aligned coactivation
   bundles instead of reading arbitrary original checkpoint order.
2. Keeping a manifest from UAS address -> byte range -> codec -> coactivation
   neighbors -> verifier history.
3. Prewarming the next likely bundles during idle time or while the user is
   reading a note.
4. Separating durable files from purgeable caches so the app can rebuild warm
   caches without redownloading or corrupting the canonical atlas.
5. Avoiding SwiftData blob bloat and letting Rust/Metal/MLX use direct file,
   mmap, or buffer-oriented paths where measured.
6. Recording cache misses as planner failures, so the atlas learns which pages
   should have been promoted earlier.

### Candidate layout

```text
Application Support/Epistemos/
  Models/
    manifests/install-state.json
    text/active/<model-slug>/
    coldstore/
      atlases/<model-id>/manifest.json
      weight_pages/<model-id>/<bundle-id>.epwp
      adapters/<adapter-id>/<slice-id>.epla
      kv_seeds/<model-id>/<session-class>.epkv
  ssm_cache/
    <model-id>/*.safetensors
    <model-id>/compressed_context/*.json
  substrate/
    neural_importance_atlas.sqlite
    hot_rent.sqlite
    interference.sqlite
    route_cards/*.json

Caches/Epistemos/
  coldstore_warm/
    decoded_pages/
    coactivation_packs/
    ane_scout_outputs/
    kv_replay_summaries/
```

If an App Group container is active, shared substrate bytes should move to the
group root so future helper processes or extensions can use the same blobs
without duplicating the atlas. MAS must use only sandbox-safe storage roots and
must tolerate cache purges.

### `AppColdStoreRouteCard`

```text
AppColdStoreRouteCard {
  task_signature
  durable_units
  warm_cache_units
  hot_runway_units
  byte_ranges
  codecs
  mmap_eligible
  metal_buffer_plan
  ane_scout_cache_key
  expected_prefetch_ms
  cache_rebuild_policy
  verifier_stack
  rollback
}
```

This makes the storage layer part of routing. The scheduler does not just ask
"which weights matter?" It asks:

> Which pages should be durable, which should be warm, which should be hot, and
> which should not be touched for this task?

## Composite importance score

Epistemos should not rely on one importance metric. Use a weighted ensemble:

```text
Importance(u, task, state) =
  a1 * StaticSaliency(u)
  + a2 * ContextualActivationPred(u | state)
  + a3 * HotRentPrior(u)
  + a4 * KVOrEvidenceUtility(u | task)
  + a5 * AdapterTaskSimilarity(u | task)
  + a6 * MechanisticFeatureMatch(u | task)
  + a7 * VerifierRegretReduction(u | task)
  + a8 * ReuseHorizon(u)
  - b1 * HotBytes(u)
  - b2 * WakeLatency(u)
  - b3 * FragmentationCost(u)
  - b4 * InterferenceRisk(u, active_set)
```

The coefficients should be learned by a conservative bandit or calibrated
offline from retained traces. Until that exists, use rule-based weights with
explicit provenance.

## New architecture objects

### `TaskSignature`

Compact fingerprint of the current request.

```text
TaskSignature {
  semantic_embedding
  claim_kinds
  required_verifiers
  domain_tags
  citation_need
  code_or_math_need
  privacy_policy
  latency_budget
  memory_budget
}
```

### `NeuralImportanceAtlas`

Persistent atlas over selectable neural units.

```text
NeuralImportanceAtlas {
  unit_id
  unit_kind: head | mlp_block | weight_page | kv_page | adapter_slice | expert | kernel
  uas_address
  codec
  static_saliency
  activation_profile
  task_affinity
  verifier_history
  hot_rent_score
  interference_edges
  coactivation_bundle
  rollback_ref
}
```

### `ActivationSketch`

Low-cost runtime observation used before expensive routing.

```text
ActivationSketch {
  prompt_hash
  first_layer_summary
  controller_state_summary
  predicted_heads
  predicted_mlp_blocks
  predicted_kv_pages
  uncertainty
}
```

### `EidosRoutePrior`

Eidos-derived route hint. It can propose neural support families, but cannot
admit them.

```text
EidosRoutePrior {
  task_signature
  evidence_ids
  citation_need
  domain_tags
  contradiction_hints
  likely_verifiers
  likely_adapter_families
  likely_kv_regions
  likely_weight_page_families
  confidence
  why_matched
}
```

### `DynamicComputeCheckpoint`

Visible interruption points in the runtime. These are policy events, not
hidden mid-kernel pauses.

```text
DynamicComputeCheckpoint {
  checkpoint_kind:
    early_exit
    | self_speculative
    | depth_budget
    | kv_restore
    | adapter_swap
    | eidos_interrupt
    | verifier_repair
    | controller_ssm
  trigger
  active_units_before
  active_units_after
  verifier_reason
  latency_budget_remaining
  run_event_id
}
```

### `ParamRouteCard`

The thing SCOPE-Rex admits before a model-state route can run.

```text
ParamRouteCard {
  task_signature
  active_units
  hot_bytes
  warm_bytes
  cold_bytes
  expected_wake_latency
  verifier_stack
  fallback_route
  rollback
}
```

### `HotRentLedger`

Residency economy for model pieces.

```text
HotRentLedger {
  unit_id
  recent_uses
  verifier_wins
  verifier_losses
  average_wake_cost
  average_utility
  rent_expires_at
}
```

Units earn hot residency by repeated verified utility. They lose residency
when they stop helping or when they interfere with better active sets.

### `InterferenceLedger`

Records when units make each other worse.

```text
InterferenceLedger {
  unit_a
  unit_b
  task_class
  observed_failure_mode
  verifier_delta
}
```

This matters because "more important parameters" can be worse than a smaller
clean set. The atlas should learn what to exclude.

## Route algorithm

### Phase 1: Offline cartography

Run curated task suites over the local controller and candidate models:

1. Collect activation statistics per layer/head/MLP block.
2. Compute static saliency: AWQ-like activation-channel stats, Wanda-like
   weight-by-activation norms, SpQR-like outlier sensitivity, and optional
   Hessian/GPTQ approximations where cheap enough.
3. Train or fit tiny contextual predictors: given a layer input sketch,
   predict useful heads/MLP blocks/KV pages/adapters.
4. Cluster coactivated units into contiguous bundles so ColdStore reads fewer,
   larger pages.
5. Associate each bundle with task tags, verifier outcomes, WBO cost, and
   rollback.

Output: `NeuralImportanceAtlas`.

### Phase 2: Runtime scout pass

Before full generation:

1. Build `TaskSignature`.
2. Retrieve likely evidence and prior tasks.
3. Run a tiny controller/scout pass that emits `ActivationSketch`.
4. Predict candidate active units.
5. Solve a budgeted selection problem:

```text
maximize expected_verifier_utility(active_set)
subject to hot_bytes + kv_bytes + runtime_bytes <= memory_budget
and wake_latency <= latency_budget
```

This is a submodular/knapsack-shaped problem. The first implementation can be
greedy with diversity penalties; later versions can learn a policy.

### Phase 3: SCOPE-Rex admission

The route does not execute until SCOPE-Rex sees:

- active units;
- memory budget;
- verifier stack;
- fallback route;
- rollback;
- privacy/data policy; and
- product status.

### Phase 4: Execute + verify + learn

After execution:

1. Compare result to verifier stack.
2. Record which units were useful, useless, or harmful.
3. Run occasional counterfactual probes on small held-out traces:
   `active_set - unit`, `active_set + backup_unit`, `adapter_A` vs
   `adapter_B`.
4. Update `HotRentLedger`, `InterferenceLedger`, and atlas priors.
5. If repair traces repeat, send them to `AdapterDistillery`.

## Creative mechanisms worth testing

### 1. Verifier-lifted saliency

Instead of asking "which weights predict next-token perplexity," ask:

> Which units most reduce downstream verifier failure?

For Epistemos, a unit is valuable if it improves citations, proof validity,
code tests, factual consistency, or note mutation quality. This is the key
move that makes the app different from ordinary model compression.

### 2. Dense shadow oracle sampling

Occasionally compare a cheap active route against a denser or cloud/reference
route on retained prompts. Measure `neural_regret`:

```text
neural_regret = verifier_score(reference) - verifier_score(active_route)
```

High regret teaches the atlas which missing units/adapters/KV pages mattered.
Low regret proves the active set was enough.

### 3. Negative-space routing

Keep track of units that consistently hurt a task class. Some weights may add
style drift, false confidence, citation noise, or domain contamination. The
best active set is sometimes the one that excludes a tempting adapter.

### 4. Citation-conditioned routing

Retrieved evidence should influence model-state selection. If the current note
cluster is neuroscience, use the neuroscience adapter and relevant evidence
features; if it is Lean/math, choose math/proof adapters and stricter verifier
paths. The route is evidence-conditioned, not merely prompt-conditioned.

### 5. Feature-to-adapter bridge

Use SAE/feature activations as router hints. If a task activates a cluster of
features associated with proof repair or citation discipline, the adapter
router can choose matching LoRA slices. This is a bridge between mechanistic
interpretability and practical adapter routing.

### 6. Coactivation page packing

Apple's flash lesson is not "read from SSD token by token." It is "make reads
larger, fewer, and better predicted." Pack weights/KV/adapters by coactivation,
not by original checkpoint order, for ColdStore research builds.

App-owned ColdStore makes this practical: the canonical model snapshot remains
hash-verified, while Epistemos creates scheduler-native packs that are sorted
by observed coactivation, route class, and verifier utility.

### 7. Layer-staggered routing

Do not route all layers with one decision. Early layers can use stable hot
bundles, middle layers can be contextual, and late layers can be verifier/task
specialized. This reduces router overhead while preserving adaptivity.

### 8. Adapter path stitching

Do not choose one whole adapter when a task is mixed. Choose rank slices or
layer segments from multiple adapters:

```text
math proof adapter: layers 12-20
citation adapter: layers 21-26
style adapter: output-facing low-rank slice only
```

This stays Pro Research until adapter interference is measured.

### 9. Hot-rent market

Treat hot memory as rented space. Units pay rent with recent verified utility.
When memory pressure rises, evict the units with lowest utility per byte.

### 10. Failure-triggered expansion

Start small. If the verifier fails, expand along the failure axis:

| Failure | Expansion |
|---|---|
| citation missing | add evidence pages + citation adapter |
| proof gap | add proof adapter + Lean verifier budget |
| code test fail | add code adapter + tool plan |
| hallucinated claim | add stricter Eidos retrieval + contradiction graph |
| reasoning shallow | add self-consistency traces, not necessarily more parameters |

## How this can beat ordinary MoE

Ordinary MoE asks: **which model experts should process this token?**

Epistemos asks the larger question:

> Which complete support set makes this task correct under this hardware
> budget?

That support set can include:

- model heads and MLP blocks;
- selected adapters or adapter slices;
- KV pages and latent KV summaries;
- retrieved evidence packets;
- note/claim graph neighborhoods;
- Lean/schema/code/citation verifiers;
- Metal kernels;
- ANE scout heads; and
- fallback routes.

This can be better than MoE only when it wins a falsifier. The claim is not
"more experts are better." The claim is:

```text
verified_task_score / active_hot_byte
```

should improve when routing is done across the whole cognitive substrate
instead of only inside the model graph.

MoE routes conditional computation. Epistemos routes conditional support.
That is the difference.

## Falsifier targets

### F-NeuralImportanceAtlas

Passes only if the atlas predicts active units that beat random and static
baselines under the same memory budget.

Required comparisons:

- random active set;
- magnitude-only active set;
- AWQ/Wanda-style static saliency set;
- contextual predictor set;
- contextual + verifier-regret set.

### F-Eidos-NeuralRoute-Prior

Passes only if Eidos route priors improve neural support prediction versus
non-Eidos baselines.

Required comparisons:

- random route prior;
- task-label-only prior;
- embedding-only prior;
- Eidos evidence + `why_matched` prior;
- Eidos evidence + verifier-regret prior.

Required metrics:

- adapter/KV/weight-page family recall;
- verifier score;
- citation validity;
- active bytes;
- latency;
- fallback count;
- visible route explanation quality.

### F-DynamicCompute-Checkpoint

Passes only if checkpointed execution improves quality/cost over fixed-depth
execution and every checkpoint that affects output is visible in RunEventLog.

Required comparisons:

- fixed-depth baseline;
- early-exit route;
- self-speculative route;
- depth-budget route;
- Eidos-interrupt repair route;
- helper-SSM controller route.

### F-ActiveSet-Utility

Passes only if selected active sets improve task score per byte over dense or
naive local baselines on held-out tasks.

Required metrics:

- verifier score;
- peak RSS;
- hot bytes;
- cold bytes;
- latency;
- active unit count;
- fallback count;
- neural regret.

### F-AdapterRoute-Composition

Passes only if routing or composing adapters beats the best single adapter and
base model on mixed-domain tasks without unacceptable interference.

### F-KV-Importance-Parity

Passes only if KV page retention/eviction preserves recall, citations, or
reasoning outcomes under a declared WBO budget.

### F-HotRent-Stability

Passes only if the rent policy avoids oscillation: hot sets should not thrash
across adjacent prompts unless the task signature actually changes.

### F-AppleSilicon-RouteSplit

Passes only if the heterogeneous Apple route beats a simpler local baseline
under the same task set and memory budget.

Required comparisons:

- MLX/Metal-only baseline;
- Core ML/ANE scout + MLX/Metal execution;
- Rust rule-based router without scout;
- Rust + ANE scout + verifier-regret feedback.

Required metrics:

- route accuracy;
- end-to-end latency;
- ANE/Core ML dispatch overhead;
- GPU active time;
- peak RSS;
- hot bytes;
- transfer/copy count;
- verifier score;
- fallback count.

The ANE route is accepted only if it improves route quality or total cost
after its dispatch and transfer costs are included.

### F-AppColdStore-Layout

Passes only if app-owned packed storage improves effective route cost over the
raw installed snapshot layout without changing model outputs beyond the
declared WBO budget.

Required comparisons:

- raw installed model snapshot;
- app-owned durable atlas without warm cache;
- app-owned durable atlas plus warm cache;
- app-owned durable atlas plus predictive prewarm.

Required metrics:

- first-token latency;
- page-fault count or proxy miss count;
- bytes read;
- number of read spans;
- hot bytes;
- warm cache bytes;
- peak RSS;
- checksum / manifest verification;
- output delta against baseline;
- cache rebuild time after purge.

The layout wins only if it improves measured cost while remaining rebuildable
from durable, verified artifacts.

## Build/status placement

| Mechanism | Status |
|---|---|
| Static saliency atlas over small local model | Pro Research |
| TaskSignature + AdapterRegistry route | Pro Research -> Pro Gated after eval |
| KV importance parity harness | Pro Gated candidate |
| Verifier-lifted saliency | Pro Research |
| ANE/Core ML scout router | Pro Research -> Pro Gated only after `F-AppleSilicon-RouteSplit` |
| Rust residency scheduler | Pro Research -> Pro Gated when copy counts and rollback pass |
| Metal/MLX KV and weight-page kernels | Pro Research -> Pro Gated per-kernel falsifier |
| Lean route-card schema authority | Pro Gated candidate; never hot-path proof search |
| App-owned ColdStore layout | Pro Research -> Pro Gated after `F-AppColdStore-Layout` |
| Feature-to-adapter bridge | Pro Vault-Preserved / Pro Research |
| Weight-block page packing | Pro Research |
| Live parameter/circuit routing | Pro Omega until falsified upward |
| MAS route selection | Only for fully measured, safe, deterministic defaults |

## Source handles

Primary handles used for this doctrine:

- `arXiv:2310.17157` Deja Vu — contextual sparsity and low-cost predictors.
- `arXiv:2306.00978` AWQ — activation-aware salient channel protection.
- `locuslab/wanda` — weight magnitude times activation norm pruning.
- `arXiv:2306.03078` SpQR — isolate quantization-sensitive outlier weights.
- `arXiv:2312.12456` PowerInfer — hot/cold neuron locality.
- Apple `LLM in a Flash` — windowing and row-column bundling for flash.
- `arXiv:2406.10774` Quest — query-aware KV cache selection.
- `arXiv:2312.04985` SparQ Attention — selective cached-history fetch.
- `arXiv:2407.02490` MInference — dynamic sparse attention for long prefill.
- `arXiv:2404.16710` LayerSkip / `facebookresearch/LayerSkip` — early exit and self-speculative decoding.
- `arXiv:2404.02258` Mixture-of-Depths — token/layer-level dynamic compute allocation.
- `arXiv:2405.21060` Mamba-2 / state-space duality — helper SSM controller lane.
- `arXiv:2501.00663` Titans — test-time neural memory candidate.
- Apple Core ML / MLComputeUnits — public CPU/GPU/ANE execution surface.
- Apple Machine Learning Research `Deploying Transformers on the Apple Neural Engine` — ANE transformer layout/copy principles.
- Apple MLX — unified-memory ML array/runtime lane for Apple Silicon.
- Apple Metal Performance Shaders — GPU-side ML/compute primitives.
- Apple `Using the File System Effectively` / `applicationSupportDirectory` / `cachesDirectory` — durable support files vs purgeable cache files.
- Apple `Data.ReadingOptions.mappedIfSafe` — Foundation-level mmap hint for file-backed data when safe.
- `FMInference/H2O` — heavy-hitter KV retention.
- `Zefan-Cai/KVCache-Factory` — PyramidKV/SnapKV/H2O/StreamingLLM comparison framework.
- `arXiv:2311.03285` S-LoRA — unified paging for adapters and KV cache.
- `arXiv:2601.21795` LORAUTER — task-representation adapter routing.
- `arXiv:2603.15965` MoLoRA — per-token adapter routing.
- Hugging Face PEFT Arrow / GenKnowSub — token-wise adapter routing and adapter-space purification.
- TransformerLens / SAE Lens / OpenAI sparse_autoencoder — activation/circuit feature tooling.

## Final synthesis

Epistemos should learn **which parts of intelligence are worth waking**.

The winning local system is not the one with the largest cold model file. It
is the one with the best importance atlas: the one that can predict, before
spending memory, which small set of parameters, adapters, KV pages, evidence,
tools, and verifiers will make the current task correct.
