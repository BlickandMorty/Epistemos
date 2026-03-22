import AppKit
import SwiftData
import SwiftUI

// MARK: - ProseEditorRepresentable
// NSViewRepresentable wrapping ClickableTextView inside its own NSScrollView.
//
// Architecture:
// - ONE persistent NSTextView for the entire notes lifetime.
// - MarkdownTextStorage instances are swapped per page via PageStoragePool.
//   Tab switches detach the old storage and attach the new one — ~5ms, zero teardown.
// - NSScrollView handles all scrolling natively — NOT a SwiftUI ScrollView.
//   This eliminates the SwiftUI <-> AppKit layout feedback loop that caused 100% CPU:
//   bare NSTextView + SwiftUI ScrollView required intrinsicContentSize -> ensureLayout()
//   -> O(document) per keystroke/resize. With NSScrollView, NSTextView manages its own
//   height and scrolling entirely within AppKit. SwiftUI never queries text height.
// - Text stack built manually so MarkdownTextStorage is the original storage,
//   preserving native undo manager wiring (Cmd+Z / Cmd+Shift+Z work natively).
// - Writing Tools enabled (.default) — full rewrite/summarize/key points support.
// - Obsidian-style centering: textContainerInset adjusts dynamically to center a
//   720px readable column as the window resizes.
//
// Pitfall guards:
// - #3: All text processing disabled (spell check, grammar, link detection).
// - #4: Focus via window.makeFirstResponder, not @FocusState.
// - #6: updateNSView guards ALL work with Coordinator cache.

