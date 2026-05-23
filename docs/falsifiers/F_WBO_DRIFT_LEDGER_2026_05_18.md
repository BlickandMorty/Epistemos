---
falsifier: F-WBO-DriftLedger
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-WBO-DriftLedger

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove every approximate/compressed substrate path pays into a WBO drift ledger and that observed drift stays inside the declared WBO envelope. |
| Current status | NOT IMPLEMENTED as a runtime falsifier. `agent_core/src/wbo6/mod.rs`, `epistemos-research/src/wbo_generations.rs`, and `epistemos-research/src/theorems/e4_wbo7.rs` provide budget/envelope substrate, while `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md` says real WBO-6 per-token KL measurement is not yet run. No T17B register artifact is present on this branch and no T23B script exists. |
| Input fixture | M2 Pro replay fixture with reference logits and candidate logits for KV/cache compression, quantization, resonance, substrate boundary, sovereign/security, active-support, DAG, and numerical-precision terms; include empty distribution, NaN/Inf, missing-term, over-budget, and unicode prompt labels. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: every drift-bearing token has a ledger entry with finite non-negative term values; WBO-7 pre-softmax delta-z infinity norm is at most `T_LWZ + T_K + T_R + T_TTR + T_SE + T_DAG + T_num`; post-softmax drift is <= 0.5 of the pre-softmax envelope; missing or orphan terms fail closed. |
| Failure meaning | Approximation debt is invisible; KV-Direct, PageGather, active assembly, quantization, or model-surgery paths can change logits without a bounded witness. |
| Fallback route | Treat WBO as a planning budget only; disable approximate/compressed runtime paths or route them through full-reference execution until ledgered drift artifacts pass. |
| Product lane | Verification plane / Research until the drift ledger is measured; Core only for static budget declarations. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_wbo_drift_ledger.sh` |
| Expected artifact | `artifacts/falsifiers/wbo_drift_ledger/result.jsonl` with per-token ledger entries, envelope sums, observed drift, pass/fail margin, and missing-term failures. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 11 multi-objective KV cache precision allocation](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because every approximate or compressed path needs visible drift debt.
- Unified Active Substrate Canon: [§4 provenance-ledger cross-link](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#4-uas-acs-cross-link-map), where verification-plane ledgers consume UAS evidence.

## Failure Criterion

This falsifier fails if any drift-bearing token lacks a finite non-negative ledger entry, if observed drift exceeds the WBO-7 envelope, if missing/orphan terms do not fail closed, if over-budget paths continue, or if no Jojo M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.jsonl` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `finite_nonnegative_terms`, `envelope_bound`, `post_softmax_drift`, and `missing_term_fail_closed`.
