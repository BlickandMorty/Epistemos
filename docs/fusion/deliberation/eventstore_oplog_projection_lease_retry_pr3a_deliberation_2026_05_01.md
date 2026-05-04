# EventStore OpLog Projection Lease/Retry PR3A Deliberation - 2026-05-01

## Gate

Approved action: **add deterministic lease/retry primitives to the existing
mutation projection outbox and make `MutationOpLogProjector` claim rows before
projecting**.

This gate does not approve launch bootstrap scheduling, timers, UI integration,
AgentEvent, GraphEvent, replay/rollback semantics, protected editor work,
graph-engine work, generated binding edits, staging, commits, or branch
operations.

## Repo Evidence

- PR2 already mirrors committed `MutationEnvelope` outbox rows into the Rust
  OpLog with append-before-mark idempotency.
- `EventStore` still says leases/retries are deferred; this PR3A is the next
  smallest substrate slice to remove that deferral without adding a background
  scheduler.
- `MutationOpLogProjector.projectPending(limit:)` currently reads pending rows
  directly. A future worker needs bounded claims so concurrent or retried runs
  cannot process active rows twice.

## Decision

Add only the worker-safe primitives:

- Extend `mutation_projection_outbox` with nullable lease metadata and retry
  state.
- Add EventStore APIs to claim unprojected, unleased or expired rows for a
  named worker with a finite lease deadline.
- Add EventStore API to record projection failure, clear the active lease, keep
  a retry deadline, and preserve a bounded last-error string.
- Clear lease/failure state when a row is marked projected.
- Update `MutationOpLogProjector` to claim rows before appending/marking and to
  record a bounded failure before rethrowing projection errors.

## Files Approved

- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/eventstore_oplog_projection_lease_retry_pr3a_deliberation_2026_05_01.md`
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
- OpLog projection remains append-only and idempotent.
- No background worker, timer, launch bootstrap, or UI path is added.
- Claiming must be bounded, deterministic, owner-scoped, and ignore active
  unexpired leases.
- Retry deadlines must prevent immediate busy-loop retries.
- Marking a row projected must clear lease and failure metadata.
- Failed projection should be retryable through the existing idempotent recovery
  path after the retry deadline expires.

## Tests

Red/green Swift focused command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreOpLogProjectionTests test
```

Focused fallback command if Xcode's selected test alias maps to the wider file:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveSubstrateTests test
```

Guardrails:

```bash
git diff --check -- Epistemos/State/EventStore.swift Epistemos/Engine/MutationOpLogProjector.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
/usr/bin/grep -nE "Timer|DispatchQueue|Task\\.detached|Task \\{" Epistemos/Engine/MutationOpLogProjector.swift Epistemos/State/EventStore.swift
git diff --name-only -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine epistemos-shadow
```

## Acceptance

- Wired: `MutationOpLogProjector` claims rows before projecting.
- Reachable: tests can claim rows, observe active leases blocking competing
  workers, expire/retry rows, and project after a claim.
- Visible: tests show attempt count, lease owner/deadline, retry deadline,
  bounded last error, and cleared lease/failure metadata after projection.

## Closeout

Status: **closed 2026-05-01**.

Additional hardening added during implementation:

- `markMutationProjectionOutboxProjected(...)` now accepts an optional
  `ownerID`.
- `MutationOpLogProjector` supplies its worker id when marking rows projected.
- A stale worker whose lease expired cannot clear a newer worker's active
  lease or mark that newer claim projected.

Evidence:

- Original red log:
  `/tmp/epistemos-oplog-lease-retry-pr3a-red-20260501.log`
- Owner-guard red log:
  `/tmp/epistemos-oplog-lease-retry-pr3a-owner-red-20260501.log`
- Green log:
  `/tmp/epistemos-oplog-lease-retry-pr3a-green-20260501.log`
- Swift Testing suite `EventStore Cognitive Tables`: `13` tests passed,
  `0` failed.
- Kimi oversight:
  `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_041_2026_05_01.md`

Deferred future gates:

- Background projection worker scheduling.
- Max-attempt/dead-letter handling.
- Configured lease/retry durations.
- Structured retry/failure observability.
- Replay/rollback, AgentEvent/tool provenance, and GraphEvent mapping.

## Rollback

Revert only the outbox lease/retry columns, EventStore claim/failure APIs,
projector claim/failure handling, tests, and docs for this slice. PR2
projection can remain intact.

## Stop Triggers

- Any need to touch protected editor/graph files, `graph-engine/**`,
  `agent_core/**`, generated bindings, project files, entitlements, stashes,
  branches, staging, or commits.
- Any need to add a timer, app launch worker, UI surface, AgentEvent,
  GraphEvent, or replay/rollback feature.
- Claim/retry behavior cannot be proven without nondeterministic sleeps.
