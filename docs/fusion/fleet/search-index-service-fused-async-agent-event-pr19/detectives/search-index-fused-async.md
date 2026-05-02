---
role: detective
slice: search-index-service-fused-async-agent-event-pr19
concept: SearchIndexService fused async retrieval provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §5
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/round-19-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:591
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/RRFFusionQuery.swift:35
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/VaultSyncService.swift:2326
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift:370
deliberations_consulted:
  - docs/fusion/fleet/round-19-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "SearchIndexService contains zero AgentProvenance|saveAgentEvent references today"
  code_says: "[paraphrase] Grep found no AgentProvenance or saveAgentEvent references in SearchIndexService."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/round-19-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift
load_bearing_quote: "Single Swift actor, single user-reachable RRF cross-index fusion chokepoint"
verdict: open
usefulness: +1
usefulness_reason: Identifies the next live retrieval chokepoint and exact code seam for PR19.
---

## Findings
- `SearchIndexService.fusedSearchAsync(query:weights:now:)` currently wraps the RRF query with the existing `fused_search` signpost and `SearchFusionMetrics`, but has no persisted AgentEvent row.
- `VaultSyncService.searchFullAsync` reaches this async fused path when `RRFFusionFlags.isEnabled`, so the slice is user-reachable without changing consumer call sites.
- The existing `SearchIndexServiceFusionTests` file has a real file-backed async parity test that can be extended for red/green provenance coverage.

## Open questions
- Whether to use an in-memory recorder sink only or also write through EventStore. PR16-PR18 used injected recorders; the implementation should stay injectable and tests can assert captured rows directly.

## Recommendation
Instrument only `fusedSearchAsync`, leave sync `fusedSearch` and legacy search methods untouched, and add focused tests proving completed, zero-hit, cancellation, invalid-input, and sync-untouched behavior.
