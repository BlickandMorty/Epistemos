# Deliberation - Phase4 perceive AgentEvent provenance PR40

## Classification

- Tier: Pro/Research bridge surface.
- Canon anchors: `MASTER_RESEARCH_INDEX_2026_05_02.md` §2, §6, §13.
- Workcard match: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 - AgentEvent Tool Provenance.
- Sovereign Gate touchpoint: none.
- Killer-feature dependency: none.

## Proposal

Instrument `Phase4Bridge.perceive(appName:depth:)` with bounded AgentEvent lifecycle provenance while preserving existing Screen2AX perception behavior and returned payload shape. The bridge should record requested, started, completed, and failed tool events using sanitized depth/app-scope/result classes only.

Allowed source writes:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/Phase4BridgePerceiveAgentEventTests.swift`
- This slice's docs under `docs/fusion/**`

Forbidden writes:
- `Phase4Bridge.interact(actionJson:)` behavior beyond shared helpers needed for this file.
- `Phase4Bridge.startScreenWatch(watchJson:)` behavior beyond shared helpers needed for this file.
- Core/MAS tool allowlists.
- MCP/Hermes routing.
- UI, graph, graph-engine, generated bindings, project files, packages, build scripts.
- Sovereign Gate or LocalAuthentication surfaces.

## Acceptance

- Successful perception records sanitized requested, started, and completed AgentEvents.
- Screen2AX unavailable failure records sanitized requested, started, and failed AgentEvents while preserving the existing error response.
- AgentEvent arguments/results/errors do not persist raw AX tree JSON, OCR text, raw app names, raw depth strings, raw perception payloads, user paths, localized descriptions, or arbitrary error strings.
- The existing returned perception payload remains unchanged for callers, including raw AX JSON in the returned response.
- Focused test log prints `** TEST SUCCEEDED **`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 - Substrate spine and architectural invariants.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6 - Hermes / Pro Tunnels / MCP.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §13 - Privacy / Telemetry / Security.

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none. This is one remaining broader runtime bridge-provenance surface identified by the parallel coverage map.

## Failure-proof guardrails (post-merge)

- grep: `recordPhase4PerceiveEvent|phase4\\.perceive|depth_class|app_scope|interactive_count|ocr_count`
- forbidden grep: `argumentsJSON: appName|argumentsJSON: depth|resultJSON: payload|errorMessage: errorJson|ax_tree_json`
- log: `✔ Test "Phase4 perceive source never stores AX tree OCR text app names or raw results" passed`
- test: `Phase4BridgePerceiveAgentEventTests`

## Fleet evidence packet

- `docs/fusion/fleet/phase4-perceive-agent-event-pr40/aggregator.md`
- `docs/fusion/fleet/phase4-perceive-agent-event-pr40/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a high-risk Screen2AX perception provenance gap without changing surfaced capability policy.
