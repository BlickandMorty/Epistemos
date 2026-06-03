---
state: primary_witness
created_on: 2026-06-03
falsifier_id: F-ProofCarryingResidencyLease
artifact: artifacts/falsifiers/proof_carrying_residency_lease/result.json
command: Tools/falsifiers/f_proof_carrying_residency_lease.sh
scope_guard: metadata-only proof-carrying residency lease fixture; no mmap, model decode, MLX, Metal, KV, provider, byte transport, or live route policy mutation executed
---

# F-ProofCarryingResidencyLease - 2026-06-03

## Verdict

`F-ProofCarryingResidencyLease` is the third landed Research Construction
Engine witness from the June 1 constructive-residency bundle.

It proves that cold-byte wake proposals must carry UAS address, lease reason,
active byte cost, expected utility, proof/falsifier reference, expiry, fallback,
and rollback evidence before they authorize. It also proves missing lease,
missing proof, missing fallback, missing rollback, expired lease, wrong lease,
and over-budget wake attempts fail closed.

This is **not** a live cold assembly, model, KV, mmap, Metal, MLX, GGUF, or
provider pass. It loads zero runtime/model bytes and does not mutate live route
policy.

## Artifact Summary

Artifact:

```text
artifacts/falsifiers/proof_carrying_residency_lease/result.json
```

Measured dry-run fixture:

| Axis | Result |
|---|---:|
| Proof-carrying leases present | `true` |
| UAS addresses bound | `true` |
| Lease reasons bound | `true` |
| Active byte costs bound | `true` |
| Expected utility bound | `true` |
| Proof/falsifier refs bound | `true` |
| Expiry bound | `true` |
| Fallback bound | `true` |
| Rollback bound | `true` |
| Lease tier capability ceiling | `true` |
| Lease address deterministic | `true` |
| Authorized wakes | `2` |
| Rejected wakes | `8` |
| Active byte total | `40960` |
| Max active byte cost | `32768` |
| Minimum TTL | `90000 ms` |
| Runtime bytes loaded | `0` |
| Overall pass | `true` |

Interpretation:

```text
CoactivationTile
  -> ProofCarryingResidencyLease
  -> authorized cold-byte wake proposals
  -> missing/expired/wrong/over-budget proposals fail closed
```

## What This Does Not Prove

- It does not prove a cold assembly runtime beats dense-local or RAG baselines.
- It does not prove held-out cold-miss learning or repeated-stall reduction.
- It does not prove live 70B, KV-Direct, MLX, Metal, mmap, or provider output.
- It does not promote PatternBoost-derived policy to live route authority.

Those remain separate gates in
`docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`.

## Canon Link

This gate implements the third candidate target named by:

- `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`
- `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`

The immediate next architecture gate after this lease witness was
`F-ColdAssemblyPlan-70B-Lite`, now implemented by
`docs/falsifiers/F-ColdAssemblyPlan-70B-Lite_2026_06_03.md` with artifact
`artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json`.

`F-LatticeStateController` is now implemented by
`docs/falsifiers/F-LatticeStateController_2026_06_03.md` with artifact
`artifacts/falsifiers/lattice_state_controller/result.json`.

The active default architecture cursor after that lattice witness is:

```text
F-ReasoningStateContinuity
```

That next gate should prove resumable cache/summary/tool/route state improves
continuity without hidden-chain leakage, verifier bypass, stale-state reuse, or
missing rollback evidence.
