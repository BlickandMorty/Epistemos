---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-settings-workspace-delete-pr15
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-settings-workspace-delete.md
web_consumed: []
claude_side_fleet_consumed:
  - none
canon_gaps_opened: []
conflicts: []
drift_signals:
  - Settings saved-workspace delete is a Core destructive UI action not yet routed through SovereignGate.
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
usefulness_reason: Converts a named ungated destructive Settings action into a gated slice.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` and `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2` require one Sovereign Gate entrypoint for destructive UI actions.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1760` allows exact future confirmation-surface migrations with focused tests.
- `Epistemos/Views/Settings/SettingsView.swift:645` is an exact Core surface: the button is destructive and its accessibility hint says "Permanently removes this saved workspace."
- `EpistemosTests/SovereignGateTests.swift:685` has the existing Settings source-guard pattern to reuse.

## Recommended slice shape

Implement a Core-only additive migration in `SettingsView.swift` and `SovereignGateTests.swift`: add a typed `savedWorkspace(name:)` target, route the trash button through `requestSavedWorkspaceDeleteAuthorization(_:)`, and prove with focused tests that direct `deleteWorkspace(workspace)` calls moved behind `SovereignGate`.

## Failure-proof guardrails

- grep: `savedWorkspace\\(name:`
- grep: `requestSavedWorkspaceDeleteAuthorization\\(`
- log: `Settings saved workspace delete maps to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`
