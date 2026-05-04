# Codex/Kimi Oversight Round 047 - 2026-05-01

## Slice

AgentEvent Live Tool Provenance PR2.

## Question

Where should the first live AgentEvent tool lifecycle emission be wired without
touching protected or behavior-sensitive surfaces?

## Kimi Advisory

Raw advisory log:

- `/tmp/epistemos-agent-event-pr2-kimi-advisory-20260501.log`

Kimi recommended using `PipelineService.observedToolExecutor(...)` rather than
ChatCoordinator or Rust-stream paths for PR2 because it is the narrowest live
tool-execution chokepoint, already has approval and result context, and can be
tested with a stubbed executor plus real EventStore persistence.

## Codex Decision

Accepted Kimi's route and pivoted PR2 away from the earlier Rust-stream idea.

Implemented:

- `AgentToolProvenanceRecorder` as a best-effort EventStore recorder.
- PipelineService observed-tool lifecycle emission for requested,
  approved/denied, started, and completed/failed rows.
- Focused EventStore, PipelineService, and runtime guard tests.

Not implemented in this round:

- ChatCoordinator Rust stream event emission.
- Omega/hook provenance emission.
- AgentEvent projection into OpLog, GraphEvent, Halo, Theater, or ReplayBundle.
- Trace id propagation at PipelineService, because the chokepoint does not yet
  expose a canonical trace id.

## Evidence

- Red:
  `/tmp/epistemos-agent-event-pr2-red-20260501.log`
- Final green:
  `/tmp/epistemos-agent-event-pr2-combined-green-20260501-r3.log`
- Result: `304` tests in `3` suites passed.
- Xcode reported `** TEST SUCCEEDED **`; inherited SwiftLint package-plugin
  noise for CodeEdit packages appeared after the success marker.

## Guardrails

- No ChatCoordinator edit.
- No Omega edit.
- No hook edit.
- No graph/editor protected-path edit.
- No generated binding, generated library, project, entitlement, branch, stash,
  stage, or commit operation.
- Broad branch diff still contains earlier approved OpLog projection/replay
  changes; PR2 did not modify those projection/runtime surfaces.

## Next Recommended Gate

Open a fresh AgentEvent PR3 gate for exactly one of:

- ChatCoordinator/Rust-stream lifecycle coverage.
- Omega/hook lifecycle coverage.
- AgentEvent-to-GraphEvent or audit projection.

Do not reopen PipelineService observed-tool instrumentation unless a regression
is found.
