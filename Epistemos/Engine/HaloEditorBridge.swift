import AppKit
import Foundation
import OSLog
import os.signpost

// MARK: - HaloEditorBridge
//
// Wave 8.6 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"What gets measured").
//
// The wire that connects any NSTextView to a HaloController. Per the
// V1 decision §"Concurrency": editor delegate fires on every keystroke
// → bridge forwards to `HaloController.editorTextDidChange` (cheap,
// non-blocking, instant return).
//
// Per V1 §"What gets measured": every hot path emits an os_signpost
// interval. The bridge owns the editor.keystrokeToFrame.ms interval
// (begin on textDidChange, end on next layout pass — out of scope for
// this base; the begin/end pair lives here as a hook future timing
// code will use).

/// Adapter that connects an NSTextView to a HaloController. Single
/// instance per editor view. Holds a weak reference to the textView so
/// the bridge can be torn down without cycle leaks.
@MainActor
public final class HaloEditorBridge: NSObject {

    public let controller: HaloController
    /// Domain to attribute keystrokes to. Most editors host one
    /// domain (.notes / .chats); a multi-domain editor (e.g. a chat
    /// transcript with embedded notes) sets this on each delegate
    /// callback.
    public var domain: ShadowDomain
    private weak var textView: NSTextView?
    private static let log = Logger(subsystem: "com.epistemos", category: "HaloEditorBridge")
    private static let signpost = OSLog(subsystem: "com.epistemos", category: .pointsOfInterest)

    public init(
        controller: HaloController,
        textView: NSTextView,
        domain: ShadowDomain = .notes
    ) {
        self.controller = controller
        self.textView = textView
        self.domain = domain
        super.init()
        textView.delegate = self
    }

    /// Detach the bridge from its textView. Idempotent.
    public func disconnect() {
        if textView?.delegate === self {
            textView?.delegate = nil
        }
        textView = nil
    }

    /// Manual delivery — used by callers that own a non-NSTextView
    /// surface (e.g. a SwiftUI TextEditor or a WKWebView contentDidChange
    /// hook) but still want to drive the controller. Avoids the
    /// NSTextView delegate detour.
    public func feed(text: String) {
        Self.beginSignpost()
        defer { Self.endSignpost() }
        controller.editorTextDidChange(text, domain: domain)
    }

    /// Tell the controller the editor lost focus. Mirrors
    /// HaloController.editorDidLoseFocus.
    public func notifyFocusLost() {
        controller.editorDidLoseFocus()
    }

    private static func beginSignpost() {
        os_signpost(
            .begin,
            log: signpost,
            name: "halo.editorTextDidChange"
        )
    }

    private static func endSignpost() {
        os_signpost(
            .end,
            log: signpost,
            name: "halo.editorTextDidChange"
        )
    }
}

// MARK: - NSTextViewDelegate

extension HaloEditorBridge: NSTextViewDelegate {

    public func textDidChange(_ notification: Notification) {
        guard let view = notification.object as? NSTextView else { return }
        feed(text: view.string)
    }

    public func textDidEndEditing(_ notification: Notification) {
        notifyFocusLost()
    }
}
