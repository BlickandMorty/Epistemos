import AppKit
import SwiftUI

// MARK: - MarkdownTextView
// Renders markdown content as formatted SwiftUI Text for chat messages.
// Uses SwiftUI's native AttributedString markdown parsing for inline styles
// (bold, italic, code, links, strikethrough) and custom line-level parsing
// for headings, lists, code blocks, blockquotes, and tables.
//
// Read-only — no editing. Used for AI assistant responses in chat bubbles.
// The note editor uses the dedicated TextKit 2 editing stack.

enum MarkdownHeadingDisplay {
    private static let h1FullSizeCharacterLimit = 24
    private static let h1MediumSizeCharacterLimit = 44
    private static let h1LongSizeCharacterLimit = 72

    nonisolated static func noteHeadingBaseSize(
        for level: Int,
        baseFontSize: CGFloat? = nil
    ) -> CGFloat {
        let resolvedBaseFontSize = baseFontSize ?? MarkdownEditorStyle.noteBaseFontSize
        switch level {
        case 1:
            return resolvedBaseFontSize + 39
        case 2:
            return resolvedBaseFontSize + 13
        case 3:
            return resolvedBaseFontSize + 4
        case 4:
            return resolvedBaseFontSize + 2
        default:
            return max(resolvedBaseFontSize, 9)
        }
    }

    nonisolated static func noteHeadingFontWeight(for level: Int) -> Font.Weight {
        switch level {
        case 1: .bold
        case 2: .heavy
        case 3, 4: .bold
        default: .medium
        }
    }

    nonisolated static func noteHeadingWeight(for level: Int) -> NSFont.Weight {
        switch noteHeadingFontWeight(for: level) {
        case .heavy: .heavy
        case .bold: .bold
        case .semibold: .semibold
        case .medium: .medium
        default: .regular
        }
    }

    nonisolated static func noteHeadingFontSize(
        for level: Int,
        text: String,
        baseFontSize: CGFloat? = nil
    ) -> CGFloat {
        let resolvedBaseFontSize = baseFontSize ?? MarkdownEditorStyle.noteBaseFontSize
        return fontSize(
            for: level,
            text: text,
            baseSize: noteHeadingBaseSize(for: level, baseFontSize: resolvedBaseFontSize),
            nextLevelSize: noteHeadingBaseSize(for: 2, baseFontSize: resolvedBaseFontSize)
        )
    }

    nonisolated static func foregroundHex(for theme: EpistemosTheme, level: Int) -> UInt32 {
        guard (1...3).contains(level) else { return theme.foregroundHex }
        if level == 1 {
            return theme.headingAccentHex
        }
        return theme.markdownHeadingAccentHex
    }

    nonisolated static func fontSize(
        for level: Int,
        text: String,
        baseSize: CGFloat,
        nextLevelSize: CGFloat
    ) -> CGFloat {
        guard level == 1 else { return baseSize }

        let minimumSize = min(baseSize, max(nextLevelSize + 2, floor(baseSize * 0.74)))
        let availableDrop = max(0, baseSize - minimumSize)
        guard availableDrop > 0 else { return baseSize }
        let characterCount = normalizedHeadingText(text, level: level).count
        let mediumDrop = max(2, (availableDrop * 0.35).rounded())
        let longDrop = max(mediumDrop + 1, (availableDrop * 0.7).rounded())

        switch characterCount {
        case ...h1FullSizeCharacterLimit:
            return baseSize
        case ...h1MediumSizeCharacterLimit:
            return max(baseSize - mediumDrop, minimumSize)
        case ...h1LongSizeCharacterLimit:
            return max(baseSize - longDrop, minimumSize)
        default:
            return minimumSize
        }
    }

    /// Backwards-compatible single-arg form. Returns the text
    /// untouched. Used by call sites that don't have access to the
    /// active theme — they get the canonical mixed-case text.
    nonisolated static func displayText(_ text: String, level: Int) -> String {
        return text
    }

    /// Theme-aware heading transform. Two paths:
    ///   - Legacy `prefersUppercaseDisplay` uppercases H1-H3 (currently
    ///     no theme opts in; the property is retired but the wiring
    ///     stays for future themes).
    ///   - `uppercaseH1Display` uppercases H1 only — Ember pair per
    ///     user direction 2026-05-19.
    /// Levels 4-6 always keep mixed case for typographic rhythm.
    nonisolated static func displayText(_ text: String, level: Int, theme: EpistemosTheme) -> String {
        let legacyH1ToH3 = theme.prefersUppercaseDisplay && (1...3).contains(level)
        let h1OnlyUppercase = theme.uppercaseH1Display && level == 1
        guard legacyH1ToH3 || h1OnlyUppercase else {
            return text
        }
        return text.uppercased()
    }

    nonisolated static func foregroundColor(for theme: EpistemosTheme, level: Int) -> Color {
        Color(hex: foregroundHex(for: theme, level: level))
    }

