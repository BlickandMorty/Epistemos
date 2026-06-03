---
state: canonical_no_gap_build_order
created_on: 2026-05-28
source_artifact: artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json
posture: executable queue beats prose; no hidden promotion paths
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS (Anchored Cognitive Substrate)/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# Architecture No-Gap Build Order - 2026-05-28

This is the human-readable mirror of the executable queue in
`artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json` at
`measurements.ordered_build_queue`.

The artifact is the authority. This doc explains the order so agents do not
invent a parallel roadmap.

## Current Verdict

| Field | Value |
|---|---|
| Route status | `vault_research_route_with_packetized_mitigation` |
| Overall pass | `false` |
| Next bottleneck | `research_construction_engine` |
| Canonical queue present | `true` |
| Unmapped architecture gap count | `0` |

`unmapped_architecture_gap_count=0` means every known remaining Capability
Ceiling / Pro Research / Pro Vault-Preserved gap has a queue row with
ProductBuild/ProStatus, witness, promotion condition, and rollback. It does
not mean the route is green.

2026-06-03 update: 128K Qwen/GGUF/KV-Direct work is deferred by default. It
remains available only for explicit heavy long-context probes with
`EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1`.

2026-06-03 update: 70B/GGUF/provider-reference work is no longer the active
architecture cursor while the app is routed through practical MLX local
inference. The preserved 70B artifacts stay honest red research evidence, but
they must not block the default loop or force a provider-reference manifest.

## Ordered Queue

| Order | Gap | Build/status | Current status | Promotion condition |
|---:|---|---|---|---|
| 0 | MAS current-app guard | MAS / CurrentApp | completed | Dense 36B remains 32 GB + opt-in; 70B stays Pro Vault-Preserved / Pro Research until artifacts pass. |
| 1 | Schema-normalized artifact floor | Verified Floor | completed | Route-consumed artifacts use the shared schema. |
| 2 | Verified Floor primary Metal | Verified Floor | completed | `F-ULP-Oracle` and `F-ControllerKernelPack` primary Metal witnesses stay green. |
| 3 | UAS / AcsAnchor / ColdStore hot-path floor | Verified Floor | completed | `F-UAS-CopyCount`, `F-ACS-AnchorLookup`, and legacy-named `F-UAS-ACS-MmapResidency` pass as schema witnesses. |
| 4 | PageGather packetized floor + caller | Capability Ceiling | completed | Packetized PageGather mitigation and caller-path packet consumption pass. |
| 5 | PageGather dense primary or accepted packet policy | Capability Ceiling | completed | `F-PageGather-Packetized-Policy-Acceptance` accepts packetized PageGather only for retrieval/witness packet surfaces while dense primary remains red. |
| 6 | KV-Direct live 128K inputs | Capability Ceiling | pending 128K context model | Canonical Qwen3-8B MLX identity is now explicitly guarded and passes (`Qwen/Qwen3-8B-MLX-4bit`), and the canonical prompt suite, smoke logits, file-backed prompt-cache reload, restartable prompt shards, shard merger, and 100 one-prompt shard full-suite run plan exist. The resolved local model config still declares only `40960` context tokens and `rope_scaling = none`. Resolve a canonical model asset/config with `model_context_window_tokens >= 128000`, then repair or rerun the preserved `shard_000_000` failure and produce paired logits, metrics JSON, `>=100` prompts, `>=128000` context tokens, and `>=256` decode tokens per prompt; the spill trace must prove `residual_patched_mmap_nf4_ssd_spill` with residual patching, mmap-backed cold KV, NF4/equivalent storage, and positive cold bytes. Candidate plans for noncanonical long-context models are allowed only as research evidence. |
| 7 | Agent local-model runtime bridge | Pro / Agent Runtime | `ready_for_capability_ceiling_recheck` | `F-Agent-Local-Model-Runtime-Bridge` is now a schema-valid primary witness for the guarded local-model bridge slice: LocalAgent adapter dispatch is wired, Rust emits a `LocalMlx` handoff, Swift consumes it through the registered local client, a retained live prompt-suite artifact records token streaming from `Qwen/Qwen3-8B-MLX-4bit`, and AnswerPacket local-model provenance is present. This does not promote 70B, 128K, or KV-Direct. |
| 8 | Active Assembly runtime floor | Capability Ceiling | completed | Synthetic runtime witness proves small support with bounded drift. |
| 9 | Sparse Runtime Split floor | Capability Ceiling | completed | Synthetic sparse/reference split passes KL, active-ratio, cost-ratio, and chart-label axes. |
| 10 | Live sparse 70B runtime + chart coverage | Pro Vault-Preserved / Capability Ceiling | `large_model_provider_reference_deferred_by_mlx_route` | Deferred under the active MLX route unless explicitly re-enabled for research. |
| 11 | 70B prompt-level cocktail | Pro Omega / Beyond | `large_model_provider_reference_deferred_by_mlx_route` | No active provider-reference prompt-level work is required for the MLX route. |
| 12 | Research Construction Engine | Pro Research | `next_active_architecture_cursor` | Motifs become ProblemCards with WBO budget, falsifier, witness, ProductBuild, ProStatus/ResidencyStatus, and rollback. |

