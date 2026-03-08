# Writer v2 — Prose Writing Features + TextKit 2 Document Mode

## Context

Writer mode (paginated academic documents with MLA/APA/Chicago presets) is being removed.
Two new workstreams replace it:

1. **Prose editor writing features** — focus mode, typewriter scroll, session word targets,
   chapter navigator. Bolted onto the existing TextKit 1 prose editor.
2. **TextKit 2 document mode** — rich text editing with tables, lists, inline images,
   DOCX import/export. New standalone editor backed by `NSTextContentStorage`.

## Decisions

- TextKit 1 prose editor stays untouched at its core — no engine swap.
- TextKit 2 is used only for the new document mode (continuous scroll, rich text).
- Pages have a `format` property: `"markdown"` (default) or `"richtext"`.
- Writer mode (8 files) deleted. Cmd+R reused for Document mode toggle.
- All implementations use native NS APIs. No SwiftUI workarounds for text.

---

## Workstream A: Prose Editor Writing Features

All features bolt onto `ClickableTextView` / `ProseEditorRepresentable`. No new editor surface.

### Focus Mode
- Toggle: Cmd+Shift+F or toolbar button.
- Dims all paragraphs except the one containing the cursor to ~30% opacity.
- Implementation: `drawBackground(in:)` override on `ClickableTextView`, apply temporary
  foreground color alpha to non-active paragraph ranges via temporary attributes on
  `NSLayoutManager`.
- State: `isFocusMode: Bool` on `NotesUIState`.

### Typewriter Scroll
- Active only when focus mode is on.
- Keep cursor line vertically centered in the scroll view.
- Implementation: `didChangeSelection` in Coordinator, call `scrollRangeToVisible`
  with adjusted rect that centers the line.

### Session Word Target
- Set a word count goal per writing session (e.g. 500 words).
- Track delta from session-start word count.
- Small progress indicator in the bottom toolbar.
- State: `sessionWordTarget: Int?` and `sessionStartWordCount: Int` on `NotesUIState`.

### Chapter/Section Navigator
- Parse `#` / `##` headers from body text.
- Display as dropdown or extend existing `NoteTableOfContents`.
- Click to scroll to heading.
- Debounced re-scan on text changes.

---

## Workstream B: TextKit 2 Document Mode

### Architecture

```
NoteWindowManager
  -> mode toggle: Editor | Preview | Document (replaces Writer)
       -> Editor:   ProseEditorRepresentable (TextKit 1, MarkdownTextStorage)
       -> Preview:  MarkdownPreviewView (existing)
       -> Document: DocumentEditorRepresentable (TextKit 2, NSTextContentStorage)
```

```
DocumentEditorRepresentable (NSViewRepresentable)
  -> NSScrollView
       -> DocumentTextView (NSTextView subclass, TextKit 2 backed)
            -> NSTextContentStorage (owns attributed string)
            -> NSTextLayoutManager (single container, viewport-based rendering)
            -> NSTextContainer (full width, infinite height)
```

`NSTextView` initialized with `usingTextLayoutManager: true` to opt into TextKit 2.

### Page Format Property

Add `format: String` to `SDPage` (default `"markdown"`).

| Format | Storage | Extension | Editor |
|--------|---------|-----------|--------|
| `"markdown"` | Plain text | `.md` | ProseEditorRepresentable |
| `"richtext"` | RTFD bundle | `.rtfd` | DocumentEditorRepresentable |

`NoteFileStorage` additions:
- `readRichText(pageId:) -> NSAttributedString?`
- `writeRichText(pageId:, content: NSAttributedString)`
- Rich text files stored in `note-bodies/{pageId}.rtfd` (alongside existing `.md` files).

### Format Bar

`DocumentFormatBar` — native `NSToolbar` items or `.ultraThinMaterial` strip:

- Font family/size picker (NSFontPanel integration)
- Bold / Italic / Underline / Strikethrough toggles
- Heading level picker (H1-H6, Body) — paragraph styles
- Alignment (left, center, right, justified)
- List controls (bullet, numbered, checklist via `NSTextList`)
- Table insert (`NSTextTable` + `NSTextTableBlock`)
- Image insert (drag-drop + Insert menu via `NSTextAttachment`)
- Link insert (`NSAttributedString.Key.link`)

