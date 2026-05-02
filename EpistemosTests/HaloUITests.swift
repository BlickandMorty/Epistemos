import AppKit
import Foundation
import SwiftUI
import Testing

@testable import Epistemos

/// Wave 8.5 source-guard for the Halo panel + button views
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 8.5,
///  cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"UI").
///
/// Tests the canonical panel construction (non-activating, never main),
/// the controller's show/hide lifecycle, and that ShadowPanelHandlers'
/// closure surface compiles cleanly. SwiftUI render testing is not
/// in scope — that requires the full app lifecycle + layout.
@MainActor
@Suite("Halo panel + button (Wave 8.5)")
struct HaloUITests {

    // MARK: - ShadowPanel

    @Test("ShadowPanel uses non-activating + never-main style mask")
    func panelStyleMask() {
        let panel = ShadowPanel(content: { Text("hello") })
        let mask = panel.styleMask
        #expect(mask.contains(.nonactivatingPanel),
                "ShadowPanel must include .nonactivatingPanel so clicking it doesn't steal main-window status from the editor (V1 decision §UI)")
        #expect(panel.canBecomeMain == false,
                "ShadowPanel.canBecomeMain MUST be false — the editor behind keeps main-window status")
        #expect(panel.canBecomeKey == true,
                "ShadowPanel.canBecomeKey must be true so inline TextEditors inside receive keyboard input")
    }

    @Test("ShadowPanel uses floating level + appropriate collection behavior")
    func panelFloatingLevel() {
        let panel = ShadowPanel(content: { Text("hello") })
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(panel.becomesKeyOnlyIfNeeded == true)
        #expect(panel.hidesOnDeactivate == false)
    }

    @Test("ShadowPanel has a 360x480 default frame to cap blur cost ≤ 2 ms/frame")
    func panelDefaultFrame() {
        let panel = ShadowPanel(content: { Text("hello") })
        #expect(panel.frame.width == 360,
                "default width MUST be 360 to keep .ultraThinMaterial blur cost under the V1 budget (≤ 2 ms/frame)")
        #expect(panel.frame.height == 480)
    }

    // MARK: - ShadowPanelController lifecycle

    @Test("ShadowPanelController starts hidden")
    func panelControllerStartsHidden() {
        let controller = ShadowPanelController(onOutsideClick: {})
        #expect(controller.isVisible == false)
    }

    @Test("ShadowPanelController.show makes the panel visible; hide reverts")
    func panelControllerShowHide() {
        let controller = ShadowPanelController(onOutsideClick: {})
        controller.show { Text("contents") }
        #expect(controller.isVisible == true)
        controller.hide()
        #expect(controller.isVisible == false)
    }

    @Test("ShadowPanelController.dismiss tears down the panel entirely")
    func panelControllerDismiss() {
        let controller = ShadowPanelController(onOutsideClick: {})
        controller.show { Text("contents") }
        controller.dismiss()
        #expect(controller.isVisible == false)
    }

    // MARK: - ShadowPanelHandlers

    @Test("ShadowPanelHandlers default closures are no-ops (smoke test for compile + safe defaults)")
    func handlersDefaultsCompile() {
        let handlers = ShadowPanelHandlers()
        let sample = ShadowHit(
            id: "x",
            title: "x",
            snippet: "x",
            score: 1.0,
            domain: .notes,
            source: "stub"
        )
        // Each default closure should run without crash.
        handlers.onOpenHit(sample)
        handlers.onBeginEditNote(sample)
        handlers.onCommitEdit("x", "body")
        handlers.onSummarizeChat(sample)
        #expect(Bool(true))
    }

    @Test("ShadowPanelHandlers carry custom closures forward")
    func handlersCustomClosures() {
        var openCount = 0
        var editCount = 0
        var commitCount = 0
        var summariseCount = 0
        let handlers = ShadowPanelHandlers(
            onOpenHit: { _ in openCount += 1 },
            onBeginEditNote: { _ in editCount += 1 },
            onCommitEdit: { _, _ in commitCount += 1 },
            onSummarizeChat: { _ in summariseCount += 1 }
        )
        let sample = ShadowHit(id: "x", title: "x", snippet: "x", score: 1.0, domain: .notes, source: "stub")
        handlers.onOpenHit(sample)
        handlers.onBeginEditNote(sample)
        handlers.onCommitEdit("x", "body")
        handlers.onSummarizeChat(sample)
        #expect(openCount == 1)
        #expect(editCount == 1)
        #expect(commitCount == 1)
        #expect(summariseCount == 1)
    }

    // MARK: - HaloButton

    @Test("HaloButton initializes with the controller passed through")
    func haloButtonInit() {
        let mock = HaloUITestSupport.mockController()
        let button = HaloButton(controller: mock)
        // Body is opaque (some View); we just verify the init compiles
        // + the underlying controller is reachable for rendering.
        #expect(button.controller === mock)
    }

    // MARK: - ShadowPanelController.panelOrigin (T+5 trailing-edge anchor)
    //
    // Pure-function tests for the V1 doctrine canonical positioning
    // logic per `ambient_V1_DECISION.md` section UI ("anchored to the
    // editor's trailing edge"). These test the positioning rules in
    // isolation; the actual NSPanel show/hide is covered by the
    // ShadowPanelController tests above.

    @Test("panelOrigin places panel just right of anchor with horizontal gap")
    func panelOriginPrefersTrailingEdge() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let anchor = NSRect(x: 200, y: 400, width: 600, height: 300)
        let origin = ShadowPanelController.panelOrigin(
            forAnchorRect: anchor,
            panelSize: NSSize(width: 360, height: 480),
            in: screen
        )
        // Trailing-edge x = anchor.maxX + 8 = 808
        #expect(origin.x == 808,
                "panel x must be anchor.maxX + horizontalGap (8) by default - got \(origin.x)")
        // y top-aligned: panel.maxY = anchor.maxY -> y = anchor.maxY - panelHeight = 700 - 480 = 220
        #expect(origin.y == 220,
                "panel y must top-align with anchor (anchor.maxY - panelHeight) - got \(origin.y)")
    }

    @Test("panelOrigin flips to leading edge when trailing overflows screen")
    func panelOriginFlipsLeftWhenRightOverflows() {
        let screen = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let anchor = NSRect(x: 1000, y: 200, width: 250, height: 100)
        // anchor.maxX = 1250, panel 360 wide -> 1250+8+360 = 1618 > 1280, so flip.
        let origin = ShadowPanelController.panelOrigin(
            forAnchorRect: anchor,
            panelSize: NSSize(width: 360, height: 480),
            in: screen,
            horizontalGap: 8
        )
        // Flipped: x = anchor.minX - panelWidth - gap = 1000 - 360 - 8 = 632
        #expect(origin.x == 632,
                "panel must flip to leading edge when right overflows - got \(origin.x)")
    }

    @Test("panelOrigin clamps left when neither side fits")
    func panelOriginClampsWhenNeitherSideFits() {
        // Tiny screen + anchor near left + huge panel: neither side has room.
        let screen = NSRect(x: 0, y: 0, width: 400, height: 400)
        let anchor = NSRect(x: 50, y: 100, width: 100, height: 50)
        // panel 360 wide. anchor.maxX=150, +8=158, +360=518 > 400 -> flip.
        // anchor.minX-360-8 = 50-360-8 = -318 (off left).
        // Then horizontal clamp: x < screen.minX (0), so x = 0.
        let origin = ShadowPanelController.panelOrigin(
            forAnchorRect: anchor,
            panelSize: NSSize(width: 360, height: 200),
            in: screen
        )
        #expect(origin.x == 0,
                "neither-side-fits clamps to screen.minX - got \(origin.x)")
    }

    @Test("panelOrigin clamps top when panel overflows screen.maxY")
    func panelOriginClampsTopWhenAboveScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let anchor = NSRect(x: 100, y: 750, width: 600, height: 100)
        // anchor.maxY = 850. y = 850 - 480 = 370. + 480 = 850 > 800 -> clamp.
        let origin = ShadowPanelController.panelOrigin(
            forAnchorRect: anchor,
            panelSize: NSSize(width: 360, height: 480),
            in: screen
        )
        // After top-clamp: y = screen.maxY - panelHeight = 800 - 480 = 320
        #expect(origin.y == 320,
                "panel must clamp inside screen.maxY when top would overflow - got \(origin.y)")
    }

    @Test("panelOrigin clamps bottom when panel overflows screen.minY")
    func panelOriginClampsBottomWhenBelowScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let anchor = NSRect(x: 100, y: 0, width: 600, height: 100)
        // anchor.maxY = 100. y = 100 - 480 = -380 -> clamp to 0.
        let origin = ShadowPanelController.panelOrigin(
            forAnchorRect: anchor,
            panelSize: NSSize(width: 360, height: 480),
            in: screen
        )
        #expect(origin.y == 0,
                "panel must clamp at screen.minY when below would underflow - got \(origin.y)")
    }

    @Test("panelOrigin respects custom horizontalGap")
    func panelOriginCustomGap() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let anchor = NSRect(x: 200, y: 400, width: 300, height: 100)
        let origin = ShadowPanelController.panelOrigin(
            forAnchorRect: anchor,
            panelSize: NSSize(width: 360, height: 240),
            in: screen,
            horizontalGap: 20
        )
        #expect(origin.x == 520,
                "horizontalGap=20 must yield x = anchor.maxX + 20 - got \(origin.x)")
    }

    // MARK: - Production mount dependencies

    @Test("ContextualShadowsState exposes configured Shadow search for the Halo mount")
    func contextualShadowsExposesHaloSearchService() {
        let state = ContextualShadowsState(isEnabledOverride: true)
        #expect(state.haloSearchService == nil)

        let search = HaloUIMockSearch()
        state.configureShadowSearch(search)

        #expect(state.haloSearchService != nil,
                "The editor Halo mount needs a read-only route to the already-configured Shadow backend")
    }
}

// MARK: - Test support

@MainActor
enum HaloUITestSupport {
    static func mockController() -> HaloController {
        HaloController(search: HaloUIMockSearch(), debounceWindowMs: 1)
    }
}

@MainActor
final class HaloUIMockSearch: ShadowSearchServicing, @unchecked Sendable {
    nonisolated func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit] {
        []
    }
}
