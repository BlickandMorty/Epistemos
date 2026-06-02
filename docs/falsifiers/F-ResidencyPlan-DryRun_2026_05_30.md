---
state: primary_witness
created_on: 2026-05-30
falsifier_id: F-ResidencyPlan-DryRun
artifact: artifacts/falsifiers/residency_plan_dry_run/result.json
command: Tools/falsifiers/f_residency_plan_dry_run.sh
scope_guard: dry-run planner only; no mmap, decode, MLX, Metal, KV, or 70B inference executed
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-ResidencyPlan-DryRun - 2026-05-30

## Verdict

`F-ResidencyPlan-DryRun` is the safe next gate between the file-backed
UAS/AcsAnchor slice and any future 128K/70B runtime probe.

It proves that `WeightBlockManifest` rows can be composed into a deterministic
`ResidencyPlan` and rejected before runtime if the plan violates memory, WBO,
rollback, or codec/witness discipline.

This is **not** a live 70B inference pass. It loads zero model bytes and does
not touch Metal, MLX, KV caches, mmap, or the GGUF route.

The source ABI now also includes:

- bounded range hashing via `WeightBlockManifest::from_reader_range`, which
  hashes a seekable byte range in 64 KiB chunks and refuses over-limit ranges
  before reading;
- known-hash ingestion via `WeightBlockManifest::from_known_hash_hex`, so
  externally precomputed model-file range hashes can be admitted without
  loading the range into RAM;
- `ConstructionCard`, which binds ProblemCard / LiftChart / ProjectionPacket /
  Witness / Budget / Falsifier / Rollback to a passed `ResidencyPlan`.

## Artifact Summary

Artifact:

```text
artifacts/falsifiers/residency_plan_dry_run/result.json
```

Measured dry-run fixture:

| Axis | Result |
|---|---:|
| Active runtime bytes | `872,415,232` |
| Cold SSD/MMAP-addressed bytes | `77,309,411,328` |
| Runtime model bytes loaded | `0` |
| Plan address deterministic | `true` |
| Missing rollback rejected | `true` |
| Sherry and Leech codec names present | `true` |
| Overall pass | `true` |

Interpretation:

```text
72 GiB cold model-shaped body
  + ~832 MiB hot/warm active set
  + Sherry/Leech/NF4 codec route labels
  + dense rollback requirement
  + zero runtime model loads
  -> FitForDryRun
```

## What This Does Not Prove

- It does not prove live 70B generation.
- It does not prove KV-Direct correctness.
- It does not prove MLX/Metal can execute the selected plan.
- It does not prove PageGather bandwidth.
- It does not prove tensor zero-copy through the live Swift/Rust/Metal path.

Those remain with:

- `F-KV-Direct-Gate`
- `F-70B-Local-Cocktail-Lite`
- `F-UAS-CopyCount`
- `F-PageGather-M2Pro`
- `F-Sparse-Runtime-Split`

## Canon Link

This gate implements the immediate next build surface named in:

- `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md`
- `docs/fusion/AETHERLINK_OAS_CANON_INTAKE_2026_05_30.md`
- `docs/fusion/AETHERLINK_ERDOS_PARAMETER_GOLF_INTAKE_2026_05_30.md`

The invariant is:

```text
lift the model into addressed weight/KV/component charts
  -> search a budgeted active set
  -> project to an executable active assembly
  -> carry WBO/copy/memory witnesses and dense rollback
```

This falsifier currently lands the first two steps and refuses to claim the
third until a real runtime probe passes.
