# AgentEvent Tool Provenance PR1 Deliberation - 2026-05-01

## Gate

Approved action: **add the first durable Swift AgentEvent/tool provenance
foundation**.

This follows the EventStore-to-OpLog projection PR series. `MutationEnvelope`
now has durable storage, projection, replay snapshots, diagnostics, and worker
scheduling. AgentEvent is still missing as a typed persisted surface. This
slice adds the smallest honest foundation: a typed AgentEvent model and
EventStore persistence/readback. It does not wire production ChatCoordinator,
Omega, hooks, or UI.

## Repo Evidence

- `MutationEnvelope` already has a typed Swift model and EventStore persistence.
- `EventStore` has no dedicated AgentEvent table or typed AgentEvent read API.
- `AgentRuntimeEvent` exists only in an unavailable archived compatibility
  surface.
- `ReasoningLoopService.ToolCallRecord`, `HookToolCall`, `HookToolResult`, and
  `AgentPermissionRequest` expose enough vocabulary to inform the schema, but
  production wiring is a separate gate.
- The canonical spine remains:
  `TypedArtifact -> MutationEnvelope -> RunEventLog / AgentEvent / GraphEvent`.

## Decision

Add:

- A typed Swift model for durable AgentEvent provenance with
  lower-snake-case JSON wire keys.
- Typed tool provenance payloads for tool request, approval, completion, and
  failure.
- EventStore `agent_events` table with unique `event_id` and indexed
  `run_id`, `trace_id`, and `tool_name`.
- EventStore `saveAgentEvent(_:)`, `loadAgentEvent(eventID:)`, and bounded
  `agentEvents(runID:limit:)`.
- Focused tests for JSON round-trip, table creation, save/load, bounded ordered
  reads, and idempotent event-id upsert.

## Files Approved

- `Epistemos/Models/AgentProvenanceEvent.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/agent_event_tool_provenance_pr1_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/HookRegistry.swift`
- `Epistemos/Omega/**`
- `Epistemos/Views/**`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `agent_core/**`
- `graph-engine/**`
- `epistemos-shadow/**`
- generated Swift/header bindings
- generated libraries
- Xcode project files
- entitlements
- DerivedData, `.xcresult`
- stash, branch, staging, commit, or destructive git operations

## Implementation Contract

- No production wiring. Do not emit AgentEvents from live chat, Omega, hooks,
  approvals, or tool execution in this slice.
- EventStore remains the durable source for the Swift AgentEvent table.
- AgentEvent JSON must be deterministic enough for tests: sorted keys through
  EventStore's existing payload encoder.
- Reads must be bounded and insertion/sequence ordered.
- Failed or denied tool events are persisted as events, not as thrown errors
  from the EventStore API.
- Do not project AgentEvents into OpLog, GraphEvent, UI, Halo, Theater, or
  ReplayBundle yet.

## Tests

Red/green focused Swift command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

Expected tests:

- AgentEvent JSON round-trips lower-snake-case tool provenance.
- EventStore creates `agent_events`.
- EventStore saves and loads an AgentEvent by id.
- EventStore returns bounded run events ordered by sequence then recorded time.
- Saving the same event id is idempotent and updates the stored JSON.

Guardrails:

```bash
git diff --check -- Epistemos/Models/AgentProvenanceEvent.swift Epistemos/State/EventStore.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
git diff --no-index --check /dev/null Epistemos/Models/AgentProvenanceEvent.swift
/usr/bin/grep -nE "ChatCoordinator|HookRegistry|ReasoningLoopService|Omega|RustOpLogFFIClient|oplog_|GraphEvent|ReplayBundle" Epistemos/Models/AgentProvenanceEvent.swift Epistemos/State/EventStore.swift
git diff --name-only -- Epistemos/App/ChatCoordinator.swift Epistemos/Engine/HookRegistry.swift Epistemos/Omega Epistemos/Views Epistemos/Engine/MutationOpLogProjector.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Engine/RustOpLogFFIClient.swift agent_core graph-engine epistemos-shadow build-rust
```

## Acceptance

- Wired: Swift has a typed AgentEvent model and EventStore persistence/readback.
- Reachable: focused tests can save, load, and list tool provenance events.
- Visible: tests prove JSON shape, ordering, and idempotency.

## Rollback

Delete `AgentProvenanceEvent.swift`, remove the EventStore table/API additions,
remove the focused tests, and remove PR1 docs. MutationEnvelope, OpLog
projection, diagnostics, and replay snapshot work remain intact.

## Stop Triggers

- Any need to touch production chat, Omega, hook, approval, UI, Rust, graph, or
  generated files.
- Any need to emit AgentEvents from live tool calls in this slice.
- Any need to project AgentEvents into OpLog or GraphEvent immediately.
- EventStore schema migration requires destructive migration or table rewrite.

## Closeout

Status: **closed with focused verification**.

Implementation note:

- Generated UniFFI Swift already declares an unrelated `AgentEvent` struct in
  `build-rust/swift-bindings/epistemos_core.swift`.
- This slice therefore uses `AgentProvenanceEvent` as the durable Swift model
  name while preserving the canonical EventStore API names:
  `saveAgentEvent(_:)`, `loadAgentEvent(eventID:)`, and
  `agentEvents(runID:limit:)`.
- The durable table remains the canonical `agent_events` table.

Verification:

- Red log: `/tmp/epistemos-agent-event-pr1-red-20260501.log`.
  Expected failure: the first test shape collided with the generated UniFFI
  `AgentEvent` type and proved the missing durable provenance surface.
- Green log: `/tmp/epistemos-agent-event-pr1-green-20260501.log`.
  Result: `21` tests in `EventStore Cognitive Tables` passed.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`. The inherited
  SwiftLint plugin messages for `CodeEditTextView` and `CodeEditSourceEditor`
  remain existing build noise after test success.

Guardrails:

- `git diff --check` emitted no findings for the approved tracked files and
  docs.
- Direct whitespace audit of the new `AgentProvenanceEvent.swift` file emitted
  no findings.
- Scope grep showed only preexisting `oplog_seq` references in `EventStore`.
- Protected-path dirty files are inherited branch drift outside this PR1 slice;
  PR1 only touched `EventStore`, the new durable model, focused tests, and
  docs.
