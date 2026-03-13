import AppKit
import Testing

@testable import Epistemos

@Suite("NoteWindowManager")
struct NoteWindowManagerTests {

    @Test("Undersized autosaved note frames reset to the sane default")
    func undersizedFrameResetsToDefault() {
        let visible = NSRect(x: 0, y: 0, width: 1800, height: 1130)
        let tiny = NSRect(x: 12, y: 18, width: 320, height: 240)

        let frame = NoteWindowManager.sanitizedNoteWindowFrame(
            proposedFrame: tiny,
            visibleFrame: visible
        )

        #expect(frame.width == NoteWindowManager.noteDefaultFrameSize.width)
        #expect(frame.height == NoteWindowManager.noteDefaultFrameSize.height)
        #expect(frame.midX == visible.midX)
        #expect(frame.midY == visible.midY)
    }

    @Test("Healthy autosaved note frames are preserved")
    func healthyFrameIsPreserved() {
        let visible = NSRect(x: 0, y: 0, width: 1800, height: 1130)
        let saved = NSRect(x: 180, y: 140, width: 1040, height: 720)

        let frame = NoteWindowManager.sanitizedNoteWindowFrame(
            proposedFrame: saved,
            visibleFrame: visible
        )

        #expect(frame == saved)
    }

    @Test("Off-screen note frames are clamped back into the visible screen")
    func offscreenFrameIsClamped() {
        let visible = NSRect(x: 100, y: 50, width: 1200, height: 800)
        let saved = NSRect(x: -300, y: 900, width: 980, height: 680)

        let frame = NoteWindowManager.sanitizedNoteWindowFrame(
            proposedFrame: saved,
            visibleFrame: visible
        )

        #expect(frame.minX >= visible.minX)
        #expect(frame.maxX <= visible.maxX)
        #expect(frame.minY >= visible.minY)
        #expect(frame.maxY <= visible.maxY)
    }

    @Test("Note titles resolve an untitled fallback for native window labels")
    func noteTitleResolvesUntitledFallback() {
        #expect(NoteTitleDisplay.resolvedTitle("Research Plan") == "Research Plan")
        #expect(NoteTitleDisplay.resolvedTitle("   ") == "Untitled")
    }

    @MainActor
    @Test("Modular window policy keeps zoom and disables desktop fullscreen")
    func modularWindowPolicyDisablesDesktopFullscreen() throws {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.collectionBehavior.insert(.fullScreenAllowsTiling)

        WindowPresentationPolicy.applyModularZoomBehavior(to: window)

        #expect(!window.collectionBehavior.contains(.fullScreenPrimary))
        #expect(!window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(!window.collectionBehavior.contains(.fullScreenAllowsTiling))
        let zoomButton = try #require(window.standardWindowButton(.zoomButton))
        #expect(zoomButton.target === window)
        #expect(zoomButton.action == #selector(NSWindow.performZoom(_:)))
    }

