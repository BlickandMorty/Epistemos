# SS-DD — Remove stray dropdown chevrons on icon menus (code-editor eye/gear deformed) (2026-06-20)

Owner (with screenshot): *"two icons in the code editor — an eye and a settings icon — both have a weird drop-down
arrow inside them, so the eye looks deformed and the settings icon is deformed. Get rid of that drop-down arrow, don't
lose the functionality, and upgrade the usefulness (e.g. searching parts of the file). Get rid of those arrows
everywhere they interfere/overlap other UI, mainly the one I screenshotted."* Code-grounded. [S], high-visibility,
NON-INVASIVE. Cross-ref SS-GC (same code-editor top bar).

## Root cause
The eye + gear are SwiftUI `Menu`s with an icon-only label + `.menuStyle(.borderlessButton)`, which renders the DEFAULT
menu indicator (a small dropdown chevron) next to/overlapping the SF Symbol → the icon looks "deformed":
- **`viewOptionsMenu` (the EYE):** `Views/Notes/CodeEditorView.swift:2998-3011` — `Menu { … } label { Image(systemName:
  "eye") } .menuStyle(.borderlessButton)`. Mounted in `codeEditorTopBar` (`:2186-2187`, `:2278-2279`).
- **`editorSettingsMenu` (the GEAR):** `CodeEditorView.swift:2950-2992` — same shape, `Image(systemName: "gear")`.
The chevron is the `Menu`'s automatic `menuIndicator`. The screenshot shows it on the eye + gear (next to the ▶ preview,
search, outline icons in the top bar).

## Fix — `.menuIndicator(.hidden)` (keeps the menu, removes the chevron; already used in this codebase)
Add `.menuIndicator(.hidden)` to the icon-only borderlessButton menus. This is PROVEN/consistent here — 2 files already
use it (`Views/Sessions/FSRSReviewSidebar.swift`, `Views/Notes/NoteDetailWorkspaceView.swift`). The menu still opens on
click; only the chevron disappears, so the eye/gear render as clean icons. (Functionality unchanged.)

## Sweep — ALL the places (owner: "everywhere they interfere/overlap")
8 files use `.menuStyle(.borderlessButton)` (chevron-prone icon-menu sites) — audit each; apply `.menuIndicator(.hidden)`
to the ICON-ONLY ones (where a chevron deforms the glyph), and LEAVE text-labeled menus that legitimately want a
disclosure indicator:
- `Views/Notes/CodeEditorView.swift` (eye + gear — the screenshotted ones; FIX FIRST)
- `Views/Epdoc/EpdocEditorToolbar.swift`, `Views/Epdoc/EpdocBlockGutterMenu.swift`
- `Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift`
- `Views/Chat/ArtifactBlockView.swift`, `KnowledgeFusion/UI/AdapterSelectorView.swift`,
  `Views/Notes/DiffSheetView.swift`, `Views/Sessions/FSRSReviewSidebar.swift` (already partially hidden — verify)
Check each: if the label is an icon-only `Image(systemName:)` → add `.menuIndicator(.hidden)`. (AdapterSelectorView may
WANT a chevron since it's a text "Active Adapter" menu — judgment per site.)

## Functionality upgrade (owner: "make it more robust… searching parts of the file")
The eye = `viewOptionsMenu` (view toggles), gear = `editorSettingsMenu` (tab width etc.); the bar already has a search
(magnifying glass) + outline (list) icon. OPTIONAL follow-on (after the chevron cleanup): make the code-editor in-file
SEARCH more robust — e.g. find-in-file with match count / next-prev / case+regex toggles, surfaced from the existing
search affordance (`CodeEditorView` Find/Go-to-Line at the top bar). Keep it minimal + pixel-art. Flag as a [S/M]
enhancement; the chevron removal is the [S] must-do the owner screenshotted.

## Order
1. [S] `.menuIndicator(.hidden)` on CodeEditorView `viewOptionsMenu` (:3008) + `editorSettingsMenu` (:2989) — the
   screenshotted deform. Test: render/source-assert the menus carry `.menuIndicator(.hidden)`.
2. [S] sweep the other 7 borderlessButton icon-menus; apply where icon-only.
3. [S/M] optional: more-robust in-file search on the code editor.
Visual confirmation PENDING OWNER (rebuild). NON-INVASIVE; TK2/Prose + Metal untouched.
