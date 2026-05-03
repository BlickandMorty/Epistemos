---
role: codex-red-team
slice: sovereign-gate-notes-vault-disconnect-pr11
brief: docs/fusion/deliberation/sovereign_gate_notes_vault_disconnect_pr11_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 4
p0_attacks: 0
p1_attacks: 0
p2_attacks: 4
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Claude returned actionable issues; this fallback packet mirrors the non-blocking mitigations after brief revision.
---

## Attacks

### A1 - Vault URL must be captured and rechecked after auth [P2]
**Surface:** `VaultConnectionButton` menu action.
**Attack:** If the menu action only authenticates and then disconnects whatever vault is current after `await`, a fast vault switch could disconnect a newer vault context.
**Evidence:** Card 9 PR7-PR10 already hardened captured destructive targets before async auth.
**Mitigation proposed:** Pass the concrete `vaultURL` into `requestVaultDisconnectAuthorization(vaultURL:)` and verify `vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL` before calling disconnect.

### A2 - Do not move vault teardown semantics into the view [P2]
**Surface:** `NotesSidebar.swift` and `VaultConnectionActions.disconnect`.
**Attack:** A patch could duplicate disconnect logic in the view while adding the gate, creating drift from the centralized vault teardown path.
**Evidence:** Existing code centralizes the teardown sequence in `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.
**Mitigation proposed:** Keep the original helper unchanged and call it only after the shared gate returns `.allowed`.

### A3 - Missing gate must deny [P2]
**Surface:** `requestVaultDisconnectAuthorization(vaultURL:)`.
**Attack:** Optional `AppBootstrap.shared` access can accidentally become an auth bypass if a future edit falls through on nil.
**Evidence:** Claude Red Team A1.
**Mitigation proposed:** Use a nil-coalesced denied outcome and return unless outcome is `.allowed`.

### A4 - Re-entrant taps need a guard [P2]
**Surface:** `Button("Disconnect Vault", role: .destructive)`.
**Attack:** Repeated taps can start multiple auth prompts unless the request is guarded.
**Evidence:** PR8 used an in-flight guard for vault disconnect in RootView.
**Mitigation proposed:** Add a local `@State` in-flight flag with `guard`, `defer`, and `.disabled(...)`.

## Brief Verdict

Approve the revised brief. Keep the patch to `NotesSidebar.swift` plus focused SovereignGate tests and docs.
