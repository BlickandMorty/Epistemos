# Codex/Kimi Oversight Round 041 - EventStore OpLog Projection Lease/Retry PR3A

Date: 2026-05-01

## Scope

Raw Thoughts / provenance spine hardening: EventStore OpLog Projection
Lease/Retry PR3A.

This round covered only deterministic lease/retry primitives for the existing
`mutation_projection_outbox` and the projector's claim-before-project path. It
did not approve launch bootstrap scheduling, timers, UI integration,
AgentEvent, GraphEvent, replay/rollback semantics, protected editor work,
graph-engine work, generated binding edits, staging, commits, or branch
operations.

## Gate

Deliberation gate:

- `docs/fusion/deliberation/eventstore_oplog_projection_lease_retry_pr3a_deliberation_2026_05_01.md`

Approved files:

- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/**`

Forbidden files and actions:

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- generated Swift/header bindings and generated libraries
- Xcode project files, entitlements, DerivedData, `.xcresult`
- stash, branch, staging, commit, or destructive git operations

## Codex Verification

Red logs:

- `/tmp/epistemos-oplog-lease-retry-pr3a-red-20260501.log`
- Expected failure before implementation: missing lease/retry outbox APIs and
  row metadata.
- `/tmp/epistemos-oplog-lease-retry-pr3a-owner-red-20260501.log`
- Expected failure before owner hardening: missing owner-scoped projection mark
  API, proving stale workers could not yet be denied.

Green log:

- `/tmp/epistemos-oplog-lease-retry-pr3a-green-20260501.log`
- Swift Testing suite `EventStore Cognitive Tables`: `13` tests passed,
  `0` failed.
- Covered active lease blocking, retry deadlines, bounded last error,
  stale-owner mark denial, projector append/mark, and append-before-mark
  recovery.
- Xcode emitted `** TEST SUCCEEDED **` and exited `0`.

Guardrails:

- `git diff --check -- Epistemos/State/EventStore.swift Epistemos/Engine/MutationOpLogProjector.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion` passed.
- Scheduler grep found no new `Timer`, `Task.detached`, or `Task {` in the
  approved implementation files; the only hits were the preexisting
  `EventStore` serial `DispatchQueue` and queue-key check.
- Protected-path scan still lists inherited dirty `agent_core`,
  `graph-engine/**`, and `epistemos-shadow/**` paths from the existing
  worktree, but this PR3A slice did not edit them.
- `build-rust` had no tracked status after Xcode's build scripts ran.
- Kimi before/after status comparison was empty; Kimi made no file changes.

## Kimi Advisory

Log:

- `/tmp/epistemos-oplog-lease-retry-pr3a-kimi-advisory-20260501.log`
- Kimi resume id: `ad12d276-1eca-44c5-9ada-f31812c878b0`

Kimi result:

- P0 blockers: none.
- P1 blockers: none.
- Verdict: EventStore OpLog Projection Lease/Retry PR3A can close.

Kimi P2 follow-ups deferred to future gates:

- Add max-attempt/dead-letter handling so failed rows cannot retry forever.
- Wire lease duration and retry delay from future worker/config bootstrap
  rather than constructor defaults.
- Add structured retry/failure observability when the worker exists.
- Optional no-op optimization: avoid an empty transaction when there are no
  claimable rows.

## Gate Decision

Close EventStore OpLog Projection Lease/Retry PR3A.

This proves the outbox can deterministically claim unprojected rows, block
competing workers during active leases, retry after a bounded delay, preserve
attempt/error visibility, deny stale lease-owner marks, and clear lease/failure
metadata after projection.

Do not claim background projection worker completion. Worker scheduling,
dead-lettering, replay/rollback, AgentEvent/tool provenance, GraphEvent mapping,
and audit/inspector visibility remain separate gates.
