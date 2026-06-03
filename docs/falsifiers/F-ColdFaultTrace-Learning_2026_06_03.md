---
falsifier: F-ColdFaultTrace-Learning
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/cold_fault_trace_learning/result.json
---

# F-ColdFaultTrace-Learning

## Purpose

This is the executable fixture-only cold-miss learning witness for the June 1
Semantic Working-Set Compiler bundle. It proves repeated cold misses emit
deterministic `ColdFaultTrace` records and generate a bounded rollback-only
`LayoutPatch` shadow candidate that improves held-out cold-miss fixtures without
mutating production layout or route policy.

## Command

```bash
Tools/falsifiers/f_cold_fault_trace_learning.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/cold_fault_trace_learning/result.json`

The artifact passes only when two repeated traces are emitted, trace and patch
addresses are deterministic, missing/expected units, stall time, cold I/O,
fallback, answer effect, and source/cache cause are visible, the generated patch
has bounded changed tiles and storage wear, expected and observed cold-miss
deltas improve, held-out improvement is visible, and the patch remains
`shadow_candidate`.

## Rejection Coverage

The witness fails closed on single-trace learning, no-improvement patches,
missing rollback, unbounded storage wear, zero-stall traces, empty changed
tiles, and any attempted production mutation.

## Non-Promotion Rule

This falsifier does not prefetch, move bytes, rewrite storage, alter route
policy, execute MLX/Metal, touch live model/KV state, or promote a learned
layout. It only proves the cold-fault learning record shape and rollback-bound
shadow patch rules. Runtime promotion still needs RunEventLog, AnswerPacket,
rollback, build-status, and user-visible route evidence.

## Queue Effect

`F-ColdFaultTrace-Learning` closes the cold-fault learning fixture from the
Semantic Working-Set Compiler build order. The working-set oracle baseline now
has a primary witness too, so this bundle's metadata-only gates are closed.
