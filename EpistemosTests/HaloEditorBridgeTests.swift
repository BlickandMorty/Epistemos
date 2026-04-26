import AppKit
import Foundation
import Testing

@testable import Epistemos

/// Wave 8.6 source-guard for the editor → HaloController wire.
@MainActor
@Suite("HaloEditorBridge (Wave 8.6 base)")
struct HaloEditorBridgeTests {

    private static func makeController() -> (HaloController, HaloEditorMockSearch) {
        let mock = HaloEditorMockSearch()
        let ctrl = HaloController(search: mock, debounceWindowMs: 10)
        return (ctrl, mock)
    }

    private static func waitForState(
        _ controller: HaloController,
        until predicate: @MainActor @Sendable (HaloState) -> Bool,
        timeout: TimeInterval = 0.5
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(controller.state) { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    @Test("init wires the bridge as the textView's delegate")
    func initWiresDelegate() {
        let (ctrl, _) = Self.makeController()
        let view = NSTextView()
        let bridge = HaloEditorBridge(controller: ctrl, textView: view)
        #expect(view.delegate === bridge,
                "HaloEditorBridge must claim NSTextView.delegate so textDidChange fires through it")
    }

    @Test("disconnect detaches the delegate")
    func disconnectDetaches() {
        let (ctrl, _) = Self.makeController()
        let view = NSTextView()
        let bridge = HaloEditorBridge(controller: ctrl, textView: view)
        bridge.disconnect()
        #expect(view.delegate == nil,
                "disconnect() must release the delegate so the editor doesn't drive the (gone) bridge")
    }

    @Test("feed forwards text + domain to the controller")
    func feedForwards() async {
        let (ctrl, mock) = Self.makeController()
        mock.nextResults = [
            ShadowHit(id: "n1", title: "kant", snippet: "duty", score: 0.9, domain: .notes, source: "stub")
        ]
        let view = NSTextView()
        let bridge = HaloEditorBridge(controller: ctrl, textView: view, domain: .notes)

        bridge.feed(text: "kant on duty")
        await Self.waitForState(ctrl) { state in
            if case .available = state { return true }
            return false
        }
        #expect(mock.callCount == 1)
        #expect(mock.lastQuery == "kant on duty")
        #expect(mock.lastDomain == .notes)
    }

    @Test("notifyFocusLost transitions the controller back to .dormant")
    func focusLost() async {
        let (ctrl, mock) = Self.makeController()
        mock.nextResults = [
            ShadowHit(id: "n1", title: "kant", snippet: "duty", score: 0.9, domain: .notes, source: "stub")
        ]
        let bridge = HaloEditorBridge(controller: ctrl, textView: NSTextView())
        bridge.feed(text: "kant on duty")
        await Self.waitForState(ctrl) { state in
            if case .available = state { return true }
            return false
        }
        bridge.notifyFocusLost()
        #expect(ctrl.state == .dormant,
                "notifyFocusLost must collapse the controller to .dormant — Halo hides immediately when the editor loses focus")
    }

    @Test("textDidChange notification routes through feed")
    func textDidChangeNotification() async {
        let (ctrl, mock) = Self.makeController()
        mock.nextResults = [
            ShadowHit(id: "n1", title: "kant", snippet: "duty", score: 0.9, domain: .notes, source: "stub")
        ]
        let view = NSTextView()
        let bridge = HaloEditorBridge(controller: ctrl, textView: view, domain: .notes)
        view.string = "kant on duty"

        // Synthesise the notification the way NSTextView does.
        let notification = Notification(name: NSText.didChangeNotification, object: view)
        bridge.textDidChange(notification)

        await Self.waitForState(ctrl) { state in
            if case .available = state { return true }
            return false
        }
        #expect(mock.lastQuery == "kant on duty",
                "textDidChange must read view.string + forward to feed → controller")
    }
}

@MainActor
final class HaloEditorMockSearch: ShadowSearchServicing, @unchecked Sendable {
    var nextResults: [ShadowHit] = []
    private(set) var callCount = 0
    private(set) var lastQuery = ""
    private(set) var lastDomain: ShadowDomain = .notes

    nonisolated func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit] {
        await MainActor.run {
            self.callCount += 1
            self.lastQuery = text
            self.lastDomain = domain
        }
        return await MainActor.run { self.nextResults }
    }
}
