# Plan 3 — Apple-native: QuickLook + VisionKit + thumbnails (clone-ready code, Pass 4)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §6`. Three first-party frameworks, all greenfield, all MAS-safe
> (no new entitlement / usage-string — they operate on URLs/images already in the user-granted vault scope). The PDF
> *viewer* (PDFKit `PDFView`) is **Plan 2** — NOT built here. `[VERIFIED-CODE]`/`[WEB]`/`[INFERRED]` tagged.

## Verified surfaces to wire into
`NotesSidebar.swift:65 SidebarDocumentItem{url}`, `:2845 DocumentRow` (Button→`.openDocument`; has `.contextMenu`),
`:2884 HTMLWorkspaceRow`, `:2025 .openDocument` handler, `:207 SidebarAction`; `NoteImageProcessor.swift:54`
`VNRecognizeTextRequest` OCR (`extractText→String?`); `SearchIndexService.swift:1666 upsert(id:title:body:tags:updatedAt:)`
(the ingest entrypoint). QuickLook/VisionKit/QuickLookThumbnailing = **zero hits today** (greenfield).

## 1. NEW `Epistemos/Views/Shared/FilePreview.swift` — QuickLook universal preview
Zero per-format code (PDF/docx/iWork/images/csv). Drives `QLPreviewPanel` directly via a `@MainActor
FilePreviewController` (`QLPreviewPanelDataSource/Delegate`) rather than the SwiftUI `.quickLookPreview` modifier, which
is flaky on macOS when an `NSTextView` holds focus `[WEB]` (the sidebar sits next to the prose editor). Exposes
`FilePreviewButton{ url }` + a `.filePreview($url)` one-shot modifier. `FilePreviewItem: QLPreviewItem`
(`previewItemURL/Title`). Signatures current `[WEB]`.

## 2. NEW `Epistemos/Views/Shared/LiveTextImageView.swift` — VisionKit Live Text
`ImageAnalysisOverlayView` (macOS NSView → `NSViewRepresentable`) + `ImageAnalyzer` → selectable/copyable/searchable
Live Text over any image or rendered PDF page. `Configuration([.text])`, `analyzer.analyze(image, orientation:.up,
configuration:) async throws → ImageAnalysis`, `.transcript`, `overlay.preferredInteractionTypes=.automatic`,
`overlay.trackingImageView?.image`, `overlay.analysis`. Guarded by `ImageAnalyzer.isSupported`; cancels prior task on
image change. **Feeds search:** `onTextRecognized(transcript)` → `searchIndex.upsert(id:"livetext:<path>", body:transcript,
tags:"ocr,livetext", …)` (`SearchIndexService.swift:1666`) — additive to the headless `VNRecognizeTextRequest` path, both
land in FTS. Signatures current `[WEB]`.

## 3. NEW `Epistemos/Views/Shared/FileThumbnail.swift` — QuickLookThumbnailing
`FileThumbnailer.thumbnail(for:size:scale:) async -> NSImage?` via `QLThumbnailGenerator.Request(fileAt:size:scale:
representationTypes:.all)` + `generateBestRepresentation(for:) async`. Async SwiftUI `FileThumbnailView` with SF-Symbol
fallback + `.task(id:url)` (auto cancel/re-run). Signatures current `[WEB]`.

## 4. Wiring (real edits)
- **Quick Look** — `NotesSidebar.swift:2875 DocumentRow.contextMenu` (+ `:2914 HTMLWorkspaceRow`): add
  `Button("Quick Look"){ FilePreviewController.shared.present(urls:[item.url]) }`. Optional spacebar: new
  `SidebarAction.quickLook(URL)` (`:207`) handled like `.openDocument` (`:2025`) but calling the preview controller.
- **Thumbnail** — `NotesSidebar.swift:2857 DocumentRow` HStack: replace the static `Image(systemName:"doc.richtext")`
  with `FileThumbnailView(url: item.url, size: 14×18)`.
- **Live Text** — host on the inline-image/attachment surfaces (`ProseInlineImageSupport.swift`/`ProseInlineImageLayout.swift`):
  overlay `LiveTextImageView(image:onTextRecognized:)` → `SearchIndexService.upsert`.

## MAS-safety
All three are first-party, no new entitlement, no `Info.plist` usage string; operate on already-granted vault URLs /
in-memory `NSImage`s. Sandbox-clean. New = three additive `Views/Shared/*.swift` files + 1–3-line edits at the cited
`NotesSidebar.swift` lines.

## Sources
VisionKit/`ImageAnalyzer`/`ImageAnalysisOverlayView` (Apple Developer + WWDC23 — macOS overlay is NSView); `QLThumbnailGenerator`
+ `generateBestRepresentation`; QuickLook-in-SwiftUI NSTextView-focus caveat (Apple Developer Forums).
