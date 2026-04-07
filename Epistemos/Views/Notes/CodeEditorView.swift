// CodeEditorView.swift
//
// Full-screen native code editor for Epistemos. Replaces the prose editor
// when a note is detected as a code file (.swift, .rs, .py, etc.).
// Features: line number gutter, tree-sitter syntax highlighting, minimap,
// status bar with cursor position + language.
//
// Architecture: NSViewRepresentable wrapping NSScrollView → CodeTextView
// with a custom LineNumberGutter on the left and MinimapView on the right.
// Tree-sitter tokenization reuses the existing Rust FFI pipeline
// (markdown_parse_code_tokens) but applies it to the entire file rather
// than just fenced code blocks within markdown.
//
// 2026-04-06.

import AppKit
import SwiftUI

// MARK: - Language Detection

nonisolated enum CodeLanguage {
    /// Detect language from file extension. Returns nil for markdown/unknown (use prose editor).
    static func detect(from path: String) -> String? {
        let ext = (path as NSString).pathExtension.lowercased()
        if ext.isEmpty {
            // Check filename patterns
            let name = (path as NSString).lastPathComponent.lowercased()
            switch name {
            case "makefile", "gnumakefile": return "bash"
            case "dockerfile": return "bash"
            case "cargo.toml", "pyproject.toml": return "toml"
            case ".gitignore", ".env": return nil
            default: return nil
            }
        }
        switch ext {
        case "swift": return "swift"
        case "rs": return "rust"
        case "py", "pyw": return "python"
        case "js", "mjs", "cjs": return "javascript"
        case "jsx": return "javascript"
        case "ts", "mts": return "typescript"
        case "tsx": return "typescript"
        case "json", "jsonl": return "json"
        case "html", "htm": return "html"
        case "css", "scss", "less": return "css"
        case "sh", "bash", "zsh", "fish": return "bash"
        case "go": return "go"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp", "hxx", "mm": return "cpp"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "xml", "plist", "svg": return "html"
        case "md", "markdown", "txt": return nil // prose editor
        case "gd": return "gdscript"
        case "lua": return "lua"
        case "rb": return "ruby"
        case "java", "kt", "kts": return "java"
        case "sql": return "sql"
        case "r": return "r"
        case "zig": return "zig"
        case "wgsl", "glsl", "metal", "hlsl": return "c" // close enough for highlighting
        default: return nil
        }
    }

    /// Display name for the status bar.
    static func displayName(for language: String) -> String {
        switch language {
        case "swift": return "Swift"
        case "rust": return "Rust"
        case "python": return "Python"
        case "javascript": return "JavaScript"
        case "typescript": return "TypeScript"
        case "json": return "JSON"
        case "html": return "HTML"
        case "css": return "CSS"
        case "bash": return "Shell"
        case "go": return "Go"
        case "c": return "C"
        case "cpp": return "C++"
        case "yaml": return "YAML"
        case "toml": return "TOML"
        case "gdscript": return "GDScript"
        default: return language.capitalized
        }
    }
}

// MARK: - CodeEditorView (SwiftUI)

struct CodeEditorView: View {
    let initialContent: String
    let language: String
    let onContentChange: ((String) -> Void)?

    @Environment(UIState.self) private var ui
    @Environment(NoteChatState.self) private var noteChatState: NoteChatState?

    @State private var cursorLine: Int = 1
    @State private var cursorCol: Int = 1

    init(content: String, language: String, onContentChange: ((String) -> Void)? = nil) {
        self.initialContent = content
        self.language = language
        self.onContentChange = onContentChange
    }

