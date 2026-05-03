---
role: aggregator
source_fleet: codex-own
slice: graph-event-trace-inspector-projection-pr9
date: 2026-05-02
detectives_consumed:
  - detectives/graph-event-trace-inspector-projection.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: none
    sources: []
    resolution: none
drift_signals:
  - none
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
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts an open live GraphEvent consumer lane into a safe read-only diagnostic slice.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 keeps GraphEvent in the substrate spine, and Card 8 names live consumer projections as the remaining safe GraphEvent lane.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §4 makes Quick Capture/trace surfaces canonical donor context, and `TraceInspectorView` is already mounted from `QuickCaptureView`.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §10 protects graph renderer/engine paths; this slice avoids them entirely.

## Recommended Slice Shape

Add one read-only projection summary strip to `TraceInspectorView`, backed by
the existing `GraphEventAuditProjectionService().auditReport(limit: 100)`, and
refresh it on appear / manual refresh through the existing trace-load action.
After Red Team, keep report generation inside the detached utility snapshot path
and keep the projection service explicitly nonisolated/Sendable. Add focused
Swift Testing guards in `GraphEventAuditProjectionTests`.

## Failure-Proof Guardrails

- grep: `rg -n "graphProjectionReport|loadTask\\?\\.cancel\\(\\)|GraphEventAuditProjectionService\\(\\)\\.auditReport\\(limit: 100\\)|Graph projection" Epistemos/Views/Capture/TraceInspectorView.swift`
- grep: `rg -n "nonisolated final class GraphEventAuditProjectionService: @unchecked Sendable" Epistemos/Engine/GraphEventAuditProjectionService.swift`
- log: `✔ Test "trace inspector exposes read-only GraphEvent projection summary" passed`
- test: `GraphEventAuditProjectionTests`
