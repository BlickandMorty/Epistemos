import AppKit
import Testing
@testable import Epistemos

@Suite("Note Editor Layout")
struct NoteEditorLayoutTests {
    @Test("top spacing stays tight below the toolbar")
    func topSpacingStaysTightBelowToolbar() {
        #expect(ProseEditorRepresentable.verticalInset == 40)
        #expect(MarkdownTextStorage.leadingH1SpacingBefore == 36)
        #expect(MarkdownTextStorage.sectionH1SpacingBefore == 30)
    }

    @MainActor
    @Test("editor bootstraps from persisted note body before the first onAppear")
    func editorBootstrapsFromPersistedBody() {
        let page = SDPage(title: "Bootstrap")
        page.saveBody("# Persisted\n\nBody")

        let snapshot = ProseEditorView.initialBodySnapshot(for: page)

        #expect(snapshot.bodyText == "# Persisted\n\nBody")
        #expect(snapshot.lastPersistedBody == "# Persisted\n\nBody")
    }

    @MainActor
    @Test("rendered tables reserve enough editor height to avoid overlapping following prose")
    func renderedTablesReserveEnoughHeight() throws {
        let markdown = """
        | Name | Count |
        | --- | --- |
        | Pens | 12 |
        | Paper | 4 |

        After
        """

        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.theme = .light

        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: 640, height: CGFloat.greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false

        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        storage.replaceCharacters(
            in: NSRange(location: 0, length: storage.length),
            with: markdown
        )
        layoutManager.ensureLayout(for: container)

        let text = storage.string as NSString
        let tableRange = try #require(MarkdownTableBlockRanges.ranges(in: text).first)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: tableRange,
            actualCharacterRange: nil
        )
        let allocatedHeight = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: container
        ).height

        let table = try #require(MarkdownTableModel.parse(text.substring(with: tableRange)))
        let overlay = NoteEditorRenderedTableHostingView(table: table, theme: .light)
        overlay.frame = NSRect(x: 0, y: 0, width: 640, height: 1)
        overlay.layoutSubtreeIfNeeded()
        let overlayHeight = overlay.fittingSize.height

        #expect(allocatedHeight >= overlayHeight)
    }
}
