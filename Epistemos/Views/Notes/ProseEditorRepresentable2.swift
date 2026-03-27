import AppKit
import SwiftData
import SwiftUI

// MARK: - ProseEditorRepresentable2
// TextKit 2 note editor bridge.
// Uses NSTextContentStorage + NSTextLayoutManager for editing.
// MarkdownContentStorage provides on-demand paragraph styling via delegate.
// Per-page state (scroll, selection, undo) lives in Coordinator2.
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

    static func horizontalInset(for availableWidth: CGFloat, markdown: String) -> CGFloat {
        _ = availableWidth
        _ = markdown
        return minHorizontalInset
    }

    func makeCoordinator() -> Coordinator2 { Coordinator2(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let coord = context.coordinator

        // Use the factory which properly builds the TK2 stack + delegate wiring
        let (scrollView, tv) = ProseTextView2.makeTextKit2()

        tv.isEditable = isEditable
        tv.delegate = coord
        tv.usesRenderedTableOverlays = false
        tv.markdownDelegate.usesRenderedTableOverlays = false
        tv.textContainerInset = NSSize(width: Self.minHorizontalInset, height: Self.verticalInset)

        tv.applyTheme(theme)

        // Load initial content
        let body = pageBody
        tv.markdownDelegate.reparse(text: body)
        if let textStorage = tv.textStorage {
            coord.isFlushingTokens = true
            textStorage.beginEditing()
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: body)
            textStorage.endEditing()
            tv.didChangeText()
            coord.isFlushingTokens = false
        }

        coord.textView = tv
        coord.scrollView = scrollView
        coord.currentPageId = pageId
        coord.lastSyncedText = body
        coord.lastPersistedText = body
        coord.lastTheme = theme
        coord.lastIsFocusMode = isFocusMode
        coord.lastIsEditable = isEditable
        // Wire AI chat callbacks
        coord.wireNoteChatCallbacks()

        // Wire page ID + interaction closures
        tv.pageId = pageId
        tv.onFoldToggle = { [weak coord] offset in
            coord?.toggleFold(headingOffset: offset)
        }
        tv.onOpenInGraph = { pid in
            HologramController.shared.revealPage(pid)
        }

        // Scroll-to-offset observer for TOC section navigator.
        coord.scrollToOffsetObserver = NotificationCenter.default.addObserver(
            forName: ProseTextView2.scrollToOffsetNotification,
            object: nil,
            queue: .main
        ) { [weak tv, weak coord] notification in
            guard let offset = notification.userInfo?["charOffset"] as? Int,
                  let pid = notification.userInfo?["pageId"] as? String else { return }
            MainActor.assumeIsolated {
                guard let coord,
                      let tv,
                      pid == coord.currentPageId else { return }
                let safeOffset = min(offset, (tv.string as NSString).length)
                tv.scrollToCharacterOffset(safeOffset)
                let range = NSRange(location: safeOffset, length: 0)
                let lineRange = (tv.string as NSString).lineRange(for: range)
                tv.showFindIndicator(for: lineRange)
            }
        }
        coord.writingToolsObserver = NotificationCenter.default.addObserver(
            forName: WritingToolsBridge.showNotification,
            object: nil,
            queue: .main
        ) { [weak tv, weak coord] note in
            guard let pid = note.userInfo?["pageId"] as? String else { return }
            MainActor.assumeIsolated {
                guard let tv,
                      let coord,
                      pid == coord.currentPageId else { return }
                WritingToolsBridge.present(in: tv)
            }
        }
        coord.replaceRangeObserver = NotificationCenter.default.addObserver(
            forName: NoteEditorNotifications.replaceRange,
            object: nil,
            queue: .main
        ) { [weak tv, weak coord] note in
            let userInfo = note.userInfo
            let pid = userInfo?["pageId"] as? String
            let replacementRange = (userInfo?["range"] as? NSValue)?.rangeValue
            let replacement = userInfo?["replacement"] as? String
            MainActor.assumeIsolated {
                guard let tv,
                      let coord,
                      let pid,
                      pid == coord.currentPageId,
                      let replacementRange,
                      let replacement,
                      let edit = MarkdownEditorCommands.replace(
                        in: tv.string,
                        range: replacementRange,
                        replacement: replacement
                      ) else { return }
                _ = MarkdownEditorCommands.apply(edit, to: tv)
                tv.window?.makeFirstResponder(tv)
            }
        }

        // Overlay subsystems (Phase 9)
        if let mc = modelContext {
            let autocomplete = BlockRefAutocomplete2()
            autocomplete.configure(textView: tv, modelContext: mc)
            coord.blockRefAutocomplete = autocomplete

            let transclusionMgr = TransclusionOverlayManager2(textView: tv)
            transclusionMgr.configure(modelContext: mc)
            transclusionMgr.onBlockEdit = { [weak coord] blockId, newContent in
                coord?.handleTransclusionEdit(blockId: blockId, newContent: newContent)
            }
            coord.transclusionManager = transclusionMgr
            transclusionMgr.refreshAfterTextChange()
        }

        // Reposition transclusion overlays on scroll
        scrollView.contentView.postsBoundsChangedNotifications = true
        coord.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coord] _ in
            MainActor.assumeIsolated {
                coord?.scheduleScrollOverlayRefresh()
            }
        }

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
        coord.textBinding = _text
        coord.handleUpdate()
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator2) {
        // NSViewRepresentable guarantees main-thread dismantle for AppKit.
        // Defensive check: if not on main, dispatch synchronously to avoid data race.
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                coordinator.handleDismantle()
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    coordinator.handleDismantle()
                }
            }
        }
    }
}

