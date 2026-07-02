---
id: 09FAF8C3-829B-4E0D-976F-B462D6665F25
title: SS-CHATPICKER_P0_INSTALLED_MODELS_NOT_CLICKABLE_2026_06_21
---

# SS-CHATPICKER P0 — "other models installed but they still won't let me click them" (owner 2026-06-21)

Owner (verbatim, 2026-06-21): **"i also have other models installed but they still wont let me click them"**
Context: this is the SAME chat surface the owner has reported ~5+ times ("chat keeps defaulting to qwen / stays
gemma", "everything about the chat is just not working"). The default-RESOLUTION half was fixed + proven
(SS-CHATMODEL_P0, ddbadf434). This is the *selection/reachability* half: the user cannot pick the models they
installed. Tie to [[SS-CHATMODEL_P0_EXISTING_INSTALL_DEFAULT_2026_06_21]] and the SS-FOLLOWON "reachable picker".

## GROUNDED ROOT CAUSE (traced 2026-06-21, monitor/last-auditor)
The chat runtime picker is built from a FIXED lineup, NOT from the user's installed/advertised models:

- `Epistemos/Engine/EpistemosRuntimePicker.swift` → `options(for:environment:)` assembles rows from ONLY:
  1. `EpistemosFoundationLineup.candidates(for: tier)` (hardcoded foundation models), plus
  2. `extraPicks` — a hardcoded 2-item list: `Qwen/Qwen3-4B-MLX-4bit`, `Qwen/Qwen3-8B-MLX-4bit`, plus
  3. (Fast tier only) Apple Intelligence.
  It NEVER reads `inference.installedLocalTextModelIDs`, `preparedLocalTextModelIDs`, or the advertised set the
  owner curates in `ModelStackSettingsView`. So any installed model outside that fixed lineup CANNOT appear as a
  selectable chat pick.

- Selectability gate (`gatedOption`): `isSelectable = installed && fits`, where
  `fits = LocalChatModelMemoryGate.fits(requiredGB: minimumMemoryGB, availableGB: freeMemoryGB)`
  (`availableGB + headroomGB(6) >= requiredGB`). Even for lineup models, a too-low free-memory reading makes the
  row non-selectable.

- Click path (`InlineRuntimePickerPanel.select`): `guard option.isSelectable else { onOpenSettings(); onPicked() }`
  — a non-selectable row does NOT select; it bounces to Settings. To the owner that reads as "won't let me click."
  Also: a successful pick always calls `setPreferredChatModelSelection(.localMLX(option.id))` — it assumes the
  MLX lane even for non-MLX picks (latent lane-mismatch; secondary).

- DISCONNECT: `ModelStackSettingsView` ("Toggle which models appear in the picker … this only controls picker
  visibility") curates an `advertisedIDs` set over the full retained catalog (`ModelStackAssembler.rows`), but the
  chat picker ignores `advertisedIDs` entirely. The owner toggles models to appear → the chat picker still shows
  only the hardcoded lineup + 2 Qwen. The settings promise and the chat picker DISAGREE.

## ACCEPTANCE BAR (PROVEN-DONE, real-state — see [[SS-PROVEN_DONE_DOCTRINE_2026_06_21]])
1. The chat runtime picker ENUMERATES the user's installed + advertised models (union of
   `installedLocalTextModelIDs` ∪ `preparedLocalTextModelIDs`, filtered/ordered by the advertised set), not just the
   fixed foundation lineup. Foundation lineup remains the default ordering when the user hasn't customized.
2. Every installed model the owner advertised is a CLICKABLE, selectable row (subject only to the honest memory
   gate) and picking it actually sets `preferredChatModelSelection` to that model + persists it.
3. The lane is correct per model: an MLX model → `.localMLX(id)`; a non-MLX/GGUF model is selected on its real
   lane (no silent assume-MLX). No hidden fallback — if a lane is unavailable (MAS GGUF), the row says so honestly
   instead of being silently unclickable with no reason.
4. REAL-STATE test: seed persisted `installedLocalTextModelIDs` with a non-lineup model + an advertised set →
   assert the picker yields a selectable Option for it and `select` persists that exact id. (Picker logic is pure
   `EpistemosRuntimePicker.options` over an injected `Environment` — trivially unit-provable WITHOUT the UI.)
5. End-to-end: the model the owner sees in ModelStack as installed+advertised appears + is clickable in the chat
   InlineRuntimePickerPanel. Witnessed via the pure-logic test + (optionally) computer-use; UI pixel is non-blocking.

## SCOPE / SAFETY
Additive: widen the picker's option source to honor the installed+advertised set; keep the foundation lineup as the 
ordered default. No change to default RESOLUTION (already proven). No vault writes. Regression guard: with NO
advertised customization + only lineup models installed, `options(...)` returns byte-identical rows to today (prove
in a test). In scope (`EpistemosRuntimePicker.swift`, `InlineRuntimePickerPanel.swift`, ModelStack assembler glue);
NOT off-limits (no new-model/70B/Companion).

## SIBLING P0 — TOO-LARGE → SILENT QWEN FALLBACK (owner 2026-06-21, verbatim)
Owner: **"it still auto-chooses qwen when its too large literally i keep saying to fix the fallbacks and they
are still there."** CONFIRMED still-live (my earlier SS-CHATMODEL "proven" fix only repaired the persisted-pref
MIGRATION; it never touched the runtime too-large path — honest correction, this was NOT done).

