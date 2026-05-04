# EventStore OpLog Projection Worker PR3C Deliberation - 2026-05-01

## Gate

Approved action: **add the smallest production scheduling path for committed
`MutationEnvelope` projection into the Rust OpLog**.

This gate approves a one-shot/coalesced worker that AppBootstrap can create and
schedule after deferred runtime services start. It does not approve a repeating
timer, endless background loop, UI surface, AgentEvent, GraphEvent,
replay/rollback, protected editor work, graph-engine work, generated binding
edits, staging, commits, or branch operations.

## Repo Evidence

- PR2 proved committed `MutationEnvelope` outbox rows can be projected into the
  Rust OpLog idempotently.
- PR3A proved deterministic owner-scoped lease/retry primitives.
- PR3B proved bounded dead-letter state so a future worker cannot spin forever
  on poison rows.
- `RustOpLogFFIClient` currently owns the raw ABI safely but has no production
  scheduling call site.
- AppBootstrap already uses deferred runtime tasks for expensive startup
  services and skips those paths under tests where needed.

## Decision

Add only the worker/scheduler shell needed to make projection real:

- Create `MutationOpLogProjectionWorker`.
- Resolve a stable app-scoped OpLog database URL under
  `Application Support/Epistemos/mutation-oplog.sqlite`.
- Build `RustOpLogFFIClient` lazily inside each drain attempt, not on the main
  launch path.
- Coalesce scheduled drains so repeated scheduling while a drain is in flight
  does not create concurrent workers.
- Run one deferred startup drain from AppBootstrap after the main launch path
  settles.
- Keep the existing `MutationOpLogProjector` as the only projection logic owner.

## Files Approved

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/eventstore_oplog_projection_worker_pr3c_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `agent_core/src/oplog.rs`
- `Epistemos/State/EventStore.swift`
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

- EventStore remains the committed `MutationEnvelope` source of truth.
- The worker is a scheduler shell; projection semantics stay in
  `MutationOpLogProjector`.
- AppBootstrap must not open the OpLog SQLite handle synchronously on init.
- Scheduled drains must be coalesced and finite.
- Production scheduling must be skipped under tests.
- Failures must be logged and leave retry/dead-letter handling to the projector
  and EventStore primitives already proven in PR3A/PR3B.
- No background loop, timer, UI, AgentEvent, GraphEvent, replay, rollback, or
  broad agent-core integration is added.

## Tests

Red/green Swift focused command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

Guardrails:

```bash
git diff --check -- Epistemos/App/AppBootstrap.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Engine/RustOpLogFFIClient.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
/usr/bin/grep -nE "Timer|DispatchSourceTimer|repeatForever|while true|Task\\.detached|scheduleDrain" Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/App/AppBootstrap.swift
git diff --name-only -- agent_core/src/oplog.rs Epistemos/State/EventStore.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine epistemos-shadow build-rust
```

## Acceptance

- Wired: AppBootstrap creates a worker when EventStore is available and schedules
  one deferred startup drain in production.
- Reachable: tests can construct the worker, drain a pending envelope, and
  inspect the appended Rust OpLog row.
- Visible: tests/source guards prove the production scheduling call exists and
  raw ABI calls remain confined to `RustOpLogFFIClient`.

## Rollback

Remove the worker file, AppBootstrap worker creation/scheduling, the adjusted
bridge source guard, tests, and docs for this slice. PR2 projection and PR3A/B
outbox primitives can remain intact.

## Stop Triggers

- Any need to edit `EventStore.swift`, protected editor/graph files,
  `graph-engine/**`, `agent_core/**`, generated bindings, project files,
  entitlements, stashes, branches, staging, or commits.
- Any need for a repeating timer, endless worker loop, UI surface, AgentEvent,
  GraphEvent, replay, rollback, or direct raw ABI call outside
  `RustOpLogFFIClient`.
- The worker cannot be tested without sleeping or relying on wall-clock races.

## Closeout - 2026-05-01

Status: **closed as PR3C**.

Implemented:

- Added `MutationOpLogProjectionWorker` as a finite, coalesced projection
  scheduler shell.
- AppBootstrap now constructs the worker when EventStore is available and
  schedules one deferred runtime-service drain in production only.
- The worker resolves the app-scoped OpLog database at
  `Application Support/Epistemos/mutation-oplog.sqlite`.
- The worker lazily creates `RustOpLogFFIClient` per drain and delegates all
  projection semantics to `MutationOpLogProjector`.
- Source guards now prove raw OpLog C ABI calls stay confined to
  `RustOpLogFFIClient` and that AppBootstrap is the production scheduler
  entrypoint.

Kimi advisory:

- Read-only advisory log:
  `/tmp/epistemos-oplog-worker-pr3c-kimi-advisory-20260501.log`.
- Kimi recommended the same narrow one-shot/coalesced worker shape and did not
  modify the worktree. The status diff around the Kimi run only showed this
  PR3C gate doc being added by Codex.

Verification:

- Red test:
  `/tmp/epistemos-oplog-worker-pr3c-red-20260501.log`.
  Expected compile failure: `MutationOpLogProjectionWorker` did not exist yet.
- Green EventStore worker suite:
  `/tmp/epistemos-oplog-worker-pr3c-green-20260501.log`.
  Result: `16` tests in `EventStoreSchemaTests` passed; `** TEST SUCCEEDED **`.
- Boundary/source guard suite:
  `/tmp/epistemos-oplog-worker-pr3c-boundary-20260501.log`.
  Result: `2` tests in `OpLogFFIBoundaryGuardTests` passed; `** TEST SUCCEEDED **`.
- `git diff --check` emitted no findings for the approved tracked files and
  docs.
- `git diff --no-index --check` emitted no whitespace findings for the new
  worker, bridge, and PR3C gate files. The command exits `1` for new-file diffs;
  the relevant output was empty.
- Scheduler grep found the intended worker `Task.detached` and AppBootstrap
  `scheduleDrain(reason: "deferred_runtime_services")` call, with no timer,
  `DispatchSourceTimer`, `repeatForever`, or `while true` in the new worker.

Guardrail notes:

- The protected-path name-only scan still reports preexisting dirty files under
  `Epistemos/State/EventStore.swift`, `agent_core/src/oplog.rs`,
  `epistemos-shadow/**`, and `graph-engine/**`; PR3C did not edit those files.
- Xcode still reports inherited SwiftLint plugin command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`.
  This remains existing plugin/lint debt, not a PR3C compile/test blocker.

Remaining provenance gates:

- Replay/rollback semantics for projected mutation provenance.
- AgentEvent/tool provenance.
- GraphEvent durable mutation mapping.
- Dead-letter inspector/audit visibility.
