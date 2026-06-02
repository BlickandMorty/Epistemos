# PageGather Metal Destination Contract - 2026-05-27

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: Metal dense-restore correctness contract landed; packetized scheduled
mitigation witness added; primary dense throughput gate still pending.

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
- `Epistemos/Shaders/PageGather.metal` also adds
  `pageGatherPacketizeScheduled`.
- The scheduled kernel writes:

```text
out[logicalPositions[gid]] = source[indices[gid]]
```

- The packetized scheduled kernel writes:

```text
packetValues[gid] = source[indices[gid]]
packetLogicalPositions[gid] = logicalPositions[gid]
```

- `EpistemosTests/MetalWitnessGatesTests.swift` now verifies the scheduled
  dense-restore and packetized kernels against deterministic CPU fixtures.
- `Tools/metal-witness-gates/page-gather-metal-artifact.swift` now loads the
  scheduled and packetized pipelines and measures block-sorted locality probes
  through both contracts.
- The probe accounts for the extra logical-position read:
  `scheduled PageGather = 16 bytes/element`.
- The packetized probe accounts for the extra logical-position write:
  `packetized scheduled PageGather = 20 bytes/element`.

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

## Packetized Mitigation Result

A later 256/512 MB M2 Pro diagnostic run wrote
`artifacts/falsifiers/page_gather/locality_probe_result.json`:

```text
swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 256,512 --window-seconds 2 --trials 2 --warmup-iterations 1 --write-artifact
```

The dense restore path stayed slow (`0.092x` STREAM at 256 MB and `0.058x` at
512 MB), but packetized scheduled PageGather crossed the mitigation floor:

| Working set | Packetized ratio vs STREAM | Correctness |
|---|---:|---:|
| 256 MB | `0.729x` | `0` sampled violations |
| 512 MB | `0.752x` | `0` sampled violations |

This does not promote the original dense-output gate. It does identify the
lean architecture path: PageGather recall should move as packet streams with
logical-position witness coordinates, and dense order should be a later
projection only when a caller proves it needs dense order.

## What This Does Not Claim

- No `artifacts/falsifiers/page_gather/result.json` promotion.
- No green Settings chip.
- No 256/512/1024 MB dense canonical pass.
- No claim that block-sorted scheduling alone clears the product gate.
- No claim that packetized output is wire-compatible with dense output without
  an explicit downstream projection.

## No-Orphan Check

- Motion: Project / Verify.
- UAS: no new address shape.
- Plane: retrieval / page plane.
- Residency: Apple Silicon UMA through shared Metal buffers.
- WBO/error: the previous read-local-only optimism is now bounded by a
  destination-position witness; packetized output records the cheaper witness
  coordinate path separately.
- Witness: `MetalWitnessGatesTests`, the smoke probe, this audit note, and the
  existing locality/failure artifacts.
- Falsifier: `F-PageGather-M2Pro`.
- Tier: VerifiedFloor diagnostic, still orange/pending.
- Rollback: remove `pageGatherScatterScheduled` and restore the harness to the
  read-local-only locality probe.

## Next Slice

Optimization, not promotion:

1. Decide whether the PageGather product caller consumes packetized output
   directly or requires dense order at the kernel boundary.
2. If dense order is required, try a threadgroup-tiled destination restore,
   vectorized logical-position loads, or a two-pass block-local compaction path.
3. If packetized output is accepted, add a caller-path witness that consumes
   `(logical_position, value)` packets without dense restore.
4. Attempt the full canonical dense gate only after the scheduled dense path
   approaches the `0.70x` ratio.
