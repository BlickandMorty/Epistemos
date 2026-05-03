---
role: claude-red-team
slice: agent-event-search-index-block-search-pr22
brief: docs/fusion/deliberation/agent_event_search_index_block_search_pr22_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Approves the brief while preserving the PR21 no-leak lesson as a PR22 source-guard requirement.
---

## Attacks

### A1 — PR21's global block-tool ban must become a bounded positive guard [P2]
**Surface:** `/Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift:1042`
**Attack:** The current source guard forbids `search_index.search_blocks` and `search_index.search_blocks_async` anywhere in `SearchIndexService.swift`. PR22 must not simply delete the guard; it should replace it with positive assertions for block-search helper names plus body-scoped checks proving direct page search and fused search do not accidentally use block-search tool names.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md` §2, `SearchIndexServiceFusionTests.swift:1042`.
**Mitigation proposed:** Add a block-search source-guard section that requires `recordBlockSearchSyncAgentEvent`, `recordBlockSearchAsyncAgentEvent`, the two block tool names, and block sync/async sequences, while checking `search(query:)` and `fusedSearch` bodies do not reference block-search tool names.

## Brief verdict
Approve the brief. No P0/P1 attacks block Kimi/Codex code work. The only red-team concern is preserving source-guard precision when the PR21 no-block-name assertion is retired.
