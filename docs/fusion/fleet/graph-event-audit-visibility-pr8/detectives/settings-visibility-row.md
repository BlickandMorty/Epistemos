---
role: detective
slice: graph-event-audit-visibility-pr8
concept: Settings GraphEvent visibility row
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/graph_event_projection_visibility_pr5_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/GraphEventVisibilityRow.swift:1
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:1
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2643
deliberations_consulted:
  - docs/fusion/deliberation/graph_event_projection_visibility_pr5_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "`GraphEventVisibilityRow` now reads the PR4 consumer API once on appear/refresh"
  code_says: "[paraphrase] Settings row reads diagnostics and projection once on appear/refresh, no task loop"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/GraphEventVisibilityRow.swift
load_bearing_quote: "`GraphEventVisibilityRow` now reads the PR4 consumer API once on appear/refresh"
verdict: closed
usefulness: +1
usefulness_reason: Shows PR8 should extend the existing row, not touch SettingsView or add duplicate diagnostics.
---

## Findings
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1036` closes the existing Settings projection visibility row and forbids timers, `.task` loops, repair, Rust, OpLog, renderer, retrieval, Halo, or Theater side effects.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1081` lists `GraphEventVisibilityRow.swift` as an authority file for Card 8.
- `GraphEventVisibilityRow.swift:44` refreshes on `.onAppear` only; there is no timer, `.task`, polling, or mutation hook.
- `CognitiveSubstrateTests.swift:2643` already guards the row as read-only and mounted in Settings.

## Open questions
- None for this slice.

## Recommendation
Add one audit projection row to `GraphEventVisibilityRow.swift`, update the existing source guard, and leave `SettingsView.swift` untouched because the row is already mounted.
