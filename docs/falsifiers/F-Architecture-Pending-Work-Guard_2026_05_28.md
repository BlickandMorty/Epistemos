---
falsifier: F-Architecture-Pending-Work-Guard
created_on: 2026-05-28
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PRIMARY WORK-QUEUE GUARD IMPLEMENTED
---

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

The guard also reads the separate GGUF candidate artifact:

```text
artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json
```

That route is tracked so agents do not create a second GGUF fallback scaffold,
but it is deliberately not allowed to satisfy the canonical MLX
`F-KV-Direct-Gate`.

The model-resolution audit
`docs/audits/KV_DIRECT_CANONICAL_MODEL_RESOLUTION_2026_05_28.md` records the
public/local conclusion: exact canonical Qwen3-8B MLX identity is present but
context-red; 128K alternatives are candidate-tier unless the falsifier is
explicitly retargeted.

The guard also verifies that known-crashy long-context probes are opt-in only.
Both the GGUF bench helper and app-facing local-agent loop must preserve the
same safety rule: normal automatic local runs stay at or below `32768` context
tokens, and anything larger requires the explicit
`EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1` environment gate. This is an execution
safety bit, not a demotion of the UAS/ACS/70B ambition.

The guard now also consumes the safe non-runtime large-model rungs that must
exist before another 128K/70B runtime probe:

```text
artifacts/falsifiers/weight_block_range_hash_dry_run/result.json
artifacts/falsifiers/residency_plan_dry_run/result.json
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
repair_qwen3_8b_128k_gguf_metal_stall
```

That means the canonical KV prompt suite and full-suite run plan already
exist, the preserved first-shard failure should not be rerun against the
context-red canonical MLX asset, and the already-mapped GGUF fallback split is
the active non-duplicate runtime route. The local GGUF file and 131,072-token
metadata are present. The new 128K q4_0/flash-attn probe manifest shows the
run reached Metal residency but exited without metrics after waiting on a
Metal command buffer. The 2026-05-29 probe ladder further narrows the issue:
best successful local GGUF probe is 32K/256 with f16 KV; quantized KV fails
context creation without flash-attention; flash-attention times out even at
8K; disabling KV offload is not a repair. The next agent should repair or
bypass that specific GGUF backend/cache policy stall before creating any new
prompt suite, planner, or parallel scaffold.

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
- `qwen3_8b_128k_gguf_candidate_artifact_available`
- `heavy_long_context_guard_present`
- `weight_block_range_hash_dry_run_available`
- `residency_plan_dry_run_available`
- `provider_reference_manifest_dry_run_available`
- `local_70b_cocktail_honest_red`

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
