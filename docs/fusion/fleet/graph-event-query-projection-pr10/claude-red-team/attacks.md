---
role: claude-red-team
slice: graph-event-query-projection-pr10
brief: docs/fusion/deliberation/graph_event_query_projection_pr10_deliberation_2026_05_02.md
date: 2026-05-03
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Keeps the implementation constrained to existing full-text candidates and exact-hunk staging around the dirty QueryRuntime RRF site.
---

## Attacks

### A1 - Projection hint could become a second search source [P2]
**Surface:** `docs/fusion/deliberation/graph_event_query_projection_pr10_deliberation_2026_05_02.md`, implementation contract for `Epistemos/Engine/QueryRuntime.swift`.
**Attack:** If the projection snapshot inserts nodes into the result set, QueryRuntime becomes a parallel graph search surface instead of a full-text retrieval executor. That would violate the brief's Core constraint that GraphEvent state is only a read-only ordering hint.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 requires direct, deterministic substrate boundaries; the brief says the hint "never invents hits."
**Mitigation proposed:** Implement the hint as a stable reorder pass over the already-scored candidate array, and add a test proving a projected ghost node never appears in results.

### A2 - Dirty QueryRuntime RRF hunk can be accidentally committed [P2]
**Surface:** `Epistemos/Engine/QueryRuntime.swift`.
**Attack:** The file is already dirty with unrelated RRF fused-search wiring. A normal `git add Epistemos/Engine/QueryRuntime.swift` would commit unrelated work under this GraphEvent slice.
**Evidence:** `docs/fusion/fleet/graph-event-query-projection-pr10/aggregator.md` flags the same staging risk; the current diff shows the RRF hunk before the PR10 patch.
**Mitigation proposed:** Stage this file with an exact cached patch or otherwise verify the staged diff excludes the RRF hunk before committing.

## Brief verdict

The brief is approved for implementation. No P0/P1 attack blocks the slice as long as the implementation keeps projection state read-only, reorders only existing candidates, stays out of graph/UI/Rust/SearchIndex mutation surfaces, and stages `QueryRuntime.swift` with exact-hunk discipline.
