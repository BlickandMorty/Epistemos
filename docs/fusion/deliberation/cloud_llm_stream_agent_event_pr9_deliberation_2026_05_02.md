# CloudLLM Stream AgentEvent Tool Provenance PR9 Deliberation - 2026-05-02

## Slice

Card 7 AgentEvent Tool Provenance PR9 instruments the direct
`CloudLLMClient.stream(...)` cloud-provider boundary.

## Gate

Add additive AgentEvent persistence around existing cloud model streaming:
requested, started, and completed/failed. Use run ids prefixed `cloud-llm-`,
actor `cloud-llm-client`, tool name `cloud_model.stream`, and tool call id
`cloud-llm-stream:1`.

The event payload is intentionally sanitized. Arguments record provider, model,
operating mode, max token cap, prompt byte count, system-prompt presence, and
Hermes route class only. Results record chunk count and output byte count only.
Prompts, system prompts, API keys, request bodies, URLs, and streamed model
text must not be persisted as AgentEvent payloads.

## Boundaries

No provider routing, credential resolution semantics, request body
construction, SSE parsing, reasoning/usage sinks, non-streaming generation,
structured-output native provider paths, Hermes subprocess adapter, MCP bridge,
CLI delegation, approval behavior, HookRegistry, ChatCoordinator,
PipelineService, Omega, graph, Rust, generated-binding, OpLog, GraphEvent,
Halo, Theater, UI, or EventStore schema changes.

This PR records that direct cloud streaming is a `hermesGateway` class surface
according to `HermesGatewayPolicy`, but it does not introduce a Hermes runtime
adapter or force a subprocess hop.

## Files

- `Epistemos/Engine/LLMService.swift`
- `EpistemosTests/CloudLLMAgentEventTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/deliberation/cloud_llm_stream_agent_event_pr9_deliberation_2026_05_02.md`

## Evidence

- Red guard: `/tmp/epistemos-cloud-llm-stream-agent-event-pr9-red-20260502.log`
- Green focused Swift Testing: `/tmp/epistemos-cloud-llm-stream-agent-event-pr9-green-20260502.log`
- Note: the focused behavior tests passed with `TEST SUCCEEDED`; Xcode still
  printed known SwiftLint package-plugin noise after success.

## Approval

Approved for this exact PR9 only.
