# Apple Frameworks Integration Plan

> **Historical snapshot:** This plan reflects a pre-pruning editor architecture phase. Production now ships the TK2-only note editor path, and any TextKit 1 prose-editor references below should be read as historical context rather than current repo state.

## Goal
Replace hand-rolled implementations with Apple-native frameworks. Ship-quality, not demo-quality.

## Default Writer Font
**New York** at 13pt. Apple's screen-optimized serif. Falls back to Palatino if unavailable.

---

## Phase 1: Writer Mode Polish (DONE — TextKit 1, correct architecture)

**TextKit 1 stays for Writer.** TextKit 2 dropped multi-container text flow — each
`NSTextLayoutManager` manages ONE `NSTextContainer`. For paginated document editing
(text flowing across pages), TextKit 1's `NSLayoutManager` with multiple containers is
the correct architecture. Even Apple Pages uses this approach.

### Architecture (current, keeping)
```
WriterModeView (SwiftUI)
  -> PagedDocumentView (NSViewRepresentable)
       -> NSScrollView
            -> PageCanvasView (NSView, isFlipped, themed background)
                 -> PageTileView[0] (NSTextView, 612x792pt, page surface + shadow)
                 -> PageTileView[1]
                 -> ...
            NSLayoutManager (TextKit 1) flows text across all PageTileView containers
```

### Completed
- Default font: New York 13pt, General preset (1.5x spacing, no indent)
- Native zoom via `scaleUnitSquare(to:)` (crisp, not bitmap)
- WritingTools enabled on PageTileView
- Ruler removed
- Format bar uses `.ultraThinMaterial`
- Bottom toolbar visible in writer mode
- Spell/grammar checking enabled

---

## Phase 2: PDFKit Preview + Export (DONE)

Refactored `WriterExportService` — `generatePDFDocument()` returns reusable `PDFDocument`.
Export uses `PDFDocument.write(to:)`. Added `WriterPDFPreview` (PDFView wrapper) with toggle
in format bar for split-view live preview. 500ms debounced refresh on text changes.

---

## Phase 3: NaturalLanguage Framework (DONE)

`NLAnalysisService.swift` in Engine/ — entity extraction, sentiment, language detection,
word count. All APIs wired:
- **Entity extraction** — GraphBuilder extracts people/places/orgs from page bodies during
  graph build, creates `.tag` nodes (sourceId `entity-<kind>-<name>`) with `.mentions` edges.
  Runs in same body-scan loop as block refs (single `loadBody()` per page).
- **Word count** — NLTokenizer replaces NSSpellChecker in NoteWindowManager (2 sites) and
  VaultIndexActor (1 site). More accurate for non-English text.

---

## Phase 4: WritingTools Integration (DONE)

Enabled on PageTileView in writer mode via `writingToolsBehavior = .default`.
Prose editor (ClickableTextView) inherits default NSTextView behavior — already active.

---

## Phase 5: CoreSpotlight (DONE)

`SpotlightIndexer.swift` in Engine/. Index on create/save (VaultSyncService), deindex
on page/folder delete (NotesSidebar), reindexAll on vault load. Open-from-Spotlight
wired in EpistemosApp via `onContinueUserActivity`.

---

## Phase 6: QuickLook (DONE)

Implemented `QLPreviewPanelDataSource`/`QLPreviewPanelDelegate` on ClickableTextView.
Space bar on image attachment opens QuickLook panel. Full file path stored in
`EpistemosImagePath` attribute for reliable lookup.

---

## Phase 7: Translation Framework (DONE)

Added "Translate" to AI Assistant context menu. Posts notification to parent SwiftUI
view which shows `.translationPresentation` — Apple's native translation UI with
language auto-detection.

---

## Phase 8: Vision OCR (DONE)

Added to ClickableTextView context menu Insert submenu ("Extract Text from Image...").
Uses `VNRecognizeTextRequest` with `.accurate` recognition level and language correction.
Inserts extracted text as blockquote below cursor.

---

## Phase 9: DataDetection (DONE)

