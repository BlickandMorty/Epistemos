---
role: detective
slice: phase4-interact-agent-event-pr41
concept: Phase4 interact AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2, §6, §13
tier: Pro
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift
deliberations_consulted:
  - docs/fusion/deliberation/phase4_interact_agent_event_pr41_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "what failed, and which run/trace it belongs to"
  code_says: "[paraphrase] Phase4 interact existed but lacked bounded AgentEvent provenance before PR41."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift
load_bearing_quote: "what failed, and which run/trace it belongs to"
verdict: open
usefulness: +1
usefulness_reason: Identified a high-risk Phase4 action bridge still missing sanitized tool provenance.
---

## Findings

- Card 7 requires bounded tool provenance that can answer who requested a tool, what ran, what failed, and which run/trace it belongs to.
- `Phase4Bridge.interact(actionJson:)` routes primitive actions into ComputerUseBridge and AX-targeted actions into AXorcist.
- Existing code returned raw action results to the caller; the slice must not persist raw action JSON, typed text, target labels, bundle ids, raw coordinates, raw results, or arbitrary error strings into AgentEvents.
- The smallest safe slice is instrumentation around `interact(actionJson:)` plus a new focused behavior/source guard test file. `screen_watch` stays separate.

## Open questions

- None for this slice. `Phase4Bridge.startScreenWatch(watchJson:)` remains an open follow-up bridge provenance slice.

## Recommendation

Record requested, started, and terminal completed/failed AgentEvents around existing interact dispatch, using only bounded action classes, route classes, app/target scopes, text-length buckets, coordinate buckets, direction/key classes, result classes, duration, success status, and closed failure classes. Preserve existing returned payloads.
