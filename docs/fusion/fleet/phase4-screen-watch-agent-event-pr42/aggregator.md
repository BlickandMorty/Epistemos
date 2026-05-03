---
role: aggregator
source_fleet: codex-own
slice: phase4-screen-watch-agent-event-pr42
date: 2026-05-03
detectives_consumed:
  - detectives/phase4-screen-watch-agent-event.md
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
usefulness_reason: Converts the remaining Phase4 watch loop into an auditable bounded-provenance surface.
---

## Reconciled findings

- `Phase4Bridge.startScreenWatch(watchJson:)` is a Pro/Research bridge surface, not a Core/MAS surfaced capability expansion.
- AgentEvent payloads must never persist raw watch JSON, file paths, target strings, bundle ids, raw AX payloads, localized descriptions, arbitrary error strings, or per-poll state.
- The code should preserve returned watch payloads to callers while recording only sanitized lifecycle provenance.
- Tests should prove timeout completion, file-exists completion, invalid JSON failure, and source-level raw-payload/path guards.

## Recommended slice shape

Add injectable watch executor/provider/sleeper seams to `Phase4Bridge` for tests, record sanitized requested/started/completed-or-failed AgentEvents around existing `startScreenWatch` behavior, and add a focused Swift Testing suite. Do not change `perceive`, `interact`, Computer Use execution, Core/App Store tool policy, MCP/Hermes routing, UI, graph, EventStore schema, or actual AXorcist/filesystem watch semantics.

## Failure-proof guardrails

- grep: `recordPhase4ScreenWatchEvent|phase4\\.screen_watch|mode_class|timeout_bucket|poll_interval_bucket|target_scope`
- log: `✔ Test "Phase4 screen watch source never stores raw watch JSON paths" passed`
- test: `Phase4BridgeScreenWatchAgentEventTests`