`DataDetectionService.swift` — `NSDataDetector` for dates, addresses, phones, URLs.
Detection runs on 1s debounce after text changes in ProseEditorRepresentable.
Detected ranges styled with subtle underline. Click-to-open wired in ClickableTextView
(Calendar, Maps, FaceTime, browser).

---

## Phase 10: Polish Frameworks (MOSTLY DONE)

### 10a: UserNotifications (REMOVED)
Breathe reminders were implemented but later removed (UI, settings, reset hooks deleted).
No `UNUserNotificationCenter` call sites remain in the codebase.

### 10b: Continuity Camera (DONE)
Built into NSTextView — "Import from iPhone or iPad" available in Edit menu automatically.
No custom code needed since ClickableTextView already handles image attachments.

### 10c: ShortcutsProvider (DONE)
`EpistemosShortcutsProvider.swift` — 10 discoverable Siri shortcuts covering
AI analysis, research, note creation, search, daily briefing, and more.

### 10d: swift-collections (DEFERRED)
No SPM in project — adding swift-collections requires dependency setup.
Deferred to a future session.

---

## Phase 11: TextKit 2 Continuous Document Lane (PARKED FOR LATER — prior attempt reverted)

**Keep this plan. Do not treat it as active work right now.** A previous TextKit 2 document-mode
attempt was reverted, but the idea is still worth preserving for a future pass if Writer mode is
deleted or split out.

**The right use case:** a separate continuous-scroll rich text lane alongside the current
Markdown/Prose editor, not an in-place rewrite of the existing TextKit 1 markdown stack.

**Purpose:** Import/export Word (.docx) files, edit rich text with tables, lists, inline images,
and formatting — all native, no web engine needed.

### Why keep TextKit 2 on the backlog
- **Viewport-based layout for long continuous documents** — better fit for large single-flow notes,
  research documents, and read-mostly rich text than a fully custom TextKit 1 stack.
- **Fragment-driven rendering** — better foundation for comment bubbles, inline annotations,
  custom highlights, and other layout-fragment-aware overlays.
- **Native rich text structures** — stronger fit for `NSTextTable`, `NSTextList`, attachments,
  exclusion paths, and richer document editing than markdown-backed plain text.
- **DOCX / rich text interoperability** — stronger long-term lane for Word import/export,
  attributed-text editing, and richer copy/paste fidelity.
- **Better text-system correctness** — more modern text layout model for complex scripts and
  mixed-language content.

### What not to do
- **Do not casually migrate the current prose editor in place.** The live editor is still deeply
  TextKit 1-based: `MarkdownTextStorage`, `NSLayoutManager`, custom `NSTextView` drawing,
  table rendering, fold drawing, and BTK edit interception all assume the current stack.
- **Do not revive TextKit 2 just because Writer might be removed.** Removing Writer removes the
  main blocker, but the prose editor would still be a rewrite, not a swap.

### Best future targets
- A **separate continuous document editor** for rich text and DOCX-focused work
- A **read-only or lightly editable preview surface** with annotations / comments / inline widgets
- A **research / export document lane** distinct from the markdown-first note editor

### Architecture
```
NoteTabView
  -> mode toggle: Markdown | Writer | Document
       -> Markdown: ProseEditorRepresentable (TextKit 1, MarkdownTextStorage)
       -> Writer:   PagedDocumentView (TextKit 1, multi-container pagination)
       -> Document: DocumentEditorView (TextKit 2, single container, WYSIWYG)
```

```
DocumentEditorView (NSViewRepresentable)
  -> NSScrollView
       -> NSTextView (TextKit 2 backed)
            -> NSTextContentStorage (owns attributed string)
            -> NSTextLayoutManager (single container, viewport rendering)
            -> NSTextContainer (full width, infinite height)
```

### Key capabilities (all native AppKit, zero web)
- **DOCX import:** `NSAttributedString(url:, documentAttributes:)` with `.officeOpenXML`
- **DOCX export:** `NSAttributedString.data(from:, documentAttributes: [.documentType: .officeOpenXML])`
- **Tables:** `NSTextTable` + `NSTextTableBlock` for native text tables
- **Lists:** `NSTextList` for ordered/unordered/checklist
- **Inline images:** `NSTextAttachment` with custom cells
- **Headers:** Paragraph styles with preset heading sizes
- **Links:** `NSAttributedString.Key.link`
- **Find & Replace:** `NSTextFinder` integration

