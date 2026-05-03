---
role: aggregator
source_fleet: codex-own
slice: bridge-no-double-count-source-guards-pr44
date: 2026-05-03
detectives_consumed:
  - detectives/bridge-no-double-count-source-guards.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals: []
tier: Both
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
usefulness_reason: Confirms the post-PR43 bridge boundary is executable as a focused test-only slice.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6 anchors Hermes/Pro tunnel and runtime bridge work.
- `AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md` §3.2 says the next AgentEvent expansion lane is Omega + LocalAgent, not Bridge.
- `AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md` §4 says transport/parser/router/tier bridge direct instrumentation would double-count or race existing event ownership.

## Recommended slice shape

Create `EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift` only. Do not edit production bridge files. The suite should assert the four no-instrument surfaces do not directly instantiate `AgentToolProvenanceRecorder` or call `recordToolEvent`.

## Failure-proof guardrails

- grep: `rg -n "AgentToolProvenanceRecorder\\(|recordToolEvent\\(" Epistemos/Bridge/ChunkedMCPFraming.swift Epistemos/Bridge/CoTStreamInterceptor.swift Epistemos/Bridge/StreamingDelegate.swift Epistemos/Bridge/ToolTierBridge.swift`
- log: `Test Suite 'AgentEvent Bridge No-Double-Count Source Guards' passed`
- test: `EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests`
