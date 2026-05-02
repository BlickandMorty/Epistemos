# Relay Channel AgentEvent PR13 Deliberation - 2026-05-02

## Tier

Core / Pro shared Swift runtime provenance. No Core/Pro symbol split, provider
routing, approval policy, UI, Rust, generated binding, graph, or EventStore
schema changes.

## Goal

Instrument the remote relay channel HTTP client path so relay
send/fetch/list/audit calls emit bounded AgentProvenanceEvent lifecycle rows
without persisting relay secrets, message bodies, endpoint URLs, sender
identity values, relay response bodies, or HTTP error response bodies.

## Local Research First

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §6 Hermes / Pro tunnels /
  MCP and §8 streaming/provenance route relay/external execution through a
  bounded gateway.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` lists AgentEvent
  PR1-PR12 as closed and says remaining broader runtime AgentEvent coverage
  requires exact file gates.
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
  requires narrow AgentEvent slices to preserve routing, UI, approval, graph,
  Rust, generated bindings, and schema.

## Red Gate

Added relay adapter tests that inject a custom `URLSession` and a test
`AgentToolProvenanceRecorder`.

First red run:

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ControlPlaneSurfaceTests test`
- Expected failure: `RemoteRelayChannelAdapter(...)` did not yet accept
  `urlSession` or `agentProvenanceRecorder`.
- Evidence: `/tmp/epistemos-relay-channel-agent-event-pr13-red-20260502.log`.

Second red run:

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ControlPlaneSurfaceTests test`
- Expected failure: HTTP non-2xx relay response bodies were copied into the
  AgentEvent error message.
- Evidence:
  `/tmp/epistemos-relay-channel-agent-event-pr13-http-red-20260502.log`.

## Implementation

- `RelayChannelClient.execute(...)` now accepts injectable `URLSession` and
  optional `AgentToolProvenanceRecorder`.
- `RemoteRelayChannelAdapter` stores both dependencies and passes them to relay
  send/fetch/list/audit calls.
- Relay HTTP calls record requested, started, and completed/failed AgentEvents
  with `relay-channel-...` run ids, `relay-channel-<channel>` actor metadata,
  `relay-channel-tool:1` tool ids, source/surface/channel/route/method
  metadata, bounded result/error payloads, and sanitized argument/result JSON.
- Arguments record shape and sizes only: channel, route, method, query count,
  payload presence, payload byte count, credential presence, and sender
  identity presence.
- Results record only HTTP status code and response byte count.
- Relay HTTP errors preserve status code but redact response body text.

## Explicit Non-Goals

- No channel adapter parser changes.
- No relay request construction changes.
- No native fallback semantic changes.
- No DriverChannelToolExecutor wrapper changes.
- No LocalAgentLoop, PipelineService, ChatCoordinator, Omega reasoning, graph,
  Rust, generated binding, approval, UI, provider routing, or EventStore schema
  changes.

## Green Gate

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ControlPlaneSurfaceTests test`
- Expected result: `Control Plane Surfaces` passes 23 Swift Testing tests.
- Evidence: `/tmp/epistemos-relay-channel-agent-event-pr13-green-20260502.log`.
- Known non-blocker: vendored CodeEdit SwiftLint package-plugin failures may
  print after `TEST SUCCEEDED`.

## Acceptance

- Successful relay calls emit requested, started, and completed AgentEvents.
- Failed relay calls emit requested, started, and failed AgentEvents.
- Tests prove message text, relay endpoint host, relay credential, sender
  identity value, relay response body text, and HTTP error body text are not
  persisted in provenance.
