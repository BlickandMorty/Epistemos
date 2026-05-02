---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-model-vault-delete-pr9
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-model-vault-delete.md
web_consumed: []
claude_side_fleet_consumed:
  - ../round-30-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
canon_gaps_opened: []
conflicts: []
drift_signals: []
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
  plus_one: 2
  zero: 0
  minus_one: 1
usefulness: +1
usefulness_reason: Converts the selection packet into an implementation-ready exact Sovereign Gate migration.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` anchors Sovereign Gate as a Core killer feature.
- Card 9 allows named confirmation-surface migrations, and PR5-PR8 establish the pattern for destructive delete/reset/disconnect flows.
- `ModelVaultsSidebarSection.swift` is a clean exact write target and currently deletes model-vault files/folders after a local alert confirmation without shared Sovereign Gate authorization.

## Recommended Slice Shape

Add a small `ModelVaultDeletionSovereignGate` mapper, route the existing alert delete button through `AppBootstrap.shared?.sovereignGate.confirm(.deviceOwnerAuthentication, reason: ...)`, and keep the current deletion body unchanged behind the allowed outcome.

## Failure-Proof Guardrails

- grep: `enum ModelVaultDeletionSovereignGate`
- grep: `requestDeleteAuthorization`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` outside `Epistemos/Sovereign/SovereignGate.swift`
- log: `Model vault deletes map to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`