// MARK: - Coordinator2

extension ProseEditorRepresentable2 {
    @MainActor
    final class Coordinator2: NSObject, NSTextViewDelegate {
        var parent: ProseEditorRepresentable2
        var textBinding: Binding<String>
        nonisolated(unsafe) var textView: ProseTextView2?
        var scrollView: NSScrollView?

        var currentPageId: String = ""
        var lastSyncedText: String = ""
        var lastPersistedText: String = ""
        var lastIsFocused: Bool = false
        var lastTheme: EpistemosTheme = .nativeDefault
        var lastIsFocusMode: Bool = false
        var lastIsEditable: Bool = true
        var lastAvailableWidth: CGFloat = 0
        let scrollOverlayRefreshCoalescer = ScrollWorkCoalescer(
            delay: NoteEditorPerformancePolicy.scrollWorkCoalescingDelay
        )

        // Binding sync
        var bindingSyncTask: Task<Void, Never>?
        var hasPendingBindingSync = false
        var isFlushingTokens = false

        // Table alignment
        var tableAlignTask: Task<Void, Never>?

        // Bracket auto-close
        private var isInsertingBrackets = false

        // Data detection
        private var dataDetectionTask: Task<Void, Never>?

        // BTK: block edit translator for real-time block tracking
        var blockEditTranslator: BlockEditTranslator?

        // Scroll-to-offset observer for TOC section navigator.
        var scrollToOffsetObserver: (any NSObjectProtocol)?

        // Ask-bar bridge for native Apple Writing Tools.
        var writingToolsObserver: (any NSObjectProtocol)?

        // External range replacement bridge (block properties, future editor mutations).
        var replaceRangeObserver: (any NSObjectProtocol)?

        // Overlay subsystems (Phase 9)
        var blockRefAutocomplete: BlockRefAutocomplete2?
        var transclusionManager: TransclusionOverlayManager2?
        var renderedTableOverlayManager: RenderedTableOverlayManager2?
        var scrollObserver: (any NSObjectProtocol)?

        // Per-page state
        struct PageState {
            var scrollY: CGFloat = 0
            var selection: NSRange = NSRange(location: 0, length: 0)
            var undoManager: UndoManager = UndoManager()
        }
        var pageStates: [String: PageState] = [:]

        init(_ parent: ProseEditorRepresentable2) {
            self.parent = parent
            self.textBinding = parent._text
            super.init()
        }

        // MARK: - Update Dispatcher

