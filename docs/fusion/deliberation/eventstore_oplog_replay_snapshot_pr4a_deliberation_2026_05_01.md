# EventStore OpLog Replay Snapshot PR4A Deliberation - 2026-05-01

## Gate

Approved action: **add a Swift-only, read-only replay snapshot for projected
MutationEnvelope provenance in the OpLog**.

This follows PR2, PR3A, PR3B, PR3C, and PR3D. Projection is already durable,
lease/retry/dead-lettered, scheduled, and visible. This slice adds the smallest
replay/rollback semantic surface: fold OpLog projection entries into a
deterministic snapshot, optionally cut off at a sequence number.

## Repo Evidence

- `RustOpLogFFIClient` already exposes `iterateAll()` and typed `OpLogEntry`
  decoding.
- `MutationOpLogProjector` already writes mutation projections as
  `prop_set(node_id: mutationID, key: "mutation_projection", value: object)`.
- `OpLogPayload.projectionMutationID` already extracts the canonical mutation
  id from a projection payload.
- Rust `OpLog` already supports replay/fold internally and exposes iteration
  through the existing raw ABI.
- Current Swift tests already verify append, iteration, reopen, projection, and
  append-before-mark recovery.

## Decision

Add a new Swift engine file that:

- Replays only mutation projection entries from `[OpLogEntry]`.
- Produces an immutable snapshot containing ordered projection records,
  duplicate projection records, ignored non-projection count, and cutoff state.
- Supports `upToSeq` rollback inspection without mutating EventStore or OpLog.
- Treats the first projection for a mutation id as canonical and records later
  duplicates as ignored duplicates.
- Exposes a convenience method on `RustOpLogFFIClient` that calls
  `iterateAll()` and replays the decoded entries.

## Files Approved

- `Epistemos/Engine/MutationOpLogReplay.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/eventstore_oplog_replay_snapshot_pr4a_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `agent_core/src/oplog.rs`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `Epistemos/Views/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- generated Swift/header bindings
- generated libraries
- Xcode project files
- entitlements
- DerivedData, `.xcresult`
- stash, branch, staging, commit, or destructive git operations

## Implementation Contract

- Read-only only: no EventStore row updates, no OpLog append, no repair action,
  no UI, and no background scheduling.
- Swift-only: use existing decoded `OpLogEntry` values and existing
  `RustOpLogFFIClient.iterateAll()`.
- Deterministic ordering: sort/fold by ascending `seq` before producing the
  snapshot.
- Rollback semantics are a read-only cutoff view: `upToSeq` includes entries
  with `seq <= upToSeq` and excludes later entries.
- Duplicates must be visible, not silently hidden.
- Non-projection OpLog entries must be ignored and counted.
- Do not add raw C ABI symbols or touch Rust.

## Tests

Red/green focused Swift command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests test
```

Expected tests:

- Replay folds mutation projections deterministically and supports cutoff
  rollback views.
- Replay records duplicate mutation projections while preserving first-writer
  semantics.
- Bridge convenience replay reads from an actual Rust OpLog without exposing raw
  ABI outside `RustOpLogFFIClient`.

Guardrails:

```bash
git diff --check -- Epistemos/Engine/MutationOpLogReplay.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
git diff --no-index --check /dev/null Epistemos/Engine/MutationOpLogReplay.swift
/usr/bin/grep -nE "oplog_open_at|oplog_append_payload_json|@_silgen_name|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows" Epistemos/Engine/MutationOpLogReplay.swift EpistemosTests/CognitiveSubstrateTests.swift
git diff --name-only -- agent_core/src/oplog.rs Epistemos/State/EventStore.swift Epistemos/Engine/MutationOpLogProjector.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine epistemos-shadow build-rust
```

## Acceptance

- Wired: a caller with decoded OpLog entries or a `RustOpLogFFIClient` can
  produce a replay snapshot.
- Reachable: tests use a real Rust OpLog bridge for the convenience path.
- Visible: tests prove ordered replay, cutoff rollback view, duplicate
  reporting, and non-projection ignore counts.

## Rollback

Delete the replay file, remove the focused replay tests, and remove PR4A docs.
Projection, scheduling, diagnostics, and Rust OpLog ABI remain intact.

## Stop Triggers

- Any need to mutate EventStore or OpLog during replay.
- Any need for Rust ABI/schema changes.
- Any need for UI, graph, editor, generated artifact, project, entitlement,
  branch, stash, staging, commit, or destructive git changes.
- Replay needs to interpret full note bodies or graph state instead of projected
  MutationEnvelope provenance.

## Closeout - 2026-05-01

Status: **closed after focused verification**.

Kimi advisory:

- `/tmp/epistemos-oplog-replay-pr4a-kimi-advisory-20260501.log`
- Kimi found no P0 blockers and recommended the same Swift-only shape: replay
  decoded `OpLogEntry` values with no Rust FFI, EventStore schema, production
  UI, or scheduler changes.
- Kimi suggested "later duplicate wins"; Codex kept first-writer semantics
  because the existing projector recovery path indexes the first projection for
  a mutation id and marks EventStore from that canonical projection.

Implementation:

- Added `MutationOpLogReplayRecord`, `MutationOpLogReplayDuplicate`, and
  `MutationOpLogReplaySnapshot`.
- Added `MutationOpLogReplay.replay(_:upToSeq:)`.
- Added `RustOpLogFFIClient.replayMutationProjections(upToSeq:)` as a
  convenience wrapper around the existing `iterateAll()` method.
- Added focused tests for deterministic fold ordering, rollback cutoff views,
  duplicate reporting, and real Rust OpLog bridge replay.

Verification:

- Red log: `/tmp/epistemos-oplog-replay-pr4a-red-20260501.log`.
  Expected failure: missing `MutationOpLogReplay` and bridge convenience API.
- Green log: `/tmp/epistemos-oplog-replay-pr4a-green-20260501.log`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_15-52-07--0500.xcresult`.
- Xcode exited `0`; xcresult action status was `succeeded` with `4` tests.

Guardrails:

- `git diff --check` emitted no findings for PR4A files and docs.
- `git diff --no-index --check` emitted no whitespace findings for the new
  replay file and gate doc.
- Source grep found no raw OpLog ABI, projection mutators, timers,
  `DispatchQueue`, `repeatForever`, or `while true` in
  `MutationOpLogReplay.swift`.
- Protected-path scan showed older dirty `EventStore`, `agent_core`,
  `epistemos-shadow`, and `graph-engine` files outside the PR4A write set.

Decision:

PR4A closes read-only projected-provenance replay and logical rollback cutoff
views. Future work should not rebuild this snapshot layer; instead open fresh
gates for cryptographic chain verification, incremental/batched replay,
ReplayBundle export, AgentEvent/tool provenance, GraphEvent mapping, or repair
UX.
