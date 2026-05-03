---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-overseer-history-reset-pr13
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-overseer-history-reset.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [detectives/sovereign-gate-overseer-history-reset.md, current-code]
    resolution: Canon's one-gate Settings footer rule wins; migrate the visible reset footer while leaving programmatic clear() callers alone.
drift_signals:
  - Overseer Settings reset-history footer clears audit history without the shared Sovereign Gate.
tier: Core
sovereign_gate_touchpoint: migrating-existing
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: true
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts an exact audit-history clearing footer into a narrow PR13 gate.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` requires no duplicate `LocalAuthentication` outside `SovereignGate.swift`.
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138` includes Settings footers as confirmation surfaces.
- `OverseerSettingsView.swift:96` is the only user-facing reset-history call in this view; `OverseerAuditState.clear()` itself must stay usable for non-UI lifecycle cleanup.

## Recommended slice shape
Add `OverseerSettingsSovereignGate.Target.historyReset`, change the footer button to call `requestHistoryResetAuthorization()`, and call `audit.clear()` only after `.allowed`. Add focused `SovereignGateTests` mapping/source guards and keep the production view free of `LocalAuthentication` symbols.

## Failure-proof guardrails
- grep: `rg -n 'LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy' Epistemos/Views/Settings/OverseerSettingsView.swift`
- log: `/tmp/epistemos-sovereign-gate-overseer-history-pr13-green-20260502.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/SovereignGateTests`
