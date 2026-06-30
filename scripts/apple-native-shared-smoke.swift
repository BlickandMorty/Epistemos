import AppKit
import Foundation

@main
struct AppleNativeSharedSmoke {
    static func main() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-apple-native-shared-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            fail("could not create temp directory: \(error)")
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let textURL = root.appendingPathComponent("note.txt")
        let pngURL = root.appendingPathComponent("pixel.png")
        let directoryURL = root.appendingPathComponent("folder", isDirectory: true)
        let symlinkURL = root.appendingPathComponent("note-link.txt")
        let oversizedURL = root.appendingPathComponent("oversized.bin")

        do {
            try "Apple native preview smoke".write(to: textURL, atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: textURL)
            FileManager.default.createFile(atPath: oversizedURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: oversizedURL)
            try handle.truncate(atOffset: UInt64(FilePreviewURLPolicy.maxPreviewFileBytes + 1))
            try handle.close()
            try makePNGData().write(to: pngURL)
        } catch {
            fail("could not create proof fixtures: \(error)")
        }

        require(FilePreviewController.isPreviewableURL(textURL), "readable file should be QuickLook-previewable")
        require(!FilePreviewController.isPreviewableURL(URL(string: "https://example.com/file.pdf")!), "remote URL must not preview")
        require(!FilePreviewController.isPreviewableURL(directoryURL), "directory must not preview")
        require(!FilePreviewController.isPreviewableURL(symlinkURL), "final symlink must not preview")
        require(!FilePreviewController.isPreviewableURL(oversizedURL), "oversized file must not preview")

        let thumbnailSize = CGSize(width: 64, height: 64)
        require(FileThumbnailer.validatedSize(thumbnailSize) == thumbnailSize, "valid thumbnail size rejected")
        require(FileThumbnailer.validatedSize(.zero) == nil, "zero thumbnail size accepted")
        require(FileThumbnailer.validatedSize(CGSize(width: CGFloat.infinity, height: 64)) == nil, "non-finite thumbnail size accepted")
        require(
            FileThumbnailer.validatedSize(CGSize(width: FileThumbnailer.maxThumbnailDimension + 1, height: 64)) == nil,
            "oversized thumbnail size accepted"
        )
        let thumbnail = await FileThumbnailer.thumbnail(for: pngURL, size: thumbnailSize, scale: 2)
        require(thumbnail != nil, "QuickLookThumbnailing did not generate a PNG thumbnail")
        let symlinkThumbnail = await FileThumbnailer.thumbnail(for: symlinkURL, size: thumbnailSize, scale: 2)
        require(symlinkThumbnail == nil, "symlink thumbnail generated")
        let invalidSizeThumbnail = await FileThumbnailer.thumbnail(for: pngURL, size: .zero, scale: 2)
        require(invalidSizeThumbnail == nil, "invalid-size thumbnail generated")

        let validImage = NSImage(size: NSSize(width: 16, height: 16))
        validImage.addRepresentation(makeBitmapRep(width: 16, height: 16))
        let emptyImage = NSImage(size: NSSize(width: 16, height: 16))
        let oversizedPoints = NSImage(size: NSSize(width: LiveTextImageAnalysisPolicy.maxPointDimension + 1, height: 16))
        let oversizedPixels = NSImage(size: NSSize(width: 16, height: 16))
        oversizedPixels.addRepresentation(makeBitmapRep(width: LiveTextImageAnalysisPolicy.maxPixelDimension + 1, height: 1))

        require(LiveTextImageAnalysisPolicy.isEligibleForAnalysis(validImage), "valid image rejected for Live Text")
        require(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(nil), "nil image accepted for Live Text")
        require(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(NSImage(size: .zero)), "zero-size image accepted for Live Text")
        require(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(emptyImage), "empty image container accepted for Live Text")
        require(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(oversizedPoints), "oversized point image accepted for Live Text")
        require(!LiveTextImageAnalysisPolicy.isEligibleForAnalysis(oversizedPixels), "oversized pixel image accepted for Live Text")

        print("apple-native shared smoke OK: quicklook_policy=true thumbnail_generated=true livetext_policy=true")
    }

    private static func makePNGData() throws -> Data {
        guard let data = makeBitmapRep(width: 16, height: 16).representation(using: .png, properties: [:]) else {
            throw SmokeError.fixtureEncoding
        }
        return data
    }

    private static func makeBitmapRep(width: Int, height: Int) -> NSBitmapImageRep {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fail("could not create bitmap representation")
        }
        return rep
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("apple-native shared smoke failed: \(message)\n".utf8))
        Foundation.exit(1)
    }

    private enum SmokeError: Error {
        case fixtureEncoding
    }
}
