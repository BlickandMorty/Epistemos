# LocalAgentLoop AgentEvent PR11 Deliberation - 2026-05-02

## Slice

Record AgentEvent tool provenance for `LocalAgentLoop` parsed local tool calls.

## Decision

Approved as PR11 for `LocalAgentLoop` tool execution provenance only.

This slice is additive instrumentation. It gives the local Hermes-style loop a
durable AgentEvent trail without changing model routing, tool parsing, tool
execution, repair semantics, approvals, UI, provider calls, HookRegistry,
PipelineService, ChatCoordinator, Omega, graph, Rust, generated bindings, or
EventStore schema.

## Allowed Write Set

- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/deliberation/local_agent_loop_agent_event_pr11_deliberation_2026_05_02.md`

## Forbidden Write Set

- Model routing or provider selection.
- Tool parsing, canonicalization, repair, or execution semantics.
- Approval policy or UI.
- HookRegistry, PipelineService, ChatCoordinator, Omega, graph, Rust,
  generated bindings, EventStore schema, OpLog, GraphEvent, Halo, Theater, or
  ReplayBundle.
- Xcode project files, entitlements, generated artifacts, DerivedData,
  `.xcresult`, staging, commits, stashes, or branch operations outside the
  final exact commit for this slice.

## Implementation Contract

- Each parsed local tool call gets one non-empty `local-agent-...` run id and a
  stable per-run `local-agent-tool:N` call id.
- Emit requested, started, and completed/failed events around the existing
  `toolExecutor` call.
- Store `local-agent-loop` actor metadata plus `source=local_agent_loop` and
  `surface=local_agent`.
- Persist bounded result JSON on completion and bounded error payloads on
  failure.
- Lazily create the default recorder on MainActor so non-MainActor tests and
  direct loop construction do not inherit MainActor-init friction.

## Evidence

Red:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalAgentLoopTests test 2>&1 | tee /tmp/epistemos-local-agent-agent-event-pr11-red-20260502.log
```

Result: failed as expected because `LocalAgentLoop` did not accept
`agentProvenanceRecorder`.

Green:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalAgentLoopTests test 2>&1 | tee /tmp/epistemos-local-agent-agent-event-pr11-green-20260502.log
```

Result: Swift Testing passed 36 tests in `Local Agent Loop`, including the new
successful and failed provenance tests. Xcode still printed the known vendored
CodeEdit SwiftLint package-plugin failures after `TEST SUCCEEDED`.

## Closure

PR11 is closed for LocalAgentLoop parsed tool-call provenance only. Remaining
AgentEvent work must open a new gate naming the exact runtime path, tests, and
non-claims before touching additional surfaces.
