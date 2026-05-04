# AgentEvent Live Tool Provenance PR2 Deliberation - 2026-05-01

## Gate

Approved action: **wire the first live AgentEvent/tool provenance path from
`PipelineService.observedToolExecutor(...)` into EventStore**.

PR1 closed the durable foundation: `AgentProvenanceEvent`, the
`agent_events` EventStore table, and bounded save/load/list APIs. This PR2
slice makes that foundation live for the local PipelineService tool loop only.
It does not change tool approval semantics, route selection, tool results,
streaming UI state, Rust agent streams, Omega, hooks, OpLog, GraphEvent, Halo,
Theater, or generated bindings.

## Repo Evidence

- `PipelineService.run(...)` already creates a stable per-run `UUID`.
- `PipelineService.runToolLoop(...)` already calls
  `observedToolExecutor(...)`.
- `PipelineService.observedToolExecutor(...)` is the narrowest testable
  execution chokepoint: it sees tool request, approval/denial, actual executor
  invocation, result, failure status, and duration with a stubbed executor.
- `PipelineToolEvent.started` currently drives UI before approval; PR2 should
  not reinterpret or rename that surface. AgentEvent emission is separate
  durable provenance, not a replacement for UI events.
- PR1 EventStore APIs are available and persistence failures are non-fatal.

## Kimi Advisory

Kimi reviewed a copied `/tmp` context read-only and recommended this narrower
PipelineService route over ChatCoordinator Rust-stream instrumentation because
it can be tested without launching a model or relying on source guards alone.

Advisory log:
`/tmp/epistemos-agent-event-pr2-kimi-advisory-20260501.log`

## Decision

Add:

- A small `AgentToolProvenanceRecorder` that owns per-run sequence numbers and
  persists typed `AgentProvenanceEvent` rows through an injected sink.
- Additive `PipelineService` instrumentation:
  - Before approval, persist `tool_call_requested`.
  - If a required approval is denied, persist `tool_call_denied` and return the
    existing denied tool result without executing the base executor.
  - If approval is granted or no human approval is required, persist
    `tool_call_approved`.
  - Immediately before calling the base executor, persist `tool_call_started`.
  - After the base executor returns, persist `tool_call_completed` or
    `tool_call_failed`.
- Focused tests for recorder sequence/order/event shape.
- Focused local tool-executor tests proving success, denial, and failure
  produce durable AgentEvents in order.

## Files Approved

- `Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- `Epistemos/Engine/PipelineService.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/PipelineServiceTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `docs/fusion/deliberation/agent_event_live_tool_provenance_pr2_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Models/EngineTypes.swift`
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

- Additive instrumentation only. Do not alter approval decisions, tool
  execution, tool result JSON, UI event semantics, streaming behavior, or route
  selection.
- EventStore persistence must be best-effort and non-fatal.
- Every live AgentEvent must have a non-empty run id and tool call id.
- Trace id remains nil in PR2 because PipelineService does not expose a
  canonical trace id today.
- Preserve PR1 lower-snake-case JSON and `AgentProvenanceEvent` naming.
- Do not project AgentEvents into OpLog, GraphEvent, UI, Halo, Theater, or
  ReplayBundle in this slice.
- Do not instrument ChatCoordinator Rust stream loops yet; they require a later
  gate because they are harder to exercise as real runtime tests.

## Tests

