---
falsifier: F-ResidencyPageTable-Addressability
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/residency_page_table_addressability/result.json
---

# F-ResidencyPageTable-Addressability

## Purpose

This is the executable metadata-only page-table witness for the June 1 Semantic
Working-Set Compiler bundle. It proves every selected semantic unit can emit a
deterministic `ResidencyPageTableEntry` with UAS address, storage tier, byte
range, codec, checksum, compatibility fence, lease/expiry, and prefetch
priority before any runtime wake path consumes the plan.

## Command

```bash
Tools/falsifiers/f_residency_page_table_addressability.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path:
  `artifacts/falsifiers/residency_page_table_addressability/result.json`

The artifact passes only when page-table entry count matches selected-unit
count, entry ordering is deterministic, unit-to-entry fields round-trip, hot /
warm / cold / remote-reference tiers are covered, UAS addresses and entry
identities are unique, and invalid byte ranges, missing or bad checksums,
missing or bad compatibility fences, duplicate UAS addresses, and unavailable
selected units fail closed.

## Non-Promotion Rule

This falsifier does not move cold bytes, prefetch, run mmap stress, decode
model/KV pages, execute MLX/Metal, or mutate route policy. It is a page-table
addressability and fail-closed schema witness only.

## Queue Effect

`F-ResidencyPageTable-Addressability` closes the first page-table
addressability item from the Semantic Working-Set Compiler build order. The
next bundle gate moves to prefetch/cold-miss work; mmap-residency-fence
copy-count semantics are now covered by
`F-MmapResidencyFence-CopyCount`.
