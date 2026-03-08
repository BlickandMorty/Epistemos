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
        // Saves old page state, flushes unsaved edits, loads new content in-place.
        // No storage instance swap (unlike TK1) — reparse + replace is sufficient.

        func handlePageSwap() {
            guard let tv = textView else { return }
            let oldPageId = currentPageId

            // 1. Save old page state (in-memory + disk)
            saveCurrentPageState()
            let currentText = tv.string
            DiskStyleCache.shared.save(
                pageId: oldPageId,
                bodyText: currentText,
                scrollY: scrollView?.contentView.bounds.origin.y ?? 0,
                selection: tv.selectedRange()
            )

            // 2. Flush unsaved edits to old page
            if currentText != lastSyncedText {
                parent.onPageFlush?(oldPageId, currentText)
            }

            // 3. Cancel pending tasks
            bindingSyncTask?.cancel()
            directSaveTask?.cancel()
            tableAlignTask?.cancel()

            // 4. Load new page
            let newPageId = parent.pageId
            let newBody = parent.pageBody
            currentPageId = newPageId

            // 5. Replace text in-place + reparse
            tv.markdownDelegate.reparse(text: newBody)
            let textStorage = tv.textStorage!
            isFlushingTokens = true
            textStorage.beginEditing()
            textStorage.replaceCharacters(
                in: NSRange(location: 0, length: textStorage.length),
                with: newBody
            )
            textStorage.endEditing()
            tv.didChangeText()
            isFlushingTokens = false
            lastSyncedText = newBody

            // 6. Restore state for new page
            if let state = pageStates[newPageId] {
                tv.setSelectedRange(state.selection)
                scrollView?.contentView.scroll(to: NSPoint(x: 0, y: state.scrollY))
            } else if let diskState = DiskStyleCache.shared.restore(
                pageId: newPageId, currentBodyText: newBody
            ) {
                tv.setSelectedRange(diskState.selection)
                scrollView?.contentView.scroll(to: NSPoint(x: 0, y: diskState.scrollY))
            } else {
                tv.setSelectedRange(NSRange(location: 0, length: 0))
                scrollView?.contentView.scroll(to: .zero)
            }

            // 7. Per-page undo manager
            if let state = pageStates[newPageId] {
                tv.pageUndoManager = state.undoManager
            } else {
                tv.pageUndoManager = UndoManager()
            }

            // 8. Update derived state
            lastTheme = parent.theme
            lastIsFocusMode = parent.isFocusMode
            lastIsEditable = parent.isEditable
            tv.isEditable = parent.isEditable
            updateCentering()
            tv.window?.makeFirstResponder(tv)
        }

        // MARK: - Theme Change

        func handleThemeChange() {
            guard let tv = textView else { return }
            lastTheme = parent.theme
            tv.applyTheme(parent.theme)
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

        // MARK: - AI Chat (v2 — inline response streaming)
        // Same protocol as TK1: divider-based inline response with accept/discard.

        private static let aiDivider = "\n\n<!-- ai-response -->\n\n"
        private var wiredChatState: NoteChatState?

        func wireNoteChatCallbacks() {
            guard let noteChat = parent.noteChatState,
                  wiredChatState !== noteChat else { return }
            wiredChatState = noteChat

            noteChat.noteBodyProvider = { [weak self] in
                self?.textView?.string ?? ""
            }

            noteChat.onStreamStart = { [weak self] _ in
                self?.startNoteChatStream()
            }

            noteChat.onTokenFlush = { [weak self] delta in
                self?.appendNoteChatTokens(delta)
            }

            noteChat.onAccept = { [weak self] in
                self?.acceptNoteChatResponse()
            }

            noteChat.onDiscard = { [weak self] in
                self?.discardNoteChatResponse()
            }

            noteChat.onInsertAtCursor = { [weak self] text in
                self?.insertTextAtCursor(text)
            }
        }

        private func startNoteChatStream() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            isFlushingTokens = true
            ts.replaceCharacters(
                in: NSRange(location: ts.length, length: 0),
                with: Self.aiDivider
            )
            tv.didChangeText()
            isFlushingTokens = false
            tv.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
        }

        private func appendNoteChatTokens(_ delta: String) {
            guard let tv = textView, let ts = tv.textStorage, !delta.isEmpty else { return }
            isFlushingTokens = true
            ts.replaceCharacters(
                in: NSRange(location: ts.length, length: 0),
                with: delta
            )
            tv.didChangeText()
            isFlushingTokens = false
            tv.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
        }

        private func acceptNoteChatResponse() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let str = ts.string
            guard let range = str.range(of: Self.aiDivider, options: .backwards) else { return }
            let nsRange = NSRange(range, in: str)
            isFlushingTokens = true
            ts.replaceCharacters(in: nsRange, with: "\n\n")
            tv.didChangeText()
            isFlushingTokens = false
            flushBindingSync()
        }

        private func discardNoteChatResponse() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let str = ts.string
            guard let range = str.range(of: Self.aiDivider, options: .backwards) else { return }
            let nsRange = NSRange(range, in: str)
            let deleteRange = NSRange(location: nsRange.location, length: ts.length - nsRange.location)
            isFlushingTokens = true
            ts.replaceCharacters(in: deleteRange, with: "")
            tv.didChangeText()
            isFlushingTokens = false
            flushBindingSync()
        }

        private func insertTextAtCursor(_ text: String) {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let loc = tv.selectedRange().location
            let insertion = "\n\n" + text + "\n"
            isFlushingTokens = true
            if tv.shouldChangeText(in: NSRange(location: loc, length: 0), replacementString: insertion) {
                ts.replaceCharacters(in: NSRange(location: loc, length: 0), with: insertion)
                tv.didChangeText()
                tv.setSelectedRange(NSRange(location: loc + (insertion as NSString).length, length: 0))
            }
            isFlushingTokens = false
            flushBindingSync()
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
        // Coalesces rapid keystrokes so SwiftUI @Binding updates at most ~3×/second.
        // Prevents per-keystroke view tree re-evaluation (same cadence as TK1).

        func debouncedBindingSync(_ newText: String) {
            bindingSyncTask?.cancel()
            bindingSyncTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { return }
                guard !self.isFlushingTokens else { return }
                self.parent.text = newText
                self.lastSyncedText = newText
            }
        }

        /// Flush binding immediately — called by accept/discard to persist AI changes.
        func flushBindingSync() {
            bindingSyncTask?.cancel()
            guard let tv = textView else { return }
            let text = tv.string
            parent.text = text
            lastSyncedText = text
        }

        // MARK: - Direct File Save (3s defense-in-depth)
        // Writes to disk independently of SwiftData persist cycle.
        // If the app crashes between binding sync and debouncedSave (in ProseEditorView),
        // the file on disk still has recent content.

        func scheduleDirectSave(_ newText: String) {
            directSaveTask?.cancel()
            let pageId = currentPageId
            directSaveTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self else { return }
                await Task.detached(priority: .utility) {
                    NoteFileStorage.writeBody(pageId: pageId, content: newText)
                }.value
            }
        }
    }
}