Red/green focused Swift commands:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/PipelineServiceTests test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/RuntimeValidationTests test
```

Expected tests:

- Recorder persists requested/approved/started/completed events with increasing
  per-run sequence numbers.
- Recorder refuses blank run id, tool call id, or tool name.
- Local observed tool executor persists requested/approved/started/completed for
  successful execution.
- Local observed tool executor persists requested/denied without executing the
  base executor when approval is denied.
- Local observed tool executor persists failed when the base executor returns an
  error result.
- Runtime source guard proves PipelineService uses the recorder and does not
  introduce OpLog, GraphEvent, ReplayBundle, UI, ChatCoordinator, or hook
  projection.

Guardrails:

```bash
git diff --check -- Epistemos/Engine/AgentToolProvenanceRecorder.swift Epistemos/Engine/PipelineService.swift EpistemosTests/CognitiveSubstrateTests.swift EpistemosTests/PipelineServiceTests.swift EpistemosTests/RuntimeValidationTests.swift docs/fusion
git diff --no-index --check /dev/null Epistemos/Engine/AgentToolProvenanceRecorder.swift
/usr/bin/grep -nE "MutationOpLog|RustOpLogFFIClient|GraphEvent|ReplayBundle|HookRegistry|Omega|ProseEditor|MetalGraphView|HologramController|ChatCoordinator" Epistemos/Engine/AgentToolProvenanceRecorder.swift Epistemos/Engine/PipelineService.swift
git diff --name-only -- Epistemos/App/ChatCoordinator.swift Epistemos/Models/EngineTypes.swift Epistemos/Engine/HookRegistry.swift Epistemos/Omega Epistemos/Views Epistemos/Engine/MutationOpLogProjector.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Engine/RustOpLogFFIClient.swift agent_core graph-engine epistemos-shadow build-rust
```

## Acceptance

- Wired: local PipelineService tool execution persists typed AgentEvents.
- Reachable: `observedToolExecutor(...)` writes events during real executor
  invocation.
- Visible: focused tests prove success, denial, and failure event order.

## Closeout - 2026-05-01

Status: **closed**.

Implementation:

- Added `AgentToolProvenanceRecorder`, a best-effort, main-actor recorder that
  rejects blank run ids, tool call ids, and tool names, assigns per-run
  sequence numbers, and persists `AgentProvenanceEvent` rows through
  `EventStore.saveAgentEvent(_:)`.
- Instrumented `PipelineService.observedToolExecutor(...)` as the live PR2
  chokepoint. It now records requested, approved/denied, started, and
  completed/failed tool lifecycle events without changing approval decisions,
  tool execution, tool result JSON, UI event semantics, streaming behavior, or
  routing.
- Kept `traceID` nil for live PipelineService PR2 events because no canonical
  trace id is exposed at that boundary yet.
- Did not touch ChatCoordinator, Omega, hooks, graph/editor code, generated
  bindings, OpLog projection code, GraphEvent, Halo, Theater, or ReplayBundle.

Evidence:

- Red log:
  `/tmp/epistemos-agent-event-pr2-red-20260501.log`
- Kimi advisory:
  `/tmp/epistemos-agent-event-pr2-kimi-advisory-20260501.log`
- Final focused green log:
  `/tmp/epistemos-agent-event-pr2-combined-green-20260501-r3.log`
- Result: `304` tests in `3` suites passed:
  `EventStoreSchemaTests`, `PipelineServiceTests`, and
  `RuntimeValidationTests`.
- Xcode reported `** TEST SUCCEEDED **`; inherited SwiftLint package-plugin
  command failures for `CodeEditTextView` and `CodeEditSourceEditor` still
  appear after the success marker and remain non-blocking plugin/lint noise for
  this slice.

Guardrails:

- `git diff --check` on the PR2 allowed files and `docs/fusion` passed.
- Whitespace/CRLF audit on PR2 code/test files passed.
- Runtime code forbidden-symbol scan found only an existing PipelineService
  doc-comment mention of `ChatCoordinator`; `AgentToolProvenanceRecorder` and
  the PR2 PipelineService changes do not introduce OpLog, GraphEvent,
  ReplayBundle, hook, editor, graph, or generated-binding dependencies.
- Broad diff scans still show earlier approved OpLog projection/replay work in
  the dirty branch; those are not part of this PR2 live-emission slice.

## Rollback

Delete `AgentToolProvenanceRecorder.swift`, remove the PipelineService recorder
calls, remove PR2 tests, and remove PR2 docs. PR1 EventStore persistence remains
intact.

## Stop Triggers

- Any need to change `PipelineToolEvent` semantics or UI tool preview behavior.
- Any need to touch ChatCoordinator, Rust streams, Omega, hooks, generated
  bindings, graph, or editor code.
- Any approval/control-flow behavior changes are required.
- Any EventStore persistence failure would need to block a tool run.
- Any need to project AgentEvents into OpLog, GraphEvent, UI, Halo, Theater, or
  ReplayBundle immediately.
