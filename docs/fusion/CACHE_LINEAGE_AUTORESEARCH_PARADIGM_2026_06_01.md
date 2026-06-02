---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: recursive Chrome/X bookmark intake plus primary validation for persistent KV, tiered cache, MLX/autoresearch, browser traces, and GEPA-style prompt evolution
status: architecture doctrine; no product promotion without falsifiers, privacy/purge policy, rollback, and visible proof
---

# Cache-Lineage Autoresearch Paradigm - 2026-06-01

## Thesis

Constructive residency answers the question: **what is the smallest
proof-carrying resident assembly that should wake?**

Cache-lineage autoresearch answers the next question:

> **Which state, prefix, trace, and route evidence should survive so the next
> assembly is cheaper, more continuous, and more correct?**

Epistemos should treat KV/prefix caches, prompt-cache units, cold state,
execution traces, browser traces, profiler traces, and route outcomes as
first-class UAS-addressed substrate objects. They are not hidden leftovers.
They have lineage, compatibility fences, privacy class, purge policy,
admission cards, rollback handles, and AnswerPacket-visible effects when they
shape user output.

This makes AppColdStore more plausible as **active cold storage**: not RAM, but
a durable foundry for reusable cognitive state. The 70B cocktail becomes more
plausible because the app learns which prefixes, KV pages, cold tiles,
adapters, quant formats, and prefetch plans repeatedly earn their bytes.

Companion note/editor source:
`docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md` defines the
delta/projection math that feeds this loop. Cache lineage should learn from
`ExecutionTraceCapsule`s and runtime state, while editor/source changes flow
through `EditorDeltaMonoid`, `ReadableProjectionFunctor`, and
`DifferentialKnowledgeView`.

Companion working-set compiler source:
`docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md` defines how cache
lineage becomes execution planning. `KVLineageGraph`, `PrefixReuseRouter`, and
`CacheAdmissionCard` feed a `SemanticWorkingSetPlan`, `ResidencyPageTable`,
`PrefetchWindow`, `ColdFaultTrace`, and `KVByteBudgetCard`, so saved state
earns its place by reducing measured cold misses, KV bytes, and verifier
regret.

Companion trace-observatory source:
`docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md` defines how cache
lineage becomes debuggable instead of mystical. `ExecutionTraceCapsule`,
`KVPrefixUnit`, and `TraceToPlanLearner` should emit `AttentionKVTrace`,
`AgentActionFrame`, `TraceComparisonDeck`, and
`TelemetryToWorkingSetPatch` artifacts before a cache-derived mutation can
claim to improve prompts, routes, layouts, or residency policy.

Companion Residency PatternBoost source:
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` defines how
cache lineage and cold-fault traces become candidate generation material for
offline resident assembly tournaments. Cache state may seed
`AssemblyCandidatePool`, `SparseAssemblyFingerprint`, and
`EliteAssemblyArchive`, but it still needs compatibility fences, privacy/purge
policy, held-out validation, rollback, and AnswerPacket visibility before it
can shape live routing.

## Bookmark intake translated into doctrine

| Source handle | Signal | Canonical interpretation |
|---|---|---|
| oMLX bookmark thread | Apple Silicon LLM serving can combine continuous batching, persistent sessions, KV compression, and tiered RAM/SSD cache motifs. | Source-mine persistent KV and cache-admission patterns for local MLX routes; no code import without license/vendor gates. |
| TurboQuant paper | Online, data-free KV quantization can reduce KV memory while bounding distortion. | KV cache can have codec policy and proof bounds, not just eviction policy. |
| Tutti / KVDrive / tiered KV papers | KV placement, compression, SSD/DRAM tiering, and I/O-aware prefetch are now explicit inference systems. | AppColdStore should schedule KV/prefix state like a memory hierarchy with compatibility fences. |
| AWS managed tiered KV cache | Commercial inference now routes requests by cache locality and shares tiered KV across replicas. | Cache locality is an execution-route feature, not a post-hoc optimization. |
| DeepSeek context caching | Prefix cache units, disk caching, token granularity, and price/latency benefits are product-facing enough to document. | Epistemos can expose prefix-cache witnesses without exposing hidden reasoning. |
| DeepSeek-V4 preview | Large MoE/context systems push 1M-context and active-parameter separation into product APIs. | Total addressable capacity, active parameters, and context cache must be reported separately. |
| Browserbase browser-trace skill | DOM, screenshots, network/CDP logs, and browser state can be captured as searchable traces. | Browser research and app automation should emit `ExecutionTraceCapsule`, not unstructured notes. |
| Karpathy autoresearch | A research loop can repeatedly modify, train, evaluate, and keep evidence. | Epistemos should run bounded local tournaments over route plans and cache policies, not trust one heuristic. |
| GEPA | Reflective prompt evolution with Pareto selection can improve agents using full trajectory feedback. | Trace outcomes should evolve prompts, route policies, and residency plans through rollback-safe candidates. |
| Nightshift / MLX autoresearch bookmark | Apple Silicon can be used as an overnight local research loop. | The unattended loop should search low-risk policy/layout/prompt candidates before heavy model probes. |

## L12-Candidate: Cache-Lineage Law

Persistent state is useful only when its saved computation and continuity gain
exceed staleness, incompatibility, privacy, storage, and verification cost.

```text
Utility(cache_or_trace | task, route) =
  saved_prefill_compute
  + saved_cold_io
  + continuity_delta
  + trace_learning_delta
  - staleness_risk
  - incompatibility_risk
  - privacy_risk
  - storage_wear_cost
  - verification_cost
