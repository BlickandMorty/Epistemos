---
role: detective
slice: graph-event-trace-inspector-projection-pr9
concept: GraphEvent Trace Inspector read-only projection consumer
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2, §4, §10
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Capture/TraceInspectorView.swift:15
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/GraphEventAuditProjectionService.swift:58
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventAuditProjectionTests.swift:6
deliberations_consulted:
  - docs/fusion/deliberation/graph_event_halo_projection_pr7_deliberation_2026_05_02.md
quick_capture_consulted: true
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Future live GraphEvent consumer projections only after a new deliberation gate"
  code_says: "[paraphrase] TraceInspectorView is a read-only capture trace sheet with no GraphEvent projection summary."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Capture/TraceInspectorView.swift
load_bearing_quote: "Future live GraphEvent consumer projections only after a new deliberation gate"
verdict: open
usefulness: +1
usefulness_reason: Finds a narrow read-only live GraphEvent consumer that avoids protected graph/editor/Rust paths.
---

## Findings

- `TraceInspectorViewModel.loadTraces()` already loads capture provenance and filters `graph_write_attempted` trace rows, so it is a natural read-only diagnostic surface.
- `GraphEventAuditProjectionService.auditReport(limit:)` already returns bounded event/node/edge counts and latest event id from the durable projection snapshot.
- Card 8 permits future live GraphEvent consumers only after a new gate names exact files; this slice names exactly `TraceInspectorView.swift` and `GraphEventAuditProjectionTests.swift`.
- The slice should not touch `EventStore`, `MutationEnvelope`, `Views/Graph/**`, `Epistemos/Graph/**`, `graph-engine/**`, Settings, Halo, Theater, OpLog, or generated bindings.

## Open Questions

- Manual runtime verification of the Trace Inspector sheet remains deferred by user request.

## Recommendation

Expose a compact read-only `GraphEventAuditProjectionReport` summary in the
existing Capture Trace Inspector and refresh it alongside the existing trace
reload action. Add source guards proving there are no GraphEvent writes, timers,
polling loops, OpLog/Rust/Halo/Settings couplings, or protected renderer/editor
dependencies.
