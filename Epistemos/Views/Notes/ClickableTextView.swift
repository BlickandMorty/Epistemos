import AppKit
import ImageIO
import Quartz
import UniformTypeIdentifiers
import Vision
import Translation

// MARK: - ClickableTextView
// Bare NSTextView subclass with wikilink click handling.
// This is the ONLY NSTextView subclass in the app.
//
// In v3, this sits inside an NSScrollView (created by ProseEditorRepresentable).
// The NSScrollView handles all scrolling natively — no SwiftUI ScrollView wrapping.
// This eliminates the SwiftUI ↔ AppKit layout feedback loop that caused 100% CPU
// on resize/Enter, because NSTextView manages its own height internally.
//
// Pitfall guarantees:
// - #1: No layout() override. EVER.
// - #2: draw() clears dirty rect before super.draw(). Required because
//       drawsBackground = false (for SwiftUI theme transparency). Without
//       clearing, old glyph images persist as ghost artifacts at scroll edges.
//       CGContext.clear is a cheap memset, not a draw call.
// - #9: Deferred reflow — text freezes during live resize (window drag / sidebar drag).
//       Reflows once on mouse-up. Same technique Apple Notes uses.

final class ClickableTextView: NSTextView {

    // MARK: - Notifications (Right-Click → Ideas / Brain Dumps / AI)
    // Posted when user selects context menu actions.
    // NoteTabView observes these to open IdeasPanel or trigger Note Chat.
    static let createIdeaNotification = Notification.Name("EpistemosCreateIdeaAtLine")
    static let createBrainDumpNotification = Notification.Name("EpistemosCreateBrainDumpAtLine")
    /// AI operation from context menu. userInfo: ["operation": String, "selectedText": String?]
    static let aiOperationNotification = Notification.Name("EpistemosAIOperation")
    /// Block property edit from context menu. userInfo: ["lineText": String, "lineRange": NSRange, "pageId": String?]
    static let blockPropertyNotification = Notification.Name("EpistemosBlockPropertyEdit")
    static let translateNotification = Notification.Name("EpistemosTranslateText")
    static let scrollToOffsetNotification = Notification.Name("EpistemosScrollToOffset")

    // MARK: - Wikilink Click Handling
    // Wikilinks and block refs use native .link attributes with custom URL schemes
    // (wikilink:// and blockref://). Click handling is in the NSTextViewDelegate
    // (ProseEditorRepresentable.Coordinator.textView(_:clickedOnLink:at:)).

    /// Closure called when user selects "Open in Graph" from context menu.
    /// Receives a page ID (current note or wikilink target).
    var onOpenInGraph: ((String) -> Void)?

    /// Page ID for scoping notifications to the correct tab.
    var pageId: String?

    nonisolated(unsafe) var usesRenderedTableOverlays = false

    /// When true, dim all paragraphs except the one containing the insertion point.
    nonisolated(unsafe) var isFocusMode = false

    // MARK: - Per-Page Undo Manager
    // Override the default undo manager (which comes from the window's responder chain)
    // so each page has its own isolated undo history. Set by the Coordinator on page swap.
    var pageUndoManager: UndoManager?

    override var undoManager: UndoManager? {
        pageUndoManager ?? super.undoManager
    }

    // MARK: - Deferred Reflow (Pitfall #9)
    // During live resize, freeze the text container width so NSLayoutManager
    // doesn't reflow O(document) on every frame. Reflow once on mouse-up.

