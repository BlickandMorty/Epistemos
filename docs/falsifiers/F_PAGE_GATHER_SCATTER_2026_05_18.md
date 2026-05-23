---
falsifier: F-PageGather-Scatter
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-PageGather-Scatter

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the active-support memory law by measuring PageGather scatter against the locally measured contiguous baseline. |
| Current status | NOT IMPLEMENTED as a hardware gate. `pageGatherScatter` and `pageGatherScatterScaled` exist in `Epistemos/Shaders/PageGather.metal`, and the CPU reference exists in `agent_core/src/helios/page_gather.rs`; no Swift dispatcher, M2 Pro timing run, or T23B script evidence exists. |
| Input fixture | Random page-stride index lists over 256 MB and 512 MB source buffers, plus sequential control indices; use the `BW_baseline_M2Pro` artifact from F-PageGather-Baseline. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: sustained scatter throughput is at least 70% of `BW_baseline_M2Pro` over windows of at least 1.0 s for the required working sets; output bytes match the CPU reference. |
| Failure meaning | Active-support page movement is too slow or unverified; LocalRecallIsland and memory-tier claims cannot use PageGather as their bandwidth floor. |
| Fallback route | Do not run scatter without a baseline. If baseline is low but documented, use the documented lowered percentage route from F-PageGather-Baseline; otherwise keep PageGather feature-gated. |
| Product lane | Research / V2 falsifier-gated; MAS Tier-2 only after gate evidence. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_page_gather_scatter.sh` |
| Expected artifact | `artifacts/falsifiers/page_gather/scatter/result.json`, raw timings, baseline reference, and CPU-vs-Metal correctness digest. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 4 Apple Silicon unified memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock) and [§3 claim 15 typed buffers/shared memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§2 row 6 V6.2 falsifier order](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), where scatter depends on the PageGather baseline gate before any active-support memory claim.

## Failure Criterion

This falsifier fails if `BW_baseline_M2Pro` is missing, if sustained scatter throughput is below 70% of that measured baseline over at least 1.0 s, if output bytes differ from the CPU reference, or if the M2 Pro artifact hides sequential-only control behavior.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `scatter_bw_256mb`, `scatter_bw_512mb`, `baseline_ratio`, `correctness_digest`, and `window_seconds`.
