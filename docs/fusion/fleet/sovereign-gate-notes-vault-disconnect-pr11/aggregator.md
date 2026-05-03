---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-notes-vault-disconnect-pr11
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-notes-vault-disconnect.md
web_consumed: []
claude_side_fleet_consumed:
  - none
canon_gaps_opened: []
conflicts: []
drift_signals:
  - Notes Sidebar vault disconnect is a remaining destructive confirmation surface not yet gated.
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
usefulness_reason: Converts the detective finding into a narrow, testable Notes Sidebar vault-disconnect migration.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` requires a single Sovereign Gate entrypoint for native authorization.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` marks PR1-PR10 closed and leaves additional existing confirmation migrations open.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 permits future confirmation-surface migrations only when the exact surface and tests are named.
- `NotesSidebar.swift` has a destructive vault disconnect menu action that currently bypasses the shared gate.

## Recommended Slice Shape

Extend `NotesSidebarDeletionSovereignGate.Target` with `vaultDisconnect(name:)`, route the existing menu button through `requestVaultDisconnectAuthorization(vaultURL:)`, and call `VaultConnectionActions.disconnect(notesUI:vaultSync:)` only after `.allowed` and only if the current vault still matches the captured vault URL.

## Failure-Proof Guardrails

- grep: `case vaultDisconnect(name: String)`
- grep: `requestVaultDisconnectAuthorization(vaultURL:)`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` outside `Epistemos/Sovereign/SovereignGate.swift`
- log: `Notes sidebar vault disconnect maps to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`
