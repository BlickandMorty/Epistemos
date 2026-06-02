---
falsifier: F-PageGather-Packetized-Caller
created_on: 2026-05-28
hardware_floor: M2 Pro 16 GB UMA
status: PASS - FALLBACK WITNESS
artifact: artifacts/falsifiers/page_gather_packetized_caller/result.json
---

# F-PageGather-Packetized-Caller

## Result

PASS as a caller-path fallback witness.

Command:

```bash
Tools/falsifiers/f_page_gather_packetized_caller.sh
```

Measured artifact:

- `artifact_kind`: `fallback_witness`
- `fallback_tier`: `Fallback`
- `candidate_pool_size`: 50
- `packets_emitted`: 4
- `packetized_caller_consumed`: true
- `dense_restore_deferred`: true
- `schedule_block_sorted`: true

## Scope Note

This falsifier does not promote dense `F-PageGather-M2Pro`. It proves one
non-hot retrieval caller, `VaultStore::hybrid_search_with_trace`, consumes
`(logical_position, value)` PageGather packets for retained candidate scores and
does not force dense restore before witness rendering.

The dense Metal PageGather route remains red until its own STREAM-ratio gate
passes or every production caller that matters can stay packetized through the
hot path.

## Acceptance

The falsifier passes iff the vault trace records PageGather escalation, emits
one packet per retained result, keeps the block-sorted schedule, marks dense
restore deferred, and leaves `measurement_status` deferred so no one can
mistake this caller witness for the primary dense throughput gate.
