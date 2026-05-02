---
role: detective
slice: agent-event-sync-recorder-enabler-pr0
concept: sync-safe recorder constraint
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §22.1
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/round-27-next-master-plan-slice-selection/aggregator.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:563
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:3
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift:649
deliberations_consulted:
  - docs/fusion/deliberation/search_index_fused_sync_agent_event_pr20_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Do not issue a code order for PR20 until the brief either approves a sync-safe recorder design."
  code_says: "[paraphrase] No sync-safe recorder currently exists."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/detectives/agent-event-provenance.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift
load_bearing_quote: "Search local canon first: this master index, then the canonical source it names"
verdict: partial
usefulness: +1
usefulness_reason: Turns the PR20 blocker into an exact additive enabler with forbidden implementation shapes.
---

## Findings
- `SearchIndexService.fusedSearch(...)` remains synchronous and nonisolated by contract; changing its signature would spill into dirty runtime callers.
- Fire-and-forget `Task`, `Task.detached`, `DispatchQueue.main.sync`, and `MainActor.assumeIsolated` are already forbidden by the PR20 red-team packet.
- A queue-backed or lock-backed sync recorder is the narrowest design because it avoids main-actor hops and preserves synchronous success/failure semantics.

## Open Questions
- None for this enabler. Consumer instrumentation remains a separate PR20 gate.

## Recommendation
Implement a sync-safe recorder sibling with `NSLock`-protected per-run sequence allocation and shared event construction. Add tests for ordering, lower-snake-case EventStore persistence, and source-guarded absence of forbidden main-actor bridging.
