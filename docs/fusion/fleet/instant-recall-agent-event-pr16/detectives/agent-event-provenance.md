---
role: detective
slice: instant-recall-agent-event-pr16
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:189
deliberations_consulted:
  - docs/fusion/deliberation/agent_query_engine_agent_event_pr15_deliberation_2026_05_02.md
quick_capture_consulted: false
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "EventStore AgentProvenanceEvent rows on main record what the Gate emits today."
  code_says: "[paraphrase] AgentToolProvenanceRecorder records typed tool lifecycle events."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift
load_bearing_quote: "EventStore AgentProvenanceEvent rows on main record what the Gate emits today."
verdict: open
usefulness: +1
usefulness_reason: Identifies the next safe AgentEvent seam after PR15 as bounded InstantRecall sync-search provenance.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` places AgentEvent inside the substrate spine rather than as optional UI telemetry.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 keeps future live emission additive and requires exact runtime files plus focused tests.
- `AgentToolProvenanceRecorder.swift` already provides the canonical in-process recorder, so PR16 does not need EventStore schema, model, or Rust/generated changes.
- `InstantRecallService.swift:189` is the narrow sync search seam; `searchAsync(query:topK:)` is an ambient hot path and remains out of scope.

## Open questions
- None for this slice. Broader InstantRecall async/Halo/ShadowSearch provenance needs a separate hot-path gate.

## Recommendation
Approve a Core additive AgentEvent slice for `InstantRecallService.search(queryText:topK:)` only. Emit requested, started, and completed/failed rows with sanitized counts and no query text, note ids, note bodies, snippets, or result text.
