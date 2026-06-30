import AppKit
import SwiftUI

struct HTMLWorkspaceCodeEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var colorScheme: ColorScheme = .light
    var theme: EpistemosTheme? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView(frame: .zero)

        textView.string = text
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        configure(textView: textView, scrollView: scrollView)
        scrollView.documentView = textView
        Self.ensureVisibleTextGeometry(textView: textView, scrollView: scrollView)
        context.coordinator.attach(textView: textView, scrollView: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        if textView.string != text {
            textView.string = text
            context.coordinator.invalidateLineNumbers(rebuild: true)
        }
        textView.isEditable = isEditable
        textView.isSelectable = true
        configure(textView: textView, scrollView: scrollView)
        Self.ensureVisibleTextGeometry(textView: textView, scrollView: scrollView)
        context.coordinator.attach(textView: textView, scrollView: scrollView)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        if let textView = scrollView.documentView as? NSTextView {
            textView.delegate = nil
        }
        coordinator.detach()
        scrollView.verticalRulerView = nil
        scrollView.documentView = nil
    }

    private func configure(textView: NSTextView, scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .allowed
        let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        let palette = HTMLWorkspaceCodeEditorPalette(theme: theme, colorScheme: colorScheme)
        scrollView.appearance = appearance
        scrollView.verticalRulerView = (scrollView.verticalRulerView as? LineNumberRulerView)
            ?? LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView?.appearance = appearance
        if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView.labelColor = palette.gutterText
            rulerView.backgroundColor = palette.gutterBackground
        }

        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesFindPanel = true
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = AppDisplayTypography.monoUIFont(size: 12.5, weight: .regular)
        textView.textColor = palette.foreground
        textView.insertionPointColor = palette.accent
        textView.backgroundColor = palette.background
        textView.drawsBackground = true
        textView.appearance = appearance
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.height]
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        applyPlainTextAttributes(to: textView, foreground: palette.foreground)
    }

    private static func ensureVisibleTextGeometry(textView: NSTextView, scrollView: NSScrollView) {
        let contentSize = NSSize(
            width: max(scrollView.contentSize.width, scrollView.bounds.width),
            height: max(scrollView.contentSize.height, scrollView.bounds.height)
        )
        guard contentSize.width > 0 || contentSize.height > 0 else { return }

        textView.minSize = contentSize
        if textView.frame.width < contentSize.width || textView.frame.height < contentSize.height {
            textView.frame.size = NSSize(
                width: max(textView.frame.width, contentSize.width),
                height: max(textView.frame.height, contentSize.height)
            )
        }
        textView.needsDisplay = true
    }

    private func applyPlainTextAttributes(to textView: NSTextView, foreground: NSColor) {
        let editorFont = AppDisplayTypography.monoUIFont(size: 12.5, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: foreground,
            .font: editorFont,
        ]
        textView.typingAttributes = attributes
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        guard fullRange.length > 0 else { return }
        textView.textStorage?.addAttributes(attributes, range: fullRange)
        textView.layoutManager?.invalidateDisplay(forCharacterRange: fullRange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        private weak var rulerView: LineNumberRulerView?
        private weak var observedContentView: NSClipView?

        init(text: Binding<String>) {
            self.text = text
        }

        func detach() {
            if let observedContentView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedContentView
                )
            }
            observedContentView = nil
            textView?.delegate = nil
            textView = nil
            rulerView?.textView = nil
            rulerView = nil
        }

        func attach(textView: NSTextView, scrollView: NSScrollView) {
            self.textView = textView
            if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
                rulerView.textView = textView
                self.rulerView = rulerView
            }
            let contentView = scrollView.contentView
            contentView.postsBoundsChangedNotifications = true
            guard observedContentView !== contentView else { return }
            if let observedContentView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedContentView
                )
            }
            observedContentView = contentView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: contentView
            )
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            invalidateLineNumbers(rebuild: true)
        }

        func invalidateLineNumbers(rebuild: Bool = false) {
            rulerView?.invalidateLineNumbers(rebuild: rebuild)
        }

        @objc private func boundsDidChange(_ notification: Notification) {
            if let textView, let scrollView = textView.enclosingScrollView {
                HTMLWorkspaceCodeEditor.ensureVisibleTextGeometry(textView: textView, scrollView: scrollView)
            }
            invalidateLineNumbers()
        }
    }
}

