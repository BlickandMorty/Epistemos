# ReasoningLoop AgentEvent Tool Provenance PR7 Deliberation - 2026-05-02

## Slice

Card 7 AgentEvent Tool Provenance PR7 instruments Omega ReasoningLoop internal
tool calls.

## Gate

Add additive AgentEvent persistence around existing internal ReasoningLoop
`vault_search` / `graph_search` calls: requested, started, and
completed/failed. Use run ids prefixed `reasoning-loop-`, actor
`omega-reasoning-loop`, tool call ids shaped `reasoning-tool:<round>:<sequence>`,
and metadata for `source=omega_reasoning_loop`, `round_index`, and
`tool_sequence`.

## Boundaries

No approval behavior, HookRegistry, ChatCoordinator, PipelineService, provider
routing, UI, graph, Rust, generated-binding, OpLog, GraphEvent, Halo, Theater,
or EventStore schema changes. Unknown tools may emit failed AgentEvents.
Unavailable vault/graph backends for known tools remain completed tool calls
with result text because the existing execution semantics already returned
honest text rather than throwing.

## Files

- `Epistemos/Omega/Inference/ReasoningLoopService.swift`
- `EpistemosTests/ReasoningLoopAgentEventTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/deliberation/reasoning_loop_agent_event_pr7_deliberation_2026_05_02.md`

## Evidence

- Red guard: `/tmp/epistemos-reasoning-loop-agent-event-pr7-red-guard-20260502.log`
- Green focused Swift Testing: `/tmp/epistemos-reasoning-loop-agent-event-pr7-green-20260502.log`
- Note: the focused behavior test passed with `TEST SUCCEEDED`; Xcode still
  printed known SwiftLint package-plugin noise after success.

## Approval

Approved for this exact PR7 only.
