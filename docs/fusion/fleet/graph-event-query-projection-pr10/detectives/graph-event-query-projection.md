---
role: detective
slice: graph-event-query-projection-pr10
concept: GraphEvent QueryRuntime read-only projection hint
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2, §10, §22
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/QueryRuntime.swift:277
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift:896
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/MutationEnvelope.swift:580
deliberations_consulted:
  - docs/fusion/deliberation/graph_event_projection_consumer_pr4_deliberation_2026_05_02.md
  - docs/fusion/deliberation/graph_event_audit_projection_pr6_deliberation_2026_05_02.md
  - docs/fusion/deliberation/graph_event_trace_inspector_projection_pr9_deliberation_2026_05_02.md
quick_capture_consulted: false
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "Future live GraphEvent consumer projections only after a new deliberation gate"
  code_says: "[paraphrase] QueryRuntime fullText currently has no GraphEvent projection hint input."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/QueryRuntime.swift
load_bearing_quote: "Future live GraphEvent consumer projections only after a new deliberation gate"
verdict: open
usefulness: +1
usefulness_reason: Names a narrow live GraphEvent consumer that avoids renderer, Rust, SearchIndex, InstantRecall, and UI paths.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 keeps GraphEvent in the substrate spine: `TypedArtifact -> MutationEnvelope -> RunEventLog / AgentEvent / GraphEvent`.
- Card 8 allows future live GraphEvent consumers only after exact projection files and tests are named.
- `EventStore.graphEventProjectionSnapshot(limit:)` already provides the bounded read-only snapshot; this slice should consume it, not create a second projection algorithm.
- QueryRuntime is already the retrieval/query projection point; a hint there can affect only existing candidates and cannot invent search hits.

## Open questions
- None for this slice. SearchIndex, InstantRecall, MeaningAnchor, graph renderer, and UI are deliberately out of scope.

## Recommendation
Add an injectable GraphEvent projection snapshot provider to `RetrievalRuntime` / `QueryRuntime`, default it behind `EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1`, and use it only as a stable tie-break among already-returned full-text candidates. Do not mutate indexes, graph state, EventStore schema, renderer state, or UI.
