---
falsifier: F-ACS-AnchorLookup
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-ACS-AnchorLookup

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove ACS (Anchored Cognitive Substrate) anchors can be looked up, audited, and projected without losing theorem, plane, residency, source, or active-packet identity. |
| Current status | NOT IMPLEMENTED. `epistemos-research/src/acs.rs` provides research-only `AcsAnchor` and `CmsXField`, but the current anchor shape is only `anchor_id`, `theorem_id`, and `salience`; it is not the full anchor-addressing gate and no T23B script exists. |
| Input fixture | Typed anchor fixture with theorem tag, plane coordinate, residency tier, source hash, active packet ID, compatibility edge, and one intentionally invalid theorem ID. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: valid anchor round-trips through lookup, audit, and projection with all fields intact; invalid theorem IDs fail closed; ACS naming uses the canon split: Anchored Cognitive Substrate for code/structure and Autopoietic Cognitive Stack for process doctrine. |
| Failure meaning | ACS becomes unfalsifiable branding; downstream admission, governance, and five-plane projection could silently lose provenance or plane placement. |
| Fallback route | Keep ACS research-only and never MAS-shipping; use UAS metadata and explicit provenance links until T18B ACS admission and anchor lookup evidence land. |
| Product lane | Research-only now; V2 feature-gated if promoted. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_acs_anchor_lookup.sh` |
| Expected artifact | `artifacts/falsifiers/acs_anchor_lookup/result.json` with round-trip field digest and invalid-anchor rejection trace. |

## Canon Anchors

- MASTER_FUSION: [§0 authority hierarchy](../_consolidated/00_canonical_authority/MASTER_FUSION.md#0--how-to-use-this-document), which keeps doctrine amendments explicit when code and canon disagree.
- Unified Active Substrate Canon: [§2 rows 1-2 ACS substrate and five-plane register](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces) plus [§3 naming-drift disambiguation](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#3-naming-drift-disambiguation-critical).

## Failure Criterion

This falsifier fails if any typed anchor field is dropped during lookup, audit, or projection, if invalid theorem IDs do not fail closed, if ACS naming collapses the structure/process split, or if the artifact is absent on Jojo's M2 Pro 16 GB UMA rig.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `round_trip_field_digest`, `invalid_theorem_rejection`, and `projection_integrity`.
