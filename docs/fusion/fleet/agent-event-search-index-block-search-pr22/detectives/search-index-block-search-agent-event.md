---
role: detective
slice: agent-event-search-index-block-search-pr22
concept: SearchIndex block-search AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2, §19, §22
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:686
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:693
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:1654
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift:1017
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_search_index_direct_page_pr21_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "remaining broader runtime AgentEvent coverage"
  code_says: "[paraphrase] searchBlocks/searchBlocksAsync still return without AgentEvent lifecycle recording"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift
load_bearing_quote: "AgentEvent emission beyond PipelineService observed-tool"
verdict: open
usefulness: +1
usefulness_reason: Confirms the next narrow runtime provenance gap after PR21 is block-search lifecycle emission.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 keeps AgentEvent in the substrate spine, so SearchIndex provenance remains substrate work, not UI feature work.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:1124` lists remaining broader runtime AgentEvent coverage after PR21.
- `SearchIndexService.searchBlocks(query:limit:)` at `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:686` normalizes input and directly calls the private block query helper.
- `SearchIndexService.searchBlocksAsync(query:limit:)` at `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:693` offloads work but does not emit requested/started/completed/failed lifecycle events.
- `SearchIndexServiceAgentEventSourceGuardTests` at `/Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift:1017` currently guards PR21 by banning block-search tool names globally; PR22 should replace that ban with bounded positive checks.

## Open questions
- None blocking. This is pure local substrate work; no web validation is required because it does not depend on a current external API, OS behavior, App Store rule, package release, or model card.

## Recommendation
Authorize a narrow PR22 patch that instruments only `searchBlocks(query:limit:)` and `searchBlocksAsync(query:limit:)`, reuses the PR21 sanitized metadata shape, keeps invalid normalized inputs event-free, and proves sync block search uses the sync recorder without `Task`, `Task.detached`, `DispatchQueue.main.sync`, or `MainActor.assumeIsolated`.
