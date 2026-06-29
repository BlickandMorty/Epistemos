import Foundation
import Testing
@testable import Epistemos

@Suite("Plan 3 Apple-native shared views")
struct AppleNativeSharedViewsPlan3Tests {
    @Test("shared files expose the expected Apple-native component APIs")
    func sharedFilesExposeExpectedComponentAPIs() throws {
        let preview = try loadMirroredSourceTextFile("Epistemos/Views/Shared/FilePreview.swift")
        let liveText = try loadMirroredSourceTextFile("Epistemos/Views/Shared/LiveTextImageView.swift")
        let thumbnail = try loadMirroredSourceTextFile("Epistemos/Views/Shared/FileThumbnail.swift")

        for required in [
            "nonisolated enum FilePreviewURLPolicy",
            "isReadableRegularFileURL",
            "final class FilePreviewItem: NSObject, QLPreviewItem",
            "final class FilePreviewController: NSObject, @MainActor QLPreviewPanelDataSource, @MainActor QLPreviewPanelDelegate",
            "struct FilePreviewButton",
            "func filePreview(_ previewURL: Binding<URL?>) -> some View",
            "QLPreviewPanel.shared()",
            "destinationOfSymbolicLink(atPath:",
            "attributesOfItem(atPath:",
            "FileAttributeType",
            ".typeRegular"
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
            "FilePreviewURLPolicy.isReadableRegularFileURL(url)",
            "scale.isFinite",
            "scale > 0"
        ] {
            #expect(thumbnail.contains(required), "FileThumbnail missing expected API: \(required)")
        }
    }

    @Test("thumbnailer rejects invalid inputs before Quick Look generation")
    func thumbnailerRejectsInvalidInputsBeforeQuickLookGeneration() async {
        let remoteURL = URL(string: "https://example.com/paper.pdf")!
        let fileURL = URL(fileURLWithPath: "/tmp/epistemos-missing-thumbnail.pdf")
        let size = CGSize(width: 32, height: 32)

        #expect(await FileThumbnailer.thumbnail(for: remoteURL, size: size, scale: 2) == nil)
        #expect(await FileThumbnailer.thumbnail(for: fileURL, size: .zero, scale: 2) == nil)
        #expect(await FileThumbnailer.thumbnail(for: fileURL, size: size, scale: 0) == nil)
    }

    @Test("preview policy rejects remote directory and symlink URLs")
    func previewPolicyRejectsRemoteDirectoryAndSymlinkURLs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-native-preview-policy-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("Folder", isDirectory: true)
        let readableFile = root.appendingPathComponent("Note.md", isDirectory: false)
        let symlink = root.appendingPathComponent("Linked.md", isDirectory: false)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "note".write(to: readableFile, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: readableFile)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(FilePreviewController.isPreviewableURL(readableFile))
        #expect(!FilePreviewController.isPreviewableURL(URL(string: "https://example.com/paper.pdf")!))
        #expect(!FilePreviewController.isPreviewableURL(directory))
        #expect(!FilePreviewController.isPreviewableURL(symlink))
    }

    @Test("preview policy rejects non-regular file URLs")
    func previewPolicyRejectsNonRegularFileURLs() {
        let deviceURL = URL(fileURLWithPath: "/dev/null", isDirectory: false)
        guard FileManager.default.fileExists(atPath: deviceURL.path) else {
            return
        }

        #expect(!FilePreviewController.isPreviewableURL(deviceURL))
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
