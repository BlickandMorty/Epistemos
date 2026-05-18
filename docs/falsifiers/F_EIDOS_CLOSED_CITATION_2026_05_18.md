---
falsifier: F-Eidos-ClosedCitation
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-Eidos-ClosedCitation

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove Eidos V0 only lets chat/model output cite source IDs returned in an `EidosContextPacket`, with visible source trace. |
| Current status | NOT IMPLEMENTED. On this branch, `agent_core/src/eidos/` and `Epistemos/Eidos/` are absent; no closed-citation falsifier script exists. |
| Input fixture | Seed corpus with one note hit, one `.epdoc` projection hit, one code hit, one graph-neighborhood hit, one duplicate source, one fake citation ID, one empty-vault query, and one unicode query. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: all generated citations must be members of the returned Eidos context packet; fake citation rejection must be explicit; empty/no-result cases defer instead of fabricating. |
| Failure meaning | Source-truth is not sealed: Brain Panel/chat can display or emit unsupported citations, breaking the witness law before web augmentation. |
| Fallback route | Keep Eidos V0 local-only; block Brain Panel closed-citation claims; route through existing vault/source trace until T10/T22B land evidence. |
| Product lane | Core now; Pro/Research web augmentation later. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_eidos_closed_citation.sh` |
| Expected artifact | `artifacts/falsifiers/f_eidos_closed_citation/result.json` plus the returned context packet and rejected fake-citation trace. |

## Contract Ownership

This fragment consumes the T10-owned closed-citation contract from [T10 - Eidos V0](../NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md#t10---eidos-v0). It does not redesign `ClaimEvidence`, `HybridRetrieverN`, or cross-mode provenance hardening; it only records the M2 Pro falsifier gate that must witness the T10 contract.

## Canon Anchors

- MASTER_FUSION: [§1 local personal-knowledge thesis](../_consolidated/00_canonical_authority/MASTER_FUSION.md#1--what-epistemos-is-the-one-paragraph-thesis-distilled-from-5-docs) and [§3 claim 2 honest capability gating](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§4 provenance-ledger cross-link](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#4-uas-acs-cross-link-map) as the verification-plane consumer of source-truth evidence.

## Failure Criterion

This falsifier fails if any generated citation is absent from the returned Eidos context packet, if fake citation IDs are accepted, if empty/no-result cases fabricate sources, or if the artifact is not produced on Jojo's M2 Pro 16 GB UMA floor.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `citation_membership`, `fake_citation_rejection`, `empty_vault_deferral`, and `source_trace_visible`.
