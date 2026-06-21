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

## PRIORITY
P0 — owner-reported, recurring, chat-core. Preempts the queue after the loop's current in-flight commit lands.
Add to OWNER_REQUESTS_LEDGER as a top P0; do NOT mark [x] until the real-state test + reach-the-user proof exist.
