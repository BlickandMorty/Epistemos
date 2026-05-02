---
role: detective
slice: agent-event-sync-recorder-enabler-pr0
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:3
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift:649
deliberations_consulted:
  - docs/fusion/deliberation/search_index_fused_sync_agent_event_pr20_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "PR20 sync fused search can be next only after recorder safety is solved."
  code_says: "[paraphrase] The current recorder is @MainActor; EventStore persistence is nonisolated and queue-serialized."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift
load_bearing_quote: "TypedArtifact -> MutationEnvelope -> RunEventLog / AgentEvent / GraphEvent"
verdict: open
usefulness: +1
usefulness_reason: Confirms AgentEvent is substrate-spine work and the direct PR20 path is blocked until recorder safety exists.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 places AgentEvent directly in the substrate spine.
- Card 7 records PR1-PR19 as closed and leaves the sync PR20 path blocked by actor isolation.
- Current `AgentToolProvenanceRecorder` is `@MainActor`, so synchronous nonisolated callers cannot call it directly.
- Current `EventStore.saveAgentEvent(_:)` is `nonisolated` and serializes SQLite writes through `EventStore`'s utility queue, which supports a sync-safe recorder sibling if sequence state is also protected.

## Open Questions
- Should the enabler persist events directly, or only build events? Current-code evidence supports direct persistence because `EventStore.saveAgentEvent(_:)` is already nonisolated and queue-serialized.

## Recommendation
Add an additive sync-safe recorder sibling that shares event construction semantics with the existing main-actor recorder. Do not instrument `SearchIndexService.fusedSearch(...)` in this slice.
