---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-authority-reset-pr12
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-authority-reset.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [detectives/sovereign-gate-authority-reset.md, current-code]
    resolution: Canon says Settings footers/capability prompts route through Sovereign Gate; current code has an ungated batch authority reset/preset path, so current code should be migrated.
drift_signals:
  - Authority reset/default-preset buttons mutate agent authority policy without the shared Sovereign Gate.
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
usefulness_reason: Converts a discovered policy-reset drift into one exact, testable Core migration.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` anchors this as a Sovereign Gate slice, with `SovereignGate.swift` as the only `LocalAuthentication` owner.
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138` brings Settings footers and permission gates into the one-gate rule.
- `AuthoritySettingsView.swift:98` and `AuthoritySettingsView.swift:165` are the exact existing surfaces; they can be migrated without touching `SovereignGate.swift`, Rust, generated transport, graph, editor, or Xcode project files.

## Recommended slice shape
Add `AuthoritySettingsSovereignGate` as a tiny Settings-surface mapping for `resetToDefaults` and `quickSetup(name:)`, route footer reset and Quick Setup buttons through an async shared-gate helper, then call the existing reset/apply logic only after `.allowed`. Tests should fail first on the missing mapping/route, then pass with focused `SovereignGateTests`.

## Failure-proof guardrails
- grep: `rg -n 'LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy' Epistemos/Views/Settings/AuthoritySettingsView.swift`
- log: `/tmp/epistemos-sovereign-gate-authority-reset-pr12-green-20260502.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/SovereignGateTests`
