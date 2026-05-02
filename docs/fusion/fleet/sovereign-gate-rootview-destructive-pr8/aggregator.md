---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-rootview-destructive-pr8
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate.md
  - detectives/rootview-destructive-controls.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals:
  - RootView database reset bypasses the shared Sovereign Gate.
  - RootView vault disconnect bypasses the shared Sovereign Gate.
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
  minus_one: 0
usefulness: +1
usefulness_reason: Converts two remaining RootView destructive controls into one exact gate migration.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 classifies Destructive actions as every-time device-owner authentication.
- [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:271) has an existing database reset destructive alert button.
- [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:1794) has an existing vault disconnect destructive recovery overlay button.
- [SovereignGateTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:318) is the right focused suite for mapper and source-route proof.

## Recommended slice shape
Authorize PR8 as a minimal Core migration: add `RootViewDestructiveActionSovereignGate`, route database reset and vault disconnect through shared `SovereignGate` device-owner authentication, preserve the original closures after `.allowed`, and prove no duplicate `LocalAuthentication` is introduced.

## Failure-proof guardrails
- grep: `rg -n "RootViewDestructiveActionSovereignGate|requestDatabaseResetAuthorization|requestVaultDisconnectAuthorization|Reset Database|Disconnect Vault" Epistemos/App/RootView.swift EpistemosTests/SovereignGateTests.swift`
- log: `Test Suite 'Sovereign Gate' passed`
- test: `EpistemosTests/SovereignGateTests`

## Red-team revision
- P2 addressed: denied/cancelled database-reset auth restores `showDatabaseAlert` while `databaseError` remains present.
- P3 addressed: vault disconnect uses `isVaultDisconnectAuthorizationInFlight` to guard duplicate auth prompts and disable the destructive button while pending.