    nonisolated static func glowRadius(for level: Int) -> CGFloat {
        switch level {
        case 1: 14
        case 2: 10
        case 3: 7
        default: 0
        }
    }

    nonisolated static func shadowOpacity(for theme: EpistemosTheme, level: Int) -> Double {
        // RCA finalization 2026-05-13: glow extends to themes whose
        // `headingGlows` flag is on (dark mode of any theme, plus
        // Platinum light mode). Other light-mode themes still get
        // 0 — Classic + Ember light keep their flat-pixel look.
        guard theme.headingGlows else { return 0 }
        return switch level {
        case 1:
            0.38
        case 2:
            0.24
        case 3:
            0.18
        default:
            0
        }
    }

    nonisolated static func overlayOpacity(for theme: EpistemosTheme, level: Int) -> Double {
        guard theme.headingGlows else { return 0 }
        return switch level {
        case 1:
            0.34
        case 2:
            0.22
        case 3:
            0.16
        default:
            0
        }
    }

    nonisolated static func overlayBlurRadius(for level: Int) -> CGFloat {
        switch level {
        case 1: 18
        case 2: 12
        case 3: 9
        default: 0
        }
    }

    nonisolated static func previewGlowRadius(for level: Int) -> CGFloat {
        switch level {
        case 1: 9
        case 2: 6
        case 3: 4
        default: 0
        }
    }

    nonisolated static func previewShadowOpacity(for theme: EpistemosTheme, level: Int) -> Double {
        guard theme.isDark else { return 0 }
        return switch level {
        case 1:
            0.22
        case 2:
            0.14
        case 3:
            0.1
        default:
            0
        }
    }

    nonisolated static func previewOverlayOpacity(for theme: EpistemosTheme, level: Int) -> Double {
        guard theme.isDark else { return 0 }
        return switch level {
        case 1:
            0.2
        case 2:
            0.12
        case 3:
            0.09
        default:
            0
        }
    }

    nonisolated static func previewOverlayBlurRadius(for level: Int) -> CGFloat {
        switch level {
        case 1: 12
        case 2: 8
        case 3: 6
        default: 0
        }
    }

    nonisolated static func previewSwiftUIShadowColor(for theme: EpistemosTheme, level: Int) -> Color {
        guard (1...3).contains(level) else { return .clear }
        return foregroundColor(for: theme, level: level).opacity(previewShadowOpacity(for: theme, level: level))
    }

    nonisolated static func swiftUIShadowColor(for theme: EpistemosTheme, level: Int) -> Color {
        guard (1...3).contains(level) else { return .clear }
        return foregroundColor(for: theme, level: level).opacity(shadowOpacity(for: theme, level: level))
    }

    nonisolated static func nsShadow(for theme: EpistemosTheme, level: Int) -> NSShadow? {
        guard theme.isDark, (1...3).contains(level) else { return nil }
        let shadow = NSShadow()
        shadow.shadowBlurRadius = glowRadius(for: level)
        shadow.shadowOffset = .zero
        shadow.shadowColor = NSColor(Color(hex: foregroundHex(for: theme, level: level))).withAlphaComponent(
            shadowOpacity(for: theme, level: level)
        )
        return shadow
    }

    private nonisolated static func normalizedHeadingText(_ text: String, level: Int) -> Substring {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(repeating: "#", count: level) + " "
        guard trimmed.hasPrefix(prefix) else { return Substring(trimmed) }
        return trimmed.dropFirst(prefix.count)
    }
}

struct MarkdownRippleStyle: Equatable {
    var maximumHeadingLevel = 0
    var includesBodyBlocks = false

    static let none = MarkdownRippleStyle()
    static let heading1 = MarkdownRippleStyle(maximumHeadingLevel: 1)
    static let headings123 = MarkdownRippleStyle(maximumHeadingLevel: 3)
    static let heading1AndBody = MarkdownRippleStyle(
        maximumHeadingLevel: 1,
        includesBodyBlocks: true
    )
    static let headings123AndBody = MarkdownRippleStyle(
        maximumHeadingLevel: 3,
        includesBodyBlocks: true
    )

    func ripplesHeading(level: Int) -> Bool {
        guard maximumHeadingLevel > 0 else { return false }
        return (1...maximumHeadingLevel).contains(level)
    }
}

enum MarkdownRippleTextExtractor {
    static func displayText(from inlineMarkdown: String) -> String {
        guard
            let attributed = try? AttributedString(
                markdown: inlineMarkdown,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        else {
            return inlineMarkdown
        }

        var plainText = String()
        plainText.reserveCapacity(inlineMarkdown.count)
        for character in attributed.characters {
            plainText.append(character)
        }
        return plainText
    }
}

struct MarkdownTableModel: Equatable {
    let rows: [[String]]
    let headerCount: Int

