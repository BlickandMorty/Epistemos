import Foundation
import Testing
@testable import Epistemos

@Suite("File Attachment Builder")
struct FileAttachmentBuilderTests {
    @Test("text attachments truncate previews to the configured limit")
    func textAttachmentPreviewIsTruncated() async throws {
        let url = try temporaryFileURL(named: "notes.md")
        let text = String(repeating: "Epistemos ", count: 300)
        try text.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let attachment = await FileAttachmentBuilder.build(from: url)

        #expect(attachment.type == .text)
        #expect(attachment.mimeType == "text/plain")
        #expect(attachment.preview?.hasSuffix("\n...(truncated)") == true)
        #expect((attachment.preview?.count ?? 0) <= FileAttachmentBuilder.maxPreviewCharacters + 15)
    }

    @Test("large text attachments skip preview loading entirely")
    func largeTextAttachmentSkipsPreview() async throws {
        let url = try temporaryFileURL(named: "large.txt")
        let oversized = String(repeating: "0123456789", count: 70_000)
        try oversized.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let attachment = await FileAttachmentBuilder.build(from: url)

        #expect(attachment.type == .text)
        #expect(attachment.preview == nil)
        #expect(attachment.size > FileAttachmentBuilder.maxPreviewBytes)
    }

    @Test("csv attachments reuse the text preview path")
    func csvAttachmentUsesBoundedPreview() async throws {
        let url = try temporaryFileURL(named: "table.csv")
        let csv = """
        name,count
        pens,12
        paper,4
        """
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let attachment = await FileAttachmentBuilder.build(from: url)

        #expect(attachment.type == .csv)
        #expect(attachment.mimeType == "text/csv")
        #expect(attachment.preview == csv)
    }

    @Test("text attachments decode UTF-16 previews instead of showing gibberish")
    func textAttachmentPreviewDecodesUtf16() async throws {
        let url = try temporaryFileURL(named: "kimi.txt")
        let content = "Kimi text\ncafé 🚀"
        guard let data = content.data(using: .utf16) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let attachment = await FileAttachmentBuilder.build(from: url)

        #expect(attachment.type == .text)
        #expect(attachment.preview == content)
    }

    @Test("attached text context reopens percent encoded file URLs and preserves markdown content")
    func attachedTextContextReopensPercentEncodedFileURL() async throws {
        let url = try temporaryFileURL(named: "vault note cafe.md")
        let content = """
        # Vault Note

        This came from a markdown file with spaces in its URL.
        """
        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let attachment = await FileAttachmentBuilder.build(from: url)
        let context = ChatCoordinator.buildFileAttachmentContext(from: [attachment], supportsVision: false)

        #expect(context?.contains("## Required File Attachments") == true)
        #expect(context?.contains("Attached file: vault note cafe.md") == true)
        #expect(context?.contains("Status: Required context explicitly attached or requested by the user.") == true)
        #expect(context?.contains("Treat them as the primary subject of the request unless the user clearly says otherwise.") == true)
        #expect(context?.contains("any extracted `Content:` below is already available for you to use directly") == true)
        #expect(context?.contains("Do not ask the user to locate, reattach, or restate it.") == true)
        #expect(context?.contains("Writable file path (use this exact value with `write_file.path` only when the user asks you to edit this attached text file): \(url.path)") == true)
        #expect(context?.contains("# Vault Note") == true)
        #expect(context?.contains("spaces in its URL") == true)
    }

    @Test("attached text context falls back to cached preview when the file can no longer be reopened")
    func attachedTextContextFallsBackToPreview() {
        let attachment = FileAttachment(
            id: UUID().uuidString,
            name: "offline.md",
            type: .text,
            uri: "file:///Users/jojo/Definitely%20Missing/offline.md",
            size: 128,
            mimeType: "text/plain",
            preview: "Cached text from the earlier attachment scan."
        )

        let context = ChatCoordinator.buildFileAttachmentContext(from: [attachment], supportsVision: false)

        #expect(context?.contains("Attached file: offline.md") == true)
        #expect(context?.contains("Writable file path") == false)
        #expect(context?.contains("Cached text from the earlier attachment scan.") == true)
    }

    @Test("image attachments tell text-only models not to invent unseen details")
    func imageAttachmentContextRespectsVisionCapabilities() {
        let attachment = FileAttachment(
            id: UUID().uuidString,
            name: "diagram.png",
            type: .image,
            uri: "file:///tmp/diagram.png",
            size: 64,
            mimeType: "image/png",
            preview: nil
        )

        let textOnlyContext = ChatCoordinator.buildFileAttachmentContext(from: [attachment], supportsVision: false)
        let visionContext = ChatCoordinator.buildFileAttachmentContext(from: [attachment], supportsVision: true)

        #expect(textOnlyContext?.contains("This model cannot inspect images directly.") == true)
        #expect(visionContext?.contains("This model can inspect images directly.") == true)
    }

    private func temporaryFileURL(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "file-attachment-builder-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name, isDirectory: false)
    }
}
