import Testing
import AppKit
@testable import Epistemos

@Suite("Document Mode - Storage")
struct DocumentModeStorageTests {

    @Test("TextKit 2 editor is vertically resizable")
    func textKit2EditorConfiguration() {
        let (scrollView, textView) = DocumentTextView.makeTextKit2()

        #expect(scrollView.documentView === textView)
        #expect(textView.isVerticallyResizable)
        #expect(!textView.isHorizontallyResizable)
        #expect(textView.maxSize.height > 0)
        #expect(textView.textLayoutManager != nil)
    }

    @Test("Document mode applies full theme palette")
    func documentThemeApplication() {
        let (_, textView) = DocumentTextView.makeTextKit2()

        textView.applyTheme(.sunny)
        #expect(textView.backgroundColor == NSColor(EpistemosTheme.sunny.background))
        #expect((textView.typingAttributes[.foregroundColor] as? NSColor) == NSColor(EpistemosTheme.sunny.foreground))

        textView.applyTheme(.ember)
        #expect(textView.backgroundColor == NSColor(EpistemosTheme.ember.background))
        #expect((textView.typingAttributes[.foregroundColor] as? NSColor) == NSColor(EpistemosTheme.ember.foreground))
    }

    @Test("Document mode rethemes existing content to the active app theme")
    func documentThemeRethemesContent() {
        let (_, textView) = DocumentTextView.makeTextKit2()
        let color = NSColor(EpistemosTheme.light.foreground)
        let content = NSAttributedString(string: "Theme me", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: color
        ])

        textView.textStorage?.setAttributedString(content)
        textView.rethemeContent(to: .ember)

        let updatedColor = textView.textStorage?.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
        #expect(updatedColor == NSColor(EpistemosTheme.ember.foreground))
    }

    @Test("Document toolbar table insert writes content directly")
    func documentToolbarTableInsert() {
        let (_, textView) = DocumentTextView.makeTextKit2()

        DocumentFormatBar.insertTable(into: textView, foregroundColor: NSColor(EpistemosTheme.light.foreground))

        #expect(textView.string.contains("Header"))
        #expect(textView.string.contains("Cell"))
    }

    @Test("Document toolbar formatting mutates typing attributes directly")
    func documentToolbarFormatting() {
        let (_, textView) = DocumentTextView.makeTextKit2()

        textView.toggleBold()
        textView.toggleUnderline()

        let font = textView.typingAttributes[.font] as? NSFont
        let underline = textView.typingAttributes[.underlineStyle] as? Int

        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(underline == NSUnderlineStyle.single.rawValue)
    }

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

@Suite("Document Mode - DOCX")
struct DocumentModeDOCXTests {

    @Test("DOCX export produces valid data")
    func docxExport() throws {
        let content = NSAttributedString(string: "Test document for DOCX export", attributes: [
            .font: NSFont.systemFont(ofSize: 14)
        ])
        let data = try DocumentImportExport.exportDOCX(content)
        #expect(data.count > 0)
        // DOCX is a zip — check PK magic bytes
        #expect(data[0] == 0x50)
        #expect(data[1] == 0x4B)
    }

    @Test("DOCX round-trip preserves text")
    func docxRoundTrip() throws {
        let original = NSAttributedString(string: "Round trip test content")
        let data = try DocumentImportExport.exportDOCX(original)

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-roundtrip-\(UUID().uuidString).docx")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let imported = try DocumentImportExport.importDocument(from: tmpURL)
        #expect(imported.string.contains("Round trip test content"))
    }

    @Test("PDF export produces data")
    func pdfExport() {
        let content = NSAttributedString(string: "PDF test content", attributes: [
            .font: NSFont.systemFont(ofSize: 14)
        ])
        let data = DocumentImportExport.exportPDF(content)
        #expect(data != nil)
        #expect((data?.count ?? 0) > 0)
    }

    @Test("DOCX export with empty content")
    func docxExportEmpty() throws {
        let content = NSAttributedString(string: "")
        let data = try DocumentImportExport.exportDOCX(content)
        #expect(data.count > 0)
        #expect(data[0] == 0x50)
        #expect(data[1] == 0x4B)
    }

