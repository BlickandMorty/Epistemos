# SS-HF — No hidden fallbacks / de-black-box: every substitution visible AT POINT OF USE (2026-06-20)

Owner: *"I didn't want hidden fallbacks — if it is a fallback make sure it is not one of the stubborn ones, or any at all. idk
what you mean by 'fallback' — but that's important, that's part of the repair: the hiddenness of the app and black-box
surfaces."* This formalizes the CLAUDE.md NON-NEGOTIABLE ("no hidden fallback, no silent substitution, honest capability
gating") into a repair discipline + a chat-surface refinement. Part of the deep repair cycle (SS-REPAIR), gated by SS-CLEAN.

## Plain definition (for the owner)
A "fallback" = when the thing you picked/expected can't run, the app uses a different runnable thing instead. It is NOT a
fake/mask. The RULE: a fallback is acceptable ONLY if it is **honest + visible at the point of use** — the user can SEE that a
substitution happened and what's actually running — and NEVER silent/hidden/black-box. (The chat P0 fix runs your REAL
installed Qwen when the picked model isn't installed — a real model, not a stub — but it must SHOW you that, in the chat.)

## The gap to fix (chat substitution is surfaced too quietly)
- The chat P0 fix (191c9291a) substitutes the installed Qwen when the picked (uninstalled) model can't run, and marks it
  "visible via `LocalRouteHonestyHealthRow`" (`InferenceState.swift:4196/4286`). But that's a SETTINGS health row — the user
  sending a chat does NOT see, at the chat, that their pick was swapped → effectively hidden at the point of use.
- The architecture intent is already right elsewhere: `RuntimeRouter` "advances to the next lane + logs an honest escalation
  entry — never a silent fallback" (`RuntimeRouter.swift:13-14`), and InferenceState documents "not a silent swap" (`:4196`).
  So the fix is to SURFACE it where the user is, not to add new logic.

## Fix (de-black-box the chat substitution) [S→M]
1. **Surface the ACTUAL running model in the chat, at point of use:** the runtime pill / composer shows the model that will
   actually run; when it DIFFERS from the explicit pick (pick uninstalled → running Qwen), show a small honest, non-alarming
   note inline ("running Qwen — '<pick>' isn't installed", with a tap → install/pick). One-line, pixel-art, dismissible.
   Not a buried Settings row. (Cross-ref SS-CC composer minimalism — fold into the one runtime control.)
2. **AnswerPacket already carries route honesty** (residency_signals / attention_mode) — ensure the chat reflects the packet's
   actual route, so the surface and the receipt agree.

## Broader sweep — find + de-black-box ALL hidden fallbacks / silent surfaces (repair cycle)
Audit the app for places that silently substitute/degrade/swallow without telling the user, and make each honest at point of
use (or remove the silent path):
- model/runtime routing (RuntimeRouter lanes, cloud↔local escalation, tier degradation) — honest escalation visible, not just
  logged.
- recall/tools/Eidos returning empty when a backend isn't ready (SS-IR/SS-LT) — show "not ready", never a silent no-op.
- `try?` / `?? default` / empty-catch on USER-VISIBLE paths that hide a failure as success (audit; surface the failure).
- any "for show" control that does nothing (SS-GE book/cowork, dead toggles) — wire or remove (SS-CLEAN dead-flag).
- substrate honesty rows must reflect REAL state (already the discipline) — extend that honesty to the live surfaces, not just
  the Settings panel.

## Gate (add to SS-CLEAN)
**NO-HIDDEN-FALLBACK / POINT-OF-USE-HONESTY gate:** any fallback / substitution / degradation / capability-gating must be
VISIBLE to the user AT THE SURFACE where it happens (not only a Settings/health row, not only a log) — or it's a hidden
black-box surface to fix. A "honest" fallback names what's running + why; a silent one is a bug. Pairs with capability-surface-
parity + done-re-audit. NON-INVASIVE; honest > clever. Cross-ref SS-REPAIR, SS-CC, SS-CR, SS-IR, SS-LT, SS-GE.
