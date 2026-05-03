---
role: detective
slice: sovereign-gate-settings-workspace-delete-pr15
concept: Sovereign Gate Settings saved-workspace destructive delete migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:645
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:672
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_settings_reset_everything_pr14_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: true
  canon_says: "Future confirmation-surface migration PRs only after a gate names each exact existing surface"
  code_says: "[paraphrase] Saved Workspace trash button directly calls workspaceService.deleteWorkspace(workspace)."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift
load_bearing_quote: "The Sovereign Gate is the only place in the codebase that calls `LocalAuthentication`."
verdict: open
usefulness: +1
usefulness_reason: Names an exact Core destructive Settings surface still bypassing SovereignGate.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` says Sovereign Gate is the single biometric entrypoint; `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` repeats that `LocalAuthentication` must stay confined to `Epistemos/Sovereign/SovereignGate.swift`.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1760` permits future migration PRs only when the exact surface and focused tests are named.
- `Epistemos/Views/Settings/SettingsView.swift:645` has a destructive Saved Workspace trash button that directly calls `AppBootstrap.shared?.workspaceService.deleteWorkspace(workspace)` before refreshing.
- `EpistemosTests/SovereignGateTests.swift:672` already source-guards the adjacent Settings Reset Everything flow, so this slice can extend the same test suite without adding a new harness.

## Open questions

- None for implementation. Treat this as a Core destructive action because the accessibility hint says it permanently removes a saved workspace.

## Recommendation

Authorize a narrow Settings PR15 that extends `SettingsViewDestructiveActionSovereignGate.Target` with `savedWorkspace(name:)`, routes the Saved Workspace trash button through `AppBootstrap.shared?.sovereignGate.confirm(.deviceOwnerAuthentication, reason:)`, and only calls the existing delete/refresh path after `.allowed`.
