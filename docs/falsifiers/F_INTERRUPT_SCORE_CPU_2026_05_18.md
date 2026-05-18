---
falsifier: F-InterruptScore-CPU
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PARTIAL EVIDENCE, NOT FULLY PASSED
---

# F-InterruptScore-CPU

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Verify the V6.2 interrupt equation on the canonical Swift CPU path, not an always-on Metal kernel. |
| Current status | PARTIAL EVIDENCE, NOT FULLY PASSED. `Epistemos/Engine/InterruptScoreCpu.swift` implements the five-term equation and `EpistemosTests/InterruptScoreCpuTests.swift` contains a 10,000-iteration P99 test with 500 us CI headroom. The canon's exact falsifier remains P99 < 100 us over 10^5 trials, and no T23B artifact script exists. |
| Input fixture | Synthetic and corpus-derived `InterruptScoreInputs` covering LOW/MED/HIGH calibration cases, NaN/Inf clamps, all-zero, all-one, and route-change observer inputs. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: `u_t = 0.30H + 0.25WBO + 0.20Sheaf + 0.15ToolNeed + 0.10ConnectomeAlarm`; output in [0,1]; bucket boundaries at 0.25 and 0.65; P99 compute latency < 100 us over 100,000 trials on the CPU path. |
| Failure meaning | Attention-as-interrupt cannot be trusted for single-token routing; GPU dispatch may be overkill and CPU path may still be too slow or incorrectly bucketed. |
| Fallback route | Keep CPU path canonical but gate routing effects; use static 9:1 fallback or batch-only Metal shadow for >=64-token lanes until the exact P99 artifact passes. |
| Product lane | MAS-safe Tier-1 once exact P99 artifact exists. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_interrupt_score_cpu.sh` |
| Expected artifact | `artifacts/falsifiers/interrupt_score_cpu/result.json` with p50/p95/p99, bucket confusion table, and input-clamp checks. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 2 honest capability gating](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because interrupt routing must stay bounded to the path actually measured.
- Unified Active Substrate Canon: [§2 row 6 V6.2 falsifier order](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), where InterruptScoreCpu is the CPU-canonical routing gate.

## Failure Criterion

This falsifier fails if the equation coefficients or bucket thresholds drift, if NaN/Inf or clamp cases escape [0,1], if P99 is at least 100 us over 100,000 trials, or if the artifact is missing on Jojo's M2 Pro 16 GB UMA CPU path.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `equation_match`, `clamp_bounds`, `bucket_boundaries`, and `p99_latency_us`.
