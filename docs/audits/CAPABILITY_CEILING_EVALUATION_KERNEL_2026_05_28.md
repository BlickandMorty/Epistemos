---
state: implemented_red_route_kernel
created_on: 2026-05-28
scope: MAS through Verified Floor, Capability Ceiling, Research, Vault, and beyond
artifact: artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json
posture: no-compromise; failures stay visible until measured gates pass
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# Capability Ceiling Evaluation Kernel - 2026-05-28

## Result

`F-Capability-Ceiling-Evaluation-Kernel` now exists as a schema-valid route
artifact. It does not claim the 16 GB / 70B route is ready. It reads the current
local falsifier artifacts and emits one route verdict:

| Field | Current value |
|---|---|
| Route status | `vault_research_route_with_packetized_mitigation` |
| Overall pass | `false` |
| Next bottleneck | `resolve_qwen3_8b_128k_context_model_assets_for_kv_direct` |
| Command | `Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh` |
| Artifact | `artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json` |
| Ordered queue | `measurements.ordered_build_queue` |
| Unmapped architecture gaps | `0` |

The kernel is deliberately a route governor, not another benchmark. Every
future large-local-model pass should run this first, do the named next
bottleneck, then rerun it.

Human-readable queue mirror:
`docs/audits/ARCHITECTURE_NO_GAP_BUILD_ORDER_2026_05_28.md`.

## Current Route Truth

| Axis | Status | Meaning |
|---|---|---|
| `verified_floor_green` | pass | `F-ULP-Oracle` and `F-ControllerKernelPack` are primary Metal witnesses. |
| `page_gather_packetized_floor_pass` | pass | Packetized PageGather clears the mitigation floor. |
| `page_gather_dense_primary_pass` | fail | Dense restore / dense primary PageGather is still too slow. |
| `page_gather_packetized_caller_pass` | pass | `VaultStore::hybrid_search_with_trace` consumes retained-score packets and defers dense restore. |
| `kv_direct_tier1_preflight_pass` | pass | Rust QK equality and dispatch contract pass. |
| `kv_direct_live_contract_present` | pass | The falsifier can consume model/logit/metrics/spill inputs and compute average D_KL from prompt logits. |
| `kv_direct_model_assets_available` | pass | The harness auto-detects the local Qwen3-8B MLX snapshot under Epistemos app-support storage. |
| `kv_direct_model_identity_matches_canonical` | pass | The resolved asset is `Qwen/Qwen3-8B-MLX-4bit`; alternate long-context assets are candidate-tier only unless canon changes the falsifier target. |
| `kv_direct_model_context_supports_required_context` | fail | The resolved local snapshot declares `40960` context tokens with no rope scaling; the 128K run is blocked until a model asset/config honestly supports `>=128000`. |
| `kv_direct_prompt_suite_manifest_available` | pass | `artifacts/falsifiers/kv_direct_gate/prompt_suite.json` exists. |
| `kv_direct_prompt_suite_shape_pass` | pass | The manifest declares 100 prompts, 128K target context, 256 decode tokens, and balanced 25/25/25/25 family coverage. |
| `kv_direct_full_suite_run_plan_available` | pass | `Tools/falsifiers/plan_kv_direct_mlx_shards.sh --shard-size 1 --prefill-step-size 512 --write-shell` wrote a restartable 100-shard full-suite plan under `artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/`. |
| `kv_direct_logits_available` | fail | The 100-prompt paired reference/test logits are not emitted yet. |
| `kv_direct_live_metrics_available` | fail | Peak RSS, decode tok/s, suite wall-clock, context-window, decode-token, and spill-label metrics are not emitted yet. |
| `kv_direct_spill_trace_available` | fail | No SSD-spill trace witness exists yet. |
| `kv_direct_spill_trace_contract_pass` | fail | The trace must name `residual_patched_mmap_nf4_ssd_spill`, prove residual patching, mmap-backed cold KV, NF4/equivalent quantized storage, and `cold_kv_bytes > 0`; prompt-cache reload cannot satisfy this. |
| `kv_direct_live_shape_floor_pass` | fail | The live fixture has not yet proven `>=100` prompts, `>=128000` context tokens, and `>=256` decode tokens per prompt. |
| `kv_direct_live_128k_pass` | fail | Qwen3-8B 128K SSD-spill D_KL/RSS/tok/s metrics are not measured yet; the 2026-05-28 harness contract exists, can run smoke logits, supports restartable prompt shards, refuses undersized fixtures, and now refuses model configs that do not support the target context. |
| `agent_local_model_runtime_bridge_pass` | pass | `F-Agent-Local-Model-Runtime-Bridge` exists as a schema-valid primary witness for the guarded local-model bridge slice. The model catalog, MLX client, GGUF client, `ProviderPolicy::LocalMlx`, System G event seam, Rust LocalAgent adapter dispatch, Rust-to-Swift local-model handoff, registered local client consumption, retained live prompt-suite artifact, and AnswerPacket local-model provenance are present. This does not promote KV-Direct, 128K, or 70B capability-ceiling routes. Current bridge bottleneck: `ready_for_capability_ceiling_recheck`. |
| `active_assembly_shape_proof_available` | pass | Shape proof/test exists. |
| `active_assembly_runtime_artifact_pass` | pass | `F-ActiveAssembly-Minimal` now has a schema-valid primary synthetic runtime witness: 0 output-bound violations, `0.0021` cost ratio, `0.0322` firing ratio, and `117.709 us` p99 wall time. |
| `sparse_runtime_split_artifact_pass` | pass | `F-Sparse-Runtime-Split` now has a schema-valid primary synthetic runtime witness over 1000 prompts with `0.0` KL, `0.0176` active ratio, `0.0067` cost ratio, and EML/Geometry/Scan/Operator chart labels. |
| `uas_copy_count_hot_path_pass` | pass | Schema-normalized primary witness passes. |
| `acs_anchor_lookup_pass` | pass | Schema-normalized primary witness passes. |
| `uas_acs_mmap_residency_pass` | pass | Legacy `F-UAS-ACS-MmapResidency` is a schema-valid primary witness for a 16 MiB file-backed mmap KV-page slice with UAS address round-trip, AcsAnchor projection lookup, residency lease round-trip, checksum proof, invalid-offset rejection, and zero tracked hot-path copies. It is not a live MLX or 70B proof. |
| `all_gate_artifacts_schema_normalized` | pass | UAS copy-count, AcsAnchor lookup, and UAS/AcsAnchor mmap residency all use the shared artifact shape. |
| `seventy_b_route_pass` | fail | 70B Local Cocktail Lite is still a failure report. |
| `canonical_build_queue_present` | pass | The route artifact contains the ordered no-gap build queue. |
| `unmapped_architecture_gap_count` | pass | Current value is `0`; every known remaining route gap has tier, witness, promotion condition, and rollback. |

