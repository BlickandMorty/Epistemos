---
falsifier: F-PrefetchWindow-ColdMiss
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/prefetch_window_cold_miss/result.json
---

# F-PrefetchWindow-ColdMiss

## Purpose

This is the executable fixture-only prefetch witness for the June 1 Semantic
Working-Set Compiler bundle. It proves a compiled `PrefetchWindow` orders cold
semantic units by priority and beats deterministic file-order, recency, and
random baselines on misses, stall time, and byte waste under a bounded prefetch
byte budget.

## Command

```bash
Tools/falsifiers/f_prefetch_window_cold_miss.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/prefetch_window_cold_miss/result.json`

The artifact passes only when the compiled prefetch window contains cold units
only, orders them by priority, remains deterministic across input order,
prefetches the needed cold units within budget, has zero synthetic misses /
stall / byte waste, beats file-order, recency, and random baselines, and exposes
cancellation, fallback, and measurement references.

## Non-Promotion Rule

This falsifier does not perform real prefetch, file reads, mmap, SSD/RAM
benchmarking, model/KV decode, MLX/Metal execution, or route mutation. It is a
synthetic ordering and cold-miss witness only. Real transport policy still
requires ColdStream no-hidden-authority and transport-run witnesses.

## Queue Effect

`F-PrefetchWindow-ColdMiss` closes the first prefetch/cold-miss fixture in the
Semantic Working-Set Compiler bundle. Remaining bundle gates include cold-fault
learning, working-set oracle baseline, and source-to-residency no-poison
promotion guards. KV byte-budget card coverage is now closed by
`F-KVByteBudgetCard`.
