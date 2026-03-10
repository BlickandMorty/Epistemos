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
}
