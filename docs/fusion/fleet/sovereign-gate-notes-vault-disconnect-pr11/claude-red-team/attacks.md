---
role: claude-red-team
slice: sovereign-gate-notes-vault-disconnect-pr11
brief: docs/fusion/deliberation/sovereign_gate_notes_vault_disconnect_pr11_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 7
p0_attacks: 2
p1_attacks: 3
p2_attacks: 1
p3_attacks: 1
verdict: brief-revise
usefulness: +1
usefulness_reason: Claude surfaced real nil-deny, TOCTOU, and re-entrant-tap hazards that must be closed before implementation.
---

## Attacks

### A1 - Optional-chain nil-bypass [P0]
**Surface:** `requestVaultDisconnectAuthorization(vaultURL:)`.
**Attack:** If `AppBootstrap.shared?.sovereignGate` is nil and the call site falls through, the destructive disconnect can bypass auth.
**Evidence:** Brief acceptance says denied safely by default but must force a concrete nil fallback.
**Mitigation proposed:** Use `await AppBootstrap.shared?.sovereignGate.confirm(...) ?? .denied(.authenticationFailed)` and return unless outcome is `.allowed`.

### A2 - TOCTOU vault URL race [P1]
**Surface:** `VaultConnectionButton` menu action.
**Attack:** A vault switch during biometric delay could make the authorized code disconnect a newer vault context if the captured URL is not rechecked after auth.
**Evidence:** Brief requires capture but must prove post-auth comparison.
**Mitigation proposed:** Capture `vaultURL`, make the request method `@MainActor`, and verify `vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL` after `.allowed`.

### A3 - Re-entrant tap can start double auth [P1]
**Surface:** `Button("Disconnect Vault", role: .destructive)`.
**Attack:** Repeated taps before the auth prompt appears can create concurrent prompts and duplicate disconnect attempts.
**Evidence:** Existing PR8 root disconnect added an in-flight guard for the same class of action.
**Mitigation proposed:** Add `@State private var isVaultDisconnectAuthorizationInFlight`, guard it at request entry, reset it with `defer`, and disable the menu item while in flight.

### A4 - Device-owner policy semantics need to stay doctrine-aligned [P2]
**Surface:** Requirement mapping.
**Attack:** `.deviceOwnerAuthentication` allows Touch ID, watch unlock, or passcode/password depending on host. This is acceptable only if the slice classifies the action as Destructive rather than Sovereign.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` reserves Secure Enclave/Sovereign-class routes for future Pro/Research work.
**Mitigation proposed:** Keep this Core slice at `.deviceOwnerAuthentication`; do not claim Secure Enclave sealing or Sovereign-class auth.

### A5 - Forbidden grep should include broader LocalAuthentication symbols [P1]
**Surface:** Source guard.
**Attack:** A grep limited to `LAContext|canEvaluatePolicy|evaluatePolicy` can miss `LAError`, `LABiometryType`, `LAPolicy`, or `import LocalAuthentication`.
**Evidence:** `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.2` forbids local biometric surfaces outside the gate.
**Mitigation proposed:** Source guard should include `LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy`.

### A6 - Future direct disconnect call sites remain structurally possible [P3]
**Surface:** `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.
**Attack:** A later call site could bypass the gate unless future source guards check direct calls.
**Evidence:** Existing code centralizes teardown but does not encode auth in the helper.
**Mitigation proposed:** This slice should source-guard the current Notes Sidebar call site; future gates should repeat direct-call greps.

### A7 - Real biometric runtime path remains manual [P3]
**Surface:** Focused tests.
**Attack:** Mock/source tests cannot exercise real `LAContext` UI timing.
**Evidence:** Manual app testing is intentionally deferred by current user instruction.
**Mitigation proposed:** Keep focused source guards now and leave real Touch ID verification for the later manual/runtime gate.

## Brief Verdict

Revise before implementation. The brief is acceptable only if it requires nil-deny fallback, main-actor post-auth URL recheck, re-entrant in-flight guard, and broader biometric-symbol source guards.

CLAUDE-RETURN: role=RED-TEAM | slice=sovereign-gate-notes-vault-disconnect-pr11 | round=33 | artifact=docs/fusion/fleet/sovereign-gate-notes-vault-disconnect-pr11/claude-red-team/attacks.md | usefulness=+1 | p0=2 | p1=3
