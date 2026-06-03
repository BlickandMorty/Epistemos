---
falsifier: F-ColdMissLedger
status: PASS
artifact: artifacts/falsifiers/cold_miss_ledger/result.json
command: Tools/falsifiers/f_cold_miss_ledger.sh
created_on: 2026-06-03
---

# F-ColdMissLedger

## Scope

`F-ColdMissLedger` is the seventh Research Construction Engine primary
witness. It proves cold-miss learning as metadata only: repeated route-level
cold misses bind missed UAS units, stall cost, cold-I/O bytes, fallback,
verifier delta, next prefetch policy, rollback, run log, AnswerPacket, and a
shadow `ColdRoutePolicyPatch`.

The witness does not move bytes, mmap files, prefetch, run MLX/Metal, load
model weights, or mutate production route policy.

## Artifact

```text
artifacts/falsifiers/cold_miss_ledger/result.json
```

## What Passed

- `ColdMissLedger` binds route id, source cards, task signature, repeated miss
  entries, next prefetch policy, rollback, run log, AnswerPacket, and policy
  patch reference.
- The shadow `ColdRoutePolicyPatch` validates shape, rollout scope, kill
  switch, rollback, and held-out metrics references.
- Held-out cold misses improve from `4` to `1`; repeated stall drops by
  `72 ms`.
- Missing policy patch, missing rollback, one-miss-only, no-improvement,
  zero-stall, high-storage-wear, and live-production-mutation fixtures reject.
- Runtime/model bytes loaded remain `0`.

## Current Meaning

The default main-only architecture cursor moves from:

```text
F-ColdMissLedger
```

to:

```text
F-SwiftLM-SourceIntake
```

This keeps the 70B / UAS / ColdStore architecture path intact while keeping
Qwen/GGUF 128K and 70B provider-reference work deferred unless explicitly
enabled for a heavy long-context probe.

## Verification Command

```bash
Tools/falsifiers/f_cold_miss_ledger.sh
```