## Safe Non-Runtime 70B Rungs

These rungs are allowed while runtime-heavy probes are paused:

| Artifact | Status | Meaning |
|---|---|---|
| `F-WeightBlockRangeHash-DryRun` | green | The `WeightBlockManifest` byte-range hashing ABI rejects over-budget ranges before reading and supports known-hash manifests without touching model files. |
| `F-ResidencyPlan-DryRun` | green | A deterministic `ResidencyPlan` can represent a model-shaped 72 GiB cold body with a bounded hot/warm active set, rollback, WBO, and Sherry/Leech/NF4 route labels while loading zero model bytes. |
| `F-ProviderReferenceManifest-DryRun` | green | The provider/reference manifest ABI is digest-bound and prompt-suite-bound, but shape-only fixtures cannot advance the 70B comparison gate. |
| `F-ProviderReferencePromptLevel-Readiness` | deferred red | Preserved as research evidence only; not required by the default MLX architecture cursor. |
| `F-70B-Local-Cocktail-Lite` | deferred red | The route has safe planner rungs but remains non-product research unless explicitly re-enabled for heavy long-context/provider-reference work. |

The pending-work guard now requires the safe planner states above only when the
large-model/provider-reference route is an explicit active cursor. This keeps the
no-compromise SSD/UMA/UAS/ColdStore/AcsAnchor ambition alive without letting a
loop accidentally relaunch the heavy runtime path that can destabilize the
laptop.

## Non-Drift Rules

- Do not lower the dense 36B RAM gate to make the 70B story look green.
- Do not require 70B/GGUF/provider-reference setup while the active local route
  is MLX; keep it deferred unless the user explicitly re-enables that research
  lane.
- Do not treat synthetic Active Assembly or synthetic Sparse Runtime Split as
  live model proofs.
- Do not treat KV-Direct QK equality as the 128K SSD-spill gate.
- Do not treat alternate long-context model runs as the canonical Qwen3-8B
  falsifier; the `model_identity_matches_canonical` axis must stay true.
- Do not treat local model catalog metadata as a live agent runtime proof; the
  local agent bridge must stream from MLX/GGUF and carry AnswerPacket
  provenance before it can turn green.
- Do not rerun the 128K KV shard plan against a model config that only
  declares `40960` context tokens.
- Do not treat file-backed MLX prompt-cache reload as the residual-patched
  mmap/NF4 SSD-spill oracle.
- Do not treat `F-UAS-ACS-MmapResidency` as live MLX generation or a 70B pass;
  it is legacy-named and proves file-backed UAS + AcsAnchor/ColdStore-style
  residency for a deterministic KV-page slice only.
- Do not accept `spill_labeling=true` unless the spill trace itself names the
  canonical residual-patched mmap/NF4 route and carries cold-KV byte evidence.
- Do not treat PageGather packetized mitigation as dense primary PageGather.
- Do not treat `F-PageGather-Packetized-Policy-Acceptance` as anything beyond
  retrieval/witness packet policy; dense `F-PageGather-M2Pro` is still red.
- Do not treat `F-WeightBlockRangeHash-DryRun`,
  `F-ResidencyPlan-DryRun`, or `F-ProviderReferenceManifest-DryRun` as live
  generation proof; they are the safe manifest/planner floor before runtime.
- Do not move Research Construction ahead of the measured runtime gates unless
  it produces a falsifier-backed candidate artifact and stays Pro Research /
  candidate status.

## Loop Rule

Every architecture loop starts by running:

```bash
Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh
Tools/audits/epistemos_worktree_inventory.sh
Tools/audits/kv_direct_model_context_inventory.sh
Tools/falsifiers/f_architecture_pending_work_guard.sh
```

Then read:

```text
measurements.next_bottleneck.value
measurements.ordered_build_queue.value
artifacts/falsifiers/architecture_pending_work_guard/result.json measurements.next_existing_work.value
docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json summary.high_duplicate_risk_count
docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json summary.canonical_context_ok
docs/audits/KV_DIRECT_CANONICAL_MODEL_RESOLUTION_2026_05_28.md
```

Implement one row or the guard's next existing work cursor, regenerate its
artifact, rerun the kernel and guard, and update this doc only when the
executable queue changes.

Current local inventory warning: `Downloads` contains many Epistemos sibling
worktrees and copies. Treat dirty sibling worktrees as preserve/inspect
surfaces, not as permission to create another duplicate worktree.
