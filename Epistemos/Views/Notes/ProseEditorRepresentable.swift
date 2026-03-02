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
    let isDark: Bool
    let isEditable: Bool
    var modelContext: ModelContext?

    /// Called when user clicks a [[wikilink]] in the editor.
    var onWikilinkClick: ((String) -> Void)?

    /// Called when user clicks a ((block-ref)) in the editor.
    var onBlockRefClick: ((String) -> Void)?

    /// Called during page swap — flush the old page's text to SwiftData.
    /// Args: (oldPageId, currentText). Coordinator calls this so ALL page-swap
    /// logic lives in one place (updateNSView) instead of being split across
    /// updateNSView + SwiftUI onChange.
    var onPageFlush: ((String, String) -> Void)?

    /// Max readable content width (Obsidian-style centered column).
    private static let maxReadableWidth: CGFloat = 720
    /// Minimum horizontal padding even at narrow widths.
    private static let minHorizontalInset: CGFloat = 60
    /// Vertical breathing room inside the text container.
    /// Pushes content down so the title has room to breathe.
    private static let verticalInset: CGFloat = 54

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // Build text stack manually so MarkdownTextStorage is the original storage.
        // This preserves NSTextView's native undo manager wiring.
        let storage = MarkdownTextStorage()
        storage.isDark = isDark

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
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        // Prevent the system from adding top insets for toolbar/title bar.
        // Without this, macOS pushes content down to avoid the toolbar area,
        // creating a visible gap at the top of the editor.
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Wire delegate and coordinator
        tv.delegate = context.coordinator
        tv.layoutManager?.delegate = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.storage = storage

        // Transclusion overlays — shows ((block-ref)) content inline
        let transclusionMgr = TransclusionOverlayManager(textView: tv)
        if let mc = modelContext {
            transclusionMgr.configure(modelContext: mc)
        }
        context.coordinator.transclusionManager = transclusionMgr

        // Block ref autocomplete — triggered by typing ((
        if let mc = modelContext {
            let autocomplete = BlockRefAutocomplete()
            autocomplete.configure(textView: tv, modelContext: mc)
            context.coordinator.blockRefAutocomplete = autocomplete
        }

        // Wire wikilink + block ref handlers
        let coord = context.coordinator
        tv.onWikilinkClick = { [weak coord] title in
            coord?.parent.onWikilinkClick?(title)
        }
        tv.onBlockRefClick = { [weak coord] blockId in
            coord?.parent.onBlockRefClick?(blockId)
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
            guard let tv, let coord, let pageId = coord.lastPageId, !pageId.isEmpty else { return }
            MainActor.assumeIsolated {
                let now = CACurrentMediaTime()
                guard now - coord.lastScrollSaveTime > 0.2 else { return }
                coord.lastScrollSaveTime = now
                let scrollY = tv.enclosingScrollView?.contentView.bounds.origin.y ?? 0
                let selection = tv.selectedRange()
                PageStoragePool.shared.saveState(
                    pageId: pageId, scrollY: scrollY, selection: selection
                )
                // Reposition transclusion overlays on scroll
                coord.transclusionManager?.refresh()
            }
        }

        // Set lastPageId to nil so updateNSView will perform the initial page swap
        coord.lastPageId = nil

        // Apply initial centering after content loads
        DispatchQueue.main.async {
            Self.updateCenteringInsets(for: tv)
        }

        return scrollView
    }

    // MARK: - Dismantle (Save State to Pool + Disk)

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        guard let tv = scrollView.documentView as? ClickableTextView,
              let pageId = coordinator.lastPageId, !pageId.isEmpty
        else { return }

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

        // === PAGE SWAP via storage swap ===
        if coord.lastPageId != pageId {
            coord.isSwappingPage = true

            // Save outgoing page — text to SwiftData + visual state to pool
            if let oldId = coord.lastPageId, !oldId.isEmpty {
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
                    isDark: isDark
                )

                // Swap storage — detach old, attach new
                coord.storage?.removeLayoutManager(layoutManager)
                slot.storage.addLayoutManager(layoutManager)
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
            coord.blockRefAutocomplete?.dismiss()
        }

        // === GUARD ALL WORK WITH COORDINATOR CACHE (Pitfall #6) ===

        // Theme change — only when isDark actually changed.
        // Progressive restyle: line-level styles synchronous (headings/lists/quotes —
        // correct colors immediately), inline styles deferred one frame (7 regex passes).
        // Prevents multi-second freeze on theme toggle with large documents.
        if coord.lastIsDark != isDark {
            coord.lastIsDark = isDark
            coord.storage?.isDark = isDark
            let baseColor: NSColor =
                isDark ? .white.withAlphaComponent(0.88) : NSColor(white: 0.1, alpha: 1)
            tv.textColor = baseColor
            tv.typingAttributes[.foregroundColor] = baseColor
            Self.progressiveRestyle(coord.storage)
            PageStoragePool.shared.invalidateExcept(activePageId: pageId)
        }

        // Editable state — react to lock/preview toggles
        if tv.isEditable != isEditable {
            tv.isEditable = isEditable
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
        if !coord.isUserEditing, !coord.isSwappingPage, let storage = coord.storage,
            tv.string != text, !tv.hasMarkedText(),
            !(text.isEmpty && storage.length > 0)
        {
            let sel = tv.selectedRange()
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: fullRange, with: text)
            let safeLoc = min(sel.location, tv.string.utf16.count)
            tv.setSelectedRange(NSRange(location: safeLoc, length: 0))
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

        // Update wikilink + block ref handler references
        tv.onWikilinkClick = { [weak coord] title in
            coord?.parent.onWikilinkClick?(title)
        }
        tv.onBlockRefClick = { [weak coord] blockId in
            coord?.parent.onBlockRefClick?(blockId)
        }

        // Recalculate centering only when width actually changed
        let currentWidth = scrollView.contentSize.width
        if abs(coord.lastAvailableWidth - currentWidth) > 0.5 {
            coord.lastAvailableWidth = currentWidth
            Self.updateCenteringInsets(for: tv)
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

        let horizontalInset = max(minHorizontalInset, (availableWidth - maxReadableWidth) / 2)
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
        var blockRefAutocomplete: BlockRefAutocomplete?

        // Cache guards (Pitfall #6) — skip work in updateNSView if nothing changed
        var lastIsFocused = false
        var lastIsDark = false
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

        // Auto-close [[brackets]]
        private var isInsertingBrackets = false

        // Frame observer for Obsidian-style centering.
        // nonisolated(unsafe) because deinit is nonisolated and needs to remove it.
        // NSObjectProtocol is not Sendable, but we only touch this from MainActor + deinit.
        nonisolated(unsafe) var frameObserver: (any NSObjectProtocol)?

        // Scroll observer for continuous scroll position tracking.
        nonisolated(unsafe) var scrollObserver: (any NSObjectProtocol)?

        init(_ parent: ProseEditorRepresentable) {
            self.parent = parent
            self.lastIsDark = parent.isDark
            // lastPageId intentionally left nil — updateNSView will do the initial swap
        }

        deinit {
            if let observer = frameObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }

            // Don't sync during IME composition — wait for committed text.
            // Syncing partial marked text can corrupt characters (e.g. dead-key backtick).
            guard !tv.hasMarkedText() else { return }

            // Suppress binding sync during programmatic content changes (page swap / load).
            // textDidChange fires synchronously inside storage.replaceCharacters() when called
            // from updateNSView/makeNSView. Setting the binding from within an update is
            // undefined behavior and would let the text sync guard overwrite new content
            // with stale @State.
            guard !isSwappingPage else { return }

            // Notify template overlay that user started typing (short docs only).
            // Use utf16Count instead of trimmingCharacters to avoid O(n) on large docs.
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
                if cursorLoc >= 2,
                    str.substring(with: NSRange(location: cursorLoc - 2, length: 2)) == "[["
                {
                    let hasClosing =
                        cursorLoc < str.length - 1
                        && str.substring(
                            with: NSRange(
                                location: cursorLoc, length: min(2, str.length - cursorLoc)))
                            == "]]"
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

            // Refresh transclusion overlays
            transclusionManager?.refresh()

            // Sync text to binding
            isUserEditing = true
            parent.text = tv.string
            isUserEditing = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            // Selection tracking — no special behavior needed
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Tab/Shift-Tab: indent/outdent the current line(s) for outlining.
            // Pure text manipulation — BlockReconciler maps indentation to block hierarchy
            // on the next debounced save.
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return indentLines(textView: textView, indent: true)
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return indentLines(textView: textView, indent: false)
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
    }
}
