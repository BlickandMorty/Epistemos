import AppKit
import SwiftUI
import Testing

@testable import Epistemos

@Suite("NoteWindowManager")
struct NoteWindowManagerTests {
    @MainActor
    private func withPreservedThemeDefaults(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let keys = [ThemeMode.defaultsKey, UIState.themePairDefaultsKey]
        let previousValues = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in previousValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        body()
    }

    @MainActor
    private final class WindowFixtureRetainer {
        static let shared = WindowFixtureRetainer()

        private var windows: [NSWindow] = []

        func retain(_ window: NSWindow) {
            window.orderOut(nil)
            windows.append(window)
        }
    }

    @MainActor
    private func retainWindowFixture(_ window: NSWindow) {
        WindowFixtureRetainer.shared.retain(window)
    }

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

    @Test("preview mode disables the animated overlay badge to avoid per-frame invalidation")
    func previewModeDisablesAnimatedOverlayBadge() {
        #expect(NotePreviewPerformancePolicy.showsOverlayBadge == false)
    }

    @MainActor
    @Test("Navigation state can retarget a missing current note to a recovered page ID")
    func navigationStateRetargetsMissingCurrentPage() {
        let state = NoteNavigationState(rootPageId: "root", rootTitle: "Root")
        state.push(pageId: "missing", title: "Recovered Title")

        let changed = state.retargetCurrentPage(
            missingPageId: "missing",
            replacementPageId: "recovered",
            replacementTitle: "Recovered Title"
        )

        #expect(changed)
        #expect(state.currentPageId == "recovered")
        #expect(state.stack.map(\.id) == ["root", "recovered"])
        #expect(state.stack.last?.title == "Recovered Title")
    }

    @MainActor
    @Test("Navigation state discards a missing current note without preserving broken forward history")
    func navigationStateDiscardsMissingCurrentPage() {
        let state = NoteNavigationState(rootPageId: "root", rootTitle: "Root")
        state.push(pageId: "missing", title: "Missing")

        let changed = state.discardCurrentPageIfMissing("missing")

        #expect(changed)
        #expect(state.currentPageId == "root")
        #expect(state.stack.map(\.id) == ["root"])
        #expect(!state.canGoForward)
    }

    @MainActor
    @Test("Vault rebuild reset clears stale note navigation state")
    func vaultRebuildResetClearsNavigationState() {
        let manager = NoteWindowManager.shared
        manager.resetForVaultRebuild()

        let state = NoteNavigationState(rootPageId: "root", rootTitle: "Root")
        state.push(pageId: "missing", title: "Missing")
        manager.registerNavState(state, forTab: "root")

        #expect(manager.currentPageId(forTab: "root") == "missing")

        manager.resetForVaultRebuild()

        #expect(manager.currentPageId(forTab: "root") == "root")
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
        defer { retainWindowFixture(window) }
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.collectionBehavior.insert(.fullScreenAllowsTiling)

        WindowPresentationPolicy.applyModularZoomBehavior(to: window)

        #expect(!window.collectionBehavior.contains(.fullScreenPrimary))
        #expect(!window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(!window.collectionBehavior.contains(.fullScreenAllowsTiling))
        #expect(window.contentMinSize == WindowPresentationPolicy.mainWindowMinimumSize)
        let zoomButton = try #require(window.standardWindowButton(.zoomButton))
        #expect(zoomButton.target === window)
        #expect(zoomButton.action == #selector(NSWindow.performZoom(_:)))
    }

    @MainActor
    @Test("App delegate leaves the SwiftUI home window untouched when it becomes active")
    func appDelegateLeavesHomeWindowUntouchedWhenActive() async throws {
        let delegate = EpistemosAppDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        defer { retainWindowFixture(window) }
        window.title = "Epistemos"
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.collectionBehavior.insert(.fullScreenAllowsTiling)
        let originalMinimumSize = window.contentMinSize
        let zoomButton = try #require(window.standardWindowButton(.zoomButton))
        zoomButton.target = nil
        zoomButton.action = nil

        NotificationCenter.default.post(name: NSWindow.didBecomeMainNotification, object: window)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(window.collectionBehavior.contains(.fullScreenPrimary))
        #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(window.collectionBehavior.contains(.fullScreenAllowsTiling))
        #expect(window.contentMinSize == originalMinimumSize)
        #expect(zoomButton.target == nil)
        #expect(zoomButton.action == nil)

        delegate.applicationWillTerminate(
            Notification(name: NSApplication.willTerminateNotification))
    }

