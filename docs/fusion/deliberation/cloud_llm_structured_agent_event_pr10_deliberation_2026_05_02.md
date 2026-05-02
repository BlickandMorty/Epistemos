# CloudLLM Structured AgentEvent Tool Provenance PR10 Deliberation - 2026-05-02

## Slice

Card 7 AgentEvent Tool Provenance PR10 instruments
`CloudLLMClient.generateStructured(...)`, the provider-native structured cloud
generation chokepoint in `Epistemos/Engine/LLMService.swift`.

This closes only structured-output provenance for the existing cloud client. It
does not add a Hermes subprocess adapter, MCP bridge, CLI bridge, approval
surface, provider route change, or broader runtime AgentEvent sweep.

## Gate

`CloudLLMClient.generateStructured(...)` must persist requested, started, and
completed/failed `AgentProvenanceEvent` rows around provider-native structured
generation.

Required identity:

- Run ids start with `cloud-llm-`.
- Actor id is `cloud-llm-client`.
- Tool name is `cloud_model.generate_structured`.
- Tool call id is `cloud-llm-generate-structured:1`.
- Route metadata is `hermesGateway`.
- Schema metadata includes the schema name and strict flag.

## Sanitization

Persisted argument JSON may include provider/model/mode, max token count,
prompt byte count, system-prompt presence, schema name, schema strictness, and
route only.

Persisted result JSON may include raw JSON byte count and raw JSON length only.

Forbidden from AgentEvent payloads:

- Prompt body.
- System prompt body.
- API keys or credential identifiers.
- Request URL.
- Request body.
- Schema body/properties.
- Generated answer text.
- Raw structured JSON contents.

## Boundaries

Approved write set:

- `Epistemos/Engine/LLMService.swift`
- `EpistemosTests/CloudLLMAgentEventTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/deliberation/cloud_llm_structured_agent_event_pr10_deliberation_2026_05_02.md`

Do not touch provider routing, OpenAI/Anthropic request construction semantics,
URLSession transport, Hermes subprocesses, MCP, CLI, approval UI,
ChatCoordinator, PipelineService, Omega, graph, Rust, generated bindings, or
EventStore schema.

## Evidence

Test-first red:

- `/tmp/epistemos-cloud-llm-structured-agent-event-pr10-red-20260502.log`
- The two new structured-output provenance tests failed because
  `CloudLLMClient.generateStructured(...)` emitted no AgentEvents.

Green:

- `/tmp/epistemos-cloud-llm-structured-agent-event-pr10-green-20260502.log`
- Swift Testing passed all 6 tests in `CloudLLMAgentEventTests`, including the
  two new structured-output cases.
- Xcode still printed the known vendored CodeEdit SwiftLint package-plugin
  failures after `TEST SUCCEEDED`; the focused behavior tests passed.

## Decision

Approve PR10 exactly as scoped. The structured-output cloud path now participates
in the same durable AgentEvent provenance spine as non-streaming generation and
direct streaming, while keeping Hermes as the architectural cloud-gateway class
and keeping provider-native request behavior unchanged.
