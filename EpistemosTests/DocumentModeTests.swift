import Testing
import AppKit
@testable import Epistemos

@Suite("Document Mode - Storage")
struct DocumentModeStorageTests {

    @Test("RTFD round-trip preserves attributed string")
    func rtfdRoundTrip() throws {
        let pageId = "test-rtfd-\(UUID().uuidString)"
        let original = NSAttributedString(string: "Hello bold world", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ])

        NoteFileStorage.writeRichText(pageId: pageId, content: original)
        let loaded = NoteFileStorage.readRichText(pageId: pageId)
        #expect(loaded != nil)
        #expect(loaded?.string == "Hello bold world")

        NoteFileStorage.deleteRichText(pageId: pageId)
    }

    @Test("readRichText returns nil for nonexistent page")
    func rtfdMissing() {
        let result = NoteFileStorage.readRichText(pageId: "nonexistent-page-id-xyz")
        #expect(result == nil)
    }

    @Test("deleteRichText removes RTFD bundle")
    func rtfdDelete() {
        let pageId = "test-rtfd-delete-\(UUID().uuidString)"
        let content = NSAttributedString(string: "Delete me")
        NoteFileStorage.writeRichText(pageId: pageId, content: content)
        #expect(NoteFileStorage.readRichText(pageId: pageId) != nil)
        NoteFileStorage.deleteRichText(pageId: pageId)
        #expect(NoteFileStorage.readRichText(pageId: pageId) == nil)
    }

    @Test("SDPage format defaults to markdown")
    @MainActor func defaultFormat() {
        let page = SDPage(title: "Test")
        #expect(page.format == "markdown")
        #expect(!page.isRichText)
    }

    @Test("SDPage richtext format detected")
    @MainActor func richTextFormat() {
        let page = SDPage(title: "Test")
        page.format = "richtext"
        #expect(page.isRichText)
    }

    @Test("richTextExists returns false for nonexistent page")
    func richTextExistsMissing() {
        #expect(!NoteFileStorage.richTextExists(pageId: "nonexistent-xyz"))
    }
}
