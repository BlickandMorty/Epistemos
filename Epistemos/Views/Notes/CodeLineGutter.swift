// CodeLineGutter.swift
//
// Right-side line-number gutter for the code editor. Modeled directly on
// SegmentedIndentationGuideView's pattern: an NSView added as a subview of
// CodeEditSourceEditor's NSTextView, with scroll offset applied at draw time
// so it stays in lockstep with the editor without per-frame allocation.
//
// The gutter floats over the right edge of the text container — it does not
// consume editor width. The editor body keeps its full width; we sit on top
// of the trailing scroll-bar gutter region. Colors are derived from the
// active EpistemosTheme via `editorGutterTokens(for:)` so the gutter never
// fights the theme.
//
// Performance:
// - Visible-line `numberStringCache` avoids whole-file string allocation
// - One `NSDictionary` of attributes per redraw, not per line
// - Drawing scoped to `dirtyRect` only
// - No per-frame Swift Array allocation
//
// 2026-04-25.

import AppKit

// MARK: - Theme tokens (derived from EpistemosTheme)

/// Color tokens for the line-number gutter. Derived from the active theme so
/// the gutter follows accent / muted-foreground / background instead of using
/// hard-coded Xcode swatches.
struct CodeLineGutterTokens {
    let foreground: NSColor
    let activeForeground: NSColor
    let background: NSColor
    let separator: NSColor
}

extension EpistemosTheme {
    /// Builds gutter color tokens from the resolved theme. The numbers are
    /// derived from `mutedForeground` (so they always recede from body text)
    /// and the separator from `border`. We never invent a new palette.
    nonisolated func editorGutterTokens() -> CodeLineGutterTokens {
        let muted = self.resolved.mutedForeground.nsColor
        let foreground = muted.withAlphaComponent(0.55)
        let activeForeground = self.resolved.foreground.nsColor.withAlphaComponent(0.92)
        // Background: leave fully transparent so the editor canvas shows
        // through. The gutter is an inset, not a competing surface.
        let background = NSColor.clear
        let separator = self.resolved.border.nsColor.withAlphaComponent(self.isDark ? 0.45 : 0.35)
        return CodeLineGutterTokens(
            foreground: foreground,
            activeForeground: activeForeground,
            background: background,
            separator: separator
        )
    }
}

// MARK: - Gutter view

/// Right-aligned line-number gutter pinned to the trailing edge of the
/// editor's text view. The view spans the full text-content height; scroll
/// position is applied at draw time. Designed to be added once and reused.
final class CodeLineGutterView: NSView {

    // Configuration (set once after init)
    var lineHeight: CGFloat = 17 {
        didSet { if oldValue != lineHeight { needsDisplay = true } }
    }
    var topInset: CGFloat = 0
    var rightPadding: CGFloat = 8
    var leftPadding: CGFloat = 6
    /// Gutter width (in points). Updated by the coordinator whenever the
    /// digit count or font size changes.
    var gutterWidth: CGFloat = 28 {
        didSet { if oldValue != gutterWidth { needsDisplay = true } }
    }
    var font: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    // Tokens (re-applied whenever the theme changes)
    private var tokens: CodeLineGutterTokens = CodeLineGutterTokens(
        foreground: NSColor.tertiaryLabelColor,
        activeForeground: NSColor.labelColor,
        background: .clear,
        separator: NSColor.separatorColor
    )

    // Visible-line cache. The dormant fallback gutter must not allocate one
    // NSString per file line when a 100k-line buffer opens.
    private var numberStringCache: [Int: NSString] = [:]
    private var lineCount: Int = 0
    private var activeLine: Int = 1
    private var scrollOffset: CGFloat = 0

    // One attribute dict reused per draw pass (not per line).
    private var sharedAttrs: [NSAttributedString.Key: Any] = [:]
    private var sharedActiveAttrs: [NSAttributedString.Key: Any] = [:]

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // pass clicks through

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        rebuildSharedAttrs()
        // Pre-allocate a viewport-sized cache to avoid early growth churn.
        numberStringCache.reserveCapacity(512)
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - State updates

    func applyTokens(_ next: CodeLineGutterTokens) {
        tokens = next
        layer?.backgroundColor = next.background.cgColor
        rebuildSharedAttrs()
        needsDisplay = true
    }

    func applyFont(_ next: NSFont) {
        if next != font {
            font = next
            rebuildSharedAttrs()
            needsDisplay = true
        }
    }

    /// Update the line count without re-allocating the number cache when
    /// possible. Strings only grow on demand.
    func updateLineCount(_ count: Int) {
        let clamped = max(0, count)
        guard clamped != lineCount else { return }
        if clamped < lineCount {
            numberStringCache = numberStringCache.filter { $0.key <= clamped }
        }
        lineCount = clamped
        needsDisplay = true
    }