## Manageable Tier System

This is the build ladder agents should use instead of inventing new labels.

| Tier | Meaning | Current action |
|---|---|---|
| MAS / CurrentApp | Shippable app behavior on 16 GB without research claims. | Keep dense 36B gated at 32 GB. Do not expose 70B as product. |
| Verified Floor | Local measured substrate facts on the M2 Pro floor. | Keep Metal ULP, ControllerKernelPack, UAS copy-count, AcsAnchor lookup, and UAS/AcsAnchor mmap residency green. |
| Capability Ceiling | The 16 GB / 70B-class UAS/AcsAnchor route. | Advance live KV-Direct, sparse split, and chart coverage. |
| Research Construction | Candidate primitives and public-research motifs under falsifier control. | Convert motifs into ProblemCards, ConstructionGraph rows, WBO budgets, and falsifiers. |
| Vault / Beyond | Ambitious preserved work that may become product only after gates pass. | Keep 70B, L_SE, parameter anchors, circuits, and self-evolving adapters behind red artifacts until measured. |

## Recursive Loop Protocol

Every loop pass should do exactly this:

1. Run `Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh`.
2. Run `Tools/audits/epistemos_worktree_inventory.sh`.
3. Run `Tools/audits/kv_direct_model_context_inventory.sh`.
4. Run `Tools/falsifiers/f_architecture_pending_work_guard.sh`.
5. Read `measurements.next_bottleneck.value`.
6. Read `measurements.ordered_build_queue.value`.
7. Read
   `artifacts/falsifiers/architecture_pending_work_guard/result.json`
   `measurements.next_existing_work.value`.
