# PageGather Block-Sorted Scheduler - 2026-05-27

Status: scheduler-side mitigation path landed; Metal destination contract now
exists; primary throughput gate still pending.

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

- The Metal destination-position variant exists, but the first smoke probe
  shows the true scheduled restore path is still too slow for promotion.
- The full `256/512/1024 MB`, `5 s`, `3 trial` canonical gate has not passed.
- Sequential gather remains below the `0.95x` bar in the current witness.
- Thermal/reproducibility axes still need the canonical pass run.

Follow-up: `docs/audits/PAGEGATHER_METAL_DESTINATION_CONTRACT_2026_05_27.md`
adds `pageGatherScatterScheduled` and records a noncanonical 16 MB smoke probe:
`0` correctness violations, but only `0.3556x` STREAM for block-sorted scheduled
scatter. That keeps the gate orange/pending.

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

1. Try a threadgroup-tiled destination restore, vectorized logical-position
   loads, or a two-pass block-local compaction path.
2. Rerun the 256 MB scheduled diagnostic first.
3. Only after both gather and scheduled block-sorted scatter pass at 256 MB
   should the full 256/512/1024 MB canonical run be attempted.
