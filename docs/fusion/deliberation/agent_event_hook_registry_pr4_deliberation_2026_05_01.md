# AgentEvent HookRegistry PR4 Deliberation - 2026-05-01

## Gate

Approved action: add bounded, best-effort AgentEvent emission for
`HookRegistry` hook lifecycle APIs.

PR1 closed durable `agent_events` EventStore persistence. PR2 closed
PipelineService observed-tool emission. PR3 closed ChatCoordinator Rust-stream
emission. PR4 may instrument the existing Swift `HookRegistry` actor only. It
must not claim full runtime hook coverage because the registry has no current
production call sites.

## Repo Evidence

- `Epistemos/Engine/HookRegistry.swift` already owns the hook lifecycle API:
  registration plus `beforePromptBuild`, `beforeToolCall`, `afterToolCall`, and
  `afterSessionEnd` firing.
- `AgentHook` methods are non-throwing async calls, so PR4 can record
  registered, fired, and completed outcomes. It cannot honestly record thrown
  hook failures without changing the protocol.
- `AgentProvenanceEvent` supports tool-less events through a nil `tool` field
  and lower-snake-case JSON.
- `EventStore.saveAgentEvent(_:)` is nonisolated and best-effort friendly.
- `AgentToolProvenanceRecorder` proves the per-run sequence and best-effort
  persistence pattern, but PR4 should not collapse hook lifecycle events into
  tool-call provenance.
- Claude read-only scout recommended HookRegistry as the lowest-risk next
  AgentEvent coverage slice because it avoids protected editor/graph/Rust
  paths and extends an already proven provenance pattern.

## Decision

Add:

- Hook lifecycle event kinds:
  - `hook_registered`
  - `hook_fired`
  - `hook_completed`
- Best-effort HookRegistry event persistence with per-run sequence numbers.
- API-compatible optional `runID` parameters on hook fire methods so future
  production callers can bind hook events to real agent/session runs.
- Synthetic hook-registry run ids only when the caller has no run id yet, such
  as registration.
- Focused behavior tests using an injected persistence sink.
- Runtime source guard proving the instrumentation stays inside HookRegistry
  and does not re-enter PR2/PR3 or protected surfaces.

## Files Approved

- `Epistemos/Engine/HookRegistry.swift`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `docs/fusion/deliberation/agent_event_hook_registry_pr4_deliberation_2026_05_01.md`
- future closeout updates under `docs/fusion/**`

## Files Forbidden

- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- `Epistemos/Omega/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `epistemos-shadow/**`
- `agent_core/**`
- generated Swift/header bindings, generated libraries, Xcode project files,
  entitlements, DerivedData, `.xcresult`, stashes, branch operations, or
  destructive git operations.

## Implementation Contract

- Additive instrumentation only. Do not change hook ordering, cancellation,
  prompt/tool/result/session semantics, or log behavior.
- Persistence is best effort and non-fatal.
- Every persisted hook event must have a non-empty run id, event id, hook id,
  hook point, and source metadata.
- Use tool-less `AgentProvenanceEvent` rows. Do not encode hooks as fake tools.
- Preserve lower-snake-case JSON and the `AgentProvenanceEvent` schema version.
- Do not project hook AgentEvents into OpLog, GraphEvent, Halo, Theater,
  ReplayBundle, UI, Settings, or repair/audit UX in this slice.
- Do not claim HookRegistry is production-mounted until a separate runtime gate
  wires real call sites.

## Tests

Red/green focused Swift commands:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/RuntimeValidationTests test
```

Expected focused assertions:

- Hook registration persists `hook_registered` with source, hook id, and hook
  point metadata.
- Firing a hook persists `hook_fired` then `hook_completed` in per-run sequence
  order.
- A before-tool hook that cancels the tool call records a completed outcome of
  `cancelled` without changing cancellation semantics.
- Runtime source guard proves HookRegistry emits hook AgentEvents without
  touching PipelineService, ChatCoordinator, Omega, OpLog, GraphEvent,
  ReplayBundle, editor, graph, Rust, or generated bindings.

Guardrails:

```bash
git diff --check -- Epistemos/Engine/HookRegistry.swift Epistemos/Models/AgentProvenanceEvent.swift EpistemosTests/CognitiveSubstrateTests.swift EpistemosTests/RuntimeValidationTests.swift docs/fusion
/usr/bin/grep -nE "MutationOpLog|RustOpLogFFIClient|GraphEvent|ReplayBundle|ProseEditor|MetalGraphView|HologramController|ChatCoordinator|PipelineService|Omega" Epistemos/Engine/HookRegistry.swift
git diff --name-only -- Epistemos/App/ChatCoordinator.swift Epistemos/Engine/PipelineService.swift Epistemos/Omega Epistemos/Views/Notes Epistemos/Views/Graph Epistemos/Graph graph-engine epistemos-shadow agent_core build-rust
```

## Acceptance

- Wired: HookRegistry lifecycle APIs persist typed hook AgentEvents.
- Reachable: tests call the existing registry APIs and observe persisted rows.
- Visible: focused tests prove event kinds, sequence order, metadata, and
  cancellation outcome.

## Closeout

Implementation closed:

- Added `hook_registered`, `hook_fired`, and `hook_completed` event kinds.
- Added injected-clock/injected-sink HookRegistry persistence so tests can
  capture rows without touching the production EventStore singleton.
- Registered hooks now persist `hook_registered` rows.
- Hook fire APIs now accept optional `runID` parameters and persist
  `hook_fired` and `hook_completed` rows around each existing hook invocation.
- Hook events are tool-less `AgentProvenanceEvent` rows with
  `source=hook_registry`, `hook_id`, `hook_point`, and completion `outcome`.
- `beforeToolCall` cancellation still returns `nil`, and now records completion
  outcome `cancelled`.

Evidence:

- Red compile/test log:
  `/tmp/epistemos-agent-event-hook-pr4-red-20260501.log`.
- First PR4 green run exposed a test-harness isolation issue, fixed by making
  the injected capture sink nonisolated.
- EventStoreSchemaTests green:
  `/tmp/epistemos-agent-event-hook-pr4-green-eventstore-20260501.log`.
  31 Swift Testing tests passed, including both HookRegistry lifecycle tests.
- RuntimeValidationTests green:
  `/tmp/epistemos-agent-event-hook-pr4-green-runtime-20260501.log`.
  254 Swift Testing tests passed, including the HookRegistry forbidden-boundary
  source guard.
- Both green xcodebuild runs ended with `** TEST SUCCEEDED **`. They still
  reported inherited SwiftLint package-plugin failures for CodeEditSourceEditor
  and CodeEditTextView after success; these are unrelated to PR4 and match the
  known inherited build noise from earlier substrate slices.

Boundary result:

- No ChatCoordinator, PipelineService, Omega, protected editor, protected graph,
  Rust, generated binding, OpLog, GraphEvent, ReplayBundle, Settings, or UI
  files were required for this slice.
- This closes HookRegistry API-level lifecycle emission only. Production hook
  call-site mounting remains a future runtime gate.

## Rollback

Remove the hook event kind cases, HookRegistry persistence helpers/calls, PR4
tests, and this deliberation document. PR1/PR2/PR3 AgentEvent work remains
intact.

## Stop Triggers

- Any need to change `AgentHook` protocol semantics.
- Any need to touch ChatCoordinator, PipelineService, Omega, protected editor,
  graph, Rust, generated bindings, or UI.
- Any EventStore persistence failure would need to block hook execution.
- Any need to fabricate tool-call provenance for hook events.
- Any claim that this is full production runtime coverage rather than
  HookRegistry API-level emission.
