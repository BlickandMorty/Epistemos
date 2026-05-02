---
role: aggregator
source_fleet: codex-own
slice: sovereign-gate-version-delete-pr7
date: 2026-05-02
detectives_consumed:
  - detectives/sovereign-gate.md
  - detectives/diffsheet-version-delete.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals:
  - DiffSheet destructive version delete bypasses the shared Sovereign Gate.
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
usefulness_reason: Converts one discovered destructive-surface drift into an exact build slice.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 and doctrine §4.2 require a single Sovereign Gate for confirmation surfaces.
- [DiffSheetView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:218) has a destructive version-delete button that currently bypasses the gate.
- [DiffSheetView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:559) already has correct delete rollback behavior; preserve it.
- [SovereignGateTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:232) is the right focused suite for mapper-level proof.

## Recommended slice shape
Authorize PR7 as a minimal Core migration: add a DiffSheet version-delete gate mapper, route the existing menu action through shared `SovereignGate` device-owner authentication, preserve the existing delete implementation, and test the mapper without touching real `LocalAuthentication`.

## Failure-proof guardrails
- grep: `rg -n "DiffSheetVersionDeletionSovereignGate|requestSelectedVersionDeleteAuthorization|Delete This Version" Epistemos/Views/Notes/DiffSheetView.swift EpistemosTests/SovereignGateTests.swift`
- log: `Test Suite 'Sovereign Gate' passed`
- test: `EpistemosTests/SovereignGateTests`
