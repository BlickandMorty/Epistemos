---
role: detective
slice: agent-event-search-index-direct-page-pr21
concept: SearchIndex direct page AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:502
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:515
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:72
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift:825
deliberations_consulted:
  - docs/fusion/deliberation/search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md
  - docs/fusion/deliberation/search_index_fused_sync_agent_event_pr20_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "remaining broader runtime AgentEvent coverage"
  code_says: "[paraphrase] Direct page search has no AgentEvent emission; fused async/sync already does."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift
load_bearing_quote: "Add remaining broader runtime AgentEvent coverage"
verdict: open
usefulness: +1
usefulness_reason: Identifies a clean exact AgentEvent gap that extends PR19/PR20 without dirty wrapper files.
---

## Findings

- Direct page `search(query:limit:)` and `searchAsync(query:limit:)` are current code chokepoints at `SearchIndexService.swift:502` and `:515`.
- Fused async/sync SearchIndex provenance is already closed, so this slice must not double-record `fusedSearch` or `VaultSyncService` wrapper calls.
- `AgentToolProvenanceSyncRecorder` already exists and is the required path for sync nonisolated search.
- `SearchIndexServiceFusionTests.swift` already has event-capture helpers and source guards for SearchIndex AgentEvents.

## Open questions

- None for this slice. Direct block search should be PR22, not part of PR21.

## Recommendation

Build PR21 as direct page-search provenance only. Persist requested/started/completed/failed AgentEvents for valid non-empty page searches, sanitize payloads to counts/classes only, and prove invalid inputs emit nothing. Keep the implementation out of VaultSync wrappers, QueryRuntime, Graph, UI, Rust, EventStore schema, and block search.
