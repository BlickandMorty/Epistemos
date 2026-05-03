---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-custom-tool-delete-pr10
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-custom-tool-delete.md
web_consumed: []
claude_side_fleet_consumed:
  - none
canon_gaps_opened: []
conflicts: []
drift_signals:
  - Custom tool delete is a remaining destructive confirmation surface not yet gated.
tier: Core
sovereign_gate_touchpoint: migrating-existing
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: true
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
usefulness_reason: Converts the detective finding into a narrow, testable Sovereign Gate migration.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` requires a single Sovereign Gate entrypoint for native authorization.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` marks PR1-PR9 closed and leaves additional existing confirmation migrations open.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 permits future confirmation-surface migrations only when the exact surface and tests are named.
- `AgentControlSettingsView.swift` has a permanent custom-tool delete button that currently bypasses the shared gate.

## Recommended Slice Shape

Add `AgentControlSettingsDeletionSovereignGate` for custom-tool delete requirements and reasons, route the existing custom-tool delete button through an async authorization method, and keep the existing delete implementation untouched behind `.allowed`.

## Failure-Proof Guardrails

- grep: `enum AgentControlSettingsDeletionSovereignGate`
- grep: `requestCustomToolDeleteAuthorization`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` outside `Epistemos/Sovereign/SovereignGate.swift`
- log: `Agent control custom tool deletes map to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`
