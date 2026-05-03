# Deliberation - Phase4 screen_watch AgentEvent provenance PR42

## Classification

- Tier: Pro/Research bridge surface.
- Canon anchors: `MASTER_RESEARCH_INDEX_2026_05_02.md` §2, §6, §13.
- Workcard match: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 - AgentEvent Tool Provenance.
- Sovereign Gate touchpoint: none.
- Killer-feature dependency: none.

## Proposal

Instrument `Phase4Bridge.startScreenWatch(watchJson:)` with bounded AgentEvent lifecycle provenance while preserving existing AX/file/timeout watch behavior and returned payload shape. The bridge should record requested, started, completed, and failed tool events using sanitized mode/scope/bucket/result classes only.

Allowed source writes:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/Phase4BridgeScreenWatchAgentEventTests.swift`
- This slice's docs under `docs/fusion/**`

Forbidden writes:
- `Phase4Bridge.perceive(appName:depth:)` and `Phase4Bridge.interact(actionJson:)` behavior beyond shared helpers needed for this file.
- Core/MAS tool allowlists.
- MCP/Hermes routing.
- UI, graph, graph-engine, generated bindings, project files, packages, build scripts.
- Sovereign Gate or LocalAuthentication surfaces.
- Per-poll/per-frame AgentEvent emission.

## Acceptance

- Timeout-mode screen watch records sanitized requested, started, and completed AgentEvents.
- File-exists screen watch records sanitized requested, started, and completed AgentEvents without persisting raw paths.
- Invalid JSON records bounded requested/failed AgentEvents while preserving the existing error response.
- AgentEvent arguments/results/errors do not persist raw watch JSON, file paths, target strings, bundle ids, raw AX payloads, localized descriptions, arbitrary error strings, or per-poll state.
- The existing returned watch payloads remain unchanged for callers.
- Focused test log prints `** TEST SUCCEEDED **`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 - Substrate spine and architectural invariants.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6 - Hermes / Pro Tunnels / MCP.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §13 - Privacy / Telemetry / Security.

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none. This is the final Phase4 bridge function identified by the runtime coverage map after PR40/PR41.

## Failure-proof guardrails (post-merge)

- grep: `recordPhase4ScreenWatchEvent|phase4\\.screen_watch|mode_class|timeout_bucket|poll_interval_bucket|target_scope`
- forbidden grep: `argumentsJSON: watchJson|argumentsJSON: payload|resultJSON: response|resultJSON: jsonString|errorMessage: errorJson|localizedDescription`
- log: `✔ Test "Phase4 screen watch source never stores raw watch JSON paths" passed`
- test: `Phase4BridgeScreenWatchAgentEventTests`

## Fleet evidence packet

- `docs/fusion/fleet/phase4-screen-watch-agent-event-pr42/aggregator.md`
- `docs/fusion/fleet/phase4-screen-watch-agent-event-pr42/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes the remaining Phase4 watch-loop provenance gap without changing surfaced capability policy or watch semantics.
