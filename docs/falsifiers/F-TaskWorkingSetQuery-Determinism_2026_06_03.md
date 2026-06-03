---
falsifier: F-TaskWorkingSetQuery-Determinism
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/task_working_set_query_determinism/result.json
---

# F-TaskWorkingSetQuery-Determinism

## Purpose

This is the executable metadata-only query witness for the June 1 Semantic
Working-Set Compiler bundle. It proves the same mission fixture emits the same
bounded `TaskWorkingSetQuery`, canonical source refs, privacy class, evidence
need, verifier need, and hot/KV/cold-I/O budget fields before a working-set
plan can run.

## Command

```bash
Tools/falsifiers/f_task_working_set_query_determinism.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path:
  `artifacts/falsifiers/task_working_set_query_determinism/result.json`

The artifact passes only when query addressing is order-stable, duplicate
source refs canonicalize away, mission/task/privacy/evidence/verifier/budget
fields are bound to the fixture, privacy or quality drift changes the address,
and empty source refs, zero budgets, or zero deadlines fail closed.

## Non-Promotion Rule

This falsifier does not compile a full working-set plan, prefetch cold bytes,
wake model/KV pages, execute MLX/Metal, fetch live sources, or mutate route
policy. It only proves the mission-shaped query contract that later
`SemanticWorkingSetPlan` and `ResidencyPageTable` witnesses consume.

## Queue Effect

`F-TaskWorkingSetQuery-Determinism` closes the deterministic query item from
the Semantic Working-Set Compiler build order. The next schema-only gate in
this bundle is `F-ResidencyPageTable-Addressability`.
