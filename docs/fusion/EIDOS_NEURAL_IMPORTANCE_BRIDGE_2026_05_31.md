---
state: candidate-canon
created_on: 2026-05-31
source_prompt: user request to bind Eidos/search embeddings to neural parameter and dynamic-compute routing
status: architecture doctrine; no runtime promotion without falsifiers
promotion_rule: Pro Research until Eidos evidence, NeuralImportance route cards, dynamic compute controls, and visible AnswerPacket traces pass local harnesses
---

# Eidos Neural Importance Bridge

This is the bridge between the search brain and the model-state brain.

Eidos is not only a citation lock. It is the evidence selector. The next
extension is that Eidos also becomes a route-prior selector for neural
substrate objects: weight pages, heads, MLP blocks, adapter slices, KV pages,
prompt caches, controller kernels, and verifier tools.

The canonical idea is:

```text
Eidos finds the evidence and task meaning.
NeuralImportanceAtlas maps that meaning to useful neural support.
ActiveAssembly wakes the minimal complete set.
RuntimeRouter executes only admitted routes.
AnswerPacket shows the evidence, route, uncertainty, and witness.
```

UAS remains the primitive. Every note chunk, evidence hit, graph node, KV page,
adapter, model block, route card, verifier result, and AnswerPacket must have a
stable address before it can be selected.

## Ambition Lock

Do not start from "this cannot work on 16 GB." Start from the stronger local
substrate hypothesis:

```text
The SSD/AppColdStore atlas can hold far more cognition than RAM.
The runtime wins by selecting the right cold pieces before they become hot.
```

This includes per-layer, per-block, per-head, adapter, KV-page, prompt-cache,
and future parameter-component selection. The size of the cold atlas is not the
same bottleneck as the size of the hot working set.

## Rigor Lock

Do not claim SSD is RAM. UAS makes cold bytes addressable and comparable; it
does not erase latency. The win must come from:

- Eidos/embedding route priors;
- contiguous AppColdStore layout;
- prewarm while the user reads or types;
- warm cache reuse;
- query-aware KV/page selection;
- dynamic compute gates;
- verifier-guided repair;
- active-byte accounting; and
- visible falsifier witnesses.

## The Route

```text
User intent
  -> Eidos query packet
  -> evidence hits + why_matched + citation tokens
  -> TaskSignature embedding
  -> NeuralImportanceAtlas lookup
  -> ParamRouteCard / AppColdStoreRouteCard
  -> ActiveAssembly minimal support set
  -> RuntimeRouter chooses controller / model / tool / kernel lane
  -> optional layer/KV/adapter interrupt checkpoints
  -> Eidos post-validation
  -> SCOPE-Rex/SovereignGate admission
  -> RunEventLog + AnswerPacket
```

The model is not asked to guess its own substrate. The app asks Eidos what the
task is about, uses that typed evidence to query the neural atlas, and wakes a
bounded support set under policy.

## Dynamic Embedding Engine

The bridge needs more than document embeddings. It needs typed embeddings over
substrate objects:

| Embedding object | Purpose |
|---|---|
| `EvidenceEmbedding` | Note/chunk/graph/query meaning, produced by Eidos/VaultRecall. |
| `TaskSignatureEmbedding` | Compact representation of the current user intent, claim kinds, privacy, tools, and latency/memory budget. |
| `UnitAffinityEmbedding` | Offline profile of a head, MLP block, weight page, adapter slice, KV page, or kernel. |
| `FailureModeEmbedding` | What kind of mistake this unit helps or causes: citation miss, math drift, code fail, shallow reasoning, hallucination. |
| `VerifierRegretEmbedding` | How much the unit improved or harmed verified outcomes on prior tasks. |

The lookup target is not "nearest parameter." It is:

```text
argmax support_set utility
  subject to hot bytes, warm bytes, cold reads, latency, WBO, and rollback.
```

## Eidos As Neural Route Prior

Eidos should emit a route-prior packet alongside normal evidence:

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

This is not a citation. It is a planning hint. The route is not admitted until
the `ParamRouteCard` or `AppColdStoreRouteCard` passes SCOPE-Rex/SovereignGate
policy and the relevant falsifier.

## Dynamic Compute Controls

The "pause/resume layer dynamics" idea should become explicit checkpoints, not
arbitrary hidden interrupts inside a matmul:

| Control | Meaning | Status |
|---|---|---|
| `EarlyExitCheckpoint` | Stop at an intermediate layer when confidence/verifier margin is enough. | Pro Research; LayerSkip-like models only. |
| `SelfSpeculativeCheckpoint` | Use shallow layers to draft, deeper layers to verify. | Pro Research. |
| `DepthBudgetGate` | Spend transformer blocks only on tokens/routes that need them. | Pro Research; Mixture-of-Depths-style. |
| `KVRestoreCheckpoint` | Pause before a retrieval/attention step and restore likely KV pages. | Pro Gated candidate after KV falsifier. |
| `AdapterSwapCheckpoint` | Wake/swap adapter slices between planning, citation, math, code, or repair phases. | Pro Research. |
| `EidosInterruptCheckpoint` | Pause generation to retrieve missing evidence or contradiction context. | Product candidate only when visible in RunEventLog. |
| `VerifierRepairCheckpoint` | Retry with a new support set after citation/schema/test failure. | Pro Gated candidate; must be bounded. |
| `ControllerSSMCheckpoint` | Use a small SSM/semiseparable controller to decide whether to continue, retrieve, wake more units, or exit. | Pro Research. |

