# SS-TC — Custom themes: granular text/accent/surface color control (2026-06-20)

Owner: *"one part of the custom themes is that there is no proper section for text color — I have text color of the
[body] font and the user bubbles and it only changes to the user bubble. on dark mode if I turn the text to white it
has white properly on the text editor but the user bubble in chat is also white. I want to be able to change that color
as well — make it more granular: a few more accessory colors and accents and surfaces I can control. Right now it's
working perfectly, just that one thing should have added granular color selections."* Code-grounded. ADDITIVE + DEFAULTED
(no regression to existing themes). Cross-ref EpistemosTheme.

## Root cause — the conflation (custom-theme path only; presets are fine)
`userBubbleText` ALREADY exists as a distinct runtime field in `ResolvedTheme` (`Theme/EpistemosTheme.swift:136`), and
`MessageBubble` already reads it via override (`Views/Chat/MessageBubble.swift:211` `foregroundOverride: theme.userBubbleText`;
flows to `MarkdownTextView.swift:1009`). PRESET themes set their own readable `userBubbleText` (e.g. Sunny `:764`, Platinum
`:1004`) — so presets are unaffected. **The bug is only in CUSTOM themes:** `AppCustomTheme.resolved(isDark:)` fans the
single `text` slot into many fields, including `userBubbleText: .hex(text, opacity:0.96)` (`EpistemosTheme.swift:1565`). So
custom "Text" = white → editor text white (`foregroundHex: text` :1541, correct) AND user-bubble text white (:1565, wrong),
while the bubble BACKGROUND is the independent `userBubble` slot (pale lavender light-fallback `0xE4DFFF` :1433) → white-on-
pale = unreadable. The user-editable slots `AppCustomThemeColorSlot` (`:1371-1449`) are only 8 (background/text/accent/
heading/card/noteSurface/chatSurface/userBubble) — `userBubble` is background-only; **no bubble-TEXT slot**.

## Fix plan (additive, defaulted = no regression)
1. **Add slots to `AppCustomThemeColorSlot` (`EpistemosTheme.swift:1371`):** `userBubbleText` + a few accessory/accent/
   surface tokens the owner asked for: `secondaryText` (→ `mutedForeground`), `link` (→ `preferredMarkdownLink`),
   `assistantBubbleBg`, `border`. Add their `title`/`detail`/`lightFallbackHex`/`darkFallbackHex` arms (switches `:1383-1407`,
   `:1424-1448`).
2. **Default unset → inherit current behavior (the no-regression key):** mirror the existing `noteSurfaceHex` inheritance
   (`:1487-1497`) — a helper e.g. `userBubbleTextHex(isDark:defaults:)` returns the set key if present, else the current
   derived value (`.text`). Existing custom themes (no new key) resolve exactly as today.
3. **Wire in `AppCustomTheme.resolved` (`:1565`):** change `userBubbleText: .hex(text, opacity:0.96)` →
   `.hex(userBubbleTextHex(isDark:), opacity:0.96)`; do the same for the other new slots (`mutedForegroundHex` :1548,
   `preferredMarkdownLinkHex` :1545, `assistantBubbleBackgroundHex` :1550, `border` :1552), each defaulting to its current
   expression. **No change** needed in `MessageBubble.swift`, `HologramSearchSidebar.swift:937`, `MiniChatView.swift:429`
   (all already read `theme.userBubbleText`).
4. **Theme-editor UI — automatic:** `AppearanceCustomThemeSection` (`Views/Settings/SettingsView.swift:4325-4395`) renders a
   `LazyVGrid(AppCustomThemeColorSlot.allCases)` of `ColorPicker`s (`:4353-4360`) + swatch readout (`:4298-4322`) — so new
   enum cases produce new pickers with ZERO structural UI work. One refinement: replicate the `.noteSurface` inherited-
   display branch in `colorBinding`'s getter (`:4380-4394`) for inheriting slots (e.g. `userBubbleText`) so the picker shows
   the inherited color initially.

**Net:** owner gets a separate "User Bubble Text" picker + accessory/accent/surface pickers; unset themes unchanged; the
white-on-pale bubble fixed. Files: `Theme/EpistemosTheme.swift` (slot enum + `resolved` + inheritance helper) and optionally
`Views/Settings/SettingsView.swift` (`colorBinding` getter). [S], test-backed (resolved() returns the new token when set,
inherits when unset). Cross-ref SS-U (theme crash, fixed).