    var body: some View {
        VStack(spacing: 0) {
            CodeEditorRepresentable(
                content: initialContent,
                language: language,
                theme: ui.theme,
                cursorLine: $cursorLine,
                cursorCol: $cursorCol,
                onContentChange: onContentChange,
                noteChatState: noteChatState
            )

            // Status bar
            HStack(spacing: 16) {
                Text("Line: \(cursorLine)  Col: \(cursorCol)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(CodeLanguage.displayName(for: language))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("UTF-8")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.bar)
        }
    }
}

// MARK: - NSViewRepresentable Bridge

struct CodeEditorRepresentable: NSViewRepresentable {
    let content: String
    let language: String
    let theme: EpistemosTheme
    @Binding var cursorLine: Int
    @Binding var cursorCol: Int
    let onContentChange: ((String) -> Void)?
    weak var noteChatState: NoteChatState?

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // Build the code text view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = CodeTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        let fontSize: CGFloat = 13
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = theme.isDark ? .white : NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
        textView.backgroundColor = theme.isDark
            ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            : NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
        textView.insertionPointColor = theme.isDark ? .white : .black
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor
        ]

        // No word wrap — horizontal scroll like Xcode
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        textView.string = content
        textView.language = language

        scrollView.documentView = textView

        // Line number gutter
        let gutterView = LineNumberGutter(textView: textView)
        gutterView.backgroundColor = textView.backgroundColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        gutterView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(gutterView)
        container.addSubview(scrollView)

        // Minimap
        let minimapView = MinimapView(textView: textView, scrollView: scrollView)
        minimapView.translatesAutoresizingMaskIntoConstraints = false
        minimapView.backgroundColor = textView.backgroundColor
        container.addSubview(minimapView)

        NSLayoutConstraint.activate([
            gutterView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutterView.topAnchor.constraint(equalTo: container.topAnchor),
            gutterView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutterView.widthAnchor.constraint(equalToConstant: 48),

            scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: minimapView.leadingAnchor),

            minimapView.topAnchor.constraint(equalTo: container.topAnchor),
            minimapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            minimapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            minimapView.widthAnchor.constraint(equalToConstant: 80),
        ])

        context.coordinator.textView = textView
        context.coordinator.gutterView = gutterView
        context.coordinator.scrollView = scrollView
        context.coordinator.minimapView = minimapView

        // Observe text changes for highlighting + cursor tracking
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        // Scroll sync for gutter + minimap
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // Initial highlighting + minimap
        textView.highlightSyntax(theme: theme)
        minimapView.rebuildTokenRects(theme: theme)

        // Wire AI chat writer closures (undo-safe via shouldChangeText triad)
        if let chatState = noteChatState {
            chatState.noteBodyProvider = { [weak textView] in
                textView?.string ?? ""
            }

            chatState.noteBodyWriter = { [weak textView] newContent in
                DispatchQueue.main.async {
                    guard let tv = textView else { return }
                    let fullRange = NSRange(location: 0, length: tv.string.utf16.count)
                    tv.shouldChangeText(in: fullRange, replacementString: newContent)
                    tv.textStorage?.replaceCharacters(in: fullRange, with: newContent)
                    tv.didChangeText()
                }
            }

            chatState.noteRangeWriter = { [weak textView] lineRange, replacement in
                DispatchQueue.main.async {
                    guard let tv = textView else { return }
                    let nsRange = tv.nsRange(forLineRange: lineRange)
                    tv.shouldChangeText(in: nsRange, replacementString: replacement)
                    tv.textStorage?.replaceCharacters(in: nsRange, with: replacement)
                    tv.didChangeText()
                }
            }
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Theme changes: re-highlight
        context.coordinator.textView?.highlightSyntax(theme: theme)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: CodeEditorRepresentable
        weak var textView: CodeTextView?
        weak var gutterView: LineNumberGutter?
        weak var scrollView: NSScrollView?
        weak var minimapView: MinimapView?

        init(parent: CodeEditorRepresentable) {
            self.parent = parent
        }

        @objc func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            tv.invalidateGuideCache()
            tv.highlightSyntax(theme: parent.theme)
            gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
            minimapView?.rebuildTokenRects(theme: parent.theme)
            parent.onContentChange?(tv.string)
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            let (line, col) = tv.cursorPosition()
            parent.cursorLine = line
            parent.cursorCol = col
            // Only redraw the visible area for line highlight — guides are cached
            tv.setNeedsDisplay(tv.visibleRect)
            gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
        }

        @objc func scrollDidChange(_ notification: Notification) {
            gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
            minimapView?.setNeedsDisplay(minimapView?.bounds ?? .zero)
        }
    }
}

// MARK: - CodeTextView (NSTextView subclass)

class CodeTextView: NSTextView {
    var language: String = ""
    private var lastHighlightHash: Int = 0

