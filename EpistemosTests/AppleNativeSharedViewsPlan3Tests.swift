import Foundation
import Testing

@Suite("Plan 3 Apple-native shared views")
struct AppleNativeSharedViewsPlan3Tests {
    @Test("shared files expose the expected Apple-native component APIs")
    func sharedFilesExposeExpectedComponentAPIs() throws {
        let preview = try loadMirroredSourceTextFile("Epistemos/Views/Shared/FilePreview.swift")
        let liveText = try loadMirroredSourceTextFile("Epistemos/Views/Shared/LiveTextImageView.swift")
        let thumbnail = try loadMirroredSourceTextFile("Epistemos/Views/Shared/FileThumbnail.swift")

        for required in [
            "final class FilePreviewItem: NSObject, QLPreviewItem",
            "final class FilePreviewController: NSObject, @MainActor QLPreviewPanelDataSource, @MainActor QLPreviewPanelDelegate",
            "struct FilePreviewButton",
            "func filePreview(_ previewURL: Binding<URL?>) -> some View",
            "QLPreviewPanel.shared()",
            "url.isFileURL"
        ] {
            #expect(preview.contains(required), "FilePreview missing expected API: \(required)")
        }

        for required in [
            "struct LiveTextImageView: NSViewRepresentable",
            "ImageAnalysisOverlayView",
            "ImageAnalyzer.isSupported",
            "ImageAnalyzer.Configuration([.text])",
            "analysisTask?.cancel()",
            "onTextRecognized(transcript)",
            "overlay.trackingImageView = imageView",
            "overlay.preferredInteractionTypes = .automatic"
        ] {
            #expect(liveText.contains(required), "LiveTextImageView missing expected API: \(required)")
        }

        for required in [
            "enum FileThumbnailer",
            "struct FileThumbnailView: View",
            "QLThumbnailGenerator.Request",
            "generateBestRepresentation(for: request)",
            "representationTypes: .all",
            ".task(id: thumbnailIdentity)",
            "url.isFileURL"
        ] {
            #expect(thumbnail.contains(required), "FileThumbnail missing expected API: \(required)")
        }
    }

    @Test("shared views stay out of Plan 1, Plan 2, and Pro-only runtimes")
    func sharedViewsStayInPlan3Boundary() throws {
        let files = [
            "Epistemos/Views/Shared/FilePreview.swift",
            "Epistemos/Views/Shared/LiveTextImageView.swift",
            "Epistemos/Views/Shared/FileThumbnail.swift",
        ]
        let combined = try files
            .map { try loadMirroredSourceTextFile($0) }
            .joined(separator: "\n")

        for forbidden in [
            "NotesSidebar",
            "ProseInlineImage",
            "HTMLWorkspace",
            "PDFView",
            "GooseSurface",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "SearchIndexService",
            "Process(",
            "subprocess",
            "Python",
            "python",
            "Chromium",
            "browser-use"
        ] {
            #expect(!combined.contains(forbidden), "Apple-native shared views crossed a forbidden boundary: \(forbidden)")
        }
    }
}