    private var frozenWidth: CGFloat?

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        // Freeze: stop the text container from tracking the view width
        textContainer?.widthTracksTextView = false
        frozenWidth = textContainer?.containerSize.width
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        // Unfreeze: let the text container track width again, reflow once
        textContainer?.widthTracksTextView = true
        let newWidth = bounds.width - (textContainerInset.width * 2)
        textContainer?.containerSize = NSSize(width: max(newWidth, 0),
                                              height: CGFloat.greatestFiniteMagnitude)
        frozenWidth = nil
    }

    // MARK: - Pitfall #1: NEVER override layout()
    // layout() fires on every @Observable mutation anywhere in the app.
    // Calling ensureLayout() here causes O(document) text layout per SwiftUI pass.

    // MARK: - Ghost Line Fix (drawsBackground = false requires manual clear)

    override func draw(_ dirtyRect: NSRect) {
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.clear(dirtyRect)
        }
        super.draw(dirtyRect)
    }

    // MARK: - Table Background Fills (drawn BEHIND text)

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawBlockChrome(in: rect)
        if !usesRenderedTableOverlays {
            drawTableFills(in: rect)
            drawTableGridLines(in: rect)
        }
        drawFoldIndicators(in: rect)
    }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?)
        -> Bool
    {
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
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    private func applyAutomaticMarkdownEdit(_ edit: MarkdownEditorCommands.TextEdit) -> Bool {
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

    private func drawTableFills(in dirtyRect: NSRect) {
        guard let lm = layoutManager, let tc = textContainer, let storage = textStorage else { return }
        let str = storage.string as NSString
        guard str.length > 0 else { return }

        let visibleGlyphs = lm.glyphRange(forBoundingRect: dirtyRect, in: tc)
        let charRange = lm.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let origin = textContainerOrigin

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        // Apple Notes style: subtle gray header fill, no alternating row colors
        let headerFill = isDark
            ? NSColor.white.withAlphaComponent(0.04)
            : NSColor.black.withAlphaComponent(0.03)

        var lineStart = charRange.location
        var inTable = false

        while lineStart < NSMaxRange(charRange) {
            let lineRange = str.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = str.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let isTableLine = line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 3

            if isTableLine {
                let isSep = line.dropFirst().dropLast()
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }

                if !isSep {
                    let gi = lm.glyphIndexForCharacter(at: lineRange.location)
                    let fragRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: nil,
                                                       withoutAdditionalLayout: true)

                    var firstPipeX = fragRect.minX
                    var lastPipeX = fragRect.maxX
                    for (offset, ch) in line.utf16.enumerated() where ch == 0x7C {
                        let ci = lineRange.location + offset
                        if ci < str.length {
                            let pgi = lm.glyphIndexForCharacter(at: ci)
                            let loc = lm.location(forGlyphAt: pgi)
                            let x = fragRect.minX + loc.x
                            if offset == 0 { firstPipeX = x }
                            lastPipeX = x
                        }
                    }

                    // Only fill the header row
                    if !inTable {
                        let fillRect = NSRect(
                            x: firstPipeX + origin.x - 1,
                            y: fragRect.minY + origin.y,
                            width: lastPipeX - firstPipeX + 2,
                            height: fragRect.height
                        )
                        headerFill.setFill()
                        fillRect.fill()
                        inTable = true
                    }
                }
            } else {
                inTable = false
            }

            lineStart = NSMaxRange(lineRange)
        }
    }

    private func drawBlockChrome(in dirtyRect: NSRect) {
        guard let lm = layoutManager, let tc = textContainer, let storage = textStorage else { return }
        let str = storage.string as NSString
        guard str.length > 0 else { return }

        let visibleGlyphs = lm.glyphRange(forBoundingRect: dirtyRect, in: tc)
        let charRange = lm.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let origin = textContainerOrigin
        let attributedString = storage as NSAttributedString
        var seenSpans = Set<String>()
        let chromeFrame = MarkdownTextStorage.blockChromeFrame(
            textContainerOrigin: origin,
            containerWidth: tc.containerSize.width,
            boundsWidth: bounds.width
        )
        guard chromeFrame.width > 0 else { return }

        var lineStart = charRange.location
        while lineStart < NSMaxRange(charRange) {
            let lineRange = str.lineRange(for: NSRange(location: lineStart, length: 0))
            if let span = MarkdownTextStorage.blockChromeSpan(
                in: attributedString,
                text: str,
                aroundLineRange: lineRange
            ) {
                let spanKey = "\(span.kind.rawValue):\(span.lineRange.location):\(span.lineRange.length)"
                if seenSpans.insert(spanKey).inserted {
                    let styledRange = MarkdownTextStorage.blockChromeStyleRange(
                        in: str,
                        lineRange: span.lineRange
                    )
                    if styledRange.length > 0 {
                        let glyphRange = lm.glyphRange(
                            forCharacterRange: styledRange,
                            actualCharacterRange: nil
                        )
                        let fragmentRect = lm.boundingRect(
                            forGlyphRange: glyphRange,
                            in: tc
                        ).offsetBy(dx: origin.x, dy: origin.y)
                        let rect = NSRect(
                            x: chromeFrame.minX,
                            y: fragmentRect.minY - 5,
                            width: chromeFrame.width,
                            height: max(0, fragmentRect.height + 10)
                        )
                        if rect.intersects(dirtyRect) {
                            MarkdownTextStorage.drawBlockChrome(
                                kind: span.kind,
                                fill: span.fill,
                                accent: span.accent,
                                in: rect
                            )
                        }
                    }
                }
                lineStart = NSMaxRange(span.lineRange)
                continue
            }
            lineStart = NSMaxRange(lineRange)
        }
    }

    // MARK: - Table Grid Lines (drawn BEHIND text via NSBezierPath)

    private func drawTableGridLines(in dirtyRect: NSRect) {
        guard let lm = layoutManager, let tc = textContainer, let storage = textStorage else { return }
        let str = storage.string as NSString
        guard str.length > 0 else { return }

        let visibleGlyphs = lm.glyphRange(forBoundingRect: dirtyRect, in: tc)
        let charRange = lm.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let origin = textContainerOrigin

        // Apple Notes style: uniform system gray borders
        let borderColor = NSColor.separatorColor
        let headerLineColor = NSColor.tertiaryLabelColor

        struct TableRegion {
            var top: CGFloat
            var bottom: CGFloat
            var left: CGFloat
            var right: CGFloat
            var columnXs: [CGFloat]
            var rowYs: [CGFloat]
            var headerBottomY: CGFloat?
        }

        var tables: [TableRegion] = []
        var current: TableRegion?

        var lineStart = charRange.location
        while lineStart < NSMaxRange(charRange) {
            let lineRange = str.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = str.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let isTableLine = line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 3

            if isTableLine {
                let glyphIdx = lm.glyphIndexForCharacter(at: lineRange.location)
                let lineFragRect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil,
                                                       withoutAdditionalLayout: true)
                    .offsetBy(dx: origin.x, dy: origin.y)

                let isSep = line.dropFirst().dropLast()
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }

                if isSep {
                    if current != nil {
                        current!.headerBottomY = current!.rowYs.last.map { $0 + (lineFragRect.minY - $0) } ?? lineFragRect.minY
                        current!.bottom = lineFragRect.maxY
                    }
                } else {
                    var pipeXs: [CGFloat] = []
                    for (offset, ch) in line.utf16.enumerated() where ch == 0x7C {
                        let charIdx = lineRange.location + offset
                        if charIdx < str.length {
                            let gi = lm.glyphIndexForCharacter(at: charIdx)
                            let loc = lm.location(forGlyphAt: gi)
                            pipeXs.append(lineFragRect.minX + loc.x)
                        }
                    }

                    if current == nil {
                        current = TableRegion(
                            top: lineFragRect.minY, bottom: lineFragRect.maxY,
                            left: pipeXs.first ?? lineFragRect.minX,
                            right: pipeXs.last ?? lineFragRect.maxX,
                            columnXs: pipeXs, rowYs: [lineFragRect.minY],
                            headerBottomY: nil
                        )
                    } else {
                        current!.bottom = lineFragRect.maxY
                        if let first = pipeXs.first { current!.left = min(current!.left, first) }
                        if let last = pipeXs.last { current!.right = max(current!.right, last) }
                        current!.rowYs.append(lineFragRect.minY)
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
            lineStart = NSMaxRange(lineRange)
        }
        if let t = current { tables.append(t) }

        for table in tables {
            let outerRect = NSRect(
                x: table.left - 2, y: table.top - 1,
                width: table.right - table.left + 4,
                height: table.bottom - table.top + 2
            )

            // Outer border — thin, straight corners (Apple Notes style)
            borderColor.setStroke()
            let outerPath = NSBezierPath(rect: outerRect)
            outerPath.lineWidth = 0.5
            outerPath.stroke()

            // Inner grid — same color, uniform weight
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

            // Header bottom line — slightly stronger
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

    /// Draw disclosure triangles in the gutter next to heading lines.
    private func drawFoldIndicators(in dirtyRect: NSRect) {
        guard let lm = layoutManager, let tc = textContainer, let storage = textStorage else { return }
        let str = storage.string as NSString
        guard str.length > 0 else { return }

        let visibleGlyphs = lm.glyphRange(forBoundingRect: dirtyRect, in: tc)
        let charRange = lm.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let origin = textContainerOrigin

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let accent = MarkdownTextStorage.accentColor(isDark: isDark)

        var lineStart = charRange.location
        while lineStart < NSMaxRange(charRange) {
            let lineRange = str.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = str.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)

            if isHeadingLine(line) {
                let gi = lm.glyphIndexForCharacter(at: lineRange.location)
                let fragRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)

                // Check fold state: next line is "…" marker
                let isFolded: Bool
                let nextLineStart = NSMaxRange(lineRange)
                if nextLineStart < str.length {
                    let nextLineRange = str.lineRange(for: NSRange(location: nextLineStart, length: 0))
                    let nextLine = str.substring(with: nextLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    isFolded = nextLine == "…"
                } else {
                    isFolded = false
                }

                // Draw disclosure triangle
                let size: CGFloat = 10
                let x = fragRect.minX + origin.x - 20
                let y = fragRect.midY + origin.y - size / 2

                let glyph = isFolded ? "▶" : "▼"
                let alpha: CGFloat = isFolded ? 0.7 : 0.35
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: accent.withAlphaComponent(alpha)
                ]
                let str = glyph as NSString
                str.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }

            lineStart = NSMaxRange(lineRange)
            if lineStart == lineRange.location { break }
        }
    }

    // Expand invalidation rects to cover emoji glyph overflow — but ONLY during
    // text edits. During scroll, the system's invalidation rects are already correct
    // and expanding them causes ~2x overdraw (16pt expansion on every scroll step).
    //
    // The emoji overflow issue only occurs when content CHANGES (typing/pasting emoji).
    // During scroll, line fragments are already laid out and emoji is pre-rendered.
    override func setNeedsDisplay(_ invalidRect: NSRect) {
        if let mds = textStorage as? MarkdownTextStorage, mds.isProcessingEdits {
            let expanded = NSRect(
                x: invalidRect.origin.x,
                y: max(0, invalidRect.origin.y - 8),
                width: invalidRect.width,
                height: min(bounds.height - max(0, invalidRect.origin.y - 8),
                            invalidRect.height + 16)
            )
            super.setNeedsDisplay(expanded)
        } else {
            super.setNeedsDisplay(invalidRect)
        }
    }

    override var isOpaque: Bool { false }

    // MARK: - Key Handling

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+Z — Undo
        if flags == .command, event.charactersIgnoringModifiers == "z" {
            if undoManager?.canUndo == true {
                undoManager?.undo()
                return true
            }
            return false
        }

        // Cmd+Shift+Z — Redo
        if flags == [.command, .shift], event.charactersIgnoringModifiers == "Z" {
            if undoManager?.canRedo == true {
                undoManager?.redo()
                return true
            }
            return false
        }

        // Cmd+F — Show Find bar
        if flags == .command, event.charactersIgnoringModifiers == "f" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.showFindInterface.rawValue
            performTextFinderAction(item)
            return true
        }

        // Cmd+G — Find Next
        if flags == .command, event.charactersIgnoringModifiers == "g" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.nextMatch.rawValue
            performTextFinderAction(item)
            return true
        }

        // Cmd+Shift+G — Find Previous
        if flags == [.command, .shift], event.charactersIgnoringModifiers == "G" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.previousMatch.rawValue
            performTextFinderAction(item)
            return true
        }

        // Cmd+Option+F — Show Replace bar
        if flags == [.command, .option], event.charactersIgnoringModifiers == "f" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.showReplaceInterface.rawValue
            performTextFinderAction(item)
            return true
        }

        // Esc — Hide Find bar (if visible)
        if event.keyCode == 53 { // Esc key
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.hideFindInterface.rawValue
            performTextFinderAction(item)
            // Don't return true — let Esc propagate for other uses too
        }

        // Cmd+= / Cmd++ — Zoom In
        if flags == .command, let chars = event.charactersIgnoringModifiers,
           chars == "=" || chars == "+" {
            zoomIn()
            return true
        }

        // Cmd+- — Zoom Out
        if flags == .command, event.charactersIgnoringModifiers == "-" {
            zoomOut()
            return true
        }

        // Cmd+0 — Reset Zoom
        if flags == .command, event.charactersIgnoringModifiers == "0" {
            resetZoom()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - QuickLook Preview (Space on image attachment)

    /// URL of the currently previewed file for QLPreviewPanel.
    nonisolated(unsafe) var quickLookURL: URL?

    override func keyDown(with event: NSEvent) {
        // Space bar on an image attachment → QuickLook preview
        if event.charactersIgnoringModifiers == " ",
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
           let url = imageURLAtCursor() {
            quickLookURL = url
            if QLPreviewPanel.sharedPreviewPanelExists(),
               QLPreviewPanel.shared().isVisible {
                QLPreviewPanel.shared().reloadData()
            } else {
                QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
            }
            return
        }
        super.keyDown(with: event)
    }

    private func imageURLAtCursor() -> URL? {
        let loc = selectedRange().location
        guard loc < (textStorage?.length ?? 0),
              let attrs = textStorage?.attributes(at: loc, effectiveRange: nil),
              let path = attrs[NSAttributedString.Key("EpistemosImagePath")] as? String
        else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = self
            panel.delegate = self
        }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = nil
            panel.delegate = nil
        }
    }

    // MARK: - Zoom (native text scaling — crisp at any level)

    private static let minZoom: CGFloat = 0.5
    private static let maxZoom: CGFloat = 2.0
    private static let zoomStep: CGFloat = 0.1

    /// Current scale factor applied via scaleUnitSquare.
    private var currentScale: CGFloat = 1.0

    override func magnify(with event: NSEvent) {
        let newScale = max(Self.minZoom, min(Self.maxZoom, currentScale + event.magnification))
        applyScale(newScale)
    }

    private func zoomIn() {
        applyScale(min(Self.maxZoom, currentScale + Self.zoomStep))
    }

    private func zoomOut() {
        applyScale(max(Self.minZoom, currentScale - Self.zoomStep))
    }

    private func resetZoom() {
        applyScale(1.0)
    }

    private func applyScale(_ newScale: CGFloat) {
        let factor = newScale / currentScale
        scaleUnitSquare(to: NSSize(width: factor, height: factor))
        currentScale = newScale
        // Resize text container to match new coordinate space
        if let tc = textContainer, let sv = enclosingScrollView {
            let visibleWidth = sv.contentView.bounds.width / currentScale
            tc.containerSize = NSSize(width: max(visibleWidth - textContainerInset.width * 2, 0),
                                      height: CGFloat.greatestFiniteMagnitude)
        }
        needsDisplay = true
        layoutManager?.ensureLayout(for: textContainer!)
    }

    // MARK: - Insert Image

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
            let image = NSImage(cgImage: payload.cgImage, size: payload.displaySize)
            let cell = NSTextAttachmentCell(imageCell: image)
            attachment.attachmentCell = cell

            let attrStr = NSMutableAttributedString(attachment: attachment)
            attrStr.addAttribute(
                NSAttributedString.Key("EpistemosImagePath"),
                value: url.path,
                range: NSRange(location: 0, length: attrStr.length)
            )

            let safeInsertLoc = min(insertLoc, self.string.utf16.count)
            let insertRange = NSRange(location: safeInsertLoc, length: 0)
            if self.shouldChangeText(in: insertRange, replacementString: attrStr.string) {
                self.textStorage?.insert(attrStr, at: safeInsertLoc)
                self.didChangeText()
            }
        }
    }

    // MARK: - Insert Table

    @objc func insertMarkdownTable(_ sender: Any?) {
        let table = MarkdownEditorCommands.markdownTableTemplate
        let insertLoc = selectedRange().location
        let insertRange = NSRange(location: insertLoc, length: 0)
        if shouldChangeText(in: insertRange, replacementString: table) {
            textStorage?.replaceCharacters(in: insertRange, with: table)
            didChangeText()
            // Place cursor in first data cell
            if let offset = table.range(of: "| cell") {
                let charOffset = table.distance(from: table.startIndex, to: offset.lowerBound) + 2
                setSelectedRange(NSRange(location: insertLoc + charOffset, length: 4))
            }
        }
    }

    // MARK: - Drag & Drop Images

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]
        ) as? [URL], let url = fileURLs.first {
            insertImageAttachment(from: url)
            return true
        }
        return super.performDragOperation(sender)
    }

    // MARK: - Vision OCR (Extract Text from Image)

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

    func performOCR(on url: URL) {
        let insertLoc = selectedRange().location
        Task { @MainActor [weak self] in
            guard let self,
                  let extractedText = await NoteImageProcessor.extractText(from: url)
            else { return }

            let text = "\n\n> **Extracted Text:**\n> \(extractedText.replacingOccurrences(of: "\n", with: "\n> "))\n"
            let safeInsertLoc = min(insertLoc, self.string.utf16.count)
            let insertRange = NSRange(location: safeInsertLoc, length: 0)
            if self.shouldChangeText(in: insertRange, replacementString: text) {
                self.textStorage?.replaceCharacters(in: insertRange, with: text)
                self.didChangeText()
            }
        }
    }

    // MARK: - Wikilink Mouse Handling

    /// Closure called when user clicks a heading fold triangle. Receives the heading character offset.
    var onFoldToggle: ((Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let idx = characterIndexForInsertion(at: point)

        // Fold triangle click — left gutter area on a heading line
        if let lm = layoutManager, idx < (string as NSString).length {
            let lineRange = (string as NSString).lineRange(for: NSRange(location: idx, length: 0))
            let line = (string as NSString).substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if isHeadingLine(line) {
                let gi = lm.glyphIndexForCharacter(at: lineRange.location)
                let fragRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
                let origin = textContainerOrigin
                let lineLeft = fragRect.minX + origin.x
                // Click in the gutter area (left of text start, ~30pt zone)
                if point.x < lineLeft + 6 && point.x > lineLeft - 30 {
                    onFoldToggle?(lineRange.location)
                    return
                }
            }
        }

        // Wikilinks and block refs are handled by NSTextView's native link system
        // via the delegate's textView(_:clickedOnLink:at:) method.

        // Data detection: click to open in system app
        if idx < string.utf16.count,
           let attrs = textStorage?.attributes(at: idx, effectiveRange: nil),
           let item = attrs[DataDetectionService.detectedDataKey] as? DataDetectionService.DetectedItem {
            DataDetectionService.open(item)
            return
        }
        super.mouseDown(with: event)
    }

    private func isHeadingLine(_ line: String) -> Bool {
        var count = 0
        for ch in line {
            if ch == "#" { count += 1 }
            else if ch == " " && count > 0 { return count <= 6 }
            else { return false }
        }
        return false
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        WritingToolsBridge.appendStandardItems(to: menu, hasSelection: selectedRange().length > 0)

        // Reveal in Graph
        if let pid = pageId {
            menu.addItem(NSMenuItem.separator())

            let graphItem = NSMenuItem(
                title: "Reveal in Graph",
                action: #selector(contextRevealInGraph(_:)),
                keyEquivalent: ""
            )
            graphItem.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Graph")
            graphItem.target = self
            graphItem.representedObject = pid
            menu.addItem(graphItem)
        }

        // Set Property
        let propItem = NSMenuItem(
            title: "Set Property\u{2026}",
            action: #selector(openBlockPropertySheet),
            keyEquivalent: ""
        )
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

        let imageItem = NSMenuItem(title: "Image\u{2026}", action: #selector(insertImage(_:)), keyEquivalent: "")
        imageItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
        imageItem.target = self
        insertMenu.addItem(imageItem)

        let ocrItem = NSMenuItem(title: "Extract Text from Image\u{2026}", action: #selector(extractTextFromImage(_:)), keyEquivalent: "")
        ocrItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "OCR")
        ocrItem.target = self
        insertMenu.addItem(ocrItem)

        // Continuity Camera — available via system's "Import from iPhone or iPad" in Edit menu.
        // NSTextView provides this automatically through the services responder chain.

        let insertSubmenuItem = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        insertSubmenuItem.submenu = insertMenu
        insertSubmenuItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Insert")
        menu.addItem(insertSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        let ideaItem = NSMenuItem(
            title: "New Idea at This Line",
            action: #selector(createIdeaAtLine),
            keyEquivalent: ""
        )
        ideaItem.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Idea")
        ideaItem.target = self
        menu.addItem(ideaItem)

        let dumpItem = NSMenuItem(
            title: "New Brain Dump at This Line",
            action: #selector(createBrainDumpAtLine),
            keyEquivalent: ""
        )
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

        var userInfo: [String: Any] = [
            "lineText": lineText,
            "lineRange": lineRange
        ]
        if let pageId { userInfo["pageId"] = pageId }
        NotificationCenter.default.post(
            name: Self.blockPropertyNotification, object: nil, userInfo: userInfo
        )
    }

    // MARK: - Focus Mode Dim

    /// Apply temporary foreground attributes to dim non-active paragraphs.
    /// Called by Coordinator on selection change when focus mode is active.
    func applyFocusDimming() {
        guard isFocusMode, let lm = layoutManager, let ts = textStorage else {
            clearFocusDimming()
            return
        }

        let fullRange = NSRange(location: 0, length: ts.length)
        guard fullRange.length > 0 else { return }
        let cursorRange = selectedRange()
        let activeParaRange = (string as NSString).paragraphRange(for: cursorRange)

        lm.addTemporaryAttribute(.foregroundColor,
            value: NSColor.textColor.withAlphaComponent(0.25),
            forCharacterRange: fullRange)

        lm.removeTemporaryAttribute(.foregroundColor,
            forCharacterRange: activeParaRange)
    }

    /// Clear all focus mode dimming.
    func clearFocusDimming() {
        guard let ts = textStorage, ts.length > 0 else { return }
        layoutManager?.removeTemporaryAttribute(.foregroundColor,
            forCharacterRange: NSRange(location: 0, length: ts.length))
    }
}

@MainActor
final class RenderedTableOverlayManager {
    private weak var textView: ClickableTextView?
    private var overlays: [String: NoteEditorRenderedTableHostingView] = [:]
    private var theme: EpistemosTheme
    private var documentMayContainTables = false
    private var scrollRefreshTask: Task<Void, Never>?
    var onDidRefresh: (() -> Void)?

    init(textView: ClickableTextView, theme: EpistemosTheme) {
        self.textView = textView
        self.theme = theme
    }

    func setTheme(_ theme: EpistemosTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        refresh()
    }

    func refreshAfterTextChange() {
        scrollRefreshTask?.cancel()
        scrollRefreshTask = nil
        refresh(recalculateDocumentState: true)
    }

    func refreshForScroll() {
        guard documentMayContainTables || !overlays.isEmpty else { return }
        guard scrollRefreshTask == nil else { return }

        scrollRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.scrollRefreshTask = nil
            self.refresh(recalculateDocumentState: false)
        }
    }

    func refresh() {
        refresh(recalculateDocumentState: true)
    }

    private func refresh(recalculateDocumentState: Bool) {
        onDidRefresh?()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage
        else { return }

        let text = storage.string as NSString
        if recalculateDocumentState {
            documentMayContainTables = storage.string.contains("|")
            if !documentMayContainTables {
                removeAll()
                return
            }
        } else if !documentMayContainTables && overlays.isEmpty {
            return
        }
        guard text.length > 0 else {
            removeAll()
            return
        }

        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: textView.visibleRect,
            in: textContainer
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil
        )
        let tableRanges = MarkdownTableBlockRanges.ranges(in: text, intersecting: visibleCharRange)
        let origin = textView.textContainerOrigin
        let overlayWidth = max(0, min(textContainer.containerSize.width, textView.bounds.width - origin.x * 2))
        var activeKeys = Set<String>()

        for tableRange in tableRanges {
            let key = "\(tableRange.location)"
            activeKeys.insert(key)

            guard let table = MarkdownTableModel.parse(text.substring(with: tableRange)) else {
                continue
            }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: tableRange,
                actualCharacterRange: nil
            )
            let bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            guard bounds.height > 0, overlayWidth > 0 else { continue }

            let frame = NSRect(
                x: origin.x,
                y: origin.y + bounds.minY,
                width: overlayWidth,
                height: bounds.height
            )

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
        scrollRefreshTask?.cancel()
        scrollRefreshTask = nil
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
}

// MARK: - QLPreviewPanel DataSource & Delegate

extension ClickableTextView: QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        quickLookURL != nil ? 1 : 0
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        quickLookURL as? NSURL
    }
}