8. Read
   `docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json`
   before creating any sibling worktree, terminal folder, or duplicate
   artifact surface.
9. Read
   `docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json`
   before changing model IDs, model paths, or long-context KV runner plans.
10. Read `docs/audits/KV_DIRECT_CANONICAL_MODEL_RESOLUTION_2026_05_28.md`
   before treating any 128K-labeled derivative as the canonical Qwen3-8B MLX
   target.
11. Do not run any local 65K/128K/70B-class model probe unless the command is
    deliberately heavy-run gated. The current shared safety gate is
    `EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1`; normal app/local-agent loops stay
    under the 32K envelope while the GGUF Metal stall remains the active
    bottleneck.
12. Implement one narrow slice for the first pending or blocked row you can
   honestly advance.
13. Emit or update the corresponding falsifier artifact.
14. Rerun the kernel, inventories, pending-work guard, and validator.
15. Update the audit doc only if a route axis or queue row changed.

This makes the loop autonomous without becoming vague. The kernel is the queue;
the pending-work guard is the de-dup cursor; the inventory is the local
worktree-sprawl warning system.

## Ordered Implementation Plan

1. Normalize legacy artifacts. **Done on 2026-05-28.**
   - Convert `artifacts/falsifiers/uas_copy_count/result.json` and
     `artifacts/falsifiers/acs_anchor_lookup/result.json` to the shared
     `FalsifierArtifact` shape.
   - Preserve the pass values; do not re-measure unless the harness is cheap.
   - Kernel axis flipped: `all_gate_artifacts_schema_normalized=true`.

1A. Prove file-backed UAS / ACS mmap residency. **Done on 2026-05-28.**
   - `Tools/falsifiers/f_uas_acs_mmap_residency.sh` emits
     `artifacts/falsifiers/uas_acs_mmap_residency/result.json`.
   - The witness maps a deterministic 16 MiB backing file with `mmap`,
     addresses it as `UasKind::KvPage`, links it to a
     `UasKind::ModelComponent`, leases it through `ResidencyLease`, resolves an
     ACS anchor through projection lookup, verifies sampled page checksums,
     rejects invalid offsets, and records zero tracked hot-path copies.
   - Kernel axis flipped: `uas_acs_mmap_residency_pass=true`.
   - Scope guard: this proves file-backed residency and addressing only. It
     does not satisfy `F-KV-Direct-Gate`, live MLX generation, or
     `F-70B-Local-Cocktail-Lite`.

2. Promote PageGather packetized caller consumption. **Fallback witness done on 2026-05-28.**
   - Wire `(logical_position, value)` packets through one non-hot retrieval or
     witness path before dense restore.
   - Add an end-to-end artifact showing packet consumption avoids the dense
     scatter bottleneck for that path.
   - Kernel axis flipped: `page_gather_packetized_caller_pass=true`.

3. Build live KV-Direct 128K harness. **Contract, canonical suite, full-suite run plan, first-shard failure evidence, model-identity guard, and model-context guard are done; canonical MLX remains context-red, so current executable work is repairing the separate GGUF fallback/candidate 128K Metal stall.**
   - Qwen3-8B MLX local assets are detected by the harness, but the resolved
     local snapshot currently declares only `40960` context tokens and
     `rope_scaling = none`.
   - `Tools/falsifiers/kv_direct_prompt_suite.sh` emits
     `artifacts/falsifiers/kv_direct_gate/prompt_suite.json`: 100 prompts,
     128K target context, 256 decode tokens, balanced across long-prefix
     recall / multi-turn / code-completion / reasoning.
   - `Tools/falsifiers/f_kv_direct_gate.sh` now accepts:
     `EPISTEMOS_KV_DIRECT_MODEL_PATH`,
     `EPISTEMOS_KV_DIRECT_PROMPT_SUITE`,
     `EPISTEMOS_KV_DIRECT_LOGITS_PATH` or paired
     `EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS` /
     `EPISTEMOS_KV_DIRECT_TEST_LOGITS`,
     `EPISTEMOS_KV_DIRECT_METRICS_PATH`, and
     `EPISTEMOS_KV_DIRECT_SPILL_TRACE`.
   - `Tools/falsifiers/plan_kv_direct_mlx_shards.sh --shard-size 1 --prefill-step-size 512 --write-shell`
     now writes `artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/full_suite_run_plan.json`
     and `run_all_shards.sh`. The route kernel consumes this as
     `kv_direct_full_suite_run_plan_available=true`.
   - First keep `model_identity_matches_canonical=true`, then resolve
     `model_context_window_tokens >= 128000`, then record
     `>=100` paired prompt logits, `>=128000` context tokens,
     `>=256` decode tokens per prompt, D_KL/token, peak RSS, decode tok/s,
     wall clock, and spill labels.
   - Kernel axis expected to flip: `kv_direct_live_128k_pass`.