    // Bracket matching state
    private var matchedBracketRanges: [NSRange] = []
    private static let bracketPairs: [(open: Character, close: Character)] = [
        ("(", ")"), ("[", "]"), ("{", "}")
    ]
    private static let openBrackets: Set<Character> = ["(", "[", "{"]
    private static let closeBrackets: Set<Character> = [")", "]", "}"]
    private static let bracketMap: [Character: Character] = [
        "(": ")", ")": "(",
        "[": "]", "]": "[",
        "{": "}", "}": "{"
    ]
    private static let maxBracketScan = 10_000

    func cursorPosition() -> (line: Int, col: Int) {
        let loc = selectedRange().location
        guard loc <= string.count else { return (1, 1) }
        let prefix = (string as NSString).substring(to: loc)
        let lines = prefix.components(separatedBy: "\n")
        return (lines.count, (lines.last?.count ?? 0) + 1)
    }

    // MARK: - Current Line Highlight + Indent Guides

    // Cache indent guide paths — only rebuild on text change, not on scroll/selection
    private var cachedGuidePath: NSBezierPath?
    private var cachedGuideHash: Int = 0
    private var cachedSpaceWidth: CGFloat = 0

    func invalidateGuideCache() {
        cachedGuidePath = nil
        cachedGuideHash = 0
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let lm = layoutManager, let tc = textContainer else { return }

        // --- Current line highlight ---
        let insertionLoc = selectedRange().location
        let lineRange = (string as NSString).lineRange(for: NSRange(location: insertionLoc, length: 0))
        let glyphRange = lm.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        let lineRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        let highlightRect = NSRect(
            x: 0,
            y: lineRect.origin.y + textContainerInset.height,
            width: bounds.width,
            height: lineRect.height
        )
        (NSColor.labelColor.withAlphaComponent(0.06)).set()
        highlightRect.fill()

        // --- Indent guides (cached, only rebuilt on text change) ---
        let contentHash = string.hashValue
        if cachedGuidePath == nil || cachedGuideHash != contentHash {
            let monoFont = font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            cachedSpaceWidth = (" " as NSString).size(withAttributes: [.font: monoFont]).width
            cachedGuideHash = contentHash
            cachedGuidePath = buildGuidePath(lm: lm, tc: tc)
        }

        if let path = cachedGuidePath {
            NSColor.separatorColor.withAlphaComponent(0.15).set()
            path.stroke()
        }
    }

    private func buildGuidePath(lm: NSLayoutManager, tc: NSTextContainer) -> NSBezierPath {
        let nsStr = string as NSString
        let indentWidth: CGFloat = 4
        let sw = cachedSpaceWidth
        let fullRange = NSRange(location: 0, length: nsStr.length)
        let path = NSBezierPath()
        path.lineWidth = 0.5

        nsStr.enumerateSubstrings(
            in: fullRange,
            options: [.byParagraphs, .substringNotRequired]
        ) { _, substringRange, _, _ in
            let lineStr = nsStr.substring(with: substringRange)
            let leadingSpaces = lineStr.prefix(while: { $0 == " " }).count
            let indentLevels = leadingSpaces / Int(indentWidth)
            guard indentLevels > 0 else { return }

            let gRange = lm.glyphRange(forCharacterRange: substringRange, actualCharacterRange: nil)
            let lineRect = lm.boundingRect(forGlyphRange: gRange, in: tc)
            let lineY = lineRect.origin.y + self.textContainerInset.height

            for level in 1...indentLevels {
                let x = self.textContainerInset.width + CGFloat(level) * indentWidth * sw
                path.move(to: NSPoint(x: x, y: lineY))
                path.line(to: NSPoint(x: x, y: lineY + lineRect.height))
            }
        }

        return path
    }

