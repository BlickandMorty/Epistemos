---
state: candidate_falsifier_bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
authority: docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md
status: backlog spec only; not an artifact-schema migration and not a pass claim
---

# F-Constructive-Residency Bundle - 2026-06-01

## Purpose

This bundle turns the constructive residency doctrine into buildable falsifier
targets without claiming that any target has passed.

The doctrine reframes the 70B cocktail as:

```text
small hot controller
  + selected evidence
  + selected KV / model / adapter / expert pages
  + selected verifier lanes
  + explicit fallback and rollback
  -> proof-carrying resident assembly
```

It extends, but does not replace, the existing gates:

- `docs/falsifiers/F-ResidencyPlan-DryRun_2026_05_30.md`
- `docs/falsifiers/F-70B-Local-Cocktail-Composition_2026_05_17.md`
- `docs/falsifiers/F_70B_LOCAL_COCKTAIL_LITE_2026_05_18.md`

Companion 2026-06-01 gates:

- `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-MATH-NOTE-SYSTEMS-PORTABILITY-BUNDLE_2026_06_01.md`

## Candidate Gates

| Gate | What it must prove | Promotion target |
|---|---|---|
| `F-ResidencyConstructionGraph` | Candidate units, coactivation edges, incompatibilities, verifier edges, and cold-miss history produce deterministic plan scores and reject invalid assemblies. | PASS as metadata-only dry-run planner witness: `docs/falsifiers/F-ResidencyConstructionGraph_2026_06_03.md`, `artifacts/falsifiers/residency_construction_graph/result.json`. |
| `F-CoactivationTile-Prefetch` | Tile packing and prefetch beat original file order or random fetch on cold misses, stall time, and byte waste. | PASS as metadata-only dry-run tile witness: `docs/falsifiers/F-CoactivationTile-Prefetch_2026_06_03.md`, `artifacts/falsifiers/coactivation_tile_prefetch/result.json`. |
| `F-ProofCarryingResidencyLease` | No cold byte wakes without UAS address, reason, byte cost, proof/falsifier reference, expiry, fallback, and rollback. | PASS as metadata-only dry-run lease witness: `docs/falsifiers/F-ProofCarryingResidencyLease_2026_06_03.md`, `artifacts/falsifiers/proof_carrying_residency_lease/result.json`. |
| `F-ColdAssemblyPlan-70B-Lite` | A small-hot plus cold-selected plan beats dense-local, RAG-only, and static-route baselines without hidden cloud or dense-resident overclaim. | PASS as metadata-only dry-run cold assembly witness: `docs/falsifiers/F-ColdAssemblyPlan-70B-Lite_2026_06_03.md`, `artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json`. |
| `F-LatticeStateController` | A tiny recurrent/lattice controller improves route decisions over static policy and abstains when uncertain. | PASS as metadata-only route-controller witness: `docs/falsifiers/F-LatticeStateController_2026_06_03.md`, `artifacts/falsifiers/lattice_state_controller/result.json`. |
| `F-ReasoningStateContinuity` | Preserved cache/summary/tool state improves continuity or cache utility without exposing hidden chain-of-thought or bypassing verification. | PASS as metadata-only continuity-card witness: `docs/falsifiers/F-ReasoningStateContinuity_2026_06_03.md`, `artifacts/falsifiers/reasoning_state_continuity/result.json`. |
| `F-ColdMissLedger` | Cold misses update later prefetch/route policy and reduce repeated stalls on held-out tasks. | PASS as metadata-only cold-miss ledger witness: `docs/falsifiers/F-ColdMissLedger_2026_06_03.md`, `artifacts/falsifiers/cold_miss_ledger/result.json`. |
| `F-SwiftLM-SourceIntake` | SwiftLM motifs are captured as source cards with license, setup, benchmark caveats, and local test plans before any code import. | PASS as metadata-only source-intake witness: `docs/falsifiers/F-SwiftLM-SourceIntake_2026_06_03.md`, `artifacts/falsifiers/swiftlm_source_intake/result.json`. |

## Shared Artifact Axes

Each future gate should report:

```text
source_card_ids
task_signature
total_addressable_bytes
hot_resident_bytes
warm_bytes
cold_bytes
active_executed_bytes
kv_bytes
adapter_bytes
peak_rss
cold_miss_count
cold_stall_ms
quality_delta
evidence_validity_delta
verifier_delta
fallback_used
rollback_verified
answer_packet_ref
overall_pass
```

For state continuity gates, add:

```text
privacy_class
visible_summary_present
hidden_chain_exposed=false
purge_policy
verifier_caveat
```

## Baselines

No constructive-residency gate promotes unless it beats all applicable
baselines:

- dense local route within the same hardware budget;
- conventional RAG-only route;
- static residency plan;
- random or original-file-order prefetch for layout gates;
- static route policy for controller gates.

## Hard Fails

A future artifact fails immediately if it:

- treats SSD or mmap as RAM latency;
- omits active/cold byte accounting;
- wakes a cold byte without a lease and rollback;
- exposes hidden chain-of-thought as proof;
- uses public source code without license/setup/vendor review;
- hides a cloud/provider fallback inside a local claim;
- lacks an AnswerPacket witness for a promoted user-visible result.

## Source Links

- Constructive residency doctrine: `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`
- Residency PatternBoost discovery: `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
- Meta-breakthrough cards: `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`
- Semantic working-set compiler: `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`
- Frontier local reasoning: `docs/fusion/FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31.md`
- Neural importance atlas: `docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md`
- Existing dry-run witness: `docs/falsifiers/F-ResidencyPlan-DryRun_2026_05_30.md`
- First Research Construction witness: `docs/falsifiers/F-ResidencyConstructionGraph_2026_06_03.md`
- Coactivation tile prefetch witness: `docs/falsifiers/F-CoactivationTile-Prefetch_2026_06_03.md`
- Proof-carrying lease witness: `docs/falsifiers/F-ProofCarryingResidencyLease_2026_06_03.md`
- Current active cursor after the 2026-06-03 MetaBreakthrough registry witness: `F-ProofCarryingRouteCard`
