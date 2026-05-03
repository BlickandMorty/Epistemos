---
role: codex-red-team
slice: sovereign-gate-authority-reset-pr12
brief: docs/fusion/deliberation/sovereign_gate_authority_reset_pr12_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 4
p0_attacks: 0
p1_attacks: 0
p2_attacks: 3
p3_attacks: 1
verdict: brief-approved
usefulness: +1
usefulness_reason: Tightens the implementation to cover Quick Setup bypasses, nil-gate denial, and direct mutation source guards.
---

## Attacks

### A1 — Quick Setup can bypass footer-only reset gating [P2]
**Surface:** `AuthoritySettingsView.quickSetupCard`.
**Attack:** If the patch only gates the footer button, the `Recommended` Quick Setup button can still rewrite policy to the default posture and `Less Interruptions` can loosen multiple categories in one tap. The brief should require all batch Quick Setup presets to pass through the same gate.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AuthoritySettingsView.swift:98`
**Mitigation proposed:** Route Quick Setup buttons through `requestQuickSetupAuthorization(_:)` before any call to the existing apply logic.

### A2 — Nil shared gate must deny, not mutate [P2]
**Surface:** New async authorization helpers.
**Attack:** Optional chaining on `AppBootstrap.shared?.sovereignGate.confirm(...)` can otherwise produce `nil`; if implementation unwraps incorrectly, unavailable gate could become an accidental allow.
**Evidence:** `Sovereign Gate PR11` established the `?? .denied(.authenticationFailed)` pattern.
**Mitigation proposed:** Require the nil-coalescing denial in both reset and preset authorization helpers.

### A3 — Source guards must prove direct mutation left button closures [P2]
**Surface:** `SovereignGateTests`.
**Attack:** Mapping tests alone can pass while the UI still calls `store.reset()` or `applyPreset(preset)` directly from button closures.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AuthoritySettingsView.swift:98` and `:165`
**Mitigation proposed:** Add source guards for `requestQuickSetupAuthorization(preset)` and `requestResetToDefaultsAuthorization()`, plus section checks that direct mutation does not occur inside those button closures.

### A4 — Individual pickers remain outside this slice [P3]
**Surface:** `authorityPicker(for:)`.
**Attack:** Picker changes still write individual category policy immediately. This may be acceptable because the current slice is batch reset/preset only, but the limitation should stay explicit.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AuthoritySettingsView.swift:136`
**Mitigation proposed:** Document that individual picker gating is out of scope and would require a separate UX gate.

## Brief verdict
Approved after the implementation incorporates A1 through A3. A4 is a scope note, not a blocker.
