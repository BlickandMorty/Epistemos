import AppKit
import UniformTypeIdentifiers
import os

@MainActor
final class ScrollWorkCoalescer {
    private let delay: Duration
    private var task: Task<Void, Never>?

    init(delay: Duration) {
        self.delay = delay
    }

    deinit {
        task?.cancel()
    }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        guard task == nil else { return }

        task = Task { @MainActor [delay] in
            defer { self.task = nil }
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - ProseTextView2
// NSTextView subclass backed by TextKit 2 (NSTextLayoutManager).
// Plain text markdown editor — isRichText = false.
// Structural paragraph styling is provided by MarkdownContentStorage.

final class ProseTextView2: NSTextView {
    /// When true, the text view stays fully transparent regardless of
    /// the active theme so a surrounding frosted-glass surface (e.g.
    /// the graph inline note view's `unifiedFrostedGlass`) shows
    /// through. Set by `ProseEditorRepresentable2.applyEditorBackgroundMode`
    /// when its `usesTransparentEditorBackground` flag is on.
    var usesTransparentBackground: Bool = false
    private nonisolated static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private nonisolated static let log = Logger(subsystem: "com.epistemos", category: "ProseTextView2")
    private var requestedTheme: EpistemosTheme = .nativeDefault

    static func editorBackgroundColor(for theme: EpistemosTheme) -> NSColor {
        if theme.followsSystemAppearance {
            return .clear
        }
        // Eighth-pass + 1 (2026-05-13): per user feedback the prose
        // editor needs to (a) match the workspace canvas color so there
        // is no "second OLED overlay" and (b) be fully solid (alpha 1.0)
        // so the WKWebView-style blur slot doesn't leak through.
        // `solidFlatBackgroundNSColor` returns the card hue with alpha
        // forced to 1.0 — exact same color the workspace canvas paints
        // via `NoteWorkspaceSurfaceStyle.canvasBackground`. One
        // continuous solid themed surface across editor + workspace.
        let surfaceTheme = theme.surfaceVariant(.other)
        return MarkdownPreviewSurfaceStyle.solidFlatBackgroundNSColor(for: surfaceTheme)
    }

    @MainActor
    private final class TestFixtureRetainer {
        static let shared = TestFixtureRetainer()
        private var scrollViews: [NSScrollView] = []

        func retain(_ scrollView: NSScrollView) {
            scrollViews.append(scrollView)
        }
    }

    /// Delegate that classifies paragraphs via Rust FFI and applies structural styles.
    let markdownDelegate = MarkdownContentStorage()
    private var reparseTask: Task<Void, Never>?
    private var currentActiveLine: Int?
    private var pendingActiveLineInvalidation = false
    private nonisolated(unsafe) var boundsObserver: (any NSObjectProtocol)?

    // MARK: - Reparse debounce (Master Fusion Plan §C.4)
    //
    // RCA4-P1-002 — the per-keystroke reparse is bounded by fast Rust
    // FFI + tokenCache (RCA2-P2-009 fix-pass). For typical notes
    // (<10k lines) the current synchronous path is performant. For
    // long notes / 100KB pastes / heavy typing bursts, the §C.4
    // optimization path adds a 50-150ms debounce window so a typing
    // storm collapses into a single reparse at the end.
    //
    // Implementation discipline (preserves V1 UX):
    // - Default `reparseDebounceWindow = 0` (current behavior — every
    //   keystroke triggers immediate reparse via the Rust FFI).
    // - When window > 0, didChangeText() arms a DispatchWorkItem that
    //   fires once after the window expires; intermediate keystrokes
    //   cancel + re-arm. The final reparseAndInvalidate() call is
    //   identical to the synchronous path.
    // - The window is a per-instance setter so a future operator-
    //   profiling pass can flip the default for long-doc instances.
    //
    // Source-guard test: `LocalReparseDebounceTests` pins both the
    // default-zero and the debounce-coalesces-bursts invariants.
    nonisolated(unsafe) var reparseDebounceWindow: TimeInterval = 0
    private var pendingDebouncedReparse: DispatchWorkItem?
    private let scrollVisibleLineRangeCoalescer = ScrollWorkCoalescer(
        delay: NoteEditorPerformancePolicy.scrollWorkCoalescingDelay
    )

    /// When true, dim all paragraphs except the one containing the insertion point.
    nonisolated(unsafe) var isFocusMode = false

    /// Per-page undo manager, set by Coordinator2 on page swap.
    /// When nil, falls back to NSTextView's default undo manager.
    var pageUndoManager: UndoManager?

    nonisolated(unsafe) var usesRenderedTableOverlays = false
    nonisolated(unsafe) var hasProtectedInlineResponseDivider = false

    /// Page ID for scoping notifications to the correct tab.
    var pageId: String?
    var onMarkedTextStart: (() -> Void)?

    /// Closure called when user clicks a heading fold triangle. Receives the heading character offset.
    var onFoldToggle: ((Int) -> Void)?

    /// Closure called when user selects "Open in Graph" from context menu.
    var onOpenInGraph: ((String) -> Void)?

    // MARK: - Notifications
    // Stable editor notification names used by the note workspace and tests.
    nonisolated static let createIdeaNotification = Notification.Name("EpistemosCreateIdeaAtLine")
    nonisolated static let createBrainDumpNotification = Notification.Name("EpistemosCreateBrainDumpAtLine")
    nonisolated static let aiOperationNotification = Notification.Name("EpistemosAIOperation")
    nonisolated static let blockPropertyNotification = Notification.Name("EpistemosBlockPropertyEdit")
    nonisolated static let translateNotification = Notification.Name("EpistemosTranslateText")
    nonisolated static let scrollToOffsetNotification = Notification.Name("EpistemosScrollToOffset")

    override var undoManager: UndoManager? {
        pageUndoManager ?? super.undoManager
    }

    func beginNamedUndoGroup(_ name: String) {
        undoManager?.beginUndoGrouping()
        undoManager?.setActionName(name)
    }

    func endNamedUndoGroup() {
        guard let undoManager, undoManager.groupingLevel > 0 else { return }
        undoManager.endUndoGrouping()
    }

    deinit {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
    }

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        if let text = pasteboard.string(forType: .string) {
            beginNamedUndoGroup("Paste")
            defer { endNamedUndoGroup() }
            insertText(sanitizePastedText(text), replacementRange: selectedRange())
            return
        }

        if let rtfData = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            beginNamedUndoGroup("Paste")
            defer { endNamedUndoGroup() }
            insertText(sanitizePastedText(attributed.string), replacementRange: selectedRange())
            return
        }

        Self.log.debug("Paste contained no extractable text")
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 229,
           let chars = event.characters,
           chars.contains(where: { $0 == "\r" || $0 == "\n" }) {
            Self.log.debug("Ignoring IME confirmation return for page \(self.pageId ?? "unknown", privacy: .public)")
            return
        }

        if hasMarkedText() {
            super.keyDown(with: event)
            return
        }

        super.keyDown(with: event)
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        onMarkedTextStart?()
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    override func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = range

        let safeLocation = max(0, min(range.location, (string as NSString).length))
        guard let textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager,
              let documentLocation = textContentManager.location(
                textContentManager.documentRange.location,
                offsetBy: safeLocation
              ),
              let fragment = textLayoutManager.textLayoutFragment(for: documentLocation)
        else {
            return super.firstRect(forCharacterRange: range, actualRange: actualRange)
        }

        let fragmentFrame = fragment.layoutFragmentFrame.offsetBy(
            dx: textContainerOrigin.x,
            dy: textContainerOrigin.y
        )
        let caretRect = NSRect(
            x: fragmentFrame.minX,
            y: fragmentFrame.minY,
            width: 1,
            height: fragmentFrame.height
        )
        let windowRect = convert(caretRect, to: nil)
        return window?.convertToScreen(windowRect) ?? windowRect
    }

