---
role: detective
slice: sovereign-gate-overseer-history-reset-pr13
concept: Sovereign Gate Overseer audit history reset migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/OverseerSettingsView.swift:86
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/OverseerSettingsView.swift:96
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/OverseerAuditState.swift:40
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_authority_reset_pr12_deliberation_2026_05_02.md
quick_capture_consulted: false
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "Every confirmation surface in the app"
  code_says: "[paraphrase] Overseer Settings reset-history footer clears audit entries without Sovereign Gate confirmation."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/OverseerSettingsView.swift:96
load_bearing_quote: "Every confirmation surface in the app"
verdict: drift
usefulness: +1
usefulness_reason: Finds an ungated Settings footer that clears diagnostic audit history and can be migrated without protected-path changes.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` anchors this as a Sovereign Gate confirmation-surface migration.
- `/Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138` explicitly includes Settings footers in the one-gate scope.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/OverseerSettingsView.swift:96` currently calls `audit.clear()` directly from the "Reset history" footer.
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/OverseerAuditState.swift:40` says `clear()` is also used during workspace switches; this slice should gate only the user-facing Settings footer, not programmatic lifecycle cleanup.

## Open questions
- None for this slice. Programmatic workspace-switch clearing remains out of scope.

## Recommendation
Add a tiny `OverseerSettingsSovereignGate` mapping and route the visible "Reset history" footer through the shared `AppBootstrap.shared?.sovereignGate.confirm(...)` path. Preserve `OverseerAuditState.clear()` semantics, deny safely if the shared gate is unavailable, and add focused source-guard tests.
