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
        #expect(!toolbar.showsBaselineSeparator)
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
        #expect(!toolbar.showsBaselineSeparator)
        #expect(panel.toolbarStyle == .unifiedCompact)
    }
}
