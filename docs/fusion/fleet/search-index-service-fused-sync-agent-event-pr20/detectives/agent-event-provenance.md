---
role: detective
slice: search-index-service-fused-sync-agent-event-pr20
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:3
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift:649
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:563
deliberations_consulted:
  - docs/fusion/deliberation/search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: true
  canon_says: "Source and behavior stay away from sync `fusedSearch`"
  code_says: "[paraphrase] The sync fusedSearch path is still intentionally uninstrumented after PR19."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift
load_bearing_quote: "Future live emission must be additive instrumentation only"
verdict: partial
usefulness: +1
usefulness_reason: Confirms PR20 is a real parity gap, but also exposes the recorder-isolation constraint before code.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` keeps `AgentEvent` inside the substrate spine, so the sync search rail is legitimate provenance territory.
- Card 7 requires live emission to stay additive: no approval, routing, tool execution, UI control-flow, EventStore schema, GraphEvent, OpLog, Rust, or generated-binding changes.
- `AgentToolProvenanceRecorder` is `@MainActor` at `Epistemos/Engine/AgentToolProvenanceRecorder.swift:3`; direct calls from `SearchIndexService.fusedSearch` are therefore not available from a synchronous `nonisolated` method.
- `EventStore.saveAgentEvent(_:)` is nonisolated, but bypassing the recorder would duplicate sequencing/event-construction logic unless an explicit shared builder or sync-safe recorder gate is approved.

## Open Questions

- Should PR20 be reframed as an enabling recorder-safety slice before sync search provenance, or should sync fused search remain intentionally uninstrumented while async fused search is the canonical provenance rail?

## Recommendation

Do not issue a code order for PR20 until the brief either approves a sync-safe recorder design or explicitly abandons sync instrumentation. Fire-and-forget `Task`, `DispatchQueue.main.sync`, `MainActor.assumeIsolated`, or changing `fusedSearch` to actor-isolated/async would violate the slice contract.
