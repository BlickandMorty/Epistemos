---
state: primary_witness
created_on: 2026-06-03
falsifier_id: F-CoactivationTile-Prefetch
artifact: artifacts/falsifiers/coactivation_tile_prefetch/result.json
command: Tools/falsifiers/f_coactivation_tile_prefetch.sh
scope_guard: metadata-only coactivation tile prefetch fixture; no mmap, model decode, MLX, Metal, KV, provider, byte transport, or live route policy mutation executed
---

# F-CoactivationTile-Prefetch - 2026-06-03

## Verdict

`F-CoactivationTile-Prefetch` is the second landed Research Construction
Engine witness from the June 1 constructive-residency bundle.

It proves that metadata-only `CoactivationTile` manifests can bind UAS
addresses, byte ranges, codecs, verifier history, reuse horizon, prefetch
cost, and rollback evidence, then compile an order that beats file-order and
deterministic-random cold baselines under a fixed byte budget.

This is **not** a live cold-byte wakeup, model, KV, mmap, Metal, MLX, GGUF, or
provider pass. It loads zero runtime/model bytes and does not mutate live route
policy.

## Artifact Summary

Artifact:

```text
artifacts/falsifiers/coactivation_tile_prefetch/result.json
```

Measured dry-run fixture:

| Axis | Result |
|---|---:|
| Coactivation tiles present | `true` |
| Tile address deterministic | `true` |
| Tile units bound | `true` |
| Byte ranges nonempty | `true` |
| Codec coverage | `true` |
| Rollback required | `true` |
| Selected tiles | `2` |
| Compiled misses | `0` |
| File-order misses | `2` |
| Random-order misses | `2` |
| Compiled stall | `0 ms` |
| File-order stall | `14 ms` |
| Random-order stall | `14 ms` |
| Compiled byte waste | `0` |
| File-order byte waste | `98304` |
| Random-order byte waste | `98304` |
| Compiled prefetch bytes | `81920` |
| Prefetch budget | `98304` |
| Runtime bytes loaded | `0` |
| Overall pass | `true` |

Interpretation:

```text
ResidencyConstructionGraph
  -> coactivation tile manifests
  -> priority order by reuse horizon + cost
  -> bounded prefetch of needed cold tiles
  -> file-order/random baselines miss and waste bytes
```

## What This Does Not Prove

- It does not prove proof-carrying leases for runtime cold-byte wakeups.
- It does not prove held-out cold-miss learning or repeated-stall reduction.
- It does not prove a cold assembly runtime beats dense or RAG baselines.
- It does not prove live 70B, KV-Direct, MLX, Metal, mmap, or provider output.
- It does not promote PatternBoost-derived policy to live route authority.

Those remain separate gates in
`docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`.

## Canon Link

This gate implements the second candidate target named by:

- `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`
- `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`

The proof-carrying lease cursor after this gate is now complete:

```text
F-ProofCarryingResidencyLease
```

That gate proves cold byte wakeups carry UAS address, reason, byte cost,
verifier/proof reference, expiry, fallback, and rollback evidence before any
live cold assembly route advances.

The active next large-local-model architecture cursor is now:

```text
F-ColdAssemblyPlan-70B-Lite
```
