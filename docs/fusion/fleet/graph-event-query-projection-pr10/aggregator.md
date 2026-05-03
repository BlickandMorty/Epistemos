---
role: aggregator
source_fleet: codex-own
slice: graph-event-query-projection-pr10
date: 2026-05-03
detectives_consumed:
  - detectives/graph-event-query-projection.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - docs/fusion/fleet/round-47-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [explorer:next-agent-event-provenance-slice, explorer:next-graph-event-consumer-slice]
    resolution: GraphEvent QueryRuntime hint wins for this round because AgentEvent wrapper PR21 risks double-recording already closed SearchIndex PR19/PR20.
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
  plus_one: 3
  zero: 0
  minus_one: 1
usefulness: +1
usefulness_reason: Converts the remaining live GraphEvent consumer lane into a small QueryRuntime-only read-only hint.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 anchors the substrate spine and §10 anchors graph-engine boundaries.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` names live GraphEvent consumer projection beyond read-only Settings/Halo/Trace Inspector consumers as open.
- Card 8 requires a new gate naming exact files. This slice names only `Epistemos/Engine/QueryRuntime.swift` and `EpistemosTests/QueryRuntimeTests.swift`.
- The AgentEvent explorer found `VaultSyncService.searchFull*` is still a double-instrumentation risk because `SearchIndexService.fusedSearch*` is already instrumented.
- The GraphEvent explorer found QueryRuntime can consume durable projection state as a hint without touching SearchIndex, InstantRecall, MeaningAnchor, graph renderer, Rust, or UI.

## Recommended slice shape
Build `graph-event-query-projection-pr10` as a Core read-only QueryRuntime hint. The hint consumes an injected or env-enabled bounded `DurableGraphProjectionSnapshot`, only reorders already-returned full-text candidates inside equal-score groups, and never invents hits.

## Failure-proof guardrails
- grep: `rg -n "GraphEventProjectionHint|graphEventProjectionSnapshotProvider|EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1" Epistemos/Engine/QueryRuntime.swift`
- forbidden grep: `rg -n "saveGraphEvent|saveMutationEnvelope|GraphEventAuditProjectionService|InstantRecallService|MeaningAnchorService|Timer|DispatchSourceTimer|repeatForever" Epistemos/Engine/QueryRuntime.swift` returns no matches.
- log: `Test "GraphEvent projection hint only reorders existing equal-score candidates" passed`
- test: `QueryRuntimeTests`
