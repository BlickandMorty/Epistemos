---
role: aggregator
source_fleet: codex-own
slice: phase7-nightbrain-trigger-provenance-pr36
date: 2026-05-03
detectives_consumed:
  - detectives/phase7-nightbrain-trigger-provenance.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened: []
conflicts: []
drift_signals: []
tier: Core
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
usefulness_reason: Authorizes a narrow bridge provenance patch with no real NightBrain job execution in tests.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §4 names NightBrain as Layer 7 of the reflective loop; `Phase7Bridge.swift` is the current live dispatch seam.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 allows remaining runtime AgentEvent coverage when run id/tool id are non-empty and behavior is unchanged.
- Unsupported raw request fields are untrusted. The brief must require sanitized `argumentsJSON`, nil raw failure `resultJSON`, and bounded `failure_class`.

## Recommended slice shape
Instrument `Phase7Bridge.triggerNightbrainJob` with requested/started/completed/failed AgentEvents, using canonical job enum values only for supported jobs and bounded priority/failure classes. Tests should cover unsupported and bootstrap-unavailable paths through injection and must not run NightBrain jobs.

## Failure-proof guardrails
- grep: `recordNightBrainTriggerEvent|phase7-nightbrain-trigger|failure_class`
- log: `Test run with 4 tests in 1 suite passed`
- test: `EpistemosTests/Phase7BridgeAgentEventTests`
