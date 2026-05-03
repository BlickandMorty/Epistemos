---
role: codex-red-team
slice: sovereign-gate-overseer-history-reset-pr13
brief: docs/fusion/deliberation/sovereign_gate_overseer_history_reset_pr13_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 3
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 1
verdict: brief-approved
usefulness: +1
usefulness_reason: Tightens the implementation around programmatic clear callers, nil-gate denial, and direct footer mutation guards.
---

## Attacks

### A1 — Programmatic workspace hygiene must not become gated [P2]
**Surface:** `OverseerAuditState.clear()`.
**Attack:** `clear()` is documented as also used during workspace switches. Moving the gate into the state object would break non-UI hygiene and conflate user confirmation with lifecycle cleanup.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/State/OverseerAuditState.swift:40`
**Mitigation proposed:** Keep `OverseerAuditState.swift` untouched and gate only the `OverseerSettingsView` footer button.

### A2 — Nil shared gate must deny, not clear history [P2]
**Surface:** New async authorization helper.
**Attack:** Optional shared gate lookup must not become an accidental allow. If `AppBootstrap.shared` is nil under previews/tests, the footer should do nothing.
**Evidence:** PR11 and PR12 patterns use `?? .denied(.authenticationFailed)`.
**Mitigation proposed:** Require `?? .denied(.authenticationFailed)` before `guard outcome == .allowed`.

### A3 — Source guard needs to prove button closure lost direct clear [P3]
**Surface:** `SovereignGateTests`.
**Attack:** Mapping tests alone can pass while the footer button still calls `audit.clear()` directly.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/OverseerSettingsView.swift:96`
**Mitigation proposed:** Add source guards proving the footer calls `requestHistoryResetAuthorization()` and the direct `audit.clear()` call lives only behind the authorization helper.

## Brief verdict
Approved after A1 through A3 are incorporated.
