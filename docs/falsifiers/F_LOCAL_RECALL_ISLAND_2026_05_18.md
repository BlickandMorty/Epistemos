---
falsifier: F-LocalRecallIsland
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-LocalRecallIsland

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the V6.2 episodic-plane recall island can wake for exact long-context recall and go dormant without exceeding the M2 Pro memory floor. |
| Current status | NOT IMPLEMENTED as a hardware/model gate. `agent_core/src/helios/local_recall_island.rs` provides an exact-match passkey substrate harness, but there is no `Epistemos/Shaders/LocalRecallIsland.metal`, no wired model runner, no 32K Granite artifact, and no T23B script. |
| Input fixture | Core lane: `granite-4.0-h-micro` GGUF Q4_K_M or `granite-4.0-h-tiny-3bit-MLX`, 32K context, 50 trials x 5 depths, Mohtashami-Jaggi passkey plus RULER `niah_single_1`; include floor-lane and Stretch runs only as separately labeled artifacts. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: Core lane peak memory <= 4.5 GB for model + KV/state + workspace, passkey recall >= 0.95, `niah_single_1` >= 0.95 over 250 trials, and all failures include depth/model/context labels. |
| Failure meaning | Episodic wakeup is not reliable or not resident on the 16 GB floor; exact recall cannot be used to justify long-context claims, active-support gating, or Brain Panel source certainty. |
| Fallback route | Fall back to ordinary vault retrieval and source-traced context packing. If Granite-4-H-Micro fails, try the Granite H-Tiny MLX route; if that fails, Phi-3.5-mini may be used only with an explicit caveat that it is not the hybrid long-context proof. |
| Product lane | MAS-safe Core only after 32K proof; 128K Stretch and pure-SSM controls remain opt-in Research. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_local_recall_island.sh` |
| Expected artifact | `artifacts/falsifiers/local_recall_island/result.json` with per-depth recall, model ID, context length, peak-memory trace, passkey/niah scores, and fallback-route outcome. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 1 memory retrieval bottleneck](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock) and [§3 claim 11 KV precision allocation](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§2 row 6 V6.2 falsifier order](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), where LocalRecallIsland is the recall proof after state-kernel and memory gates.

## Failure Criterion

This falsifier fails if Core peak memory exceeds 4.5 GB, if passkey or `niah_single_1` recall is below 0.95 over 250 trials, if failures omit depth/model/context labels, if Stretch evidence is presented as Core proof, or if no Jojo M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `peak_memory_gb`, `passkey_recall`, `niah_single_1`, and `depth_failure_labels`.