        func handleUpdate() {
            guard let tv = textView else { return }
            tv.markdownDelegate.usesRenderedTableOverlays = false

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

            if parent.isFocused != lastIsFocused {
                lastIsFocused = parent.isFocused
                focusEditorIfNeeded()
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
            if parent.noteChatState != nil {
                wireNoteChatCallbacks()
            }
            tv.hasProtectedInlineResponseDivider = parent.noteChatState?.hasResponse == true
                && parent.noteChatState?.useResponsePanel == false

            // External body sync — vault sync / restore-to-version changed pageBody
            // outside of user editing. Replace storage content to pick up the new text.
            // Guards: skip during AI streaming (isFlushingTokens), IME composition,
            // pending binding sync (debounce window holds unsaved keystrokes).
            if !isFlushingTokens,
               !tv.hasMarkedText(),
               bindingSyncTask == nil,
               parent.pageBody != lastSyncedText,
               parent.pageBody != tv.string
            {
                let newBody = parent.pageBody
                let sel = tv.selectedRange()
                tv.markdownDelegate.reparse(text: newBody)
                guard let textStorage = tv.textStorage else { return }
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
                lastPersistedText = newBody
                let safeLoc = min(sel.location, (tv.string as NSString).length)
                tv.setSelectedRange(NSRange(location: safeLoc, length: 0))
                renderedTableOverlayManager?.refreshAfterTextChange()
            }
        }

        // MARK: - Page Swap
        // Saves old page state, flushes unsaved edits, loads new content in-place.
        // No storage instance swap is needed here; reparse + replace is sufficient.

        func handlePageSwap() {
            guard let tv = textView else { return }
            let oldPageId = currentPageId

            // 1. Strip ephemeral content BEFORE reading text for save.
            //    AI divider + unaccepted response must be discarded.
            //    Folds are non-destructive (shouldEnumerate) — no storage restore needed.
            clearAllFolds()
            stripUnacceptedAIResponse()

            // 2. Save old page state (in-memory + disk)
            saveCurrentPageState()
            let currentText = tv.string
            DiskStyleCache.shared.save(
                pageId: oldPageId,
                bodyText: currentText,
                scrollY: scrollView?.contentView.bounds.origin.y ?? 0,
                selection: tv.selectedRange()
            )

            // 3. Flush unsaved edits to old page
            // Guard against lastPersistedText (disk state), NOT lastSyncedText (binding state).
            // After 300ms binding sync, lastSyncedText == currentText even though
            // the 5s ProseEditorView save may not have fired yet. onPageFlush is the
            // only persistence path during a page swap, so compare against disk state.
            if currentText != lastPersistedText {
                parent.onPageFlush?(oldPageId, currentText)
                lastPersistedText = currentText
            }

            // 3. Cancel pending tasks + clear overlays
            bindingSyncTask?.cancel()
            tableAlignTask?.cancel()
            dataDetectionTask?.cancel()
            transclusionManager?.removeAll()
            renderedTableOverlayManager?.removeAll()
            blockRefAutocomplete?.dismiss()

            // 4. Load new page
            let newPageId = parent.pageId
            let newBody = parent.pageBody
            currentPageId = newPageId

            // 5. Replace text in-place + reparse
            tv.markdownDelegate.reparse(text: newBody)
            guard let textStorage = tv.textStorage else { return }
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
            lastPersistedText = newBody
            tv.pageId = newPageId

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
            renderedTableOverlayManager?.setTheme(tv.resolvedTheme)
            renderedTableOverlayManager?.refreshAfterTextChange()
            focusEditorIfNeeded()

            // 9. BTK: Initialize block edit translator for new page
            if let graphState = parent.graphState {
                let translator = BlockEditTranslator(
                    pageId: newPageId, graphState: graphState
                )
                if let mc = parent.modelContext {
                    let descriptor = FetchDescriptor<SDBlock>(
                        predicate: #Predicate<SDBlock> { $0.pageId == newPageId },
                        sortBy: [SortDescriptor(\.order)]
                    )
                    let existingBlocks = (try? mc.fetch(descriptor)) ?? []
                    translator.initIfNeeded(existingBlocks: existingBlocks)
                }
                blockEditTranslator = translator
            } else {
                blockEditTranslator = nil
            }
        }

        // MARK: - Theme Change

        func handleThemeChange() {
            guard let tv = textView else { return }
            lastTheme = parent.theme
            tv.applyTheme(parent.theme)
            renderedTableOverlayManager?.setTheme(tv.resolvedTheme)
        }

        // MARK: - Centering

        func updateCentering() {
            guard let tv = textView, let sv = scrollView else { return }
            let viewWidth = sv.contentSize.width
            let finalInset = ProseEditorRepresentable2.horizontalInset(
                for: viewWidth,
                markdown: tv.string
            )
            let newInset = NSSize(
                width: finalInset,
                height: ProseEditorRepresentable2.verticalInset
            )
            if tv.textContainerInset != newInset {
                tv.textContainerInset = newInset
            }
            renderedTableOverlayManager?.refresh()
        }

        // MARK: - AI Chat (v2 — inline response streaming)
        // Divider-based inline response with accept/discard.

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
            let insertLoc = ts.length
            tv.setProgrammaticEditLocation(insertLoc)
            ts.replaceCharacters(
                in: NSRange(location: insertLoc, length: 0),
                with: NoteChatInlineResponse.divider
            )
            tv.didChangeText()
            isFlushingTokens = false
            tv.hasProtectedInlineResponseDivider = true
            tv.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
        }

