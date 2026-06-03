---
state: backlog-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md
status: candidate tests; not implemented unless a later PR wires artifacts
---

# F-Semantic Working-Set Compiler Bundle - 2026-06-01

This bundle converts the Semantic Working-Set Compiler doctrine into promotion
gates. It does not claim the compiler, persistent KV, 70B working-set routing,
or AppColdStore prefetch is live. It defines the tests required before those
mechanisms can govern product behavior.

## Shared artifact contract

Every falsifier emits:

```text
falsifier_id
source_doc
scenario_id
mission_id
task_signature
source_signal_refs
privacy_class
product_build
pro_status
uas_addresses
selected_unit_count
hot_bytes
warm_bytes
cold_bytes
active_executed_bytes
kv_bytes
adapter_bytes
evidence_bytes
verifier_bytes
scratch_bytes
cold_io_bytes
cold_miss_count
cold_stall_ms
prompt_cache_hit_tokens
prompt_cache_miss_tokens
compatibility_result
source_no_poison_result
baseline_policy
candidate_policy
quality_score
evidence_validity_score
verifier_score
rollback_ref
run_event_log_visibility
answer_packet_visibility
pass
failure_reason
```

## Falsifier Matrix

| Falsifier | Pass condition | Rejects |
|---|---|---|
| `F-SourceSignalGraph-Intake` | Bookmark, repo, paper, doc, and X fixture sources become `SourceCard`s with URL/path, digest, credibility rank, license/usage note, privacy class, source type, and no-poison status. | Source-driven planning by vibes, unsourced claims, license-blind import, and stale bookmark authority. |
| `F-TaskWorkingSetQuery-Determinism` | The same mission fixture emits the same `TaskWorkingSetQuery`, max-hot/max-KV/max-cold-I/O budgets, privacy class, evidence need, and verifier need. | Non-deterministic route planning, hidden budget changes, and privacy drift. |
| `F-SemanticWorkingSetPlan-Budget` | Candidate plans reject over-budget hot bytes, KV bytes, cold I/O, verifier cost, adapter bytes, or scratch bytes before execution. | Plans that only discover impossibility after waking cold state. |
| `F-ResidencyPageTable-Addressability` | Every selected semantic unit binds UAS address, storage tier, byte range, codec, checksum, compatibility fence, lease/expiry, and prefetch priority. | Selected pages with no address, checksum, ownership, tier, or compatibility proof. |
| `F-PrefetchWindow-ColdMiss` | A compiled `PrefetchWindow` beats random, recency-only, and file-order baselines on cold misses, stall time, and byte waste in synthetic fixtures. | Prefetch policies that are no better than chance or cause token-latency cold panic. |
| `F-ColdFaultTrace-Learning` | Repeated cold-miss fixtures emit `ColdFaultTrace`, generate bounded `LayoutPatch` or `RoutePatch`, and improve held-out fixtures without mutating production policy. | Silent misses, winner-only evidence, and live policy mutation from one trace. |
| `F-MmapResidencyFence-CopyCount` | Fixtures distinguish mapped, touched, resident-estimated, copied, and faulted ranges and fail if "mmap" is counted as hot without evidence. | SSD-as-RAM claims, hidden copies, and resident-byte overclaims. |
| `F-KVByteBudgetCard` | KV bytes, codec, prompt cache hit/miss tokens, quality caveat, and compatibility failures are reported separately from weight bytes. | Weight-only memory accounting and cache-hit claims with no token accounting. |
| `F-WorkingSetOracle-Baseline` | The oracle beats random, recency, and static file-order policies on quality, evidence validity, cold misses, and active bytes, or abstains with a named reason. | Learned routers that cannot beat simple baselines or refuse uncertainty. |
| `F-SourceToResidency-NoPoison` | Prompt-injection, stale-source, license-blocked, private-source, corrupted-digest, and low-credibility fixtures cannot promote layout, cache, route, or prompt patches. | Source poisoning, license drift, stale evidence reuse, and private trace leakage. |
| `F-70B-Cocktail-WorkingSet-Lite` | A small-hot compiled plan beats dense-local, RAG-only, and static-route baselines on quality, evidence validity, active bytes, cold stalls, and visible proof without hidden cloud or dense-resident overclaim. | "70B local" claims without active/hot/cold/KV accounting, fallback, and proof. |

## Implementation status - 2026-06-03

- `F-SourceSignalGraph-Intake` is implemented as a primary witness at
  `artifacts/falsifiers/source_signal_graph_intake/result.json` and documented
  in `docs/falsifiers/F-SourceSignalGraph-Intake_2026_06_03.md`.