enum NoteImageProcessor {
    nonisolated static let maxDisplayWidth: CGFloat = 600

    struct DisplayImage: @unchecked Sendable {
        let cgImage: CGImage
        let displaySize: CGSize
    }

    nonisolated static func loadDisplayImage(from url: URL) async -> DisplayImage? {
        await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let originalSize = sourceImageSize(source)
                else { return nil }

                let displaySize = scaledSize(for: originalSize, maxWidth: maxDisplayWidth)
                let cgImage: CGImage?
                if originalSize.width > maxDisplayWidth {
                    let maxDimension = max(displaySize.width, displaySize.height)
                    let maxPixelSize = maxDimension.isFinite ? Int(ceil(maxDimension)) : Int(maxDisplayWidth)
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    ]
                    cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                } else {
                    cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
                }

                guard let cgImage else { return nil }
                return DisplayImage(cgImage: cgImage, displaySize: displaySize)
            }
        }.value
    }

    nonisolated static func extractText(from url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
                else { return nil }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])

                let extractedText = request.results?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let extractedText, !extractedText.isEmpty else { return nil }
                return extractedText
            }
        }.value
    }

    private nonisolated static func sourceImageSize(_ source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else { return nil }

        let size = CGSize(width: width.doubleValue, height: height.doubleValue)
        guard size.width > 0, size.height > 0 else { return nil }
        return size
    }

    private nonisolated static func scaledSize(for originalSize: CGSize, maxWidth: CGFloat) -> CGSize {
        guard originalSize.width > maxWidth else { return originalSize }
        let scale = maxWidth / originalSize.width
        return CGSize(width: maxWidth, height: originalSize.height * scale)
    }
}
