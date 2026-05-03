---
role: aggregator
source_fleet: codex-own
slice: phase5-ssm-state-provenance-pr37
date: 2026-05-03
detectives_consumed:
  - detectives/phase5-ssm-state-provenance.md
web_consumed: []
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
usefulness_reason: Converts an open runtime provenance gap into a bounded Phase5 bridge slice.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9 keeps SSM/MLX work under local-model substrate authority; this slice only observes Phase5 FFI state management.
- Current code confirms `save` and `load` are intentionally rejected by `Phase5Bridge` because live MLX cache access is not available through agent FFI.
- AgentEvent persistence must not include raw `actionJson`, model identifiers, state file URLs, filesystem paths, localized errors, or cache contents.

## Recommended slice shape

Add an injectable SSM service provider and `AgentToolProvenanceRecorder` to `Phase5Bridge`, then record sanitized `phase5-ssm-state` events around `manageSsmState` only. Leave constrained decoding, MLX cache save/load, service semantics, and StreamingDelegate untouched.

## Failure-proof guardrails

- grep: `recordSsmStateEvent|phase5-ssm-state|ssm_state_manage|action_class|model_scope|failure_class`
- log: `✔ Test "Phase5 SSM total size records sanitized requested started and completed events" passed`
- test: `Phase5BridgeAgentEventTests`