    // MARK: - Bracket Matching

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        if !stillSelecting {
            updateBracketMatching()
        }
    }

    private func updateBracketMatching() {
        // Clear previous matches on main thread
        guard let lm = layoutManager else { return }
        for range in matchedBracketRanges {
            lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
        }
        matchedBracketRanges.removeAll()

        let loc = selectedRange().location
        let text = string
        let nsStr = text as NSString
        guard nsStr.length > 0 else { return }

        // Check character at cursor and before cursor
        let positions = [loc, loc > 0 ? loc - 1 : -1].filter { $0 >= 0 && $0 < nsStr.length }

        // Scan synchronously — 10K char cap keeps it fast even on large files
        for pos in positions {
            let ch = Character(UnicodeScalar(nsStr.character(at: pos))!)
            guard Self.openBrackets.contains(ch) || Self.closeBrackets.contains(ch) else { continue }
            guard let match = Self.bracketMap[ch] else { continue }

            if let matchPos = Self.findMatchingBracketStatic(for: ch, matching: match, at: pos, in: nsStr) {
                let matchColor = NSColor.systemYellow.withAlphaComponent(0.25)
                let r1 = NSRange(location: pos, length: 1)
                let r2 = NSRange(location: matchPos, length: 1)
                lm.addTemporaryAttribute(.backgroundColor, value: matchColor, forCharacterRange: r1)
                lm.addTemporaryAttribute(.backgroundColor, value: matchColor, forCharacterRange: r2)
                matchedBracketRanges.append(contentsOf: [r1, r2])
                break
            }
        }
    }

    private static func findMatchingBracketStatic(for bracket: Character, matching target: Character, at position: Int, in nsStr: NSString) -> Int? {
        let isOpen = Self.openBrackets.contains(bracket)
        let direction = isOpen ? 1 : -1
        var depth = 0
        var current = position + direction
        var scanned = 0

        while current >= 0, current < nsStr.length, scanned < Self.maxBracketScan {
            let ch = Character(UnicodeScalar(nsStr.character(at: current))!)
            if ch == bracket {
                depth += 1
            } else if ch == target {
                if depth == 0 { return current }
                depth -= 1
            }
            current += direction
            scanned += 1
        }
        return nil
    }

    func highlightSyntax(theme: EpistemosTheme) {
        guard !language.isEmpty, !string.isEmpty else { return }

        // Skip if content hasn't changed
        let hash = string.hashValue &+ language.hashValue
        guard hash != lastHighlightHash else { return }
        lastHighlightHash = hash

        let text = string
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Reset to base monospace font + color
        let storage = textStorage ?? NSTextStorage()
        storage.beginEditing()
        storage.addAttribute(.font, value: font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
        storage.addAttribute(.foregroundColor, value: textColor ?? .white, range: fullRange)

        // Call tree-sitter via FFI
        let maxTokens: UInt32 = 16384
        let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
        defer { buffer.deallocate() }

        let tokenCount = language.withCString { langPtr in
            text.withCString { codePtr in
                markdown_parse_code_tokens(
                    codePtr, UInt32(text.utf8.count),
                    langPtr, buffer, maxTokens
                )
            }
        }

        // Build a UTF-8 → UTF-16 offset map for the visible portion
        let utf8 = Array(text.utf8)
        var utf8ToUtf16 = [Int](repeating: 0, count: utf8.count + 1)
        var utf16Pos = 0
        var i = 0
        while i < utf8.count {
            utf8ToUtf16[i] = utf16Pos
            let byte = utf8[i]
            let seqLen: Int
            if byte < 0x80 { seqLen = 1 }
            else if byte < 0xE0 { seqLen = 2 }
            else if byte < 0xF0 { seqLen = 3 }
            else { seqLen = 4 }
            utf16Pos += (seqLen == 4) ? 2 : 1
            i += seqLen
        }
        utf8ToUtf16[utf8.count] = utf16Pos

        for ti in 0..<Int(tokenCount) {
            let token = buffer[ti]
            let start8 = Int(token.start)
            let end8 = min(Int(token.end), utf8.count)
            guard start8 < utf8.count, start8 < end8 else { continue }
            let start16 = utf8ToUtf16[start8]
            let end16 = utf8ToUtf16[end8]
            let range = NSRange(location: start16, length: end16 - start16)
            guard range.location + range.length <= nsString.length else { continue }

            let color = theme.nsColorForTokenType(token.token_type)
            storage.addAttribute(.foregroundColor, value: color, range: range)

            // Italicize comments
            if token.token_type == 3, let baseFont = font {
                let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: italic, range: range)
            }
        }

        storage.endEditing()
    }

    // Tab key inserts 4 spaces (like Xcode)
    override func insertTab(_ sender: Any?) {
        insertText("    ", replacementRange: selectedRange())
    }

    /// Convert a 1-indexed inclusive line range to an NSRange for text mutations.
    func nsRange(forLineRange lineRange: ClosedRange<Int>) -> NSRange {
        let nsStr = string as NSString
        var lineStart = 0
        var currentLine = 1
        var rangeStart = 0
        var rangeEnd = nsStr.length

        while lineStart < nsStr.length {
            let lineEnd = nsStr.lineRange(for: NSRange(location: lineStart, length: 0))
            if currentLine == lineRange.lowerBound {
                rangeStart = lineEnd.location
            }
            if currentLine == lineRange.upperBound {
                rangeEnd = NSMaxRange(lineEnd)
                break
            }
            lineStart = NSMaxRange(lineEnd)
            currentLine += 1
        }

        return NSRange(location: rangeStart, length: rangeEnd - rangeStart)
    }
}

