import AppKit
import SwiftData
import SwiftUI

// MARK: - ProseEditorRepresentable2
// TextKit 2 replacement for ProseEditorRepresentable.
// Uses NSTextContentStorage + NSTextLayoutManager (TK2 stack).
// MarkdownContentStorage provides on-demand paragraph styling via delegate —
// no PageStoragePool needed. Per-page state (scroll, selection, undo) in Coordinator2.
//
// Data flow:
//   1. ProseEditorView passes pageBody via @State binding
//   2. makeNSView creates ProseTextView2 via factory (wires TK2 stack + delegate)
//   3. updateNSView dispatches page swap / theme / focus / centering
//   4. Coordinator2 owns: binding sync (300ms), direct file save (3s),
//      AI streaming, table ops, fold/indent, bracket auto-close

struct ProseEditorRepresentable2: NSViewRepresentable {
    @Binding var text: String
    let pageId: String
    let pageBody: String
    let isFocused: Bool
    let theme: EpistemosTheme
    let isEditable: Bool
    let isFocusMode: Bool
    var modelContext: ModelContext?
    var onWikilinkClick: ((String) -> Void)?
    var onBlockRefClick: ((String) -> Void)?
    var noteChatState: NoteChatState?
    var onPageFlush: ((String, String) -> Void)?
    var graphState: GraphState?

    static let maxReadableWidth: CGFloat = 720
    static let minHorizontalInset: CGFloat = 60
    static let verticalInset: CGFloat = 40

    func makeCoordinator() -> Coordinator2 { Coordinator2(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let coord = context.coordinator

        // Use the factory which properly builds the TK2 stack + delegate wiring
        let (scrollView, tv) = ProseTextView2.makeTextKit2()

        tv.isEditable = isEditable
        tv.delegate = coord
        tv.textContainerInset = NSSize(
            width: Self.minHorizontalInset,
            height: Self.verticalInset
        )

        tv.applyTheme(theme)

        // Load initial content
        let body = pageBody
        tv.markdownDelegate.reparse(text: body)
        let textStorage = tv.textStorage!
        coord.isFlushingTokens = true
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: body)
        textStorage.endEditing()
        tv.didChangeText()
        coord.isFlushingTokens = false

        coord.textView = tv
        coord.scrollView = scrollView
        coord.currentPageId = pageId
        coord.lastSyncedText = body
        coord.lastTheme = theme
        coord.lastIsFocusMode = isFocusMode
        coord.lastIsEditable = isEditable

        // Wire AI chat callbacks
        coord.wireNoteChatCallbacks()

        // Focus
        if isFocused {
            DispatchQueue.main.async {
                tv.window?.makeFirstResponder(tv)
            }
        }

        // Centering
        coord.updateCentering()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator
        coord.parent = self
        coord.handleUpdate()
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator2) {
        coordinator.handleDismantle()
    }
}

// MARK: - Coordinator2

extension ProseEditorRepresentable2 {
    @MainActor
    final class Coordinator2: NSObject, NSTextViewDelegate {
        var parent: ProseEditorRepresentable2
        nonisolated(unsafe) var textView: ProseTextView2?
        var scrollView: NSScrollView?

        var currentPageId: String = ""
        var lastSyncedText: String = ""
        var lastTheme: EpistemosTheme = .light
        var lastIsFocusMode: Bool = false
        var lastIsEditable: Bool = true
        var lastAvailableWidth: CGFloat = 0

        // Binding sync
        var bindingSyncTask: Task<Void, Never>?
        var isFlushingTokens = false

        // Direct file save
        var directSaveTask: Task<Void, Never>?

        // Table alignment
        var tableAlignTask: Task<Void, Never>?

        // Per-page state
        struct PageState {
            var scrollY: CGFloat = 0
            var selection: NSRange = NSRange(location: 0, length: 0)
            var undoManager: UndoManager = UndoManager()
        }
        var pageStates: [String: PageState] = [:]

        init(_ parent: ProseEditorRepresentable2) {
            self.parent = parent
            super.init()
        }

