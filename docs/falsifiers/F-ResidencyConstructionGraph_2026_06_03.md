---
state: primary_witness
created_on: 2026-06-03
falsifier_id: F-ResidencyConstructionGraph
artifact: artifacts/falsifiers/residency_construction_graph/result.json
command: Tools/falsifiers/f_residency_construction_graph.sh
scope_guard: metadata-only Research Construction Engine dry run; no mmap, model decode, MLX, Metal, KV, provider, or live route policy mutation executed
---

# F-ResidencyConstructionGraph - 2026-06-03

## Verdict

`F-ResidencyConstructionGraph` is the first landed Research Construction
Engine witness from the June 1 constructive-residency bundle.

It proves that a `ResidencyConstructionGraph` can bind a task signature,
source-card-backed candidate units, coactivation edges, incompatibility edges,
verifier edges, and cold-miss history into a deterministic assembly score. It
also proves invalid assemblies reject before runtime.

This is **not** a live model, KV, mmap, Metal, MLX, GGUF, or provider pass. It
loads zero runtime/model bytes and does not mutate any live route policy.

## Artifact Summary

Artifact:

```text
artifacts/falsifiers/residency_construction_graph/result.json
```

Measured dry-run fixture:

| Axis | Result |
|---|---:|
| Candidate units present | `true` |
| Source card ids bound | `true` |
| Graph address deterministic | `true` |
| Selected units | `2` |
| Rejected units | `2` |
| Hot resident bytes | `80` |
| Warm bytes | `16` |
| Cold bytes | `128` |
| Cold misses | `1` |
| Cold stall | `12 ms` |
| Assembly score | `9083 bps` |
| Invalid assemblies rejected | `true` |
| Rollback required | `true` |
| Runtime bytes loaded | `0` |
| Overall pass | `true` |

Interpretation:

```text
Problem/task signature
  -> source-card candidate units
  -> coactivation + incompatibility + verifier + cold-miss evidence
  -> deterministic scored assembly
  -> invalid/over-budget/rollback-missing plans reject before runtime
```

## What This Does Not Prove

- It does not prove coactivation tile prefetch improves cold misses.
- It does not prove proof-carrying leases for runtime cold-byte wakeups.
- It does not prove a cold assembly runtime beats dense or RAG baselines.
- It does not prove live 70B, KV-Direct, MLX, Metal, mmap, or provider output.
- It does not promote PatternBoost-derived policy to live route authority.

Those remain separate gates in
`docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`.

## Canon Link

This gate implements the first candidate target named by:

- `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`
- `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md`
- `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`

The coactivation tile cursor after this gate is now complete:

```text
F-CoactivationTile-Prefetch
```

The proof-carrying lease cursor after this gate is now complete:

```text
F-ProofCarryingResidencyLease
```

That gate proves cold byte wakeups carry UAS address, reason, byte cost,
verifier/proof reference, expiry, fallback, and rollback evidence before any
cold assembly route is promoted.

`F-ColdAssemblyPlan-70B-Lite` is now implemented as
`docs/falsifiers/F-ColdAssemblyPlan-70B-Lite_2026_06_03.md`. The active next
large-local-model architecture cursor is now:

```text
F-LatticeStateController
```
