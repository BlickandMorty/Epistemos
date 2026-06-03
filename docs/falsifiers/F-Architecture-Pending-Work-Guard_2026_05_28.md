---
falsifier: F-Architecture-Pending-Work-Guard
created_on: 2026-05-28
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PRIMARY WORK-QUEUE GUARD IMPLEMENTED
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS (Anchored Cognitive Substrate)/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-Architecture-Pending-Work-Guard

## Purpose

Prevent duplicate architecture work during long recursive loops.

This guard reads the Capability Ceiling Evaluation Kernel queue plus the
KV-Direct full-suite run plan and emits a single cursor:

```text
measurements.next_existing_work.value
```

Agents must check this cursor before creating new prompt suites, run plans,
artifacts, or sibling implementations.

It also consumes the local worktree inventory:

```text
docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json
docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json
```

Those inventories are produced by:

```bash
Tools/audits/epistemos_worktree_inventory.sh
Tools/audits/kv_direct_model_context_inventory.sh
```

Both inventories are read-only. The worktree inventory classifies
Epistemos-looking folders under Downloads so dirty sibling worktrees are
preserved and inspected instead of accidentally duplicated. The model-context
inventory classifies local model configs so agents do not rerun the 128K
KV-Direct plan against a model that cannot satisfy the context floor. It also
keeps alternate long-context model candidates separate from the canonical
Qwen3-8B falsifier identity.

The model-resolution audit
`docs/audits/KV_DIRECT_CANONICAL_MODEL_RESOLUTION_2026_05_28.md` records the
public/local conclusion: exact canonical Qwen3-8B MLX identity is present but
context-red; 128K alternatives are candidate-tier unless the falsifier is
explicitly retargeted.

The guard now also consumes the safe non-runtime large-model rungs that must
exist before another 128K/70B runtime probe:

```text
artifacts/falsifiers/weight_block_range_hash_dry_run/result.json
artifacts/falsifiers/residency_plan_dry_run/result.json
artifacts/falsifiers/residency_construction_graph/result.json
artifacts/falsifiers/coactivation_tile_prefetch/result.json
artifacts/falsifiers/proof_carrying_residency_lease/result.json
artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json
artifacts/falsifiers/lattice_state_controller/result.json
artifacts/falsifiers/reasoning_state_continuity/result.json
artifacts/falsifiers/cold_miss_ledger/result.json
artifacts/falsifiers/swiftlm_source_intake/result.json
artifacts/falsifiers/provider_reference_manifest_dry_run/result.json
artifacts/falsifiers/70b_local_cocktail_lite/result.json
```

Those rungs prove the byte-range hashing ABI, the deterministic residency-plan
ABI, and the provider-reference manifest shape. They deliberately do not prove
live 70B generation. The 70B preflight must remain an honest red artifact until
prompt-level fp16/provider reference evidence exists.

## Command

```bash
Tools/falsifiers/f_architecture_pending_work_guard.sh
```

## Artifact

```text
artifacts/falsifiers/architecture_pending_work_guard/result.json
```

## Current Meaning

Current expected cursor:

```text
meta_breakthrough_card_registry
```

That means the canonical KV prompt suite, full-suite run plan, coactivation
tile prefetch witness, proof-carrying residency lease witness, 70B-lite cold
assembly witness, lattice-state-controller witness, reasoning-state-continuity
witness, cold-miss-ledger witness, SwiftLM source-intake witness, and
70B/provider-reference failure reports remain preserved as research evidence,
but 128K Qwen/GGUF/KV shard work and
provider-reference work are deferred by default. Do not repair or rerun KV
shards or create provider-reference manifests unless
`EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1` is set for an explicit long-context
probe. Continue `F-MetaBreakthrough-CardRegistry` as the default architecture
path after the SwiftLM source-intake witness without treating the Qwen/GGUF
shard route as active.

## Guard Axes

- `capability_kernel_artifact_available`
- `ordered_queue_available`
- `queue_gap_ids_unique`
- `queue_orders_unique`
- `queue_required_fields_present`
- `kv_prompt_suite_available`
- `kv_full_suite_run_plan_available`
- `kv_full_suite_run_plan_shape_ok`
- `kv_plan_prompt_ids_unique`
- `kv_plan_output_dirs_unique`
- `pending_work_cursor_available`
- `no_duplicate_rebuild_risk`
- `shard_cursor_mapped`
- `local_worktree_inventory_available`
- `local_worktree_inventory_non_destructive`
- `local_worktree_current_repo_present`
- `kv_model_context_inventory_available`
- `kv_model_context_inventory_non_destructive`
- `kv_model_context_canonical_context_ok`
- `weight_block_range_hash_dry_run_available`
- `residency_plan_dry_run_available`
- `residency_construction_graph_available`
- `coactivation_tile_prefetch_available`
- `proof_carrying_residency_lease_available`
- `cold_assembly_plan_70b_lite_available`
- `lattice_state_controller_available`
- `reasoning_state_continuity_available`
- `cold_miss_ledger_available`
- `swiftlm_source_intake_available`
- `provider_reference_manifest_dry_run_available`
- `local_70b_cocktail_honest_red`
- `large_model_provider_reference_required`

The `residency_plan_dry_run_available` axis includes the
`overlapping_ranges_rejected` sub-axis from `F-ResidencyPlan-DryRun`; a planner
that permits overlapping weight byte ranges must not advance to any mmap,
MLX, Metal, KV, or 70B runtime probe.

The `provider_reference_manifest_dry_run_available` axis includes the
`replay_files_valid` sub-axis from `F-ProviderReferenceManifest-DryRun`; a
manifest whose JSON shape is valid but whose retained replay files are missing
or digest-drifted must not count as reference readiness.

## Non-Drift Rule

This is not a product-performance gate. It is an execution hygiene gate. It can
be green while the Capability Ceiling remains red, because its job is to keep
the build order canonical, prevent duplicate partially-overlapping work, and
stop recursive loops from relaunching a watchdog-triggering Metal stall without
an explicit heavy-run opt-in.

It can also be green while the 70B local cocktail remains red. In that state,
the correct interpretation is:

```text
safe planner/manifest/checklist rungs exist
  + dangerous runtime probes are still gated
  + next runtime cursor remains explicit
  != 70B runtime pass
```