These controls must be user-visible as RunEventLog events when they affect an
answer or mutation.

## Research Intake Map

These external projects are source handles, not product proof:

| Source | Buildable mechanism for Epistemos |
|---|---|
| Deja Vu contextual sparsity (`arXiv:2310.17157`, `FMInference/DejaVu`) | Predict input-dependent heads/MLP blocks before running all units. |
| PowerInfer (`arXiv:2312.12456`, `Tiiny-AI/PowerInfer`) | Hot/cold neuron locality and hybrid hot-resident/cold-fallback planning. |
| Apple `LLM in a Flash` (`arXiv:2312.11514`) | Flash/AppColdStore layout and bundled reads for models larger than DRAM. |
| H2O (`arXiv:2306.14048`, `FMInference/H2O`) | Heavy-hitter KV retention and recent-token balance. |
| Quest (`arXiv:2406.10774`, `mit-han-lab/Quest`) | Query-aware KV page selection instead of loading the whole cache. |
| SparQ Attention (`arXiv:2312.04985`) | Selective fetching of cached history to reduce memory bandwidth. |
| MInference (`arXiv:2407.02490`, `microsoft/MInference`) | Dynamic sparse attention for long-context prefill. |
| LayerSkip (`arXiv:2404.16710`, `facebookresearch/LayerSkip`) | Early exit and self-speculative decoding with layer dropout training. |
| Mixture-of-Depths (`arXiv:2404.02258`) | Token/layer-level dynamic compute budgets. |
| Mamba-2 / SSD (`arXiv:2405.21060`) | Semiseparable/SSM controller lane for cheap route and memory decisions. |
| Titans (`arXiv:2501.00663`) | Test-time neural memory lane; keep as research until stability falsifiers pass. |

Primary source anchors inspected for this bridge:

- Deja Vu: <https://arxiv.org/abs/2310.17157>, <https://github.com/FMInference/DejaVu>
- PowerInfer: <https://arxiv.org/abs/2312.12456>, <https://github.com/SJTU-IPADS/PowerInfer>
- Apple LLM in a Flash: <https://arxiv.org/abs/2312.11514>
- PagedAttention/vLLM: <https://arxiv.org/abs/2309.06180>
- H2O: <https://arxiv.org/abs/2306.14048>, <https://github.com/FMInference/H2O>
- Quest: <https://arxiv.org/abs/2406.10774>, <https://github.com/mit-han-lab/Quest>
- SparQ: <https://arxiv.org/abs/2312.04985>
- MInference: <https://arxiv.org/abs/2407.02490>, <https://github.com/microsoft/MInference>
- LayerSkip: <https://arxiv.org/abs/2404.16710>, <https://github.com/facebookresearch/LayerSkip>
- Mixture-of-Depths: <https://arxiv.org/abs/2404.02258>
- Mamba-2 / SSD: <https://arxiv.org/abs/2405.21060>
- Titans: <https://arxiv.org/abs/2501.00663>
- MLX shared-memory runtime: <https://ml-explore.github.io/mlx/>
- Parameter Golf: <https://github.com/openai/parameter-golf>

The mathematical framing is a constrained active-support problem, not a claim
that any single paper proves Epistemos. The useful external pattern is:
predictive sparsity plus page/block selection plus verifier feedback plus
budgeted compute. EML stays one Primitive-IR chart for formal/numeric
expressions; UAS remains the identity primitive.

## Required Falsifiers

`F-Eidos-NeuralRoute-Prior`

- Eidos route priors must beat random/static priors for predicting useful
  adapter/KV/weight-page families on held-out tasks.

`F-ParamRouteCard-Admission`

- A route card must bind UAS addresses, active bytes, verifier stack,
  rollback, ProductBuild, ProStatus, and witness before neural units wake.

`F-DynamicCompute-Checkpoint`

- Early exit, self-speculation, depth gating, or Eidos interrupts must improve
  quality/cost versus a fixed-depth baseline and must be visible in RunEventLog.

`F-NeuralImportanceAtlas`

- Contextual + verifier-regret routing must beat random, magnitude-only, and
  static saliency baselines under the same memory budget.

`F-HotRent-Stability`

- Hot residency must not thrash across adjacent prompts unless task signature
  or evidence context changes.

`F-Eidos-PostValidation-Repair`

- Bounded retries must improve citation/schema/test validity without causing
  latency spirals or hidden mutation.

## Product Rule

This bridge is not a new top-level organ. It nests under:

```text
Eidos / Recall
  -> NeuralImportanceAtlas route priors
  -> ActiveAssembly support selection
  -> RuntimeRouter execution
  -> RunEventLog + AnswerPacket visibility
```

Any implementation that creates an ungoverned `AgentSearch`, `AgentMemory`,
`AgentEvidence`, or `AgentParamRouter` as a separate authority is drift. The
only acceptable adapter is one that calls Eidos, UAS/AppColdStore,
NeuralImportanceAtlas, ActiveAssembly, SCOPE-Rex/SovereignGate, and
AnswerPacket in that order.