        private func appendNoteChatTokens(_ delta: String) {
            guard let tv = textView, let ts = tv.textStorage, !delta.isEmpty else { return }
            isFlushingTokens = true
            let insertLoc = ts.length
            tv.setProgrammaticEditLocation(insertLoc)
            ts.replaceCharacters(
                in: NSRange(location: insertLoc, length: 0),
                with: delta
            )
            tv.didChangeText()
            isFlushingTokens = false
            tv.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
        }

        private func acceptNoteChatResponse() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let str = ts.string
            guard let range = NoteChatInlineResponse.dividerRange(in: str) else { return }
            let nsRange = NSRange(range, in: str)
            isFlushingTokens = true
            tv.setProgrammaticEditLocation(nsRange.location)
            ts.replaceCharacters(in: nsRange, with: "\n\n")
            tv.didChangeText()
            isFlushingTokens = false
            tv.hasProtectedInlineResponseDivider = false
            flushBindingSync()
        }

        private func discardNoteChatResponse() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let str = ts.string
            guard let range = NoteChatInlineResponse.dividerRange(in: str) else { return }
            let nsRange = NSRange(range, in: str)
            let deleteRange = NSRange(location: nsRange.location, length: ts.length - nsRange.location)
            isFlushingTokens = true
            tv.setProgrammaticEditLocation(nsRange.location)
            ts.replaceCharacters(in: deleteRange, with: "")
            tv.didChangeText()
            isFlushingTokens = false
            tv.hasProtectedInlineResponseDivider = false
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

