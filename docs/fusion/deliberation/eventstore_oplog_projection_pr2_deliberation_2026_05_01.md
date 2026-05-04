# EventStore To OpLog Projection PR2 Deliberation - 2026-05-01

## Gate

Approved action: **small EventStore projection into the Rust OpLog bridge**.

This gate extends OpLog Swift Bridge PR1 by adding a production-safe projector
that reads committed `MutationEnvelope` outbox rows and appends a canonical
projection payload to OpLog. It does not approve UI integration, AgentEvent,
GraphEvent, protected editor work, graph-engine work, generated binding edits,
staging, commits, or branch operations.

## Repo Evidence

- `EventStore.saveMutationEnvelope(_:traceId:)` already persists committed
  envelopes and inserts one `mutation_projection_outbox` row per committed
  mutation.
- `pendingMutationProjectionOutboxRows(limit:)` is currently read-only and
  explicitly defers processing state, leases, retries, deletes, and RunEventLog
  emission to later gates.
- `RustOpLogFFIClient` now owns the Rust OpLog handle and can append
  serde-tagged JSON payloads, iterate tails, read the chain tip, and reopen the
  same SQLite file.
- OpLog currently cannot iterate seq `0` through the Swift bridge, so
  restart-safe duplicate detection needs one bounded read-all ABI.

## Decision

Add the smallest useful projection layer:

- Add an `oplog_iter_all_json` Rust ABI and Swift `iterateAll()` wrapper so a
  projector can detect already-appended mutation projections, including seq `0`.
- Extend `mutation_projection_outbox` with nullable projection metadata:
  `oplog_seq` and `projected_at`.
- Add EventStore APIs to mark a row projected and keep pending reads limited to
  unprojected rows.
- Add `MutationOpLogProjector` as a narrow service that:
  - reads pending rows,
  - scans OpLog for existing mutation projections,
  - marks already-existing rows without re-appending,
  - appends missing rows as `prop_set` payloads,
  - marks rows with the assigned OpLog sequence.

## Files Approved

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/eventstore_oplog_projection_pr2_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_038_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Files Forbidden

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- generated Swift/header bindings
- generated libraries
- Xcode project files
- entitlements
- DerivedData, `.xcresult`, `.rlib`
- stash, branch, staging, commit, or destructive git operations

## Implementation Contract

- EventStore remains the committed `MutationEnvelope` source of truth.
- OpLog projection must be append-only.
- Projection must be idempotent across restart/retry:
  - if a row is unmarked but already exists in OpLog, mark it without appending;
  - if a row is already marked, do not append;
  - if a row is missing, append once and mark with the assigned sequence.
- OpLog payloads must preserve at minimum:
  `mutation_id`, `trace_id`, `event_kind`, `status`, `artifact_id`,
  `artifact_kind`, `integrity_hash`, and recorded timestamp when present.
- No UI success path depends on OpLog in this slice.
- No background worker, timer, or launch bootstrap is added in this slice.
- No broad Rust payload registry rewrite is allowed.

## Tests

Red/green Swift focused command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreOpLogProjectionTests test
```

Existing bridge guard:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

Rust focused command:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
```

Guardrails:

```bash
cargo fmt --manifest-path agent_core/Cargo.toml --check
git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Engine/MutationOpLogProjector.swift Epistemos/State/EventStore.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
rg -n "oplog_(open_at|iter_after_json|iter_all_json|append_payload_json|chain_tip_hex|release|free_string)" Epistemos --glob '*.swift' --glob '!Epistemos/Engine/RustOpLogFFIClient.swift'
git diff --name-only -- Epistemos/Views/Notes/ProseEditor\*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine
```

## Completion Evidence

Status: **passed PR2 foundation slice**.

Implemented:

- Rust `oplog_iter_all_json` plus Swift `RustOpLogFFIClient.iterateAll()`.
- EventStore projection metadata columns `oplog_seq` and `projected_at`.
- Pending-outbox reads limited to unprojected rows.
- `MutationOpLogProjector` append/mark/recovery flow.
- Focused tests proving initial projection, sequence marking, and
  append-before-mark recovery without duplicate OpLog rows.

Verification logs:

- Red proof:
  `/tmp/epistemos-eventstore-oplog-projection-red-20260501.log`
- Rust OpLog focused:
  `/tmp/epistemos-eventstore-oplog-projection-cargo-test-post-kimi-20260501.log`
- Swift EventStore focused:
  `/tmp/epistemos-eventstore-oplog-projection-green-suite-post-kimi-20260501.log`
- Swift bridge/boundary focused:
  `/tmp/epistemos-eventstore-oplog-projection-bridge-boundary-post-kimi-20260501.log`
- Kimi final advisory:
  `/tmp/epistemos-eventstore-oplog-projection-kimi-final-advisory-20260501.log`

Kimi found no P0/P1 blockers. Codex accepted the timestamp-recovery hardening:
when recovering an already-appended projection, `projected_at` is marked from
the existing OpLog entry timestamp rather than the current wall clock.

## Rollback

Revert only the approved projection metadata, projector service, OpLog read-all
ABI, tests, and docs for this slice. The PR1 bridge can remain intact.

## Stop Triggers

- Any need to touch protected editor/graph files, `graph-engine/**`,
  generated bindings, project files, entitlements, stashes, branches, staging,
  or commits.
- Any inability to prove duplicate recovery after append-before-mark.
- Any need for a background worker, timer, or launch bootstrap.
- Any temptation to claim AgentEvent, GraphEvent, UI, or full product
  provenance readiness from this projection alone.
