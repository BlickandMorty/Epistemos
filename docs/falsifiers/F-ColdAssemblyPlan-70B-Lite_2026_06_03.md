---
falsifier: F-ColdAssemblyPlan-70B-Lite
created_on: 2026-06-03
artifact: artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json
command: Tools/falsifiers/f_cold_assembly_plan_70b_lite.sh
status: PRIMARY METADATA-ONLY WITNESS IMPLEMENTED
---

# F-ColdAssemblyPlan-70B-Lite

## Purpose

Prove the 70B large-local-model path is an admitted cold assembly plan, not a
Qwen/GGUF shard rerun and not a hidden dense-resident overclaim.

The witness constructs a metadata-only `ColdAssemblyPlan` over UAS addresses,
coactivation tiles, and proof-carrying residency leases. It binds:

- mission and construction graph reference;
- active, warm, and cold tiles;
- hot, warm, cold, active-executed, KV, adapter, and peak-RSS byte accounting;
- prefetch order for cold wakes;
- proof leases for every cold tile;
- verifier stack, fallback, rollback, and AnswerPacket reference;
- dense-local, RAG-only, and static-route baselines.

No model bytes are loaded. No mmap, MLX, Metal, GGUF, provider call, or live
route policy mutation occurs.

## Current Result

PASS on 2026-06-03 as a metadata-only primary witness:

```text
artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json
```

The plan uses four tiles: one active hot controller, one warm adapter, and two
cold evidence/verifier lanes. It beats all three baselines on score, quality,
evidence validity, verifier score, active executed bytes, peak RSS, and cold
stall. It also rejects unscheduled cold wakes, missing proof leases, missing
rollback, missing AnswerPacket reference, and hidden-cloud baseline evidence.

## Meaning

This keeps the 70B architecture track alive as the actual large-local-model
work. It does not require the deferred 128K Qwen/GGUF/KV shard lane or
provider-reference prompt-level lane unless `EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1`
is set for an explicit heavy probe.

`F-LatticeStateController` is now implemented as
`docs/falsifiers/F-LatticeStateController_2026_06_03.md` with artifact
`artifacts/falsifiers/lattice_state_controller/result.json`.
`F-ReasoningStateContinuity`, `F-ColdMissLedger`, and
`F-SwiftLM-SourceIntake` are also implemented as metadata-only downstream
witnesses with artifacts under
`artifacts/falsifiers/reasoning_state_continuity/result.json` and
`artifacts/falsifiers/cold_miss_ledger/result.json`, and
`artifacts/falsifiers/swiftlm_source_intake/result.json`.

The downstream MetaBreakthrough registry and proof-carrying route-card witness
are now implemented. The next Meta Control cursor is:

```text
F-RustRouteKernel-ModelCheck
```

## Axis Floor

The schema floor is recorded in
`docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` under
`F-ColdAssemblyPlan-70B-Lite`.

## Command

```bash
Tools/falsifiers/f_cold_assembly_plan_70b_lite.sh
```
