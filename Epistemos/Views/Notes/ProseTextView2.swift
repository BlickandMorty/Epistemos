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

    /// When true, dim all paragraphs except the one containing the insertion point.
    nonisolated(unsafe) var isFocusMode = false

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

        if isFocusMode {
            applyFocusDimming()
        }
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
        var firstNSRange: NSRange   // first fragment's NSRange (for boundary check)
        var lastNSRange: NSRange    // last fragment's NSRange (for boundary check)
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
           let elemRange = frag.textElement?.elementRange {
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

    private func drawTableFills(in dirtyRect: NSRect) {
        guard let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let isDark = markdownDelegate.theme.isDark
        let headerFill = isDark
            ? NSColor.white.withAlphaComponent(0.04)
            : NSColor.black.withAlphaComponent(0.03)

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard let (lineText, nsRange) = self.paragraphInfo(
                for: fragment, contentStorage: contentStorage
            ) else { return true }
            let line = lineText.trimmingCharacters(in: .newlines)

            guard Self.isTableLine(line), !Self.isSeparatorLine(line) else { return true }

            // Header = first data row of a table (previous line is NOT a table line).
            let isHeader: Bool
            if nsRange.location > 0 {
                let prevRange = str.lineRange(for: NSRange(location: nsRange.location - 1, length: 0))
                let prevLine = str.substring(with: prevRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                isHeader = !Self.isTableLine(prevLine)
            } else {
                isHeader = true
            }
            guard isHeader else { return true }

            let pipeIndices = Self.pipeCharIndices(in: line)
            guard let firstLineFrag = fragment.textLineFragments.first,
                  pipeIndices.count >= 2 else { return true }

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

            return true
        }
    }

    private func drawTableGridLines(in dirtyRect: NSRect) {
        guard let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let borderColor = NSColor.separatorColor
        let headerLineColor = NSColor.tertiaryLabelColor

        var tables: [TableRegion] = []
        var current: TableRegion?

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard let (lineText, nsRange) = self.paragraphInfo(
                for: fragment, contentStorage: contentStorage
            ) else {
                if let t = current { tables.append(t); current = nil }
                return true
            }
            let line = lineText.trimmingCharacters(in: .newlines)

            if Self.isTableLine(line) {
                let isSep = Self.isSeparatorLine(line)

                // Track last fragment range for all table lines (data + separator)
                current?.lastNSRange = nsRange

                if isSep {
                    if current != nil {
                        current!.headerBottomY = current!.rowYs.last.map {
                            $0 + (fragFrame.minY - $0)
                        } ?? fragFrame.minY
                        current!.bottom = fragFrame.maxY
                    }
                } else {
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
                            headerBottomY: nil,
                            firstNSRange: nsRange, lastNSRange: nsRange
                        )
                    } else {
                        current!.bottom = fragFrame.maxY
                        if let first = pipeXs.first { current!.left = min(current!.left, first) }
                        if let last = pipeXs.last { current!.right = max(current!.right, last) }
                        current!.rowYs.append(fragFrame.minY)
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

    /// Dim non-active paragraphs via rendering attributes.
    func applyFocusDimming() {
        guard isFocusMode, let tlm = textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else {
            clearFocusDimming()
            return
        }

        let fullDocRange = tlm.documentRange
        let str = string as NSString
        guard str.length > 0 else { return }

        let cursorRange = selectedRange()
        let activeParagraphNSRange = str.paragraphRange(for: cursorRange)

        let dimColor = NSColor.textColor.withAlphaComponent(0.25)

        // Dim entire document
        tlm.setRenderingAttributes([.foregroundColor: dimColor], for: fullDocRange)

        // Restore active paragraph
        if activeParagraphNSRange.length > 0,
           let startLoc = contentStorage.location(
               fullDocRange.location, offsetBy: activeParagraphNSRange.location),
           let endLoc = contentStorage.location(
               startLoc, offsetBy: activeParagraphNSRange.length),
           let activeRange = NSTextRange(location: startLoc, end: endLoc) {
            tlm.setRenderingAttributes([:], for: activeRange)
        }
    }

    /// Clear all focus dimming.
    func clearFocusDimming() {
        guard let tlm = textLayoutManager else { return }
        tlm.setRenderingAttributes([:], for: tlm.documentRange)
    }

    private func drawFoldIndicators(in dirtyRect: NSRect) {
        guard let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage else { return }
        let str = string as NSString
        guard str.length > 0 else { return }

        let isDark = markdownDelegate.theme.isDark
        let accent = MarkdownContentStorage.accentColor(isDark: isDark)

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard let (_, nsRange) = self.paragraphInfo(
                for: fragment, contentStorage: contentStorage
            ) else { return true }

            let lineIdx = self.markdownDelegate.lineIndex(at: nsRange.location)
            guard self.markdownDelegate.paragraphType(at: lineIdx) == 1 else { return true }

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

    // MARK: - Checkbox Toggle (Phase 5)

    /// Pure function: given a line string and a character offset within that line,
    /// return the toggled line if offset is within a checkbox marker, else nil.
    static func toggleCheckbox(in line: String, at offset: Int) -> String? {
        let ns = line as NSString
        guard ns.length >= 5 else { return nil }

        // Find checkbox pattern: "- [ ] ", "* [ ] ", "+ [ ] " or checked variants
        let prefixes = ["- ", "* ", "+ "]
        var bracketStart: Int?
        for pfx in prefixes {
            if line.hasPrefix(pfx) && ns.length >= pfx.count + 3 {
                let afterPrefix = ns.substring(with: NSRange(location: pfx.count, length: 1))
                if afterPrefix == "[" {
                    bracketStart = pfx.count
                    break
                }
            }
        }

        guard let bStart = bracketStart else { return nil }
        guard bStart + 2 < ns.length else { return nil }
        let closing = ns.substring(with: NSRange(location: bStart + 2, length: 1))
        guard closing == "]" else { return nil }

        let marker = ns.substring(with: NSRange(location: bStart + 1, length: 1))
        guard marker == " " || marker == "x" || marker == "X" else { return nil }

        // Check offset is within the bracket region [bStart..bStart+2]
        guard offset >= bStart && offset <= bStart + 2 else { return nil }

        let newMarker = (marker == " ") ? "x" : " "
        let result = NSMutableString(string: line)
        result.replaceCharacters(in: NSRange(location: bStart + 1, length: 1), with: newMarker)
        return result as String
    }

    override func mouseDown(with event: NSEvent) {
        let clickPoint = convert(event.locationInWindow, from: nil)

        if let tlm = textLayoutManager,
           let contentStorage = tlm.textContentManager as? NSTextContentStorage {
            let containerPoint = NSPoint(
                x: clickPoint.x - textContainerOrigin.x,
                y: clickPoint.y - textContainerOrigin.y
            )
            if let frag = tlm.textLayoutFragment(for: containerPoint),
               let lineFrag = frag.textLineFragments.first,
               let elemRange = frag.textElement?.elementRange {
                let docStart = contentStorage.documentRange.location
                let paraOffset = contentStorage.offset(from: docStart, to: elemRange.location)
                let paraLength = contentStorage.offset(from: elemRange.location, to: elemRange.endLocation)
                let str = string as NSString
                let paraText = str.substring(with: NSRange(location: paraOffset, length: paraLength))
                    .trimmingCharacters(in: .newlines)

                let fragFrame = frag.layoutFragmentFrame
                let localPoint = NSPoint(
                    x: containerPoint.x - fragFrame.minX,
                    y: containerPoint.y - fragFrame.minY
                )
                let charIdx = lineFrag.characterIndex(for: localPoint)

                if let toggled = Self.toggleCheckbox(in: paraText, at: charIdx) {
                    let lineRange = NSRange(location: paraOffset, length: paraText.utf16.count)
                    if shouldChangeText(in: lineRange, replacementString: toggled) {
                        (textStorage as? NSTextStorage)?.replaceCharacters(in: lineRange, with: toggled)
                        didChangeText()
                    }
                    return
                }
            }
        }

        super.mouseDown(with: event)
    }

    // MARK: - Navigation

    func scrollToCharacterOffset(_ offset: Int) {
        let range = NSRange(location: offset, length: 0)
        scrollRangeToVisible(range)
        setSelectedRange(range)
    }
}
