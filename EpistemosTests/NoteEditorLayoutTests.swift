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
    @Test("editor re-entry prefers the captured live body over an older persisted body")
    func editorReentryPrefersLiveBodySnapshot() {
        let page = SDPage(title: "Preview Toggle")
        page.saveBody("# Persisted\n\nOlder body")

        let snapshot = ProseEditorView.initialBodySnapshot(
            for: page,
            preferredBody: "# Persisted\n\nNewly pasted paragraph"
        )

        #expect(snapshot.bodyText == "# Persisted\n\nNewly pasted paragraph")
        #expect(snapshot.lastPersistedBody == "# Persisted\n\nNewly pasted paragraph")
    }

    @Test("preview handoff never reuses another note's captured body")
    func previewHandoffIgnoresOtherNotes() {
        let snapshot = NoteModeBodySnapshot(pageId: "note-a", body: "Body from note A")

        #expect(snapshot.body(ifMatches: "note-b") == nil)
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

    @Test("overlay-backed table markdown source text is hidden in TextKit 1")
    func renderedTableOverlaysHideTextKit1SourceText() throws {
        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.theme = .light
        storage.usesRenderedTableOverlays = true
        storage.replaceCharacters(
            in: NSRange(location: 0, length: storage.length),
            with: """
            | Name | Count |
            | --- | --- |
            | Pens | 12 |
            """
        )

        let text = storage.string as NSString
        let nameRange = try #require(text.range(of: "Name").location != NSNotFound ? text.range(of: "Name") : nil)
        let color = try #require(
            storage.attribute(.foregroundColor, at: nameRange.location, effectiveRange: nil) as? NSColor
        )

        #expect(color.alphaComponent == 0)
    }
}
