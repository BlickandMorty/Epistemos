---
role: detective
slice: phase4-perceive-agent-event-pr40
concept: Phase4 perceive AgentEvent provenance
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
  - docs/fusion/deliberation/phase4_perceive_agent_event_pr40_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "what failed, and which run/trace it belongs to"
  code_says: "[paraphrase] Phase4 perceive existed but lacked bounded AgentEvent provenance before PR40."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift
load_bearing_quote: "what failed, and which run/trace it belongs to"
verdict: open
usefulness: +1
usefulness_reason: Identified a high-risk Screen2AX perception bridge still missing sanitized tool provenance.
---

## Findings

- Card 7 requires bounded tool provenance that can answer who requested a tool, what ran, what failed, and which run/trace it belongs to.
- The runtime coverage map flagged `Phase4Bridge.perceive(appName:depth:)` as high risk because it returns raw Screen2AX accessibility JSON and OCR-derived text to the caller.
- Existing code returned raw perception results to the bridge caller; the slice must not persist that raw AX tree, OCR text, app names, or raw depth strings into AgentEvents.
- The smallest safe slice is instrumentation around `perceive(appName:depth:)` plus a new focused behavior/source guard test file. `interact` and `screen_watch` stay separate.

## Open questions

- None for this slice. `Phase4Bridge.interact(actionJson:)` and `startScreenWatch(watchJson:)` remain open follow-up bridge provenance slices.

## Recommendation

Record requested, started, and terminal completed/failed AgentEvents around the existing perception call, using only bounded depth classes, app-scope class, method, scalar counts, duration, success status, and closed failure classes. Preserve existing returned payloads.