    @Test("Import from nonexistent URL throws")
    func importNonexistent() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).docx")
        #expect(throws: (any Error).self) {
            try DocumentImportExport.importDocument(from: url)
        }
    }
}

// MARK: - Phase 0 Gap Fixes

@Suite("Document Mode - Wikilinks")
struct DocumentModeWikilinkTests {

    @Test("Wikilink detection applies link attribute")
    func wikilinkDetection() {
        let (_, textView) = DocumentTextView.makeTextKit2()
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "See [[My Note]] for details", attributes: [
                .font: NSFont.systemFont(ofSize: 14)
            ])
        )

        DocumentEditorRepresentable.Coordinator.applyWikilinkAttributes(to: textView.textStorage!)

        let link = textView.textStorage?.attribute(.link, at: 6, effectiveRange: nil) as? String
        #expect(link == "wikilink://My Note")
    }

    @Test("Wikilink detection handles multiple wikilinks")
    func multipleWikilinks() {
        let (_, textView) = DocumentTextView.makeTextKit2()
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "Link [[A]] and [[B]] here", attributes: [
                .font: NSFont.systemFont(ofSize: 14)
            ])
        )

        DocumentEditorRepresentable.Coordinator.applyWikilinkAttributes(to: textView.textStorage!)

        let linkA = textView.textStorage?.attribute(.link, at: 7, effectiveRange: nil) as? String
        let linkB = textView.textStorage?.attribute(.link, at: 17, effectiveRange: nil) as? String
        #expect(linkA == "wikilink://A")
        #expect(linkB == "wikilink://B")
    }

    @Test("Wikilink detection handles empty text")
    func emptyText() {
        let (_, textView) = DocumentTextView.makeTextKit2()
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "", attributes: [.font: NSFont.systemFont(ofSize: 14)])
        )

        DocumentEditorRepresentable.Coordinator.applyWikilinkAttributes(to: textView.textStorage!)
        #expect(textView.textStorage?.length == 0)
    }

    @Test("Wikilink detection ignores text without brackets")
    func noWikilinks() {
        let (_, textView) = DocumentTextView.makeTextKit2()
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "No links here", attributes: [
                .font: NSFont.systemFont(ofSize: 14)
            ])
        )

        DocumentEditorRepresentable.Coordinator.applyWikilinkAttributes(to: textView.textStorage!)

        let link = textView.textStorage?.attribute(.link, at: 0, effectiveRange: nil) as? String
        #expect(link == nil)
    }

    @Test("Wikilink brackets are dimmed")
    func bracketsDimmed() {
        let (_, textView) = DocumentTextView.makeTextKit2()
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "See [[Note]] end", attributes: [
                .font: NSFont.systemFont(ofSize: 14)
            ])
        )

        DocumentEditorRepresentable.Coordinator.applyWikilinkAttributes(to: textView.textStorage!)

        // Opening brackets at position 4-5
        let openColor = textView.textStorage?.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
        #expect(openColor == NSColor.tertiaryLabelColor)
        // Closing brackets at position 10-11
        let closeColor = textView.textStorage?.attribute(.foregroundColor, at: 10, effectiveRange: nil) as? NSColor
        #expect(closeColor == NSColor.tertiaryLabelColor)
    }
}

@Suite("Document Mode - Data Detection")
struct DocumentModeDataDetectionTests {

    @Test("Data detection styles phone numbers")
    func phoneDetection() {
        let text = "Call me at 555-123-4567 tomorrow"
        let items = DataDetectionService.detect(in: text)
        let phoneItems = items.filter {
            if case .phoneNumber = $0.kind { return true }
            return false
        }
        #expect(!phoneItems.isEmpty)
    }

    @Test("Data detection styles URLs")
    func urlDetection() {
        let text = "Visit https://example.com for more"
        let items = DataDetectionService.detect(in: text)
        let linkItems = items.filter {
            if case .link = $0.kind { return true }
            return false
        }
        #expect(!linkItems.isEmpty)
    }

