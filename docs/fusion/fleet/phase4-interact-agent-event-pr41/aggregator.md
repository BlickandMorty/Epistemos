---
role: aggregator
source_fleet: codex-own
slice: phase4-interact-agent-event-pr41
date: 2026-05-03
detectives_consumed:
  - detectives/phase4-interact-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: none
    sources: []
    resolution: none
drift_signals:
  - none
tier: Pro
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts a Phase4 action bridge into an auditable bounded-provenance surface.
---

## Reconciled findings

- `Phase4Bridge.interact(actionJson:)` is a Pro/Research action bridge surface, not a Core/MAS surfaced capability expansion.
- AgentEvent payloads must never persist raw action JSON, typed text, target labels, bundle ids, raw coordinates, raw action/result payloads, user paths, localized descriptions, or arbitrary error strings.
- The code should preserve returned interaction payloads to the caller while recording only sanitized provenance.
- Tests should prove successful computer-route dispatch, successful AX press dispatch, invalid/unsupported failures, and source-level raw-payload guards.

## Recommended slice shape

Add injectable computer/AX executor seams to `Phase4Bridge` for tests, record sanitized requested/started/completed-or-failed AgentEvents around existing `interact` dispatch, and add a focused Swift Testing suite. Do not change `perceive`, `screen_watch`, Core/App Store tool policy, MCP/Hermes routing, UI, graph, EventStore schema, or actual ComputerUse/AXorcist behavior.

## Failure-proof guardrails

- grep: `recordPhase4InteractEvent|phase4\\.interact|action_class|route_class|target_scope|value_length_bucket`
- log: `✔ Test "Phase4 interact source never stores raw action JSON target values or raw results" passed`
- test: `Phase4BridgeInteractAgentEventTests`
