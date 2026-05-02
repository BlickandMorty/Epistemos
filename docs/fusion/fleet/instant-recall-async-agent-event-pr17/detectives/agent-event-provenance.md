---
role: detective
slice: instant-recall-async-agent-event-pr17
concept: AgentEvent provenance hardening
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md section 2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:189
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:477
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/InstantRecallTests.swift:316
deliberations_consulted:
  - docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "Future live emission must be additive instrumentation only"
  code_says: "[paraphrase] sync search is instrumented; async search is not."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift
load_bearing_quote: "Future live emission must be additive instrumentation only"
verdict: open
usefulness: +1
usefulness_reason: Confirms PR17 is allowed only as additive AgentEvent instrumentation with no routing, UI, schema, or projection changes.
---

## Findings
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:807` frames Card 7 as durable agent/tool provenance, not UI behavior or tool execution.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:889` explicitly allows future InstantRecall paths beyond sync search including `searchAsync(query:topK:)` after a fresh gate.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:912` requires additive instrumentation only for future live emission.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:914` forbids projecting AgentEvents into OpLog, GraphEvent, Halo, Theater, or ReplayBundle.
- `InstantRecallService.swift:401` records sync recall events with tool name `instant_recall.search`; PR17 should preserve the same taxonomy and distinguish async through run/tool ids plus `surface`.

## Open questions
- Whether async decode failures should become failed AgentEvents even though the public async API returns `[]`; recommendation is yes by returning an internal outcome from the detached helper.

## Recommendation
Approve a narrow Core PR17 that emits requested/started/completed-or-failed AgentEvents around valid `searchAsync(query:topK:)` calls. Persist only counts, timing, topK, source/surface, and failure class. Keep query text, note ids, note bodies, result text, snippets, vault paths, Halo/ShadowSearch/editor/graph state, and Rust FFI payloads out of persisted provenance.
