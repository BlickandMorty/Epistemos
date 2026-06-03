---
falsifier: F-MmapResidencyFence-CopyCount
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/mmap_residency_fence_copy_count/result.json
---

# F-MmapResidencyFence-CopyCount

## Purpose

This is the executable fixture-only mmap accounting witness for the June 1
Semantic Working-Set Compiler bundle. It proves mmap mapping, touch state,
resident estimate, major/minor faults, copy count, byte range, and counted-hot
bytes are separate labels and cannot be conflated into an SSD-as-RAM claim.

## Command

```bash
Tools/falsifiers/f_mmap_residency_fence_copy_count.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/mmap_residency_fence_copy_count/result.json`

The artifact passes only when counted-hot bytes require mapped, touched, and
resident-enough evidence; mapped-but-untouched, unmapped, or under-resident
fixtures fail; cold uncounted bytes do not claim hot residency; faults and copy
count are reported separately; invalid byte ranges and missing file IDs fail
closed.

## Non-Promotion Rule

This falsifier does not call mmap, probe real page faults, benchmark SSD/RAM,
decode model/KV pages, execute MLX/Metal, prefetch cold bytes, or mutate route
policy. It is a fixture semantics witness only. Real transport or mmap
performance claims still require their own measured witnesses.

## Queue Effect

`F-MmapResidencyFence-CopyCount` closes the first mmap-residency-fence fixture
for the Semantic Working-Set Compiler bundle. `F-PrefetchWindow-ColdMiss` now
closes the first prefetch/cold-miss behavior fixture. The next unfinished gates
are cold-fault learning, oracle baselines, source-to-residency no-poison
propagation, and any ColdStream no-hidden-authority witness before transport
policy can influence live routes. KV byte-budget cards are now covered by
`F-KVByteBudgetCard`.
