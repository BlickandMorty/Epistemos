# GraphEvent Durable Mapping PR1 Deliberation - 2026-05-01

## Gate

Approved action: **add a Swift/EventStore GraphEvent durable mapping foundation
for committed graph-affecting `MutationEnvelope`s**.

This is the next provenance-spine slice after AgentEvent PR3. It must not touch
the protected graph renderer/controller/editor surfaces and must not project into
live UI, Halo, Theater, Rust OpLog, or graph-engine physics.

## Repo Evidence

- `MutationEnvelope` already records `mutationID`, `runID`, `sequence`,
  `traceId` at EventStore save time, `SourceOp`, `relationChanges`,
  `affectsGraph`, and integrity metadata.
- `EventStore.saveMutationEnvelope(_:traceId:)` already commits the envelope and
  mutation projection outbox row in one SQLite transaction.
- AgentEvent PR1 established the bounded EventStore pattern:
  lower-snake-case Codable model, unique `event_id`, save/load/list APIs,
  bounded reads, and idempotent upsert.

## Decision

Implement only the durable GraphEvent foundation:

- Add Swift durable graph-event Codable model types in an existing compiled
  model file. The concrete Swift type is `DurableGraphEvent` because
  `Epistemos/Engine/EventDrain.swift` already owns the 64-byte FFI
  `GraphEvent` ring-event type.
- Add `graph_events` table and indexes to EventStore.
- Add `saveGraphEvent(_:)`, `loadGraphEvent(eventID:)`, and
  `graphEvents(mutationID:limit:)`.
- When a committed `MutationEnvelope` affects graph provenance, insert the
  derived GraphEvent row(s) in the same transaction as the envelope/outbox save.
- Keep the mapping deterministic and idempotent by deriving event ids from
  `mutationID` plus deterministic indexes.

## Files Approved

- `Epistemos/Models/MutationEnvelope.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/graph_event_durable_mapping_pr1_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Omega/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- generated Swift/header bindings
- generated libraries
- Xcode project files
- entitlements
- DerivedData, `.xcresult`
- stash, branch, staging, commit, or destructive git operations

## Implementation Contract

- No UI, renderer, graph-engine, Rust OpLog, AgentEvent, hook, Omega, Halo,
  Theater, or ReplayBundle wiring.
- Pending, failed, and reverted envelopes must not create GraphEvents.
- Committed envelopes create GraphEvents only when `affectsGraph` is true,
  `relationChanges` is non-empty, or `op == .graphMutation`.
- The mapping must be deterministic, idempotent, bounded, and queryable by
  mutation id.
- Existing `MutationEnvelope` wire format must not change.

## Tests

Red/green focused Swift command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

Expected source/runtime guards:

- GraphEvent JSON round-trips lower-snake-case keys.
- `graph_events` table exists.
- EventStore can save/load/list bounded GraphEvents.
- Committed graph-affecting MutationEnvelopes create idempotent GraphEvents.
- Pending graph-affecting MutationEnvelopes do not create GraphEvents.

Guardrails:

```bash
git diff --check -- Epistemos/Models/MutationEnvelope.swift Epistemos/State/EventStore.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
/usr/bin/grep -nE "MetalGraphView|HologramController|ProseEditor|RustOpLogFFIClient|MutationOpLogProjector|MutationOpLogProjectionWorker|HookRegistry|Omega|ChatCoordinator|PipelineService" Epistemos/Models/MutationEnvelope.swift Epistemos/State/EventStore.swift
git diff --name-only -- Epistemos/Views/Graph Epistemos/Graph graph-engine agent_core Epistemos/Engine/MutationOpLogProjector.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Engine/PipelineService.swift Epistemos/App/ChatCoordinator.swift Epistemos/Omega Epistemos/Views/Notes build-rust
```

## Acceptance

- Wired: committed graph-affecting mutation envelopes persist deterministic
  GraphEvents transactionally.
- Reachable: EventStore save/load/list APIs exercise the actual SQLite table.
- Visible: focused tests prove JSON shape, table creation, bounded ordering,
  idempotency, and pending-envelope exclusion.

## Rollback

Remove GraphEvent model/API/table mapping/tests and delete this deliberation
closeout. Prior MutationEnvelope, OpLog, and AgentEvent slices remain intact.

## Stop Triggers

- Any need to touch graph renderer/controller/editor paths.
- Any need to modify Rust `agent_core`, `graph-engine`, generated bindings, or
  OpLog projection workers.
- Any need to change MutationEnvelope wire format.
- Any GraphEvent write would be non-deterministic or not tied to a mutation id.

## Closeout

Status: **closed after focused red/green verification**.

Implemented:

- `DurableGraphEventKind`, `DurableGraphEventRelation`, and
  `DurableGraphEvent` as the persisted graph mutation stream model.
- `graph_events` EventStore table with unique `event_id` and mutation, trace,
  entity, and kind indexes.
- `saveGraphEvent(_:)`, `loadGraphEvent(eventID:)`, and
  `graphEvents(mutationID:limit:)` bounded APIs.
- Transactional insertion of deterministic graph events during committed
  graph-affecting `MutationEnvelope` saves.
- Pending graph-affecting envelopes do not emit durable graph events.

Naming note:

- The persisted model intentionally uses `DurableGraphEvent`, not `GraphEvent`,
  because the app already has a public `GraphEvent` in `EventDrain.swift` for
  the substrate-rt 64-byte FFI ring event.

Verification:

- Red: `/tmp/epistemos-graph-event-pr1-red-20260501.log`
- Green: `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`
- Result: `28` tests in `EventStore Cognitive Tables` passed.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`.
- Inherited CodeEdit SwiftLint plugin command failures still appeared after the
  success marker; this is existing package-plugin noise, not a PR1 failure.

Kimi audit:

- `/tmp/epistemos-graph-event-pr1-kimi-audit-20260501-r1.log` produced no
  output and was terminated.

Guardrails:

- `git diff --check` passed for the allowed files and docs.
- Forbidden-symbol grep on implementation files produced no output.
- A broader grep over `CognitiveSubstrateTests.swift` sees inherited OpLog
  tests already present in the dirty branch; this PR1 did not edit OpLog,
  graph renderer/controller, graph engine, Omega, ChatCoordinator,
  PipelineService, generated bindings, project, entitlement, branch, stash,
  stage, or commit state.