    private func sanitizePastedText(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200C}", with: "")
            .replacingOccurrences(of: "\u{200D}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{200F}", with: "")
    }

    func applyTheme(_ theme: EpistemosTheme) {
        requestedTheme = theme
        applyResolvedTheme(theme.resolvedForAppearance(effectiveAppearance))
    }

    var resolvedTheme: EpistemosTheme {
        requestedTheme.resolvedForAppearance(effectiveAppearance)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshNativeThemeIfNeeded()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshNativeThemeIfNeeded()
    }

    private func refreshNativeThemeIfNeeded() {
        guard requestedTheme.followsSystemAppearance else { return }
        let theme = resolvedTheme
        let resolved = theme.resolved
        guard markdownDelegate.theme != theme
            || backgroundColor != Self.editorBackgroundColor(for: theme)
            || textColor != resolved.foreground.nsColor
        else { return }
        applyResolvedTheme(theme)
    }

    private func applyResolvedTheme(_ theme: EpistemosTheme) {
        let foreground = theme.resolved.foreground.nsColor
        // 2026-05-19: when the editor is hosted in a transparent context
        // (graph inline note view, etc.) keep the text view fully see-through
        // regardless of theme so the surrounding `unifiedFrostedGlass` shows
        // through. Otherwise honor the per-theme opaque-background rule.
        if usesTransparentBackground {
            drawsBackground = false
            backgroundColor = .clear
        } else {
            drawsBackground = !theme.followsSystemAppearance
            backgroundColor = Self.editorBackgroundColor(for: theme)
        }
        insertionPointColor = foreground
        textColor = foreground

        let bodyFont = NSFont.systemFont(ofSize: MarkdownEditorStyle.noteBaseFontSize)
        let paragraph =
            (MarkdownEditorStyle.bodyParagraphStyle().mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()

        defaultParagraphStyle = paragraph
        typingAttributes = [
            .font: bodyFont,
            .foregroundColor: foreground,
            .paragraphStyle: paragraph,
        ]

        markdownDelegate.theme = theme
        reparseAndInvalidate()
    }

    // MARK: - Active Line Tracking (Phase 3)

    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting: Bool
    ) {
        let previousLocation = selectedRange().location
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        guard !stillSelecting else { return }
        updateActiveLine()
        notifyFrictionMonitorCursorMove(from: previousLocation)
    }

    private func notifyFrictionMonitorCursorMove(from previousLocation: Int) {
        guard let pageId, let monitor = FrictionMonitorService.shared else { return }
        let newLocation = selectedRange().location
        let delta = newLocation - previousLocation
        guard delta != 0 else { return }
        let event = EditorTelemetryEvent(
            noteId: pageId,
            kind: .cursorMove(delta: delta),
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        Task.detached(priority: .utility) { await monitor.record(event) }
    }

    private func updateActiveLine() {
        let cursorOffset = selectedRange().location
        let newLine = markdownDelegate.lineIndex(at: cursorOffset)
        guard newLine != currentActiveLine else { return }

        let oldLine = currentActiveLine
        currentActiveLine = newLine
        markdownDelegate.activeLine = newLine

        // Coalesce rapid cursor moves into a single layout invalidation pass
        guard !pendingActiveLineInvalidation else { return }
        pendingActiveLineInvalidation = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pendingActiveLineInvalidation = false
            self.invalidateParagraphLayout(line: oldLine)
            self.invalidateParagraphLayout(line: self.currentActiveLine)
            if self.isFocusMode {
                self.applyFocusDimming()
            }
        }
    }

    private func invalidateParagraphLayout(line: Int?) {
        guard let line,
            let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage,
            let lineRange = markdownDelegate.lineRange(at: line)
        else { return }

        guard
            let startLoc = contentStorage.location(
                contentStorage.documentRange.location,
                offsetBy: lineRange.location
            ),
            let endLoc = contentStorage.location(
                startLoc,
                offsetBy: lineRange.length
            )
        else { return }

        guard let textRange = NSTextRange(location: startLoc, end: endLoc) else { return }
        textLayoutManager?.invalidateLayout(for: textRange)
    }

    // MARK: - Live Resize Centering
    // Keep widthTracksTextView = true so text reflows live,
    // then recalculate centering insets when resize ends.

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        // Recalculate centering insets for the new width.
        // The Coordinator2.updateCentering() call in updateNSView handles this,
        // but we also post a notification so the coordinator picks it up promptly.
        NotificationCenter.default.post(
            name: NSView.frameDidChangeNotification,
            object: enclosingScrollView
        )
    }

    // MARK: - Pre-Edit Hook

    /// Mark structure dirty BEFORE the edit lands so that the content storage
    /// delegate sees fresh data when it re-queries textParagraphWith immediately
    /// after the text storage change (before didChangeText fires).
    /// Track the pre-edit range so applyLinkAttributesToStorage can scope its scan.
    /// Last edit location for scoping link attribute scan. `nil` → full-document scan.
    /// Set by shouldChangeText (user edits) or setProgrammaticEditLocation (AI streaming).
    var lastEditLocation: Int?

    /// Track the last edit for friction monitor: positive = insertion, negative = deletion.
    private var lastFrictionEditDelta: Int = 0

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?)
        -> Bool
    {
        // Track edit delta for friction monitor before any guard returns
        let replacementLength = (replacementString as NSString?)?.length ?? 0
        lastFrictionEditDelta = replacementLength - affectedCharRange.length

        if hasProtectedInlineResponseDivider,
           NoteChatInlineResponse.editTouchesDivider(in: string, affectedRange: affectedCharRange) {
            return false
        }
        if MarkdownEditorCommands.isSelectionInsideTable(in: string, selection: affectedCharRange) {
            return false
        }
        if let autoEdit = MarkdownEditorCommands.autoExpandCodeFence(
            in: string,
            selection: affectedCharRange,
            replacementString: replacementString
        ) {
            return applyAutomaticMarkdownEdit(autoEdit)
        }
        markdownDelegate.markDirty()
        lastEditLocation = affectedCharRange.location
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    private func applyAutomaticMarkdownEdit(_ edit: MarkdownEditorCommands.TextEdit) -> Bool {
        markdownDelegate.markDirty()
        lastEditLocation = edit.replacementRange.location
        guard super.shouldChangeText(
            in: edit.replacementRange,
            replacementString: edit.replacementText
        ) else {
            return false
        }
        textStorage?.replaceCharacters(in: edit.replacementRange, with: edit.replacementText)
        didChangeText()
        setSelectedRange(edit.selectedRange)
        return false
    }

    /// Set edit location for programmatic inserts that bypass shouldChangeText.
    /// Prevents applyLinkAttributesToStorage from doing a full-document scan.
    func setProgrammaticEditLocation(_ location: Int) {
        markdownDelegate.markDirty()
        lastEditLocation = location
    }

    // MARK: - Live Edit Loop

    override func didChangeText() {
        super.didChangeText()
        // §C.4 reparse-debounce dispatch:
        // - window == 0 (default): synchronous reparse, same as the
        //   pre-§C.4 behavior. Rust FFI is fast enough for per-keystroke.
        // - window > 0: cancel any prior pending reparse + arm a new
        //   DispatchWorkItem on main. A typing burst collapses to ONE
        //   reparse at the end of the quiet window.
        if reparseDebounceWindow > 0 {
            pendingDebouncedReparse?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.reparseAndInvalidate()
            }
            pendingDebouncedReparse = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + reparseDebounceWindow,
                execute: work
            )
        } else {
            reparseAndInvalidate()
        }
        Task { @MainActor in
            AppBootstrap.shared?.activityTracker.recordInAppActivity()
        }
        notifyFrictionMonitorEdit()
    }

    /// Lightweight friction telemetry hook — dispatches to actor, never blocks editor.
    private func notifyFrictionMonitorEdit() {
        guard let pageId, let monitor = FrictionMonitorService.shared else { return }
        let delta = lastFrictionEditDelta
        guard delta != 0 else { return }
        let kind: EditorTelemetryEvent.Kind = delta > 0
            ? .insertion(count: delta)
            : .deletion(count: -delta)
        let event = EditorTelemetryEvent(
            noteId: pageId,
            kind: kind,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        Task.detached(priority: .utility) { await monitor.record(event) }
    }

    /// Reparse structure, apply link attributes to storage, invalidate layout.
    func reparseAndInvalidate() {
        guard
            let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage
        else { return }

        let str = string as NSString
        let paragraphRange = Self.paragraphNeighborhoodRange(in: str, around: lastEditLocation)

        markdownDelegate.reparse(text: string)
        updateVisibleLineRange()

        // Apply .link attributes directly to textStorage for wikilinks and block refs.
        // The delegate-provided NSTextParagraph attributes don't flow back to storage,
        // so NSTextView's clickedOnLink delegate never fires without this.
        applyLinkAttributesToStorage(in: paragraphRange, string: str)
        lastEditLocation = nil

        invalidateLayout(in: contentStorage, nsRange: paragraphRange, stringLength: str.length)
    }

    /// Scan textStorage for wikilinks ([[...]]) and block refs (((...))) and apply
    /// .link attributes directly. This is what makes clickedOnLink fire in TK2.
    ///
    /// Scoped to the edited paragraph + neighbors on per-keystroke calls.
    /// Full-document scan only on initial load (lastEditLocation == nil).
    func applyLinkAttributesToStorage() {
        guard let storage = textStorage else { return }
        let str = storage.string as NSString
        guard str.length > 0 else { return }

        let scanRange = Self.paragraphNeighborhoodRange(in: str, around: lastEditLocation)
        applyLinkAttributesToStorage(in: scanRange, string: str)
        lastEditLocation = nil
    }

    static func paragraphNeighborhoodRange(in text: NSString, around editLocation: Int?) -> NSRange {
        guard text.length > 0, let editLocation else {
            return NSRange(location: 0, length: text.length)
        }

        let clampedLocation = min(max(editLocation, 0), max(text.length - 1, 0))
        if let structuralRange = structuralEditRange(in: text, around: clampedLocation) {
            return structuralRange
        }

        let paragraphRange = text.paragraphRange(for: NSRange(location: clampedLocation, length: 0))
        let start =
            paragraphRange.location > 0
            ? text.paragraphRange(for: NSRange(location: paragraphRange.location - 1, length: 0))
                .location
            : 0
        let paragraphEnd = NSMaxRange(paragraphRange)
        let end =
            paragraphEnd < text.length
            ? NSMaxRange(text.paragraphRange(for: NSRange(location: paragraphEnd, length: 0)))
            : text.length
        return NSRange(location: start, length: end - start)
    }

    private static func structuralEditRange(in text: NSString, around editLocation: Int) -> NSRange? {
        if let fencedBlockRange = fencedCodeBlockRange(in: text, containing: editLocation) {
            return fencedBlockRange
        }

        let lineRange = text.lineRange(for: NSRange(location: editLocation, length: 0))
        let trimmedLine = trimmedLine(in: text, range: lineRange)

        if isQuoteChainLine(trimmedLine) {
            return contiguousStructuralRange(
                in: text,
                startingAt: lineRange,
                matches: isQuoteChainLine
            )
        }

        if isTableLine(trimmedLine) {
            return contiguousStructuralRange(
                in: text,
                startingAt: lineRange,
                matches: isTableLine
            )
        }

        return nil
    }

    private static func fencedCodeBlockRange(in text: NSString, containing editLocation: Int) -> NSRange? {
        var location = 0
        var openFenceStart: Int?

        while location < text.length {
            let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
            let trimmedLine = trimmedLine(in: text, range: lineRange)

            if isFenceLine(trimmedLine) {
                if let activeFenceStart = openFenceStart {
                    let candidate = NSRange(
                        location: activeFenceStart,
                        length: NSMaxRange(lineRange) - activeFenceStart
                    )
                    if NSLocationInRange(editLocation, candidate) {
                        return candidate
                    }
                    openFenceStart = nil
                } else {
                    openFenceStart = lineRange.location
                }
            }

            let nextLocation = NSMaxRange(lineRange)
            guard nextLocation > location else { break }
            location = nextLocation
        }

        if let openFenceStart {
            let candidate = NSRange(location: openFenceStart, length: text.length - openFenceStart)
            if NSLocationInRange(editLocation, candidate) || editLocation == NSMaxRange(candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func contiguousStructuralRange(
        in text: NSString,
        startingAt lineRange: NSRange,
        matches: (String) -> Bool
    ) -> NSRange {
        var start = lineRange.location
        var end = NSMaxRange(lineRange)

        while start > 0 {
            let previousLine = text.lineRange(for: NSRange(location: start - 1, length: 0))
            guard matches(trimmedLine(in: text, range: previousLine)) else { break }
            start = previousLine.location
        }

        while end < text.length {
            let nextLine = text.lineRange(for: NSRange(location: end, length: 0))
            guard matches(trimmedLine(in: text, range: nextLine)) else { break }
            end = NSMaxRange(nextLine)
        }

        return NSRange(location: start, length: end - start)
    }

    private static func trimmedLine(in text: NSString, range: NSRange) -> String {
        text.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isFenceLine(_ line: String) -> Bool {
        line.hasPrefix("```")
    }

    private static func isQuoteChainLine(_ line: String) -> Bool {
        line.hasPrefix(">")
    }

    private func applyLinkAttributesToStorage(in scanRange: NSRange, string str: NSString) {
        guard let storage = textStorage else { return }
        guard str.length > 0 else { return }

        // Clear old wikilink/blockref links in scan range
        storage.enumerateAttribute(.link, in: scanRange, options: []) { val, range, _ in
            guard let linkStr = val as? String,
                linkStr.hasPrefix("wikilink://") || linkStr.hasPrefix("blockref://")
            else { return }
            storage.removeAttribute(.link, range: range)
        }

        // Wikilinks: [[title]]
        if let wikilinkRegex = try? NSRegularExpression(pattern: "\\[\\[([^\\]]+)\\]\\]") {
            for match in wikilinkRegex.matches(in: str as String, range: scanRange) {
                guard match.numberOfRanges >= 2 else { continue }
                let innerRange = match.range(at: 1)
                let title = str.substring(with: innerRange)
                storage.addAttribute(
                    .link, value: "wikilink://\(title)" as NSString, range: innerRange)
            }
        }

        // Block refs: ((blockId))
        if let blockRefRegex = try? NSRegularExpression(pattern: "\\(\\(([^)]+)\\)\\)") {
            for match in blockRefRegex.matches(in: str as String, range: scanRange) {
                guard match.numberOfRanges >= 2 else { continue }
                let innerRange = match.range(at: 1)
                let blockId = str.substring(with: innerRange)
                storage.addAttribute(
                    .link, value: "blockref://\(blockId)" as NSString, range: innerRange)
            }
        }
    }

    private func invalidateLayout(
        in contentStorage: NSTextContentStorage,
        nsRange: NSRange,
        stringLength: Int
    ) {
        guard let textLayoutManager else { return }
        guard stringLength > 0,
              !(nsRange.location == 0 && nsRange.length == stringLength),
              let startLoc = contentStorage.location(
                contentStorage.documentRange.location,
                offsetBy: nsRange.location
              ),
              let endLoc = contentStorage.location(
                startLoc,
                offsetBy: nsRange.length
              ),
              let textRange = NSTextRange(location: startLoc, end: endLoc) else {
            textLayoutManager.invalidateLayout(for: contentStorage.documentRange)
            return
        }

        textLayoutManager.invalidateLayout(for: textRange)
    }

    // MARK: - Viewport Tracking (Phase 6)

    func updateVisibleLineRange() {
        guard let tlm = textLayoutManager,
            let contentStorage = tlm.textContentManager as? NSTextContentStorage
        else { return }
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds

        let startPoint = CGPoint(x: 0, y: max(visibleRect.minY - textContainerOrigin.y, 0))
        let endPoint = CGPoint(x: 0, y: visibleRect.maxY - textContainerOrigin.y)

        var startLine = 0
        var endLine = markdownDelegate.lineCount

        if let startFrag = tlm.textLayoutFragment(for: startPoint) {
            let startRange = startFrag.rangeInElement
            let offset = contentStorage.offset(
                from: tlm.documentRange.location, to: startRange.location)
            startLine = markdownDelegate.lineIndex(at: offset)
        }

        if let endFrag = tlm.textLayoutFragment(for: endPoint) {
            let endRange = endFrag.rangeInElement
            let offset = contentStorage.offset(
                from: tlm.documentRange.location, to: endRange.location)
            endLine = markdownDelegate.lineIndex(at: offset)
        }

        markdownDelegate.visibleLineRange = Self.normalizedVisibleLineRange(
            startLine: startLine,
            endLine: endLine,
            lineCount: markdownDelegate.lineCount
        )
    }

    nonisolated static func normalizedVisibleLineRange(
        startLine: Int,
        endLine: Int,
        lineCount: Int
    ) -> Range<Int> {
        let boundedLineCount = max(lineCount, 0)
        let lower = min(max(startLine, 0), boundedLineCount)
        let boundedEnd = min(max(endLine, lower), boundedLineCount)
        let upper = min(max(boundedEnd + 1, lower + 1), boundedLineCount + 1)
        return lower..<upper
    }

    // MARK: - Factory

    /// Create a TextKit 2-backed prose editor in a scroll view.
    /// The MarkdownContentStorage delegate is wired automatically.
    static func makeTextKit2() -> (NSScrollView, ProseTextView2) {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets()

        let tv = ProseTextView2(usingTextLayoutManager: true)
        tv.frame = NSRect(x: 0, y: 0, width: 700, height: 1000)
        tv.minSize = .zero
        tv.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = true
        tv.usesFontPanel = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.drawsBackground = true
        tv.textContainerInset = NSSize(width: 60, height: 40)
        tv.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.writingToolsBehavior = .default
        tv.wantsLayer = true

        tv.applyTheme(.nativeDefault)

        // Wire MarkdownContentStorage as delegate for BOTH TextKit 2 delegate roles.
        // NSTextContentStorage overrides the `delegate` property from NSTextContentManager,
        // creating separate slots for NSTextContentStorageDelegate (paragraph styling) and
        // NSTextContentManagerDelegate (shouldEnumerate for fold filtering).
        if let contentStorage = tv.textLayoutManager?.textContentManager
            as? NSTextContentStorage
        {
            // 1. NSTextContentStorageDelegate — paragraph styling
            contentStorage.delegate = tv.markdownDelegate
            // 2. NSTextContentManagerDelegate — shouldEnumerate (fold hiding)
            //    Uses ObjC objc_msgSendSuper to call NSTextContentManager's setter,
            //    bypassing NSTextContentStorage's override. See ContentManagerDelegateHelper.m.
            EpistemosSetContentManagerDelegate(contentStorage, tv.markdownDelegate)
        }

        // Wire layout manager delegate for custom fragment vending (code blocks).
        tv.textLayoutManager?.delegate = tv

        // Track scroll position for viewport-gated code tokenization.
        scrollView.contentView.postsBoundsChangedNotifications = true
        tv.attachBoundsObserver(to: scrollView.contentView)

        scrollView.documentView = tv
        if Self.isRunningTests {
            TestFixtureRetainer.shared.retain(scrollView)
        }
        return (scrollView, tv)
    }

    private func attachBoundsObserver(to contentView: NSClipView) {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleVisibleLineRangeUpdate()
            }
        }
    }

    private func scheduleVisibleLineRangeUpdate() {
        scrollVisibleLineRangeCoalescer.schedule { [weak self] in
            self?.updateVisibleLineRange()
        }
    }

    // MARK: - Custom Drawing (Phase 4)

    override func drawBackground(in rect: NSRect) {
        guard NSGraphicsContext.current?.cgContext != nil else { return }
        super.drawBackground(in: rect)
        drawBlockChrome(in: rect)
        if !usesRenderedTableOverlays {
            drawTableFills(in: rect)
            drawTableGridLines(in: rect)
        }
        drawFoldIndicators(in: rect)
    }

    private struct TableRegion {
        var top: CGFloat
        var bottom: CGFloat
        var left: CGFloat
        var right: CGFloat
        var columnXs: [CGFloat]
        var rowYs: [CGFloat]
        var headerBottomY: CGFloat?
        var firstNSRange: NSRange  // first fragment's NSRange (for boundary check)
        var lastNSRange: NSRange  // last fragment's NSRange (for boundary check)
    }

    /// Get paragraph text and NSRange for a layout fragment.
    /// Returns nil if the fragment references stale ranges (can happen during rapid edits).
    private func paragraphInfo(
        for fragment: NSTextLayoutFragment,
        contentStorage: NSTextContentStorage
    ) -> (text: String, nsRange: NSRange)? {
        guard let textParagraph = fragment.textElement as? NSTextParagraph,
            let elementRange = textParagraph.elementRange
        else { return nil }
        let docStart = contentStorage.documentRange.location
        let offset = contentStorage.offset(from: docStart, to: elementRange.location)
        let length = contentStorage.offset(
            from: elementRange.location, to: elementRange.endLocation)
        // Guard stale layout: fragment ranges can exceed storage after rapid edits.
        guard offset >= 0, length >= 0, offset &+ length <= (string as NSString).length else {
            return nil
        }
        return (textParagraph.attributedString.string, NSRange(location: offset, length: length))
    }

    private struct FoldIndicatorLayout {
        let paragraphRange: NSRange
        let headingOffset: Int
        let isFolded: Bool
        let lineRect: NSRect
        let hitRect: NSRect
    }

    private func foldIndicatorLayout(
        for fragment: NSTextLayoutFragment,
        fragFrame: NSRect,
        contentStorage: NSTextContentStorage
    ) -> FoldIndicatorLayout? {
        guard let (_, nsRange) = paragraphInfo(for: fragment, contentStorage: contentStorage) else {
            return nil
        }

        let lineIdx = markdownDelegate.lineIndex(at: nsRange.location)
        guard lineIdx >= 0,
              markdownDelegate.paragraphType(at: lineIdx) == 1,
              let lineFrag = fragment.textLineFragments.first else {
            return nil
        }

        let lineY = fragFrame.minY + lineFrag.typographicBounds.origin.y
        let lineRect = NSRect(
            x: floor(fragFrame.minX - 22),
            y: floor(lineY),
            width: 16,
            height: ceil(lineFrag.typographicBounds.height)
        )
        let hitRect = lineRect.insetBy(dx: -6, dy: -4)

        return FoldIndicatorLayout(
            paragraphRange: nsRange,
            headingOffset: nsRange.location,
            isFolded: markdown_is_folded(UInt32(clamping: lineIdx)),
            lineRect: lineRect,
            hitRect: hitRect
        )
    }

    // MARK: - Visible Fragment Enumeration

    /// Enumerate layout fragments intersecting the dirty rect.
    /// Uses textLayoutFragment(for:) for O(log n) start, early-terminates past the rect.
    /// Block receives (fragment, viewFrame). Return true to continue, false to stop.
    private func enumerateVisibleFragments(
        in dirtyRect: NSRect,
        using block: (NSTextLayoutFragment, NSRect) -> Bool
    ) {
        guard let tlm = textLayoutManager else { return }
        let origin = textContainerOrigin

        // Convert dirty rect top to text container coordinates
        let containerTopY = dirtyRect.minY - origin.y
        let startPoint = CGPoint(x: 0, y: max(containerTopY - 1, 0))

        // O(log n) lookup for the fragment at the top of the dirty rect
        let startLocation: NSTextLocation
        if let frag = tlm.textLayoutFragment(for: startPoint),
            let elemRange = frag.textElement?.elementRange
        {
            startLocation = elemRange.location
        } else {
            startLocation = tlm.documentRange.location
        }

        tlm.enumerateTextLayoutFragments(
            from: startLocation,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let fragFrame = fragment.layoutFragmentFrame.offsetBy(dx: origin.x, dy: origin.y)

            // Past dirty rect — stop
            if fragFrame.minY > dirtyRect.maxY { return false }

            // Above dirty rect — skip (rare with the starting position)
            if fragFrame.maxY < dirtyRect.minY { return true }

            return block(fragment, fragFrame)
        }
    }

    private func drawBlockChrome(in dirtyRect: NSRect) {
        guard let textLayoutManager, let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let attributedString = contentStorage.attributedString else { return }
        let text = string as NSString
        guard text.length > 0 else { return }
        let chromeFrame = MarkdownEditorStyle.blockChromeFrame(
            textContainerOrigin: textContainerOrigin,
            containerWidth: textContainer?.containerSize.width ?? bounds.width,
            boundsWidth: bounds.width
        )
        guard chromeFrame.width > 0 else { return }
        var seenSpans = Set<String>()
        var coveredRanges: [NSRange] = []

        enumerateVisibleFragments(in: dirtyRect) { fragment, _ in
            guard let (_, paragraphRange) = self.paragraphInfo(
                for: fragment,
                contentStorage: contentStorage
            ), !coveredRanges.contains(where: { NSLocationInRange(paragraphRange.location, $0) })
            else {
                return true
            }

            guard let span = MarkdownEditorStyle.blockChromeSpan(
                in: attributedString,
                text: text,
                aroundLineRange: paragraphRange
            ) else {
                return true
            }

            let spanKey = "\(span.kind.rawValue):\(span.lineRange.location):\(span.lineRange.length)"
            guard seenSpans.insert(spanKey).inserted,
                  let rect = self.blockChromeRect(
                    for: span.lineRange,
                    chromeFrame: chromeFrame,
                    text: text,
                    textLayoutManager: textLayoutManager,
                    contentStorage: contentStorage
                  ),
                  rect.intersects(dirtyRect)
            else {
                return true
            }

            coveredRanges.append(span.lineRange)
            MarkdownEditorStyle.drawBlockChrome(
                kind: span.kind,
                fill: span.fill,
                accent: span.accent,
                in: rect
            )
            return true
        }
    }

    private func blockChromeRect(
        for lineRange: NSRange,
        chromeFrame: NSRect,
        text: NSString,
        textLayoutManager: NSTextLayoutManager,
        contentStorage: NSTextContentStorage
    ) -> NSRect? {
        let styledRange = MarkdownEditorStyle.blockChromeStyleRange(in: text, lineRange: lineRange)
        guard styledRange.length > 0 else { return nil }

        let documentStart = contentStorage.documentRange.location
        var cursor = styledRange.location
        var unionRect = NSRect.null

        while cursor < NSMaxRange(styledRange) {
            let paragraphRange = text.lineRange(for: NSRange(location: cursor, length: 0))
            guard let location = contentStorage.location(documentStart, offsetBy: paragraphRange.location),
                  let fragment = textLayoutManager.textLayoutFragment(for: location) else {
                cursor = NSMaxRange(paragraphRange)
                continue
            }

            unionRect = unionRect.union(fragment.layoutFragmentFrame)
            let nextCursor = NSMaxRange(paragraphRange)
            guard nextCursor > cursor else { break }
            cursor = nextCursor
        }

        guard !unionRect.isNull, unionRect.height > 0 else { return nil }
        return NSRect(
            x: chromeFrame.minX,
            y: textContainerOrigin.y + unionRect.minY - 5,
            width: chromeFrame.width,
            height: max(0, unionRect.height + 10)
        )
    }

    private func drawTableFills(in dirtyRect: NSRect) {
        guard
            let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage
        else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let isDark = markdownDelegate.theme.isDark
        let headerFill =
            isDark
            ? NSColor.white.withAlphaComponent(0.04)
            : NSColor.black.withAlphaComponent(0.03)

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard
                let (lineText, nsRange) = self.paragraphInfo(
                    for: fragment, contentStorage: contentStorage
                )
            else { return true }
            let line = lineText.trimmingCharacters(in: .newlines)

            guard Self.isTableLine(line), !Self.isSeparatorLine(line) else { return true }

            // Header = first data row of a table (previous line is NOT a table line).
            let isHeader: Bool
            if nsRange.location > 0 {
                let prevRange = str.lineRange(
                    for: NSRange(location: nsRange.location - 1, length: 0))
                let prevLine = str.substring(with: prevRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                isHeader = !Self.isTableLine(prevLine)
            } else {
                isHeader = true
            }
            guard isHeader else { return true }

            let pipeIndices = Self.pipeCharIndices(in: line)
            guard let lastPipeIndex = pipeIndices.last else { return true }
            guard let firstLineFrag = fragment.textLineFragments.first,
                pipeIndices.count >= 2,
                lastPipeIndex < firstLineFrag.characterRange.length
            else { return true }

            let firstPipeX = firstLineFrag.locationForCharacter(at: pipeIndices[0]).x
            let lastPipeX = firstLineFrag.locationForCharacter(at: lastPipeIndex).x
            guard lastPipeX > firstPipeX else { return true }

            let fillRect = NSRect(
                x: fragFrame.minX + firstPipeX - 1,
                y: fragFrame.minY,
                width: lastPipeX - firstPipeX + 2,
                height: fragFrame.height
            )
            headerFill.setFill()
            fillRect.fill()

            return true
        }
    }

    private func drawTableGridLines(in dirtyRect: NSRect) {
        guard
            let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage
        else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let borderColor = NSColor.separatorColor
        let headerLineColor = NSColor.tertiaryLabelColor

        var tables: [TableRegion] = []
        var current: TableRegion?

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard
                let (lineText, nsRange) = self.paragraphInfo(
                    for: fragment, contentStorage: contentStorage
                )
            else {
                if let t = current {
                    tables.append(t)
                    current = nil
                }
                return true
            }
            let line = lineText.trimmingCharacters(in: .newlines)

            if Self.isTableLine(line) {
                let isSep = Self.isSeparatorLine(line)

                // Track last fragment range for all table lines (data + separator)
                current?.lastNSRange = nsRange

                if isSep {
                    if var table = current {
                        table.headerBottomY =
                            table.rowYs.last.map {
                                $0 + (fragFrame.minY - $0)
                            } ?? fragFrame.minY
                        table.bottom = fragFrame.maxY
                        current = table
                    }
                } else {
                    var pipeXs: [CGFloat] = []
                    if let firstLineFrag = fragment.textLineFragments.first {
                        let pipeIndices = Self.pipeCharIndices(in: line)
                        let charLimit = firstLineFrag.characterRange.length
                        for idx in pipeIndices where idx < charLimit {
                            let loc = firstLineFrag.locationForCharacter(at: idx)
                            pipeXs.append(fragFrame.minX + loc.x)
                        }
                    }

                    if current == nil {
                        current = TableRegion(
                            top: fragFrame.minY, bottom: fragFrame.maxY,
                            left: pipeXs.first ?? fragFrame.minX,
                            right: pipeXs.last ?? fragFrame.maxX,
                            columnXs: pipeXs, rowYs: [fragFrame.minY],
                            headerBottomY: nil,
                            firstNSRange: nsRange, lastNSRange: nsRange
                        )
                    } else if var table = current {
                        table.bottom = fragFrame.maxY
                        if let first = pipeXs.first { table.left = min(table.left, first) }
                        if let last = pipeXs.last { table.right = max(table.right, last) }
                        table.rowYs.append(fragFrame.minY)
                        if pipeXs.count == table.columnXs.count {
                            for i in table.columnXs.indices {
                                table.columnXs[i] =
                                    (table.columnXs[i] * 0.7) + (pipeXs[i] * 0.3)
                            }
                        }
                        current = table
                    }
                }
            } else {
                if let t = current {
                    tables.append(t)
                    current = nil
                }
            }

            return true
        }
        if let t = current { tables.append(t) }

        // Draw collected table regions — individual edges, not rectangles.
        // Suppress top/bottom edges when the dirty rect clips mid-table.
        for table in tables {
            let left = table.left - 2
            let right = table.right + 2
            let top = table.top - 1
            let bottom = table.bottom + 1

            // Is this the actual table start, or did the dirty rect clip it?
            let isActualTop: Bool
            if table.firstNSRange.location > 0 {
                let prevRange = str.lineRange(
                    for: NSRange(location: table.firstNSRange.location - 1, length: 0))
                let prevLine = str.substring(with: prevRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                isActualTop = !Self.isTableLine(prevLine)
            } else {
                isActualTop = true
            }

            // Is this the actual table end, or does it continue past the dirty rect?
            let isActualBottom: Bool
            let nextStart = NSMaxRange(table.lastNSRange)
            if nextStart < str.length {
                let nextRange = str.lineRange(for: NSRange(location: nextStart, length: 0))
                let nextLine = str.substring(with: nextRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                isActualBottom = !Self.isTableLine(nextLine)
            } else {
                isActualBottom = true
            }

            // Outer border — individual edges, suppress clipped boundaries
            borderColor.setStroke()
            let outerPath = NSBezierPath()
            outerPath.lineWidth = 0.5
            // Left + right edges always drawn
            outerPath.move(to: NSPoint(x: left, y: top))
            outerPath.line(to: NSPoint(x: left, y: bottom))
            outerPath.move(to: NSPoint(x: right, y: top))
            outerPath.line(to: NSPoint(x: right, y: bottom))
            if isActualTop {
                outerPath.move(to: NSPoint(x: left, y: top))
                outerPath.line(to: NSPoint(x: right, y: top))
            }
            if isActualBottom {
                outerPath.move(to: NSPoint(x: left, y: bottom))
                outerPath.line(to: NSPoint(x: right, y: bottom))
            }
            outerPath.stroke()

            // Inner grid
            let innerPath = NSBezierPath()
            innerPath.lineWidth = 0.5
            if table.columnXs.count > 2 {
                for x in table.columnXs[1..<(table.columnXs.count - 1)] {
                    innerPath.move(to: NSPoint(x: x, y: table.top))
                    innerPath.line(to: NSPoint(x: x, y: table.bottom))
                }
            }
            for y in table.rowYs.dropFirst() {
                if let hby = table.headerBottomY, abs(y - hby) < 4 { continue }
                innerPath.move(to: NSPoint(x: left, y: y))
                innerPath.line(to: NSPoint(x: right, y: y))
            }
            innerPath.stroke()

            if let headerY = table.headerBottomY {
                headerLineColor.setStroke()
                let headerPath = NSBezierPath()
                headerPath.lineWidth = 1.0
                headerPath.move(to: NSPoint(x: left, y: headerY))
                headerPath.line(to: NSPoint(x: right, y: headerY))
                headerPath.stroke()
            }
        }
    }

    // MARK: - Focus Dimming (Phase 4)

    /// NSRange of the last paragraph that was bright (un-dimmed) during focus mode.
    private var lastFocusParagraphRange: NSRange?

    /// Apply or update focus dimming. On first call, dims entire document then restores
    /// active paragraph. On subsequent calls, only dims the old active paragraph and
    /// restores the new one — O(1) per cursor move instead of O(document).
    func applyFocusDimming() {
        guard isFocusMode, let tlm = textLayoutManager,
            let contentStorage = tlm.textContentManager as? NSTextContentStorage
        else {
            clearFocusDimming()
            return
        }

        let str = string as NSString
        guard str.length > 0 else { return }

        let cursorRange = selectedRange()
        let activeParagraphNSRange = str.paragraphRange(for: cursorRange)

        // Skip if cursor is still in the same paragraph
        if let lastRange = lastFocusParagraphRange, NSEqualRanges(lastRange, activeParagraphNSRange)
        {
            return
        }

        let dimColor = NSColor.textColor.withAlphaComponent(0.25)
        let fullDocRange = tlm.documentRange

        if lastFocusParagraphRange == nil {
            // First time: dim entire document
            tlm.setRenderingAttributes([.foregroundColor: dimColor], for: fullDocRange)
        } else if let oldRange = lastFocusParagraphRange {
            // Dim the previous active paragraph
            if oldRange.length > 0, oldRange.location + oldRange.length <= str.length,
                let oldStart = contentStorage.location(
                    fullDocRange.location, offsetBy: oldRange.location),
                let oldEnd = contentStorage.location(oldStart, offsetBy: oldRange.length),
                let oldTextRange = NSTextRange(location: oldStart, end: oldEnd)
            {
                tlm.setRenderingAttributes([.foregroundColor: dimColor], for: oldTextRange)
            }
        }

        // Restore new active paragraph
        if activeParagraphNSRange.length > 0,
            let startLoc = contentStorage.location(
                fullDocRange.location, offsetBy: activeParagraphNSRange.location),
            let endLoc = contentStorage.location(
                startLoc, offsetBy: activeParagraphNSRange.length),
            let activeRange = NSTextRange(location: startLoc, end: endLoc)
        {
            tlm.setRenderingAttributes([:], for: activeRange)
        }

        lastFocusParagraphRange = activeParagraphNSRange
    }

    /// Clear all focus dimming.
    func clearFocusDimming() {
        guard let tlm = textLayoutManager else { return }
        tlm.setRenderingAttributes([:], for: tlm.documentRange)
        lastFocusParagraphRange = nil
    }

    private func drawFoldIndicators(in dirtyRect: NSRect) {
        guard
            let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage
        else { return }
        guard (string as NSString).length > 0 else { return }

        let isDark = markdownDelegate.theme.isDark
        let accent = MarkdownContentStorage.accentColor(isDark: isDark)
        var seenParagraphs = Set<String>()

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard let indicator = self.foldIndicatorLayout(
                for: fragment,
                fragFrame: fragFrame,
                contentStorage: contentStorage
            ) else {
                return true
            }

            let paragraphKey =
                "\(indicator.paragraphRange.location):\(indicator.paragraphRange.length)"
            guard seenParagraphs.insert(paragraphKey).inserted else {
                return true
            }

            let glyph = indicator.isFolded ? "\u{25B6}" : "\u{25BC}"
            let alpha: CGFloat = indicator.isFolded ? 0.7 : 0.35
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: accent.withAlphaComponent(alpha),
            ]
            let glyphSize = (glyph as NSString).size(withAttributes: attrs)
            let drawRect = NSRect(
                x: floor(indicator.lineRect.midX - glyphSize.width / 2),
                y: floor(indicator.lineRect.midY - glyphSize.height / 2),
                width: ceil(glyphSize.width),
                height: ceil(glyphSize.height)
            )
            (glyph as NSString).draw(in: drawRect, withAttributes: attrs)

            return true
        }
    }

    // MARK: - Table Detection Helpers (static, testable)

    static func isTableLine(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 3
    }

    static func isSeparatorLine(_ line: String) -> Bool {
        guard isTableLine(line) else { return false }
        return line.dropFirst().dropLast()
            .split(separator: "|", omittingEmptySubsequences: false)
            .allSatisfy {
                $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" }
            }
    }

    static func pipeCharIndices(in line: String) -> [Int] {
        line.utf16.enumerated().compactMap { $0.element == 0x7C ? $0.offset : nil }
    }

    // MARK: - Checkbox Toggle (Phase 5)

    /// Pure function: given a line string and a character offset within that line,
    /// return the toggled line if offset is within a checkbox marker, else nil.
    static func toggleCheckbox(in line: String, at offset: Int) -> String? {
        let ns = line as NSString
        guard ns.length >= 5 else { return nil }

        // Strip leading whitespace to handle nested task lists
        var leadingCount = 0
        for ch in line {
            if ch == " " || ch == "\t" { leadingCount += 1 } else { break }
        }
        let trimmed = String(line.dropFirst(leadingCount))

        // Find checkbox pattern in trimmed content
        let prefixes = ["- ", "* ", "+ "]
        var bracketStart: Int?
        for pfx in prefixes {
            if trimmed.hasPrefix(pfx) && trimmed.count >= pfx.count + 3 {
                let tns = trimmed as NSString
                let afterPrefix = tns.substring(with: NSRange(location: pfx.count, length: 1))
                if afterPrefix == "[" {
                    bracketStart = pfx.count
                    break
                }
            }
        }

        guard let bStart = bracketStart else { return nil }
        let tns = trimmed as NSString
        guard bStart + 2 < tns.length else { return nil }
        let closing = tns.substring(with: NSRange(location: bStart + 2, length: 1))
        guard closing == "]" else { return nil }

        let marker = tns.substring(with: NSRange(location: bStart + 1, length: 1))
        guard marker == " " || marker == "x" || marker == "X" else { return nil }

        // Adjust offset for leading whitespace and check bracket region
        let adjustedOffset = offset - leadingCount
        guard adjustedOffset >= bStart && adjustedOffset <= bStart + 2 else { return nil }

        // Replace in original string at correct position
        let newMarker = (marker == " ") ? "x" : " "
        let result = NSMutableString(string: line)
        result.replaceCharacters(
            in: NSRange(location: leadingCount + bStart + 1, length: 1),
            with: newMarker
        )
        return result as String
    }

    override func mouseDown(with event: NSEvent) {
        let clickPoint = convert(event.locationInWindow, from: nil)

        guard let tlm = textLayoutManager,
            let contentStorage = tlm.textContentManager as? NSTextContentStorage
        else {
            super.mouseDown(with: event)
            return
        }

        let containerPoint = NSPoint(
            x: clickPoint.x - textContainerOrigin.x,
            y: clickPoint.y - textContainerOrigin.y
        )

        if let frag = tlm.textLayoutFragment(for: containerPoint),
            let elemRange = frag.textElement?.elementRange
        {
            let docStart = contentStorage.documentRange.location
            let paraOffset = contentStorage.offset(from: docStart, to: elemRange.location)
            let paraLength = contentStorage.offset(
                from: elemRange.location, to: elemRange.endLocation)
            let str = string as NSString
            // Guard stale layout: fragment ranges can exceed storage after rapid edits.
            guard paraOffset >= 0, paraLength >= 0,
                paraOffset &+ paraLength <= str.length
            else {
                super.mouseDown(with: event)
                return
            }
            let paraText = str.substring(with: NSRange(location: paraOffset, length: paraLength))
                .trimmingCharacters(in: .newlines)

            // Fold triangle click — gutter area on a heading line
            let fragFrame = frag.layoutFragmentFrame.offsetBy(
                dx: textContainerOrigin.x,
                dy: textContainerOrigin.y
            )
            if let indicator = foldIndicatorLayout(
                for: frag,
                fragFrame: fragFrame,
                contentStorage: contentStorage
            ), indicator.hitRect.contains(clickPoint) {
                onFoldToggle?(indicator.headingOffset)
                return
            }

            // Data detection click
            if let storage = textStorage,
                storage.length > 0,
                paraOffset >= 0, paraOffset < storage.length
            {
                let lineCharIdx =
                    frag.textLineFragments.first?.characterIndex(
                        for:
                            NSPoint(
                                x: containerPoint.x - fragFrame.minX,
                                y: containerPoint.y - fragFrame.minY)
                    ) ?? 0
                let charIdx = min(paraOffset &+ lineCharIdx, storage.length - 1)
                if charIdx < storage.length,
                    let item = storage.attribute(
                        DataDetectionService.detectedDataKey, at: charIdx, effectiveRange: nil)
                        as? DataDetectionService.DetectedItem
                {
                    DataDetectionService.open(item)
                    return
                }
            }

            // Checkbox toggle
            if let lineFrag = frag.textLineFragments.first {
                let localPoint = NSPoint(
                    x: containerPoint.x - fragFrame.minX,
                    y: containerPoint.y - fragFrame.minY
                )
                let charIdx = lineFrag.characterIndex(for: localPoint)

                if let toggled = Self.toggleCheckbox(in: paraText, at: charIdx) {
                    let lineRange = NSRange(location: paraOffset, length: paraText.utf16.count)
                    if shouldChangeText(in: lineRange, replacementString: toggled) {
                        textStorage?.replaceCharacters(in: lineRange, with: toggled)
                        didChangeText()
                    }
                    return
                }
            }
        }

        super.mouseDown(with: event)
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        WritingToolsBridge.appendStandardItems(to: menu, hasSelection: selectedRange().length > 0)

        // Reveal in Graph
        if let pid = pageId {
            menu.addItem(NSMenuItem.separator())
            let graphItem = NSMenuItem(
                title: "Reveal in Graph", action: #selector(contextRevealInGraph(_:)),
                keyEquivalent: "")
            graphItem.image = NSImage(
                systemSymbolName: "point.3.connected.trianglepath.dotted",
                accessibilityDescription: "Graph")
            graphItem.target = self
            graphItem.representedObject = pid
            menu.addItem(graphItem)
        }

        // Set Property
        let propItem = NSMenuItem(
            title: "Set Property\u{2026}", action: #selector(openBlockPropertySheet),
            keyEquivalent: "")
        propItem.image = NSImage(systemSymbolName: "tag", accessibilityDescription: "Property")
        propItem.target = self
        menu.addItem(propItem)

        // Insert submenu
        menu.addItem(NSMenuItem.separator())
        let insertMenu = NSMenu(title: "Insert")
        let tableItem = NSMenuItem(
            title: "Table", action: #selector(insertMarkdownTable(_:)), keyEquivalent: "")
        tableItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Table")
        tableItem.target = self
        insertMenu.addItem(tableItem)

        let imageItem = NSMenuItem(
            title: "Image\u{2026}", action: #selector(insertImage(_:)), keyEquivalent: "")
        imageItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
        imageItem.target = self
        insertMenu.addItem(imageItem)

        let ocrItem = NSMenuItem(
            title: "Extract Text from Image\u{2026}", action: #selector(extractTextFromImage(_:)),
            keyEquivalent: "")
        ocrItem.image = NSImage(
            systemSymbolName: "text.viewfinder", accessibilityDescription: "OCR")
        ocrItem.target = self
        insertMenu.addItem(ocrItem)

        let insertSubmenuItem = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        insertSubmenuItem.submenu = insertMenu
        insertSubmenuItem.image = NSImage(
            systemSymbolName: "plus.circle", accessibilityDescription: "Insert")
        menu.addItem(insertSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        let ideaItem = NSMenuItem(
            title: "New Idea at This Line", action: #selector(createIdeaAtLine), keyEquivalent: "")
        ideaItem.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Idea")
        ideaItem.target = self
        menu.addItem(ideaItem)

        let dumpItem = NSMenuItem(
            title: "New Brain Dump at This Line", action: #selector(createBrainDumpAtLine),
            keyEquivalent: "")
        dumpItem.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Brain Dump")
        dumpItem.target = self
        menu.addItem(dumpItem)

        // AI Assistant submenu
        menu.addItem(NSMenuItem.separator())
        let aiMenu = NSMenu(title: "AI Assistant")
        let hasSelection = selectedRange().length > 0
        if hasSelection {
            aiMenu.addItem(
                makeAIItem("Rewrite", icon: "arrow.triangle.2.circlepath", op: "rewrite"))
            aiMenu.addItem(makeAIItem("Summarize", icon: "text.quote", op: "summarize"))
            aiMenu.addItem(
                makeAIItem("Expand", icon: "arrow.up.left.and.arrow.down.right", op: "expand"))
            aiMenu.addItem(makeAIItem("Simplify", icon: "text.redaction", op: "simplify"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Convert to List", icon: "list.bullet", op: "toList"))
            aiMenu.addItem(makeAIItem("Convert to Table", icon: "tablecells", op: "toTable"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Translate", icon: "character.book.closed", op: "translate"))
        } else {
            aiMenu.addItem(makeAIItem("Continue Writing", icon: "text.append", op: "continue"))
            aiMenu.addItem(makeAIItem("Generate Outline", icon: "list.number", op: "outline"))
            aiMenu.addItem(
                makeAIItem("Suggest Structure", icon: "rectangle.3.group", op: "structure"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(
                makeAIItem("Restructure Note", icon: "arrow.triangle.branch", op: "restructure"))
        }
        let aiSubmenuItem = NSMenuItem(title: "AI Assistant", action: nil, keyEquivalent: "")
        aiSubmenuItem.submenu = aiMenu
        aiSubmenuItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI")
        menu.addItem(aiSubmenuItem)

        return menu
    }

    private func makeAIItem(_ title: String, icon: String, op: String) -> NSMenuItem {
        let item = NSMenuItem(
            title: title, action: #selector(handleAIOperation(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        item.target = self
        item.representedObject = op
        return item
    }

    @objc private func contextRevealInGraph(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? String else { return }
        onOpenInGraph?(pid)
    }

    @objc private func createIdeaAtLine() {
        NotificationCenter.default.post(
            name: Self.createIdeaNotification, object: nil,
            userInfo: pageId.map { ["pageId": $0] }
        )
    }

    @objc private func createBrainDumpAtLine() {
        NotificationCenter.default.post(
            name: Self.createBrainDumpNotification, object: nil,
            userInfo: pageId.map { ["pageId": $0] }
        )
    }

    @objc private func handleAIOperation(_ sender: NSMenuItem) {
        guard let op = sender.representedObject as? String else { return }
        var userInfo: [String: String] = ["operation": op]
        if let pageId { userInfo["pageId"] = pageId }
        let sel = selectedRange()
        if sel.length > 0, let str = string as NSString? {
            userInfo["selectedText"] = str.substring(with: sel)
        }
        if op == "translate" {
            NotificationCenter.default.post(
                name: Self.translateNotification, object: nil, userInfo: userInfo)
            return
        }
        NotificationCenter.default.post(
            name: Self.aiOperationNotification, object: nil, userInfo: userInfo)
    }

    @objc private func openBlockPropertySheet() {
        let nsStr = string as NSString
        let cursorLoc = selectedRange().location
        let lineRange = nsStr.lineRange(for: NSRange(location: cursorLoc, length: 0))
        let lineText = nsStr.substring(with: lineRange).trimmingCharacters(in: .newlines)
        var userInfo: [String: Any] = ["lineText": lineText, "lineRange": lineRange]
        if let pageId { userInfo["pageId"] = pageId }
        NotificationCenter.default.post(
            name: Self.blockPropertyNotification, object: nil, userInfo: userInfo)
    }

    @objc func insertMarkdownTable(_ sender: NSMenuItem) {
        let table =
            MarkdownEditorCommands.markdownTableTemplate.trimmingCharacters(in: .newlines) + "\n"
        let loc = selectedRange().location
        if shouldChangeText(in: NSRange(location: loc, length: 0), replacementString: table) {
            textStorage?.replaceCharacters(in: NSRange(location: loc, length: 0), with: table)
            didChangeText()
            if let cellRange = table.range(of: "cell") {
                let offset = table.distance(from: table.startIndex, to: cellRange.lowerBound)
                setSelectedRange(NSRange(location: loc + offset, length: 4))
            }
        }
    }

    @objc func insertImage(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.insertImageAttachment(from: url)
        }
    }

    func insertImageAttachment(from url: URL) {
        let insertLoc = selectedRange().location
        Task { @MainActor [weak self] in
            guard let self,
                let payload = await NoteImageProcessor.loadDisplayImage(from: url)
            else { return }

            let attachment = NSTextAttachment()
            attachment.image = NSImage(cgImage: payload.cgImage, size: payload.displaySize)

            let attrStr = NSMutableAttributedString(attachment: attachment)
            attrStr.addAttribute(
                NSAttributedString.Key("EpistemosImagePath"),
                value: url.path,
                range: NSRange(location: 0, length: attrStr.length))

            let safeInsertLoc = min(insertLoc, self.string.utf16.count)
            let insertRange = NSRange(location: safeInsertLoc, length: 0)
            if self.shouldChangeText(in: insertRange, replacementString: attrStr.string) {
                self.textStorage?.insert(attrStr, at: safeInsertLoc)
                self.didChangeText()
            }
        }
    }

    @objc func extractTextFromImage(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.performOCR(on: url)
        }
    }

    private func performOCR(on url: URL) {
        let insertLoc = selectedRange().location
        Task { @MainActor [weak self] in
            guard let self,
                let extractedText = await NoteImageProcessor.extractText(from: url)
            else { return }

            let text =
                "\n\n> **Extracted Text:**\n> \(extractedText.replacingOccurrences(of: "\n", with: "\n> "))\n"
            let safeInsertLoc = min(insertLoc, self.string.utf16.count)
            let insertRange = NSRange(location: safeInsertLoc, length: 0)
            if self.shouldChangeText(in: insertRange, replacementString: text) {
                self.textStorage?.replaceCharacters(in: insertRange, with: text)
                self.didChangeText()
            }
        }
    }

    // MARK: - Navigation

    func scrollToCharacterOffset(_ offset: Int) {
        let range = NSRange(location: offset, length: 0)
        scrollRangeToVisible(range)
        setSelectedRange(range)
    }

    // MARK: - Block Move Up/Down (Opt+Arrow)

    static func headingLevelForCommandDigitKeyCode(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: 1
        case 20: 3
        case 21: 4
        default: nil
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Opt+Up: move block up
        if event.keyCode == 126 && flags == .option {
            moveBlockUp()
            return true
        }
        // Opt+Down: move block down
        if event.keyCode == 125 && flags == .option {
            moveBlockDown()
            return true
        }

        // Cmd+Shift+K: delete line
        if event.keyCode == 40 && flags == [.command, .shift] {
            deleteLine()
            return true
        }

        // Formatting shortcuts
        if flags == .command {
            if event.keyCode == 19 {
                UtilityWindowManager.shared.show(.notes)
                return true  // Cmd+2
            }
            if let headingLevel = Self.headingLevelForCommandDigitKeyCode(event.keyCode) {
                insertHeading(level: headingLevel)
                return true
            }
        }
        if flags == [.command, .shift] {
            switch event.keyCode {
            case 37:
                toggleLinePrefix("- ")
                return true  // Cmd+Shift+L (bullet)
            case 24:
                toggleLinePrefix("1. ")
                return true  // Cmd+Shift+= (numbered)
            case 46:
                toggleLinePrefix("- [ ] ")
                return true  // Cmd+Shift+M (task)
            case 39:
                toggleLinePrefix("> ")
                return true  // Cmd+Shift+' (quote)
            case 34:
                wrapSelection("`", "`")
                return true  // Cmd+Shift+I (inline code)
            default: break
            }
        }
        // Cmd+Shift+Enter: insert divider
        if event.keyCode == 36 && flags == [.command, .shift] {
            insertDivider()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    func moveBlockUp() {
        let str = string as NSString
        guard str.length > 0 else { return }
        let sel = selectedRange()
        let curLineRange = str.lineRange(for: sel)
        let curBlock = semanticBlockRange(startingAt: curLineRange, in: str)
        guard curBlock.location > 0 else { return }

        let curIndent = indentLevel(str.substring(with: curLineRange))

        // Walk backward to find previous sibling at same indent level
        var prevSiblingLine: NSRange?
        var pos = curBlock.location - 1
        while pos >= 0 {
            let lr = str.lineRange(for: NSRange(location: pos, length: 0))
            let line = str.substring(with: lr)
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let indent = indentLevel(line)
                if indent == curIndent {
                    prevSiblingLine = lr
                    break
                }
                if indent < curIndent { break }  // First in parent, can't move up
            }
            pos = lr.location - 1
        }
        guard let prevLine = prevSiblingLine else { return }
        let prevBlock = semanticBlockRange(startingAt: prevLine, in: str)

        let prevText = str.substring(with: prevBlock)
        let curText = str.substring(with: curBlock)
        let gapLoc = NSMaxRange(prevBlock)
        let gapLen = curBlock.location - gapLoc
        let gapText =
            gapLen > 0 ? str.substring(with: NSRange(location: gapLoc, length: gapLen)) : ""

        let totalRange = NSRange(
            location: prevBlock.location,
            length: NSMaxRange(curBlock) - prevBlock.location)
        let replacement = curText + gapText + prevText

        if shouldChangeText(in: totalRange, replacementString: replacement) {
            textStorage?.replaceCharacters(in: totalRange, with: replacement)
            didChangeText()
            let newCursorOffset = sel.location - curBlock.location
            setSelectedRange(
                NSRange(location: prevBlock.location + newCursorOffset, length: sel.length))
        }
    }

    func moveBlockDown() {
        let str = string as NSString
        guard str.length > 0 else { return }
        let sel = selectedRange()
        let curLineRange = str.lineRange(for: sel)
        let curBlock = semanticBlockRange(startingAt: curLineRange, in: str)
        let curBlockEnd = NSMaxRange(curBlock)
        guard curBlockEnd < str.length else { return }

        let curIndent = indentLevel(str.substring(with: curLineRange))

        // Walk forward to find next sibling at same indent level
        var nextSiblingLine: NSRange?
        var pos = curBlockEnd
        while pos < str.length {
            let lr = str.lineRange(for: NSRange(location: pos, length: 0))
            let line = str.substring(with: lr)
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let indent = indentLevel(line)
                if indent == curIndent {
                    nextSiblingLine = lr
                    break
                }
                if indent < curIndent { break }  // Last in parent, can't move down
            }
            pos = NSMaxRange(lr)
        }
        guard let nextLine = nextSiblingLine else { return }
        let nextBlock = semanticBlockRange(startingAt: nextLine, in: str)

        let curText = str.substring(with: curBlock)
        let nextText = str.substring(with: nextBlock)
        let gapLoc = curBlockEnd
        let gapLen = nextBlock.location - gapLoc
        let gapText =
            gapLen > 0 ? str.substring(with: NSRange(location: gapLoc, length: gapLen)) : ""

        let totalRange = NSRange(
            location: curBlock.location,
            length: NSMaxRange(nextBlock) - curBlock.location)
        let replacement = nextText + gapText + curText

        if shouldChangeText(in: totalRange, replacementString: replacement) {
            textStorage?.replaceCharacters(in: totalRange, with: replacement)
            didChangeText()
            let newCursorOffset = sel.location - curBlock.location
            let newBlockStart =
                curBlock.location + (nextText as NSString).length + (gapText as NSString).length
            setSelectedRange(NSRange(location: newBlockStart + newCursorOffset, length: sel.length))
        }
    }

    // MARK: - Semantic Block Helpers

    /// Expands a line range to include all contiguous following lines with strictly greater indentation.
    private func semanticBlockRange(startingAt lineRange: NSRange, in str: NSString) -> NSRange {
        let startLine = str.substring(with: lineRange)
        let baseIndent = indentLevel(startLine)
        var blockEnd = NSMaxRange(lineRange)
        while blockEnd < str.length {
            let nextLR = str.lineRange(for: NSRange(location: blockEnd, length: 0))
            let nextLine = str.substring(with: nextLR)
            if nextLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            if indentLevel(nextLine) <= baseIndent { break }
            blockEnd = NSMaxRange(nextLR)
        }
        return NSRange(location: lineRange.location, length: blockEnd - lineRange.location)
    }

    private func indentLevel(_ line: String) -> Int {
        line.prefix(while: { $0 == " " || $0 == "\t" }).count
    }

    private func deleteLine() {
        let str = string as NSString
        guard str.length > 0 else { return }
        let sel = selectedRange()
        let lineRange = str.lineRange(for: sel)
        if shouldChangeText(in: lineRange, replacementString: "") {
            textStorage?.replaceCharacters(in: lineRange, with: "")
            didChangeText()
            setSelectedRange(
                NSRange(location: min(lineRange.location, (string as NSString).length), length: 0))
        }
    }

    // MARK: - Formatting Actions

    func insertHeading(level: Int) {
        guard let edit = MarkdownEditorCommands.setHeading(
            in: string,
            selection: selectedRange(),
            level: level
        ) else {
            return
        }
        _ = MarkdownEditorCommands.apply(edit, to: self)
    }

    func toggleLinePrefix(_ prefix: String) {
        let str = string as NSString
        let sel = selectedRange()
        let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        let lineText = str.substring(with: lineRange)
        let trimmed = lineText.trimmingCharacters(in: .newlines)

        let newLine: String
        let hasSuffix = lineText.hasSuffix("\n")
        if trimmed.hasPrefix(prefix) {
            // Remove prefix
            newLine = String(trimmed.dropFirst(prefix.count)) + (hasSuffix ? "\n" : "")
        } else {
            let clean = MarkdownEditorCommands.strippedLineMarker(from: trimmed)
            newLine = prefix + clean + (hasSuffix ? "\n" : "")
        }

        if shouldChangeText(in: lineRange, replacementString: newLine) {
            textStorage?.replaceCharacters(in: lineRange, with: newLine)
            didChangeText()
        }
    }

    func insertCallout(_ kind: NoteCalloutKind) {
        let sel = selectedRange()
        let template = MarkdownEditorCommands.calloutTemplate(for: kind)
        if shouldChangeText(
            in: NSRange(location: sel.location, length: 0), replacementString: template)
        {
            textStorage?.replaceCharacters(
                in: NSRange(location: sel.location, length: 0), with: template)
            didChangeText()
            setSelectedRange(NSRange(location: sel.location + template.utf16.count, length: 0))
        }
    }

    func wrapSelection(_ before: String, _ after: String) {
        let sel = selectedRange()
        if sel.length > 0 {
            let str = (string as NSString).substring(with: sel)
            let wrapped = before + str + after
            if shouldChangeText(in: sel, replacementString: wrapped) {
                textStorage?.replaceCharacters(in: sel, with: wrapped)
                didChangeText()
                setSelectedRange(
                    NSRange(location: sel.location + before.utf16.count, length: sel.length))
            }
        } else {
            let wrapped = before + after
            if shouldChangeText(in: sel, replacementString: wrapped) {
                textStorage?.replaceCharacters(in: sel, with: wrapped)
                didChangeText()
                setSelectedRange(NSRange(location: sel.location + before.utf16.count, length: 0))
            }
        }
    }

    func insertDivider() {
        let sel = selectedRange()
        let divider = "\n---\n"
        if shouldChangeText(
            in: NSRange(location: sel.location, length: 0), replacementString: divider)
        {
            textStorage?.replaceCharacters(
                in: NSRange(location: sel.location, length: 0), with: divider)
            didChangeText()
            setSelectedRange(NSRange(location: sel.location + divider.utf16.count, length: 0))
        }
    }

    /// Insert a code fence at the cursor.
    func insertCodeFence() {
        let sel = selectedRange()
        let fence = "```\n\n```"
        if shouldChangeText(
            in: NSRange(location: sel.location, length: 0), replacementString: fence)
        {
            textStorage?.replaceCharacters(
                in: NSRange(location: sel.location, length: 0), with: fence)
            didChangeText()
            setSelectedRange(NSRange(location: sel.location + 4, length: 0))
        }
    }
}

@MainActor
final class RenderedTableOverlayManager2 {
    private weak var textView: ProseTextView2?
    private var overlays: [String: NoteEditorRenderedTableHostingView] = [:]
    private var theme: EpistemosTheme
    private var documentMayContainTables = false
    private var scrollRefreshTask: Task<Void, Never>?
    private var textChangeRefreshTask: Task<Void, Never>?
    private var bufferedVisibleCharacterRange: NSRange?
    private var pendingBufferedCharacterRange: NSRange?
    var onDidRefresh: (() -> Void)?

    init(textView: ProseTextView2, theme: EpistemosTheme) {
        self.textView = textView
        self.theme = theme
    }

    func setTheme(_ theme: EpistemosTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        refresh()
    }

    func refreshAfterTextChange() {
        textChangeRefreshTask?.cancel()
        textChangeRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: NoteEditorPerformancePolicy.renderedTableOverlayRefreshDelay)
            guard let self, !Task.isCancelled else { return }
            self.textChangeRefreshTask = nil
            self.scrollRefreshTask?.cancel()
            self.scrollRefreshTask = nil
            self.pendingBufferedCharacterRange = nil
            self.bufferedVisibleCharacterRange = nil
            self.refresh()
        }
    }

    func refreshForScroll() {
        guard let window = currentCharacterWindow() else {
            removeAll()
            return
        }
        if let bufferedVisibleCharacterRange,
           NoteEditorScrollViewport.contains(
            bufferedRange: bufferedVisibleCharacterRange,
            visibleRange: window.visibleRange
           ) {
            return
        }
        pendingBufferedCharacterRange = window.bufferedRange
        guard scrollRefreshTask == nil else { return }
        scrollRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: NoteEditorPerformancePolicy.scrollOverlayRefreshDelay)
            guard let self, !Task.isCancelled else { return }
            let bufferedRange = self.pendingBufferedCharacterRange
            self.pendingBufferedCharacterRange = nil
            self.scrollRefreshTask = nil
            self.refresh(
                recalculateDocumentState: false,
                preferredBufferedCharacterRange: bufferedRange
            )
        }
    }

    func refresh() {
        refresh(recalculateDocumentState: true)
    }

    private func refresh(
        recalculateDocumentState: Bool,
        preferredBufferedCharacterRange: NSRange? = nil
    ) {
        onDidRefresh?()

        guard let textView,
              let textLayoutManager = textView.textLayoutManager,
              let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let storage = textView.textStorage
        else { return }

        let text = storage.string as NSString
        guard text.length > 0 else {
            removeAll()
            return
        }
        if recalculateDocumentState {
            documentMayContainTables = storage.string.contains("|")
            if !documentMayContainTables {
                removeAll()
                return
            }
        } else if !documentMayContainTables && overlays.isEmpty {
            return
        }

        guard let characterWindow = NoteEditorScrollViewport.window(
            in: textView,
            textLayoutManager: textLayoutManager,
            contentStorage: contentStorage,
            length: text.length,
            preferredBufferedRange: preferredBufferedCharacterRange
        ) else {
            removeAll()
            return
        }
        bufferedVisibleCharacterRange = characterWindow.bufferedRange

        let tableRanges = MarkdownTableBlockRanges.ranges(
            in: text,
            intersecting: characterWindow.bufferedRange
        )
        let origin = textView.textContainerOrigin
        let overlayWidth = max(0, textView.bounds.width - origin.x * 2)
        let documentStart = contentStorage.documentRange.location
        var activeKeys = Set<String>()

        for tableRange in tableRanges {
            let key = "\(tableRange.location)"
            activeKeys.insert(key)

            guard let table = MarkdownTableModel.parse(text.substring(with: tableRange)),
                  let frame = Self.frame(
                    for: tableRange,
                    in: textView,
                    textLayoutManager: textLayoutManager,
                    contentStorage: contentStorage,
                    documentStart: documentStart,
                    overlayWidth: overlayWidth
                  )
            else {
                continue
            }

            if let overlay = overlays[key] {
                overlay.update(table: table, theme: theme, frame: frame)
            } else {
                let overlay = NoteEditorRenderedTableHostingView(table: table, theme: theme)
                overlay.update(table: table, theme: theme, frame: frame)
                textView.addSubview(overlay)
                overlays[key] = overlay
            }
        }

        removeMissingOverlays(activeKeys)
    }

    func removeAll() {
        textChangeRefreshTask?.cancel()
        textChangeRefreshTask = nil
        scrollRefreshTask?.cancel()
        scrollRefreshTask = nil
        documentMayContainTables = false
        pendingBufferedCharacterRange = nil
        bufferedVisibleCharacterRange = nil
        for overlay in overlays.values {
            overlay.removeFromSuperview()
        }
        overlays.removeAll()
    }

    private func removeMissingOverlays(_ activeKeys: Set<String>) {
        let staleKeys = overlays.keys.filter { !activeKeys.contains($0) }
        for key in staleKeys {
            overlays[key]?.removeFromSuperview()
            overlays.removeValue(forKey: key)
        }
    }

    private func currentCharacterWindow() -> NoteEditorVisibleCharacterWindow? {
        guard let textView,
              let textLayoutManager = textView.textLayoutManager,
              let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let storage = textView.textStorage
        else { return nil }

        return NoteEditorScrollViewport.window(
            in: textView,
            textLayoutManager: textLayoutManager,
            contentStorage: contentStorage,
            length: storage.length
        )
    }

    private static func frame(
        for tableRange: NSRange,
        in textView: ProseTextView2,
        textLayoutManager: NSTextLayoutManager,
        contentStorage: NSTextContentStorage,
        documentStart: NSTextLocation,
        overlayWidth: CGFloat
    ) -> NSRect? {
        guard overlayWidth > 0 else { return nil }

        let text = textView.string as NSString
        let origin = textView.textContainerOrigin
        var cursor = tableRange.location
        var unionRect = NSRect.null

        while cursor < NSMaxRange(tableRange) {
            let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
            guard let location = contentStorage.location(documentStart, offsetBy: lineRange.location),
                  let fragment = textLayoutManager.textLayoutFragment(for: location)
            else {
                cursor = NSMaxRange(lineRange)
                continue
            }

            unionRect = unionRect.union(fragment.layoutFragmentFrame)
            cursor = NSMaxRange(lineRange)
        }

        guard !unionRect.isNull, unionRect.height > 0 else { return nil }
        return NSRect(
            x: origin.x,
            y: origin.y + unionRect.minY,
            width: overlayWidth,
            height: unionRect.height
        )
    }
}

enum NoteEditorPerformancePolicy {
    static let renderedTableOverlayRefreshDelay: Duration = .milliseconds(120)
    static let scrollOverlayRefreshDelay: Duration = .milliseconds(40)
    static let scrollWorkCoalescingDelay: Duration = .milliseconds(16)
    static let overlayViewportPaddingMultiplier = 1
}

struct NoteEditorVisibleCharacterWindow: Equatable {
    let visibleRange: NSRange
    let bufferedRange: NSRange
}

enum NoteEditorScrollViewport {
    static func window(
        in textView: NSTextView,
        textLayoutManager: NSTextLayoutManager,
        contentStorage: NSTextContentStorage,
        length: Int,
        preferredBufferedRange: NSRange? = nil
    ) -> NoteEditorVisibleCharacterWindow? {
        let visibleRange = visibleCharacterRange(
            in: textView,
            textLayoutManager: textLayoutManager,
            contentStorage: contentStorage,
            length: length
        )
        guard visibleRange.length > 0 else { return nil }

        let bufferedRange = clipped(
            preferredBufferedRange ?? defaultBufferedRange(for: visibleRange, length: length),
            length: length
        )
        return NoteEditorVisibleCharacterWindow(
            visibleRange: visibleRange,
            bufferedRange: bufferedRange
        )
    }

    static func contains(bufferedRange: NSRange, visibleRange: NSRange) -> Bool {
        bufferedRange.location <= visibleRange.location
            && NSMaxRange(bufferedRange) >= NSMaxRange(visibleRange)
    }

    private static func visibleCharacterRange(
        in textView: NSTextView,
        textLayoutManager: NSTextLayoutManager,
        contentStorage: NSTextContentStorage,
        length: Int
    ) -> NSRange {
        let visibleRect = textView.visibleRect
        let origin = textView.textContainerOrigin
        let topPoint = CGPoint(x: 0, y: max(visibleRect.minY - origin.y, 0))
        guard let startFragment = textLayoutManager.textLayoutFragment(for: topPoint),
              let startLocation = startFragment.textElement?.elementRange?.location
        else {
            return NSRange(location: 0, length: 0)
        }

        let documentStart = contentStorage.documentRange.location
        var visibleStart = 0
        var visibleEnd = 0
        var foundStart = false

        textLayoutManager.enumerateTextLayoutFragments(
            from: startLocation,
            options: [.ensuresLayout, .estimatesSize]
        ) { fragment in
            let frame = fragment.layoutFragmentFrame
            let viewY = origin.y + frame.origin.y
            if viewY > visibleRect.maxY {
                return false
            }

            if let elementRange = fragment.textElement?.elementRange {
                let start = contentStorage.offset(from: documentStart, to: elementRange.location)
                let end = contentStorage.offset(from: documentStart, to: elementRange.endLocation)
                if !foundStart {
                    visibleStart = start
                    foundStart = true
                }
                visibleEnd = max(visibleEnd, end)
            }

            return true
        }

        guard foundStart, visibleEnd > visibleStart else {
            return NSRange(location: 0, length: 0)
        }

        return NSRange(
            location: visibleStart,
            length: min(visibleEnd - visibleStart, max(0, length - visibleStart))
        )
    }

    private static func defaultBufferedRange(for visibleRange: NSRange, length: Int) -> NSRange {
        let padding = max(
            visibleRange.length * NoteEditorPerformancePolicy.overlayViewportPaddingMultiplier,
            visibleRange.length
        )
        let location = max(0, visibleRange.location - padding)
        let end = min(length, NSMaxRange(visibleRange) + padding)
        return NSRange(location: location, length: max(0, end - location))
    }

    private static func clipped(_ range: NSRange, length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let location = min(max(range.location, 0), max(length - 1, 0))
        let end = min(length, max(location, NSMaxRange(range)))
        return NSRange(location: location, length: max(0, end - location))
    }
}

// MARK: - NSTextLayoutManagerDelegate (Phase 6)

extension ProseTextView2: NSTextLayoutManagerDelegate {

    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        guard
            let contentStorage = textLayoutManager.textContentManager
                as? NSTextContentStorage
        else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }

        let offset = contentStorage.offset(
            from: textLayoutManager.documentRange.location, to: location
        )
        let line = markdownDelegate.lineIndex(at: offset)

        guard markdownDelegate.paragraphType(at: line) == 6 else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }

        let fragment = MarkdownLayoutFragment(
            textElement: textElement, range: textElement.elementRange)

        // Configure with token data from the block-level cache.
        if let metadata = markdownDelegate.paragraphMetadata(at: line) {
            let languageId = UInt8(metadata & 0xFF)
            if languageId > 0,
                let docString = contentStorage.attributedString?.string as NSString?
            {
                let tokens = markdownDelegate.codeTokensForLine(
                    line, languageId: languageId, documentString: docString
                )
                fragment.configure(
                    tokens: tokens, theme: markdownDelegate.theme, languageId: languageId)
            }
        }

        return fragment
    }
}