private struct HTMLWorkspaceCodeEditorPalette {
    let background: NSColor
    let gutterBackground: NSColor
    let foreground: NSColor
    let gutterText: NSColor
    let accent: NSColor

    init(theme: EpistemosTheme?, colorScheme: ColorScheme) {
        let resolvedTheme = (theme ?? (colorScheme == .dark ? EpistemosTheme.oledSoft : EpistemosTheme.light))
            .surfaceVariant(.other)
        let base = MarkdownPreviewSurfaceStyle
            .canvasNSColor(for: resolvedTheme)
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
        let tintSource: NSColor = resolvedTheme.isDark ? .white : .black
        let gutter = (base.blended(
            withFraction: resolvedTheme.isDark ? 0.055 : 0.045,
            of: tintSource
        ) ?? base)
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)

        let preferredForeground = resolvedTheme.resolved.foreground.nsColor.rgbSafeForCodeEditorTheme()
        let preferredMuted = resolvedTheme.resolved.mutedForeground.nsColor.rgbSafeForCodeEditorTheme()

        self.background = base
        self.gutterBackground = gutter
        self.foreground = Self.readable(preferredForeground, on: base, isDark: resolvedTheme.isDark)
        self.gutterText = Self.readable(preferredMuted, on: gutter, isDark: resolvedTheme.isDark).withAlphaComponent(0.78)
        self.accent = resolvedTheme.resolved.accent.nsColor.rgbSafeForCodeEditorTheme()
    }

    private static func readable(_ preferred: NSColor, on background: NSColor, isDark: Bool) -> NSColor {
        if preferred.contrastRatio(against: background) >= 4.5 {
            return preferred
        }
        return (background.relativeLuminance < 0.46
            ? NSColor(deviceWhite: 0.92, alpha: 1.0)
            : NSColor(deviceWhite: 0.12, alpha: 1.0))
            .rgbSafeForCodeEditorTheme()
    }
}