    var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    var placeholderTitle: String {
        let headerRows = Array(rows.prefix(max(headerCount, 1)))
        let prioritizedCells = headerRows.flatMap { $0 } + rows.flatMap { $0 }
        for cell in prioritizedCells {
            let plainCell = MarkdownRippleTextExtractor.displayText(from: cell)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !plainCell.isEmpty {
                return plainCell
            }
        }
        return "Untitled"
    }

    var placeholderLabel: String {
        "Table: \(placeholderTitle)"
    }

    static func parse(_ block: String) -> Self? {
        let lines = block
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !lines.isEmpty else { return nil }

        var rows: [[String]] = []
        var headerCount = 0
        var foundSeparator = false

        for line in lines {
            guard line.hasPrefix("|"), line.hasSuffix("|"), line.count >= 3 else {
                return nil
            }

            let cells = line
                .dropFirst()
                .dropLast()
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let isSeparator = cells.allSatisfy { cell in
                cell.allSatisfy { $0 == "-" || $0 == ":" }
            }
            if isSeparator {
                if !foundSeparator {
                    headerCount = rows.count
                }
                foundSeparator = true
                continue
            }

            rows.append(cells)
        }

        guard !rows.isEmpty else { return nil }
        return Self(rows: rows, headerCount: max(headerCount, 1))
    }
}

enum MarkdownTableBlockRanges {
    static func ranges(in text: NSString, intersecting visibleRange: NSRange? = nil) -> [NSRange] {
        guard text.length > 0 else { return [] }

        let fullRange = NSRange(location: 0, length: text.length)
        let scanRange = visibleRange.map { NSIntersectionRange(fullRange, $0) } ?? fullRange
        guard scanRange.length > 0 else { return [] }

        let firstLocation = min(scanRange.location, max(0, text.length - 1))
        var cursor = text.lineRange(for: NSRange(location: firstLocation, length: 0)).location
        let scanEnd = min(text.length, NSMaxRange(scanRange))
        var tableRanges: [NSRange] = []

        while cursor < scanEnd {
            let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
            let trimmedLine = text.substring(with: lineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard isTableLine(trimmedLine) else {
                cursor = NSMaxRange(lineRange)
                continue
            }

            let tableRange = expandedRange(in: text, from: lineRange)
            if tableRanges.last != tableRange {
                tableRanges.append(tableRange)
            }
            cursor = NSMaxRange(tableRange)
        }

        return tableRanges
    }

    private static func expandedRange(in text: NSString, from seedRange: NSRange) -> NSRange {
        var start = seedRange.location
        var end = NSMaxRange(seedRange)

        while start > 0 {
            let previousRange = text.lineRange(for: NSRange(location: start - 1, length: 0))
            let previousLine = text.substring(with: previousRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isTableLine(previousLine) else { break }
            start = previousRange.location
        }

        while end < text.length {
            let nextRange = text.lineRange(for: NSRange(location: end, length: 0))
            let nextLine = text.substring(with: nextRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isTableLine(nextLine) else { break }
            end = NSMaxRange(nextRange)
        }

        return NSRange(location: start, length: end - start)
    }

    private static func isTableLine(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 3
    }
}

@MainActor
final class NoteEditorRenderedTableHostingView: NSHostingView<NoteEditorTablePlaceholderView>, NSPopoverDelegate {
    private static let previewHotspotWidth: CGFloat = 24

    private var table: MarkdownTableModel
    private var theme: EpistemosTheme
    private var placeholderSize: CGSize
    private let previewPopover = NSPopover()
    private var isPopoverPinned = false
    private var hoverTrackingArea: NSTrackingArea?
    private(set) var contentConfigurationCount = 0

    init(table: MarkdownTableModel, theme: EpistemosTheme) {
        self.table = table
        self.theme = theme
        self.placeholderSize = NoteEditorTablePlaceholderView.preferredSize(for: table)
        super.init(rootView: NoteEditorTablePlaceholderView(table: table, theme: theme))
        translatesAutoresizingMaskIntoConstraints = true
        previewPopover.delegate = self
        previewPopover.animates = true
        contentConfigurationCount = 1
    }

    required init(rootView: NoteEditorTablePlaceholderView) {
        self.table = rootView.table
        self.theme = rootView.theme
        self.placeholderSize = NoteEditorTablePlaceholderView.preferredSize(for: rootView.table)
        super.init(rootView: rootView)
        previewPopover.delegate = self
        previewPopover.animates = true
        contentConfigurationCount = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override var acceptsFirstResponder: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        previewHotspotRect.contains(point) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        guard previewHotspotRect.width > 0, previewHotspotRect.height > 0 else {
            hoverTrackingArea = nil
            return
        }
        let trackingArea = NSTrackingArea(
            rect: previewHotspotRect,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func resetCursorRects() {
        discardCursorRects()
        guard previewHotspotRect.width > 0, previewHotspotRect.height > 0 else { return }
        addCursorRect(previewHotspotRect, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isPopoverPinned else { return }
        showPreview(pinned: false)
    }

    override func mouseExited(with event: NSEvent) {
        guard !isPopoverPinned else { return }
        previewPopover.performClose(nil)
    }

    override func mouseDown(with event: NSEvent) {
        if previewPopover.isShown, isPopoverPinned {
            isPopoverPinned = false
            previewPopover.performClose(nil)
        } else {
            showPreview(pinned: true)
        }
    }

    override func mouseDragged(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {}

    override func otherMouseDown(with event: NSEvent) {}

    override func scrollWheel(with event: NSEvent) {
        if let scrollView = enclosingScrollView {
            scrollView.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }

    func update(table: MarkdownTableModel, theme: EpistemosTheme, frame: NSRect) {
        if self.table != table || self.theme != theme {
            self.table = table
            self.theme = theme
            placeholderSize = NoteEditorTablePlaceholderView.preferredSize(for: table)
            rootView = NoteEditorTablePlaceholderView(table: table, theme: theme)
            contentConfigurationCount += 1
            if previewPopover.isShown {
                configurePreviewPopover()
            }
        }

        let placeholderWidth = min(frame.width, max(placeholderSize.width, 1))
        let placeholderHeight = max(24, placeholderSize.height)
        self.frame = NSRect(
            x: frame.minX,
            y: frame.minY,
            width: placeholderWidth,
            height: placeholderHeight
        )
    }

    override func removeFromSuperview() {
        previewPopover.performClose(nil)
        super.removeFromSuperview()
    }

    func popoverDidClose(_ notification: Notification) {
        isPopoverPinned = false
    }

    private var previewHotspotRect: NSRect {
        let width = min(Self.previewHotspotWidth, bounds.width)
        return NSRect(
            x: max(0, bounds.maxX - width),
            y: 0,
            width: width,
            height: bounds.height
        )
    }

    private func showPreview(pinned: Bool) {
        isPopoverPinned = pinned
        configurePreviewPopover()
        previewPopover.behavior = pinned ? .semitransient : .transient
        if !previewPopover.isShown {
            previewPopover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
        }
    }

    private func configurePreviewPopover() {
        previewPopover.contentSize = NoteEditorRenderedTablePopoverContent.preferredSize(for: table)
        previewPopover.contentViewController = NSHostingController(
            rootView: NoteEditorRenderedTablePopoverContent(table: table, theme: theme)
        )
    }
}

struct NoteEditorTablePlaceholderView: View {
    fileprivate static let labelFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    fileprivate static let iconWidth: CGFloat = 18
    fileprivate static let iconHeight: CGFloat = 18
    fileprivate static let spacing: CGFloat = 6
    fileprivate static let horizontalPadding: CGFloat = 4
    fileprivate static let verticalPadding: CGFloat = 8

    let table: MarkdownTableModel
    let theme: EpistemosTheme

    static func preferredSize(for table: MarkdownTableModel) -> CGSize {
        let label = table.placeholderLabel as NSString
        let labelSize = label.size(withAttributes: [.font: labelFont])
        return CGSize(
            width: ceil(labelSize.width) + iconWidth + spacing + horizontalPadding,
            height: ceil(max(labelSize.height, iconHeight) + verticalPadding)
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(table.placeholderLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "tablecells")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textTertiary.opacity(0.9))
                .frame(width: 18, height: 18)
        }
        .frame(alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .background(Color.clear)
    }
}

struct NoteEditorRenderedTablePopoverContent: View {
    let table: MarkdownTableModel
    let theme: EpistemosTheme

    static func contentSize(for table: MarkdownTableModel) -> CGSize {
        CGSize(
            width: min(900, max(320, CGFloat(table.columnCount) * 160)),
            height: max(48, CGFloat(table.rows.count) * 34 + 12)
        )
    }

    static func preferredSize(for table: MarkdownTableModel) -> CGSize {
        let contentSize = contentSize(for: table)
        let width = min(760, contentSize.width + 32)
        let height = min(420, max(120, contentSize.height + 28))
        return CGSize(width: width, height: height)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            NoteEditorRenderedTableView(table: table, theme: theme)
                .padding(14)
        }
        .frame(
            width: Self.preferredSize(for: table).width,
            height: Self.preferredSize(for: table).height
        )
        .background(theme.resolved.background.color)
    }
}

struct MarkdownPreviewSurfaceMetrics: Equatable, Sendable {
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let contentPadding: CGFloat
    let verticalSpacing: CGFloat
    let topEdgeWidth: CGFloat
    let bottomEdgeWidth: CGFloat
    let rightEdgeWidth: CGFloat

    nonisolated static let `default` = MarkdownPreviewSurfaceMetrics(
        cornerRadius: 14,
        borderWidth: 0.8,
        contentPadding: 12,
        verticalSpacing: 4,
        topEdgeWidth: 0,
        bottomEdgeWidth: 0,
        rightEdgeWidth: 0.8
    )
}

enum MarkdownPreviewSurfaceStyle {
    static func canvasNSColor(for theme: EpistemosTheme) -> NSColor {
        if theme.followsSystemAppearance {
            return .textBackgroundColor
        }
        return theme.resolved.background.nsColor
    }

    static func canvasBackground(for theme: EpistemosTheme) -> Color {
        Color(nsColor: canvasNSColor(for: theme))
    }

    /// Whether the preview should use a system material instead of a solid color.
    static var usesSystemMaterial: Bool {
        true
    }

    static func flatBackground(for theme: EpistemosTheme) -> Color {
        theme.card.opacity(theme.isDark ? 0.92 : 0.96)
    }

    /// Eighth-pass+1 (2026-05-13): same hue as `flatBackground` but
    /// alpha forced to 1.0. The Tiptap WKWebView in the Epdoc editor
    /// is transparent (`drawsBackground = false`), so any opacity on
    /// the surrounding canvas painted through SwiftUI shows through
    /// as a "blur slot" where the desktop / system blur leaks in. Used
    /// by `NoteWorkspaceSurfaceStyle.canvasBackground` so the workspace
    /// canvas paints a fully opaque card hue with no see-through, per
    /// user feedback "can i turn that blur … or do i just make the
    /// color be full solid".
    static func solidFlatBackground(for theme: EpistemosTheme) -> Color {
        Color(nsColor: solidFlatBackgroundNSColor(for: theme))
    }

    static func solidFlatBackgroundNSColor(for theme: EpistemosTheme) -> NSColor {
        theme.resolved.card.nsColor.withAlphaComponent(1.0)
    }

    static func borderOpacity(isDark: Bool) -> Double {
        isDark ? 0.18 : 0.12
    }

    static func borderColor(for theme: EpistemosTheme) -> Color {
        theme.glassBorder.opacity(borderOpacity(isDark: theme.isDark))
    }

    static func sheenColor(for theme: EpistemosTheme) -> Color {
        Color.white.opacity(theme.isDark ? 0.08 : 0.22)
    }
}

private struct MarkdownPreviewSurfaceModifier: ViewModifier {
    let theme: EpistemosTheme
    let metrics: MarkdownPreviewSurfaceMetrics

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .hoverGlass(
                flatBackground: MarkdownPreviewSurfaceStyle.flatBackground(for: theme),
                cornerRadius: metrics.cornerRadius
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .strokeBorder(
                        MarkdownPreviewSurfaceStyle.borderColor(for: theme),
                        lineWidth: metrics.borderWidth
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                MarkdownPreviewSurfaceStyle.sheenColor(for: theme),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            }
    }
}

extension View {
    func markdownPreviewSurface(
        theme: EpistemosTheme,
        metrics: MarkdownPreviewSurfaceMetrics = .default
    ) -> some View {
        modifier(MarkdownPreviewSurfaceModifier(theme: theme, metrics: metrics))
    }

    func markdownHeadingGlow<GlowContent: View>(
        theme: EpistemosTheme,
        level: Int,
        @ViewBuilder glowContent: () -> GlowContent
    ) -> some View {
        overlay {
            if MarkdownHeadingDisplay.previewOverlayOpacity(for: theme, level: level) > 0 {
                glowContent()
                    .opacity(MarkdownHeadingDisplay.previewOverlayOpacity(for: theme, level: level))
                    .blur(radius: MarkdownHeadingDisplay.previewOverlayBlurRadius(for: level))
                    .allowsHitTesting(false)
            }
        }
        .shadow(
            color: MarkdownHeadingDisplay.previewSwiftUIShadowColor(for: theme, level: level),
            radius: MarkdownHeadingDisplay.previewGlowRadius(for: level)
        )
    }
}

struct MarkdownTableSurfaceView<CellContent: View>: View {
    let table: MarkdownTableModel
    let theme: EpistemosTheme
    var verticalPadding: CGFloat = 6
    var containerFill: Color = .clear
    var bodyRowBackground: Color = .clear
    var usesPreviewHoverChrome = false
    let cellContent: (String, Bool) -> CellContent

    var body: some View {
        let borderColor = usesPreviewHoverChrome
            ? MarkdownPreviewSurfaceStyle.borderColor(for: theme)
            : (theme.isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12))
        let headerBg = theme.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
        let altRowBg = theme.isDark ? Color.white.opacity(0.02) : Color.black.opacity(0.02)
        let colCount = table.rows.map(\.count).max() ?? 1

        VStack(spacing: 0) {
            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIdx, cells in
                let isHeader = rowIdx < table.headerCount
                HStack(spacing: 0) {
                    ForEach(0..<colCount, id: \.self) { colIdx in
                        let cell = colIdx < cells.count ? cells[colIdx] : ""
                        cellContent(cell, isHeader)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(alignment: .trailing) {
                                if colIdx < colCount - 1 {
                                    Rectangle().fill(borderColor).frame(width: 1)
                                }
                            }
                    }
                }
                .background(
                    isHeader ? headerBg :
                    rowIdx % 2 != 0 ? altRowBg : bodyRowBackground
                )

                if rowIdx < table.rows.count - 1 {
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: isHeader ? 1.5 : 0.5)
                }
            }
        }
        .modifier(
            TableChromeModifier(
                theme: theme,
                containerFill: containerFill,
                borderColor: borderColor,
                usesPreviewHoverChrome: usesPreviewHoverChrome
            )
        )
        .padding(.vertical, verticalPadding)
    }

    private struct TableChromeModifier: ViewModifier {
        let theme: EpistemosTheme
        let containerFill: Color
        let borderColor: Color
        let usesPreviewHoverChrome: Bool

        func body(content: Content) -> some View {
            if usesPreviewHoverChrome {
                content.markdownPreviewSurface(theme: theme)
            } else {
                content
                    .background(
                        containerFill,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
            }
        }
    }
}

struct NoteEditorRenderedTableView: View {
    let table: MarkdownTableModel
    let theme: EpistemosTheme

    private var containerFill: Color {
        theme.resolved.background.color.opacity(theme.isDark ? 0.96 : 0.98)
    }

    private var contentSize: CGSize {
        NoteEditorRenderedTablePopoverContent.contentSize(for: table)
    }

    var body: some View {
        MarkdownTableSurfaceView(
            table: table,
            theme: theme,
            verticalPadding: 0,
            containerFill: containerFill,
            bodyRowBackground: containerFill
        ) { cell, isHeader in
            InlineMarkdownStyler.text(
                cell,
                strongFontSize: 13,
                strongForegroundColor: nil,
                linkForegroundColor: theme.preferredMarkdownLinkColor
            )
            .font(.system(size: 13))
            .foregroundStyle(isHeader ? theme.resolved.foreground.color : theme.resolved.foreground.color.opacity(0.9))
            .fontWeight(isHeader ? .semibold : .regular)
        }
        .frame(
            width: contentSize.width,
            height: contentSize.height,
            alignment: .topLeading
        )
        .allowsHitTesting(false)
    }
}

struct MarkdownTextView: View {
    let content: String
    let theme: EpistemosTheme
    var rippleStyle: MarkdownRippleStyle = .none
    var foregroundOverride: Color? = nil
    private let blocks: [MarkdownBlock]

    private enum PreviewTypography {
        static let bodyFontSize: CGFloat = 16
        static let bodyLineSpacing: CGFloat = 6
        static let blockSpacing: CGFloat = 14
        static let listIndent: CGFloat = 18
        static let markerTopPadding: CGFloat = 3
    }

    init(
        content: String,
        theme: EpistemosTheme,
        rippleStyle: MarkdownRippleStyle = .none,
        foregroundOverride: Color? = nil
    ) {
        self.content = content
        self.theme = theme
        self.rippleStyle = rippleStyle
        self.foregroundOverride = foregroundOverride
        self.blocks = Self.mergeTableBlocks(Self.parseBlocks(content))
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: PreviewTypography.blockSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        .textSelection(.enabled)
    }

    /// Whether ripple overlays should be evaluated. Skips all ripple text extraction
    /// and overlay modifier instantiation when rippleStyle is .none (preview mode).
    private var rippleEnabled: Bool { rippleStyle != .none }

    // MARK: - Block Types

    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case bulletItem(text: String)
        case numberedItem(number: String, text: String)
        case checkItem(checked: Bool, text: String)
        case blockquote(text: String)
        case codeBlock(language: String, code: String)
        case horizontalRule
        case tableLine(text: String)
        case table(rows: [[String]], headerCount: Int)
    }

    private var bodyForeground: Color {
        foregroundOverride ?? theme.resolved.foreground.color
    }

    // MARK: - Block Parsing

    private static func parseBlocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var paragraphLines: [String] = []

        func flushParagraph() {
            let paragraph = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                blocks.append(.paragraph(text: paragraph))
            }
            paragraphLines.removeAll(keepingCapacity: true)
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Fenced code block
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    let codeLine = lines[i]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(codeLine)
                    i += 1
                }
                blocks.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                continue
            }

            // Headings
            if trimmed.hasPrefix("##### ") {
                flushParagraph()
                blocks.append(.heading(level: 5, text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix("#### ") && !trimmed.hasPrefix("##### ") {
                flushParagraph()
                blocks.append(.heading(level: 4, text: String(trimmed.dropFirst(5))))
            } else if trimmed.hasPrefix("### ") && !trimmed.hasPrefix("#### ") {
                flushParagraph()
                blocks.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(level: 1, text: String(trimmed.dropFirst(2))))
            }
            // Horizontal rule
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.horizontalRule)
            }
            // Checkbox
            else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [ ] ") {
                flushParagraph()
                let checked = trimmed.hasPrefix("- [x] ")
                blocks.append(.checkItem(checked: checked, text: String(trimmed.dropFirst(6))))
            }
            // Bullet list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bulletItem(text: String(trimmed.dropFirst(2))))
            }
            // Numbered list
            else if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flushParagraph()
                let number = String(trimmed[trimmed.startIndex..<match.upperBound]).trimmingCharacters(in: .whitespaces)
                let rest = String(trimmed[match.upperBound...])
                blocks.append(.numberedItem(number: number, text: rest))
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.blockquote(text: String(trimmed.dropFirst(2))))
            }
            // Table
            else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                flushParagraph()
                blocks.append(.tableLine(text: trimmed))
            }
            // Paragraph
            else {
                paragraphLines.append(line)
            }

            i += 1
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Table Merging

    /// Post-processes parsed blocks to merge consecutive `.tableLine` entries
    /// into a single `.table` block with structured rows and header detection.
    private static func mergeTableBlocks(_ blocks: [MarkdownBlock]) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var tableLines: [String] = []

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            var rows: [[String]] = []
            var headerCount = 0
            var foundSeparator = false

            for line in tableLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let cells = trimmed.dropFirst().dropLast()
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }

                let isSep = cells.allSatisfy { $0.allSatisfy { $0 == "-" || $0 == ":" } }
                if isSep {
                    if !foundSeparator { headerCount = rows.count }
                    foundSeparator = true
                    continue
                }
                rows.append(cells)
            }

            if !rows.isEmpty {
                result.append(.table(rows: rows, headerCount: max(headerCount, 1)))
            }
            tableLines = []
        }

        for block in blocks {
            if case .tableLine(let text) = block {
                tableLines.append(text)
            } else {
                flushTable()
                result.append(block)
            }
        }
        flushTable()
        return result
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let text):
            inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                .font(.system(size: PreviewTypography.bodyFontSize))
                .lineSpacing(PreviewTypography.bodyLineSpacing)
                .foregroundStyle(bodyForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .asciiRippleOverlay(
                    text: rippleEnabled ? MarkdownRippleTextExtractor.displayText(from: text) : "",
                    font: .system(size: PreviewTypography.bodyFontSize),
                    color: bodyForeground,
                    lineSpacing: PreviewTypography.bodyLineSpacing,
                    enabled: rippleEnabled && rippleStyle.includesBodyBlocks
                )
        case .bulletItem(let text):
            HStack(alignment: .top, spacing: 10) {
                Text("\u{2022}")
                    .padding(.top, PreviewTypography.markerTopPadding)
                    .foregroundStyle(theme.resolved.accent.color)
                inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                    .font(.system(size: PreviewTypography.bodyFontSize))
                    .lineSpacing(PreviewTypography.bodyLineSpacing)
                    .foregroundStyle(bodyForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .asciiRippleOverlay(
                        text: rippleEnabled ? MarkdownRippleTextExtractor.displayText(from: text) : "",
                        font: .system(size: PreviewTypography.bodyFontSize),
                        color: bodyForeground,
                        lineSpacing: PreviewTypography.bodyLineSpacing,
                        enabled: rippleEnabled && rippleStyle.includesBodyBlocks
                    )
            }
            .padding(.leading, PreviewTypography.listIndent)
        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 10) {
                Text(number)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .padding(.top, PreviewTypography.markerTopPadding)
                    .foregroundStyle(theme.resolved.accent.color)
                inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                    .font(.system(size: PreviewTypography.bodyFontSize))
                    .lineSpacing(PreviewTypography.bodyLineSpacing)
                    .foregroundStyle(bodyForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .asciiRippleOverlay(
                        text: rippleEnabled ? MarkdownRippleTextExtractor.displayText(from: text) : "",
                        font: .system(size: PreviewTypography.bodyFontSize),
                        color: bodyForeground,
                        lineSpacing: PreviewTypography.bodyLineSpacing,
                        enabled: rippleEnabled && rippleStyle.includesBodyBlocks
                    )
            }
            .padding(.leading, PreviewTypography.listIndent)
        case .checkItem(let checked, let text):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .padding(.top, PreviewTypography.markerTopPadding)
                    .foregroundStyle(checked ? theme.resolved.accent.color : theme.textTertiary)
                inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                    .font(.system(size: PreviewTypography.bodyFontSize))
                    .lineSpacing(PreviewTypography.bodyLineSpacing)
                    .foregroundStyle(checked ? theme.textTertiary : bodyForeground)
                    .strikethrough(checked)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .asciiRippleOverlay(
                        text: rippleEnabled ? MarkdownRippleTextExtractor.displayText(from: text) : "",
                        font: .system(size: PreviewTypography.bodyFontSize),
                        color: checked ? theme.textTertiary : bodyForeground,
                        lineSpacing: PreviewTypography.bodyLineSpacing,
                        enabled: rippleEnabled && rippleStyle.includesBodyBlocks
                    )
            }
            .padding(.leading, PreviewTypography.listIndent)
        case .blockquote(let text):
            let metrics = MarkdownPreviewSurfaceMetrics.default
            let railWidth: CGFloat = 3
            inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                .font(.system(size: PreviewTypography.bodyFontSize))
                .lineSpacing(PreviewTypography.bodyLineSpacing)
                .italic()
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, metrics.contentPadding)
                .padding(.bottom, metrics.contentPadding)
                .padding(.trailing, metrics.contentPadding)
                .padding(.leading, metrics.contentPadding + railWidth + 14)
                .asciiRippleOverlay(
                    text: rippleEnabled ? MarkdownRippleTextExtractor.displayText(from: text) : "",
                    font: .system(size: PreviewTypography.bodyFontSize),
                    color: theme.textSecondary,
                    lineSpacing: PreviewTypography.bodyLineSpacing,
                    enabled: rippleEnabled && rippleStyle.includesBodyBlocks
                )
            .frame(maxWidth: .infinity, alignment: .leading)
            .markdownPreviewSurface(theme: theme)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: railWidth / 2, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(0.5))
                    .frame(width: railWidth)
                    .padding(.vertical, 8)
                    .padding(.leading, 8)
            }
            .padding(.vertical, MarkdownPreviewSurfaceMetrics.default.verticalSpacing)
        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 4) {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.isDark
                        ? Color.white.opacity(0.75)
                        : Color(red: 0.2, green: 0.2, blue: 0.2))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, language.isEmpty ? 10 : 4)
                    .padding(.bottom, language.isEmpty ? 0 : 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .markdownPreviewSurface(theme: theme)
            .padding(.vertical, MarkdownPreviewSurfaceMetrics.default.verticalSpacing)
        case .horizontalRule:
            Divider()
                .padding(.vertical, 2)
        case .table(let rows, let headerCount):
            renderTable(rows: rows, headerCount: headerCount)
        case .tableLine:
            EmptyView()
        }
    }

    // MARK: - Heading Rendering

    @ViewBuilder
    private func renderHeading(level: Int, text: String) -> some View {
        let headingRole = AppHeadingRole.markdownRole(level: level)
        let fontSize = MarkdownHeadingDisplay.noteHeadingFontSize(for: level, text: text)
        let fontWeight = MarkdownHeadingDisplay.noteHeadingFontWeight(for: level)
        let font: Font = {
            if (1...3).contains(level) {
                // RCA finalization 2026-05-13: theme-aware H1-H3 font
                // — Platinum + Ember swap their light-mode heading
                // face; Classic keeps CoralPixels; dark mode keeps
                // RetroGaming.
                AppDisplayTypography.headingFont(size: fontSize, weight: fontWeight, theme: theme)
            } else if headingRole != nil {
                AppDisplayTypography.font(
                    size: fontSize,
                    weight: fontWeight,
                    allowDisplayFont: false
                )
            } else {
                Font.system(size: fontSize, weight: fontWeight)
            }
        }()
        let topPad = headingRole?.topPadding ?? 6
        let color = MarkdownHeadingDisplay.foregroundColor(for: theme, level: level)
        let displayText = MarkdownHeadingDisplay.displayText(text, level: level, theme: theme)

        inlineMarkdown(displayText, baseFontSize: fontSize)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(level == 1 ? 4 : 2)
            .markdownHeadingGlow(theme: theme, level: level) {
                inlineMarkdown(displayText, baseFontSize: fontSize)
                    .font(font)
                    .foregroundStyle(color)
                    .lineSpacing(level == 1 ? 4 : 2)
            }
            .asciiRippleOverlay(
                text: rippleEnabled ? MarkdownRippleTextExtractor.displayText(from: displayText) : "",
                font: font,
                color: color,
                shadowColor: MarkdownHeadingDisplay.previewSwiftUIShadowColor(for: theme, level: level),
                shadowRadius: MarkdownHeadingDisplay.previewGlowRadius(for: level),
                lineSpacing: level == 1 ? 4 : 2,
                opacity: level == 1 ? 0.7 : 0.48,
                enabled: rippleEnabled && rippleStyle.ripplesHeading(level: level)
            )
            .padding(.top, topPad)
            .padding(.bottom, level == 1 ? 8 : 4)
    }

    // MARK: - Table Rendering

    @ViewBuilder
    private func renderTable(rows: [[String]], headerCount: Int) -> some View {
        MarkdownTableSurfaceView(
            table: MarkdownTableModel(rows: rows, headerCount: headerCount),
            theme: theme,
            containerFill: .clear,
            bodyRowBackground: .clear,
            usesPreviewHoverChrome: true
        ) { cell, isHeader in
            inlineMarkdown(cell, baseFontSize: 13)
                .font(.system(size: 13))
                .foregroundStyle(theme.resolved.foreground.color.opacity(isHeader ? 1.0 : 0.85))
                .fontWeight(isHeader ? .semibold : .regular)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Inline Markdown -> SwiftUI Text

    private func inlineMarkdown(_ text: String, baseFontSize: CGFloat) -> Text {
        InlineMarkdownStyler.text(
            text,
            strongFontSize: baseFontSize,
            strongForegroundColor: nil,
            linkForegroundColor: theme.preferredMarkdownLinkColor
        )
    }
}
