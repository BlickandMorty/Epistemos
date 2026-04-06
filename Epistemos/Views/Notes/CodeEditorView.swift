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
                onContentChange: onContentChange
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

        NSLayoutConstraint.activate([
            gutterView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutterView.topAnchor.constraint(equalTo: container.topAnchor),
            gutterView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutterView.widthAnchor.constraint(equalToConstant: 48),

            scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        context.coordinator.textView = textView
        context.coordinator.gutterView = gutterView
        context.coordinator.scrollView = scrollView

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
        // Scroll sync for gutter
        if let clipView = scrollView.contentView as? NSClipView {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.scrollDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }

        // Initial highlighting
        textView.highlightSyntax(theme: theme)

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

        init(parent: CodeEditorRepresentable) {
            self.parent = parent
        }

        @objc func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            tv.highlightSyntax(theme: parent.theme)
            gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
            parent.onContentChange?(tv.string)
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            let (line, col) = tv.cursorPosition()
            parent.cursorLine = line
            parent.cursorCol = col
        }

        @objc func scrollDidChange(_ notification: Notification) {
            gutterView?.setNeedsDisplay(gutterView?.bounds ?? .zero)
        }
    }
}

// MARK: - CodeTextView (NSTextView subclass)

class CodeTextView: NSTextView {
    var language: String = ""
    private var lastHighlightHash: Int = 0

    func cursorPosition() -> (line: Int, col: Int) {
        let loc = selectedRange().location
        guard loc <= string.count else { return (1, 1) }
        let prefix = (string as NSString).substring(to: loc)
        let lines = prefix.components(separatedBy: "\n")
        return (lines.count, (lines.last?.count ?? 0) + 1)
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