// MARK: - Line Number Gutter

class LineNumberGutter: NSView {
    private weak var textView: CodeTextView?
    var backgroundColor: NSColor = .clear

    private let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let lineNumberColor = NSColor.secondaryLabelColor
    private let currentLineColor = NSColor.labelColor

    init(textView: CodeTextView) {
        self.textView = textView
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let tv = textView,
              let scrollView = tv.enclosingScrollView else { return }

        // Background
        backgroundColor.set()
        dirtyRect.fill()

        // Separator line
        let sepRect = NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height)
        NSColor.separatorColor.withAlphaComponent(0.2).set()
        sepRect.fill()

        let content = tv.string as NSString
        let visibleRect = scrollView.contentView.bounds
        let cursorLine = tv.cursorPosition().line

        // Count total lines
        var lineStarts: [Int] = [0]
        content.enumerateSubstrings(
            in: NSRange(location: 0, length: content.length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, range, _, _ in
            lineStarts.append(NSMaxRange(range))
        }
        let totalLines = lineStarts.count

        // Draw line numbers
        let attrs: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]
        let currentAttrs: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: currentLineColor
        ]

        guard let layoutManager = tv.layoutManager,
              let textContainer = tv.textContainer else { return }

        for lineNum in 1...totalLines {
            let charIndex = lineStarts[lineNum - 1]
            guard charIndex <= content.length else { break }
            let safeIndex = min(charIndex, content.length)
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: safeIndex, length: 0),
                actualCharacterRange: nil
            )
            let lineRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textContainer
            )

            let y = lineRect.origin.y + tv.textContainerInset.height - visibleRect.origin.y
            guard y + lineRect.height > 0, y < bounds.height else { continue }

            let numStr = "\(lineNum)" as NSString
            let isCurrentLine = lineNum == cursorLine
            let size = numStr.size(withAttributes: isCurrentLine ? currentAttrs : attrs)
            let drawPoint = NSPoint(x: bounds.width - size.width - 8, y: y)
            numStr.draw(at: drawPoint, withAttributes: isCurrentLine ? currentAttrs : attrs)
        }
    }
}

// MARK: - Minimap

class MinimapView: NSView {
    private weak var textView: CodeTextView?
    private weak var scrollView: NSScrollView?
    var backgroundColor: NSColor = .clear

    /// Precomputed token rectangles in minimap coordinates.
    private var tokenRects: [(rect: CGRect, color: NSColor)] = []
    private var totalDocumentLines: Int = 1

