---
falsifier: F-PageGather-Baseline
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-PageGather-Baseline

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Calibrate the M2 Pro contiguous-memory floor that every PageGather scatter threshold depends on. |
| Current status | NOT IMPLEMENTED as a hardware gate. `Epistemos/Shaders/PageGather.metal` and `agent_core/src/helios/page_gather.rs` exist as substrate scaffolding, but `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` explicitly caveats Helios kernel hardware validation as separate; no `falsifier_calibration.toml` or T23B script exists. |
| Input fixture | STREAM-on-Metal-style contiguous read probe over 256 MB, 512 MB, and 1 GB buffers; 5 runs per size; each measurement window must be at least 1.0 s. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: record median `BW_baseline_M2Pro` per buffer and overall. Canon expects the local sustained band to drive later thresholds, commonly 63-73 GB/s after recalibration, never 70% of theoretical 200 GB/s. |
| Failure meaning | Scatter gates become numerology: using theoretical or sub-second burst bandwidth would either create an impossible pass bar or hide memory-path regressions. |
| Fallback route | If `BW_baseline_M2Pro` is below 60 GB/s, lower the scatter pass band to at least 65% of the measured baseline and document the rig state; do not pretend. |
| Product lane | Research / V2 falsifier-gated; MAS-safe only after measured floor exists. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_page_gather_baseline.sh` |
| Expected artifact | `artifacts/falsifiers/page_gather/baseline/falsifier_calibration.toml` plus raw per-run timing JSONL. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 4 Apple Silicon unified memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock) and [§3 claim 15 typed buffers/shared memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§2 row 6 V6.2 falsifier order](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), where PageGather baseline is the first M2 Pro hardware gate.

## Failure Criterion

This falsifier fails if `BW_baseline_M2Pro` is absent, if any measurement window is shorter than 1.0 s, if the row uses theoretical 200 GB/s bandwidth as the pass floor, or if the raw timing artifact is not produced on Jojo's M2 Pro 16 GB UMA rig.

## Artifact Schema Axes

The expected calibration artifact must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `median_bw_256mb`, `median_bw_512mb`, `median_bw_1gb`, and `window_seconds`.
