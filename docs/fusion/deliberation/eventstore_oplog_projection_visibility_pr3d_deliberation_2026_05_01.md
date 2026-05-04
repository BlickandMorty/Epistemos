# EventStore OpLog Projection Visibility PR3D Deliberation - 2026-05-01

## Gate

Approved action: **add bounded read-only diagnostics for EventStore OpLog
projection health and dead-letter visibility**.

This gate follows PR3C. Projection, lease/retry, dead-lettering, and scheduling
are already wired; this slice only makes the current state inspectable from the
existing Settings diagnostics surface.

## Repo Evidence

- PR2 mirrors committed `MutationEnvelope` outbox rows into Rust OpLog.
- PR3A supplies owner-scoped lease/retry state.
- PR3B supplies max-attempt dead-letter state and repair clearing.
- PR3C supplies finite AppBootstrap scheduling through
  `MutationOpLogProjectionWorker`.
- `SettingsView` already has a read-only "Diagnostics" section containing
  `EditorBundleHealthRow`, `BackgroundIndexingHealthRow`, and
  `SearchFusionHealthRow`.
- `EventStore.MutationProjectionOutboxRow` already exposes projected, leased,
  attempt, last-error, and dead-letter fields.

## Decision

Add the smallest diagnostics path:

- Add a bounded EventStore diagnostics value for mutation projection outbox
  counts: total, pending, leased, projected, dead-lettered, and latest
  dead-letter row.
- Add `OpLogProjectionHealthRow` to Settings diagnostics.
- Mount it in `SettingsView` below the existing background/search diagnostics.
- Add focused tests for counts, latest dead-letter ordering, and source guards
  proving the Settings row is mounted.

## Files Approved

- `Epistemos/State/EventStore.swift`
- `Epistemos/Views/Settings/OpLogProjectionHealthRow.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/eventstore_oplog_projection_visibility_pr3d_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
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

- Read-only only: no repair button, retry button, projection trigger, or
  mutation of EventStore rows.
- EventStore remains the source of diagnostics truth.
- Queries must be bounded and tolerate empty databases.
- The Settings row must not instantiate Rust OpLog clients or call raw ABI.
- No timer, no endless loop, no background worker, no UI outside Settings.
- No protected editor/graph work.

## Tests

Focused Swift command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

Guardrails:

```bash
git diff --check -- Epistemos/State/EventStore.swift Epistemos/Views/Settings/OpLogProjectionHealthRow.swift Epistemos/Views/Settings/SettingsView.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
/usr/bin/grep -nE "Timer|DispatchSourceTimer|repeatForever|while true|oplog_open_at|oplog_append_payload_json" Epistemos/Views/Settings/OpLogProjectionHealthRow.swift Epistemos/Views/Settings/SettingsView.swift
git diff --name-only -- agent_core/src/oplog.rs Epistemos/Engine/MutationOpLogProjector.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine epistemos-shadow build-rust
```

## Acceptance

- Wired: Settings diagnostics includes an OpLog projection health row.
- Reachable: EventStore exposes bounded diagnostics without needing a vault or
  Rust OpLog handle.
- Visible: diagnostics surface projected/pending/leased/dead-letter counts and
  latest dead-letter mutation/reason when present.

## Rollback

Remove the EventStore diagnostics value/API, the Settings row file, the
SettingsView mount, tests, and docs for this slice. Projection PR2, PR3A/B, and
PR3C worker scheduling can remain intact.

## Stop Triggers

- Any need to mutate projection rows from the UI.
- Any need to touch Rust, OpLog ABI, graph/editor protected files, generated
  outputs, project files, entitlements, stashes, branches, staging, or commits.
- The diagnostics query requires an unbounded table scan or polling loop.

## Closeout - 2026-05-01

Status: **closed after focused verification**.

Kimi advisory:

- First model attempt failed with `LLM not set`:
  `/tmp/epistemos-oplog-dead-letter-visibility-kimi-advisory-20260501.log`.
- Correct `kimi-code/kimi-for-coding` advisory completed in:
  `/tmp/epistemos-oplog-dead-letter-visibility-kimi-advisory-2-20260501.log`.
- Kimi recommended the same narrow shape: read-only Settings diagnostics plus
  bounded EventStore diagnostics, with no repair UI or raw OpLog ABI in the
  view.

Implementation:

- Added `MutationProjectionOutboxDiagnostics` and
  `mutationProjectionOutboxDiagnostics(now:)` to EventStore.
- Added read-only `OpLogProjectionHealthRow` under Settings diagnostics.
- Mounted the row in `SettingsView`.
- Added focused coverage for counts, latest dead-letter ordering, and
  source-guard read-only mounting.

Verification:

- First focused run failed as expected while tightening Swift 6 actor isolation:
  `/tmp/epistemos-oplog-visibility-pr3d-focused-20260501.log`.
- Green focused run:
  `/tmp/epistemos-oplog-visibility-pr3d-focused-2-20260501.log`.
- Result: `20` tests in `2` suites passed, `** TEST SUCCEEDED **`, exit `0`.

Guardrails:

- `git diff --check` emitted no findings for approved PR3D files and docs.
- `git diff --no-index --check` emitted no whitespace findings for the new
  Settings row and gate doc.
- Source grep found no timer, `DispatchSourceTimer`, `repeatForever`,
  `while true`, raw OpLog ABI, or projection mutator calls in the Settings
  diagnostics row.
- Protected-path scan showed only older dirty `agent_core`, `epistemos-shadow`,
  and `graph-engine` files outside this PR3D slice.

Decision:

PR3D closes basic dead-letter/projection visibility. Future work may add deeper
audit trails or repair UX only behind a fresh gate that names the exact files
and keeps mutating controls out of this read-only diagnostics row.
