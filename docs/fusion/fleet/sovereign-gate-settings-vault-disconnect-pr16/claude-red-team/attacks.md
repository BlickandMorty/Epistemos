---
role: claude-red-team
slice: sovereign-gate-settings-vault-disconnect-pr16
brief: docs/fusion/deliberation/sovereign_gate_settings_vault_disconnect_pr16_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Local fallback checked the main race and staging risks after the Claude CLI failed to return an artifact.
---

## Attacks

### A1 - Do not authorize a stale vault disconnect [P2]
**Surface:** `Epistemos/Views/Settings/SettingsView.swift` Settings > Vault `Disconnect` button.
**Attack:** The brief routes the destructive button through `SovereignGate`, but an implementation could capture one vault URL, wait for biometric authorization, then disconnect whatever vault is currently active if the user changed vaults while the prompt was open. That would be a user-visible correctness regression even though it is not a biometric bypass.
**Evidence:** `Epistemos/Views/Settings/SettingsView.swift:3147` implements `requestVaultDisconnectAuthorization(vaultURL:)`; the guardrail must require `vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL` before calling `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.
**Mitigation proposed:** Keep the stale-URL recheck in the authorized path, keep `.disabled(isVaultDisconnectAuthorizationInFlight)`, and keep the source guard in `SovereignGateTests`.

## Brief verdict

Approved. The implementation contains the denial fallback, duplicate-click guard, stale-vault guard, and no direct `LocalAuthentication`/`LAContext` calls in `SettingsView.swift`. No P0/P1 blockers remain.

CLAUDE-RETURN: role=RED-TEAM | slice=sovereign-gate-settings-vault-disconnect-pr16 | round=46 | artifact=docs/fusion/fleet/sovereign-gate-settings-vault-disconnect-pr16/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=0
