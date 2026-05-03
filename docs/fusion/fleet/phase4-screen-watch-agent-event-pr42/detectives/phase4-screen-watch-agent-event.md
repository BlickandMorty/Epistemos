---
role: detective
slice: phase4-screen-watch-agent-event-pr42
concept: Phase4 screen_watch AgentEvent provenance
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
  - docs/fusion/deliberation/phase4_screen_watch_agent_event_pr42_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "what failed, and which run/trace it belongs to"
  code_says: "[paraphrase] Phase4 screen_watch existed but lacked bounded AgentEvent provenance before PR42."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift
load_bearing_quote: "what failed, and which run/trace it belongs to"
verdict: open
usefulness: +1
usefulness_reason: Identified the remaining Phase4 watch bridge as a high-risk runtime surface missing sanitized lifecycle provenance.
---

## Findings

- Card 7 requires bounded tool provenance that answers who requested a tool, what ran, what failed, and which run/trace it belongs to.
- `Phase4Bridge.startScreenWatch(watchJson:)` polls for AX presence, file existence, file modification, or timeout sleep semantics.
- The watch loop must not persist raw watch JSON, file paths, target strings, bundle ids, raw AX payloads, localized descriptions, or arbitrary errors into AgentEvents.
- The smallest safe slice is lifecycle-only instrumentation around `startScreenWatch(watchJson:)` plus a focused behavior/source guard test file. Per-poll and per-frame telemetry is explicitly out of scope.

## Open questions

- None for this slice. Broader Computer Use and Phase4 perceive/interact provenance are already closed in PR39, PR40, and PR41.

## Recommendation

Record requested, started, and terminal completed/failed AgentEvents around existing screen-watch behavior, using bounded mode classes, app/target scopes, timeout and poll-interval buckets, duration, triggered state, reason classes, and closed failure classes. Preserve the returned watch response shape for callers.
