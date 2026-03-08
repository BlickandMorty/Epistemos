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

    // MARK: - Custom Drawing (Phase 4)

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawTableFills(in: rect)
        drawTableGridLines(in: rect)
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
    }

    /// Get paragraph text and NSRange for a layout fragment.
    private func paragraphInfo(
        for fragment: NSTextLayoutFragment,
        contentStorage: NSTextContentStorage
    ) -> (text: String, nsRange: NSRange)? {
        guard let textParagraph = fragment.textElement as? NSTextParagraph,
              let elementRange = textParagraph.elementRange else { return nil }
        let docStart = contentStorage.documentRange.location
        let offset = contentStorage.offset(from: docStart, to: elementRange.location)
        let length = contentStorage.offset(from: elementRange.location, to: elementRange.endLocation)
        return (textParagraph.attributedString.string, NSRange(location: offset, length: length))
    }

    private func drawTableFills(in dirtyRect: NSRect) {
        guard let tlm = textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let isDark = markdownDelegate.theme.isDark
        let headerFill = isDark
            ? NSColor.white.withAlphaComponent(0.04)
            : NSColor.black.withAlphaComponent(0.03)
        let origin = textContainerOrigin

        var inTable = false

        tlm.enumerateTextLayoutFragments(
            from: tlm.documentRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let fragFrame = fragment.layoutFragmentFrame.offsetBy(dx: origin.x, dy: origin.y)

            guard let (lineText, _) = self.paragraphInfo(for: fragment, contentStorage: contentStorage) else {
                inTable = false
                return true
            }
            let line = lineText.trimmingCharacters(in: .newlines)

            if Self.isTableLine(line) {
                if !Self.isSeparatorLine(line) && !inTable {
                    // First non-separator data row = header → fill
                    let pipeIndices = Self.pipeCharIndices(in: line)
                    if let firstLineFrag = fragment.textLineFragments.first, pipeIndices.count >= 2 {
                        let firstPipeX = firstLineFrag.locationForCharacter(at: pipeIndices[0]).x
                        let lastPipeX = firstLineFrag.locationForCharacter(at: pipeIndices.last!).x

                        let fillRect = NSRect(
                            x: fragFrame.minX + firstPipeX - 1,
                            y: fragFrame.minY,
                            width: lastPipeX - firstPipeX + 2,
                            height: fragFrame.height
                        )
                        headerFill.setFill()
                        fillRect.fill()
                    }
                    inTable = true
                }
            } else {
                inTable = false
            }

            return true
        }
    }

    private func drawTableGridLines(in dirtyRect: NSRect) {
        guard let tlm = textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let borderColor = NSColor.separatorColor
        let headerLineColor = NSColor.tertiaryLabelColor
        let origin = textContainerOrigin

        var tables: [TableRegion] = []
        var current: TableRegion?

        tlm.enumerateTextLayoutFragments(
            from: tlm.documentRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let fragFrame = fragment.layoutFragmentFrame.offsetBy(dx: origin.x, dy: origin.y)

            guard let (lineText, _) = self.paragraphInfo(for: fragment, contentStorage: contentStorage) else {
                if let t = current { tables.append(t); current = nil }
                return true
            }
            let line = lineText.trimmingCharacters(in: .newlines)

            if Self.isTableLine(line) {
                let isSep = Self.isSeparatorLine(line)

                if isSep {
                    if current != nil {
                        current!.headerBottomY = current!.rowYs.last.map {
                            $0 + (fragFrame.minY - $0)
                        } ?? fragFrame.minY
                        current!.bottom = fragFrame.maxY
                    }
                } else {
                    // Data row — compute pipe x-positions
                    var pipeXs: [CGFloat] = []
                    if let firstLineFrag = fragment.textLineFragments.first {
                        let pipeIndices = Self.pipeCharIndices(in: line)
                        for idx in pipeIndices {
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
                            headerBottomY: nil
                        )
                    } else {
                        current!.bottom = fragFrame.maxY
                        if let first = pipeXs.first { current!.left = min(current!.left, first) }
                        if let last = pipeXs.last { current!.right = max(current!.right, last) }
                        current!.rowYs.append(fragFrame.minY)
                        // Weighted average for column alignment across rows
                        if pipeXs.count == current!.columnXs.count {
                            for i in current!.columnXs.indices {
                                current!.columnXs[i] = (current!.columnXs[i] * 0.7) + (pipeXs[i] * 0.3)
                            }
                        }
                    }
                }
            } else {
                if let t = current { tables.append(t); current = nil }
            }

            return true
        }
        if let t = current { tables.append(t) }

        // Draw all collected table regions
        for table in tables {
            let outerRect = NSRect(
                x: table.left - 2, y: table.top - 1,
                width: table.right - table.left + 4,
                height: table.bottom - table.top + 2
            )

            // Outer border
            borderColor.setStroke()
            let outerPath = NSBezierPath(rect: outerRect)
            outerPath.lineWidth = 0.5
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
                innerPath.move(to: NSPoint(x: table.left - 2, y: y))
                innerPath.line(to: NSPoint(x: table.right + 2, y: y))
            }
            innerPath.stroke()

            // Header underline — stronger
            if let headerY = table.headerBottomY {
                headerLineColor.setStroke()
                let headerPath = NSBezierPath()
                headerPath.lineWidth = 1.0
                headerPath.move(to: NSPoint(x: table.left - 2, y: headerY))
                headerPath.line(to: NSPoint(x: table.right + 2, y: headerY))
                headerPath.stroke()
            }
        }
    }

    private func drawFoldIndicators(in dirtyRect: NSRect) {
        guard let tlm = textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let isDark = markdownDelegate.theme.isDark
        let accent = MarkdownContentStorage.accentColor(isDark: isDark)
        let origin = textContainerOrigin

        tlm.enumerateTextLayoutFragments(
            from: tlm.documentRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let fragFrame = fragment.layoutFragmentFrame.offsetBy(dx: origin.x, dy: origin.y)

            guard let (_, nsRange) = self.paragraphInfo(for: fragment, contentStorage: contentStorage) else {
                return true
            }

            let lineIdx = self.markdownDelegate.lineIndex(at: nsRange.location)
            guard self.markdownDelegate.paragraphType(at: lineIdx) == 1 else { return true }

            // Check fold state: next line is "…"
            let isFolded: Bool
            let nextLineStart = NSMaxRange(nsRange)
            if nextLineStart < str.length {
                let nextLineRange = str.lineRange(for: NSRange(location: nextLineStart, length: 0))
                let nextLine = str.substring(with: nextLineRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                isFolded = nextLine == "\u{2026}"
            } else {
                isFolded = false
            }

            let size: CGFloat = 10
            let x = fragFrame.minX - 20
            let y = fragFrame.midY - size / 2

            let glyph = isFolded ? "\u{25B6}" : "\u{25BC}"
            let alpha: CGFloat = isFolded ? 0.7 : 0.35
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: accent.withAlphaComponent(alpha)
            ]
            (glyph as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

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
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
    }

    static func pipeCharIndices(in line: String) -> [Int] {
        line.utf16.enumerated().compactMap { $0.element == 0x7C ? $0.offset : nil }
    }

    // MARK: - Navigation

    func scrollToCharacterOffset(_ offset: Int) {
        let range = NSRange(location: offset, length: 0)
        scrollRangeToVisible(range)
        setSelectedRange(range)
    }
}
