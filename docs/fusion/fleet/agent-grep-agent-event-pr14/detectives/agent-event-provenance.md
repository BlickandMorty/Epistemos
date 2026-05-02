---
role: detective
slice: agent-grep-agent-event-pr14
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentGrepService.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_tool_provenance_pr1_deliberation_2026_05_01.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Persist and then wire bounded agent/tool provenance"
  code_says: "[paraphrase] AgentProvenanceEvent and AgentToolProvenanceRecorder are the existing typed persistence path"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift
load_bearing_quote: "Persist and then wire bounded agent/tool provenance"
verdict: open
usefulness: +1
usefulness_reason: Identifies AgentGrep as a remaining runtime AgentEvent surface after PR13.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` places AgentEvent on the substrate spine feeding audit projections.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:741` defines the Card 7 goal as bounded provenance for who requested a tool, what ran, and what failed.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:698` leaves "remaining broader runtime AgentEvent coverage" open after PR13.
- `AgentToolProvenanceRecorder.swift:29` already records typed tool lifecycle events and rejects empty run/tool identity.

## Open questions
- None for this slice.

## Recommendation
Use the existing `AgentToolProvenanceRecorder` from the clean `AgentGrepService.search(...)` chokepoint only, with sanitized metadata and no query/snippet/path/body/provenance payload persistence.