### What makes this different from Writer mode
| Feature | Writer (TextKit 1) | Document (TextKit 2) |
|---------|-------------------|---------------------|
| Layout | Paginated (multi-container) | Continuous scroll (single container) |
| Purpose | Academic papers (MLA/APA/Chicago) | General rich text editing |
| Format | Markdown backing store | NSAttributedString backing store |
| Page breaks | Visual page tiles | None (continuous) |
| Export | PDF primary | DOCX primary |
| Tables | Not supported | NSTextTable native |
| Lists | Markdown lists | NSTextList native |
| Title page | Academic title page | No |
| Headers/footers | Running head, page numbers | No |

### Tasks
1. Create `DocumentEditorView.swift` — NSViewRepresentable with TextKit 2
2. Configure `NSTextContentStorage` + `NSTextLayoutManager` + single `NSTextContainer`
3. Build `DocumentFormatBar.swift` — toolbar with:
   - Font family/size picker
   - Bold/italic/underline/strikethrough toggles
   - Heading level picker (H1-H6, Body)
   - Alignment (left/center/right/justified)
   - List controls (bullet, numbered, checklist)
   - Table insert/edit
   - Image insert
   - Link insert
4. DOCX import: File → Open, reads `.docx` via `NSAttributedString`
5. DOCX export: File → Export → Word, writes `.docx` via `NSAttributedString`
6. Table editing: insert/delete rows/columns, resize, cell selection
7. List editing: tab to indent, shift-tab to outdent, auto-continue on Enter
8. Image handling: drag-drop or Insert menu, `NSTextAttachment` with resizable cells
9. Add Document mode to NoteTabView mode toggle
10. Persistence: save `NSAttributedString` as RTFD bundle or serialized attributed string

### Verification
- Document mode opens with TextKit 2 single-container layout
- DOCX import renders tables, lists, images, formatting correctly
- DOCX export round-trips without loss
- Table editing (add/remove rows/columns) works
- List indentation works
- Image drag-drop works
- Mode switching preserves content (Markdown ↔ Document converts)
- All 6 themes render correctly

---

## Execution Order

| Phase | Framework | Status | Priority |
|-------|-----------|--------|----------|
| 1 | Writer Mode Polish (TextKit 1) | DONE | — |
| 2 | PDFKit Preview + Export | DONE | — |
| 3 | NaturalLanguage | DONE (entity extraction + word count wired) | — |
| 4 | WritingTools | DONE | — |
| 5 | CoreSpotlight | DONE (index + deindex + open wired) | — |
| 6 | QuickLook | DONE | — |
| 7 | Translation | DONE | — |
| 8 | Vision OCR | DONE | — |
| 9 | DataDetection | DONE | — |
| 10a | UserNotifications | REMOVED (breathe reminders deleted) | — |
| 10b | Continuity Camera | DONE (built-in NSTextView) | — |
| 10c | ShortcutsProvider | DONE (pre-existing, 10 shortcuts) | — |
| 10d | swift-collections | DEFERRED (no SPM, needs dependency setup) | LOWER |
| **11** | **TextKit 2 Continuous Document Lane** | **PARKED (prior attempt reverted; keep for later)** | LATER |

## What Stays Unchanged
- TextKit 1 prose editor (MarkdownTextStorage, ClickableTextView, ProseEditorRepresentable)
- TextKit 1 writer mode (PagedDocumentView, multi-container pagination)
- Rust graph engine + markdown parser
- SwiftData models
- Graph visualization (Metal + Rust)
- AI pipeline (TriageService, PipelineService, LLMService)
- VaultSyncService (file I/O)

## TextKit Strategy Summary
| Mode | TextKit | Why |
|------|---------|-----|
| Markdown/Prose | TextKit 1 | MarkdownTextStorage live highlighting, proven stable |
| Writer (paginated) | TextKit 1 | Multi-container flow — TextKit 2 can't do this |
| Document (WYSIWYG) | TextKit 2 | Single container, modern layout, NSTextTable/NSTextList, DOCX native |
