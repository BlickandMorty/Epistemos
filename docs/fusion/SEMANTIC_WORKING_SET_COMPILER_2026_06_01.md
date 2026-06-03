---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: recursive browser/bookmark/X intake plus primary validation for UAS, AppColdStore, active cold storage, KV paging, autonomous research loops, Lean/proof routes, and 70B cocktail plausibility
status: architecture doctrine; no product promotion without falsifiers, byte budgets, cold-miss evidence, rollback, and visible proof
---

# Semantic Working-Set Compiler - 2026-06-01

## Thesis

The breakthrough is not "SSD is RAM" and not "model size does not matter" in
isolation. The breakthrough is:

> **Compile every reasoning task into a predicted, budgeted, prefetchable,
> observable semantic working set.**

For Epistemos, the 70B cocktail and active cold storage become plausible when
the app can answer a smaller question before it runs:

```text
What exact notes, source pages, KV pages, adapters, model byte ranges, kernels,
proof tools, route priors, and verifier lanes must be hot or warm for this
mission, and what can remain cold?
```

This reframes UAS/AppColdStore as a compiler and page-table problem. UAS names
the universe. AppColdStore stores and lays it out. Eidos and the bookmark/source
graph shape the task. NeuralImportanceAtlas and constructive residency score
candidate support. Cache lineage remembers what helped before. The working-set
compiler emits the page table and prefetch window that make the run physically
reasonable.

It preserves the ambition: a huge local cognitive substrate can behave like a
small, fast active brain when the right working set is selected.

It preserves the rigor: cold bytes remain cold until a route card, byte budget,
compatibility fence, verifier, fallback, rollback, and visible witness exist.

## Why this exists

The current canon already has the pieces:

- `Cold Trillion, Hot Five Billion, Active Minimum` names the target posture.
- `NeuralImportanceAtlas` predicts useful model/evidence/KV/adapters.
- `Constructive Residency` builds proof-carrying resident assemblies.
- `Cache-Lineage Autoresearch` remembers reusable prefixes, traces, and
  policy wins.
- `Engineering Logic` forces invariants, budgets, failure envelopes, and
  observability.

The missing compiler is the layer that turns those pieces into an execution
plan with page-table semantics:

```text
TaskSignature
  + SourceSignalGraph
  + EidosRoutePrior
  + KVLineageGraph
  + NeuralImportanceAtlas
  + ResidencyConstructionGraph
  -> SemanticWorkingSetPlan
  -> ResidencyPageTable
  -> PrefetchWindow
  -> RuntimeRouter execution
  -> ColdFaultTrace
  -> LayoutPatch / RoutePatch
```

The result is a new doctrine lock: do not ask whether the whole model fits hot.
Ask whether the selected semantic working set fits hot, whether cold pages are
prefetched, whether misses are learned from, and whether the answer proves the
route it took.

Companion trace-observatory source:
`docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md` defines how the
working-set plan becomes inspectable. A `SemanticWorkingSetPlan` must be able
to emit `CognitiveTraceGraph`, `RouteMicroscopeFrame`, `AttentionKVTrace`,
`SourceReasoningOverlay`, `AgentActionFrame`, `TraceComparisonDeck`,
`TelemetryToWorkingSetPatch`, and `VisualProofCapsule` artifacts when its
route shapes user-visible output. Cold misses are failed predictions only if
the trace records which page was predicted, what stalled, what fallback ran,
and what layout or route patch was proposed.

