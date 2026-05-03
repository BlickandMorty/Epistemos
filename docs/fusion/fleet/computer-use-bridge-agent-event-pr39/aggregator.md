---
role: aggregator
source_fleet: codex-own
slice: computer-use-bridge-agent-event-pr39
date: 2026-05-03
detectives_consumed:
  - detectives/computer-use-bridge-agent-event.md
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
usefulness_reason: Converts a high-risk uninstrumented bridge into an auditable bounded-provenance surface.
---

## Reconciled findings

- `ComputerUseBridge` is a Pro/Research bridge surface, not a Core/MAS capability expansion; PR39 must not alter tool-surface allowlists.
- AgentEvent payloads must never persist screenshot base64, accessibility tree text, typed text, raw action JSON, raw app names, exact coordinates, or raw error strings.
- The code should preserve returned computer-use results to the caller while recording only sanitized provenance.
- Tests should prove successful trusted actions, accessibility denial, invalid JSON, unsupported actions, and source-level raw-payload guards.

## Recommended slice shape

Add an injectable permission/executor seam to `ComputerUseBridge` for tests, record sanitized requested/started/completed-or-failed AgentEvents around the existing action execution, and add a focused Swift Testing suite. Do not change Core/App Store tool policy, MCP/Hermes routing, UI, graph, EventStore schema, or actual computer-use behavior.

## Failure-proof guardrails

- grep: `recordComputerActionEvent|computer\\.type|coordinate_bucket|text_length_bucket`
- log: `✔ Test "ComputerUseBridge provenance source never stores raw action payloads or raw results" passed`
- test: `ComputerUseBridgeAgentEventTests`
