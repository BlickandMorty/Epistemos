---
role: detective
slice: agent-query-engine-agent-event-pr15
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHarness/AgentQueryEngine.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Persist and then wire bounded agent/tool provenance"
  code_says: "[paraphrase] AgentProvenanceEvent and AgentToolProvenanceRecorder remain the durable Swift provenance path"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift
load_bearing_quote: "Persist and then wire bounded agent/tool provenance"
verdict: open
usefulness: +1
usefulness_reason: Identifies AgentQueryEngine backend stream as the next clean runtime AgentEvent surface after PR14.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` places AgentEvent on the substrate spine feeding audit projections.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 closes PR1-PR14 and leaves future runtime coverage open only after exact gates.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` leaves "remaining broader runtime AgentEvent coverage" open after AgentGrep PR14.
- `AgentToolProvenanceRecorder.swift` already rejects empty run id, tool call id, and tool name before persisting.

## Open questions
- None for this narrow slice.

## Recommendation
Use the existing recorder from the provider-agnostic `AgentQueryEngine` stream seam only. Persist lifecycle identity and bounded counts, never prompt text, history, cwd, tool input data, tool output text, thinking/text deltas, backend logs, or system prompts.
