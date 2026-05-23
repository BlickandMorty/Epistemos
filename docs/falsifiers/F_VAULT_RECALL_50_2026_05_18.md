---
falsifier: F-VaultRecall-50
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PARTIAL EVIDENCE, NOT FULLY PASSED
---

# F-VaultRecall-50

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove topical vault recall does not return the first irrelevant index-order notes and surfaces enough candidates plus trace to make retrieval honesty visible. |
| Current status | PARTIAL EVIDENCE, NOT FULLY PASSED. `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` records Fix B at commit `2281c73f0` and `cargo test --manifest-path agent_core/Cargo.toml --lib` -> 1194 passed, plus `strip_query_chatter` 4/4. The broader T21 contract still requires full-manifest inventory, 50-200 candidate retrieval, and visible lexical/semantic/graph/recency/MMR trace across entry points. No T23B script exists. |
| Input fixture | Vault fixture with at least 50 notes: 7 distractor notes matching chatty terms, 3+ residency-governance target notes, unicode notes, stopword-only query, single-word query, multi-paragraph query, and no-result query. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: for `Pull my notes on residency governance`, top packed context includes the residency-governance targets, never just index-order distractors; retrieval considers the full manifest, gathers 50-200 candidates before packing, emits trace components, and weak evidence asks/broadens instead of pretending. |
| Failure meaning | The app still cannot be trusted to find the user's own notes; ceiling research and closed citations become decoration over broken recall. |
| Fallback route | Keep Fix B query-chatter stripping; block ship claims on full vault context until T21 proves inventory completeness, trace visibility, and broad candidate retrieval. |
| Product lane | Core / V1 credibility gate. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_vault_recall_50.sh` |
| Expected artifact | `artifacts/falsifiers/f_vault_recall_50/trace.jsonl`, candidate manifest, packed context, and source-trace summary. |

## Canon Anchors

- MASTER_FUSION: [§1 personal-knowledge thesis](../_consolidated/00_canonical_authority/MASTER_FUSION.md#1--what-epistemos-is-the-one-paragraph-thesis-distilled-from-5-docs) and [§3 claim 1 memory retrieval bottleneck](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§10 scope note](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#10-what-this-canon-isnt), which explicitly treats F-VaultRecall-50 as orthogonal product work rather than a UAS-ACS register claim.

## Failure Criterion

This falsifier fails if the topical fixture returns only index-order distractors, skips full-manifest inventory, gathers fewer than 50 candidates before packing without an explicit no-evidence reason, omits lexical/semantic/graph/recency/MMR trace, or lacks a Jojo M2 Pro 16 GB UMA artifact.

## Artifact Schema Axes

The expected trace artifact must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `target_recall`, `distractor_suppression`, `candidate_count`, `trace_components`, and `weak_evidence_behavior`.