    @MainActor
    @Test("status bar setup stays disabled under test hosts")
    func statusBarSetupStaysDisabledUnderTests() {
        StatusBar.shared.remove()
        StatusBar.shared.setup()

        #expect(StatusBar.shared.hasInstalledStatusItemForTesting == false)
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
        defer { retainWindowFixture(window) }

        NoteWindowChrome.apply(to: window, toolbarIdentifier: "TestNoteToolbar")

        #expect(window.titleVisibility == .hidden)
        #expect(window.titlebarAppearsTransparent)
        #expect(window.isMovableByWindowBackground)
        #expect(window.styleMask.contains(.fullSizeContentView))
        let toolbar = try #require(window.toolbar)
        #expect(toolbar.identifier == "TestNoteToolbar")
        if #unavailable(macOS 15.0) {
            #expect(!toolbar.showsBaselineSeparator)
        }
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
        defer { retainWindowFixture(panel) }

        UtilityPanelChrome.applySidebarChrome(to: panel)

        #expect(panel.styleMask.contains(.fullSizeContentView))
        #expect(panel.titleVisibility == .hidden)
        #expect(panel.titlebarAppearsTransparent)
        let toolbar = try #require(panel.toolbar)
        #expect(toolbar.identifier == "NotesSidebarToolbar")
        #expect(panel.toolbarStyle == .unifiedCompact)
    }

    @Test("Utility panels include notes, omega, and a detached settings window")
    func utilityPanelsIncludeDetachedSettingsWindow() {
        #expect(UtilityPanel.allCases == [.notes, .omega, .settings])
        #expect(UtilityPanel.notes.title == "Notes")
        #expect(UtilityPanel.settings.title == "Settings")
        #expect(UtilityPanel.settings.icon == "gearshape")
        #expect(UtilityPanel.settings.defaultSize.width >= 900)
        #expect(UtilityPanel.settings.defaultSize.height >= 680)
    }

    @MainActor
    @Test("Settings utility window uses split-view chrome with a transparent titlebar")
    func settingsUtilityWindowUsesSplitViewChrome() throws {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        defer { retainWindowFixture(panel) }

        UtilityPanelChrome.apply(to: panel, kind: .settings)

        #expect(panel.styleMask.contains(.fullSizeContentView))
        #expect(panel.titleVisibility == .hidden)
        #expect(panel.titlebarAppearsTransparent)
        #expect(panel.isMovableByWindowBackground)
        let toolbar = try #require(panel.toolbar)
        #expect(toolbar.identifier == "SettingsToolbar")
        #expect(panel.toolbarStyle == .unified)
    }

    @MainActor
    @Test("Note window theme refresh keeps native chrome when custom themes are disabled")
    func noteWindowThemeRefreshKeepsNativeChromeWhenThemesDisabled() throws {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1110, height: 740),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            defer { retainWindowFixture(window) }
            let uiState = UIState()

            NoteWindowChrome.apply(to: window, toolbarIdentifier: "TestNoteToolbar")
            NoteWindowThemeStyler.apply(to: window, uiState: uiState)

            #expect(window.appearance?.name != .darkAqua)
            #expect(window.titlebarAppearsTransparent)
            #expect(window.toolbarStyle == .unified)
            #expect(
                !window.titlebarAccessoryViewControllers.contains(where: {
                    $0.identifier?.rawValue == "GlassToolbar"
                })
            )
        }
    }

    @MainActor
    @Test("Legacy theme calls no longer force custom chrome into note windows")
    func noteWindowThemeRefreshIgnoresLegacyCustomThemeCalls() throws {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1110, height: 740),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            defer { retainWindowFixture(window) }
            let uiState = UIState()

            uiState.setPair(.platinum)
            uiState.setThemeMode(.custom)
            uiState.isSystemDark = true

            NoteWindowChrome.apply(to: window, toolbarIdentifier: "TestNoteToolbar")
            NoteWindowThemeStyler.apply(to: window, uiState: uiState)

            #expect(window.appearance == nil)
            #expect(window.titlebarAppearsTransparent)
            #expect(window.toolbarStyle == .unified)
            #expect(
                !window.titlebarAccessoryViewControllers.contains(where: {
                    $0.identifier?.rawValue == "GlassToolbar"
                })
            )
        }
    }

    @MainActor
    @Test("Note window theme refresh stays native across legacy theme toggles")
    func noteWindowThemeRefreshStaysNativeAcrossLegacyThemeToggles() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1110, height: 740),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            defer { retainWindowFixture(window) }
            let uiState = UIState()

            NoteWindowChrome.apply(to: window, toolbarIdentifier: "TestNoteToolbar")

            uiState.setPair(.platinum)
            uiState.setThemeMode(.custom)
            uiState.isSystemDark = true
            NoteWindowThemeStyler.apply(to: window, uiState: uiState)
            #expect(
                !window.titlebarAccessoryViewControllers.contains(where: {
                    $0.identifier?.rawValue == "GlassToolbar"
                })
            )

            uiState.setCustomThemesEnabled(false)
            NoteWindowThemeStyler.apply(to: window, uiState: uiState)

            #expect(window.appearance == nil)
            #expect(
                !window.titlebarAccessoryViewControllers.contains(where: {
                    $0.identifier?.rawValue == "GlassToolbar"
                })
            )
        }
    }

    @MainActor
    @Test("Note window theme refresh keeps the live content root free of utility backdrops")
    func noteWindowThemeRefreshKeepsLiveContentRootClear() throws {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1110, height: 740),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            defer { retainWindowFixture(window) }
            let uiState = UIState()

            NoteWindowChrome.apply(to: window, toolbarIdentifier: "TestNoteToolbar")
            WindowThemeStyler.applyBackdrop(in: window.contentView, uiState: uiState)
            let hadBackdrop = window.contentView?.subviews.contains(where: { $0 is NSVisualEffectView }) ?? false
            #expect(!hadBackdrop)

            NoteWindowThemeStyler.apply(to: window, uiState: uiState)
            let hasBackdropAfterCleanup =
                window.contentView?.subviews.contains(where: { $0 is NSVisualEffectView }) ?? false

            #expect(!hasBackdropAfterCleanup)
        }
    }

    @MainActor
    @Test("Note windows keep the hosted content in a plain native wrapper")
    func noteWindowNativeContentControllerKeepsPlainWrapper() throws {
        let uiState = UIState()
        let hosted = NSHostingController(rootView: Color.clear.frame(width: 120, height: 80))

        let controller = try #require(
            NoteWindowThemeStyler.themedContentController(
                hostingController: hosted,
                uiState: uiState
            ) as? NoteWindowBackdropController
        )

        #expect(controller.view.subviews.contains(hosted.view))
        #expect(!controller.view.subviews.contains(where: { $0 is NSVisualEffectView }))
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
        #expect(NoteToolbarMetrics.chatFieldWidth == 220)
        #expect(NoteToolbarMetrics.stripGlowBlurRadius == 6)
        #expect(NoteToolbarDisplay.hidesMenuIndicators)
        #expect(NoteToolbarPalette.stripGlowOpacity(for: .platinum) == 0)
        #expect(NoteToolbarPalette.stripGlowOpacity(for: .platinumDark) == 0)
    }

    @Test("Preview mode stays on the TK2 stack and leaves markdown unchanged")
    func previewModeUsesMatchingStack() {
        #expect(NotePreviewDisplay.renderedMarkdown("## Sub Heading\n### Third Level\nBody") == "## Sub Heading\n### Third Level\nBody")
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

    @Test("Landing shortcuts keep sentence case and use the native UI font")
    func landingShortcutsUseSentenceCaseAndUIFont() {
        #expect(LandingShortcutDisplay.label("New Note") == "New Note")
        #expect(LandingShortcutDisplay.label("Click to search") == "Click to search")
        #expect(LandingShortcutDisplay.fontSize == 12)
        #expect(LandingShortcutDisplay.keyHorizontalPadding == 7)
        #expect(LandingShortcutDisplay.keyVerticalPadding == 4)
        #expect(LandingShortcutDisplay.keyCornerRadius == 7)
        #expect(LandingShortcutDisplay.shortcutRowSpacing == 12)
        #expect(LandingShortcutDisplay.keyMinWidth(for: "N") == nil)
        #expect(LandingShortcutDisplay.keyMinWidth(for: "Space") == 48)
        #expect(AppDisplayTypography.isRegularUIFont(LandingShortcutDisplay.nsFont()))
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

    @Test("Graph overlay controls stay global-only and hide noisy graph filter pills")
    func graphOverlayControlsStayGlobalOnly() {
        #expect(!GraphOverlayModePolicy.pageModeEnabled)
        #expect(!GraphOverlayControlsDisplay.showsPageModeToggle)
        #expect(!GraphOverlayControlsDisplay.filterTypes.contains(.tag))
        #expect(!GraphOverlayControlsDisplay.filterTypes.contains(.source))
        #expect(!GraphOverlayControlsDisplay.filterTypes.contains(.quote))
        #expect(GraphOverlayControlsDisplay.filterTypes.contains(.proseNote))
        #expect(GraphOverlayControlsDisplay.filterTypes.contains(.document))
        #expect(GraphOverlayControlsDisplay.filterTypes.contains(.code))
        #expect(GraphOverlayControlsDisplay.filterTypes.contains(.output))
        #expect(
            GraphOverlayControlsDisplay.filterTypes == [
                .note, .chat, .idea, .folder,
                .person, .project, .topic, .decision, .event, .resource,
                .run, .rawThought, .toolTrace, .proseNote, .document, .code, .output,
            ]
        )
    }

    @Test("Graph mini panel opens as a centered square with a slight right bias")
    func graphMiniPanelUsesCenteredSquareFrame() {
        let visible = NSRect(x: 80, y: 40, width: 1440, height: 900)
        let frame = GraphMiniPanelLayout.frame(in: visible)

        #expect(frame.width == frame.height)
        #expect(frame.width == GraphMiniPanelLayout.defaultSide)
        #expect(frame.midY == visible.midY)
        // Mini panel is pinned to the right edge of the screen.
        #expect(frame.maxX == visible.maxX - GraphMiniPanelLayout.screenPadding)
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

@Suite("Notes Sidebar Visible Tree")
struct NotesSidebarVisibleTreeBuilderTests {

    @Test("Visible tree emits expanded descendants in render order")
    func visibleTreeExpandedOrder() {
        let rows = NotesSidebarVisibleTreeBuilder.build(
            rootFolderIds: ["root"],
            expandedFolderIds: ["root", "child"],
            childFolderIdsById: [
                "root": ["child"],
                "child": [],
            ],
            pageIdsByFolderId: [
                "root": ["page-root"],
                "child": ["page-child-a", "page-child-b"],
            ]
        )

        #expect(rows == [
            .folder(id: "root", indent: 0),
            .folder(id: "child", indent: 1),
            .page(id: "page-child-a", indent: 2),
            .page(id: "page-child-b", indent: 2),
            .page(id: "page-root", indent: 1),
        ])
    }

    @Test("Visible tree keeps collapsed descendants virtualized")
    func visibleTreeCollapsedOrder() {
        let rows = NotesSidebarVisibleTreeBuilder.build(
            rootFolderIds: ["root"],
            expandedFolderIds: [],
            childFolderIdsById: [
                "root": ["child"],
                "child": [],
            ],
            pageIdsByFolderId: [
                "root": ["page-root"],
                "child": ["page-child"],
            ]
        )

        #expect(rows == [
            .folder(id: "root", indent: 0),
        ])
    }

    @Test("Visible tree emits empty-folder placeholder only for expanded leaf folders")
    func visibleTreeEmptyFolderPlaceholder() {
        let rows = NotesSidebarVisibleTreeBuilder.build(
            rootFolderIds: ["leaf"],
            expandedFolderIds: ["leaf"],
            childFolderIdsById: [
                "leaf": [],
            ],
            pageIdsByFolderId: [
                "leaf": [],
            ]
        )

        #expect(rows == [
            .folder(id: "leaf", indent: 0),
            .emptyFolder(id: "leaf", indent: 1),
        ])
    }
}