    @MainActor
    @Test("Main window observer reapplies modular zoom policy on window attachment")
    func modularZoomObserverAppliesPolicyWhenAttachedToWindow() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenAllowsTiling)

        let root = NSView(frame: window.frame)
        let observer = ModularZoomWindowObserverView(frame: .zero)
        window.contentView = root
        root.addSubview(observer)
        observer.viewDidMoveToWindow()

        #expect(!window.collectionBehavior.contains(.fullScreenPrimary))
        #expect(!window.collectionBehavior.contains(.fullScreenAllowsTiling))
        let zoomButton = try #require(window.standardWindowButton(.zoomButton))
        #expect(zoomButton.target === window)
        #expect(zoomButton.action == #selector(NSWindow.performZoom(_:)))
    }

    @MainActor
    @Test("App delegate reapplies modular zoom policy when the main window becomes active")
    func appDelegateReappliesMainWindowZoomPolicy() throws {
        let delegate = EpistemosAppDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Epistemos"
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.collectionBehavior.insert(.fullScreenAllowsTiling)

        NotificationCenter.default.post(name: NSWindow.didBecomeMainNotification, object: window)

        #expect(!window.collectionBehavior.contains(.fullScreenPrimary))
        #expect(!window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(!window.collectionBehavior.contains(.fullScreenAllowsTiling))
        let zoomButton = try #require(window.standardWindowButton(.zoomButton))
        #expect(zoomButton.target === window)
        #expect(zoomButton.action == #selector(NSWindow.performZoom(_:)))

        delegate.applicationWillTerminate(
            Notification(name: NSApplication.willTerminateNotification))
    }

    @MainActor
    @Test("Note editor windows hide the native title and use unified toolbar chrome")
    func noteEditorWindowUsesCustomChrome() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1110, height: 740),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        NoteWindowChrome.apply(to: window, toolbarIdentifier: "TestNoteToolbar")

        #expect(window.titleVisibility == .hidden)
        #expect(window.titlebarAppearsTransparent)
        #expect(window.isMovableByWindowBackground)
        let toolbar = try #require(window.toolbar)
        #expect(toolbar.identifier == "TestNoteToolbar")
        #expect(window.toolbarStyle == .unified)
    }

    @MainActor
    @Test("Notes utility window uses full-size compact chrome for the custom sidebar header")
    func notesUtilityWindowUsesCustomChrome() throws {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        UtilityPanelChrome.applySidebarChrome(to: panel)

        #expect(panel.styleMask.contains(.fullSizeContentView))
        #expect(panel.titleVisibility == .hidden)
        #expect(panel.titlebarAppearsTransparent)
        let toolbar = try #require(panel.toolbar)
        #expect(toolbar.identifier == "NotesSidebarToolbar")
        #expect(panel.toolbarStyle == .unifiedCompact)
    }

    @MainActor
    @Test("Note window theme refresh reapplies appearance and unified toolbar chrome")
    func noteWindowThemeRefreshReappliesChrome() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1110, height: 740),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        NoteWindowChrome.apply(to: window, toolbarIdentifier: "TestNoteToolbar")
        NoteWindowThemeStyler.apply(to: window, theme: .platinumDark)

        #expect(window.appearance?.name == .darkAqua)
        #expect(window.titlebarAppearsTransparent)
        #expect(window.toolbarStyle == .unified)
    }

    @Test("Note toolbar uses native symbol mappings inside the unified strip")
    func noteToolbarUsesNativeSymbolMappings() {
        #expect(NoteToolbarGlyph.format.symbolName == "textformat")
        #expect(NoteToolbarGlyph.preview.symbolName == "eye")
        #expect(NoteToolbarGlyph.edit.symbolName == "pencil")
        #expect(NoteToolbarGlyph.more.symbolName == "ellipsis.circle")
        #expect(NoteToolbarGlyph.writingTools.symbolName == "apple.intelligence")
        #expect(NoteToolbarGlyph.backlinks.symbolName == "link")
        #expect(NoteToolbarGlyph.history.symbolName == "bubble.left")
        #expect(NoteToolbarMetrics.iconSide == 14)
        #expect(NoteToolbarMetrics.buttonSide == 28)
        #expect(NoteToolbarMetrics.buttonSide == NoteToolbarMetrics.iconSide * 2)
        #expect(NoteToolbarMetrics.chatFieldWidth == 180)
        #expect(NoteToolbarMetrics.stripGlowBlurRadius == 6)
        #expect(NoteToolbarPalette.stripGlowOpacity(for: .platinum) == 0.012)
    }

    @Test("Preview mode follows the active editor stack and preserves uppercase heading display")
    func previewModeUsesMatchingStack() {
        #expect(NotePreviewRenderer.resolved(useTK2Editor: false) == .textKit1)
        #expect(NotePreviewRenderer.resolved(useTK2Editor: true) == .textKit2)
        #expect(
            NotePreviewDisplay.renderedMarkdown(
                "## Sub Heading\n### Third Level\nBody",
                renderer: .textKit1
            ) == "## SUB HEADING\n### THIRD LEVEL\nBody"
        )
        #expect(
            NotePreviewDisplay.renderedMarkdown(
                "## Sub Heading\n### Third Level\nBody",
                renderer: .textKit2
            ) == "## Sub Heading\n### Third Level\nBody"
        )
    }

    @Test("Table-heavy notes keep a wider single-page preview and compact editor column")
    func tableHeavyNotesUseWiderPreviewWidth() {
        let tableMarkdown = """
            # Inventory

            | Name | Count |
            | --- | --- |
            | Pens | 12 |
            """
        let proseMarkdown = """
            # Inventory

            Pens, paper, and folders.
            """

        #expect(
            NoteDualPreviewLayout.singlePageMaxWidth(for: tableMarkdown)
                == NoteDualPreviewLayout.tableSinglePageMaxWidth
        )
        #expect(
            NoteDualPreviewLayout.singlePageMaxWidth(for: proseMarkdown)
                == NoteDualPreviewLayout.defaultSinglePageMaxWidth
        )
        #expect(NoteDualPreviewLayout.defaultSinglePageMaxWidth >= 880)
        #expect(NoteDualPreviewLayout.tableSinglePageMaxWidth >= 800)
        #expect(
            NoteDualPreviewLayout.tableSinglePageMaxWidth < NoteDualPreviewLayout.defaultSinglePageMaxWidth
        )
        #expect(
            NoteDualPreviewLayout.singlePageWidth(for: tableMarkdown, availableWidth: 1600)
                == NoteDualPreviewLayout.tableSinglePageMaxWidth
        )
        #expect(
            NoteDualPreviewLayout.readableWidth(for: tableMarkdown, defaultWidth: 800)
                == NoteDualPreviewLayout.tableReadableMaxWidth
        )
        #expect(NoteDualPreviewLayout.readableWidth(for: proseMarkdown, defaultWidth: 800) == 800)
    }

    @Test("Dual preview pages keep a stable readable width instead of collapsing skinny")
    func dualPreviewPagesUseStableReadableWidth() {
        #expect(NoteDualPreviewLayout.dualPageWidth(for: 1180) >= 520)
        #expect(NoteDualPreviewLayout.dualPageWidth(for: 1320) > NoteDualPreviewLayout.dualPageWidth(for: 1180))
        #expect(
            NoteDualPreviewLayout.dualPageWidth(for: 1800) == NoteDualPreviewLayout.pageMaxWidth
        )
    }

    @Test("TK2 wide preview switches into the dual-column paragraph layout")
    func tk2WidePreviewUsesDualColumnLayout() {
        #expect(!NoteDualPreviewLayout.usesDualColumns(for: 1179))
        #expect(NoteDualPreviewLayout.usesDualColumns(for: 1180))

        let blocks = NoteDualPreviewLayout.paragraphBlocks(
            in: """
            # Title

            First paragraph
            still first

            ```swift
            let x = 1

            let y = 2
            ```

            Last paragraph
            """
        )

        #expect(blocks.count == 4)
        #expect(blocks[0] == "# Title")
        #expect(blocks[1] == "First paragraph\nstill first")
        #expect(blocks[2].contains("```swift"))
        #expect(blocks[3] == "Last paragraph")
    }

    @Test("Book preview groups short prose blocks into fuller reading sections")
    func bookPreviewGroupsShortProseBlocks() {
        let sections = NoteDualPreviewLayout.bookSections(
            in: """
            # Title

            First paragraph.

            Second paragraph.

            - Bullet one
            - Bullet two

            ```swift
            let x = 1
            ```

            Closing paragraph.
            """,
            targetCharacterCount: 80
        )

        #expect(sections.count == 3)
        #expect(sections[0].contains("# Title"))
        #expect(sections[0].contains("Second paragraph."))
        #expect(sections[1].contains("```swift"))
        #expect(sections[2] == "Closing paragraph.")
    }

    @Test("Book preview keeps dual pages contiguous and balanced")
    func bookPreviewSplitsIntoContiguousPages() {
        let pages = NoteDualPreviewLayout.columnContents(
            in: """
            # Intro

            Alpha

            Beta

            Gamma

            Delta
            """,
            targetCharacterCount: 12
        )

        #expect(pages.count == 2)
        #expect(pages[0].contains("# Intro"))
        #expect(pages[0].contains("Alpha"))
        #expect(!pages[0].contains("Delta"))
        #expect(!pages[1].contains("# Intro"))
        #expect(pages[1].contains("Beta"))
        #expect(pages[1].contains("Gamma"))
        #expect(pages[1].contains("Delta"))
    }

    @Test("Landing shortcuts render uppercase at the stronger display size")
    func landingShortcutsUseUppercaseDisplayLabels() {
        #expect(LandingShortcutDisplay.label("New Note") == "NEW NOTE")
        #expect(LandingShortcutDisplay.label("Click to search") == "CLICK TO SEARCH")
        #expect(LandingShortcutDisplay.fontSize == 12)
        #expect(LandingShortcutDisplay.keyHorizontalPadding == 7)
        #expect(LandingShortcutDisplay.keyVerticalPadding == 4)
        #expect(LandingShortcutDisplay.keyCornerRadius == 7)
        #expect(LandingShortcutDisplay.shortcutRowSpacing == 12)
        #expect(LandingShortcutDisplay.keyMinWidth(for: "N") == nil)
        #expect(LandingShortcutDisplay.keyMinWidth(for: "Space") == 48)
    }

    @Test("Notes sidebar keeps compact header spacing and restores the vault changes control")
    func notesSidebarKeepsCompactHeaderSpacing() {
        #expect(NotesSidebarMetrics.headerTopPadding == 14)
        #expect(NotesSidebarMetrics.headerBottomPadding == 2)
        #expect(NotesSidebarMetrics.searchBarTopPadding == 0)
        #expect(!NotesSidebarMetrics.overlapsTitlebar)
        #expect(!NotesSidebarMetrics.showsBottomCollectionButton)
        #expect(!NotesSidebarMetrics.showsBottomMiniChatButton)
        #expect(NotesSidebarMetrics.changesPanelWidth == 320)
        #expect(NotesSidebarMetrics.changesPanelHeight == 400)
        #expect(NotesSidebarGlyph.vaultChanges.symbolName == "doc.badge.clock")
        #expect(NotesSidebarGlyph.vaultChanges.activeSymbolName == "doc.badge.clock.fill")
    }

    @Test("Graph overlay controls stay global-only and hide the tag filter pill")
    func graphOverlayControlsStayGlobalOnly() {
        #expect(!GraphOverlayModePolicy.pageModeEnabled)
        #expect(!GraphOverlayControlsDisplay.showsPageModeToggle)
        #expect(!GraphOverlayControlsDisplay.filterTypes.contains(.tag))
        #expect(
            GraphOverlayControlsDisplay.filterTypes == [.note, .chat, .idea, .source, .folder, .quote]
        )
    }

    @Test("Graph mini panel opens as a centered square with a slight right bias")
    func graphMiniPanelUsesCenteredSquareFrame() {
        let visible = NSRect(x: 80, y: 40, width: 1440, height: 900)
        let frame = GraphMiniPanelLayout.frame(in: visible)

        #expect(frame.width == frame.height)
        #expect(frame.width == GraphMiniPanelLayout.defaultSide)
        #expect(frame.midY == visible.midY)
        #expect(frame.midX == visible.midX + GraphMiniPanelLayout.horizontalBias)
        #expect(frame.maxX <= visible.maxX - GraphMiniPanelLayout.screenPadding)
        #expect(frame.minX >= visible.minX + GraphMiniPanelLayout.screenPadding)
        #expect(frame.minY >= visible.minY + GraphMiniPanelLayout.screenPadding)
    }
}

@Suite("Notes Sidebar Delete Planner")
struct NotesSidebarDeletePlannerTests {

    @Test("Folder tree deletion includes descendants and nested pages")
    func folderTreeDeletionIncludesDescendants() {
        let plan = NotesSidebarDeletePlanner.folderTreeDeletion(
            rootId: "root",
            childFolderIdsById: [
                "root": ["child-a", "child-b"],
                "child-a": ["grandchild"],
                "child-b": [],
                "grandchild": [],
            ],
            pageIdsByFolderId: [
                "root": ["page-root"],
                "child-a": ["page-a"],
                "child-b": ["page-b"],
                "grandchild": ["page-grandchild"],
            ]
        )

        #expect(plan.folderIds == ["root", "child-a", "child-b", "grandchild"])
        #expect(plan.pageIds == ["page-root", "page-a", "page-b", "page-grandchild"])
    }

    @Test("Page deletion plan targets only the requested page")
    func pageDeletionTargetsOnlyTheRequestedPage() {
        let plan = NotesSidebarDeletePlanner.pageDeletion(pageId: "page-1")

        #expect(plan.folderIds.isEmpty)
        #expect(plan.pageIds == ["page-1"])
    }
}