Companion Residency PatternBoost source:
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` defines how
working-set and cold-fault traces become offline assembly tournaments. The
compiler emits one mission plan; Residency PatternBoost searches, repairs,
archives, and distills reusable assembly motifs across many missions so future
working-set plans start from proven held-out winners instead of raw recency or
embedding-only guesses.

## Bookmark intake translated into doctrine

| Source handle | Signal | Canonical interpretation |
|---|---|---|
| Arc bookmarks: `karpathy/autoresearch`, Kimi/Kimi CLI, ResearchRabbit, Consensus, NotebookLM, Helios attention-as-interrupt | The user's saved research cluster is about autonomous experiment loops, source-grounded research, code agents, and evidence maps. | Browser/bookmark/source traces become `SourceSignalGraph` inputs, not product authority. They rank source motifs and route priors. |
| X bookmarks: KV cache threads | Local LLM performance is often blocked by KV cache and context state, not only weight size. | The compiler must budget KV bytes separately from weight bytes and expose cache hits/misses. |
| X bookmarks: browser-trace / autobrowse / Nightshift / autoresearch / GEPA-style loops | Full execution traces and bounded experiments can improve policies over time. | Slow/failing runs should emit `ColdFaultTrace` and reversible `LayoutPatch` / `RoutePatch` candidates. |
| Kimi/Kimi CLI | Agents that can read, edit, search, and adjust actions need source and tool feedback in the loop. | Epistemos should make route selection feedback first-class instead of hiding it in chat state. |
| ResearchRabbit / Consensus / NotebookLM | Source discovery, full-text evidence, and source-bounded notebooks are useful research surfaces. | Source discovery feeds `SourceSignalGraph`, but Eidos and proof surfaces decide what becomes evidence. |
| Lean / Mathlib / DeepSeek-Prover / AxProver-style loops | LLM proposals become reliable only when a checker accepts replayable proof artifacts. | The working-set compiler can wake Lean/proof lanes as verifier pages in the same support set. |

## Primary validation extracted

| Source | Validated motif | Architecture use |
|---|---|---|
| Denning working-set model | A process's useful pages are the recently referenced set; scheduler and memory management are coupled; the working-set parameter balances page traffic against wasted memory. | `SemanticWorkingSetPlan` couples route scheduling with memory residency instead of treating prefetch as an afterthought. |
| vLLM / PagedAttention | KV cache can use virtual-memory-like block tables and sharing across requests. | `ResidencyPageTable` maps semantic units to physical KV/model/evidence pages. |
| LMCache | Reusable text KV can be stored across GPU, CPU, disk, and S3 and reused beyond strict same-request context. | `KVLineageGraph` and `PrefixReuseRouter` become working-set inputs. |
| DeepSeek context caching | Disk-backed prefix units can report hit and miss tokens, but hits require persisted compatible prefixes. | `KVCompatibilityFence` and `KVByteBudgetCard` must reject incompatible or unpersisted reuse. |
| FlexGen | Limited-memory inference can aggregate GPU, CPU, and disk with searched access patterns and compression. | Offload is a scheduled plan with budgets, not a panic path. |
| PowerInfer | Activation locality separates repeatedly hot neurons from input-dependent cold neurons. | `WorkingSetOracleCard` should learn repeated hot units while preserving cold fallback. |
| KTransformers | Heterogeneous CPU/GPU inference is a real local research path for large models. | `ResidencyPageTable` can include CPU/GPU/KV/kernel placement lanes. |
| KIVI | KV cache can be a first-class compression target. | The working set budgets KV codec, byte count, and quality caveat. |
| Karpathy autoresearch | Small fixed-budget experiments can keep or discard changes by measured metric. | Working-set policy evolves through bounded tournaments, not instinct. |
| Lean/Mathlib and DeepSeek-Prover-V2 | Formal proof routes need Lean 4, Mathlib, subgoal decomposition, and replayable verifier feedback. | Proof lanes become selectable working-set units with pinned environments. |

## L15-Candidate: Semantic Working-Set Law

A cold cognitive atlas becomes useful only when each mission compiles to a
predicted, budgeted, prefetchable, observable working set whose misses update
future layout and routing.

```text
Utility(working_set | mission) =
  evidence_validity_delta
  + verifier_delta
  + saved_prefill_compute
  + saved_cold_io
  + route_quality_delta
  - hot_byte_cost
  - kv_byte_cost
  - cold_miss_cost
  - incompatibility_risk
  - source_staleness_risk
  - privacy_risk
  - rollback_risk