GROUNDED ROOT CAUSE (traced 2026-06-21):
- `Epistemos/State/InferenceState.swift:3072-3073` → `recommendedLocalTextModelID` is HARDCODED to `.qwen3_4B4Bit`.
- The too-large/constrained resolution chains through that Qwen anchor:
  `recommendedLocalTextModelID(for: conditions)` (3151) when `conditions.prefersConstrainedLocalModel`,
  `recommendedConstrainedLocalTextModelID` / `constrainedFallbackTextModelID`
  (`LocalModelInfrastructure.swift:2573`), and `smallerLocalTextModelID(than:)` (3076) all anchor on Qwen.
- Net: when the user's chosen model won't fit memory ("too large"), the runtime SILENTLY lands on Qwen — a
  hidden fallback (HARD-FLOOR / no-hidden-fallback violation the owner has reported ~5×).

OWNER DECISION (2026-06-21, AskUserQuestion): **KILL THE FALLBACK IN-PLACE — keep the chat, NO Osaurus/Act
pivot.** (Osaurus rewrite rejected: it's in the owner's own hard off-limits set + needs a MAS-blocked subprocess
server.) So fix the current chat surgically.

ACCEPTANCE (fallback half):
- "Too large to fit" NEVER silently substitutes a different model (esp. Qwen). It surfaces an HONEST, visible
  message at the point of use ("<model> needs ~N GB, won't fit with M GB free — choose a smaller model") and
  the user keeps control; no auto-swap.
- Remove/replace the hardcoded `.qwen3_4B4Bit` recommended anchor with an honest hardware-fit selection (or no
  silent default at all) so nothing routes to Qwen behind the user's back.
- REAL-STATE regression test that WOULD HAVE CAUGHT the report: seed a selected model that doesn't fit on the
  given memory → assert the resolver returns an honest blocked/visible state, NOT `.qwen3_4B4Bit` (and never any
  silent substitute). The resolver is `nonisolated`/pure over injected conditions → unit-provable headlessly.

## PRIORITY
P0 — owner-reported, recurring, chat-core. BOTH halves (picker enumeration + too-large silent-Qwen fallback) are
the same chat-model-resolution P0. Preempts the queue after the loop's current in-flight commit lands.
Add to OWNER_REQUESTS_LEDGER as a top P0; do NOT mark [x] until the real-state test + reach-the-user proof exist.