    init(textView: CodeTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    /// Rebuild token rects asynchronously. Call on textDidChange, not on scroll.
    func rebuildTokenRects(theme: EpistemosTheme) {
        guard let tv = textView, !tv.string.isEmpty, !tv.language.isEmpty else {
            tokenRects.removeAll()
            setNeedsDisplay(bounds)
            return
        }

        let text = tv.string
        let language = tv.language
        let lines = text.components(separatedBy: "\n")
        totalDocumentLines = max(lines.count, 1)

        // Tokenize via FFI
        let maxTokens: UInt32 = 16384
        let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
        defer { buffer.deallocate() }

        let tokenCount = language.withCString { langPtr in
            text.withCString { codePtr in
                markdown_parse_code_tokens(
                    codePtr, UInt32(text.utf8.count),
                    langPtr, buffer, maxTokens
                )
            }
        }

        // Build line start offsets (UTF-8)
        let utf8 = Array(text.utf8)
        var lineStartOffsets: [Int] = [0]
        for (i, byte) in utf8.enumerated() where byte == 0x0A {
            lineStartOffsets.append(i + 1)
        }

        // Map tokens to minimap rects
        var rects: [(rect: CGRect, color: NSColor)] = []
        let lineHeight: CGFloat = 2.0 // each line is 2px tall in minimap
        let charWidth: CGFloat = 0.8  // each char is <1px wide

        for ti in 0..<Int(tokenCount) {
            let token = buffer[ti]
            let start8 = Int(token.start)
            let end8 = min(Int(token.end), utf8.count)
            guard start8 < end8 else { continue }

            // Find which line this token starts on via binary search
            var lo = 0, hi = lineStartOffsets.count - 1
            while lo < hi {
                let mid = (lo + hi + 1) / 2
                if lineStartOffsets[mid] <= start8 { lo = mid } else { hi = mid - 1 }
            }
            let line = lo
            let col = start8 - lineStartOffsets[line]
            let tokenLen = end8 - start8

            let rect = CGRect(
                x: 4 + CGFloat(col) * charWidth,
                y: CGFloat(line) * lineHeight,
                width: CGFloat(tokenLen) * charWidth,
                height: lineHeight
            )
            let color = theme.nsColorForTokenType(token.token_type)
            rects.append((rect, color))
        }

        tokenRects = rects
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Background
        backgroundColor.set()
        dirtyRect.fill()

        // Separator on left edge
        NSColor.separatorColor.withAlphaComponent(0.2).set()
        NSRect(x: 0, y: 0, width: 1, height: bounds.height).fill()

        guard !tokenRects.isEmpty else { return }

        let lineHeight: CGFloat = 2.0
        let totalHeight = CGFloat(totalDocumentLines) * lineHeight

        // Scale factor to fit content into view height
        let scale: CGFloat = totalHeight > bounds.height
            ? bounds.height / totalHeight
            : 1.0

        // Draw token rects
        for (rect, color) in tokenRects {
            let scaledRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y * scale,
                width: min(rect.width, bounds.width - rect.origin.x - 2),
                height: max(rect.height * scale, 1)
            )
            guard scaledRect.intersects(dirtyRect) else { continue }
            color.withAlphaComponent(0.7).set()
            scaledRect.fill()
        }

        // Viewport indicator
        if let sv = scrollView, let tv = textView {
            let contentHeight = tv.frame.height
            guard contentHeight > 0 else { return }
            let visibleRect = sv.contentView.bounds
            let yRatio = visibleRect.origin.y / contentHeight
            let hRatio = visibleRect.height / contentHeight
            let drawableHeight = totalHeight * scale

            let vpRect = NSRect(
                x: 0,
                y: yRatio * drawableHeight,
                width: bounds.width,
                height: max(hRatio * drawableHeight, 20)
            )
            NSColor.labelColor.withAlphaComponent(0.08).set()
            vpRect.fill()

            // Top/bottom edges
            NSColor.labelColor.withAlphaComponent(0.15).set()
            NSRect(x: 0, y: vpRect.origin.y, width: bounds.width, height: 1).fill()
            NSRect(x: 0, y: vpRect.maxY, width: bounds.width, height: 1).fill()
        }
    }

    // Click-to-scroll
    override func mouseDown(with event: NSEvent) {
        scrollToClick(event)
    }

    override func mouseDragged(with event: NSEvent) {
        scrollToClick(event)
    }

    private func scrollToClick(_ event: NSEvent) {
        guard let sv = scrollView, let tv = textView else { return }
        let localPoint = convert(event.locationInWindow, from: nil)

        let lineHeight: CGFloat = 2.0
        let totalHeight = CGFloat(totalDocumentLines) * lineHeight
        let scale: CGFloat = totalHeight > bounds.height
            ? bounds.height / totalHeight
            : 1.0
        let drawableHeight = totalHeight * scale
        guard drawableHeight > 0 else { return }

        let ratio = localPoint.y / drawableHeight
        let contentHeight = tv.frame.height
        let targetY = ratio * contentHeight - sv.contentView.bounds.height / 2
        let clampedY = max(0, min(targetY, contentHeight - sv.contentView.bounds.height))

        sv.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
        sv.reflectScrolledClipView(sv.contentView)
    }
}

