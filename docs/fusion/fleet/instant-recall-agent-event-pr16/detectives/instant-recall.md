---
role: detective
slice: instant-recall-agent-event-pr16
concept: InstantRecall sync recall search
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §5
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:189
  - /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/InstantRecallService.swift:477
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/InstantRecallTests.swift:316
deliberations_consulted:
  - docs/fusion/deliberation/agent_query_engine_agent_event_pr15_deliberation_2026_05_02.md
quick_capture_consulted: false
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "25ms end-to-end recall latency budget."
  code_says: "[paraphrase] Focused tests keep first search under 50ms and preserve topK."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/EpistemosTests/InstantRecallTests.swift:191
load_bearing_quote: "25ms end-to-end recall latency budget."
verdict: partial
usefulness: +1
usefulness_reason: Confirms InstantRecall is canonical recall infrastructure but only sync search is safe for this PR.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` names `InstantRecallService.swift` as the Swift fallback for Halo / Contextual Shadows / Recall.
- `InstantRecallService.swift:189` is a synchronous recall query that already mutates search metrics, making it safer for additive provenance than ambient async recall.
- `InstantRecallService.swift:477` is the async search path. PR16 intentionally leaves it untouched because that path feeds ambient recall and needs a latency/sampling gate.
- `InstantRecallTests.swift:316` now proves sync recall emits sanitized lifecycle AgentEvents without leaking query text, note ids, or note bodies.

## Open questions
- Should future ambient recall provenance be sampled, disabled by default, or aggregated? That is outside PR16 and should be its own gate.

## Recommendation
Instrument only `InstantRecallService.search(queryText:topK:)` with an injectable recorder and bounded payloads. Keep `searchAsync(query:topK:)`, ShadowSearch, Halo, editor, and graph untouched.
