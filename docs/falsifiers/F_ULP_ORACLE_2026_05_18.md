---
falsifier: F-ULP-Oracle
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PARTIAL SUBSTRATE, NOT FULLY PASSED
---

# F-ULP-Oracle

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the Metal arithmetic floor for EML's `exp`, `ln`, and fused `eml(x,y)=exp(x)-ln(y)` before AnswerPacket schema or claim-envelope arithmetic is frozen. |
| Current status | PARTIAL SUBSTRATE, NOT FULLY PASSED. `Epistemos/Shaders/morph_eval_reduced.metal` and `agent_core/src/research/eml/ulp_oracle.rs` exist, but the shader is not wired by a Swift dispatcher and the module only runs a 1,024-point smoke shape. The full 412k + 2,048 stress-point M2 Pro fixture has not produced a T23B artifact or script. |
| Input fixture | 412,000 log-sampled fp16 points across `[2^-15, 2^15] x [2^-15, 2^15]`, plus 2,048 stress points covering denormals, +/-0, +/-Inf, NaN, and `ln` branch cuts; compare Metal fp16 output to fp64/Rust oracle using sign-correct ordered-bit ULP distance. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: every comparable point in `[0.5, 2]` is <= 2 ULP fp16, stress cases are classified rather than silently counted, and the full run completes in < 90 s wall-clock. |
| Failure meaning | The arithmetic substrate is not empirically sealed; AnswerPacket schema freeze, EML claim envelopes, and any Metal `exp`/`ln` accuracy claim remain blocked. |
| Fallback route | Use Rust/fp64 reference arithmetic for proofs and keep AnswerPacket schema/claim-envelope freezing blocked until the full M2 Pro ULP artifact passes. |
| Product lane | Verified Floor / Research gate before schema freeze; not a user-facing product lane until passed. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_ulp_oracle.sh` |
| Expected artifact | `artifacts/falsifiers/ulp_oracle/result.json` with max/mean ULP, outside-bar count, stress-case taxonomy, wall-clock timing, and shader build flags. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 15 typed buffers/shared memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because arithmetic evidence must be replayed from typed numeric fixtures.
- Unified Active Substrate Canon: [§4 terminal prompt cross-link](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#4-uas-acs-cross-link-map), where Terminal D gates MissionPacket and AnswerPacket schema work on F-ULP-Oracle.

## Failure Criterion

This falsifier fails if any comparable `[0.5, 2]` point exceeds 2 ULP fp16, if stress cases are silently counted instead of classified, if the full run exceeds 90 s without calibrated-budget documentation, or if no Jojo M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `max_ulp`, `comparable_points_over_2ulp`, `stress_case_classification`, and `wall_clock_seconds`.
