---
role: detective
slice: sovereign-gate-version-delete-pr7
concept: DiffSheet version delete
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:218
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:559
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_notes_delete_pr5_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_chat_delete_pr6_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "Every confirmation surface in the app"
  code_says: "[paraphrase] Button(role: .destructive) calls deleteSelectedVersion() without shared gate."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:218
load_bearing_quote: "Button(role: .destructive)"
verdict: open
usefulness: +1
usefulness_reason: Names the exact UI path and existing focused test suite to extend.
---

## Findings
- [DiffSheetView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:218) exposes the exact destructive surface: `Button(role: .destructive)`.
- [DiffSheetView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:559) keeps deletion rollback local by reinserting the version on save failure.
- [RuntimeValidationTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift:3581) already source-checks the delete rollback invariant.
- [SovereignGateTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:232) already tests PR5/PR6 destructive mapper semantics.

## Open questions
- None; this can be tested as a mapper-level red/green without invoking real Touch ID.

## Recommendation
Add a DiffSheet-specific mapper tested in `SovereignGateTests`, route the menu action through async shared gate confirmation, and leave `deleteSelectedVersion()` rollback semantics unchanged for existing runtime validation tests.
