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

    private func temporaryFileURL(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "file-attachment-builder-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name, isDirectory: false)
    }
}
