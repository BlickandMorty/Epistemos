---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-settings-vault-disconnect-pr16
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate-settings-vault-disconnect.md
web_consumed: []
claude_side_fleet_consumed:
  - none
canon_gaps_opened: []
conflicts: []
drift_signals:
  - Settings vault disconnect was a Core destructive UI action not yet routed through SovereignGate.
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
usefulness_reason: Converts the remaining Settings vault disconnect action into a gated Core slice.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` and `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2` require one Sovereign Gate entrypoint for destructive UI actions.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 permits exact future confirmation-surface migrations with named files and focused tests.
- `Epistemos/Views/Settings/SettingsView.swift:3072` is the exact Core surface: the Settings Vault `Disconnect` button is destructive and mutates active vault connection state.
- `EpistemosTests/SovereignGateTests.swift:796` has the adjacent Settings source-guard pattern to reuse.

## Recommended slice shape

Implement a Core-only additive migration in `SettingsView.swift` and `SovereignGateTests.swift`: add a typed `vaultDisconnect(name:)` target, route the button through `requestVaultDisconnectAuthorization(vaultURL:)`, deny safely when the shared gate is unavailable, prevent duplicate prompts, recheck that the active vault has not changed, and only then call the original `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.

## Failure-proof guardrails

- grep: `vaultDisconnect\\(name:`
- grep: `requestVaultDisconnectAuthorization\\(vaultURL:`
- log: `Settings vault disconnect routes through Sovereign Gate`
- test: `SovereignGateTests`
