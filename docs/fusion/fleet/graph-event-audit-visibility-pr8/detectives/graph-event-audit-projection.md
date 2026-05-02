---
role: detective
slice: graph-event-audit-visibility-pr8
concept: GraphEvent audit projection
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/graph_event_audit_projection_pr6_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/GraphEventAuditProjectionService.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/GraphEventVisibilityRow.swift:1
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2643
deliberations_consulted:
  - docs/fusion/deliberation/graph_event_audit_projection_pr6_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "`GraphEventAuditProjectionService` consumes the existing `EventStore.graphEventProjectionSnapshot(limit:)` API"
  code_says: "[paraphrase] service still returns a bounded report from graphEventProjectionSnapshot(limit:)"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/GraphEventAuditProjectionService.swift
load_bearing_quote: "`GraphEventAuditProjectionService` consumes the existing `EventStore.graphEventProjectionSnapshot(limit:)` API"
verdict: closed
usefulness: +1
usefulness_reason: Confirms PR8 should reuse the closed PR6 audit service, not create a new projection algorithm.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` names GraphEvent as part of the substrate spine feeding audit projections.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:321` closes PR6 as a read-only audit projection service.
- `GraphEventAuditProjectionService.swift:35` already uses `EventStore.shared?.graphEventProjectionSnapshot(limit:)`, so PR8 can stay UI-only and read-only.
- `graph_event_audit_projection_pr6_deliberation_2026_05_02.md:17` forbids renderer, graph, retrieval, Rust, schema, mutation, repair, polling, timer, and UI changes for PR6; PR8 may only consume the closed service from Settings.

## Open questions
- None for this slice.

## Recommendation
Expose the existing PR6 `GraphEventAuditProjectionService` report inside the already-mounted Settings `GraphEventVisibilityRow` on appear/refresh only. Do not change EventStore, projection logic, renderer, Rust, Halo, Theater, polling, or repair behavior.
