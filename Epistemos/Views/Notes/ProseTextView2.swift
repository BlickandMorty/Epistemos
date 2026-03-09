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

    /// Per-page undo manager, set by Coordinator2 on page swap.
    /// When nil, falls back to NSTextView's default undo manager.
    var pageUndoManager: UndoManager?

    /// Page ID for scoping notifications to the correct tab.
    var pageId: String?

    /// Closure called when user clicks a heading fold triangle. Receives the heading character offset.
    var onFoldToggle: ((Int) -> Void)?

    /// Closure called when user selects "Open in Graph" from context menu.
    var onOpenInGraph: ((String) -> Void)?

    // MARK: - Notifications (same names as ClickableTextView for NotePageContent compatibility)
    static let createIdeaNotification = Notification.Name("EpistemosCreateIdeaAtLine")
    static let createBrainDumpNotification = Notification.Name("EpistemosCreateBrainDumpAtLine")
    static let aiOperationNotification = Notification.Name("EpistemosAIOperation")
    static let blockPropertyNotification = Notification.Name("EpistemosBlockPropertyEdit")
    static let translateNotification = Notification.Name("EpistemosTranslateText")
    static let scrollToOffsetNotification = Notification.Name("EpistemosScrollToOffset")

    override var undoManager: UndoManager? {
        pageUndoManager ?? super.undoManager
    }

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
        updateVisibleLineRange()

        // Invalidate the full document so delegate re-provides all paragraphs.
        let fullRange = contentStorage.documentRange
        textLayoutManager?.invalidateLayout(for: fullRange)
    }

    // MARK: - Viewport Tracking (Phase 6)

    func updateVisibleLineRange() {
        guard let tlm = textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else { return }
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds

        let startPoint = CGPoint(x: 0, y: max(visibleRect.minY - textContainerOrigin.y, 0))
        let endPoint = CGPoint(x: 0, y: visibleRect.maxY - textContainerOrigin.y)

        var startLine = 0
        var endLine = markdownDelegate.lineCount

        if let startFrag = tlm.textLayoutFragment(for: startPoint) {
            let startRange = startFrag.rangeInElement
            let offset = contentStorage.offset(from: tlm.documentRange.location, to: startRange.location)
            startLine = markdownDelegate.lineIndex(at: offset)
        }

        if let endFrag = tlm.textLayoutFragment(for: endPoint) {
            let endRange = endFrag.rangeInElement
            let offset = contentStorage.offset(from: tlm.documentRange.location, to: endRange.location)
            endLine = markdownDelegate.lineIndex(at: offset)
        }

        markdownDelegate.visibleLineRange = startLine..<(endLine + 1)
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

        // Wire MarkdownContentStorage as delegate for BOTH TextKit 2 delegate roles.
        // NSTextContentStorage overrides the `delegate` property from NSTextContentManager,
        // creating separate slots for NSTextContentStorageDelegate (paragraph styling) and
        // NSTextContentManagerDelegate (shouldEnumerate for fold filtering).
        if let contentStorage = tv.textLayoutManager?.textContentManager
            as? NSTextContentStorage {
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
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak tv] _ in
            tv?.updateVisibleLineRange()
        }

        scrollView.documentView = tv
        return (scrollView, tv)
    }

    // MARK: - Custom Drawing (Phase 4)

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawCalloutBackgrounds(in: rect)
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

    private func drawCalloutBackgrounds(in dirtyRect: NSRect) {
        guard let contentStorage = textLayoutManager?.textContentManager
                as? NSTextContentStorage else { return }
        guard (string as NSString).length > 0 else { return }

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard let (_, nsRange) = self.paragraphInfo(
                for: fragment, contentStorage: contentStorage
            ) else { return true }

            let lineIdx = self.markdownDelegate.lineIndex(at: nsRange.location)
            guard self.markdownDelegate.paragraphType(at: lineIdx) == 5 else { return true }

            guard let metadata = self.markdownDelegate.paragraphMetadata(at: lineIdx) else { return true }
            let calloutTypeId = UInt8((metadata >> 8) & 0xFF)
            guard let callout = self.markdownDelegate.theme.calloutColors(typeId: calloutTypeId) else {
                return true
            }

            // Background fill
            let bgRect = NSRect(
                x: fragFrame.minX + 16,
                y: fragFrame.minY,
                width: fragFrame.width - 16,
                height: fragFrame.height
            )
            callout.background.setFill()
            bgRect.fill()

            // Left accent border (3pt wide)
            let borderRect = NSRect(
                x: fragFrame.minX + 16,
                y: fragFrame.minY,
                width: 3,
                height: fragFrame.height
            )
            callout.accent.setFill()
            borderRect.fill()

            return true
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
        guard (string as NSString).length > 0 else { return }

        let isDark = markdownDelegate.theme.isDark
        let accent = MarkdownContentStorage.accentColor(isDark: isDark)

        enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
            guard let (_, nsRange) = self.paragraphInfo(
                for: fragment, contentStorage: contentStorage
            ) else { return true }

            let lineIdx = self.markdownDelegate.lineIndex(at: nsRange.location)
            guard self.markdownDelegate.paragraphType(at: lineIdx) == 1 else { return true }

            let isFolded = markdown_is_folded(UInt32(lineIdx))

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
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else {
            super.mouseDown(with: event)
            return
        }

        let containerPoint = NSPoint(
            x: clickPoint.x - textContainerOrigin.x,
            y: clickPoint.y - textContainerOrigin.y
        )

        if let frag = tlm.textLayoutFragment(for: containerPoint),
           let elemRange = frag.textElement?.elementRange {
            let docStart = contentStorage.documentRange.location
            let paraOffset = contentStorage.offset(from: docStart, to: elemRange.location)
            let paraLength = contentStorage.offset(from: elemRange.location, to: elemRange.endLocation)
            let str = string as NSString
            let paraText = str.substring(with: NSRange(location: paraOffset, length: paraLength))
                .trimmingCharacters(in: .newlines)

            // Fold triangle click — gutter area on a heading line
            let fragFrame = frag.layoutFragmentFrame
            let lineLeft = fragFrame.minX + textContainerOrigin.x
            if clickPoint.x < lineLeft + 6 && clickPoint.x > lineLeft - 30 {
                if paraText.hasPrefix("#") && paraText.contains(" ") {
                    var hashCount = 0
                    for ch in paraText { if ch == "#" { hashCount += 1 } else { break } }
                    if hashCount >= 1 && hashCount <= 6 {
                        onFoldToggle?(paraOffset)
                        return
                    }
                }
            }

            // Data detection click
            if let storage = textStorage,
               storage.length > 0,
               paraOffset < storage.length {
                let charIdx = min(paraOffset + Int(frag.textLineFragments.first?.characterIndex(for:
                    NSPoint(x: containerPoint.x - fragFrame.minX, y: containerPoint.y - fragFrame.minY)
                ) ?? 0), storage.length - 1)
                if charIdx < storage.length,
                   let item = storage.attribute(DataDetectionService.detectedDataKey, at: charIdx, effectiveRange: nil) as? DataDetectionService.DetectedItem {
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
                        (textStorage as? NSTextStorage)?.replaceCharacters(in: lineRange, with: toggled)
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

        // Reveal in Graph
        if let pid = pageId {
            menu.addItem(NSMenuItem.separator())
            let graphItem = NSMenuItem(title: "Reveal in Graph", action: #selector(contextRevealInGraph(_:)), keyEquivalent: "")
            graphItem.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Graph")
            graphItem.target = self
            graphItem.representedObject = pid
            menu.addItem(graphItem)
        }

        // Set Property
        let propItem = NSMenuItem(title: "Set Property\u{2026}", action: #selector(openBlockPropertySheet), keyEquivalent: "")
        propItem.image = NSImage(systemSymbolName: "tag", accessibilityDescription: "Property")
        propItem.target = self
        menu.addItem(propItem)

        // Insert submenu
        menu.addItem(NSMenuItem.separator())
        let insertMenu = NSMenu(title: "Insert")
        let tableItem = NSMenuItem(title: "Table", action: #selector(insertMarkdownTable(_:)), keyEquivalent: "")
        tableItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Table")
        tableItem.target = self
        insertMenu.addItem(tableItem)
        let insertSubmenuItem = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        insertSubmenuItem.submenu = insertMenu
        insertSubmenuItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Insert")
        menu.addItem(insertSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        let ideaItem = NSMenuItem(title: "New Idea at This Line", action: #selector(createIdeaAtLine), keyEquivalent: "")
        ideaItem.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Idea")
        ideaItem.target = self
        menu.addItem(ideaItem)

        let dumpItem = NSMenuItem(title: "New Brain Dump at This Line", action: #selector(createBrainDumpAtLine), keyEquivalent: "")
        dumpItem.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Brain Dump")
        dumpItem.target = self
        menu.addItem(dumpItem)

        // AI Assistant submenu
        menu.addItem(NSMenuItem.separator())
        let aiMenu = NSMenu(title: "AI Assistant")
        let hasSelection = selectedRange().length > 0
        if hasSelection {
            aiMenu.addItem(makeAIItem("Rewrite", icon: "arrow.triangle.2.circlepath", op: "rewrite"))
            aiMenu.addItem(makeAIItem("Summarize", icon: "text.quote", op: "summarize"))
            aiMenu.addItem(makeAIItem("Expand", icon: "arrow.up.left.and.arrow.down.right", op: "expand"))
            aiMenu.addItem(makeAIItem("Simplify", icon: "text.redaction", op: "simplify"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Convert to List", icon: "list.bullet", op: "toList"))
            aiMenu.addItem(makeAIItem("Convert to Table", icon: "tablecells", op: "toTable"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Translate", icon: "character.book.closed", op: "translate"))
        } else {
            aiMenu.addItem(makeAIItem("Continue Writing", icon: "text.append", op: "continue"))
            aiMenu.addItem(makeAIItem("Generate Outline", icon: "list.number", op: "outline"))
            aiMenu.addItem(makeAIItem("Suggest Structure", icon: "rectangle.3.group", op: "structure"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Restructure Note", icon: "arrow.triangle.branch", op: "restructure"))
        }
        let aiSubmenuItem = NSMenuItem(title: "AI Assistant", action: nil, keyEquivalent: "")
        aiSubmenuItem.submenu = aiMenu
        aiSubmenuItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI")
        menu.addItem(aiSubmenuItem)

        return menu
    }

    private func makeAIItem(_ title: String, icon: String, op: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleAIOperation(_:)), keyEquivalent: "")
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
            NotificationCenter.default.post(name: Self.translateNotification, object: nil, userInfo: userInfo)
            return
        }
        NotificationCenter.default.post(name: Self.aiOperationNotification, object: nil, userInfo: userInfo)
    }

    @objc private func openBlockPropertySheet() {
        let nsStr = string as NSString
        let cursorLoc = selectedRange().location
        let lineRange = nsStr.lineRange(for: NSRange(location: cursorLoc, length: 0))
        let lineText = nsStr.substring(with: lineRange).trimmingCharacters(in: .newlines)
        var userInfo: [String: Any] = ["lineText": lineText, "lineRange": lineRange]
        if let pageId { userInfo["pageId"] = pageId }
        NotificationCenter.default.post(name: Self.blockPropertyNotification, object: nil, userInfo: userInfo)
    }

    @objc private func insertMarkdownTable(_ sender: NSMenuItem) {
        let table = "| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n|  |  |  |\n"
        let loc = selectedRange().location
        if shouldChangeText(in: NSRange(location: loc, length: 0), replacementString: table) {
            textStorage?.replaceCharacters(in: NSRange(location: loc, length: 0), with: table)
            didChangeText()
            setSelectedRange(NSRange(location: loc + "| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n| ".count, length: 0))
        }
    }

    // MARK: - Navigation

    func scrollToCharacterOffset(_ offset: Int) {
        let range = NSRange(location: offset, length: 0)
        scrollRangeToVisible(range)
        setSelectedRange(range)
    }
}

// MARK: - NSTextLayoutManagerDelegate (Phase 6)

extension ProseTextView2: NSTextLayoutManagerDelegate {

    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        guard let contentStorage = textLayoutManager.textContentManager
                as? NSTextContentStorage else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }

        let offset = contentStorage.offset(
            from: textLayoutManager.documentRange.location, to: location
        )
        let line = markdownDelegate.lineIndex(at: offset)

        guard markdownDelegate.paragraphType(at: line) == 6 else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }

        let fragment = MarkdownLayoutFragment(textElement: textElement, range: textElement.elementRange)

        // Configure with token data from the block-level cache.
        if let metadata = markdownDelegate.paragraphMetadata(at: line) {
            let languageId = UInt8(metadata & 0xFF)
            if languageId > 0,
               let docString = contentStorage.attributedString?.string as NSString? {
                let tokens = markdownDelegate.codeTokensForLine(
                    line, languageId: languageId, documentString: docString
                )
                fragment.configure(tokens: tokens, theme: markdownDelegate.theme, languageId: languageId)
            }
        }

        return fragment
    }
}
