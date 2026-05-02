---
role: detective
slice: agent-grep-agent-event-pr14
concept: AgentGrep search lifecycle
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentGrepService.swift
sister_sources:
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentGrepServiceTests.swift
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentGrepService.swift:160
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentGrepServiceTests.swift:143
deliberations_consulted:
  - docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Future live-emission PRs must write a failing test first for the selected path"
  code_says: "[paraphrase] PR14 red log failed before implementation; green log passed after instrumentation"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentGrepServiceTests.swift
load_bearing_quote: "Future live-emission PRs must write a failing test first"
verdict: closed
usefulness: +1
usefulness_reason: Confirms the exact clean chokepoint and privacy requirements for PR14.
---

## Findings
- `AgentGrepService.swift:160` owns the single `search(query:kindFilter:limit:)` chokepoint for backend search plus sidecar enrichment.
- `AgentGrepService.swift:208` still returns full `AgentGrepHit` values to the caller, but PR14 AgentEvents persist only bounded counts and filters.
- `AgentGrepServiceTests.swift:143` proves requested/started/completed provenance and rejects query, path, snippet, run id, and tool-use id leakage.
- `AgentGrepServiceTests.swift:198` proves requested/started/failed provenance on backend error without persisting query text.

## Open questions
- None for this slice.

## Recommendation
Approve PR14 as a Core additive instrumentation slice around `search(...)` only. Do not instrument indexing, unindexing, UI, graph, Rust, generated bindings, provider routing, approvals, or other agent surfaces.
