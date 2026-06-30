# Plan 3 - Apple-native Shared Views (shipped code): QuickLook + VisionKit + Thumbnails

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md` section 6. Plan 3 builds shared components only.
> Plan 2 owns editor/sidebar/pdf viewer integration. This codepack must not edit the Plan 2 editor, sidebar,
> HTML workspace, wikilinks, or PDF viewer surfaces.

## Scope Boundary

- Plan 3 owns reusable Apple-native shared views under `Epistemos/Views/Shared/*`.
- Plan 2 owns every consumer mount in the editor, sidebar, inline image, HTML workspace, wikilink, and PDF viewer surfaces.
- Do not edit NotesSidebar.
- Do not edit ProseInlineImage.
- Do not edit HTMLWorkspace.
- Do not build PDFView. PDFKit `PDFView` remains a Plan 2 viewer concern.
- Do not add Python, subprocess, Chromium, or browser-use runtime dependencies to the MAS path.
- Do not touch `Epistemos/Goose/*` or `Epistemos/Agent/*`.

## Verified Native Frameworks

QuickLook, VisionKit, and QuickLookThumbnailing are first-party Apple frameworks. The Plan 3 slice is MAS-safe because
it operates on already user-granted file URLs and in-memory `NSImage` values. It does not need new entitlements or
usage strings.

## Shipped implementation state

- **DONE:** `Epistemos/Views/Shared/FilePreview.swift` provides `FilePreviewItem`, `FilePreviewController`,
  `FilePreviewButton`, `.filePreview(_:)`, and a shared URL policy that rejects remote URLs, directories, unreadable
  files, non-regular files, final symlinks, and files over 512 MiB through a descriptor-backed `O_NOFOLLOW` + `fstat`
  envelope before Quick Look opens anything.
- **DONE:** `Epistemos/Views/Shared/LiveTextImageView.swift` provides a VisionKit-backed Live Text overlay when
  VisionKit is available and an honest image fallback when it is not, with a bounded image-analysis policy before
  VisionKit receives in-memory images.
- **DONE:** `Epistemos/Views/Shared/FileThumbnail.swift` provides `FileThumbnailer` and `FileThumbnailView`, with
  the same readable bounded regular-file URL policy, including no-follow non-regular and oversized file rejection, plus
  finite/max dimension and scale rejection before QuickLookThumbnailing generation.
- **Still Plan 2:** mounting these components in editor/sidebar/PDF viewer surfaces.

## 1. DELIVERED `Epistemos/Views/Shared/FilePreview.swift`

Build a reusable QuickLook preview layer for already-granted vault URLs:

- `FilePreviewItem: QLPreviewItem`
- `@MainActor FilePreviewController`
- `FilePreviewButton`
- `.filePreview($url)` one-shot SwiftUI modifier
- descriptor-backed `O_NOFOLLOW` + `fstat` URL validation with a 512 MiB cap

The controller should drive `QLPreviewPanel` directly through `QLPreviewPanelDataSource` and
`QLPreviewPanelDelegate`. Keep the component isolated so Plan 2 can mount it wherever its own surfaces allow.

## 2. DELIVERED `Epistemos/Views/Shared/LiveTextImageView.swift`

Build a reusable VisionKit Live Text overlay for images:

- macOS `NSViewRepresentable` wrapper around `ImageAnalysisOverlayView`
- async `ImageAnalyzer` pipeline guarded by `ImageAnalyzer.isSupported`
- bounded `LiveTextImageAnalysisPolicy` rejection for nil, empty, zero-size, non-finite, or oversized images before
  VisionKit analysis starts
- task cancellation when the image changes
- `onTextRecognized(transcript)` callback for the consumer to decide where indexing belongs

The shared view must not import or call editor/sidebar-specific types. It returns recognized text to its consumer.

## 3. DELIVERED `Epistemos/Views/Shared/FileThumbnail.swift`

Build a reusable QuickLookThumbnailing thumbnail layer:

- `FileThumbnailer.thumbnail(for:size:scale:) async -> NSImage?`
- `QLThumbnailGenerator.Request(fileAt:size:scale:representationTypes:.all)`
- `generateBestRepresentation(for:) async`
- `FileThumbnailView` SwiftUI wrapper with an SF Symbol fallback and `.task(id: url)`
- same bounded no-follow regular-file URL validation as Quick Look preview
- finite/max thumbnail dimension and scale validation, with a stable fallback frame for invalid view inputs

Keep all thumbnail policy in the shared component. Consumers decide placement later.

## Consumer Handoff

Plan 3 delivers the shared components and documents the adapter contract. Plan 2 can later consume these components
from its editor/sidebar/pdf viewer surfaces without Plan 3 modifying those files:

- Quick Look consumers pass a vault URL to `FilePreviewController` or `FilePreviewButton`.
- Live Text consumers pass a bounded image plus an `onTextRecognized` closure.
- Thumbnail consumers pass a vault URL and target size to `FileThumbnailView`.

## Done Bar

- New files are confined to `Epistemos/Views/Shared/`.
- Source guards prove this codepack stays in Plan 3 scope.
- Live Text analysis rejects invalid or oversized images before invoking VisionKit.
- No Plan 1 paths, Plan 2 editor paths, Python/subprocess/Chromium runtime, or `PDFView` viewer implementation is added.
- The implementation remains honest when native framework support is unavailable.
