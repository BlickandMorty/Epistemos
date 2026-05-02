---
role: detective
slice: search-index-service-fused-sync-agent-event-pr20
concept: SearchIndexService fused sync retrieval provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §5
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:563
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:597
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/VaultSyncService.swift:2309
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/QueryRuntime.swift:289
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift:582
deliberations_consulted:
  - docs/fusion/fleet/round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
  - docs/fusion/deliberation/search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "PR19 explicitly closes only the async `fusedSearchAsync` rail"
  code_says: "[paraphrase] Source guard still asserts sync fusedSearch contains no recorder calls."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
  code_path: /Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift
load_bearing_quote: "sync `fusedSearch` remains uninstrumented"
verdict: open
usefulness: +1
usefulness_reason: Identifies why PR20 is the next parity candidate and why it is riskier than PR19.
---

## Findings

- `SearchIndexService.fusedSearch(query:weights:now:)` is `nonisolated public` at `Epistemos/Sync/SearchIndexService.swift:563`; production callers currently rely on the synchronous signature.
- `SearchIndexService.fusedSearchAsync(query:weights:now:)` at `Epistemos/Sync/SearchIndexService.swift:597` already owns the safe async recorder pattern from PR19.
- `EpistemosTests/SearchIndexServiceFusionTests.swift:582` currently proves sync `fusedSearch` remains uninstrumented; PR20 would need to invert this guard only if a sync-safe recorder strategy is approved.
- Existing production sync callers include `VaultSyncService.swift:2309` and `QueryRuntime.swift:289`; changing the method isolation/signature would force broader runtime edits outside the recommended narrow slice.

## Open Questions

- Can sync provenance be emitted without changing `fusedSearch` isolation, without blocking the main actor, and without duplicating recorder sequencing/privacy logic?

## Recommendation

Treat sync fused-search provenance as a valid target but not yet an approved code patch. The next implementation should either be an enabling shared recorder/event-builder slice or a decision to keep sync search direct and use async fused search as the provenance-bearing rail.
