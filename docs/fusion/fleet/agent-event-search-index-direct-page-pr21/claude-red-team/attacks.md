---
role: codex-red-team
slice: agent-event-search-index-direct-page-pr21
brief: docs/fusion/deliberation/agent_event_search_index_direct_page_pr21_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Claude CLI stalled twice; Codex fallback found two P2 guard refinements and no P0/P1 blockers.
---

## Attacks

### A1 - Sync direct page search could accidentally use async recorder patterns [P2]
**Surface:** `SearchIndexService.search(query:limit:)`, `SearchIndexServiceFusionTests.swift` source guards.
**Attack:** The brief requires sync direct page search AgentEvents but does not explicitly say the sync body must use `AgentToolProvenanceSyncRecorder` and must not use `Task`, `Task.detached`, `DispatchQueue.main.sync`, `MainActor.assumeIsolated`, or the async recorder. PR20 had the same class of risk, and direct page search is also `nonisolated`. This is not a blocker if source guards are added before merge.
**Evidence:** `Epistemos/Sync/SearchIndexService.swift:502`; `Epistemos/Engine/AgentToolProvenanceRecorder.swift:72`; `AGENT_BUILD_WORKCARDS_2026_05_01.md:1028`.
**Mitigation proposed:** Add a source-guard assertion that the sync `search(query:limit:)` body contains the sync recorder path and does not contain async recorder or actor-hop patterns.

### A2 - Direct page PR21 must not silently include block search [P2]
**Surface:** `SearchIndexService.searchBlocks(query:limit:)`, brief forbidden scope.
**Attack:** Direct page and direct block search are adjacent methods. The brief names direct page search, but implementation convenience could accidentally instrument `searchBlocks` in the same patch and turn PR21 into a two-surface slice. This would make event semantics harder to review and could create duplicate low-level events for callers that fan out to page and block search.
**Evidence:** `Epistemos/Sync/SearchIndexService.swift:502`; `Epistemos/Sync/SearchIndexService.swift:526`; `AGENT_BUILD_WORKCARDS_2026_05_01.md:1001`.
**Mitigation proposed:** Keep block search untouched and add source/test guard language that `search_index.search_blocks` and `search_index.search_blocks_async` are absent in PR21.

## Brief verdict

Approved for implementation. No P0/P1 blockers. The two P2 findings should be folded into tests/source guards before merge.
