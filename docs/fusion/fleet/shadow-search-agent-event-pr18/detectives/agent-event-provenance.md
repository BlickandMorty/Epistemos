---
role: detective
slice: shadow-search-agent-event-pr18
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:3
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md
  - docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "PR17 InstantRecall async recall provenance is also closed."
  code_says: "[paraphrase] InstantRecallService records requested, started, completed, failed, zero-hit, and cancellation events."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift
load_bearing_quote: "The durable model is intentionally named `AgentProvenanceEvent`"
verdict: open
usefulness: +1
usefulness_reason: Confirms PR18 must reuse AgentProvenanceEvent/AgentToolProvenanceRecorder and extend Card 7 without schema changes.
---

## Findings
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:661` through `:815` show Card 7 has closed PR1-PR17 and names PR17 as the latest closed recall provenance slice.
- `AgentToolProvenanceRecorder.swift:3` keeps persistence behind an existing `@MainActor` recorder; PR18 does not need a new event model or EventStore schema.
- `AgentProvenanceEvent.swift:1` already includes `toolCallRequested`, `toolCallStarted`, `toolCallCompleted`, and `toolCallFailed`.
- The PR16/PR17 pattern records bounded metadata and omits raw prompt/query/result bodies; PR18 should inherit that privacy stance.

## Open questions
- Whether `ShadowSearchService.search` should record non-positive limit calls or treat them as invalid/no-event. The aggregator should choose the minimal behavior-preserving rule.

## Recommendation
Implement PR18 as another bounded Card 7 provenance slice: one run id per valid ShadowSearch call, one monotonic `shadow-search:N` tool id per service instance, requested/started/terminal lifecycle rows, and no schema/model changes.
