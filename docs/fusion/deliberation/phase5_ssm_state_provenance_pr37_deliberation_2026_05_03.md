# Deliberation - phase5-ssm-state-provenance-pr37

## Slice

Add sanitized AgentEvent provenance to `Phase5Bridge.manageSsmState(actionJson:)`.

## Tier

Core. No Pro/Research surfaces.

## Allowed files

- `Epistemos/Bridge/Phase5Bridge.swift`
- `EpistemosTests/Phase5BridgeAgentEventTests.swift`
- Round 74 docs/fleet/oversight/state/workcard/guard files

## Forbidden files and subsystems

- `Epistemos/Views/**`, `Epistemos/Graph/**`, `graph-engine/**`, `agent_core/**`, `omega-mcp/**`, `epistemos-core/**`, generated bindings, `Epistemos.xcodeproj`
- `SSMStateService` save/load/cache internals
- `Phase5Bridge.generateConstrained(prompt:grammarJson:)`
- Hermes/MCP, subprocess, browser/computer-use, Sovereign/LocalAuthentication, ANE/private API, Z3/Kani/Lean/Kissat/cvc5

## Plan

1. Add a failing Swift Testing suite for sanitized Phase5 SSM AgentEvents.
2. Add a test seam to inject the SSM service provider and recorder.
3. Record requested/started/completed/failed events for `manageSsmState` only.
4. Persist only bounded action class, model scope, count/removed/kept/bytes, success/result, duration, and bounded failure class.
5. Preserve existing external JSON responses and SSM behavior.

## Acceptance

- Unsupported `save`/`load` record requested and failed events without raw `actionJson`, model id, paths, or cache hints.
- Bootstrap/service-unavailable records requested and failed events with `bootstrap_unavailable`.
- `total_size` records requested, started, and completed events with sanitized result JSON.
- Focused `Phase5BridgeAgentEventTests` pass.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §19

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: AgentEvent/tool provenance broader runtime coverage
- Deviation: none; this is a newly gated exact runtime file and test slice.

## Failure-proof guardrails (post-merge)

- grep: `recordSsmStateEvent|phase5-ssm-state|ssm_state_manage|action_class|model_scope|failure_class`
- log: `✔ Test "Phase5 SSM total size records sanitized requested started and completed events" passed`
- test: `Phase5BridgeAgentEventTests`

## Fleet evidence packet

- `docs/fusion/fleet/phase5-ssm-state-provenance-pr37/aggregator.md`
- `docs/fusion/fleet/phase5-ssm-state-provenance-pr37/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a specific open runtime AgentEvent bridge without widening Phase5 behavior.
