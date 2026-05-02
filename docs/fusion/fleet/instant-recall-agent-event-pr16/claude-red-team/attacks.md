---
role: claude-red-team
slice: instant-recall-agent-event-pr16
brief: docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 3
p0_attacks: 0
p1_attacks: 0
p2_attacks: 3
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Tightens privacy, ambient-hot-path, and dirty-tree staging requirements before code begins.
---

## Attacks

### A1 - Recall payloads can leak user content [P2]
**Surface:** `InstantRecallService.search(queryText:topK:)` arguments/result recording.
**Attack:** Query text, note ids, note bodies, snippets, and result text are all sensitive vault content. Persisting any of them would turn provenance into a recall-content leak.
**Evidence:** `InstantRecallService.swift:241` passes raw query text to Rust, and `InstantRecallService.swift:322` decodes result dictionaries containing doc ids and text.
**Mitigation proposed:** Persist only query length/count, topK, hit count, document count, elapsed milliseconds, source/surface, and failure class. Tests must assert query text, note ids, and note bodies are absent from every AgentEvent.

### A2 - Ambient recall hot path can become noisy [P2]
**Surface:** `InstantRecallService.searchAsync(query:topK:)`.
**Attack:** Contextual Shadows / Halo ambient recall can fire frequently. Instrumenting async recall without sampling or a latency gate could create event spam and violate the recall budget.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md §5` ties recall to a 25ms budget; `InstantRecallService.swift:477` is the async search path.
**Mitigation proposed:** PR16 must leave `searchAsync(query:topK:)` untouched. Any future ambient recall provenance needs a separate gate with sampling, budget, and log-volume acceptance.

### A3 - Whole-worktree dirty scope can make a clean slice unsafe [P2]
**Surface:** Commit boundary.
**Attack:** The repository has unrelated dirty files under generated bindings, build outputs, docs, graph, and other surfaces. A broad stage would violate the brief's forbidden write set.
**Evidence:** Round 11 worktree status remains dirty before exact staging.
**Mitigation proposed:** Exact-stage only PR16 files and run a staged protected-path scan before commit.

## Brief verdict
Ship the brief after enforcing the privacy tests, leaving async recall untouched, and exact-staging only the PR16 files. No P0/P1 blocker remains.