```

Promotion condition:

- the plan names every selected unit by UAS address or pinned tool/runtime
  identity;
- hot, warm, cold, KV, adapter, evidence, verifier, and scratch bytes are
  reported separately;
- the prefetch window beats no-prefetch and naive recency/file-order baselines;
- cold misses emit trace data that changes later plans on held-out fixtures;
- source-derived priors cannot promote without license, credibility, digest,
  privacy, and no-poison gates;
- user-visible answers expose the route through RunEventLog and AnswerPacket;
  and
- rollback exists for cache, layout, prompt, route, adapter, and source
  mutations.

## New primitive set

### `SourceSignalGraph`

The ranked source-motif graph from bookmarks, repos, papers, X bookmarks,
docs, traces, and local canon.

```text
SourceSignalGraph {
  source_cards
  bookmark_edges
  citation_edges
  repo_edges
  trace_edges
  credibility_rank
  license_or_usage_note
  digest
  route_affinities
  no_poison_status
}
```

### `TaskWorkingSetQuery`

The mission-shaped query sent into the compiler.

```text
TaskWorkingSetQuery {
  mission_id
  task_signature
  privacy_class
  deadline
  quality_target
  evidence_need
  verifier_need
  max_hot_bytes
  max_kv_bytes
  max_cold_io_bytes
}
```

### `SemanticWorkingSetPlan`

The selected active support set before execution.

```text
SemanticWorkingSetPlan {
  query
  selected_evidence_pages
  selected_kv_pages
  selected_adapter_slices
  selected_weight_pages
  selected_kernels
  selected_verifiers
  rejected_units
  hot_bytes
  warm_bytes
  cold_bytes
  kv_bytes
  predicted_cold_misses
  fallback_route
  rollback
}
```

### `ResidencyPageTable`

The page table that binds semantic units to physical/storage placement.

```text
ResidencyPageTable {
  semantic_unit_id
  uas_address
  storage_tier: hot | warm | cold | remote_reference | unavailable
  byte_range
  codec
  compatibility_fence
  prefetch_priority
  expiry_or_lease
  checksum
}
```

### `PrefetchWindow`

The bounded plan for waking bytes before they become token-latency blockers.

```text
PrefetchWindow {
  route_id
  ordered_units
  trigger_event
  max_parallel_reads
  max_bytes
  cancellation_rule
  fallback_on_miss
  measurement_ref
}
```

### `WorkingSetOracleCard`

The learned predictor that proposes a working set and admits uncertainty.

```text
WorkingSetOracleCard {
  oracle_id
  inputs
  predicted_units
  confidence
  abstain_condition
  baseline_policy
  held_out_score
  regret_update_key
}
```

### `ColdFaultTrace`

The trace emitted when the compiler guessed wrong or the storage plan stalled.

```text
ColdFaultTrace {
  mission_id
  missing_unit
  expected_unit
  stall_ms
  cold_io_bytes
  fallback_used
  answer_effect
  source_or_cache_cause
  next_layout_patch
}
```

### `LayoutPatch`

The reversible proposal that changes AppColdStore layout or cache policy.

```text
LayoutPatch {
  patch_id
  target_layout
  baseline_layout
  changed_tiles
  expected_cold_miss_delta
  observed_cold_miss_delta
  storage_wear_cost
  rollback
  promotion_status
}
```

### `MmapResidencyFence`

The guard that prevents "mapped" from being confused with "hot."

```text
MmapResidencyFence {
  file_id
  byte_range
  mapped
  touched
  resident_estimate
  major_faults
  minor_faults
  copy_count
  pass_or_fail
}
```

### `KVByteBudgetCard`

The explicit budget for KV, not just weights.

```text
KVByteBudgetCard {
  model_id
  context_tokens
  kv_codec
  kv_bytes_predicted
  kv_bytes_observed
  prompt_cache_hit_tokens
  prompt_cache_miss_tokens
  quality_caveat
}
```

### `SourceToResidencyPatch`

The bridge from source research to candidate layout/route changes.

```text
SourceToResidencyPatch {
  source_signal
  proposed_unit_or_policy
  affected_organs
  import_gate
  falsifier_required
  rollback
}
```

## Mathematical interpretation

Denning's working-set idea can be translated into a semantic runtime:

```text
W_semantic(mission, t, tau) =
  { UAS-addressed units referenced, verified, or made necessary by the mission
    during the recent route interval (t - tau, t) }