```

Promotion condition:

- the cache or trace has a UAS address, source lineage, owner, privacy class,
  purge policy, and byte accounting;
- the compatibility fence checks model, tokenizer, adapter, RoPE/window,
  system prompt, prompt prefix digest, quant codec, and route policy;
- reuse beats no-cache and naive-cache baselines on quality, latency, cold I/O,
  and active bytes;
- trace-derived policy changes include baseline, patch, ablation, rollback,
  and held-out validation; and
- RunEventLog and AnswerPacket reveal when cached state or trace-learned policy
  materially shaped a user-visible answer.

## New primitive set

### `KVPrefixUnit`

A durable prefix/KV cache chunk.

```text
KVPrefixUnit {
  unit_id
  uas_address
  model_id
  tokenizer_id
  adapter_set
  rope_or_window_config
  source_prompt_digest
  token_range
  kv_digest
  codec
  byte_count
  privacy_class
  purge_policy
  hit_count
  miss_count
  verifier_caveat
}
```

### `KVLineageGraph`

The provenance graph for reusable state.

```text
KVLineageGraph {
  source_cards
  prompt_fragments
  system_prompt_versions
  note_or_document_addresses
  tool_trace_refs
  kv_prefix_units
  downstream_cold_assembly_plans
  invalidation_edges
}
```

### `KVCompatibilityFence`

A hard gate before a cache unit can be restored.

```text
KVCompatibilityFence {
  candidate_unit
  current_model_id
  current_tokenizer_id
  current_adapter_set
  current_rope_or_window_config
  current_system_prompt_digest
  current_privacy_context
  accept_or_reject
  rejection_reason
}
```

### `CacheAdmissionCard`

The admit/compress/evict/purge decision for cache substrate.

```text
CacheAdmissionCard {
  cache_unit
  expected_reuse_horizon
  saved_prefill_estimate
  saved_io_estimate
  storage_wear_estimate
  privacy_class
  compression_policy
  admission_decision
  eviction_decision
  purge_deadline
  rollback
}
```

### `ExecutionTraceCapsule`

Replayable evidence from app, browser, terminal, profiler, and route
execution.

```text
ExecutionTraceCapsule {
  trace_id
  mission_id
  source: app | browser | terminal | profiler | model_runtime
  events
  screenshots_or_artifacts
  network_or_cdp_logs
  dom_or_accessibility_snapshot
  prompt_and_route_refs
  privacy_redactions
  outcome_metrics
  failure_signature
}
```

### `ParetoResidencyTournament`

A bounded research loop over cache and route policies.

```text
ParetoResidencyTournament {
  task_family
  candidate_policies
  baseline_policy
  evaluation_suite
  metrics: quality | latency | active_bytes | cold_io | privacy_risk | storage_wear
  pareto_front
  rejected_candidates
  rollback_refs
}
```

### `CacheMutationPatch`

A proposed cache/layout/prompt/route policy change.

```text
CacheMutationPatch {
  patch_id
  target: prompt_policy | kv_policy | cold_layout | quant_codec | prefetch_policy | route_policy
  baseline_ref
  patch_ref
  ablation_ref
  expected_delta
  observed_delta
  rollback
  promotion_status
}
```

### `PrefixReuseRouter`

Detects compatible reusable prefixes before prefill work is repeated.

```text
PrefixReuseRouter {
  task_signature
  prompt_prefix_digest
  candidate_kv_units
  compatibility_results
  selected_unit_or_none
  saved_prefill_estimate
  answer_packet_note
}
```

### `TraceToPlanLearner`

Turns failed or slow traces into new candidate route plans.

```text
TraceToPlanLearner {
  trace_capsule
  failure_signature
  missed_cache_or_tile
  proposed_cache_mutation_patch
  proposed_cold_assembly_patch
  required_falsifier
}
```

## How this upgrades UAS, AppColdStore, and the 70B cocktail

The storage layer becomes a **ColdStateFoundry**:

| Object | Durable role |
|---|---|
| raw model/evidence bytes | cold addressed material |
| `CoactivationTile` | layout unit for things that wake together |
| `KVPrefixUnit` | reusable prefill/KV state with compatibility proof |
| `ReasoningStateContinuityCard` | safe continuity summary/cache policy |
| `ExecutionTraceCapsule` | replayable evidence for what happened |
| `ParetoResidencyTournament` | bounded local search over better plans |
| `CacheMutationPatch` | reversible change to prompt/cache/layout/route policy |

Constructive residency builds the current assembly. Cache-lineage
autoresearch remembers which assemblies, prefixes, and traces should influence
the next one. Together they create a software-side path toward a more capable
local brain without pretending SSD latency vanished or mutating base weights
silently.

## Engineering route

1. **Source cards.** Store oMLX, TurboQuant, Tutti, KVDrive/Swarm, AWS tiered
   KV, DeepSeek context caching/V4, Browserbase skills, Karpathy autoresearch,
   and GEPA as `SourceCard`s with license/status notes.
2. **Trace schema first.** Define `ExecutionTraceCapsule` over synthetic
   browser/runtime traces before capturing sensitive live user sessions.
3. **Prefix dry run.** Build `KVPrefixUnit`, `KVLineageGraph`,
   `KVCompatibilityFence`, and `PrefixReuseRouter` over fixture prompt tokens.
4. **Admission dry run.** Emit `CacheAdmissionCard` with byte, privacy,
   storage-wear, and purge decisions.
5. **Park/resume falsifier.** Simulate a session that parks a compatible prefix
   and resumes it under compatibility checks.
6. **Tournament harness.** Run `ParetoResidencyTournament` over prompt/cache
   policy fixtures and reject candidates without held-out gains.
7. **Mutation promotion.** Let `CacheMutationPatch` promote only after
   baseline, patch, ablation, rollback, and AnswerPacket witness exist.

## New falsifier targets

Backlog bundle:
`docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md`.

| Falsifier | Purpose |
|---|---|
| `F-KVPrefixUnit-Lineage` | Proves a prefix/KV unit binds model, tokenizer, adapter set, prompt digest, token range, codec, privacy, purge, and byte accounting. |
| `F-KVCompatibilityFence` | Proves stale or incompatible cache units are rejected with specific reasons before restore. |
| `F-PrefixReuseRouter` | Proves compatible prefix reuse beats repeated prefill and naive reuse on latency, active bytes, and correctness. |
| `F-CacheAdmissionCard` | Proves persist/compress/evict/purge decisions account for reuse, privacy, storage wear, rollback, and byte cost. |
| `F-PersistentKV-ParkResume` | Proves a parked compatible KV/prefix state can resume through the runtime without hidden chain-of-thought exposure. |
| `F-ExecutionTraceCapsule` | Proves browser/app/runtime traces are captured with redaction, artifact integrity, and replayable failure signatures. |
| `F-ParetoResidencyTournament` | Proves trace-derived candidates are selected by Pareto metrics, not one greedy score or vibe. |
| `F-CacheMutationPatch-Rollback` | Proves every cache/layout/prompt/route mutation has baseline, patch, ablation, held-out result, rollback, and promotion status. |
| `F-TraceToPlanLearner` | Proves slow/failing traces produce bounded candidate plans and never mutate production policy directly. |
| `F-CacheLineage-NoPoison` | Proves privacy, stale-source, prompt-injection, and incompatible-cache cases cannot promote into reusable state. |

## Hard no-overclaim rules

- Do not say cached KV is proof. It is reusable state; claims still need
  evidence and verification.
- Do not reuse a KV/prefix unit across model, tokenizer, adapter, RoPE/window,
  system-prompt, privacy, or route-policy mismatch.
- Do not treat browser/X bookmarks as authority. They seed source cards;
  primary repos, papers, docs, and local falsifiers govern promotion.
- Do not persist sensitive traces without redaction, user-visible storage
  policy, and purge path.
- Do not let autoresearch mutate production prompts, route policies, cache
  policies, or cold layouts without a reversible `CacheMutationPatch`.
- Do not call AppColdStore RAM. Call it addressable, schedulable, cacheable,
  prewarmable, measurable cold state.

## Source links

- oMLX: `https://github.com/solatticus/omlx`
- TurboQuant: `https://ar5iv.org/abs/2504.19874`
- Tutti: `https://arxiv.org/abs/2605.03375`
- KVDrive / Swarm memory offloading: `https://arxiv.org/abs/2603.17803`
- AWS managed tiered KV cache: `https://aws.amazon.com/about-aws/whats-new/2025/11/sagemaker-hyperpod-managed-tiered-kv-cache/`
- DeepSeek context caching: `https://api-docs.deepseek.com/guides/kv_cache`
- DeepSeek-V4 preview: `https://api-docs.deepseek.com/news/news260424`
- Browserbase skills: `https://github.com/browserbase/skills`
- Karpathy autoresearch: `https://github.com/karpathy/autoresearch`
- GEPA: `https://github.com/gepa-ai/gepa`

## Agent rule

Any PR touching persistent KV, prompt-prefix reuse, context caching,
AppColdStore cache admission, execution/browser traces, CDP/DOM trace intake,
autoresearch, GEPA-style prompt/policy evolution, MLX overnight research,
oMLX/TurboQuant motifs, or DeepSeek-style context caching must cite this
source and declare: source card, UAS address, compatibility fence, privacy
class, purge policy, admission card, baseline, patch/ablation when relevant,
rollback, falsifier, RunEventLog, and AnswerPacket surface.