struct ProseEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    let pageId: String
    /// Direct page body — always current, not delayed by @State.
    /// Used for page swap and initial load so the editor never shows stale content.
    let pageBody: String
    let isFocused: Bool
    let theme: EpistemosTheme
    let isEditable: Bool
    let isFocusMode: Bool
    var modelContext: ModelContext?

    /// Called when user clicks a [[wikilink]] in the editor.
    var onWikilinkClick: ((String) -> Void)?

    /// Called when user clicks a ((block-ref)) in the editor.
    var onBlockRefClick: ((String) -> Void)?

    /// Per-note AI chat state for inline response streaming.
    var noteChatState: NoteChatState?

    /// Called during page swap — flush the old page's text to SwiftData.
    /// Args: (oldPageId, currentText). Coordinator calls this so ALL page-swap
    /// logic lives in one place (updateNSView) instead of being split across
    /// updateNSView + SwiftUI onChange.
    var onPageFlush: ((String, String) -> Void)?

    /// Graph state for BTK (Block Transaction Kernel) access to the Rust engine.
    var graphState: GraphState?

    /// Max readable content width (Obsidian-style centered column).
    private static let maxReadableWidth: CGFloat = 720
    /// Minimum horizontal padding even at narrow widths.
    private static let minHorizontalInset: CGFloat = 60
    /// Vertical breathing room inside the text container.
    /// Vertical breathing room inside the text container.
    static let verticalInset: CGFloat = 40

    static func horizontalInset(for availableWidth: CGFloat, markdown: String) -> CGFloat {
        let readableWidth = NoteDualPreviewLayout.editorReadableWidth(
            for: markdown,
            defaultWidth: maxReadableWidth
        )
        return max(minHorizontalInset, (availableWidth - readableWidth) / 2)
    }

    static func typingAttributes(for theme: EpistemosTheme) -> [NSAttributedString.Key: Any] {
        let paragraph =
            (MarkdownTextStorage.bodyParagraphStyle().mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        return [
            .font: NSFont.systemFont(ofSize: MarkdownTextStorage.noteBaseFontSize),
            .foregroundColor: NSColor(theme.foreground),
            .paragraphStyle: paragraph,
        ]
    }

    static func matchesNotificationPageId(_ notificationPageId: String?, coordinatorPageId: String?) -> Bool {
        guard let notificationPageId, !notificationPageId.isEmpty,
              let coordinatorPageId, !coordinatorPageId.isEmpty else {
            return false
        }
        return notificationPageId == coordinatorPageId
    }

    static func applyEditorAppearance(to textView: NSTextView, theme: EpistemosTheme) {
        let typingAttributes = typingAttributes(for: theme)
        let foreground = NSColor(theme.foreground)
        textView.textColor = foreground
        textView.insertionPointColor = foreground
        textView.defaultParagraphStyle = typingAttributes[.paragraphStyle] as? NSParagraphStyle
        textView.typingAttributes = typingAttributes
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // Build text stack manually so MarkdownTextStorage is the original storage.
        // This preserves NSTextView's native undo manager wiring.
        let storage = MarkdownTextStorage()
        storage.isDark = theme.isDark
        storage.theme = theme
        storage.usesRenderedTableOverlays = false

        let layoutManager = NSLayoutManager()
        // Only lay out visible text — skip everything below the fold.
        // Remaining layout happens in idle time (backgroundLayoutEnabled).
        // Without these, TextKit lays out the ENTIRE document synchronously on load.
        layoutManager.allowsNonContiguousLayout = true
        layoutManager.backgroundLayoutEnabled = true
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let tv = ClickableTextView(frame: .zero, textContainer: container)

        // GPU compositing — give the text view its own CALayer so scroll
        // compositing moves a cached bitmap on GPU instead of calling draw()
        // on every frame. Default policy (.duringViewResize) is used — it's
        // well-tested with NSTextView and lets scroll reveal new content correctly.
        tv.wantsLayer = true

        // Appearance
        tv.isRichText = false
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.usesFontPanel = false
        tv.usesRuler = false
        tv.importsGraphics = false
        tv.drawsBackground = false
        tv.backgroundColor = .clear

        // Initial insets — will be recalculated by frame observer for centering.
        tv.textContainerInset = NSSize(width: Self.minHorizontalInset, height: Self.verticalInset)
        tv.textContainer?.lineFragmentPadding = 0
        Self.applyEditorAppearance(to: tv, theme: theme)

        // Find & Replace — NSTextView's built-in NSTextFinder.
        // usesFindBar embeds it in the scroll view (Cmd+F).
        // Incremental search highlights all matches as you type.
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true

        // Disable smart text features (Pitfall #3 — prevents scroll lag)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        // Prevent NSTextView from overriding our custom wikilink styling with system link blue
        tv.linkTextAttributes = [:]

        // Writing Tools — competitive advantage: only native apps get full integration
        tv.writingToolsBehavior = NSWritingToolsBehavior.default

        // NSTextView inside NSScrollView: standard AppKit pattern.
        // The text view grows vertically as text is added; the scroll view clips and scrolls.
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Create NSScrollView wrapper
        let scrollView = NSScrollView()
        scrollView.documentView = tv
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Wire delegate and coordinator
        tv.delegate = context.coordinator
        tv.layoutManager?.delegate = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.storage = storage
        tv.usesRenderedTableOverlays = false

        // Transclusion overlays — editable inline block-ref content
        let transclusionMgr = TransclusionOverlayManager(textView: tv)
        if let mc = modelContext {
            transclusionMgr.configure(modelContext: mc)
        }
        transclusionMgr.onBlockEdit = { [weak context = context.coordinator] blockId, newContent in
            context?.handleTransclusionEdit(blockId: blockId, newContent: newContent)
        }
        context.coordinator.transclusionManager = transclusionMgr

        // Block ref autocomplete — triggered by typing ((
        if let mc = modelContext {
            let autocomplete = BlockRefAutocomplete()
            autocomplete.configure(textView: tv, modelContext: mc)
            context.coordinator.blockRefAutocomplete = autocomplete
        }


        // Wire wikilink + block ref handlers and page ID for scoped notifications
        let coord = context.coordinator
        tv.pageId = pageId
        tv.onFoldToggle = { [weak coord] headingOffset in
            coord?.toggleFold(headingOffset: headingOffset)
        }
        tv.onOpenInGraph = { pageId in
            HologramController.shared.revealPage(pageId)
        }

        // Obsidian-style centering: observe clip view frame changes to dynamically
        // adjust textContainerInset, centering a 720px readable column.
        scrollView.contentView.postsFrameChangedNotifications = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        coord.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak tv] _ in
            guard let tv else { return }
            MainActor.assumeIsolated {
                Self.updateCenteringInsets(for: tv)
                context.coordinator.renderedTableOverlayManager?.refresh()
            }
        }

        // Scroll observer — throttled to ~5 Hz (every 200ms) to avoid
        // per-frame overhead. Scroll position is saved to pool on page switch
        // anyway, so continuous tracking isn't needed.
        coord.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak tv, weak coord] _ in
            guard let tv, let coord else { return }
            MainActor.assumeIsolated {
                guard let pageId = coord.lastPageId, !pageId.isEmpty else { return }
                let now = CACurrentMediaTime()
                guard now - coord.lastScrollSaveTime > 0.2 else { return }
                coord.lastScrollSaveTime = now
                let scrollY = tv.enclosingScrollView?.contentView.bounds.origin.y ?? 0
                let selection = tv.selectedRange()
                PageStoragePool.shared.saveState(
                    pageId: pageId, scrollY: scrollY, selection: selection
                )
                // Reposition transclusion overlays on scroll
                coord.transclusionManager?.refreshForScroll()
                coord.renderedTableOverlayManager?.refreshForScroll()
            }
        }

        // Scroll-to-offset observer for TOC section navigator.
        coord.scrollToOffsetObserver = NotificationCenter.default.addObserver(
            forName: ClickableTextView.scrollToOffsetNotification,
            object: nil,
            queue: .main
        ) { [weak tv, weak coord] notification in
            guard let offset = notification.userInfo?["charOffset"] as? Int,
                  let pid = notification.userInfo?["pageId"] as? String,
                  let tv,
                  let coord else { return }
            MainActor.assumeIsolated {
                guard Self.matchesNotificationPageId(pid, coordinatorPageId: coord.lastPageId) else { return }
                let safeOffset = min(offset, (tv.string as NSString).length)
                let range = NSRange(location: safeOffset, length: 0)
                tv.scrollRangeToVisible(range)
                tv.setSelectedRange(range)
                let lineRange = (tv.string as NSString).lineRange(for: range)
                tv.showFindIndicator(for: lineRange)
            }
        }
        coord.writingToolsObserver = NotificationCenter.default.addObserver(
            forName: WritingToolsBridge.showNotification,
            object: nil,
            queue: .main
        ) { [weak tv, weak coord] note in
            guard let tv,
                  let pid = note.userInfo?["pageId"] as? String,
                  let coord else { return }
            MainActor.assumeIsolated {
                guard Self.matchesNotificationPageId(pid, coordinatorPageId: coord.lastPageId) else { return }
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
                      pid == coord.lastPageId,
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

        // Set lastPageId to nil so updateNSView will perform the initial page swap
        coord.lastPageId = nil

        // Apply initial centering after content loads
        DispatchQueue.main.async {
            Self.updateCenteringInsets(for: tv)
            context.coordinator.renderedTableOverlayManager?.refresh()
        }

        return scrollView
    }

    // MARK: - Dismantle (Save State to Pool + Disk)

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.removeNotificationObservers()
        guard let tv = scrollView.documentView as? ClickableTextView,
              let pageId = coordinator.lastPageId, !pageId.isEmpty
        else { return }

        coordinator.renderedTableOverlayManager?.removeAll()
        let scrollY = scrollView.contentView.bounds.origin.y
        let selection = tv.selectedRange()

        PageStoragePool.shared.saveState(
            pageId: pageId, scrollY: scrollY, selection: selection
        )
        PageStoragePool.shared.saveToDisk(pageId: pageId)
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? ClickableTextView else { return }
        let coord = context.coordinator

        // Keep Coordinator's parent in sync so its @Binding stays connected to
        // the current @State. Without this, flushBindingSync writes to a stale binding.
        coord.parent = self

        // === PAGE SWAP via storage swap ===
        if coord.lastPageId != pageId {
            let interval = Log.notesPerf.beginInterval("pageSwap")
            defer { Log.notesPerf.endInterval("pageSwap", interval) }
            coord.isSwappingPage = true

            // Force binding sync before page swap so debouncedSave has current text
            coord.flushBindingSync()

            // Save outgoing page — text to SwiftData + visual state to pool
            if let oldId = coord.lastPageId, !oldId.isEmpty {
                // Cancel any pending direct save — we're flushing now
                coord.directSaveTask?.cancel()

                // Direct file write FIRST — guaranteed content preservation on page swap
                let swapContent = tv.string
                NoteFileStorage.writeBody(pageId: oldId, content: swapContent)

                // Flush text to SwiftData via callback (single source of truth for flush)
                coord.parent.onPageFlush?(oldId, tv.string)

                let scrollY = scrollView.contentView.bounds.origin.y
                let selection = tv.selectedRange()
                PageStoragePool.shared.saveState(
                    pageId: oldId, scrollY: scrollY, selection: selection
                )
                PageStoragePool.shared.saveToDisk(pageId: oldId)
            }

            if !pageId.isEmpty {
                guard let layoutManager = tv.layoutManager else { return }

                // Get or create storage for incoming page
                let slot = PageStoragePool.shared.getOrCreate(
                    pageId: pageId,
                    bodyText: pageBody,
                    theme: theme
                )

                // Swap storage — detach old, attach new
                coord.storage?.removeLayoutManager(layoutManager)
                slot.storage.addLayoutManager(layoutManager)
                slot.storage.usesRenderedTableOverlays = false
                coord.storage = slot.storage

                // Swap per-page undo manager
                tv.pageUndoManager = slot.undoManager
                tv.needsDisplay = true

                // Restore scroll + selection SYNCHRONOUSLY (no async flash)
                // NSLayoutManager lays out text lazily as it scrolls into view —
                // no manual ensureLayout needed. This is how Apple Notes works.
                let safeSelLoc = min(slot.selectionRange.location, slot.storage.length)
                let safeSelLen = min(slot.selectionRange.length, slot.storage.length - safeSelLoc)
                tv.setSelectedRange(NSRange(location: safeSelLoc, length: safeSelLen))
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: slot.scrollY))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                Self.applyEditorAppearance(to: tv, theme: theme)
                Self.updateCenteringInsets(for: tv)
                coord.lastAvailableWidth = scrollView.contentSize.width
            } else {
                // No page active — clear content
                if let storage = coord.storage {
                    storage.skipAllStyling = true
                    let fullRange = NSRange(location: 0, length: storage.length)
                    storage.replaceCharacters(in: fullRange, with: "")
                    storage.skipAllStyling = false
                }
            }

            coord.lastPageId = pageId

            // Clear transclusion overlays from previous page
            coord.transclusionManager?.removeAll()
            coord.renderedTableOverlayManager?.removeAll()
            coord.blockRefAutocomplete?.dismiss()

            // BTK: Initialize block edit translator for real-time block tracking.
            if let graphState = graphState {
                coord.blockEditTranslator = BlockEditTranslator(
                    pageId: pageId, graphState: graphState
                )
                if let mc = modelContext {
                    let descriptor = FetchDescriptor<SDBlock>(
                        predicate: #Predicate<SDBlock> { $0.pageId == pageId },
                        sortBy: [SortDescriptor(\.order)]
                    )
                    let existingBlocks = (try? mc.fetch(descriptor)) ?? []
                    coord.blockEditTranslator?.initIfNeeded(existingBlocks: existingBlocks)
                }
            } else {
                coord.blockEditTranslator = nil
            }

            if isFocused {
                DispatchQueue.main.async {
                    tv.window?.makeFirstResponder(tv)
                }
            }
        }

        // === GUARD ALL WORK WITH COORDINATOR CACHE (Pitfall #6) ===

        // Theme change — restyle when the actual theme changes, not just dark/light mode.
        // Progressive restyle: line-level styles synchronous (headings/lists/quotes —
        // correct colors immediately), inline styles deferred one frame (7 regex passes).
        // Prevents multi-second freeze on theme toggle with large documents.
        if coord.lastTheme != theme {
            coord.lastTheme = theme
            coord.storage?.isDark = theme.isDark
            coord.storage?.theme = theme
            coord.storage?.usesRenderedTableOverlays = false
            Self.applyEditorAppearance(to: tv, theme: theme)
            Self.progressiveRestyle(coord.storage)
            PageStoragePool.shared.invalidateExcept(activePageId: pageId)
            coord.renderedTableOverlayManager?.setTheme(theme)

        }

        // Editable state — react to lock/preview toggles
        if tv.isEditable != isEditable {
            tv.isEditable = isEditable
        }

        // Focus mode — sync from NotesUIState
        let wasFocus = tv.isFocusMode
        tv.isFocusMode = isFocusMode
        if wasFocus && !isFocusMode {
            tv.clearFocusDimming()
        } else if isFocusMode {
            tv.applyFocusDimming()
        }

        // Reset page swap flag BEFORE text sync so the sync can correct stale cache content.
        // onChange(of: page.id) sets bodyText = page.body, making text == pageBody.
        // Once that happens, the swap is complete and text sync should be active.
        if coord.isSwappingPage && (text == pageBody || pageBody.isEmpty) {
            coord.isSwappingPage = false
        }

        // Text sync — only if text changed externally (not from user typing)
        // Replace through storage so processEditing() styles inline (no flash).
        // Guard against IME composition — replacing during marked text destroys composing state.
        // Skip during page swap — @State bodyText still holds the OLD page's text
        // until onChange(of: page.id) fires and sets bodyText = page.body.
        // Without this guard, stale text would overwrite the new storage content.
        if !coord.isUserEditing, !coord.isSwappingPage,
            !coord.hasPendingBindingSync,
            let storage = coord.storage,
            tv.string != text, !tv.hasMarkedText(),
            !(text.isEmpty && storage.length > 0)
        {
            let sel = tv.selectedRange()
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: fullRange, with: text)
            let safeLoc = min(sel.location, tv.string.utf16.count)
            tv.setSelectedRange(NSRange(location: safeLoc, length: 0))
            Self.updateCenteringInsets(for: tv)
            coord.transclusionManager?.refreshAfterTextChange()
            coord.renderedTableOverlayManager?.refreshAfterTextChange()
        }

        // Focus management (Pitfall #4)
        if coord.lastIsFocused != isFocused {
            coord.lastIsFocused = isFocused
            if isFocused && tv.window?.firstResponder !== tv {
                DispatchQueue.main.async {
                    tv.window?.makeFirstResponder(tv)
                }
            }
        }

        // Update wikilink + block ref handler references + page ID for scoped notifications
        tv.pageId = pageId
        tv.onFoldToggle = { [weak coord] headingOffset in
            coord?.toggleFold(headingOffset: headingOffset)
        }

        // Wire Note Chat callbacks — only when the state reference changes.
        if let noteChat = noteChatState, coord.noteChatState !== noteChat {
            coord.noteChatState = noteChat
            noteChat.onStreamStart = { [weak coord] query in
                coord?.startNoteChatStream(query)
            }
            noteChat.onTokenFlush = { [weak coord] delta in
                coord?.appendNoteChatTokens(delta)
            }
            noteChat.onAccept = { [weak coord] in
                coord?.acceptNoteChatResponse()
            }
            noteChat.onDiscard = { [weak coord] in
                coord?.discardNoteChatResponse()
            }
            noteChat.noteBodyProvider = { [weak coord] in
                guard let coord, let storage = coord.storage else { return "" }
                return storage.mutableString as String
            }
            noteChat.onInsertAtCursor = { [weak coord] text in
                coord?.insertTextAtCursor(text)
            }
        }

        // Recalculate centering only when width actually changed
        let currentWidth = scrollView.contentSize.width
        if abs(coord.lastAvailableWidth - currentWidth) > 0.5 {
            coord.lastAvailableWidth = currentWidth
            Self.updateCenteringInsets(for: tv)
            coord.renderedTableOverlayManager?.refresh()
        }
    }

    // MARK: - Progressive Restyle
    // Splits restyle into two phases to avoid blocking the main thread on large documents:
    // Phase 1 (sync): base + line-level styles — headings, lists, quotes get correct colors.
    // Phase 2 (deferred): inline styles — bold, italic, code, links (7 regex passes).
    // Called from MainActor context so the deferred closure is MainActor-isolated.

    private static func progressiveRestyle(_ storage: MarkdownTextStorage?) {
        guard let storage else { return }
        storage.reapplyLineStyles()

        // Defer inline styles one frame — runs after the current layout pass
        let weakStorage = storage
        DispatchQueue.main.async {
            guard weakStorage.length > 0 else { return }
            let range = NSRange(location: 0, length: weakStorage.length)
            weakStorage.beginEditing()
            weakStorage.applyInlineStyles(fullRange: range)
            weakStorage.edited(.editedAttributes, range: range, changeInLength: 0)
            weakStorage.endEditing()
        }
    }

    // MARK: - Obsidian-Style Centering
    // Dynamically adjusts horizontal textContainerInset to center a readable column.
    // When the view is wider than maxReadableWidth + padding, symmetric insets center the text.
    // When narrow, falls back to minHorizontalInset (60pt) for comfortable reading.

    private static func updateCenteringInsets(for tv: NSTextView) {
        guard let scrollView = tv.enclosingScrollView else { return }
        let availableWidth = scrollView.contentSize.width
        let horizontalInset = horizontalInset(for: availableWidth, markdown: tv.string)
        let vInset = verticalInset

        let currentInset = tv.textContainerInset
        // Only update if inset actually changed (avoid layout churn)
        if abs(currentInset.width - horizontalInset) > 0.5
            || abs(currentInset.height - vInset) > 0.5
        {
            tv.textContainerInset = NSSize(width: horizontalInset, height: vInset)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate, NSLayoutManagerDelegate {
        var parent: ProseEditorRepresentable
        weak var textView: ClickableTextView?
        var storage: MarkdownTextStorage?
        var transclusionManager: TransclusionOverlayManager?
        var renderedTableOverlayManager: RenderedTableOverlayManager?

        var blockRefAutocomplete: BlockRefAutocomplete?

        /// Per-note AI chat state reference — wired in updateNSView.
        weak var noteChatState: NoteChatState?
        /// Suppresses textDidChange binding sync during programmatic token appends.
        var isFlushingTokens = false
        /// Debounce task for syncing NSTextStorage → SwiftUI @Binding.
        /// Text lives in NSTextStorage — binding only needed for debouncedSave and page swap.
        private var bindingSyncTask: Task<Void, Never>?
        /// True when NSTextView has edits not yet synced to the SwiftUI binding.
        /// Read by updateNSView to skip stale-text overwrites during the debounce window.
        private(set) var hasPendingBindingSync = false

        /// Debounce task for auto-aligning table columns after typing.
        private var tableAlignTask: Task<Void, Never>?

        // Cache guards (Pitfall #6) — skip work in updateNSView if nothing changed
        var lastIsFocused = false
        var lastTheme: EpistemosTheme?
        var lastAvailableWidth: CGFloat = -1
        var isUserEditing = false
        /// Suppresses `textDidChange` binding sync during programmatic content changes
        /// (page swap in `updateNSView`, initial load in `makeNSView`).
        /// Also gates the text sync guard so stale @State doesn't overwrite new content.
        var isSwappingPage = false

        // Page swap guard — detects page changes without .id() teardown
        var lastPageId: String?

        // Scroll save throttle (CACurrentMediaTime)
        var lastScrollSaveTime: Double = 0

        /// Direct file save — bypasses the SwiftUI binding chain entirely.
        /// Defense-in-depth: ensures content is persisted even if binding → onChange → debouncedSave fails.
        var directSaveTask: Task<Void, Never>?

        // Auto-close [[brackets]]
        private var isInsertingBrackets = false

        // Frame observer for Obsidian-style centering.
        // nonisolated(unsafe) because deinit is nonisolated and needs to remove it.
        // NSObjectProtocol is not Sendable, but we only touch this from MainActor + deinit.
        nonisolated(unsafe) var frameObserver: (any NSObjectProtocol)?

        // Scroll observer for continuous scroll position tracking.
        nonisolated(unsafe) var scrollObserver: (any NSObjectProtocol)?

        // Scroll-to-offset observer for TOC section navigator.
        nonisolated(unsafe) var scrollToOffsetObserver: (any NSObjectProtocol)?

        // Ask-bar bridge for native Apple Writing Tools.
        nonisolated(unsafe) var writingToolsObserver: (any NSObjectProtocol)?

        // External range replacement bridge (block properties, future editor mutations).
        nonisolated(unsafe) var replaceRangeObserver: (any NSObjectProtocol)?


        /// Block Transaction Kernel translator — tracks edits as block ops.
        var blockEditTranslator: BlockEditTranslator?

        // MARK: - Heading Fold State
        // Ephemeral visual fold — text storage replacement approach.
        // Folded content is replaced with "…\n" in storage and original text stored here.
        // Key = character offset of the heading line. Value = (original text, marker range).
        struct FoldInfo {
            let originalText: String
            var markerRange: NSRange  // range of the "…\n" in current storage
        }
        var foldedSections: [Int: FoldInfo] = [:]
        /// True while programmatically folding/unfolding — suppresses textDidChange.
        var isFolding = false

        /// Debounced data detection (dates, addresses, phones, URLs).
        private var dataDetectionTask: Task<Void, Never>?

        init(_ parent: ProseEditorRepresentable) {
            self.parent = parent
            self.lastTheme = parent.theme
            // lastPageId intentionally left nil — updateNSView will do the initial swap
        }

        deinit {
            removeNotificationObservers()
        }

        nonisolated func removeNotificationObservers() {
            if let observer = frameObserver {
                NotificationCenter.default.removeObserver(observer)
                frameObserver = nil
            }
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
                scrollObserver = nil
            }
            if let observer = scrollToOffsetObserver {
                NotificationCenter.default.removeObserver(observer)
                scrollToOffsetObserver = nil
            }
            if let observer = writingToolsObserver {
                NotificationCenter.default.removeObserver(observer)
                writingToolsObserver = nil
            }
            if let observer = replaceRangeObserver {
                NotificationCenter.default.removeObserver(observer)
                replaceRangeObserver = nil
            }
        }

        // MARK: - Native Link Click Handling

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

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }

            // Don't sync during IME composition — wait for committed text.
            guard !tv.hasMarkedText() else { return }

            // Suppress during programmatic content changes (page swap / load).
            guard !isSwappingPage else { return }

            // Suppress during AI token flushing.
            guard !isFlushingTokens else { return }

            // Suppress during programmatic fold/unfold operations.
            guard !isFolding else { return }

            // Clear all heading folds on any edit — folds are purely a reading aid.
            if !foldedSections.isEmpty {
                clearAllFolds()
            }

            // ═══════════════════════════════════════════════════════════
            // SAVE-CRITICAL: binding sync + direct file save FIRST.
            // Everything below this block is non-critical (bracket auto-close,
            // BTK, table alignment). A crash there must NOT prevent saving.
            // ═══════════════════════════════════════════════════════════

            // Debounced binding sync — NSTextStorage is always source of truth.
            hasPendingBindingSync = true
            bindingSyncTask?.cancel()
            bindingSyncTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, !Task.isCancelled else { return }
                self.flushBindingSync()
            }

            // Direct file save — bypasses the entire SwiftUI binding chain.
            directSaveTask?.cancel()
            let savePageId = parent.pageId
            let saveContent = tv.string
            directSaveTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard self != nil, !Task.isCancelled else { return }
                await NoteFileStorage.writeBodyAsync(pageId: savePageId, content: saveContent)
            }

            // ═══════════════════════════════════════════════════════════
            // NON-CRITICAL: UI niceties. A crash here won't lose data.
            // ═══════════════════════════════════════════════════════════

            // Notify template overlay that user started typing (short docs only).
            if tv.textStorage?.length ?? 0 <= 10 {
                NotificationCenter.default.post(
                    name: .init("ProseEditorUserDidType"),
                    object: nil,
                    userInfo: ["pageId": parent.pageId]
                )
            }

            // Auto-close [[ -> [[|]]
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
                        tv.insertText(
                            "]]", replacementRange: NSRange(location: cursorLoc, length: 0))
                        tv.setSelectedRange(NSRange(location: cursorLoc, length: 0))
                        isInsertingBrackets = false
                    }
                }
            }

            // Check for (( autocomplete trigger
            blockRefAutocomplete?.checkTrigger()

            // BTK: translate edit into block ops (translator non-nil iff BTK enabled)
            if let translator = blockEditTranslator,
               let storage = tv.textStorage {
                let editedRange = storage.editedRange
                // Guard: editedRange can be {NSNotFound, 0} after processEditing completes
                if editedRange.location != NSNotFound,
                   editedRange.location + editedRange.length <= storage.length {
                    let changeInLength = storage.changeInLength
                    let oldLength = editedRange.length - changeInLength
                    let newText = (storage.string as NSString).substring(with: editedRange)
                    translator.translateEdit(offset: editedRange.location, oldLength: oldLength, newText: newText)
                }
            }

            // Auto-align table columns (500ms debounce)
            scheduleTableAlignment(tv)


            // Refresh transclusion overlays
            transclusionManager?.refreshAfterTextChange()
            renderedTableOverlayManager?.refreshAfterTextChange()

            // Data detection (1s debounce — scans full document for dates, addresses, etc.)
            scheduleDataDetection(tv)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? ClickableTextView else { return }
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

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let str = textView.string as NSString
            let cursorLoc = textView.selectedRange().location

            // Check if cursor is on a table line for table-aware navigation
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

            // Tab/Shift-Tab: indent/outdent the current line(s) for outlining.
            // Pure text manipulation — BTK maps indentation to block hierarchy.
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

        /// Indent or outdent all lines in the selection range.
        /// Uses 2-space indent (matching BlockParser.measureIndent convention).
        private func indentLines(textView: NSTextView, indent: Bool) -> Bool {
            let str = textView.string as NSString
            let sel = textView.selectedRange()
            // Expand selection to full lines
            let lineRange = str.lineRange(for: sel)

            let linesStr = str.substring(with: lineRange)
            let lines = linesStr.components(separatedBy: "\n")

            var result: [String] = []
            for (i, line) in lines.enumerated() {
                // Last component after splitting is empty if text ends with \n — preserve it
                if i == lines.count - 1 && line.isEmpty {
                    result.append(line)
                    continue
                }
                if indent {
                    result.append("  " + line)
                } else {
                    // Remove up to 2 leading spaces or 1 tab
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
            // Use shouldChangeText + replaceCharacters for proper undo support
            if textView.shouldChangeText(in: lineRange, replacementString: newText) {
                textView.textStorage?.replaceCharacters(in: lineRange, with: newText)
                textView.didChangeText()

                // Restore selection: adjust to cover the same logical lines
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

        /// Move cursor to the next (forward=true) or previous (forward=false) table cell.
        /// Wraps across rows at table boundaries.
        private func moveToTableCell(textView: NSTextView, forward: Bool) -> Bool {
            let str = textView.string as NSString
            let cursorLoc = textView.selectedRange().location
            let lineRange = str.lineRange(for: NSRange(location: min(cursorLoc, max(0, str.length - 1)), length: 0))
            let lineStr = str.substring(with: lineRange)
            let trimmed = lineStr.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return false }

            // Find pipe positions within the line (absolute positions)
            let lineStart = lineRange.location
            var pipePositions: [Int] = []
            for (offset, ch) in lineStr.utf16.enumerated() where ch == 0x7C /* | */ {
                pipePositions.append(lineStart + offset)
            }
            guard pipePositions.count >= 2 else { return false }

            if forward {
                // Find the next pipe after cursor, position after pipe + space
                if let nextPipe = pipePositions.first(where: { $0 > cursorLoc }) {
                    // If it's the last pipe (end of row), wrap to next row
                    if nextPipe == pipePositions.last {
                        let nextRowStart = NSMaxRange(lineRange)
                        if nextRowStart < str.length {
                            let nextLineRange = str.lineRange(for: NSRange(location: nextRowStart, length: 0))
                            let nextLine = str.substring(with: nextLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                            if nextLine.hasPrefix("|") && nextLine.hasSuffix("|") {
                                // Skip separator rows
                                let isSep = nextLine.dropFirst().dropLast()
                                    .split(separator: "|", omittingEmptySubsequences: false)
                                    .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
                                if isSep {
                                    // Jump past separator to the row after
                                    let afterSepStart = NSMaxRange(nextLineRange)
                                    if afterSepStart < str.length {
                                        let afterSepRange = str.lineRange(for: NSRange(location: afterSepStart, length: 0))
                                        let afterSepLine = str.substring(with: afterSepRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                        if afterSepLine.hasPrefix("|") {
                                            // Position after first pipe + space
                                            let pos = afterSepRange.location + 2
                                            textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                                            return true
                                        }
                                    }
                                } else {
                                    // Position after first pipe + space
                                    let pos = nextLineRange.location + 2
                                    textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                                    return true
                                }
                            }
                        }
                        return true // at last cell of last row, do nothing
                    }
                    // Position after the pipe + space
                    let pos = nextPipe + 2
                    textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                    return true
                }
            } else {
                // Find the pipe before cursor, position after previous pipe + space
                if let prevPipe = pipePositions.last(where: { $0 < cursorLoc }) {
                    // If it's the first pipe (start of row), wrap to previous row
                    if prevPipe == pipePositions.first {
                        if lineRange.location > 0 {
                            let prevLineEnd = lineRange.location - 1
                            let prevLineRange = str.lineRange(for: NSRange(location: prevLineEnd, length: 0))
                            let prevLine = str.substring(with: prevLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                            if prevLine.hasPrefix("|") && prevLine.hasSuffix("|") {
                                // Skip separator rows
                                let isSep = prevLine.dropFirst().dropLast()
                                    .split(separator: "|", omittingEmptySubsequences: false)
                                    .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
                                if isSep && prevLineRange.location > 0 {
                                    let beforeSepEnd = prevLineRange.location - 1
                                    let beforeSepRange = str.lineRange(for: NSRange(location: beforeSepEnd, length: 0))
                                    let beforeSepLine = str.substring(with: beforeSepRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if beforeSepLine.hasPrefix("|") {
                                        // Position at last cell: before the last pipe
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
                                    // Position at last cell of previous row
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
                        return true // at first cell of first row, do nothing
                    }
                    // Find the pipe before prevPipe — position after it + space
                    if let twoPipesBack = pipePositions.last(where: { $0 < prevPipe }) {
                        let pos = twoPipesBack + 2
                        textView.setSelectedRange(NSRange(location: min(pos, str.length), length: 0))
                        return true
                    }
                }
            }
            return true
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
            let sourcePageId = block.pageId
            let pageDesc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == sourcePageId }
            )
            // Flush any open editor for the source page so disk is current.
            NoteFileStorage.requestFlush(pageId: sourcePageId)

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
                page.needsVaultSync = true
                page.updatedAt = .now
                NoteFileStorage.notifyBodyChanged(pageId: sourcePageId)
            }
            try? mc.save()

            if let engine = parent.graphState?.engineHandle {
                _ = BlockEditTranslator.updateBlock(
                    blockId: blockId,
                    pageId: sourcePageId,
                    newContent: newContent,
                    engine: engine
                )
            }
        }

        // MARK: - Binding Sync

        /// Force-sync NSTextStorage content to SwiftUI binding.
        /// Called after debounce timer, and immediately during page swap flush.
        func flushBindingSync() {
            guard hasPendingBindingSync, let tv = textView else { return }
            hasPendingBindingSync = false
            bindingSyncTask?.cancel()
            bindingSyncTask = nil
            isUserEditing = true
            parent.text = tv.string
            isUserEditing = false
        }

        // MARK: - Table Auto-Alignment

        /// Schedule table column alignment 500ms after the last keystroke on a table line.
        private func scheduleDataDetection(_ tv: NSTextView) {
            dataDetectionTask?.cancel()
            dataDetectionTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                guard let storage = tv.textStorage else { return }
                let text = storage.string
                let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let items = await DataDetectionService.detectAsync(in: text)
                guard !Task.isCancelled else { return }
                guard storage.string == text else { return }
                // Clear old detection attributes (only ranges that had them).
                let fullRange = NSRange(location: 0, length: storage.length)
                storage.enumerateAttribute(DataDetectionService.detectedDataKey, in: fullRange) { val, range, _ in
                    guard val != nil else { return }
                    storage.removeAttribute(DataDetectionService.detectedDataKey, range: range)
                    storage.removeAttribute(.underlineStyle, range: range)
                    storage.removeAttribute(.underlineColor, range: range)
                }
                DataDetectionService.styleDetectedRanges(in: storage, items: items, isDark: isDark)
            }
        }

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

        // MARK: - Note Chat (v2 — simplified inline response)

        /// Unique divider that won't collide with markdown horizontal rules (---).
        private static let aiDivider = "\n\n<!-- ai-response -->\n\n"

        /// Insert the AI divider at the end of storage when streaming starts.
        func startNoteChatStream(_ query: String) {
            guard let storage else { return }
            isFlushingTokens = true
            storage.replaceCharacters(in: NSRange(location: storage.length, length: 0), with: Self.aiDivider)
            isFlushingTokens = false
            textView?.scrollRangeToVisible(NSRange(location: storage.length, length: 0))
        }

        /// Append streaming tokens at the end of storage.
        func appendNoteChatTokens(_ delta: String) {
            guard let storage else { return }
            isFlushingTokens = true
            storage.replaceCharacters(in: NSRange(location: storage.length, length: 0), with: delta)
            isFlushingTokens = false
            textView?.scrollRangeToVisible(NSRange(location: storage.length, length: 0))
        }

        /// Accept: replace the AI divider with paragraph spacing, keep response text.
        /// Syncs binding so the accepted text persists via debouncedSave.
        func acceptNoteChatResponse() {
            guard let storage else { return }
            let str = storage.mutableString as String
            if let range = str.range(of: Self.aiDivider, options: .backwards) {
                let nsRange = NSRange(range, in: str)
                isFlushingTokens = true
                storage.replaceCharacters(in: nsRange, with: "\n\n")
                isFlushingTokens = false
            }
            flushBindingSync()
        }

        /// Discard: delete everything from the AI divider to end of storage.
        /// Syncs binding to restore the pre-chat note body.
        func discardNoteChatResponse() {
            guard let storage else { return }
            let str = storage.mutableString as String
            if let range = str.range(of: Self.aiDivider, options: .backwards) {
                let nsRange = NSRange(range, in: str)
                let deleteRange = NSRange(location: nsRange.location, length: storage.length - nsRange.location)
                isFlushingTokens = true
                storage.replaceCharacters(in: deleteRange, with: "")
                isFlushingTokens = false
            }
            flushBindingSync()
        }

        /// Insert text at the current cursor position (panel mode accept).
        func insertTextAtCursor(_ text: String) {
            guard let storage, let tv = textView else { return }
            let loc = tv.selectedRange().location
            let insertion = "\n\n" + text + "\n"
            isFlushingTokens = true
            if tv.shouldChangeText(in: NSRange(location: loc, length: 0), replacementString: insertion) {
                storage.replaceCharacters(in: NSRange(location: loc, length: 0), with: insertion)
                tv.didChangeText()
                tv.setSelectedRange(NSRange(location: loc + (insertion as NSString).length, length: 0))
            }
            isFlushingTokens = false
            flushBindingSync()
        }

        // MARK: - Heading Fold (Collapsible Sections)
        // Ephemeral visual fold — text storage is NEVER modified.
        // Uses setNotShownAttribute (hide glyphs) + shouldSetLineFragmentRect (collapse space).
        // All folds clear on any text edit.

        /// Toggle fold for a heading at the given character offset.
        func toggleFold(headingOffset: Int) {
            guard let tv = textView, let storage = storage else { return }
            let str = storage.string as NSString

            // Adjust heading offset for any prior folds that shifted positions
            if foldedSections[headingOffset] != nil {
                unfold(headingOffset: headingOffset)
            } else {
                let headingLineRange = str.lineRange(for: NSRange(location: headingOffset, length: 0))
                let headingLine = str.substring(with: headingLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let level = headingLevel(headingLine) else { return }

                // Content range: from end of heading line to next heading of equal/higher level
                let contentStart = NSMaxRange(headingLineRange)
                var contentEnd = str.length
                var cursor = contentStart
                while cursor < str.length {
                    let lineRange = str.lineRange(for: NSRange(location: cursor, length: 0))
                    let line = str.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if let nextLevel = headingLevel(line), nextLevel <= level {
                        contentEnd = lineRange.location
                        break
                    }
                    cursor = NSMaxRange(lineRange)
                    if cursor == lineRange.location { break }
                }

                guard contentEnd > contentStart else { return }
                let foldRange = NSRange(location: contentStart, length: contentEnd - contentStart)
                let originalText = str.substring(with: foldRange)

                // Replace folded content with marker in text storage
                isFolding = true
                let marker = "…\n"
                if tv.shouldChangeText(in: foldRange, replacementString: marker) {
                    storage.replaceCharacters(in: foldRange, with: marker)
                    tv.didChangeText()
                }
                let markerRange = NSRange(location: contentStart, length: (marker as NSString).length)
                // Style the marker
                storage.addAttributes([
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium)
                ], range: markerRange)
                foldedSections[headingOffset] = FoldInfo(originalText: originalText, markerRange: markerRange)
                isFolding = false
                tv.needsDisplay = true
            }
        }

        func unfold(headingOffset: Int) {
            guard let tv = textView, let storage = storage else { return }
            guard let info = foldedSections.removeValue(forKey: headingOffset) else { return }

            isFolding = true
            if tv.shouldChangeText(in: info.markerRange, replacementString: info.originalText) {
                storage.replaceCharacters(in: info.markerRange, with: info.originalText)
                tv.didChangeText()
            }
            isFolding = false
            tv.needsDisplay = true
        }

        func clearAllFolds() {
            guard let tv = textView, let storage = storage else {
                foldedSections.removeAll()
                return
            }
            // Unfold in reverse order of marker position to keep offsets valid
            let sorted = foldedSections.sorted { $0.value.markerRange.location > $1.value.markerRange.location }
            isFolding = true
            for (_, info) in sorted {
                if tv.shouldChangeText(in: info.markerRange, replacementString: info.originalText) {
                    storage.replaceCharacters(in: info.markerRange, with: info.originalText)
                    tv.didChangeText()
                }
            }
            foldedSections.removeAll()
            isFolding = false
            tv.needsDisplay = true
        }

        private func headingLevel(_ line: String) -> Int? {
            var count = 0
            for ch in line {
                if ch == "#" { count += 1 }
                else if ch == " " && count > 0 { return count <= 6 ? count : nil }
                else { return nil }
            }
            return nil
        }



    }
}
