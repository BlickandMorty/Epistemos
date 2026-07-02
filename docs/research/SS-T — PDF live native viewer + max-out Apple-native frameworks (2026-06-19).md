---
id: 37505EE4-F796-4B43-B9EB-1EF55B88745B
title: SS-T — PDF live native viewer + max-out Apple-native frameworks (2026-06-19)
---

# SS-T — PDF live native viewer + max-out Apple-native frameworks (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the PDF-VIEWER / APPLE-NATIVE ledger item. Owner: *"a PDF*  
*live native viewer — use all of Apple's native things (the PDF rich viewer + everything Apple supplies) to max*  
*out my app with the bare-but-robust Apple-native tools."* Doctrine: local-first, MAS-safe, native-first,  
integrate (don't just list).

## Headline

**There is NO live PDF viewer anywhere** — PDFKit is imported in exactly one file and used only as a headless  
text-extractor (`PDFDocument`→`page.string`), never `PDFView`. The owner's #1 ask (open/scroll/zoom/search/  
select/annotate/outline/thumbnail a PDF in-app) is a true greenfield gap on top of an **already-rich**  
Apple-native foundation. The app already ships **CoreSpotlight indexing, AppIntents/Shortcuts (large surface),**  
**Vision OCR, Speech (SFSpeechRecognizer + AVSpeech), the Translation framework, NaturalLanguage, WidgetKit,**  
**CryptoKit, CoreML, UTType, a WebKit host kit**. **Absent: QuickLook, QuickLookThumbnailing, VisionKit (Live**  
**Text/DataScanner), PencilKit, PhotosUI, MapKit, EventKit, SoundAnalysis.** Strongest near-term wins: a real  
`PDFView` viewer + QuickLook universal preview + VisionKit Live Text — all MAS-safe, all reusing existing seams.

## PDF / document viewing today

- **PDFKit — extract only, no viewer.** `KnowledgeFusion/DataIngestion/VaultParser.swift:2 import PDFKit`; `:239 PDFDocument(url:)`; loop `:248-258` pulls `page.string` (page/char caps). Ingest-for-search, NOT a viewer.
- **PDF export (WebKit→PDF), not view.** `Engine/HTMLWorkspacePDFExporter.swift:9` renders an `HTMLWorkspace Package` through an offscreen `WKWebView` to PDF `Data`. One-way export.
- **PDF import→Markdown (no render).** `LiteParse/LiteParsePDFImportController.swift:11` converts PDF→Markdown  
`SDPage`; honestly returns `.notWired` until a native PDFium vendor lands (no fake note). Mounts: `Views/Notes/ NotesSidebar.swift:1194`, `Views/Settings/LiteParseSettingsImportRow.swift:32`.
- **NSDocument/Epdoc** = bespoke `.epdoc` doc layer (`App/EpistemosDocumentController.swift`, `Models/Epdoc Package.swift`), not a PDF viewer.
- **QuickLook: completely absent** (zero `QLPreviewController`/`QLPreviewPanel`/`QLThumbnailGenerator`). **Gap to**  
**a live PDF viewer: total** — no `PDFView` mount, no thumbnail/outline/search/selection/annotation surface.

## Apple frameworks already imported vs absent

