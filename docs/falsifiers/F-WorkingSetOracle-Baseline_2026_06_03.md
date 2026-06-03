---
falsifier: F-WorkingSetOracle-Baseline
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/working_set_oracle_baseline/result.json
---

# F-WorkingSetOracle-Baseline

## Purpose

This is the executable fixture-only oracle baseline witness for the June 1
Semantic Working-Set Compiler bundle. It proves a deterministic
`WorkingSetOracleCard` beats random, recency, and static file-order baselines on
held-out quality, evidence validity, cold misses, and active bytes, while
retaining a named abstention path.

## Command

```bash
Tools/falsifiers/f_working_set_oracle_baseline.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/working_set_oracle_baseline/result.json`

The artifact passes only when the oracle card address is deterministic, inputs
and predicted units are bound, confidence and abstain condition are visible,
random / recency / file-order baselines are covered, held-out quality and
evidence validity beat every baseline, held-out cold misses and active bytes are
below every baseline, and the card status is `beats_baselines`.

## Abstention And Rejection Coverage

The witness also proves low confidence and baseline loss abstain with named
reasons. It rejects missing abstain conditions, missing baselines, empty inputs,
empty predicted units, invalid confidence, out-of-range scores, and duplicate
baseline policies.

## Non-Promotion Rule

This falsifier does not train an oracle, route live requests, fetch sources,
prefetch bytes, decode model/KV state, call MLX/Metal, or mutate production
policy. It only proves the oracle card and baseline comparison contract.
Runtime promotion still needs RunEventLog, AnswerPacket, rollback, build-status,
and user-visible route evidence.

## Queue Effect

`F-WorkingSetOracle-Baseline` closes the remaining Semantic Working-Set Compiler
metadata-only falsifier gate. The June 1 Semantic Working-Set Compiler bundle now
has primary local witnesses for source intake, deterministic query emission,
budget rejection, page-table addressability, mmap/copy-count semantics,
prefetch/cold-miss ordering, KV byte-budget cards, source-to-residency
no-poison promotion guards, cold-fault learning, and oracle baseline comparison.
