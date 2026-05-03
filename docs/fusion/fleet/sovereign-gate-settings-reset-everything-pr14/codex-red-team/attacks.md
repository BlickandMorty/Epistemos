---
role: codex-red-team
slice: sovereign-gate-settings-reset-everything-pr14
brief: docs/fusion/deliberation/sovereign_gate_settings_reset_everything_pr14_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 4
p0_attacks: 0
p1_attacks: 0
p2_attacks: 4
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Hardens the slice around partial staging, nil-gate denial, and preserving the existing reset alert semantics.
---

## Attacks

### A1 — Dirty SettingsView hunk can accidentally ride along [P2]
**Surface:** `Epistemos/Views/Settings/SettingsView.swift`.
**Attack:** The file already contains an unrelated diagnostics hunk before PR14. A normal `git add SettingsView.swift` would commit unrelated user/previous-agent work with the reset gate.
**Evidence:** `docs/fusion/oversight/PREFLIGHT_36_2026_05_02.md`
**Mitigation proposed:** Partial-stage only the reset-everything hunk and verify `git diff --cached -- SettingsView.swift` excludes the diagnostics text/row changes.

### A2 — Nil shared gate must deny, not reset all data [P2]
**Surface:** New reset authorization helper.
**Attack:** Optional shared gate lookup must not become an accidental allow. If `AppBootstrap.shared` is nil, `resetAllData()` must not run.
**Evidence:** PR11 through PR13 use `?? .denied(.authenticationFailed)`.
**Mitigation proposed:** Require the nil-coalescing denial before `guard outcome == .allowed`.

### A3 — Keep existing alert as the first confirmation layer [P2]
**Surface:** Reset Everything button plus alert.
**Attack:** Moving the biometric prompt onto the first button would change UX by prompting before the existing explicit destructive alert.
**Evidence:** Current code opens `showResetAlert` first, then destructive alert action calls reset.
**Mitigation proposed:** Keep the initial `showResetAlert = true` button unchanged; route only the alert's destructive Reset action.

### A4 — Source guard must prove direct reset left the alert closure [P2]
**Surface:** `SovereignGateTests`.
**Attack:** Mapping tests alone can pass while the alert still calls `resetAllData()` directly.
**Evidence:** `SettingsView.swift` alert action currently calls `await AppBootstrap.shared?.resetAllData()`.
**Mitigation proposed:** Add source guards proving the alert calls `requestResetEverythingAuthorization()` and the direct reset call lives only in the post-auth helper.

## Brief verdict
Approved after A1 through A4 are incorporated.