// MARK: - Code Inspector Views (Graph Node Preview)
// Lightweight syntax-highlighted views for the graph inspector panel.
// No minimap, no line numbers — just clean colored code.

/// Read-only syntax-highlighted code preview for the graph inspector.
struct CodeInspectorPreview: NSViewRepresentable {
    let content: String
    let language: String
    let theme: EpistemosTheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.drawsBackground = true

        let fontSize: CGFloat = 12
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = theme.isDark ? .white : NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
        textView.backgroundColor = theme.isDark
            ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            : NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        textView.textContainerInset = NSSize(width: 12, height: 12)

        textView.string = content
        scrollView.documentView = textView
        context.coordinator.textView = textView

        applySyntaxHighlighting(to: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != content {
            tv.string = content
            applySyntaxHighlighting(to: tv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        weak var textView: NSTextView?
    }

    fileprivate func applySyntaxHighlighting(to textView: NSTextView) {
        CodeSyntaxHighlighter.apply(to: textView, language: language, theme: theme)
    }
}

/// Shared syntax highlighting logic for inspector views.
enum CodeSyntaxHighlighter {
    static func apply(to textView: NSTextView, language: String, theme: EpistemosTheme) {
        let text = textView.string
        guard !text.isEmpty, !language.isEmpty else { return }

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let storage = textView.textStorage ?? NSTextStorage()

        storage.beginEditing()
        storage.addAttribute(.font, value: textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)
        storage.addAttribute(.foregroundColor, value: textView.textColor ?? .white, range: fullRange)

        let maxTokens: UInt32 = 16384
        let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
        defer { buffer.deallocate() }

        let tokenCount = language.withCString { langPtr in
            text.withCString { codePtr in
                markdown_parse_code_tokens(codePtr, UInt32(text.utf8.count), langPtr, buffer, maxTokens)
            }
        }

        let utf8 = Array(text.utf8)
        var utf8ToUtf16 = [Int](repeating: 0, count: utf8.count + 1)
        var utf16Pos = 0
        var i = 0
        while i < utf8.count {
            utf8ToUtf16[i] = utf16Pos
            let byte = utf8[i]
            let seqLen: Int
            if byte < 0x80 { seqLen = 1 }
            else if byte < 0xE0 { seqLen = 2 }
            else if byte < 0xF0 { seqLen = 3 }
            else { seqLen = 4 }
            utf16Pos += (seqLen == 4) ? 2 : 1
            i += seqLen
        }
        utf8ToUtf16[utf8.count] = utf16Pos

        for ti in 0..<Int(tokenCount) {
            let token = buffer[ti]
            let start8 = Int(token.start)
            let end8 = min(Int(token.end), utf8.count)
            guard start8 < utf8.count, start8 < end8 else { continue }
            let start16 = utf8ToUtf16[start8]
            let end16 = utf8ToUtf16[end8]
            let range = NSRange(location: start16, length: end16 - start16)
            guard range.location + range.length <= nsString.length else { continue }

            let color = theme.nsColorForTokenType(token.token_type)
            storage.addAttribute(.foregroundColor, value: color, range: range)

            if token.token_type == 3, let baseFont = textView.font {
                let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: italic, range: range)
            }
        }

        storage.endEditing()
    }
}

/// Editable syntax-highlighted code editor for the graph inspector.
/// Lightweight: no minimap, no gutter — just colored code with undo support.
struct CodeInspectorEditor: NSViewRepresentable {
    @Binding var text: String
    let language: String
    let theme: EpistemosTheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.drawsBackground = true

        let fontSize: CGFloat = 12
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = theme.isDark ? .white : NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
        textView.backgroundColor = theme.isDark
            ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            : NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        textView.insertionPointColor = theme.isDark ? .white : .black
        textView.textContainerInset = NSSize(width: 12, height: 12)

        textView.string = text
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.parent = self

        CodeSyntaxHighlighter.apply(to: textView, language: language, theme: theme)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Avoid feedback loop
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        weak var textView: NSTextView?
        var parent: CodeInspectorEditor?

        @objc func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent?.text = tv.string
            // Re-highlight after edit
            if let p = parent {
                CodeSyntaxHighlighter.apply(to: tv, language: p.language, theme: p.theme)
            }
        }
    }
}
