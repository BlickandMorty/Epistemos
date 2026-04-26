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