private extension NSColor {
    var relativeLuminance: CGFloat {
        let color = usingColorSpace(.sRGB) ?? self
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * channel(color.redComponent))
            + (0.7152 * channel(color.greenComponent))
            + (0.0722 * channel(color.blueComponent))
    }

    func contrastRatio(against other: NSColor) -> CGFloat {
        let first = relativeLuminance
        let second = other.relativeLuminance
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

private final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView? {
        didSet {
            clientView = textView
            invalidateLineNumbers(rebuild: true)
        }
    }

    var labelColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }
    var backgroundColor: NSColor = .clear {
        didSet {
            layer?.backgroundColor = backgroundColor.cgColor
            needsDisplay = true
        }
    }

    private var lineStarts: [Int] = [0]
    private var labelAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        return [
            .font: AppDisplayTypography.monoUIFont(size: 10.5, weight: .regular),
            .foregroundColor: labelColor,
            .paragraphStyle: paragraph,
        ]
    }

    init(textView: NSTextView) {
        super.init(scrollView: nil, orientation: .verticalRuler)
        self.textView = textView
        self.clientView = textView
        self.ruleThickness = 46
        self.reservedThicknessForMarkers = 0
        self.reservedThicknessForAccessoryView = 0
        self.wantsLayer = true
        self.layer?.backgroundColor = backgroundColor.cgColor
        self.invalidateLineNumbers(rebuild: true)
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.ruleThickness = 46
        self.reservedThicknessForMarkers = 0
        self.reservedThicknessForAccessoryView = 0
        self.wantsLayer = true
        self.layer?.backgroundColor = backgroundColor.cgColor
    }

    func invalidateLineNumbers(rebuild: Bool = false) {
        if rebuild {
            rebuildLineStarts()
        }
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let clipView = textView.enclosingScrollView?.contentView else {
            return
        }

        backgroundColor.setFill()
        rect.fill()
        layoutManager.ensureLayout(for: textContainer)
        if lineStarts.isEmpty {
            rebuildLineStarts()
        }

        let visibleRect = textView.convert(clipView.bounds, from: clipView)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let textOrigin = textView.textContainerOrigin

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, glyphRange, _ in
            guard glyphRange.location < layoutManager.numberOfGlyphs else { return }
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
            let lineNumber = self.lineNumber(forUTF16Offset: characterIndex)
            let y = textOrigin.y + usedRect.minY
            let point = self.convert(NSPoint(x: 0, y: y), from: textView)
            let label = "\(lineNumber)" as NSString
            label.draw(
                in: NSRect(
                    x: 4,
                    y: point.y,
                    width: self.ruleThickness - 10,
                    height: usedRect.height
                ),
                withAttributes: self.labelAttributes
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    private func rebuildLineStarts() {
        guard let text = textView?.string else {
            lineStarts = [0]
            return
        }
        let nsText = text as NSString
        guard nsText.length > 0 else {
            lineStarts = [0]
            return
        }

        var starts: [Int] = []
        var location = 0
        while location < nsText.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsText.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: location, length: 0)
            )
            if starts.last != lineStart {
                starts.append(lineStart)
            }
            guard lineEnd > location else { break }
            location = lineEnd
        }
        if text.hasSuffix("\n") {
            starts.append(nsText.length)
        }
        lineStarts = starts.isEmpty ? [0] : starts
    }

    private func lineNumber(forUTF16Offset offset: Int) -> Int {
        var low = 0
        var high = max(0, lineStarts.count - 1)
        while low <= high {
            let mid = (low + high) / 2
            if lineStarts[mid] <= offset {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return max(1, high + 1)
    }
}

nonisolated struct HTMLWorkspaceDOMSnapshot: Equatable, Sendable {
    enum Source: String, Sendable {
        case source
        case live

        var label: String {
            switch self {
            case .source: "source"
            case .live: "live"
            }
        }
    }

    var outline: String
    var nodeCount: Int
    var source: Source
}

nonisolated enum HTMLWorkspaceDOMOutline {
    static func outline(for html: String) -> String {
        let tags = tagSummaries(in: html)
        guard !tags.isEmpty else { return "No DOM nodes" }
        return tags.joined(separator: "\n")
    }

    static func nodeCount(in html: String) -> Int {
        tagSummaries(in: html).count
    }

    static func snapshot(for html: String, source: HTMLWorkspaceDOMSnapshot.Source = .source) -> HTMLWorkspaceDOMSnapshot {
        let tags = tagSummaries(in: html)
        return HTMLWorkspaceDOMSnapshot(
            outline: tags.isEmpty ? "No DOM nodes" : tags.joined(separator: "\n"),
            nodeCount: tags.count,
            source: source
        )
    }

    private static func tagSummaries(in html: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"<\s*([A-Za-z][A-Za-z0-9:-]*)([^>]*)>"#
        ) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = expression.matches(in: html, range: range)
        return matches.compactMap { match in
            guard let tagRange = Range(match.range(at: 1), in: html) else { return nil }
            let tag = String(html[tagRange]).lowercased()
            guard !tag.hasPrefix("!") else { return nil }
            let attributes = match.range(at: 2).location == NSNotFound
                ? ""
                : Range(match.range(at: 2), in: html).map { String(html[$0]) } ?? ""
            let id = captureAttribute("id", in: attributes).map { "#\($0)" } ?? ""
            let classes = captureAttribute("class", in: attributes)
                .map { "." + $0.split(separator: " ").joined(separator: ".") } ?? ""
            let dataMarker = attributes.contains("data-") ? " data" : ""
            return "<\(tag)\(id)\(classes)>\(dataMarker)"
        }
    }

    private static func captureAttribute(_ name: String, in attributes: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        guard let expression = try? NSRegularExpression(
            pattern: #"\#(escapedName)\s*=\s*["']([^"']+)["']"#,
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = expression.firstMatch(in: attributes, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: attributes) else {
            return nil
        }
        return String(attributes[valueRange])
    }
}
