# Deliberation - ClarifyPromptBridge AgentEvent provenance PR43

## Classification

- Tier: Pro/Research bridge surface.
- Canon anchors: `MASTER_RESEARCH_INDEX_2026_05_02.md` §2, §6, §13.
- Workcard match: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 - AgentEvent Tool Provenance.
- Sovereign Gate touchpoint: none.
- Killer-feature dependency: none.

## Proposal

Instrument `ClarifyPromptBridge.ask(questionJson:)` with bounded AgentEvent lifecycle provenance while preserving the existing Rust clarify callback, native NSAlert presentation, and returned response JSON. The bridge should record requested, started, and completed tool events using sanitized prompt/result classes only.

Allowed source writes:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ClarifyPromptBridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift`
- This slice's docs under `docs/fusion/**`

Forbidden writes:
- Core/MAS tool allowlists.
- MCP/Hermes routing.
- Sovereign Gate or LocalAuthentication surfaces.
- UI view surfaces outside the existing NSAlert bridge.
- Graph, graph-engine, EventStore schema, generated bindings, project files, packages, build scripts, subprocess surfaces, ANE/private API surfaces, or cloud/provider policy.

## Acceptance

- Free-form clarify answers record sanitized requested, started, and completed AgentEvents.
- Choice clarify answers record selected index without persisting raw choices.
- Invalid JSON and cancelled answers stay bounded and still return valid cancellation JSON.
- AgentEvent arguments/results/errors do not persist raw question JSON, questions, choices, answers, filesystem paths, prompt text, or arbitrary errors.
- Existing returned clarify response JSON remains unchanged for callers.
- Focused test log prints `** TEST SUCCEEDED **`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 - Substrate spine and architectural invariants.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6 - Hermes / Pro Tunnels / MCP.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §13 - Privacy / Telemetry / Security.

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none. This is a narrow runtime provenance bridge selected after Phase4 bridge coverage closed.

## Failure-proof guardrails (post-merge)

- grep: `recordClarifyPromptEvent|clarify\\.ask|input_mode|question_scope|response_length_bucket|choice_count_bucket`
- forbidden grep: `argumentsJSON: questionJson|argumentsJSON: parsed\\.question|resultJSON: response|resultJSON: answer\\.response|errorMessage: error`
- log: `✔ Test "Clarify source never stores raw question JSON answers or choices" passed`
- test: `ClarifyPromptBridgeAgentEventTests`

## Fleet evidence packet

- `docs/fusion/fleet/clarify-prompt-bridge-agent-event-pr43/aggregator.md`
- `docs/fusion/fleet/clarify-prompt-bridge-agent-event-pr43/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a small local clarify-callback provenance gap without changing prompt UX or returned answer JSON.
