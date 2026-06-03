---
falsifier: F-VaultRecall-50
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PRIMARY WITNESS; VAULT SEMANTIC FLOOR CLOSED; T21 CAPSTONE CLOSED
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-VaultRecall-50

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove topical vault recall does not return the first irrelevant index-order notes and surfaces enough candidates plus trace to make retrieval honesty visible. |
| Current status | CURRENT-MAIN PRIMARY WITNESS. `artifacts/falsifiers/vault_recall_50/result.json` records `overall_pass=true`, top-1 exact-title `0.9726 (213/219)`, top-5 paraphrase `0.9800 (49/50)` against the real `0.80` floor, adversarial reject `1.0 (51/51)`, and fixture rows `370`. VaultRecall semantic recall is closed by the concept-normalized `VaultBackend` fallback, and the broader T21 capstone artifact over VaultRecall + Eidos + PageGather is green at `artifacts/falsifiers/t21_retrieval_contract_capstone/result.json`. See `docs/audits/T21_RETRIEVAL_CONTRACT_RECONCILIATION_2026_06_03.md`. |
| Input fixture | Vault fixture with at least 50 notes: 7 distractor notes matching chatty terms, 3+ residency-governance target notes, unicode notes, stopword-only query, single-word query, multi-paragraph query, and no-result query. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: for `Pull my notes on residency governance`, top packed context includes the residency-governance targets, never just index-order distractors; retrieval considers the full manifest, gathers 50-200 candidates before packing, emits trace components, and weak evidence asks/broadens instead of pretending. |
| Failure meaning | The app still cannot be trusted to find the user's own notes; ceiling research and closed citations become decoration over broken recall. |
| Fallback route | Keep the current in-process semantic fallback and trace guards; block only the broader T21 capstone claim until a single artifact ties VaultRecall, Eidos closed citations, and PageGather packet policy together. |
| Product lane | Core / V1 credibility gate. |
| Exact command | `cargo run --release --bin falsify_vault_recall_50` |
| Expected artifact | `artifacts/falsifiers/vault_recall_50/result.json` plus the retained T21 reconciliation note. |

## Canon Anchors

- MASTER_FUSION: [§1 personal-knowledge thesis](../_consolidated/00_canonical_authority/MASTER_FUSION.md#1--what-epistemos-is-the-one-paragraph-thesis-distilled-from-5-docs) and [§3 claim 1 memory retrieval bottleneck](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§10 scope note](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#10-what-this-canon-isnt), which explicitly treats F-VaultRecall-50 as orthogonal product work rather than a UAS-ACS register claim.

## Failure Criterion

This falsifier fails if the topical fixture returns only index-order distractors, skips full-manifest inventory, gathers fewer than 50 candidates before packing without an explicit no-evidence reason, omits lexical/semantic/graph/recency/MMR trace, or lacks a Jojo M2 Pro 16 GB UMA artifact.

## Artifact Schema Axes

The expected trace artifact must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `target_recall`, `distractor_suppression`, `candidate_count`, `trace_components`, and `weak_evidence_behavior`.
