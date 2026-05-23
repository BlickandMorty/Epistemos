---
falsifier: F-UAS-CopyCount
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-UAS-CopyCount

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the Unified Address Space claim by counting actual copies across the Swift/Rust/Metal/MLX/KV hot path for one addressed payload. |
| Current status | NOT IMPLEMENTED. Canon and code contain zero-copy surfaces (`MTLStorageModeShared`, mapped note body, KV-Direct substrate), but no copy-count harness or T23B script exists. Do not promote UAS metadata into a measured zero-copy claim. |
| Input fixture | One UAS-addressed payload with stable ID, content hash, byte range, residency lease, provenance link, shared `MTLBuffer.storageModeShared` or mmap backing, and KV/Metal consumer path. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: hot path performs zero tensor/data copies after the shared backing is created; any allowed metadata copies are enumerated and byte-counted; the artifact records allocation/copy sites with stack labels. |
| Failure meaning | UAS is only an address doctrine, not a verified memory substrate; KV-Direct, PageGather, and active-support claims must not inherit zero-copy language. |
| Fallback route | Fall back to boring UAS/UASA metadata first: stable addresses, content hashes, residency leases, and provenance IDs; keep model/KV pages Research-gated until copy count is measured. |
| Product lane | Core metadata now; Research/V2 for model/KV pages. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_uas_copy_count.sh` |
| Expected artifact | `artifacts/falsifiers/uas_copy_count/result.json` with per-hop copy counts, byte totals, and allowed metadata-copy ledger. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 4 Apple Silicon unified memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock) and [§3 claim 15 typed buffers/shared memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§1 UAS definition](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#1-one-paragraph-definition) and [§2 row 3 KV-Direct gate](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), which make zero-copy a measured substrate claim rather than doctrine prose.

## Failure Criterion

This falsifier fails if any tensor/data copy occurs after shared backing is created, if copy sites are not byte-counted with stack labels, if metadata copies are not explicitly separated from data copies, or if there is no artifact from Jojo's M2 Pro 16 GB UMA floor.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `tensor_copy_count`, `data_copy_bytes`, `metadata_copy_ledger`, and `stack_label_coverage`.