@Suite("Notes Sidebar Hover Haptics")
struct NotesSidebarHoverHapticsTests {

    @Test("Hover tick state only fires when the pointer enters a row")
    func hoverTickStateOnlyTicksOnEntry() async {
        var state = NotesSidebarHoverTickState()

        let firstEnter = state.update(hovering: true)
        let repeatedHover = state.update(hovering: true)
        let hoverExit = state.update(hovering: false)
        try? await Task.sleep(for: .milliseconds(90))
        let secondEnter = state.update(hovering: true)

        #expect(firstEnter)
        #expect(!repeatedHover)
        #expect(!hoverExit)
        #expect(secondEnter)
    }

    @Test("File and folder hover recipes stay distinct")
    func hoverRecipesStayDistinct() {
        #expect(NotesSidebarHoverHapticStyle.file.recipe.pattern == .generic)
        #expect(NotesSidebarHoverHapticStyle.folder.recipe.pattern == .levelChange)
    }
}

@Suite("Notes Sidebar Folder Metrics")
struct NotesSidebarFolderMetricsTests {

    @Test("Descendant page counts include nested folder pages once")
    func descendantPageCountsIncludeNestedPages() {
        let counts = NotesSidebarFolderMetrics.descendantPageCounts(
            folderIds: ["root", "child", "grandchild"],
            childFolderIdsById: [
                "root": ["child"],
                "child": ["grandchild"],
                "grandchild": [],
            ],
            pageIdsByFolderId: [
                "root": ["page-root"],
                "child": ["page-child-a", "page-child-b"],
                "grandchild": ["page-grandchild"],
            ]
        )

        #expect(counts["root"] == 4)
        #expect(counts["child"] == 3)
        #expect(counts["grandchild"] == 1)
    }

    @Test("Descendant page counts return zero for empty folders")
    func descendantPageCountsHandleEmptyFolders() {
        let counts = NotesSidebarFolderMetrics.descendantPageCounts(
            folderIds: ["empty", "parent"],
            childFolderIdsById: [
                "empty": [],
                "parent": ["empty"],
            ],
            pageIdsByFolderId: [:]
        )

        #expect(counts["empty"] == 0)
        #expect(counts["parent"] == 0)
    }
}
