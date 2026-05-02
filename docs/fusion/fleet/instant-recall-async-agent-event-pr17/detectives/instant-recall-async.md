---
role: detective
slice: instant-recall-async-agent-event-pr17
concept: InstantRecall async recall search
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md section 5
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:466
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:477
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:492
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/InstantRecallTests.swift:209
deliberations_consulted:
  - docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "async recall, Halo, ShadowSearch, UI, approval, routing, graph, Rust"
  code_says: "[paraphrase] async recall uses Task.detached and returns results without metrics mutation or provenance."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift
load_bearing_quote: "InstantRecall paths beyond sync search including `searchAsync(query:topK:)`"
verdict: open
usefulness: +1
usefulness_reason: Identifies the exact async seam and confirms it is the intended PR17 target.
---

## Findings
- `InstantRecallService.swift:466` documents async recall as the off-MainActor Contextual Shadows path.
- `InstantRecallService.swift:477` validates readiness, normalized query text, positive topK, and hydration before detached search.
- `InstantRecallService.swift:492` is the detached helper that can classify JSON/decode failures internally without changing the public async return type.
- `InstantRecallTests.swift:209` already proves async search triggers lazy hydration and returns hydrated results.
- `InstantRecallTests.swift:316` provides the sync AgentEvent privacy/assertion pattern PR17 should mirror.

## Open questions
- Async search intentionally does not mutate `lastResults`, `searchCount`, or latency metrics. PR17 must preserve that behavior.

## Recommendation
Instrument `searchAsync(query:topK:)` after validation and before detached search. Use `instant-recall-async-<UUID>` run ids, `instant-recall-search-async:N` tool call ids, `instant_recall.search` tool name, and `surface=instant_recall_async`. Add an internal async outcome so decode failures can record failed events without changing public behavior.
