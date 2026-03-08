import AppKit

// MARK: - ProseTextView2
// NSTextView subclass backed by TextKit 2 (NSTextLayoutManager).
// Plain text markdown editor — isRichText = false.
// Phase 1: structural paragraph styling via MarkdownContentStorage delegate.
// Replaces ClickableTextView (TextKit 1) in the new prose editor stack.

final class ProseTextView2: NSTextView {

    /// Delegate that classifies paragraphs via Rust FFI and applies structural styles.
    let markdownDelegate = MarkdownContentStorage()
    private var reparseTask: Task<Void, Never>?
    private var currentActiveLine: Int?

    func applyTheme(_ theme: EpistemosTheme) {
        let foreground = NSColor(theme.foreground)
        backgroundColor = NSColor(theme.background)
        insertionPointColor = foreground
        textColor = foreground

        let bodyFont = NSFont(name: "New York", size: 15) ?? .systemFont(ofSize: 15)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 6

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
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        guard !stillSelecting else { return }
        updateActiveLine()
    }

    private func updateActiveLine() {
        let cursorOffset = selectedRange().location
        let newLine = markdownDelegate.lineIndex(at: cursorOffset)
        guard newLine != currentActiveLine else { return }

        let oldLine = currentActiveLine
        currentActiveLine = newLine
        markdownDelegate.activeLine = newLine

        invalidateParagraphLayout(line: oldLine)
        invalidateParagraphLayout(line: newLine)
    }

    private func invalidateParagraphLayout(line: Int?) {
        guard let line,
              let contentStorage = textLayoutManager?.textContentManager
                  as? NSTextContentStorage,
              let lineRange = markdownDelegate.lineRange(at: line) else { return }

        guard let startLoc = contentStorage.location(
                  contentStorage.documentRange.location,
                  offsetBy: lineRange.location
              ),
              let endLoc = contentStorage.location(
                  startLoc,
                  offsetBy: lineRange.length
              ) else { return }

        guard let textRange = NSTextRange(location: startLoc, end: endLoc) else { return }
        textLayoutManager?.invalidateLayout(for: textRange)
    }

    // MARK: - Live Edit Loop

    override func didChangeText() {
        super.didChangeText()
        markdownDelegate.markDirty()
        scheduleDebouncedReparse()
    }

    private func scheduleDebouncedReparse() {
        reparseTask?.cancel()
        reparseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let self else { return }
            self.reparseAndInvalidate()
        }
    }

    /// Reparse structure and invalidate layout so paragraphs restyle.
    func reparseAndInvalidate() {
        guard let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage else { return }

        markdownDelegate.reparse(text: string)

        // Invalidate the full document so delegate re-provides all paragraphs.
        let fullRange = contentStorage.documentRange
        textLayoutManager?.invalidateLayout(for: fullRange)
    }

    // MARK: - Factory

    /// Create a TextKit 2-backed prose editor in a scroll view.
    /// The MarkdownContentStorage delegate is wired automatically.
    static func makeTextKit2() -> (NSScrollView, ProseTextView2) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

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

        tv.applyTheme(.light)

        // Wire MarkdownContentStorage delegate to the TextKit 2 content storage.
        if let contentStorage = tv.textLayoutManager?.textContentManager
            as? NSTextContentStorage {
            contentStorage.delegate = tv.markdownDelegate
        }

        scrollView.documentView = tv
        return (scrollView, tv)
    }

    // MARK: - Navigation

    func scrollToCharacterOffset(_ offset: Int) {
        let range = NSRange(location: offset, length: 0)
        scrollRangeToVisible(range)
        setSelectedRange(range)
    }
}