        /// Strip in-progress AI response (divider + tokens) from storage.
        /// Called before any save-path read of tv.string to avoid persisting ephemeral content.
        private func stripUnacceptedAIResponse() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let str = ts.string
            guard let range = NoteChatInlineResponse.dividerRange(in: str) else {
                tv.hasProtectedInlineResponseDivider = false
                return
            }
            let nsRange = NSRange(range, in: str)
            let deleteRange = NSRange(location: nsRange.location, length: ts.length - nsRange.location)
            isFlushingTokens = true
            tv.setProgrammaticEditLocation(nsRange.location)
            ts.replaceCharacters(in: deleteRange, with: "")
            tv.didChangeText()
            isFlushingTokens = false
            tv.hasProtectedInlineResponseDivider = false
        }

        // MARK: - Dismantle

        func handleDismantle() {
            // Cancel pending tasks FIRST — prevents races where a debounced sync
            // fires mid-dismantle and writes to the binding during teardown.
            bindingSyncTask?.cancel()
            bindingSyncTask = nil
            scrollOverlayRefreshCoalescer.cancel()

            // Strip ephemeral content before any save reads.
            clearAllFolds()
            stripUnacceptedAIResponse()

            // DO NOT write to the @Binding here. During NSHostingView.deinit →
            // PlatformViewChild.destroy() → dismantleNSView, SwiftUI already holds
            // an exclusive access to the @State storage. Writing to the binding
            // triggers swift_beginAccess on the same StoredLocation → exclusivity
            // violation → SIGABRT. The binding sync is unnecessary anyway —
            // persistCurrentTextIfNeeded() writes directly to disk via onPageFlush.

            // Persist through the page flush callback (disk + BlockMirror + dirty flag).
            persistCurrentTextIfNeeded()
            tableAlignTask?.cancel()
            dataDetectionTask?.cancel()
            blockEditTranslator = nil
            transclusionManager?.removeAll()
            transclusionManager = nil
            renderedTableOverlayManager?.removeAll()
            renderedTableOverlayManager = nil
            blockRefAutocomplete?.dismiss()
            blockRefAutocomplete = nil
            if let obs = scrollObserver {
                NotificationCenter.default.removeObserver(obs)
                scrollObserver = nil
            }
            if let obs = scrollToOffsetObserver {
                NotificationCenter.default.removeObserver(obs)
                scrollToOffsetObserver = nil
            }
            if let obs = writingToolsObserver {
                NotificationCenter.default.removeObserver(obs)
                writingToolsObserver = nil
            }
            if let obs = replaceRangeObserver {
                NotificationCenter.default.removeObserver(obs)
                replaceRangeObserver = nil
            }
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

        func scheduleScrollOverlayRefresh() {
            scrollOverlayRefreshCoalescer.schedule { [weak self] in
                self?.transclusionManager?.refreshForScroll()
                self?.renderedTableOverlayManager?.refreshForScroll()
            }
        }

        private func persistCurrentTextIfNeeded() {
            guard !currentPageId.isEmpty, let tv = textView else { return }
            let text = tv.string
            guard text != lastPersistedText else { return }
            parent.onPageFlush?(currentPageId, text)
            lastPersistedText = text
        }

        private func focusEditorIfNeeded() {
            guard parent.isFocused, let tv = textView else { return }
            guard tv.window?.firstResponder !== tv else { return }
            tv.window?.makeFirstResponder(tv)
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

            // Clear all folds on any edit — folds are purely a reading aid
            clearAllFolds()

            // ── SAVE-CRITICAL ──────────────────────────────────
            let newText = tv.string
            hasPendingBindingSync = true
            debouncedBindingSync(newText)

            // ── NON-CRITICAL ───────────────────────────────────

            // Notify template overlay that user started typing (short docs only).
            if tv.textStorage?.length ?? 0 <= 10 {
                NotificationCenter.default.post(
                    name: .init("ProseEditorUserDidType"),
                    object: nil,
                    userInfo: ["pageId": currentPageId]
                )
            }

            // Auto-close [[ → [[|]]
            if !isInsertingBrackets {
                let str = tv.string as NSString
                let cursorLoc = tv.selectedRange().location
                if cursorLoc != NSNotFound, cursorLoc >= 2, cursorLoc <= str.length,
                   str.substring(with: NSRange(location: cursorLoc - 2, length: 2)) == "[["
                {
                    let remaining = str.length - cursorLoc
                    let hasClosing = remaining >= 2
                        && str.substring(with: NSRange(location: cursorLoc, length: 2)) == "]]"
                    if !hasClosing {
                        isInsertingBrackets = true
                        tv.insertText("]]", replacementRange: NSRange(location: cursorLoc, length: 0))
                        tv.setSelectedRange(NSRange(location: cursorLoc, length: 0))
                        isInsertingBrackets = false
                    }
                }
            }

            // BTK: translate edit into block ops
            if let translator = blockEditTranslator,
               let storage = tv.textStorage {
                let editedRange = storage.editedRange
                if editedRange.location != NSNotFound,
                   editedRange.location + editedRange.length <= storage.length {
                    let changeInLength = storage.changeInLength
                    let oldLength = editedRange.length - changeInLength
                    let newText = (storage.string as NSString).substring(with: editedRange)
                    translator.translateEdit(offset: editedRange.location, oldLength: oldLength, newText: newText)
                }
            }

            // Block ref autocomplete trigger
            blockRefAutocomplete?.checkTrigger()

            // Refresh transclusion overlays
            transclusionManager?.refreshAfterTextChange()
            renderedTableOverlayManager?.refreshAfterTextChange()

            scheduleTableAlignment(tv)
            scheduleDataDetection(newText)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? ProseTextView2 else { return }
            if tv.isFocusMode {
                tv.applyFocusDimming()
                if let scrollView = tv.enclosingScrollView {
                    let insertionRect = tv.firstRect(forCharacterRange: tv.selectedRange(), actualRange: nil)
                    let localRect = tv.convert(insertionRect, from: nil)
                    let visibleHeight = scrollView.contentView.bounds.height
                    var scrollPoint = localRect.origin
                    scrollPoint.y -= visibleHeight / 2
                    scrollPoint.y = max(0, scrollPoint.y)
                    tv.scroll(scrollPoint)
                }
            }
        }

        // MARK: - Command Dispatch (Tab, Enter, etc.)

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let str = textView.string as NSString
            let cursorLoc = textView.selectedRange().location

            // Table-aware navigation when cursor is on a table line
            if cursorLoc <= str.length {
                let lineRange = str.lineRange(for: NSRange(location: min(cursorLoc, max(0, str.length - 1)), length: 0))
                let line = str.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let isTableLine = line.hasPrefix("|") && line.hasSuffix("|") && line.count > 1

                if isTableLine {
                    if commandSelector == #selector(NSResponder.insertTab(_:)) {
                        return moveToTableCell(textView: textView, forward: true)
                    }
                    if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                        return moveToTableCell(textView: textView, forward: false)
                    }
                    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                        return MarkdownEditorCommands.handleTableNewline(in: textView)
                    }
                }
            }

            // Tab/Shift-Tab: indent/outdent for outlining
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return indentLines(textView: textView, indent: true)
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return indentLines(textView: textView, indent: false)
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return MarkdownEditorCommands.handleContinuationNewline(in: textView)
            }
            return false
        }

        // MARK: - Indent / Outdent

        private func indentLines(textView: NSTextView, indent: Bool) -> Bool {
            let str = textView.string as NSString
            let sel = textView.selectedRange()
            let lineRange = str.lineRange(for: sel)
            let linesStr = str.substring(with: lineRange)
            let lines = linesStr.components(separatedBy: "\n")

            var result: [String] = []
            for (i, line) in lines.enumerated() {
                if i == lines.count - 1 && line.isEmpty {
                    result.append(line)
                    continue
                }
                if indent {
                    result.append("  " + line)
                } else {
                    if line.hasPrefix("\t") {
                        result.append(String(line.dropFirst(1)))
                    } else if line.hasPrefix("  ") {
                        result.append(String(line.dropFirst(2)))
                    } else if line.hasPrefix(" ") {
                        result.append(String(line.dropFirst(1)))
                    } else {
                        result.append(line)
                    }
                }
            }

            let newText = result.joined(separator: "\n")
            if textView.shouldChangeText(in: lineRange, replacementString: newText) {
                textView.textStorage?.replaceCharacters(in: lineRange, with: newText)
                textView.didChangeText()
                let delta = newText.utf16.count - lineRange.length
                let newSelLoc = max(lineRange.location, sel.location + (indent ? 2 : -2))
                let newSelLen = max(0, sel.length + delta - (indent ? 2 : min(2, -delta)))
                let safeLoc = min(newSelLoc, (textView.string as NSString).length)
                let safeLen = min(newSelLen, (textView.string as NSString).length - safeLoc)
                textView.setSelectedRange(NSRange(location: safeLoc, length: safeLen))
            }
            return true
        }

        // MARK: - Table Cell Navigation

        private func moveToTableCell(textView: NSTextView, forward: Bool) -> Bool {
            let str = textView.string as NSString
            let cursorLoc = textView.selectedRange().location
            let lineRange = str.lineRange(for: NSRange(location: min(cursorLoc, max(0, str.length - 1)), length: 0))
            let lineStr = str.substring(with: lineRange)
            let trimmed = lineStr.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return false }

            let lineStart = lineRange.location
            var pipePositions: [Int] = []
            for (offset, ch) in lineStr.utf16.enumerated() where ch == 0x7C {
                pipePositions.append(lineStart + offset)
            }
            guard pipePositions.count >= 2 else { return false }

            if forward {
                if let nextPipe = pipePositions.first(where: { $0 > cursorLoc }) {
                    if nextPipe == pipePositions.last {
                        // Wrap to next row
                        let nextRowStart = NSMaxRange(lineRange)
                        if nextRowStart < str.length {
                            let nextLineRange = str.lineRange(for: NSRange(location: nextRowStart, length: 0))
                            let nextLine = str.substring(with: nextLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                            if nextLine.hasPrefix("|") && nextLine.hasSuffix("|") {
                                let isSep = nextLine.dropFirst().dropLast()
                                    .split(separator: "|", omittingEmptySubsequences: false)
                                    .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
                                if isSep {
                                    let afterSepStart = NSMaxRange(nextLineRange)
                                    if afterSepStart < str.length {
                                        let afterSepRange = str.lineRange(for: NSRange(location: afterSepStart, length: 0))
                                        let afterSepLine = str.substring(with: afterSepRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                        if afterSepLine.hasPrefix("|") {
                                            let pos = afterSepRange.location + 2
                                            textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                                            return true
                                        }
                                    }
                                } else {
                                    let pos = nextLineRange.location + 2
                                    textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                                    return true
                                }
                            }
                        }
                        return true
                    }
                    let pos = nextPipe + 2
                    textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                    return true
                }
            } else {
                if let prevPipe = pipePositions.last(where: { $0 < cursorLoc }) {
                    if prevPipe == pipePositions.first {
                        // Wrap to previous row
                        if lineRange.location > 0 {
                            let prevLineEnd = lineRange.location - 1
                            let prevLineRange = str.lineRange(for: NSRange(location: prevLineEnd, length: 0))
                            let prevLine = str.substring(with: prevLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                            if prevLine.hasPrefix("|") && prevLine.hasSuffix("|") {
                                let isSep = prevLine.dropFirst().dropLast()
                                    .split(separator: "|", omittingEmptySubsequences: false)
                                    .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
                                if isSep && prevLineRange.location > 0 {
                                    let beforeSepEnd = prevLineRange.location - 1
                                    let beforeSepRange = str.lineRange(for: NSRange(location: beforeSepEnd, length: 0))
                                    let beforeSepLine = str.substring(with: beforeSepRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if beforeSepLine.hasPrefix("|") {
                                        var pipes: [Int] = []
                                        let bsStr = str.substring(with: beforeSepRange)
                                        for (offset, ch) in bsStr.utf16.enumerated() where ch == 0x7C {
                                            pipes.append(beforeSepRange.location + offset)
                                        }
                                        if pipes.count >= 2 {
                                            let pos = pipes[pipes.count - 2] + 2
                                            textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                                            return true
                                        }
                                    }
                                }
                                if !isSep {
                                    var pipes: [Int] = []
                                    let plStr = str.substring(with: prevLineRange)
                                    for (offset, ch) in plStr.utf16.enumerated() where ch == 0x7C {
                                        pipes.append(prevLineRange.location + offset)
                                    }
                                    if pipes.count >= 2 {
                                        let pos = pipes[pipes.count - 2] + 2
                                        textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                                        return true
                                    }
                                }
                            }
                        }
                        return true
                    }
                    if let twoPipesBack = pipePositions.last(where: { $0 < prevPipe }) {
                        let pos = twoPipesBack + 2
                        textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                        return true
                    }
                }
            }
            return true
        }

        // MARK: - Table Auto-Alignment (500ms debounce)

        private func scheduleTableAlignment(_ tv: NSTextView) {
            let str = tv.string as NSString
            let cursorLoc = tv.selectedRange().location
            guard cursorLoc > 0, cursorLoc <= str.length else { return }
            let lineRange = str.lineRange(for: NSRange(location: min(cursorLoc, str.length - 1), length: 0))
            let line = str.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("|") && line.hasSuffix("|") else {
                tableAlignTask?.cancel()
                tableAlignTask = nil
                return
            }
            tableAlignTask?.cancel()
            tableAlignTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                _ = MarkdownEditorCommands.realignTable(in: tv)
            }
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

        // MARK: - Transclusion Edit

        /// Handle edits from an EditableTransclusionView overlay.
        /// Updates the source SDBlock in SwiftData and syncs to BTK.
        func handleTransclusionEdit(blockId: String, newContent: String) {
            guard let mc = parent.modelContext else { return }

            let descriptor = FetchDescriptor<SDBlock>(
                predicate: #Predicate<SDBlock> { $0.id == blockId }
            )
            guard let block = try? mc.fetch(descriptor).first else { return }

            // Rewrite the source page's body file on disk.
            // The app's canonical note body lives in NoteFileStorage (page.loadBody / saveBody).
            // SDBlock.content alone is not read by vault export, search, or reopen.
            let sourcePageId = block.pageId

            // Flush any open editor for the source page so disk is current.
            // Synchronous — when this returns, loadBody() reflects live edits.
            NoteFileStorage.requestFlush(pageId: sourcePageId)

            let pageDesc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == sourcePageId }
            )
            if let page = try? mc.fetch(pageDesc).first {
                let pageBody = page.loadBody()
                if BlockMirror.parsedBlock(in: pageBody, for: block) == nil {
                    BlockMirror.sync(pageId: sourcePageId, body: pageBody, modelContext: mc)
                }

                guard let refreshedBlock = try? mc.fetch(descriptor).first,
                      let newBody = BlockMirror.rewrittenBody(
                          body: pageBody,
                          block: refreshedBlock,
                          newContent: newContent
                      ) else { return }

                page.saveBody(newBody)
                BlockMirror.sync(pageId: sourcePageId, body: newBody, modelContext: mc)
                if let syncedBlock = try? mc.fetch(descriptor).first {
                    syncedBlock.updatedAt = .now
                }
                transclusionManager?.invalidateResolvedBlock(blockId)
                page.needsVaultSync = true
                page.updatedAt = .now

                // Notify open editors for the source page so they reload from disk.
                NoteFileStorage.notifyBodyChanged(pageId: sourcePageId)
            }
            try? mc.save()

            if let engine = parent.graphState?.engineHandle {
                let updated = BlockEditTranslator.updateBlock(
                    blockId: blockId,
                    pageId: block.pageId,
                    newContent: newContent,
                    engine: engine
                )
                if !updated {
                    parent.graphState?.needsRefresh = true
                }
            } else {
                parent.graphState?.needsRefresh = true
            }
        }

        // MARK: - Heading Fold (Non-Destructive via shouldEnumerate)
        // Fold state lives in Rust (markdown_set_fold/markdown_is_folded).
        // MarkdownContentStorage.hiddenLines drives shouldEnumerate to skip folded paragraphs.
        // No storage rewriting — text is never modified by folds.

        func toggleFold(headingOffset: Int) {
            guard let tv = textView else { return }
            let delegate = tv.markdownDelegate

            let line = delegate.lineIndex(at: headingOffset)
            let isFolded = markdown_is_folded(UInt32(line))
            markdown_set_fold(UInt32(line), !isFolded)

            delegate.recomputeHiddenLines(documentText: tv.string)
            forceContentReEnumeration(tv)
        }

        func clearAllFolds() {
            guard let tv = textView else {
                markdown_clear_all_folds()
                return
            }
            markdown_clear_all_folds()
            tv.markdownDelegate.recomputeHiddenLines(documentText: tv.string)
            forceContentReEnumeration(tv)
        }

        /// Force the content manager to re-enumerate all elements (triggers shouldEnumerate).
        /// An empty performEditingTransaction is not reliable — recordEditAction tells the
        /// content manager that the content range actually changed, forcing re-enumeration.
        private func forceContentReEnumeration(_ tv: ProseTextView2) {
            guard let contentStorage = tv.textLayoutManager?.textContentManager
                    as? NSTextContentStorage else { return }
            let docRange = contentStorage.documentRange
            contentStorage.performEditingTransaction {
                contentStorage.recordEditAction(in: docRange, newTextRange: docRange)
            }
            tv.textLayoutManager?.ensureLayout(for: docRange)
            tv.needsDisplay = true
        }

        // MARK: - Data Detection (1s debounce)

        private func scheduleDataDetection(_ text: String) {
            dataDetectionTask?.cancel()
            dataDetectionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                let items = await DataDetectionService.detectAsync(in: text)
                guard !Task.isCancelled else { return }
                guard let tv = self.textView, let storage = tv.textStorage else { return }
                guard storage.string == text else { return }
                let fullRange = NSRange(location: 0, length: storage.length)
                storage.enumerateAttribute(DataDetectionService.detectedDataKey, in: fullRange) { val, range, _ in
                    guard val != nil else { return }
                    storage.removeAttribute(DataDetectionService.detectedDataKey, range: range)
                    storage.removeAttribute(.underlineStyle, range: range)
                    storage.removeAttribute(.underlineColor, range: range)
                }
                let isDark = self.parent.theme.isDark
                DataDetectionService.styleDetectedRanges(in: storage, items: items, isDark: isDark)
            }
        }

        // MARK: - Binding Sync (300ms debounce)
        // Coalesces rapid keystrokes so SwiftUI @Binding updates at most ~3×/second.
        // Prevents per-keystroke view tree re-evaluation.

        func debouncedBindingSync(_ newText: String) {
            bindingSyncTask?.cancel()
            bindingSyncTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { return }
                guard !self.isFlushingTokens else { return }
                self.syncBinding(to: newText)
                self.bindingSyncTask = nil
            }
        }

        /// Flush binding immediately — called by accept/discard to persist AI changes.
        func flushBindingSync(force: Bool = false) {
            bindingSyncTask?.cancel()
            bindingSyncTask = nil
            guard let tv = textView else { return }
            let text = tv.string
            guard force || hasPendingBindingSync || text != lastSyncedText else { return }
            syncBinding(to: text)
        }

        private func syncBinding(to text: String) {
            textBinding.wrappedValue = text
            lastSyncedText = text
            hasPendingBindingSync = false
        }

    }
}
