# DriverChannel AgentEvent PR12 Deliberation - 2026-05-02

## Slice

Instrument only the `DriverChannelToolExecutor.execute(...)` wrapper used by
channel driver send/fetch/list/audit calls so channel tool execution emits
bounded AgentEvents.

## Gate Decision

Approved as a narrow AgentEvent provenance slice.

This gate deliberately avoids channel adapter behavior, contact routing,
fallback semantics, local agent execution, provider routing, graph surfaces,
Rust, generated bindings, and EventStore schema changes. The executor wrapper
is a clean chokepoint because it already owns the call into `executeToolCall`
and already converts unsuccessful tool results into `DriverChannelError`.

## Allowed Write Set

- `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`
- `EpistemosTests/ControlPlaneSurfaceTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/deliberation/driver_channel_agent_event_pr12_deliberation_2026_05_02.md`

## Forbidden Changes

- Do not change `resolveContact(...)` fallback behavior.
- Do not change `recordMessage(...)` best-effort audit behavior.
- Do not change channel adapter payload construction.
- Do not change `LocalAgentLoop`, PipelineService, ChatCoordinator, Omega
  reasoning, provider routing, approval flow, UI, graph code, Rust code,
  generated bindings, or EventStore schema.
- Do not project AgentEvents into OpLog, GraphEvent, Halo, Theater, or replay
  bundles in this slice.

## Implementation Notes

- Add `DriverChannelToolExecutionResult` and a `DriverChannelToolRunner` test
  seam around the existing FFI call.
- Keep existing call sites source-compatible with default parameters.
- Emit requested, started, and completed/failed events with:
  - run id prefix `driver-channel-<channel>-`
  - actor id `driver-channel-<channel>`
  - tool call id `driver-channel-tool:1`
  - metadata `source=driver_channel_tool_executor`
  - metadata `surface=driver_channel`
  - metadata `channel=<channel>`
  - metadata `tier=<tier>`
- Bound result/error payloads before recording.

## Evidence

- Red log:
  `/tmp/epistemos-driver-channel-agent-event-pr12-red-20260502.log`
- Red failure:
  `DriverChannelToolExecutionResult` was missing and the executor had no
  `toolRunner` / `agentProvenanceRecorder` seam.
- Green log:
  `/tmp/epistemos-driver-channel-agent-event-pr12-green-20260502.log`
- Green result:
  `ControlPlaneSurfaceTests` passed 20 tests, including success and failure
  provenance cases for the driver-channel executor.
- Known non-blocker:
  Xcode printed vendored CodeEdit SwiftLint package-plugin failures after
  `TEST SUCCEEDED`.

## Residual Open Work

- Driver-channel paths beyond the executor wrapper require a separate
  deliberation gate.
- Contact routing/fallback provenance requires a separate gate because those
  paths intentionally treat unsuccessful tool results differently than the
  executor wrapper.
- Any AgentEvent projection into GraphEvent, OpLog, replay, Halo, or Theater
  remains out of scope until a projection-specific gate exists.
