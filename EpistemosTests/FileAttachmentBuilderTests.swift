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

    @Test("attachment diagnostics redact file errors")
    func attachmentDiagnosticsRedactFileErrors() throws {
        let error = NSError(
            domain: "NSCocoaErrorDomain\n/Users/jojo/PrivateVault",
            code: 257,
            userInfo: [
                NSLocalizedDescriptionKey: "/Users/jojo/PrivateVault/secret.md denied"
            ]
        )

        let message = FileAttachmentDiagnostics.logMessage(
            for: error,
            fallback: "FileAttachmentBuilder: failed to read preview"
        )

        #expect(message.contains("FileAttachmentBuilder: failed to read preview"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=257"))
        #expect(message.count <= FileAttachmentDiagnostics.maxLogMessageCharacters)
        #expect(!message.contains("/Users/jojo"))
        #expect(!message.contains("PrivateVault"))
        #expect(!message.contains("secret.md"))

        let longName = String(repeating: "a", count: FileAttachmentDiagnostics.maxDisplayNameCharacters + 32) + ".pdf"
        #expect(FileAttachmentDiagnostics.displayName("  \(longName)\n").count == FileAttachmentDiagnostics.maxDisplayNameCharacters)
    }

    @Test("attachment logs avoid raw file errors")
    func attachmentLogsAvoidRawFileErrors() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ChatComposerKeyboard.swift")

        #expect(source.contains("FileAttachmentDiagnostics.logMessage"))
        #expect(source.contains("FileAttachmentDiagnostics.displayName(url.lastPathComponent)"))
        #expect(source.contains("String(message.prefix(maxLogMessageCharacters + 32))"))
        #expect(source.contains("String(domain.prefix(maxDomainCharacters + 32))"))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
        #expect(!source.contains("failed to read file size for \\(url.lastPathComponent"))
        #expect(!source.contains("failed to read preview for \\(url.lastPathComponent"))
        #expect(!source.contains("failed to close preview handle for \\(url.lastPathComponent"))
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