        // MARK: - Update Dispatcher

        func handleUpdate() {
            guard let tv = textView else { return }

            // Page swap
            if parent.pageId != currentPageId {
                handlePageSwap()
                return
            }

            // Theme change
            if parent.theme != lastTheme {
                handleThemeChange()
            }

            // Focus mode
            if parent.isFocusMode != lastIsFocusMode {
                lastIsFocusMode = parent.isFocusMode
                tv.isFocusMode = parent.isFocusMode
                if parent.isFocusMode {
                    tv.applyFocusDimming()
                } else {
                    tv.clearFocusDimming()
                }
            }

            // Editable
            if parent.isEditable != lastIsEditable {
                lastIsEditable = parent.isEditable
                tv.isEditable = parent.isEditable
            }

            // Recalculate centering only when width changes
            if let sv = scrollView {
                let currentWidth = sv.contentSize.width
                if abs(lastAvailableWidth - currentWidth) > 0.5 {
                    lastAvailableWidth = currentWidth
                    updateCentering()
                }
            }

            // Wire note chat if reference changed
            if let noteChat = parent.noteChatState {
                wireNoteChatCallbacks()
            }
        }

        // MARK: - Page Swap

        func handlePageSwap() {
            // placeholder — Task 3
        }

        // MARK: - Theme Change

        func handleThemeChange() {
            // placeholder — Task 4
        }

        // MARK: - Centering

        func updateCentering() {
            guard let tv = textView, let sv = scrollView else { return }
            let viewWidth = sv.contentSize.width
            let finalInset = max(
                ProseEditorRepresentable2.minHorizontalInset,
                (viewWidth - ProseEditorRepresentable2.maxReadableWidth) / 2
            )
            let newInset = NSSize(
                width: finalInset,
                height: ProseEditorRepresentable2.verticalInset
            )
            if tv.textContainerInset != newInset {
                tv.textContainerInset = newInset
            }
        }

        // MARK: - AI Chat Wiring

        func wireNoteChatCallbacks() {
            // placeholder — Task 5
        }

        // MARK: - Dismantle

        func handleDismantle() {
            bindingSyncTask?.cancel()
            directSaveTask?.cancel()
            tableAlignTask?.cancel()
            saveCurrentPageState()
            // Persist to disk
            if !currentPageId.isEmpty {
                DiskStyleCache.shared.save(
                    pageId: currentPageId,
                    bodyText: textView?.string ?? "",
                    scrollY: scrollView?.contentView.bounds.origin.y ?? 0,
                    selection: textView?.selectedRange() ?? NSRange(location: 0, length: 0)
                )
            }
        }

        func saveCurrentPageState() {
            guard let tv = textView, !currentPageId.isEmpty else { return }
            let scrollY = scrollView?.contentView.bounds.origin.y ?? 0
            let selection = tv.selectedRange()
            pageStates[currentPageId] = PageState(
                scrollY: scrollY,
                selection: selection,
                undoManager: tv.undoManager ?? UndoManager()
            )
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            guard !tv.hasMarkedText() else { return }
            guard !isFlushingTokens else { return }
            let newText = tv.string
            debouncedBindingSync(newText)
            scheduleDirectSave(newText)
        }

        // MARK: - Link Click Handling

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let urlString = link as? String else { return false }
            if urlString.hasPrefix("wikilink://") {
                let title = String(urlString.dropFirst("wikilink://".count))
                parent.onWikilinkClick?(title)
                return true
            }
            if urlString.hasPrefix("blockref://") {
                let blockId = String(urlString.dropFirst("blockref://".count))
                parent.onBlockRefClick?(blockId)
                return true
            }
            return false
        }

        // MARK: - Binding Sync (300ms debounce)

        func debouncedBindingSync(_ newText: String) {
            // placeholder — Task 2
        }

        // MARK: - Direct File Save (3s defense-in-depth)

        func scheduleDirectSave(_ newText: String) {
            // placeholder — Task 2
        }
    }
}
