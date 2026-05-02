# AgentEvent Rust Stream PR3 Deliberation - 2026-05-01

## Gate

Approved action: **wire best-effort AgentEvent/tool provenance emission for
ChatCoordinator Rust `AgentStreamEvent` consumers**.

PR1 closed durable `agent_events` EventStore persistence. PR2 closed live
PipelineService local tool-loop emission. PR3 extends the same typed event
spine to the Rust agent stream paths already consumed by `ChatCoordinator`,
without changing Rust execution, permission decisions, stream UI behavior,
message persistence, routing, tool allowlists, or generated bindings.

## Repo Evidence

- `StreamingDelegate` emits typed Rust stream events with tool identity and
  inputs:
  - `AgentStreamEvent.toolStarted(id:name:inputJson:)`
  - `AgentStreamEvent.toolCompleted(id:result:isError:)`
  - `AgentStreamEvent.permissionRequired(AgentPermissionRequest)`
- `AgentPermissionRequest` carries `id`, `toolName`, `inputJson`, and
  `riskLevel`, so permission request/decision provenance can be recorded
  honestly when the Rust stream exposes the permission event.
- `ChatCoordinator.runCommandCenterRustAgentPath(...)` creates a per-run
  `sessionId`, consumes the Rust stream, records command-center diagnostics,
  and already computes `durationMs` for completed tools.
- `ChatCoordinator.runRustAgentPath(...)` creates a per-run `sessionId`,
  consumes the same Rust stream, tracks `toolInputsByID`, resolves permission
  through stored authority/prompting, and records chat UI tool activity.
- `AgentToolProvenanceRecorder` already assigns per-run sequences, rejects
  blank run/tool identity, and persists `AgentProvenanceEvent` rows through
  an injected best-effort sink.

## Decision

Instrument both ChatCoordinator Rust stream consumers:

- `runCommandCenterRustAgentPath(...)`
- `runRustAgentPath(...)`

Map stream events to AgentEvent provenance as follows:

- `.permissionRequired(request)`:
  - record `.toolCallRequested` / `.requested`
  - after the existing approval decision is computed, record
    `.toolCallApproved` / `.approved` or `.toolCallDenied` / `.denied`
  - use `request.id` as the approval/tool call identity because the Rust
    permission callback provides no separate tool-use id at that point
- `.toolStarted(id, name, inputJson)`:
  - record `.toolCallStarted` / `.started`
  - store the input and start time for later completion provenance
- `.toolCompleted(id, result, isError)`:
  - record `.toolCallCompleted` / `.completed` or `.toolCallFailed` /
    `.failed`
  - include result JSON, duration when known, and a bounded error message for
    failures

Do not synthesize requested/approved events from `.toolStarted` alone when no
permission event was emitted. That would make read-only or internally approved
tool calls appear to have an approval surface the stream never exposed.

## Files Approved

- `Epistemos/App/ChatCoordinator.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `docs/fusion/deliberation/agent_event_rust_stream_pr3_deliberation_2026_05_01.md`
- future closeout docs under `docs/fusion/**`

## Files Forbidden

- `Epistemos/Bridge/StreamingDelegate.swift`
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `Epistemos/Models/EngineTypes.swift`
- `Epistemos/Engine/PipelineService.swift`
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

- Additive instrumentation only. Do not alter stream consumption, approval
  decisions, delegate resolution, chat UI state, diagnostics, verified-vault
  read enforcement, message persistence, tool result JSON, or route selection.
- Use the existing `sessionId` as `runID`.
- Keep `traceID` nil because these paths do not expose a canonical trace id
  today.
- Use `AgentProvenanceActor.agent(id:modelID:)` with distinct stable ids for
  command-center and managed-chat Rust paths.
- Use a small private helper in `ChatCoordinator` to avoid duplicating recorder
  call shape, metadata normalization, duration calculation, and failure
  truncation.
- Keep EventStore persistence best-effort and non-fatal.
- Do not project AgentEvents into OpLog, GraphEvent, UI, Halo, Theater, hooks,
  Omega, or ReplayBundle in this slice.
- Do not edit Rust stream bindings or generated files.

## Tests

Red/green focused Swift command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/RuntimeValidationTests test
```

Expected source guard:

- `ChatCoordinator` creates `AgentToolProvenanceRecorder` for both Rust stream
  consumers.
- `ChatCoordinator` records permission requested/approved/denied events from
  `.permissionRequired`.
- `ChatCoordinator` records started/completed/failed events from
  `.toolStarted` and `.toolCompleted`.
- `ChatCoordinator` uses `sessionId` as `runID`.
- `ChatCoordinator` does not import OpLog, GraphEvent, ReplayBundle, hooks, or
  Omega for this PR3 slice.

Guardrails:

```bash
git diff --check -- Epistemos/App/ChatCoordinator.swift EpistemosTests/RuntimeValidationTests.swift docs/fusion
/usr/bin/grep -nE "MutationOpLog|RustOpLogFFIClient|GraphEvent|ReplayBundle|HookRegistry" Epistemos/App/ChatCoordinator.swift
git diff --name-only -- Epistemos/Bridge/StreamingDelegate.swift Epistemos/Engine/AgentToolProvenanceRecorder.swift Epistemos/Models/AgentProvenanceEvent.swift Epistemos/Models/EngineTypes.swift Epistemos/Engine/PipelineService.swift Epistemos/Omega Epistemos/Views agent_core graph-engine epistemos-shadow build-rust
```

## Acceptance

- Wired: both ChatCoordinator Rust stream consumers persist typed AgentEvents
  for exposed tool lifecycle events.
- Reachable: the existing stream switch cases call the recorder during real
  Rust agent session consumption.
- Visible: focused runtime guard proves the wiring and forbidden-boundary
  constraints.

## Rollback

Remove the ChatCoordinator recorder helper/calls, remove the PR3 source guard,
and delete this deliberation/closeout update. PR1 durable persistence and PR2
PipelineService live emission remain intact.

## Stop Triggers

- Any need to change `AgentStreamEvent`, `StreamingDelegate`, generated
  bindings, Rust `agent_core`, or tool registry behavior.
- Any need to alter permission approval semantics or UI prompting.
- Any recorder/EventStore failure would need to block a tool call.
- Any need to touch protected editor, graph, Omega, hook, OpLog, or generated
  surfaces.

## Closeout

Status: **closed after focused red/green verification**.

- Red: `/tmp/epistemos-agent-event-pr3-red-20260501-r2.log` failed on the new
  `ChatCoordinator Rust stream persists live AgentEvent tool provenance` source
  guard before implementation.
- Green: `/tmp/epistemos-agent-event-pr3-green-20260501-r1.log` passed
  `RuntimeValidationTests` with `253` tests in `1` suite.
- Overseer re-verification:
  `/tmp/epistemos-agent-event-pr3-runtimevalidation-green-20260501.log` passed
  `RuntimeValidationTests` with `253` tests in `1` suite.
- Xcode reported `** TEST SUCCEEDED **`; inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` remain package-plugin/lint noise.
- The implementation stayed additive: it records exposed permission and tool
  lifecycle events from the existing Rust stream switch cases and keeps approval
  semantics, UI flow, diagnostics, verified-vault-read enforcement, Rust
  bindings, OpLog, GraphEvent, Omega, hooks, and generated files out of scope.
- Kimi read-only audit attempt:
  `/tmp/epistemos-agent-event-pr3-kimi-audit-20260501-r1.log` produced no
  output after several minutes and was terminated.
- Any temptation to claim full AgentEvent runtime coverage beyond
  ChatCoordinator Rust stream tool lifecycle events.
