import Foundation
import Testing
@testable import Epistemos

@Suite("MappedNoteBody")
struct MappedNoteBodyTests {
    private func tempURL(ext: String = "md") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("mapped-note-\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }

    @Test("loads mapped data with correct byte count and string value")
    func loadsDataAndDecodesToString() throws {
        let content = "Mapped content for testing"
        let url = tempURL()
        try Data(content.utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapped = try MappedNoteBody(url: url)
        let byteCount = mapped.byteCount
        let isEmpty = mapped.isEmpty
        #expect(byteCount == Data(content.utf8).count)
        #expect(!isEmpty)

        let decoded = mapped.toString()
        #expect(decoded == content)
    }

    @Test("empty file is reported as empty")
    func emptyFileIsEmpty() throws {
        let url = tempURL()
        try Data().write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapped = try MappedNoteBody(url: url)
        let isEmpty = mapped.isEmpty
        let byteCount = mapped.byteCount
        #expect(isEmpty)
        #expect(byteCount == 0)
    }

    @Test("contains finds existing byte sequences")
    func containsFindsNeedle() throws {
        let content = "alpha beta gamma delta"
        let url = tempURL()
        try Data(content.utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapped = try MappedNoteBody(url: url)
        let hasBeta = mapped.contains(Array("beta".utf8))
        let hasGamma = mapped.contains(Array("gamma".utf8))
        #expect(hasBeta)
        #expect(hasGamma)
    }

    @Test("contains rejects empty, oversized, and missing needles")
    func containsRejectsInvalidNeedles() throws {
        let content = "short"
        let url = tempURL()
        try Data(content.utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapped = try MappedNoteBody(url: url)
        let emptyNeedle = mapped.contains([])
        let oversizedNeedle = mapped.contains(Array("this-is-longer-than-file".utf8))
        let missingNeedle = mapped.contains(Array("xyz".utf8))
        #expect(!emptyNeedle)
        #expect(!oversizedNeedle)
        #expect(!missingNeedle)
    }

    @Test("prefix returns requested leading bytes")
    func prefixReturnsLeadingBytes() throws {
        let content = "0123456789"
        let url = tempURL()
        try Data(content.utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapped = try MappedNoteBody(url: url)
        let firstFour = mapped.prefix(4)
        let allBytes = mapped.prefix(100)
        #expect(firstFour == Data("0123".utf8))
        #expect(allBytes == Data(content.utf8))
    }

    @Test("toString returns empty string for invalid UTF-8")
    func toStringInvalidUtf8() throws {
        let url = tempURL(ext: "bin")
        try Data([0xFF, 0xFE, 0xFD]).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapped = try MappedNoteBody(url: url)
        #expect(mapped.toString().isEmpty)
    }

    @Test("toString decodes UTF-16 text bodies")
    func toStringDecodesUtf16() throws {
        let content = "Kimi line\ncafé 🚀"
        let url = tempURL()
        guard let data = content.data(using: .utf16) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapped = try MappedNoteBody(url: url)
        #expect(mapped.toString() == content)
    }
}
