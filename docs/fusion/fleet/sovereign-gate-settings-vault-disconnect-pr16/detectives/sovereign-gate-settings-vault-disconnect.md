---
role: detective
slice: sovereign-gate-settings-vault-disconnect-pr16
concept: Sovereign Gate Settings vault disconnect migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:3072
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:796
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_settings_workspace_delete_pr15_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: true
  canon_says: "Future confirmation-surface migration PRs only after a gate names each exact existing surface"
  code_says: "[paraphrase] Settings Vault Disconnect directly called VaultConnectionActions.disconnect(notesUI:vaultSync:)."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift
load_bearing_quote: "The Sovereign Gate is the only place in the codebase that calls `LocalAuthentication`."
verdict: open
usefulness: +1
usefulness_reason: Names the remaining Settings vault disconnect path that was still bypassing SovereignGate.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` points destructive biometric gating to the single Sovereign Gate canon.
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2` requires destructive popups and footings to flow through one Sovereign Gate, not per-dialog biometric policy.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 allows exact future confirmation-surface migrations with focused tests.
- `Epistemos/Views/Settings/SettingsView.swift:3072` was an exact Core destructive surface: the Settings Vault `Disconnect` button disconnected the active vault through `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.
- `EpistemosTests/SovereignGateTests.swift:796` is the focused suite location for adjacent Settings destructive action source guards.

## Open questions

- None for implementation. Treat this as a Core destructive action because it disconnects the active local vault.

## Recommendation

Authorize a narrow Settings PR16 that adds `vaultDisconnect(name:)` to `SettingsViewDestructiveActionSovereignGate.Target`, routes the Vault `Disconnect` button through the shared `AppBootstrap` `SovereignGate`, disables duplicate clicks while authorization is in flight, rechecks the active vault URL after authorization, and only then calls the existing disconnect helper.
