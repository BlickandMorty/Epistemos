# Deliberation - Phase4 interact AgentEvent provenance PR41

## Classification

- Tier: Pro/Research bridge surface.
- Canon anchors: `MASTER_RESEARCH_INDEX_2026_05_02.md` §2, §6, §13.
- Workcard match: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 - AgentEvent Tool Provenance.
- Sovereign Gate touchpoint: none.
- Killer-feature dependency: none.

## Proposal

Instrument `Phase4Bridge.interact(actionJson:)` with bounded AgentEvent lifecycle provenance while preserving existing ComputerUseBridge/AXorcist dispatch behavior and returned payload shape. The bridge should record requested, started, completed, and failed tool events using sanitized action/route/result classes only.

Allowed source writes:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/Phase4BridgeInteractAgentEventTests.swift`
- This slice's docs under `docs/fusion/**`

Forbidden writes:
- `Phase4Bridge.startScreenWatch(watchJson:)` behavior beyond shared helpers needed for this file.
- Core/MAS tool allowlists.
- MCP/Hermes routing.
- UI, graph, graph-engine, generated bindings, project files, packages, build scripts.
- Sovereign Gate or LocalAuthentication surfaces.

## Acceptance

- Successful ComputerUseBridge-routed interaction records sanitized requested, started, and completed AgentEvents.
- Successful AX press interaction records sanitized requested, started, and completed AgentEvents.
- Invalid JSON and unsupported actions record bounded requested/failed AgentEvents while preserving existing error responses.
- AgentEvent arguments/results/errors do not persist raw action JSON, typed text, target labels, bundle ids, raw coordinates, raw returned payloads, user paths, localized descriptions, or arbitrary error strings.
- The existing returned interaction payloads remain unchanged for callers.
- Focused test log prints `** TEST SUCCEEDED **`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 - Substrate spine and architectural invariants.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6 - Hermes / Pro Tunnels / MCP.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §13 - Privacy / Telemetry / Security.

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none. This is one remaining broader runtime bridge-provenance surface identified by the parallel coverage map.

## Failure-proof guardrails (post-merge)

- grep: `recordPhase4InteractEvent|phase4\\.interact|action_class|route_class|target_scope|value_length_bucket`
- forbidden grep: `argumentsJSON: actionJson|argumentsJSON: payload|resultJSON: response|resultJSON: jsonString|errorMessage: errorJson|errorMessage: errorMessage as\\? String`
- log: `✔ Test "Phase4 interact source never stores raw action JSON target values or raw results" passed`
- test: `Phase4BridgeInteractAgentEventTests`

## Fleet evidence packet

- `docs/fusion/fleet/phase4-interact-agent-event-pr41/aggregator.md`
- `docs/fusion/fleet/phase4-interact-agent-event-pr41/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a high-risk Phase4 action provenance gap without changing surfaced capability policy.
