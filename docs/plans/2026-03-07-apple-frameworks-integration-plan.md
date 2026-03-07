# Apple Frameworks Integration Plan

## Goal
Replace hand-rolled implementations with Apple-native frameworks. Ship-quality, not demo-quality.

## Default Writer Font
**New York** at 13pt. Apple's screen-optimized serif. Falls back to Palatino if unavailable.

---

## Phase 1: Writer Mode Polish (HIGH — keep TextKit 1, it's the right tool)

**Why not TextKit 2:** TextKit 2 dropped multi-container text flow. Each NSTextLayoutManager manages ONE container. For paginated document editing (text flowing across pages), TextKit 1's multi-container layout is still the correct architecture. Even Apple Pages uses this approach.

**What changes:** Default font, theme polish, zoom (already fixed), dead code cleanup.

### Architecture
```
WriterModeView (SwiftUI)
  -> WriterDocumentView (NSViewRepresentable)
       -> NSScrollView
            -> NSTextView (TextKit 2 backed)
                 -> NSTextContentStorage (owns the text)
                 -> NSTextLayoutManager (handles pagination + viewport rendering)
                 -> NSTextContainer (one per page, or single with page breaks)
```

### Tasks
1. Create `WriterDocumentView.swift` — NSViewRepresentable using TextKit 2
2. Configure NSTextView with `NSTextLayoutManager` (not legacy NSLayoutManager)
3. Use `NSTextLayoutManager.textViewportLayoutController` for viewport-based rendering
4. Implement page breaks via `NSTextLayoutFragment` inspection
5. Page chrome (numbers, headers, footers) drawn in a custom `NSTextLayoutFragmentProvider` or overlay
6. Wire WriterFormatState (font, spacing, margins, alignment) to text attributes
7. Theme colors on page backgrounds (keep existing 6-theme palette)
8. Zoom via `scaleUnitSquare(to:)` on the text view (native, crisp)
9. Keep WriterFormatBar + WriterExportService (they don't touch TextKit internals)
10. Default font: New York 13pt, line spacing: 1.5x
11. Delete: PagedDocumentView.swift, PageTileView, PageCanvasView, WriterTextStorage, WriterRulerView (already deleted)

### Verification
- Writer mode opens, displays text, edits work
- Page breaks appear at correct positions
- Zoom is crisp at all levels
- All 6 themes render correctly
- Export still works (PDF/DOCX)
- Format bar controls (font, size, spacing, alignment, margins) all apply

---

## Phase 2: PDFKit Preview + Export (HIGH — replaces CGContext PDF generation)

**What dies:** WriterExportService.exportPDF() CGContext manual rendering.

**What replaces it:** PDFKit for live preview pane and export.

### Tasks
1. Add PDF preview toggle in writer mode — renders current document as PDFDocument
2. Use `PDFView` in an NSViewRepresentable for live preview
3. Thumbnail sidebar via `PDFThumbnailView`
4. Export: generate `PDFDocument` from TextKit 2 layout, save via `PDFDocument.write(to:)`
5. Annotation support: let users highlight/comment in preview mode
6. Keep DOCX/plaintext/markdown export paths (they work fine)

### Verification
- PDF preview shows document with correct formatting
- Thumbnails update as user edits
- Exported PDF matches preview
- Annotations persist

---

## Phase 3: NaturalLanguage Framework (HIGH — augments Rust entity extraction)

**What it adds:** On-device NER, sentiment analysis, language detection. Complements Rust parser.

### Tasks
1. Create `NLAnalysisService.swift` in Engine/
2. Entity extraction: `NLTagger` with `.nameType` scheme — extracts person names, place names, organization names from note text
3. Sentiment analysis: `NLTagger` with `.sentimentScore` — per-paragraph sentiment for the graph's emotional mapping
4. Language detection: `NLLanguageRecognizer` — auto-detect note language, feed to Translation framework later
5. Wire NL entities into GraphBuilder alongside Rust-extracted entities (deduplicate)
6. Use NL tokenization for better word count (replace `NSSpellChecker.countWords`)

### Verification
- Entity extraction finds names/places/orgs in sample notes
- Entities appear as graph nodes
- No duplicate entities between NL and Rust extraction
- Word count matches or improves current behavior

---

## Phase 4: WritingTools Integration (HIGH — free Apple Intelligence features)

**What it adds:** Rewrite, proofread, summarize in any NSTextView — for free.

### Tasks
1. Audit ClickableTextView and writer NSTextView — ensure `isWritingToolsActive` is not disabled
2. Verify `writingToolsCoordinator` delegate works (may need adoption)
3. Test: select text, right-click, Writing Tools submenu should appear
4. Ensure AI zone protection doesn't interfere with Writing Tools edits
5. If needed, implement `NSTextViewDelegate.textView(_:writingToolsDidFinishEditing:)` to sync changes

### Verification
- Writing Tools menu appears on text selection in both prose editor and writer mode
- Rewrite/Proofread/Summarize work without corrupting text
- Undo works after Writing Tools edits

---

## Phase 5: CoreSpotlight (MEDIUM — deep system search integration)

### Tasks
1. Create `SpotlightIndexer.swift` in Sync/
2. Index each SDPage as a `CSSearchableItem` with title, body excerpt, tags, graph connections
3. Update index on note save (piggyback on VaultSyncService)
4. Delete items from index on note deletion
5. Handle `CSSearchableItemActionType` in app delegate to open notes from Spotlight

### Verification
- Notes appear in system Spotlight search
- Clicking Spotlight result opens correct note
- Deleted notes removed from Spotlight

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

## Phase 8: Vision OCR (MEDIUM — extract text from images)

### Tasks
1. When user inserts an image, offer "Extract Text" option
2. Use `VNRecognizeTextRequest` to OCR the image
3. Insert extracted text below the image or in a popover
4. Support: screenshots, photos, scanned documents

### Verification
- Drop image, right-click, "Extract Text" works
- Extracted text is accurate
- Works with screenshots and photos

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

## Execution Order

| Phase | Framework | Priority | Est. Complexity |
|-------|-----------|----------|-----------------|
| 1 | TextKit 2 Writer | HIGH | Large — replaces entire writer subsystem |
| 2 | PDFKit | HIGH | Medium — builds on Phase 1 output |
| 3 | NaturalLanguage | HIGH | Small — additive, no existing code replaced |
| 4 | WritingTools | HIGH | Tiny — mostly just "don't disable it" |
| 5 | CoreSpotlight | MEDIUM | Small — indexing pipeline |
| 6 | QuickLook | MEDIUM | Small — delegate implementation |
| 7 | Translation | MEDIUM | Small — context menu + API call |
| 8 | Vision OCR | MEDIUM | Small — one request type |
| 9 | DataDetection | MEDIUM | Medium — detection + click handlers |
| 10a-d | Polish | LOWER | Small each |

## What Stays Unchanged
- TextKit 1 prose editor (MarkdownTextStorage, ClickableTextView, ProseEditorRepresentable)
- Rust graph engine + markdown parser
- SwiftData models
- Graph visualization (Metal + Rust)
- AI pipeline (TriageService, PipelineService, LLMService)
- VaultSyncService (file I/O)
- All existing views except writer mode internals
