---
role: detective
slice: computer-use-bridge-agent-event-pr39
concept: ComputerUseBridge AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2, §6, §13
tier: Pro
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ComputerUseBridge.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift
deliberations_consulted:
  - docs/fusion/deliberation/computer_use_bridge_agent_event_pr39_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "what failed, and which run/trace it belongs to"
  code_says: "[paraphrase] ComputerUseBridge existed but lacked bounded AgentEvent provenance before PR39."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ComputerUseBridge.swift
load_bearing_quote: "what failed, and which run/trace it belongs to"
verdict: open
usefulness: +1
usefulness_reason: Identified a high-risk runtime bridge still missing sanitized tool provenance.
---

## Findings

- Card 7 requires bounded tool provenance that can answer who requested a tool, what ran, what failed, and which run/trace it belongs to.
- The runtime coverage map flagged `ComputerUseBridge` as high risk because it handles screenshots, accessibility trees, click coordinates, typed text, scrolls, and key presses.
- Existing code returned raw action results to the computer-use caller; the slice must not persist those raw results into AgentEvents.
- The smallest safe slice is instrumentation inside `ComputerUseBridge.execute(actionJSON:)` plus a new source/behavior guard test file.

## Open questions

- None for this slice. Broader computer-use policy surfacing remains a separate MAS/Core boundary lane.

## Recommendation

Record requested, started, and terminal completed/failed AgentEvents around the existing bridge call, using only bounded action classes, coordinate buckets, text-length buckets, result classes, element counts, and closed failure classes. Preserve existing tool behavior and returned payloads.