    @Test("Data detection applies underline attribute")
    func underlineAttribute() {
        let (_, textView) = DocumentTextView.makeTextKit2()
        let text = "Visit https://example.com today"
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 14)])
        )

        let items = DataDetectionService.detect(in: text)
        guard !items.isEmpty else { return }
        textView.textStorage!.beginEditing()
        DataDetectionService.styleDetectedRanges(in: textView.textStorage!, items: items, isDark: false)
        textView.textStorage!.endEditing()

        let detected = textView.textStorage?.attribute(
            DataDetectionService.detectedDataKey,
            at: items[0].range.location,
            effectiveRange: nil
        )
        #expect(detected != nil)
    }

    @Test("Data detection handles empty text")
    func emptyDetection() {
        let items = DataDetectionService.detect(in: "")
        #expect(items.isEmpty)
    }
}

@Suite("Document Mode - Rich Text TOC")
struct DocumentModeRichTextTOCTests {

    @Test("TOC parser extracts headings from rich text by font size")
    func richTextTOC() {
        let text = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 16)
        let h1Font = NSFont.systemFont(ofSize: 28, weight: .bold)
        let h2Font = NSFont.systemFont(ofSize: 22, weight: .semibold)

        text.append(NSAttributedString(string: "Introduction\n", attributes: [.font: h1Font]))
        text.append(NSAttributedString(string: "Some body text here.\n", attributes: [.font: bodyFont]))
        text.append(NSAttributedString(string: "Methods\n", attributes: [.font: h2Font]))
        text.append(NSAttributedString(string: "More body text.\n", attributes: [.font: bodyFont]))

        let items = TOCParser.parseRichText(text)
        #expect(items.count == 2)
        #expect(items[0].title == "Introduction")
        #expect(items[0].level == 1)
        #expect(items[1].title == "Methods")
        #expect(items[1].level == 2)
    }

    @Test("TOC parser handles H3 headings")
    func h3Headings() {
        let text = NSMutableAttributedString()
        let h3Font = NSFont.systemFont(ofSize: 18, weight: .medium)
        text.append(NSAttributedString(string: "Subsection\n", attributes: [.font: h3Font]))

        let items = TOCParser.parseRichText(text)
        #expect(items.count == 1)
        #expect(items[0].level == 3)
        #expect(items[0].title == "Subsection")
    }

    @Test("TOC parser ignores body text")
    func bodyTextIgnored() {
        let text = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 16)
        text.append(NSAttributedString(string: "Just a paragraph.\n", attributes: [.font: bodyFont]))
        text.append(NSAttributedString(string: "Another paragraph.\n", attributes: [.font: bodyFont]))

        let items = TOCParser.parseRichText(text)
        #expect(items.isEmpty)
    }

    @Test("TOC parser handles empty attributed string")
    func emptyTOC() {
        let items = TOCParser.parseRichText(NSAttributedString(string: ""))
        #expect(items.isEmpty)
    }

    @Test("TOC parser preserves charOffset")
    func charOffsets() {
        let text = NSMutableAttributedString()
        let h1Font = NSFont.systemFont(ofSize: 28, weight: .bold)
        let bodyFont = NSFont.systemFont(ofSize: 16)

        text.append(NSAttributedString(string: "Title\n", attributes: [.font: h1Font]))
        text.append(NSAttributedString(string: "Body text here.\n", attributes: [.font: bodyFont]))
        text.append(NSAttributedString(string: "Second Title\n", attributes: [.font: h1Font]))

        let items = TOCParser.parseRichText(text)
        #expect(items.count == 2)
        #expect(items[0].charOffset == 0)
        #expect(items[1].charOffset == 22) // "Title\n" (6) + "Body text here.\n" (16) = 22
    }

    @Test("TOC parser handles mixed heading levels")
    func mixedLevels() {
        let text = NSMutableAttributedString()
        let h1Font = NSFont.systemFont(ofSize: 28, weight: .bold)
        let h2Font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        let h3Font = NSFont.systemFont(ofSize: 18, weight: .medium)

        text.append(NSAttributedString(string: "Chapter 1\n", attributes: [.font: h1Font]))
        text.append(NSAttributedString(string: "Section A\n", attributes: [.font: h2Font]))
        text.append(NSAttributedString(string: "Detail\n", attributes: [.font: h3Font]))

        let items = TOCParser.parseRichText(text)
        #expect(items.count == 3)
        #expect(items[0].level == 1)
        #expect(items[1].level == 2)
        #expect(items[2].level == 3)
    }
}
