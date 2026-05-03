---
role: pipeline-builder
slice: graph-event-query-projection-pr10
date: 2026-05-03
tier: Core
deliberation: docs/fusion/deliberation/graph_event_query_projection_pr10_deliberation_2026_05_02.md
red_team: docs/fusion/fleet/graph-event-query-projection-pr10/claude-red-team/attacks.md
usefulness: +1
usefulness_reason: Mirrors the approved deliberation brief in the slice-local fleet artifact tree.
---

# GraphEvent Query Projection PR10 Brief

Canonical brief:
`docs/fusion/deliberation/graph_event_query_projection_pr10_deliberation_2026_05_02.md`

Approved implementation:
`Epistemos/Engine/QueryRuntime.swift` may consume an injected or env-enabled
bounded `DurableGraphProjectionSnapshot` only as a stable tie-break over
existing full-text retrieval candidates.

Forbidden:
No new hits, no SearchIndex writes, no GraphEvent writes, no semantic retrieval
hinting, no graph renderer, Theater, OpLog, Rust, generated bindings, mutation,
repair, polling, timer, or projection-worker behavior.

Evidence:
- Red: `/tmp/epistemos-graph-event-query-projection-pr10-red-20260502.log`
- Green: `/tmp/epistemos-graph-event-query-projection-pr10-green-20260502.log`
- Guards: `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
