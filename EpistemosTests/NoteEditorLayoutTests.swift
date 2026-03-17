import AppKit
import SwiftData
import Testing
import SwiftUI
@testable import Epistemos

@Suite("Note Editor Layout")
struct NoteEditorLayoutTests {
    @MainActor
    private final class HostingViewFixtureRetainer {
        static let shared = HostingViewFixtureRetainer()
        private var views: [NSView] = []

        func retain(_ view: NSView) {
            view.removeFromSuperview()
            views.append(view)
        }
    }

    @MainActor
    private func retainHostingFixture(_ view: NSView) {
        HostingViewFixtureRetainer.shared.retain(view)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("note footer uses glass chips and keeps the legacy shortcut hints")
    func noteFooterUsesGlassChipsAndLegacyHints() {
        #expect(!NoteWorkspaceFooterDisplay.showsBottomFade)
        #expect(NoteWorkspaceFooterDisplay.chipSpacing == 8)
        #expect(NoteWorkspaceFooterDisplay.shortcuts.map(\.key) == ["S", "2"])
        #expect(
            NoteWorkspaceFooterDisplay.shortcuts.map(\.label) == ["Save to Disk", "Note Sidebar"]
        )
    }

    @Test("preview reserves the native titlebar inset and falls back higher for tab groups")
    func previewReservesTitlebarInset() {
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 0, hasMultipleTabs: false)
                == NotePreviewChromeMetrics.fallbackSingleTopInset
        )
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 0, hasMultipleTabs: true)
                == NotePreviewChromeMetrics.fallbackTabbedTopInset
        )
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 52, hasMultipleTabs: false)
                == 52
        )
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 88, hasMultipleTabs: true)
                == 88
        )
    }

    @Test("top spacing stays tight below the toolbar")
    func topSpacingStaysTightBelowToolbar() {
        #expect(ProseEditorRepresentable.verticalInset == 40)
        #expect(MarkdownTextStorage.leadingH1SpacingBefore == 36)
        #expect(MarkdownTextStorage.sectionH1SpacingBefore == 30)
        #expect(NoteEditorPerformancePolicy.renderedTableOverlayRefreshDelay == .milliseconds(120))
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

    @MainActor
    @Test("note workspace falls back to loadBody when its cached persisted body is empty")
    func noteWorkspacePersistedBodyFallsBackToLoadBody() {
        let page = SDPage(title: "Fallback")
        page.body = "# Inline\n\nRecovered body"

        let resolved = NoteDetailWorkspaceView.resolvedPersistedBody("", for: page)

        #expect(resolved == "# Inline\n\nRecovered body")
    }

    @Test("preview handoff never reuses another note's captured body")
    func previewHandoffIgnoresOtherNotes() {
        let snapshot = NoteModeBodySnapshot(pageId: "note-a", body: "Body from note A")

        #expect(snapshot.body(ifMatches: "note-b") == nil)
    }

    @MainActor
    @Test("editor tables collapse into compact placeholders instead of full inline previews")
    func editorTablesCollapseIntoCompactPlaceholders() throws {
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
        storage.usesRenderedTableOverlays = true

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
        let placeholder = NoteEditorRenderedTableHostingView(table: table, theme: .light)
        placeholder.update(
            table: table,
            theme: .light,
            frame: NSRect(x: 0, y: 0, width: 640, height: allocatedHeight)
        )

        let popoverPreviewSize = NoteEditorRenderedTablePopoverContent.preferredSize(for: table)

        #expect(allocatedHeight < popoverPreviewSize.height)
        #expect(placeholder.frame.height < popoverPreviewSize.height)
        #expect(placeholder.frame.height <= 28)
        #expect(placeholder.frame.width < 200)
    }

    @Test("classic editor uses the same readable inset for table and prose notes")
    func classicEditorUsesSameInsetForTableAndProseNotes() {
        let proseInset = ProseEditorRepresentable.horizontalInset(
            for: 1000,
            markdown: "# Heading\n\nBody"
        )
        let tableInset = ProseEditorRepresentable.horizontalInset(
            for: 1000,
            markdown: """
            | Name | Count |
            | --- | --- |
            | Pens | 12 |
            """
        )

        #expect(tableInset == proseInset)
    }

    @Test("classic editor typing attributes reset to body style")
    func classicEditorTypingAttributesResetToBodyStyle() throws {
        let attributes = ProseEditorRepresentable.typingAttributes(for: .light)
        let font = try #require(attributes[.font] as? NSFont)
        let paragraphStyle = try #require(attributes[.paragraphStyle] as? NSParagraphStyle)

        #expect(font.pointSize == MarkdownTextStorage.noteBaseFontSize)
        #expect(paragraphStyle.firstLineHeadIndent == MarkdownTextStorage.bodyParagraphStyle().firstLineHeadIndent)
        #expect(paragraphStyle.headIndent == MarkdownTextStorage.bodyParagraphStyle().headIndent)
    }

    @Test("classic editor notification page matching rejects stale page ids")
    func classicEditorNotificationPageMatchingRejectsStalePageIds() {
        #expect(ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: "page-a"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: "page-b"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId(nil, coordinatorPageId: "page-a"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: nil))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("", coordinatorPageId: "page-a"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: ""))
    }

    @MainActor
    @Test("classic editor dismantle unregisters content-view observers before teardown")
    func classicEditorDismantleUnregistersContentViewObservers() {
        let editor = ProseEditorRepresentable(
            text: .constant("Body"),
            pageId: "page-a",
            pageBody: "Body",
            isFocused: false,
            theme: .light,
            isEditable: true,
            isFocusMode: false
        )
        let coordinator = editor.makeCoordinator()
        let scrollView = NSScrollView()
        let textView = ClickableTextView(frame: .zero, textContainer: nil)
        scrollView.documentView = textView
        coordinator.lastPageId = "page-a"

        let clipView = scrollView.contentView
        var frameNotifications = 0
        var boundsNotifications = 0

        coordinator.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: nil
        ) { _ in
            frameNotifications += 1
        }
        coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: nil
        ) { _ in
            boundsNotifications += 1
        }

        ProseEditorRepresentable.dismantleNSView(scrollView, coordinator: coordinator)

        NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: clipView)
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: clipView)

        #expect(frameNotifications == 0)
        #expect(boundsNotifications == 0)
        #expect(coordinator.frameObserver == nil)
        #expect(coordinator.scrollObserver == nil)
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

    @Test("table placeholders use the first non-empty header cell as the title")
    func tablePlaceholderUsesFirstNonEmptyHeaderCell() throws {
        let table = try #require(
            MarkdownTableModel.parse(
                """
                |   | Δ Count |
                | --- | --- |
                | Pens | 12 |
                """
            )
        )

        #expect(table.placeholderLabel == "Table: Δ Count")
    }

    @MainActor
    @Test("table popover renders a full-sized table surface")
    func tablePopoverRendersFullSizedTableSurface() throws {
        let table = try #require(
            MarkdownTableModel.parse(
                """
                | Subject | Score |
                | --- | --- |
                | Pens | 12 |
                | Paper | 4 |
                """
            )
        )

        let size = NoteEditorRenderedTablePopoverContent.preferredSize(for: table)
        let host = NSHostingView(
            rootView: NoteEditorRenderedTablePopoverContent(table: table, theme: .light)
        )
        defer { retainHostingFixture(host) }
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize.width >= size.width - 20)
        #expect(host.fittingSize.height >= 80)
    }

    @MainActor
    @Test("table placeholder keeps typing click-through outside the preview hotspot")
    func tablePlaceholderKeepsTypingClickThroughOutsidePreviewHotspot() throws {
        let table = try #require(
            MarkdownTableModel.parse(
                """
                | Subject | Score |
                | --- | --- |
                | Pens | 12 |
                """
            )
        )

        let host = NoteEditorRenderedTableHostingView(table: table, theme: .light)
        host.update(
            table: table,
            theme: .light,
            frame: NSRect(x: 0, y: 0, width: 320, height: 26)
        )

        let textPoint = NSPoint(x: 6, y: host.bounds.midY)
        let hotspotPoint = NSPoint(x: host.bounds.maxX - 6, y: host.bounds.midY)

        #expect(host.hitTest(textPoint) == nil)
        #expect(host.hitTest(hotspotPoint) === host)
    }

    @Test("typing triple backticks expands into a fenced code block")
    func typingTripleBackticksExpandsIntoFence() throws {
        let edit = try #require(
            MarkdownEditorCommands.autoExpandCodeFence(
                in: "  ``",
                selection: NSRange(location: 4, length: 0),
                replacementString: "`"
            )
        )

        #expect(edit.replacementRange == NSRange(location: 2, length: 2))
        #expect(edit.replacementText == "```\n  \n  ```")
        #expect(edit.selectedRange == NSRange(location: 8, length: 0))
    }

    @Test("ascii ripple preserves spaces while scrambling the active wave front")
    func asciiRipplePreservesSpaces() {
        let configuration = ASCIIRippleConfiguration(
            duration: 1,
            characters: Array("~!"),
            preserveSpaces: true,
            spread: 1
        )
        let output = ASCIIRippleEngine.displayText(
            original: "A B",
            now: 0.2,
            waves: [ASCIIRippleWave(startIndex: 0, startTime: 0)],
            configuration: configuration
        )

        let characters = Array(output)
        #expect(characters.count == 3)
        #expect(characters[1] == " ")
    }

    @Test("ascii ripple maps hover x positions into stable character indices")
    func asciiRippleMapsHoverPositions() {
        #expect(ASCIIRippleEngine.characterIndex(forX: 0, width: 120, textLength: 6) == 0)
        #expect(ASCIIRippleEngine.characterIndex(forX: 60, width: 120, textLength: 6) == 3)
        #expect(ASCIIRippleEngine.characterIndex(forX: 120, width: 120, textLength: 6) == 5)
    }

    @Test("ascii frame animation cycles preview frames deterministically")
    func asciiFrameAnimationCyclesDeterministically() {
        let configuration = ASCIIFrameAnimationConfiguration(
            frames: ["[>]", "[>>]", "[>>>]"],
            frameDuration: 0.1
        )

        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0,
                startTime: 0,
                configuration: configuration
            ) == "[>]"
        )
        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0.12,
                startTime: 0,
                configuration: configuration
            ) == "[>>]"
        )
        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0.24,
                startTime: 0,
                configuration: configuration
            ) == "[>>>]"
        )
        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0.34,
                startTime: 0,
                configuration: configuration
            ) == "[>]"
        )
    }

    @Test("markdown ripple style scopes headings and body separately")
    func markdownRippleStyleScopesHeadingsAndBodySeparately() {
        #expect(MarkdownRippleStyle.heading1.ripplesHeading(level: 1))
        #expect(!MarkdownRippleStyle.heading1.ripplesHeading(level: 2))
        #expect(!MarkdownRippleStyle.heading1.includesBodyBlocks)
        #expect(MarkdownRippleStyle.headings123.ripplesHeading(level: 3))
        #expect(!MarkdownRippleStyle.headings123.ripplesHeading(level: 4))
        #expect(MarkdownRippleStyle.heading1AndBody.includesBodyBlocks)
        #expect(MarkdownRippleStyle.headings123AndBody.includesBodyBlocks)
    }

    @Test("markdown ripple text extractor preserves visible inline markdown text")
    func markdownRippleTextExtractorPreservesVisibleInlineMarkdownText() {
        let visible = MarkdownRippleTextExtractor.displayText(
            from: "**Bold** and [Link](https://example.com) with `Code`"
        )

        #expect(visible == "Bold and Link with Code")
    }

    @Test("synced note title extracts the first real H1 and ignores fenced code")
    func syncedNoteTitleExtractsFirstRealH1() {
        let title = ProseEditorView.syncedNoteTitle(
            from: """
            ```
            # Not The Title
            ```

            ## Section
            # Actual Title ###

            # Later Title
            """
        )

        #expect(title == "Actual Title")
    }

    @MainActor
    @Test("syncing note title from H1 updates page metadata and requests a rename")
    func syncingNoteTitleFromH1UpdatesPageMetadataAndRequestsRename() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = SDPage(title: "Old Title")
        context.insert(page)
        try context.save()

        var renameRequest: (pageId: String, title: String)?
        let changed = ProseEditorView.syncNoteTitleIfNeeded(
            from: "# New Title\n\nBody",
            for: page,
            modelContext: context
        ) { pageId, newTitle in
            renameRequest = (pageId, newTitle)
        }

        #expect(changed)
        #expect(page.title == "New Title")
        #expect(page.needsVaultSync)
        #expect(renameRequest?.pageId == page.id)
        #expect(renameRequest?.title == "New Title")
    }

    @MainActor
    @Test("syncing note title ignores bodies without an H1")
    func syncingNoteTitleIgnoresBodiesWithoutH1() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = SDPage(title: "Keep Title")
        context.insert(page)
        try context.save()

        var renameCount = 0
        let changed = ProseEditorView.syncNoteTitleIfNeeded(
            from: "Body only\n\n## Section",
            for: page,
            modelContext: context
        ) { _, _ in
            renameCount += 1
        }

        #expect(!changed)
        #expect(page.title == "Keep Title")
        #expect(renameCount == 0)
    }

    @MainActor
    @Test("graph overlay hosted views resolve required app environment")
    func graphOverlayHostedViewsResolveRequiredAppEnvironment() {
        let existingBootstrap = AppBootstrap.shared
        let bootstrap = existingBootstrap ?? AppBootstrap()
        let host = NSHostingView(
            rootView: HologramOverlayHostedViewBuilder.root(
                GraphOverlayEnvironmentProbe(),
                bootstrap: bootstrap
            )
        )
        defer { retainHostingFixture(host) }

        host.frame = NSRect(x: 0, y: 0, width: 240, height: 120)
        host.layoutSubtreeIfNeeded()

        if let existingBootstrap {
            #expect(bootstrap === existingBootstrap)
        }
        #expect(host.fittingSize.width >= 0)
    }
}

private struct GraphOverlayEnvironmentProbe: View {
    @Environment(UIState.self) private var ui
    @Environment(GraphState.self) private var graphState
    @Environment(QueryEngine.self) private var queryEngine

    var body: some View {
        Text(verbatim: "\(ui.theme.displayName) \(graphState.store.nodes.count) \(queryEngine.isProcessing)")
    }
}