    func updateActiveLine(_ line: Int) {
        let clamped = max(1, line)
        guard clamped != activeLine else { return }
        activeLine = clamped
        needsDisplay = true
    }

    /// Match the indent-guide pattern: scroll offset is applied at draw time.
    func updateScrollOffset(_ offset: CGFloat) {
        guard offset != scrollOffset else { return }
        scrollOffset = offset
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard lineCount > 0, lineHeight > 0 else { return }

        guard let visibleLines = Self.visibleLineRange(
            lineCount: lineCount,
            lineHeight: lineHeight,
            topInset: topInset,
            scrollOffset: scrollOffset,
            dirtyRect: dirtyRect
        ) else { return }

        let rightX = bounds.maxX - rightPadding
        let textRectWidth = max(1, gutterWidth - rightPadding - leftPadding)

        for line in visibleLines {
            let idx = line - 1
            guard idx < lineCount else { break }

            let y = topInset + scrollOffset + CGFloat(idx) * lineHeight
            // Stop early if we run past the dirty rect.
            if y > dirtyRect.maxY { break }
            if y + lineHeight < dirtyRect.minY { continue }

            let str = stringForLine(line)
            let attrs = (line == activeLine) ? sharedActiveAttrs : sharedAttrs
            let size = str.size(withAttributes: attrs)

            // Right-align inside [rightX - textRectWidth, rightX]
            let drawX = rightX - size.width
            let drawY = y + max(0, (lineHeight - size.height) / 2)
            // Bound the X inside the gutter area to avoid bleed.
            let clampedX = max(rightX - textRectWidth, drawX)
            str.draw(at: NSPoint(x: clampedX, y: drawY), withAttributes: attrs)
        }

        // Subtle inner separator on the inside (left) edge.
        let sepX = bounds.maxX - gutterWidth
        if sepX >= dirtyRect.minX, sepX <= dirtyRect.maxX {
            tokens.separator.setFill()
            let sepRect = NSRect(x: sepX, y: dirtyRect.minY, width: 0.5, height: dirtyRect.height)
            sepRect.fill()
        }
    }

    // MARK: - Helpers

    nonisolated static func visibleLineRange(
        lineCount: Int,
        lineHeight: CGFloat,
        topInset: CGFloat,
        scrollOffset: CGFloat,
        dirtyRect: NSRect
    ) -> ClosedRange<Int>? {
        guard lineCount > 0, lineHeight > 0 else { return nil }

        // Visible Y range (in our coordinate space)
        let topY = max(0, dirtyRect.minY)
        let bottomY = dirtyRect.maxY

        // Map Y to line range, accounting for scroll offset and top inset.
        // Numbers sit at: y(line) = topInset + scrollOffset + (line - 1) * lineHeight
        let firstLine = max(1, Int(((topY - scrollOffset - topInset) / lineHeight).rounded(.down)) + 1)
        let lastLine = min(lineCount, Int(((bottomY - scrollOffset - topInset) / lineHeight).rounded(.up)) + 1)

        guard firstLine <= lastLine else { return nil }
        return firstLine...lastLine
    }

    private func rebuildSharedAttrs() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byClipping
        sharedAttrs = [
            .font: font,
            .foregroundColor: tokens.foreground,
            .paragraphStyle: paragraph
        ]
        sharedActiveAttrs = [
            .font: font,
            .foregroundColor: tokens.activeForeground,
            .paragraphStyle: paragraph
        ]
    }

    private func stringForLine(_ line: Int) -> NSString {
        if let cached = numberStringCache[line] {
            return cached
        }
        if numberStringCache.count > 2_048 {
            numberStringCache.removeAll(keepingCapacity: true)
        }
        let next = String(line) as NSString
        numberStringCache[line] = next
        return next
    }

    /// Computes the preferred gutter width for a given digit count and font.
    /// Caller decides when to apply this (e.g. when `lineCount` crosses a
    /// power-of-ten boundary).
    static func preferredWidth(digitCount: Int, font: NSFont, leftPadding: CGFloat = 6, rightPadding: CGFloat = 8) -> CGFloat {
        let digits = max(2, digitCount)
        let sample = String(repeating: "8", count: digits) as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let width = sample.size(withAttributes: attrs).width
        return ceil(width) + leftPadding + rightPadding
    }
}

// MARK: - Width policy

enum CodeLineGutterPolicy {
    /// Number of decimal digits in `count` (minimum 2 so the gutter doesn't
    /// jitter narrower than 2-digit width on small files).
    static func digitCount(for count: Int) -> Int {
        if count < 100 { return 2 }
        if count < 1_000 { return 3 }
        if count < 10_000 { return 4 }
        if count < 100_000 { return 5 }
        return 6
    }

    /// Body font size → gutter font size (one step smaller, clamped).
    /// Honors Dynamic Type because the body font already does.
    static func gutterFontSize(forBodyPointSize body: CGFloat) -> CGFloat {
        max(9, body - 2)
    }
}