```

The useful parameter is no longer only clock time. It is route phase:

- intake/source discovery;
- evidence retrieval;
- proof/tool planning;
- prefill/KV reuse;
- model execution;
- verification/repair;
- answer witness;
- mutation/cache/layout learning.

For each phase, the compiler should minimize:

```text
total_cost =
  hot_bytes
  + alpha * cold_misses
  + beta * wrong_evidence
  + gamma * verifier_failures
  + delta * rollback_risk
```

The page-fault analogy becomes concrete: a cold miss is not only an I/O event.
It is a failed prediction about what the task would need. That miss must feed
the next `WorkingSetOracleCard`, `CoactivationTile`, `CacheAdmissionCard`, or
`LayoutPatch`.

## How this makes UAS, active cold storage, and the 70B cocktail more plausible

The 70B cocktail should be described as a large cold addressable material set
plus a small compiled working set:

| Layer | Working-set interpretation |
|---|---|
| source research | `SourceSignalGraph` ranks motifs and proof obligations. |
| Eidos | evidence and citation pages selected as route priors. |
| KV/cache | reusable prefix units selected by compatibility, not recency alone. |
| model weights | pages/experts/adapters selected by utility and coactivation. |
| proof tools | Lean/schema/tests selected only when the mission needs them. |
| AppColdStore | layout favors coactivation tiles and prefetch windows. |
| RunEventLog / AnswerPacket | route, bytes, cache hits, cold faults, and rollback are visible. |

The model's total size still matters as cold material. It does not determine
runtime cost alone. Runtime cost depends on the compiled working set, the
quality of the prefetch window, and the number of wrong guesses.

## Engineering route

1. **Source cards first.** Convert bookmark, repo, paper, and X handles into
   `SourceSignalGraph` fixtures with URL, digest, license/usage note, and
   credibility rank.
2. **Schema-only compiler.** Build `TaskWorkingSetQuery`,
   `SemanticWorkingSetPlan`, `ResidencyPageTable`, `PrefetchWindow`,
   `ColdFaultTrace`, and `KVByteBudgetCard` as dry-run artifacts.
3. **Synthetic page-table simulator.** Use fixture byte ranges only. Prove
   "mapped" is not counted as hot unless touched/resident evidence exists.
4. **Working-set baselines.** Compare random, recency, file-order, Eidos-only,
   cache-only, and compiled working-set plans.
5. **Cold-fault learning.** Feed repeated misses into `LayoutPatch` and prove
   held-out improvements without mutating production layout.
6. **KV budget witness.** Report predicted/observed KV bytes, hit tokens, miss
   tokens, codec, quality caveat, and compatibility failures.
7. **Proof lane selection.** Add Lean/schema/test lanes as selected verifier
   units, not always-on overhead.
8. **AnswerPacket surface.** Show route plan, selected unit families, cache
   hit/miss, cold faults, fallback, and rollback for user-impacting answers.

## New falsifier targets

Backlog bundle: `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`.

| Falsifier | Purpose |
|---|---|
| `F-SourceSignalGraph-Intake` | Proves bookmark/repo/paper/X sources become source cards with digest, credibility, license/usage note, and no-poison status. |
| `F-TaskWorkingSetQuery-Determinism` | Proves the same mission fixture emits the same bounded query and privacy/budget class. |
| `F-SemanticWorkingSetPlan-Budget` | Proves plans reject over-budget hot/KV/cold I/O selections before execution. |
| `F-ResidencyPageTable-Addressability` | Proves every selected semantic unit binds UAS address, byte range, tier, checksum, codec, and compatibility fence. |
| `F-PrefetchWindow-ColdMiss` | Proves compiled prefetch beats random/recency/file-order baselines on cold misses and stall time. |
| `F-ColdFaultTrace-Learning` | Proves cold faults create bounded layout/route patches and improve held-out routes. |
| `F-MmapResidencyFence-CopyCount` | Proves mmap mapping, touching, resident estimate, major/minor faults, and copy count are not conflated. |
| `F-KVByteBudgetCard` | Proves KV bytes, hit/miss tokens, codec, and quality caveat are reported separately from weight bytes. |
| `F-WorkingSetOracle-Baseline` | Proves the oracle beats random, recency, and static file-order policies or abstains. |
| `F-SourceToResidency-NoPoison` | Proves prompt-injection, stale-source, license-blocked, and low-credibility sources cannot promote layout or route patches. |
| `F-70B-Cocktail-WorkingSet-Lite` | Proves a small-hot compiled plan beats dense-local, RAG-only, and static-route baselines without hidden cloud or dense-resident overclaim. |

**2026-06-03 status.** `F-SourceSignalGraph-Intake`,
`F-TaskWorkingSetQuery-Determinism`, and
`F-SemanticWorkingSetPlan-Budget`, and
`F-ResidencyPageTable-Addressability`, and
`F-MmapResidencyFence-CopyCount`, and `F-PrefetchWindow-ColdMiss` now have
primary local witnesses on main. Continue this bundle with cold-fault learning,
KV byte budget card coverage, working-set oracle baseline, and
source-to-residency no-poison guards; do not reinstall model assets or fetch
live sources for these metadata-only gates.

## Product locks

- The compiler is a planning surface, not a new hidden router authority.
- Live execution still routes through Eidos, NeuralImportanceAtlas,
  ActiveAssembly, SCOPE-Rex/SovereignGate, RuntimeRouter/System G, RunEventLog,
  and AnswerPacket.
- Source handles from bookmarks, X, papers, and repos are source motifs, not
  proof.
- No public source code import happens without ImportGateCard.
- No cache or trace can affect a user-visible answer without compatibility,
  privacy, purge, rollback, and visible witness.
- No claim may equate mmap, SSD, or cloud storage with RAM latency.
- No 70B local claim promotes until active/hot/cold/KV bytes, cold misses,
  quality, verifier results, fallback, and rollback are reported.

## Companion sources

- `docs/fusion/FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31.md`
- `docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md`
- `docs/fusion/EIDOS_NEURAL_IMPORTANCE_BRIDGE_2026_05_31.md`
- `docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md`
- `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
- `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`
- `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`
- `docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md`
- `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`
- `docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md`
- `docs/fusion/FORMAL_MATH_COMPANY_AND_LEAN_INTAKE_2026_06_01.md`

## 2026-06-01 companion upgrade: sparse route + ColdStream

`SemanticWorkingSetPlan` is now the shared contract between selection and
transport:

- L17 sparse routing consumes the task/source/cache/trace features and emits
  `SparseWakeProposal`, `VerifierBudgetAuction`, `QueryAwareKVSelector`,
  `DepthLease`, and `SparseWakeCertificate` before heavy execution.
- L18 ColdStream consumes the selected `ResidencyPageTable` ranges and emits
  `TransportRunManifest`, `PageRunScheduler`, `SlabArena` or
  `MetalBufferLease`, `CodecStage`, `TransportTrace`, and
  `ColdPanicFallback`.

The compiler must not hide either decision. A valid working-set artifact must
be able to explain both **why these units were selected** and **how their cold
bytes will arrive before token-critical execution needs them**.
