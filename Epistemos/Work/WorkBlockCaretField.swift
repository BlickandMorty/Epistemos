import SwiftUI
import AppKit

// Single-line text input with a PIXEL BLOCK caret (owner's "blocky cursor" — the TUI identity). A custom NSTextView
// that draws a filled BLOCK insertion point (widen the caret rect; the proven block-caret pattern) instead of the thin
// system bar, treats Enter as submit, and treats Tab as "add to queue" (single-line; no newline/tab insertion). Text
// binding is two-way; the placeholder is drawn by the SwiftUI host (so this stays minimal + robust).
// drawsBackground=false so the host's flat background shows.
struct WorkBlockCaretField: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var caretColor: NSColor
    var isEnabled: Bool = true
    var onSubmit: () -> Void = {}
    var onQueue: () -> Void = {}

    func makeNSView(context: Context) -> WorkBlockCaretTextView {
        let view = WorkBlockCaretTextView()
        view.delegate = context.coordinator
        view.isRichText = false
        view.drawsBackground = false
        view.allowsUndo = true
        view.font = font
        view.textColor = .labelColor
        view.caretColor = caretColor
        view.onSubmit = { context.coordinator.parent.onSubmit() }
        view.onQueue = { context.coordinator.parent.onQueue() }
        view.textContainerInset = NSSize(width: 0, height: 1)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        // Auto-focus so the user can type immediately when the surface appears.
        DispatchQueue.main.async { [weak view] in view?.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ view: WorkBlockCaretTextView, context: Context) {
        context.coordinator.parent = self
        if view.string != text { view.string = text }
        view.font = font
        view.caretColor = caretColor
        view.isEditable = isEnabled
        view.isSelectable = isEnabled
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WorkBlockCaretField
        init(_ parent: WorkBlockCaretField) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}

final class WorkBlockCaretTextView: NSTextView {
    var caretColor: NSColor = .controlAccentColor
    var onSubmit: () -> Void = {}
    var onQueue: () -> Void = {}

    private var caretWidth: CGFloat {
        let advance = (font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)).maximumAdvancement.width
        return advance > 1 ? advance : 7
    }

    /// Block caret: widen the insertion-point rect so it fills a character cell (the system fills/erases the rect).
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var blockRect = rect
        blockRect.size.width = caretWidth
        super.drawInsertionPoint(in: blockRect, color: caretColor.withAlphaComponent(0.55), turnedOn: flag)
    }

    /// Ensure the wider block fully invalidates/erases on blink.
    override func setNeedsDisplay(_ invalidRect: NSRect, avoidAdditionalLayout flag: Bool) {
        var rect = invalidRect
        rect.size.width += caretWidth
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }

    /// Single-line: Enter submits (no newline inserted).
    override func insertNewline(_ sender: Any?) {
        onSubmit()
    }

    /// Single-line: Tab stages the prompt in the native queue (no tab inserted / no focus hop).
    override func insertTab(_ sender: Any?) {
        onQueue()
    }
}
