---
role: detective
slice: sovereign-gate-authority-reset-pr12
concept: Sovereign Gate authority reset and preset migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AuthoritySettingsView.swift:88
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AuthoritySettingsView.swift:165
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHarness/AgentAuthority.swift:127
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_core_pr1_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_approval_surface_pr3_deliberation_2026_05_02.md
quick_capture_consulted: false
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "Every confirmation surface in the app"
  code_says: "[paraphrase] Authority reset and preset buttons currently mutate policy without Sovereign Gate confirmation."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138
  code_path: /Users/jojo/Downloads/Epistemos/Views/Settings/AuthoritySettingsView.swift:98
load_bearing_quote: "Every confirmation surface in the app"
verdict: drift
usefulness: +1
usefulness_reason: Finds an ungated authority-policy reset/preset surface that fits Card 9's exact confirmation-migration lane.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` says Sovereign Gate's single entrypoint is `/Users/jojo/Downloads/Epistemos/Epistemos/Sovereign/SovereignGate.swift`; this slice must not import `LocalAuthentication` in the Settings view.
- `/Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138` explicitly includes "Settings footers" and "permission gates" in the confirmation-surface scope.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AuthoritySettingsView.swift:98` applies Quick Setup presets directly, and line 165 resets authority defaults directly.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHarness/AgentAuthority.swift:127` shows presets can rewrite several capability categories in one tap, including `lessInterruptions`.

## Open questions
- Individual picker changes remain out of this slice; they are not batch reset/preset footers and would need a separate UX gate if canon wants every single authority picker change gated.

## Recommendation
Gate the batch Authority Settings reset and Quick Setup preset buttons through the shared `AppBootstrap.shared?.sovereignGate.confirm(...)` path with `.deviceOwnerAuthentication`, preserve the existing reset/apply semantics after `.allowed`, deny safely when the shared gate is unavailable, and add source-guard tests proving no `LocalAuthentication` symbols enter the Settings view.
