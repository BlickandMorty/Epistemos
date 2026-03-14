import AppKit
import Foundation
import Testing
@testable import Epistemos

@Suite("Note Image Processor")
struct NoteImageProcessorTests {
    @Test("large images are downscaled to the editor width limit")
    func largeImagesAreDownscaled() async throws {
        let url = try temporaryImageURL(width: 1200, height: 800)
        defer { cleanup(url) }

        let payload = await NoteImageProcessor.loadDisplayImage(from: url)

        #expect(payload != nil)
        #expect(Int(payload?.displaySize.width.rounded() ?? 0) == Int(NoteImageProcessor.maxDisplayWidth))
        #expect(Int(payload?.displaySize.height.rounded() ?? 0) == 400)
    }

    @Test("small images keep their original size")
    func smallImagesKeepOriginalSize() async throws {
        let url = try temporaryImageURL(width: 320, height: 200)
        defer { cleanup(url) }

        let payload = await NoteImageProcessor.loadDisplayImage(from: url)

        #expect(payload != nil)
        #expect(Int(payload?.displaySize.width.rounded() ?? 0) == 320)
        #expect(Int(payload?.displaySize.height.rounded() ?? 0) == 200)
    }

    @Test("invalid files return nil instead of blocking image work")
    func invalidFilesReturnNil() async throws {
        let directory = try temporaryDirectoryURL(named: "note-image-processor-invalid")
        let url = directory.appendingPathComponent("not-an-image.txt", isDirectory: false)
        try "epistemos".write(to: url, atomically: true, encoding: .utf8)
        defer { cleanup(url) }

        let payload = await NoteImageProcessor.loadDisplayImage(from: url)
        let extractedText = await NoteImageProcessor.extractText(from: url)

        #expect(payload == nil)
        #expect(extractedText == nil)
    }

    private func temporaryImageURL(width: Int, height: Int) throws -> URL {
        let directory = try temporaryDirectoryURL(named: "note-image-processor")
        let url = directory.appendingPathComponent("\(width)x\(height).png", isDirectory: false)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.imageContext
        }

        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            throw TestError.cgImage
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw TestError.pngRepresentation
        }

        try data.write(to: url, options: .atomic)
        return url
    }

    private func temporaryDirectoryURL(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(name)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private enum TestError: Error {
        case imageContext
        case cgImage
        case pngRepresentation
    }
}
