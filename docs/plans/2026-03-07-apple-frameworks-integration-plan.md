# Apple Frameworks Integration Plan

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

## Phase 2: PDFKit Preview + Export (HIGH — replaces CGContext PDF generation)

**What dies:** WriterExportService.exportPDF() CGContext manual rendering.

**What replaces it:** PDFKit for live preview pane and export.

### Tasks
1. Add PDF preview toggle in writer mode — renders current document as PDFDocument
2. Use `PDFView` in an NSViewRepresentable for live preview
3. Thumbnail sidebar via `PDFThumbnailView`
4. Export: generate `PDFDocument` from TextKit 1 layout, save via `PDFDocument.write(to:)`
5. Annotation support: let users highlight/comment in preview mode
6. Keep DOCX/plaintext/markdown export paths (they work fine)

### Verification
- PDF preview shows document with correct formatting
- Thumbnails update as user edits
- Exported PDF matches preview
- Annotations persist

---

## Phase 3: NaturalLanguage Framework (DONE)

`NLAnalysisService.swift` created in Engine/. Provides:
- Entity extraction: `NLTagger` with `.nameType` (person/place/org)
- Sentiment analysis: `NLTagger` with `.sentimentScore` (-1.0 to +1.0)
- Language detection: `NLLanguageRecognizer` (BCP-47 codes)
- Word count: `NLTokenizer` (more accurate than NSSpellChecker for non-English)

### Remaining
- Wire NL entities into GraphBuilder alongside Rust-extracted entities (deduplicate)

---

## Phase 4: WritingTools Integration (DONE)

Enabled on PageTileView in writer mode via `writingToolsBehavior = .default`.
Prose editor (ClickableTextView) inherits default NSTextView behavior — already active.

---

## Phase 5: CoreSpotlight (DONE — already existed)

`SpotlightIndexer.swift` already implemented in Sync/. Full CoreSpotlight integration
with index/deindex/reindexAll. No work needed.

---

## Phase 6: QuickLook (MEDIUM — Space bar preview for attachments)

### Tasks
1. Implement `QLPreviewPanelDataSource` and `QLPreviewPanelDelegate` on note window
2. When cursor is on an image attachment or file reference, Space bar shows QuickLook preview
3. Support: images, PDFs, code files, any file the user has linked

### Verification
- Space on image attachment shows full-size preview
- Space on file link shows QuickLook panel
- Panel dismisses on Space or Esc

---

## Phase 7: Translation Framework (MEDIUM — one-line translate)

### Tasks
1. Add "Translate" to ClickableTextView context menu (under AI Assistant submenu)
2. Use `TranslationSession` to translate selected text
3. Show translation in a popover or inline replacement
4. Auto-detect source language via NaturalLanguage (Phase 3)

### Verification
- Select text, right-click, Translate works
- Translation appears in popover
- Multiple languages supported

---

## Phase 8: Vision OCR (DONE)

Added to ClickableTextView context menu Insert submenu ("Extract Text from Image...").
Uses `VNRecognizeTextRequest` with `.accurate` recognition level and language correction.
Inserts extracted text as blockquote below cursor.

---

## Phase 9: DataDetection (MEDIUM — smart data linking)

### Tasks
1. Use `NSDataDetector` on note text to find dates, addresses, phone numbers, URLs
2. Style detected data with subtle underline (like wikilinks)
3. Click handlers: dates open Calendar, addresses open Maps, phones open FaceTime
4. Run detection on save (debounced), not per-keystroke

### Verification
- Dates, addresses, phone numbers highlighted in notes
- Clicking opens correct system app
- No performance impact (debounced)

---

## Phase 10: Polish Frameworks (LOWER)

### 10a: UserNotifications
- Daily brief reminder: "You have X notes to review"
- Spaced repetition reminders for tagged notes
- Notification actions: Open note, Snooze, Dismiss

### 10b: Continuity Camera
- Add "Scan Document" to Insert menu
- Uses `NSCameraCapture` to invoke iPhone camera
- Scanned image inserted into note, OCR'd via Vision (Phase 8)

### 10c: ShortcutsProvider
- Define `AppIntent` actions: Create Note, Search Notes, Open Graph, Export PDF
- Users can build Shortcuts automations with Epistemos

### 10d: swift-collections
- Audit codebase for `Dictionary` usage where order matters
- Replace with `OrderedDictionary` where appropriate
- Use `Deque` for any FIFO queues (token buffers, etc.)

---

## Phase 11: Document Mode (NEW — TextKit 2 rich text WYSIWYG)

**The third editing mode.** Alongside Markdown/Prose (TextKit 1) and Writer (TextKit 1 paginated),
Document mode is a single-continuous-scroll rich text editor using TextKit 2. This is where
TextKit 2 shines — single container, modern layout, rich inline elements.

**Purpose:** Import/export Word (.docx) files, edit rich text with tables, lists, inline images,
and formatting — all native, no web engine needed.

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
| 2 | PDFKit Preview + Export | TODO | HIGH |
| 3 | NaturalLanguage | DONE (wire to graph remaining) | — |
| 4 | WritingTools | DONE | — |
| 5 | CoreSpotlight | DONE (pre-existing) | — |
| 6 | QuickLook | TODO | MEDIUM |
| 7 | Translation | TODO | MEDIUM |
| 8 | Vision OCR | DONE | — |
| 9 | DataDetection | TODO | MEDIUM |
| 10a-d | Polish (Notifications, Camera, Shortcuts, swift-collections) | TODO | LOWER |
| **11** | **Document Mode (TextKit 2 WYSIWYG)** | **TODO** | **HIGH** |

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
