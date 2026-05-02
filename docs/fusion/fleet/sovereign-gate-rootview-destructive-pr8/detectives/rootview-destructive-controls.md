---
role: detective
slice: sovereign-gate-rootview-destructive-pr8
concept: RootView destructive controls
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:271
  - /Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:280
  - /Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:1754
  - /Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:1794
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:336
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "gate names each exact existing surface and its focused tests"
  code_says: "[paraphrase] RootView had two exact destructive buttons not yet named in Card 9."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift
load_bearing_quote: "gate names each exact existing surface and its focused tests"
verdict: drift
usefulness: +1
usefulness_reason: Narrows PR8 to two named RootView controls and excludes unrelated vault/database semantics.
---

## Findings
- Card 9 allows future confirmation-surface migrations only when the exact existing surface and focused tests are named.
- [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:271) database reset is an existing destructive alert action.
- [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:1794) vault disconnect is an existing destructive recovery overlay action.
- [SovereignGateTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:336) is the focused source-guard suite that can prove the routing without invoking real Touch ID.

## Open questions
- None. The slice should not rename alert copy, alter database recovery behavior, or change vault recovery state.

## Recommendation
Authorize an exact two-surface migration in `RootView.swift`, using a tiny mapper for destructive requirements/reasons and source guards that prove both direct destructive closures moved behind `AppBootstrap.shared?.sovereignGate.confirm(...)`.
