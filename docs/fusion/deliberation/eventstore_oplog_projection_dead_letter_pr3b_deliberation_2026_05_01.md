# EventStore OpLog Projection Dead-Letter PR3B Deliberation - 2026-05-01

## Gate

Approved action: **add bounded dead-letter state to the existing mutation
projection outbox so poison projection rows cannot retry forever once a future
worker exists**.

This gate builds directly on PR3A lease/retry primitives. It does not approve a
background worker, launch bootstrap scheduling, timers, UI integration,
AgentEvent, GraphEvent, replay/rollback semantics, protected editor work,
graph-engine work, generated binding edits, staging, commits, or branch
operations.

## Repo Evidence

- PR2 proved committed `MutationEnvelope` outbox rows can be projected into the
  Rust OpLog idempotently.
- PR3A proved owner-scoped claim/retry, active lease blocking, stale-owner mark
  denial, and retry deadline behavior.
- Kimi PR3A P2 follow-up recommended max-attempt/dead-letter handling before a
  real worker can spin on poison rows.

## Decision

Add only bounded dead-letter primitives:

- Extend `mutation_projection_outbox` with nullable dead-letter metadata.
- Exclude dead-lettered rows from pending and claim queries.
- Allow `recordMutationProjectionOutboxFailure(...)` to dead-letter a leased row
  once its attempt count reaches a caller-supplied maximum.
- Keep last error bounded and visible.
- Clear dead-letter metadata if a row is later marked projected through an
  explicit repair/recovery path.
- Wire `MutationOpLogProjector` to pass a bounded max-attempt value when
  recording projection failures.

## Files Approved

- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/eventstore_oplog_projection_dead_letter_pr3b_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `agent_core/src/oplog.rs`
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

- EventStore remains the committed `MutationEnvelope` source of truth.
- Dead-letter is projection-worker state only; it must not mutate the committed
  envelope payload.
- Dead-lettered rows must not be returned by pending/claim APIs.
- Failure recording must be owner-scoped and must not dead-letter someone
  else's active lease.
- Successful projection must clear lease, retry, and dead-letter metadata.
- No background loop, timer, app launch worker, UI surface, AgentEvent,
  GraphEvent, or replay/rollback feature is added.

## Tests

Red/green Swift focused command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

Guardrails:

```bash
git diff --check -- Epistemos/State/EventStore.swift Epistemos/Engine/MutationOpLogProjector.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
/usr/bin/grep -nE "Timer|DispatchQueue|Task\\.detached|Task \\{" Epistemos/Engine/MutationOpLogProjector.swift Epistemos/State/EventStore.swift
git diff --name-only -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine epistemos-shadow build-rust
```

## Acceptance

- Wired: `MutationOpLogProjector` passes a max-attempt limit into failure
  recording.
- Reachable: tests can drive a row to max attempts and see it dead-lettered.
- Visible: tests show dead-letter timestamp/reason, bounded last error, claim
  exclusion, and successful projection metadata clearing.

## Rollback

Revert only the dead-letter columns, EventStore max-attempt failure behavior,
projector max-attempt wiring, tests, and docs for this slice. PR2 projection and
PR3A lease/retry primitives can remain intact.

## Stop Triggers

- Any need to touch protected editor/graph files, `graph-engine/**`,
  `agent_core/**`, generated bindings, project files, entitlements, stashes,
  branches, staging, or commits.
- Any need to add a timer, app launch worker, UI surface, AgentEvent,
  GraphEvent, or replay/rollback feature.
- Dead-letter behavior cannot be proven deterministically without sleeps.

## Closeout - 2026-05-01

Status: **closed by focused red/green verification and local guardrails**.

Implementation:

- `mutation_projection_outbox` now has nullable `dead_lettered_at` and
  `dead_letter_reason` metadata plus a claimable index that includes
  dead-letter state.
- Pending and claim APIs exclude rows where `dead_lettered_at` is set.
- `recordMutationProjectionOutboxFailure(...)` remains owner-scoped and can
  dead-letter a leased row when `attempt_count >= maxAttempts`.
- `last_error` remains bounded to 512 characters.
- `markMutationProjectionOutboxProjected(...)` clears lease, retry, last-error,
  and dead-letter metadata so explicit repair can mark a row projected.
- `MutationOpLogProjector` now passes a bounded default max-attempt limit when
  recording projection failures.

Red evidence:

- `/tmp/epistemos-oplog-dead-letter-pr3b-red-20260501.log`
- Expected compile failures:
  `Extra argument 'maxAttempts' in call`,
  missing `deadLetteredAt`, and missing `deadLetterReason`.

Green evidence:

- `/tmp/epistemos-oplog-dead-letter-pr3b-green-20260501.log`
- `/tmp/epistemos-oplog-dead-letter-pr3b-green-2-20260501.log`
- Swift Testing result: `14` tests in `EventStore Cognitive Tables` passed.
- Xcode result: `** TEST SUCCEEDED **`, command exit code `0`.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after test success; this is
  existing plugin/lint noise and not a PR3B test failure.

Guardrails:

- `git diff --check -- Epistemos/State/EventStore.swift Epistemos/Engine/MutationOpLogProjector.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion`
  passed.
- Scheduler grep found only the existing EventStore serial queue and queue-key
  guard; PR3B added no worker, timer, detached task, UI, AgentEvent, GraphEvent,
  replay, or rollback feature.
- Protected-path diff scan still reports preexisting dirty graph/shadow/oplog
  paths on the branch; PR3B did not edit those paths and did not touch
  generated bindings, project files, entitlements, stash, branch, staging, or
  commit state.

Kimi oversight:

- Attempted read-only Kimi audit:
  `/tmp/epistemos-oplog-dead-letter-pr3b-kimi-advisory-20260501.log`
- The audit produced no output and was terminated after several minutes.
- Before/after status diff was empty:
  `/tmp/epistemos-oplog-dead-letter-pr3b-kimi-status-before-20260501.txt`
  versus
  `/tmp/epistemos-oplog-dead-letter-pr3b-kimi-status-after-20260501.txt`.
- PR3B closeout therefore relies on Codex local review, red/green tests, and
  guardrails, not on a completed Kimi approval.

Remaining deferred work:

- Background projection worker scheduling.
- Replay/rollback semantics for projected mutation provenance.
- `AgentEvent`/tool provenance and `GraphEvent` durable mutation mapping.
- Inspector/audit visibility for dead-lettered projection rows.
