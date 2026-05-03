---
role: aggregator
source_fleet: codex-own
slice: phase4-perceive-agent-event-pr40
date: 2026-05-03
detectives_consumed:
  - detectives/phase4-perceive-agent-event.md
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
usefulness_reason: Converts a Screen2AX perception bridge into an auditable bounded-provenance surface.
---

## Reconciled findings

- `Phase4Bridge.perceive(appName:depth:)` is a Pro/Research perception bridge surface, not a Core/MAS surfaced capability expansion.
- AgentEvent payloads must never persist raw AX tree JSON, OCR text, raw app names, raw depth strings, raw perception payloads, user paths, or arbitrary error strings.
- The code should preserve returned perception payloads to the caller while recording only sanitized provenance.
- Tests should prove successful perception, unavailable perception failure, and source-level raw-payload guards.

## Recommended slice shape

Add an injectable perception-provider seam to `Phase4Bridge` for tests, record sanitized requested/started/completed-or-failed AgentEvents around the existing `perceive` call, and add a focused Swift Testing suite. Do not change `interact`, `screen_watch`, Core/App Store tool policy, MCP/Hermes routing, UI, graph, EventStore schema, or actual Screen2AX behavior.

## Failure-proof guardrails

- grep: `recordPhase4PerceiveEvent|phase4\\.perceive|depth_class|app_scope|interactive_count|ocr_count`
- log: `✔ Test "Phase4 perceive source never stores AX tree OCR text app names or raw results" passed`
- test: `Phase4BridgePerceiveAgentEventTests`
