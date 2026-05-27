# PageGather Metal Destination Contract - 2026-05-27

Status: Metal correctness contract landed; primary throughput gate still pending.

Branch: `codex/pagegather-metal-destination-contract-2026-05-27`

## Why This Exists

The 256 MB locality probe showed that a block-sorted read walk can cross the
scatter-ratio floor, but that probe wrote output in execution order. The
product scheduler contract restored in
`PAGEGATHER_BLOCK_SORTED_SCHEDULER_2026_05_27.md` requires caller-visible output
order, which means the Metal kernel also needs a destination-position buffer.

Without that, the measured block-sorted ratio was too generous: it proved
read-locality, not the full read-local/write-positioned product path.

## What Changed

- `Epistemos/Shaders/PageGather.metal` adds `pageGatherScatterScheduled`.
- The scheduled kernel writes:

```text
out[logicalPositions[gid]] = source[indices[gid]]
```

- `EpistemosTests/MetalWitnessGatesTests.swift` now verifies the scheduled
  kernel against a deterministic CPU fixture.
- `Tools/metal-witness-gates/page-gather-metal-artifact.swift` now loads the
  scheduled pipeline and measures block-sorted locality probes through the
  destination-position contract.
- The probe accounts for the extra logical-position read:
  `scheduled PageGather = 16 bytes/element`.

## Diagnostic Result

A tiny noncanonical smoke probe was run only to exercise the new path:

```text
swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 16 --window-seconds 0.1 --trials 1 --warmup-iterations 0
```

Result: expected exit `2`, because this was not a canonical primary run.

Observed values:

- STREAM: `153.2166 GB/s`.
- Block-sorted scheduled scatter ratio: `0.3556x`.
- Block-sorted scheduled correctness violations: `0`.

This is the honest result: the scheduled kernel is correct, but the real
destination-position restore path is not yet fast enough to promote
`F-PageGather-M2Pro`.

## What This Does Not Claim

- No `artifacts/falsifiers/page_gather/result.json` promotion.
- No green Settings chip.
- No 256/512/1024 MB canonical pass.
- No claim that block-sorted scheduling alone clears the product gate.

## No-Orphan Check

- Motion: Project / Verify.
- UAS: no new address shape.
- Plane: retrieval / page plane.
- Residency: Apple Silicon UMA through shared Metal buffers.
- WBO/error: the previous read-local-only optimism is now bounded by a
  destination-position witness.
- Witness: `MetalWitnessGatesTests`, the smoke probe, this audit note, and the
  existing locality/failure artifacts.
- Falsifier: `F-PageGather-M2Pro`.
- Tier: VerifiedFloor diagnostic, still orange/pending.
- Rollback: remove `pageGatherScatterScheduled` and restore the harness to the
  read-local-only locality probe.

## Next Slice

Optimization, not promotion:

1. Try a threadgroup-tiled destination restore, vectorized logical-position
   loads, or a two-pass block-local compaction path.
2. Rerun a 256 MB diagnostic first.
3. Attempt the full canonical `256/512/1024 MB`, `5 s`, `3 trial` gate only
   after the 256 MB scheduled path approaches the `0.70x` ratio.