**Imported &amp; used:** PDFKit (extract, `VaultParser.swift:2`) · Vision OCR (`Views/Notes/NoteImageProcessor .swift:54 VNRecognizeTextRequest`; `Omega/Vision/Screen2AXFusion.swift:154`) · Speech (`KnowledgeFusion/Data Ingestion/AudioTranscriber.swift:85 SFSpeechRecognizer`; AVSpeech `Views/Shared/ReadAloudButton.swift` = SS-K) ·  
**Translation** (`Views/Notes/NoteDetailWorkspaceView.swift:951 .translationPresentation`) · CoreSpotlight  
(`App/EpistemosApp.swift:2,249` + `Engine/SpotlightIndexer.swift`, `Sync/NoteEntitySpotlightIndexer.swift`,  
`Sync/VaultIndexActor.swift`) · AppIntents/Shortcuts (`Intents/EpistemosShortcutsProvider.swift`, `Intents/ Schemas/*`, `IndexedEntity`) · WidgetKit (`Intents/Schemas/EpistemosControlWidget.swift`) · NaturalLanguage  
(`Graph/EmbeddingService.swift`) · WebKit host kit · CryptoKit, CoreML, UTType, Contacts (settings).  
**Absent (greenfield):** QuickLook, QuickLookThumbnailing, **VisionKit** (Live Text/`DataScannerViewController`/  
`ImageAnalyzer`/`VNDocumentCameraViewController`), PencilKit, PhotosUI, MapKit, EventKit, SoundAnalysis. (Plain  
`Vision` present; VisionKit's Live-Text UI layer is not.)

## High-value native adds ranked (PDF viewer first)

1. **[#1, owner ask] PDFKit live** `PDFView` **viewer — high value / low effort / MAS-safe.** `PDFView`-backed  
NSViewRepresentable`(display mode,`PDFThumbnailView`,` PDFOutline`, built-in find` PDFView.findString`,   ext selection,` PDFAnnotation`). Mount from (a) the LiteParse import row (preview), (b) a note attachment /   ile row, (c) NSDocument open of` .pdf`. Reuses the proven` PDFDocument(url:) `load (`VaultParser.swift:239`).
2. **QuickLook universal preview — high / low / MAS-safe.** `QLPreviewController`/`QLPreviewPanel` for ANY vault  
ile type (pdf/docx/images/csv). Zero today; one file-row action covers dozens of formats.
3. **VisionKit Live Text + OCR-over-PDF/images — high / medium / MAS-safe.** OCR engine exists  
`NoteImageProcessor.swift:54`); add VisionKit `ImageAnalyzer`/Live Text selectable overlays + run Vision OCR  
ver PDF page renders + scanned images → feeds search/vault. (`VNDocumentCameraViewController` is iOS-only;  
acOS scan via Continuity Camera = unverified.)
4. **QuickLookThumbnailing — med / low.** `QLThumbnailGenerator` thumbnails for file/PDF rows.
5. **Translation expansion — med / low.** Already in notes (`:951`); extend `.translationPresentation` to chat  
essages + PDF selection.
6. **AppIntents for PDF/QuickLook/OCR actions — med / low.** Mature `Intents/` framework; expose "Open PDF"/  
OCR file"/"Preview file" mirroring `Schemas/*Intents.swift`.
7. **Spotlight extension — low / low.** Already indexing notes; extend `CSSearchableItem` to imported PDFs.
8. **PencilKit/**`PDFAnnotation` **markup — lower / medium.** `PDFAnnotation` is the cheaper macOS path than  
PKCanvasView`.

## Integration seams (compose, don't bolt on)

- **Vault + search:** OCR/extracted PDF text → `Sync/VaultIndexActor.swift` + `Sync/SearchIndexService.swift`  
(+ `Sync/RRFFusionQuery.swift` / `Engine/ShadowSearchService.swift`) so PDF/scanned text lands in shadow/RRF  
— same pipeline `VaultParser` already feeds.
- **Note/page model:** the PDF→note path writes `SDPage` (file-first); a live viewer reuses the `SDPage`+vault-  
file contract, not new storage.
- **Chat/tools:** a `PDFView` "send selection to chat" feeds `App/ChatCoordinator.swift`/`State/ChatState.swift`  
(loop `LocalAgent/LocalAgentLoop.swift`). NOTE: the Swift side has no `ToolRegistry` class — the tool surface  
is `LocalAgent/LocalToolGrammar.swift` + `Bridge/ToolTierBridge.swift` → the Rust `agent_core` registry (SS-H);  
new "open_pdf"/"ocr_file" tools register through that bridge, tier-gated.
- **AppIntents/Spotlight:** reuse `Intents/EpistemosShortcutsProvider.swift` + the `IndexedEntity` pattern so  
viewer/preview/OCR actions are Siri/Shortcuts/Spotlight reachable.

## Honest gating (entitlements)

- **MAS-safe, no extra entitlement:** PDFKit, QuickLook, QuickLookThumbnailing, Vision OCR, VisionKit Live Text,
Translation, NaturalLanguage, AppIntents, WidgetKit, CoreSpotlight, PencilKit — all local, on-device.
- **Already declared:** `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription` in both
`Epistemos-Info.plist:23/25` + `Epistemos-AppStore-Info.plist:21/23` (covers SS-K voice); folder-access
strings present; sandbox `Epistemos/Epistemos-AppStore.entitlements`.
- **Would need NEW usage strings (NOT for the PDF viewer):** Photos, Contacts (verify string), Calendar/EventKit,
Camera (document-scan). **The PDF viewer + QuickLook + OCR-over-imported-files need NONE of these.**
- **No-fake:** keep the honest gate — `LiteParsePDFImportController` returning `.notWired` is correct; a live
`PDFView` viewer is independent of liteparse and ships without it.

## Ordered plan

1. **[S] PDFKit `PDFView` viewer surface** — `NSViewRepresentable` + `PDFThumbnailView` + find/outline/selection;
ount from the LiteParse import row + a file/attachment row; load via `PDFDocument(url:)`. **The #1 ask.**
2. **[S] QuickLook preview action** — `QLPreviewController`/`QLPreviewPanel` on any vault file row.
3. **[S] QuickLookThumbnailing** — `QLThumbnailGenerator` thumbnails for file/PDF rows.
4. **[M] OCR-over-PDF/images into search** — run existing `VNRecognizeText` over PDF page renders + images →
VaultIndexActor`→`SearchIndexService`/RRF.
5. **[M] VisionKit Live Text overlay** — selectable text on image/PDF previews.
6. **[M] "Send PDF selection to chat" + AppIntents** — `PDFView` selection → `ChatState`; register open/preview/
cr as Shortcuts via `EpistemosShortcutsProvider`.
7. **[L] PencilKit/`PDFAnnotation` markup + Translation-on-selection** across chat/PDF.

## Unverified

macOS document-scan UI (`VNDocumentCameraViewController` is iOS; Continuity-Camera macOS path unverified);
whether `NSContactsUsageDescription` is present despite `import Contacts` in `ChannelsSettingsView.swift`; no
central Swift `ToolRegistry` class (tool surface = LocalAgent grammar/ToolTierBridge → Rust registry).

Key files: `KnowledgeFusion/DataIngestion/VaultParser.swift:2,239` · `Engine/HTMLWorkspacePDFExporter.swift:9` ·
`LiteParse/LiteParsePDFImportController.swift:11` (mounts `Views/Notes/NotesSidebar.swift:1194`, `Views/Settings/ LiteParseSettingsImportRow.swift:32`) · `Views/Notes/NoteImageProcessor.swift:54` (Vision OCR) · `Views/Notes/ NoteDetailWorkspaceView.swift:951` (Translation) · `App/EpistemosApp.swift:2,249` + `Engine/SpotlightIndexer .swift` + `Sync/VaultIndexActor.swift` · `Sync/SearchIndexService.swift` + `Sync/RRFFusionQuery.swift` +
`Engine/ShadowSearchService.swift` · `LocalAgent/LocalToolGrammar.swift` + `App/ChatCoordinator.swift` +
`State/ChatState.swift` · `Intents/EpistemosShortcutsProvider.swift` · `Epistemos-Info.plist:23/25` +
`Epistemos-AppStore-Info.plist:21/23` + `Epistemos/Epistemos-AppStore.entitlements`.