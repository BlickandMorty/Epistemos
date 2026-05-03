---
role: post-merge-guards
slice: graph-event-query-projection-pr10
date: 2026-05-03
tier: Core
usefulness: +1
usefulness_reason: Records the guardrails that must remain true after PR10 is merged.
---

# GraphEvent Query Projection PR10 Guards

- grep: `rg -n "GraphEventProjectionHint|graphEventProjectionSnapshotProvider|EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1" Epistemos/Engine/QueryRuntime.swift`
- forbidden grep: `rg -n "saveGraphEvent|saveMutationEnvelope|GraphEventAuditProjectionService|InstantRecallService|MeaningAnchorService|Timer|DispatchSourceTimer|repeatForever" Epistemos/Engine/QueryRuntime.swift` returns no matches.
- log: `✔ Test "GraphEvent projection hint only reorders existing equal-score candidates" passed`
- log: `✔ Test "retrieval runtime applies GraphEvent projection hint only to existing full-text candidates" passed`
- log: `✔ Test "GraphEvent projection hint stays out of indexes and renderer" passed`
- test: `QueryRuntimeTests`
- test: `GraphEventAuditProjectionTests`