3A. Attach the Swift/MLX or Python/MLX runner to the contract. **Next executable slice.**
   - `Tools/falsifiers/run_kv_direct_mlx_live.sh` now uses the detected
     Qwen3-8B MLX 4-bit snapshot and materializes the canonical prompt suite
     with the resolved tokenizer.
   - A 1-prompt / 512-context / 1-decode smoke run emitted real full-vocabulary
     reference/test logit rows and metrics under
     `artifacts/falsifiers/kv_direct_gate/live_mlx/`; it intentionally does
     not satisfy the falsifier.
   - The runner now labels `full_kv`, `kv_quantized`, and
     `prompt_cache_reload` routes. `prompt_cache_reload` saves an MLX prompt
     cache to disk, clears memory, reloads it, and emits test logits from the
     reloaded cache. The first smoke run wrote a 75 MB cache file and had low
     D_KL, but it is still only a file-backed reload witness, not the final
     residual-patched mmap/NF4 SSD-spill oracle.
   - The runner now accepts `--prompt-offset`, and
     `Tools/falsifiers/merge_kv_direct_mlx_shards.sh` merges restartable
     shard directories into the canonical paired-logit / metrics / spill-trace
     inputs consumed by `F-KV-Direct-Gate`.
   - `Tools/falsifiers/plan_kv_direct_mlx_shards.sh --shard-size 1 --prefill-step-size 512 --write-shell`
     materializes the current 100 one-prompt shard full-suite plan. It is marked
     `falsifier_green_capable=false` because the current executable runner
     route is `prompt_cache_reload`, not the final residual mmap/NF4 SSD-spill
     oracle.
   - `Tools/falsifiers/plan_kv_direct_mlx_shards.sh --model-path ...` can also
     materialize candidate-tier long-context plans. The current
     `live_mlx_candidate_qwen3_coder_next_plan` points at
     `mlx-community/Qwen3-Coder-Next-4bit` and records
     `model_identity_matches_canonical=false`, so it is useful for runtime
     exploration but cannot satisfy the canonical Qwen3-8B falsifier.
   - `shard_000_000` now has failure evidence: the `2048` prefill-step attempt
     aborted with a Metal interactivity command-buffer error, and the `512`
     prefill-step retry was stopped after about 14 minutes with zero completed
     prompt rows. That evidence stays on disk, but the pending-work guard now
     reports `resolve_qwen3_8b_128k_context_model_assets_for_kv_direct`
     because the canonical MLX model remains context-red. Do not redirect this
     row into the removed optional candidate route.
   - Next after the model/context axis is green: run the full 100-prompt
     reference/test logits with an SSD-spill route, not merely the current
     KV-quantized or prompt-cache-reload development routes.
   - The route kernel now refuses noncanonical spill traces. A future trace
     must explicitly prove `residual_patched_mmap_nf4_ssd_spill`,
     residual patching, mmap-backed cold KV, NF4/equivalent storage, and a
     positive cold-KV byte count.
   - Write paired logits and metrics JSON in the shapes documented by
     `docs/falsifiers/F_KV_DIRECT_GATE_2026_05_18.md`.
   - Do not mark `F-KV-Direct-Gate` green unless the model path, model-context
     floor, logits, metrics, spill trace, and live fixture shape floor all
     exist and pass the thresholds.

