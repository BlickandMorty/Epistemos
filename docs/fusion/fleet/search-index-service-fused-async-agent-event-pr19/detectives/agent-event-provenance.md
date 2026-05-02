---
role: detective
slice: search-index-service-fused-async-agent-event-pr19
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift:649
deliberations_consulted:
  - docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md
  - docs/fusion/deliberation/shadow_search_agent_event_pr18_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: true
  canon_says: "InstantRecall paths beyond sync/async recall search"
  code_says: "[paraphrase] ShadowSearch PR18 is now closed; current-state open wording has not been narrowed yet."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift
load_bearing_quote: "Future live emission must be additive instrumentation only"
verdict: partial
usefulness: +1
usefulness_reason: Confirms PR19 needs a fresh Card 7 gate and should update stale PR18/PR19 status wording.
---

## Findings
- Card 7 keeps `AgentProvenanceEvent` as the durable Swift source and requires additive instrumentation only; do not alter approval, routing, tool execution, EventStore schema, or UI.
- `AgentToolProvenanceRecorder` is the canonical recorder shape already used by PR16-PR18; PR19 should reuse it rather than inventing a second persistence surface.
- The current-state open wording still omits closed ShadowSearch PR18, so PR19's doc update must also tighten that drift before adding the fused async search closure.

## Open questions
- None for the brief. The only open choice is the exact surface string; Claude side-fleet recommends `fused_search_async`.

## Recommendation
Authorize a Core, additive AgentEvent slice scoped to `SearchIndexService.fusedSearchAsync(query:weights:now:)`, with bounded JSON, closed failure classes, no EventStore schema changes, and a doc correction for the stale PR18 open wording.
