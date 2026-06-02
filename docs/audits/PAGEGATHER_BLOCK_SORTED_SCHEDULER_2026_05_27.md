# PageGather Block-Sorted Scheduler - 2026-05-27

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: scheduler-side mitigation path landed; Metal dense destination and
packetized contracts now exist; primary dense throughput gate still pending.

Branch: `codex/pagegather-block-sorted-scheduler-2026-05-27`

## Why This Exists

`artifacts/falsifiers/page_gather/locality_probe_result.json` showed that a
block-sorted access pattern can cross the scatter-ratio floor at 256 MB while
the full Fisher-Yates random stressor remains far below the threshold. The gap
was architectural, not cosmetic: there was no reusable scheduler contract that
kept source access local while preserving the caller's logical output order.

## What Changed

Rust:

- `agent_core::helios::DEFAULT_PAGE_GATHER_BLOCK_ELEMENTS = 8192`
- `PageGatherScheduleClass`
- `PageGatherSchedulePlan`
- `block_sorted_schedule(...)`
- `gather_scheduled(...)`
- `gather_block_sorted(...)`

The scheduler sorts execution by source block and carries
`logical_positions` so the result is restored to the caller-visible order. This
keeps full random permutation as a failure stressor and adds a product-candidate
path that matches the measured locality probe.

Trace/UI:

- `PageGatherEscalationTrace` now carries `schedule_class` and
  `locality_block_elements`.
- Swift `VaultRecallTrace` mirrors those fields and exposes
  `scheduleLabel`.
- Chat provenance and Vault Recall health surfaces show the block-sorted
  candidate while keeping the falsifier chip orange/pending.

## What This Does Not Claim

This does not promote `F-PageGather-M2Pro`.

Remaining blockers:

- The Metal dense destination-position variant exists, but the 256/512 MB
  witness shows true scheduled dense restore is still too slow for promotion.
- The packetized scheduled variant crosses the `0.70x` mitigation floor at
  256/512 MB, but no product caller consumes packet packets yet.
- The full `256/512/1024 MB`, `5 s`, `3 trial` canonical gate has not passed.
- Sequential gather remains below the `0.95x` bar in the current witness.
- Thermal/reproducibility axes still need the canonical pass run.

Follow-up: `docs/audits/PAGEGATHER_METAL_DESTINATION_CONTRACT_2026_05_27.md`
adds `pageGatherScatterScheduled` and `pageGatherPacketizeScheduled`.
Dense scheduled restore remains below threshold, while packetized scheduled
PageGather reaches `0.729x` / `0.752x` STREAM at 256/512 MB. That keeps the
dense gate orange/pending and points the next slice at caller-path packet
consumption.

## Verification

Focused local gates:

```text
cargo test --manifest-path agent_core/Cargo.toml page_gather --lib --tests
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosPageGatherSchedulerFocused test -only-testing:EpistemosTests/VaultRecallWiringTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

Full merge gate must still run before checkpoint:

```text
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosPageGatherSchedulerGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

## No-Orphan Check

- Motion: Project / Verify.
- UAS: no new address shape; consumes the existing PageGather retrieval path.
- Plane: retrieval / page plane.
- Residency: CurrentApp CPU reference plus future Apple Silicon UMA Metal path.
- WBO/error: output order is explicitly restored through logical positions; no
  failed primary axis is hidden.
- Witness: scheduler tests, retrieval-trace tests, locality artifact, and this
  audit note.
- Falsifier: `F-PageGather-M2Pro`.
- Tier: VerifiedFloor diagnostic / product-candidate scheduler, not green
  hardware evidence.
- Rollback: remove the schedule plan helpers and trace schedule metadata; the
  existing failure and locality artifacts remain valid.

## Next Slice

Optimize the scheduled Metal path, not the label:

1. Add a caller-path witness that consumes `(logical_position, value)` packets
   directly, or optimize dense restore if dense order is non-negotiable.
2. Rerun the 256/512 MB diagnostic first.
3. Only after the chosen product contract passes at 256/512 MB should the full
   dense or packetized promotion gate be attempted.
