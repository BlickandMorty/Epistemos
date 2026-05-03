# Deliberation - ComputerUseBridge AgentEvent provenance PR39

## Classification

- Tier: Pro/Research bridge surface.
- Canon anchors: `MASTER_RESEARCH_INDEX_2026_05_02.md` §2, §6, §13.
- Workcard match: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 - AgentEvent Tool Provenance.
- Sovereign Gate touchpoint: none.
- Killer-feature dependency: none.

## Proposal

Instrument `ComputerUseBridge.execute(actionJSON:)` with bounded AgentEvent lifecycle provenance while preserving the existing computer-use execution behavior. The bridge should record requested, started, completed, and failed tool events using sanitized action/result classes only.

Allowed source writes:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ComputerUseBridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ComputerUseBridgeAgentEventTests.swift`
- This slice's docs under `docs/fusion/**`

Forbidden writes:
- Core/MAS tool allowlists.
- MCP/Hermes routing.
- UI, graph, graph-engine, generated bindings, project files, packages, build scripts.
- Sovereign Gate or LocalAuthentication surfaces.

## Acceptance

- Successful trusted actions record sanitized requested, started, and completed AgentEvents.
- Accessibility-denied calls record sanitized requested and failed AgentEvents before executing the action.
- Invalid JSON records a bounded failed AgentEvent and preserves the existing error response.
- Unknown actions record bounded `computer.unknown` provenance without raw action strings.
- AgentEvent arguments/results/errors do not persist raw screenshot payloads, accessibility trees, typed text, raw action JSON, app names, exact coordinates, raw results, paths, or localized descriptions.
- Focused test log prints `** TEST SUCCEEDED **`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 - Substrate spine and architectural invariants.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6 - Hermes / Pro Tunnels / MCP.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §13 - Privacy / Telemetry / Security.

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none. This is one remaining broader runtime bridge-provenance surface identified by the parallel coverage map.

## Failure-proof guardrails (post-merge)

- grep: `recordComputerActionEvent|computer\\.type|coordinate_bucket|text_length_bucket`
- forbidden grep: `argumentsJSON: actionJSON|argumentsJSON: input|resultJSON: result,|errorMessage: errorResult|localizedDescription`
- log: `✔ Test "ComputerUseBridge provenance source never stores raw action payloads or raw results" passed`
- test: `ComputerUseBridgeAgentEventTests`

## Fleet evidence packet

- `docs/fusion/fleet/computer-use-bridge-agent-event-pr39/aggregator.md`
- `docs/fusion/fleet/computer-use-bridge-agent-event-pr39/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a high-risk computer-use bridge provenance gap without changing surfaced capability policy.