### DOCX Import / Export

All native `NSAttributedString`:
- **Import:** `NSAttributedString(url:, documentAttributes:)` with `.officeOpenXML`
- **Export:** `NSAttributedString.data(from:, documentAttributes: [.documentType: .officeOpenXML])`
- Menu items: File → Import Document, File → Export → Word Document

### Persistence & Save Pipeline

Same pattern as prose editor (`ProseEditorView.swift`):
- Debounced save writes RTFD bundle to `NoteFileStorage`.
- Sets `page.needsVaultSync = true` + `modelContext.save()`.
- `lastPersistedData` tracks last save to avoid redundant writes.
- `flushIfNeeded()` on page switch and disappear.
- Posts `NoteFileStorage.pageBodyDidChange` notification for cross-editor sync.

### Mental Model

- **Notes editor** = blocky/custom knowledge editor (markdown, wikilinks, AI chat)
- **Doc mode** = continuous drafting/manuscript editor (clean, flowing, one document)
- **Print/pages** = preview/export layer (not the editing core)

Doc mode is a continuous writing canvas first, paged preview/export second.
No fake pages as the main editing UI. Clean long-form writing surface.

### Entry Points

Three ways to enter document mode:
1. **New Document** — create a new rich text page from sidebar or Cmd+N variant
2. **Open Note in Doc Mode** — convert an existing markdown note to rich text instantly
   (markdown → attributed string, sets `page.format = "richtext"`)
3. **Import** — .md / .txt / .rtf / .docx files create a rich text page

### Mode Switching

- Cmd+R toggles Document mode (replaces Writer).
- Opening a rich text page auto-selects Document mode.
- Markdown → Document conversion is instant and one-way (converts markdown to attributed
  string). The user confirms before converting.
- Optional print preview overlay for page layout / PDF export (not the editing surface).

---

## Workstream C: Writer Mode Removal

### Files to Delete (8)
- `Views/Notes/Writer/WriterModeView.swift`
- `Views/Notes/Writer/PagedDocumentView.swift`
- `Views/Notes/Writer/WriterTextStorage.swift`
- `Views/Notes/Writer/WriterFormatState.swift`
- `Views/Notes/Writer/WriterFormatBar.swift`
- `Views/Notes/Writer/WriterExportService.swift`
- `Views/Notes/Writer/WriterPDFPreview.swift`
- `Views/Notes/Writer/AcademicStyle.swift`

### References to Clean
- `NoteWindowManager.swift`: Remove `showWriterMode`, `toggleWriterMode()`,
  `WriterModeView` branch, Writer toolbar button.
- `Epistemos.xcodeproj/project.pbxproj`: Remove file references.
- Any tests referencing writer mode.

### What Migrates
- **PDF export** — adapt `WriterExportService.generatePDFDocument()` for document mode
  (export attributed string → PDF via `NSPrintOperation`).
- **WritingTools** — already enabled on all `NSTextView` subclasses.

---

## Execution Order

| Order | Workstream | Effort | Depends On |
|-------|------------|--------|------------|
| 1 | C: Writer mode removal | Small | Nothing |
| 2 | A: Prose editor writing features | Medium | Nothing |
| 3 | B: TextKit 2 document mode | Large | C (Cmd+R freed) |

---

## Verification

### Workstream A
- Focus mode dims non-active paragraphs, clears on toggle off.
- Typewriter scroll keeps cursor centered when focus mode is active.
- Session word target shows progress delta from session start.
- Chapter navigator lists all `#`/`##` headings, scrolls to clicked heading.

### Workstream B
- Document mode opens with TextKit 2 single-container layout.
- Rich text editing: bold, italic, headings, alignment all work.
- Table editing: insert, add/remove rows and columns.
- List editing: tab to indent, shift-tab to outdent, auto-continue on Enter.
- Image drag-drop inserts inline attachment.
- DOCX import renders tables, lists, images, formatting correctly.
- DOCX export round-trips without loss.
- Save pipeline: debounced RTFD write, dirty flag, vault sync notification.
- Cross-editor: if same page open in note window, body change notification fires.

### Workstream C
- Writer mode files deleted, no build errors.
- Cmd+R does nothing (until Workstream B wires it).
- No references to WriterModeView, AcademicStyle, etc. in codebase.