3B. Wire the agent local-model runtime bridge. **Primary guarded bridge witness is present; adapter dispatch, System G local-model handoff, Swift local-client consumption, retained live prompt suite, and AnswerPacket provenance are landed.**
   - `Tools/falsifiers/f_agent_local_model_runtime_bridge.sh` emits
     `artifacts/falsifiers/agent_local_model_runtime_bridge/result.json`.
   - Current pass axes prove the catalog and local runtime clients are present:
     Qwen3 floor fallback preserved, dense 36B gate preserved, MLX client
     available, GGUF client available, `ProviderPolicy::LocalMlx` available,
     and System G event seam available.
   - The LocalAgent adapter now admits/refuses capabilities and produces a
     typed local MLX provider plan.
   - Rust System G accepts `ProviderPolicy::LocalMlx`, emits a local-model
     handoff, and does not falsely pretend the Rust V1 seam owns Swift/MLX
     generation.
   - Swift consumes that handoff through the registered local client, and the
     retained live prompt-suite artifact records `Qwen/Qwen3-8B-MLX-4bit`, `10`
     token chunks, local-model handoff visibility, and AnswerPacket provenance.
   - Kernel axis flipped for the guarded local bridge slice:
     `agent_local_model_runtime_bridge_pass`.
   - Remaining red capability-ceiling surfaces are separate: canonical
     KV-Direct 128K, GGUF 128K Metal stall, and 70B/UAS prompt-level runtime.

4. Promote Active Assembly from shape proof to runtime artifact. **Done on 2026-05-28 for the synthetic packet-graph gate.**
   - `Tools/falsifiers/f_active_assembly_minimal.sh` emits
     `artifacts/falsifiers/active_assembly_minimal/result.json`.
   - The artifact keeps small support (`firing_ratio`) and bounded behavior
     (`output_bound_violation_count`) as separate axes.
   - Kernel axis flipped: `active_assembly_runtime_artifact_pass=true`.
   - Live model packet routing remains a later Capability Ceiling slice.

5. Add sparse runtime split and chart coverage. **Synthetic substrate witness done on 2026-05-28.**
   - `Tools/falsifiers/f_sparse_runtime_split.sh` emits
     `artifacts/falsifiers/sparse_runtime_split/result.json`.
   - Bounded synthetic sparse/reference path passes `average_d_kl_nats <= 0.05`,
     `active_assembly_ratio < 0.40`, and `cost_ratio < 0.40`.
   - EML/Geometry/Scan/Operator chart coverage labels exist for the synthetic
     route.
   - Live 70B sparse runtime and live 70B chart coverage remain red.

6. Replace the 70B sentinel run with real inputs.
   - Set `EPISTEMOS_70B_MODEL_PATH`.
   - Set `EPISTEMOS_70B_PROVIDER_REFERENCE`.
   - Replace D_KL, TTFT, tok/s, RSS, and bottleneck sentinel values.
   - Kernel axis expected to flip only after the composed route passes.

## No-Compromise Guard

The kernel must stay stricter than product copy. It is allowed to say "red" for
weeks. It is not allowed to hide missing measurements behind an opt-in toggle,
cloud lane, dense MLX route, or Pro Research name.

Motion / UAS / Plane / Residency / WBO / Witness / Falsifier / Tier / Rollback:

| Field | Kernel stance |
|---|---|
| Motion | Project / Compress / Recall route verdict from artifact substrate to one visible gate. |
| UAS | Artifact paths are the current address surface; future revision should add UAS addresses for each artifact row. |
| Plane | Verification plane. |
| Residency | VerifiedFloor and CapabilityCeiling. |
| WBO | Route-level approximation budget remains unpaid until live KV, PageGather dense/primary or accepted packetized policy, live sparse 70B, and 70B composition pass. |
| Witness | `artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json`. |
| Falsifier | `F-Capability-Ceiling-Evaluation-Kernel`. |
| Tier | Failure report; Pro Vault-Preserved / Pro Research route only. |
| Rollback | Remove the route artifact from product health surfaces; keep dense MLX gates unchanged. |
