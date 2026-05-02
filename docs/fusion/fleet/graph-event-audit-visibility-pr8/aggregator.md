---
role: aggregator
source_fleet: codex-own
slice: graph-event-audit-visibility-pr8
date: 2026-05-02
detectives_consumed:
  - detectives/graph-event-audit-projection.md
  - detectives/settings-visibility-row.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals: []
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
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
usefulness_reason: Converts closed PR6 audit service plus existing Settings row into a bounded PR8 visibility slice.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` treats GraphEvent as a substrate-spine stream that feeds audit projections.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:321` closes `GraphEventAuditProjectionService` as the canonical bounded audit report source.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1036` closes the existing Settings projection visibility row and requires no timers, `.task` loops, repair actions, Rust, OpLog, renderer, retrieval, Halo, or Theater side effects.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1099` permits future GraphEvent consumer projections only after a new deliberation gate names exact projection files and focused tests; this packet supplies that gate.

## Recommended slice shape
Approve a Core, read-only Settings consumer that adds an "Audit projection" row to `GraphEventVisibilityRow.swift`, backed by `GraphEventAuditProjectionService().auditReport(limit: 100)`, and updates the existing source-guard test. Do not touch `SettingsView.swift`, EventStore, graph renderer, Rust, generated bindings, Halo, Theater, OpLog, polling, timers, or repair behavior.

## Failure-proof guardrails
- grep: `GraphEventAuditProjectionService\\(\\)\\.auditReport\\(limit: 100\\)`
- log: `✔ Test "GraphEvent visibility row is read-only and mounted in Settings" passed`
- test: `GraphEvent visibility row is read-only and mounted in Settings`