- `F-TaskWorkingSetQuery-Determinism` is implemented as a primary witness at
  `artifacts/falsifiers/task_working_set_query_determinism/result.json` and
  documented in
  `docs/falsifiers/F-TaskWorkingSetQuery-Determinism_2026_06_03.md`.
- `F-SemanticWorkingSetPlan-Budget` is implemented as a primary witness at
  `artifacts/falsifiers/semantic_working_set_plan_budget/result.json`.
- `F-ResidencyPageTable-Addressability` is implemented as a primary witness at
  `artifacts/falsifiers/residency_page_table_addressability/result.json` and
  documented in
  `docs/falsifiers/F-ResidencyPageTable-Addressability_2026_06_03.md`.
- Remaining bundle work starts with prefetch/cold-miss and
  mmap-residency-fence fixtures. Source intake, deterministic query emission,
  budget rejection, and page-table addressability no longer need to be rebuilt
  from scratch.

## Required fixture families

1. **Bookmark source.** A saved browser source becomes a `SourceCard` with
   digest, source type, and no-poison status.
2. **X source.** A bookmark thread becomes a source signal but cannot promote
   without primary validation.
3. **Paper source.** A paper/repo pair creates route affinities and license
   notes without copying code.
4. **KV-heavy mission.** The same weights but different context lengths expose
   KV bytes as the bottleneck.
5. **Mmap cold slice.** A mapped but untouched range must not count as hot.
6. **Page-table plan.** Selected evidence/KV/adapter/model pages all bind UAS
   addresses and byte ranges.
7. **Cold miss.** A missing unit stalls, falls back, logs trace, and proposes a
   bounded patch.
8. **Stale source.** Source digest changes after cache creation and invalidates
   the plan.
9. **Poison source.** Source text asks to preserve/reveal forbidden state and
   fails source-to-residency promotion.
10. **70B-lite dry run.** Fixture large-model byte ranges prove planning shape
    with zero real model bytes loaded.

## Build order

1. Add schema-only artifacts for `SourceSignalGraph`,
   `TaskWorkingSetQuery`, `SemanticWorkingSetPlan`, `ResidencyPageTable`,
   `PrefetchWindow`, `ColdFaultTrace`, `LayoutPatch`, `MmapResidencyFence`,
   and `KVByteBudgetCard`. `SourceSignalGraph` and
   `TaskWorkingSetQuery`, `SemanticWorkingSetPlan` budget rejection, and
   `ResidencyPageTable` addressability now have primary witnesses.
2. Synthetic fixtures for deterministic query emission are covered by
   `F-TaskWorkingSetQuery-Determinism`; source intake is already wired through
   `F-SourceSignalGraph-Intake`.
3. Budget rejection before any runtime wake path is covered by
   `F-SemanticWorkingSetPlan-Budget`.
4. Page-table addressability is covered by
   `F-ResidencyPageTable-Addressability`; continue with mmap fence fixtures.
5. Add KV budget and compatibility fixtures.
6. Add cold-miss learning fixtures with rollback-only layout patches.
7. Add oracle baseline comparison.
8. Add no-poison source-to-residency fixtures.
9. Only after synthetic gates pass, connect dry-run plans to existing
   constructive-residency and cache-lineage artifacts.

## Product locks

- The Semantic Working-Set Compiler is Pro Research until these gates pass.
- The compiler cannot bypass Eidos, NeuralImportanceAtlas, ActiveAssembly,
  SCOPE-Rex/SovereignGate, RuntimeRouter/System G, RunEventLog, or
  AnswerPacket.
- Source-derived plans require source cards and no-poison checks.
- Persistent KV and trace reuse require compatibility, privacy, purge, and
  rollback gates.
- mmap, SSD, and AppColdStore are addressability and layout tools, not RAM.
- No 70B-cocktail claim promotes without active/hot/cold/KV byte accounting,
  cold-miss evidence, quality baselines, fallback, rollback, and visible proof.

## Companion gates

- Constructive residency bundle:
  `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- Residency PatternBoost bundle:
  `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- Cache-lineage autoresearch bundle:
  `docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md`
- Engineering logic bundle:
  `docs/falsifiers/F-ENGINEERING-LOGIC-ARCHITECTURE-BUNDLE_2026_06_01.md`
- Neural importance routing atlas:
  `docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md`
- Frontier local reasoning:
  `docs/fusion/FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31.md`
