---
role: claude-red-team
slice: sovereign-gate-rootview-destructive-pr8
brief: docs/fusion/deliberation/sovereign_gate_rootview_destructive_pr8_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 3
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 2
verdict: brief-approved
usefulness: +1
usefulness_reason: Red team found one UI recovery regression and one duplicate-prompt hardening issue; both were fixed before commit.
---

## Attacks

### A1 - Denied reset auth dismisses the recovery alert [P2]
**Surface:** [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:269)
**Attack:** SwiftUI dismisses the database error alert as soon as "Reset Database" is clicked. Before revision, denied/cancelled/unavailable auth correctly avoided `onResetDatabase?()`, but the recovery alert stayed gone.
**Evidence:** Red-team explorer `019de9c4-5e54-7560-b463-66acb6e59c46`.
**Mitigation proposed:** Reopen the alert after denied auth when `databaseError` is still present.
**Resolution:** Addressed. `requestDatabaseResetAuthorization()` now restores `showDatabaseAlert = true` on denied auth while preserving reset execution only after `.allowed`.

### A2 - Vault disconnect can spawn duplicate auth requests [P3]
**Surface:** [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:1754)
**Attack:** The vault disconnect button had no auth-in-flight state, so rapid repeated clicks could create multiple device-owner prompts and repeated `disconnectAction()` calls if allowed.
**Evidence:** Red-team explorer `019de9c4-5e54-7560-b463-66acb6e59c46`.
**Mitigation proposed:** Add a local in-flight guard and disable the button while auth is pending.
**Resolution:** Addressed. `VaultRecoveryOverlay` now tracks `isVaultDisconnectAuthorizationInFlight`, guards duplicate requests, resets the flag with `defer`, and disables the button while pending.

### A3 - Source-shape coverage remains narrow [P3]
**Surface:** [SovereignGateTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:334)
**Attack:** The tests are intentionally source-shape guards, not a full runtime UI simulation. This is acceptable for the narrow slice but brittle if RootView structure changes.
**Evidence:** Red-team explorer `019de9c4-5e54-7560-b463-66acb6e59c46`.
**Mitigation proposed:** Strengthen the source guards to include the denied-auth recovery and duplicate-click guard strings.
**Resolution:** Addressed for this slice. The focused source guards now prove alert restoration and vault disconnect in-flight protection.

## Brief verdict

Ship the brief. No P0/P1 blockers were found. The P2/P3 findings were useful and are addressed in code and tests before commit; remaining risk is the accepted source-shape nature of this narrow Core guard.
