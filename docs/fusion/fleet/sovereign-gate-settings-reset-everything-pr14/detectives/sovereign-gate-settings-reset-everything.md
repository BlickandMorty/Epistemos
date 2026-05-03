---
role: detective
slice: sovereign-gate-settings-reset-everything-pr14
concept: Sovereign Gate Settings reset-everything migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:678
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:702
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_authority_reset_pr12_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_overseer_history_reset_pr13_deliberation_2026_05_02.md
quick_capture_consulted: false
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "Every confirmation surface in the app"
  code_says: "[paraphrase] Settings Reset Everything alert confirms with SwiftUI only, then calls resetAllData directly."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:702
load_bearing_quote: "Every confirmation surface in the app"
verdict: drift
usefulness: +1
usefulness_reason: Finds the broadest destructive Settings reset path still outside the shared Sovereign Gate.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` anchors the single-entrypoint rule for this biometric gate work.
- `/Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138` explicitly includes dangerous-action dialogs and Settings footers in the one-gate scope.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:678` opens a destructive "Reset Everything" flow and line 702 calls `resetAllData()` directly from the alert action.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift` already has an unrelated dirty diagnostics hunk; PR14 must partial-stage only the reset gate hunk if committed.

## Open questions
- None for the reset-everything path. Other dirty `SettingsView` key-clear/disconnect surfaces should stay out of this exact slice.

## Recommendation
Gate only the "Reset Everything" alert action through a tiny `SettingsViewDestructiveActionSovereignGate` mapping and shared `SovereignGate` confirmation. Preserve the existing alert presentation and `resetAllData()` behavior after `.allowed`, and keep unrelated diagnostics changes unstaged.
