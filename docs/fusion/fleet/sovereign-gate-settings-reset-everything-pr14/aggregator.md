---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-settings-reset-everything-pr14
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-settings-reset-everything.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [detectives/sovereign-gate-settings-reset-everything.md, current-code]
    resolution: Migrate the current destructive alert action to shared Sovereign Gate; do not stage unrelated dirty diagnostics work in the same file.
drift_signals:
  - Settings reset-everything alert calls resetAllData without the shared Sovereign Gate.
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
usefulness_reason: Converts the broad destructive Settings reset path into a narrow PR14 gate.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` requires no duplicate `LocalAuthentication` outside `SovereignGate.swift`.
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138` includes dangerous-action dialogs and Settings footers as one-gate surfaces.
- `SettingsView.swift` is dirty before PR14; exact staging is mandatory so only the reset-everything hunk lands.

## Recommended slice shape
Add `SettingsViewDestructiveActionSovereignGate.Target.resetEverything`, route the alert's destructive "Reset" button through `requestResetEverythingAuthorization()`, and call `AppBootstrap.shared?.resetAllData()` only after `.allowed`. Add source guards in `SovereignGateTests` and partial-stage only the PR14 hunk from `SettingsView.swift`.

## Failure-proof guardrails
- grep: `rg -n 'LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy' Epistemos/Views/Settings/SettingsView.swift`
- log: `/tmp/epistemos-sovereign-gate-settings-reset-pr14-green-20260502.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/SovereignGateTests`
