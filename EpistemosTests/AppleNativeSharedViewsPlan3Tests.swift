import AppKit
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
            "maxPreviewFileBytes",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "S_IFREG",
            "st_size"
        ] {
            #expect(preview.contains(required), "FilePreview missing expected API: \(required)")
        }

        for required in [
            "struct LiveTextImageView: NSViewRepresentable",
            "nonisolated enum LiveTextImageAnalysisPolicy",
            "maxPointDimension",
            "maxPixelDimension",
            "maxPixelCount",
            "ImageAnalysisOverlayView",
            "ImageAnalyzer.isSupported",
            "LiveTextImageAnalysisPolicy.isEligibleForAnalysis(image)",
            "image.representations",
            "pixelsWide",
            "pixelsHigh",
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
            "maxThumbnailDimension",
            "maxThumbnailScale",
            "validatedSize",
            "displaySize"
        ] {
            #expect(thumbnail.contains(required), "FileThumbnail missing expected API: \(required)")
        }
    }

    @Test("thumbnailer rejects invalid inputs before Quick Look generation")
    func thumbnailerRejectsInvalidInputsBeforeQuickLookGeneration() async throws {
        let remoteURL = URL(string: "https://example.com/paper.pdf")!
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-native-thumbnail-policy-\(UUID().uuidString)", isDirectory: true)
        let fileURL = root.appendingPathComponent("thumbnail.txt", isDirectory: false)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("thumbnail source".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let missingFileURL = URL(fileURLWithPath: "/tmp/epistemos-missing-thumbnail.pdf")
        let size = CGSize(width: 32, height: 32)

        #expect(await FileThumbnailer.thumbnail(for: remoteURL, size: size, scale: 2) == nil)
        #expect(await FileThumbnailer.thumbnail(for: missingFileURL, size: .zero, scale: 2) == nil)
        #expect(await FileThumbnailer.thumbnail(for: fileURL, size: .zero, scale: 2) == nil)
        #expect(await FileThumbnailer.thumbnail(for: fileURL, size: CGSize(width: CGFloat.infinity, height: 32), scale: 2) == nil)
        #expect(
            await FileThumbnailer.thumbnail(
                for: fileURL,
                size: CGSize(width: FileThumbnailer.maxThumbnailDimension + 1, height: 32),
                scale: 2
            ) == nil
        )
        #expect(await FileThumbnailer.thumbnail(for: fileURL, size: size, scale: 0) == nil)
        #expect(await FileThumbnailer.thumbnail(for: fileURL, size: size, scale: CGFloat.infinity) == nil)
        #expect(await FileThumbnailer.thumbnail(for: fileURL, size: size, scale: FileThumbnailer.maxThumbnailScale + 1) == nil)
    }

    @Test("Live Text policy rejects invalid and oversized images before VisionKit analysis")
    func liveTextPolicyRejectsInvalidAndOversizedImagesBeforeVisionKitAnalysis() {
        let bounded = NSImage(size: NSSize(width: 128, height: 128))
        let boundedRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 128,
            pixelsHigh: 128,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        #expect(boundedRep != nil)
        if let boundedRep {
            bounded.addRepresentation(boundedRep)
        }

        let emptyContainer = NSImage(size: NSSize(width: 128, height: 128))
        let oversizedPoints = NSImage(
            size: NSSize(width: LiveTextImageAnalysisPolicy.maxPointDimension + 1, height: 128)
        )
        let oversizedPixels = NSImage(size: NSSize(width: 128, height: 128))
        let oversizedPixelRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: LiveTextImageAnalysisPolicy.maxPixelDimension + 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        #expect(oversizedPixelRep != nil)
        if let oversizedPixelRep {
            oversizedPixels.addRepresentation(oversizedPixelRep)
        }

        #expect(LiveTextImageAnalysisPolicy.isEligibleForAnalysis(bounded))
        #expect(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(nil))
        #expect(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(NSImage(size: .zero)))
        #expect(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(emptyContainer))
        #expect(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(oversizedPoints))
        #expect(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(oversizedPixels))
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

    @Test("preview policy rejects oversized file URLs")
    func previewPolicyRejectsOversizedFileURLs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-native-preview-size-\(UUID().uuidString)", isDirectory: true)
        let oversized = root.appendingPathComponent("Huge.pdf", isDirectory: false)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #expect(FileManager.default.createFile(atPath: oversized.path, contents: nil))
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(FilePreviewURLPolicy.maxPreviewFileBytes + 1))
        try handle.close()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(!FilePreviewController.isPreviewableURL(oversized))
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
