// CodeEditorView.swift
//
// Native code editor chrome for Epistemos. Markdown documents use MarkEdit's
// verbatim chrome; code documents keep the Epistemos top bar, search, outline,
// semantic sidecars, and live preview while sharing MarkEdit CoreEditor as the
// editing engine.
//
// 2026-04-06.

import AppKit
import SwiftUI
import SwiftData
import Accelerate

// Helper extension for hex color initialization
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    func rgbSafeForCodeEditorTheme() -> NSColor {
        if let converted = usingColorSpace(.deviceRGB) {
            return converted
        }
        if let converted = usingColorSpace(.sRGB) {
            return converted
        }
        if let converted = usingColorSpace(.extendedSRGB) {
            return converted
        }
        if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
           let convertedCGColor = cgColor.converted(
               to: colorSpace,
               intent: .defaultIntent,
               options: nil
           ),
           let converted = NSColor(cgColor: convertedCGColor) {
            return converted
        }
        if let components = cgColor.components {
            switch components.count {
            case 2:
                let gray = components[0]
                return NSColor(deviceRed: gray, green: gray, blue: gray, alpha: cgColor.alpha)
            case 4:
                return NSColor(
                    deviceRed: components[0],
                    green: components[1],
                    blue: components[2],
                    alpha: components[3]
                )
            default:
                break
            }
        }
        return NSColor(deviceRed: 0, green: 0, blue: 0, alpha: alphaComponent)
    }
}

// MARK: - SwiftUI Color → NSColor

extension Color {
    /// Converts SwiftUI Color to NSColor (macOS only)
    func toNSColor() -> NSColor {
        NSColor(self).rgbSafeForCodeEditorTheme()
    }
}

enum CodeEditorPerformancePolicy {
    static func shouldRefreshSemanticContext(isSidebarVisible: Bool) -> Bool {
        isSidebarVisible
    }

    static func outlineRefreshDelay(characterCount: Int) -> Duration {
        switch characterCount {
        case ..<4_000:
            .milliseconds(90)
        case ..<20_000:
            .milliseconds(160)
        default:
            .milliseconds(280)
        }
    }

    static func outlineRefreshDelayMilliseconds(characterCount: Int) -> Int {
        switch characterCount {
        case ..<4_000:
            90
        case ..<20_000:
            160
        default:
            280
        }
    }

    static func insightRefreshDelay(characterCount: Int) -> Duration {
        switch characterCount {
        case ..<2_000:
            .milliseconds(180)
        case ..<10_000:
            .milliseconds(320)
        default:
            .milliseconds(520)
        }
    }

    static func insightRefreshDelayMilliseconds(characterCount: Int) -> Int {
        switch characterCount {
        case ..<2_000:
            180
        case ..<10_000:
            320
        default:
            520
        }
    }

    static let semanticRefreshDelay: Duration = .milliseconds(220)
    static let scrollGuideRefreshDelay: Duration = .milliseconds(50)
    static let horizontalScrollGeometryRefreshDelay: Duration = .milliseconds(45)
    static let horizontalScrollScanLimitUTF16 = 250_000

    static func indentationGuideRefreshDelay(characterCount: Int) -> Duration {
        switch characterCount {
        case ..<4_000:
            .milliseconds(45)
        case ..<20_000:
            .milliseconds(90)
        default:
            .milliseconds(160)
        }
    }
}

enum CodeEditorScrollConfigurator {
    private static let estimatedWidthPadding: CGFloat = 96
    private static let maximumEstimatedDocumentWidth: CGFloat = 80_000

    static func allowTwoAxisScrolling(textView: NSTextView, scrollView: NSScrollView) {
        configureAlwaysVisibleScrollers(scrollView)

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.height]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        updateTextKitDocumentWidth(textView: textView, scrollView: scrollView)
    }

    private static func configureAlwaysVisibleScrollers(_ scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .allowed
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    private static func updateTextKitDocumentWidth(textView: NSTextView, scrollView: NSScrollView) {
        let inset = textView.textContainerInset.width * 2
        let targetWidth = estimatedDocumentWidth(
            text: textView.string,
            font: textView.font,
            visibleWidth: visibleWidth(for: scrollView),
            horizontalInset: inset
        )
        textView.minSize = NSSize(width: targetWidth, height: 0)
        if abs(textView.frame.width - targetWidth) > 1 {
            textView.setFrameSize(NSSize(
                width: targetWidth,
                height: max(textView.frame.height, scrollView.contentSize.height)
            ))
            textView.needsLayout = true
            textView.needsDisplay = true
        }
    }

    static func estimatedDocumentWidth(
        text: String,
        font: NSFont?,
        visibleWidth: CGFloat,
        horizontalInset: CGFloat
    ) -> CGFloat {
        let font = font ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let charWidth = max(
            1,
            ("W" as NSString).size(withAttributes: [.font: font]).width
        )
        let longestLine = longestLineUTF16Length(
            in: text,
            scanLimit: CodeEditorPerformancePolicy.horizontalScrollScanLimitUTF16
        )
        let estimatedWidth = CGFloat(longestLine) * charWidth + horizontalInset + estimatedWidthPadding
        let minimumWidth = max(visibleWidth, 1)
        return min(max(estimatedWidth, minimumWidth), maximumEstimatedDocumentWidth)
    }

    static func longestLineUTF16Length(in text: String, scanLimit: Int) -> Int {
        var longest = 0
        var current = 0
        var scanned = 0
        var previousWasCarriageReturn = false

        for unit in text.utf16 {
            guard scanned < scanLimit else { break }
            scanned += 1

            if unit == 10 || unit == 13 {
                longest = max(longest, current)
                current = 0
                previousWasCarriageReturn = unit == 13
                continue
            }

            if previousWasCarriageReturn {
                previousWasCarriageReturn = false
            }
            current += 1
        }

        return max(longest, current)
    }

    private static func visibleWidth(for scrollView: NSScrollView) -> CGFloat {
        let contentWidth = scrollView.contentSize.width
        if contentWidth.isFinite, contentWidth > 0 {
            return contentWidth
        }
        let boundsWidth = scrollView.bounds.width
        return boundsWidth.isFinite && boundsWidth > 0 ? boundsWidth : 1
    }
}

nonisolated enum CodeEditorLargeFilePolicy {
    nonisolated static let largeFileCharacterThreshold = 100_000
    nonisolated static let largeFileLineThreshold = 10_000
    nonisolated static let indentGuideViewportOverscanMultiplier: CGFloat = 1.5
    nonisolated static let maximumIndentGuideWindowLines = 1_200

    nonisolated static func usesViewportScopedIndentGuides(characterCount: Int, lineCount: Int) -> Bool {
        characterCount >= largeFileCharacterThreshold || lineCount >= largeFileLineThreshold
    }

    nonisolated static func visibleLineRange(
        visibleRect: NSRect,
        lineHeight: CGFloat,
        lineCount: Int,
        overscanMultiplier: CGFloat = indentGuideViewportOverscanMultiplier,
        maximumLineCount: Int = maximumIndentGuideWindowLines
    ) -> ClosedRange<Int>? {
        guard lineCount > 0,
              lineHeight > 0,
              visibleRect.height > 0,
              maximumLineCount > 0 else { return nil }

        let overscanHeight = max(0, visibleRect.height * overscanMultiplier)
        let minY = max(0, visibleRect.minY - overscanHeight)
        let maxY = max(minY, visibleRect.maxY + overscanHeight)
        let firstLine = max(1, Int(floor(minY / lineHeight)) + 1)
        let lastLine = min(lineCount, Int(ceil(maxY / lineHeight)) + 1)

        guard firstLine <= lastLine else { return nil }

        let lineWindowCount = lastLine - firstLine + 1
        guard lineWindowCount > maximumLineCount else {
            return firstLine...lastLine
        }

        let midpoint = max(1, min(lineCount, Int((Double(firstLine + lastLine) / 2.0).rounded())))
        let halfWindow = max(1, maximumLineCount / 2)
        let latestStart = max(1, lineCount - maximumLineCount + 1)
        let start = max(1, min(midpoint - halfWindow, latestStart))
        let end = min(lineCount, start + maximumLineCount - 1)
        return start...end
    }
}

nonisolated enum CodeEditorLineMetrics {
    /// Count text lines without splitting the full buffer into an array.
    ///
    /// NSTextView represents an empty document as one visual line, and a
    /// trailing newline creates an additional blank line, so the counter starts
    /// at one and increments only on LF bytes. CRLF files are covered by the LF.
    nonisolated static func lineCount(_ text: String) -> Int {
        var count = 1
        for byte in text.utf8 where byte == UInt8(ascii: "\n") {
            count += 1
        }
        return count
    }

    nonisolated static func lineStartUTF16Offsets(in text: String) -> [Int] {
        var offsets: [Int] = [0]
        offsets.reserveCapacity(max(1, text.utf8.count / 32))

        var offset = 0
        var previousWasCR = false
        for codeUnit in text.utf16 {
            offset += 1
            switch codeUnit {
            case 10:
                if previousWasCR {
                    previousWasCR = false
                } else {
                    offsets.append(offset)
                }
            case 13:
                offsets.append(offset)
                previousWasCR = true
            default:
                previousWasCR = false
            }
        }

        return offsets
    }

    nonisolated static func textWindow(
        in text: String,
        lineRange: ClosedRange<Int>,
        lineStartUTF16Offsets: [Int]
    ) -> (text: String, baseLineNumber: Int)? {
        guard !lineStartUTF16Offsets.isEmpty,
              lineRange.lowerBound > 0,
              lineRange.lowerBound <= lineRange.upperBound else { return nil }

        let lowerIndex = min(lineStartUTF16Offsets.count - 1, lineRange.lowerBound - 1)
        let startOffset = lineStartUTF16Offsets[lowerIndex]
        let endOffset: Int
        if lineRange.upperBound < lineStartUTF16Offsets.count {
            endOffset = lineStartUTF16Offsets[lineRange.upperBound]
        } else {
            endOffset = (text as NSString).length
        }
        guard endOffset >= startOffset else { return nil }

        let nsText = text as NSString
        let range = NSRange(location: startOffset, length: endOffset - startOffset)
        return (nsText.substring(with: range), lineRange.lowerBound)
    }
}

nonisolated enum CodeEditorSearchDirection {
    case forward
    case backward
}

nonisolated enum CodeEditorSearchEngine {
    static func find(
        in text: String,
        query: String,
        caseSensitive: Bool,
        direction: CodeEditorSearchDirection,
        currentRange: NSRange?
    ) -> NSRange? {
        let queryLength = (query as NSString).length
        guard !text.isEmpty, queryLength > 0 else { return nil }

        let source = text as NSString
        let textLength = source.length
        let options: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]

        switch direction {
        case .forward:
            let start = forwardSearchStart(currentRange: currentRange, textLength: textLength)
            if let range = firstMatch(
                in: source,
                query: query,
                options: options,
                range: NSRange(location: start, length: textLength - start)
            ) {
                return range
            }
            guard start > 0 else { return nil }
            return firstMatch(
                in: source,
                query: query,
                options: options,
                range: NSRange(location: 0, length: start)
            )

        case .backward:
            let end = backwardSearchEnd(currentRange: currentRange, textLength: textLength)
            if let range = firstMatch(
                in: source,
                query: query,
                options: options.union(.backwards),
                range: NSRange(location: 0, length: end)
            ) {
                return range
            }
            guard end < textLength else { return nil }
            return firstMatch(
                in: source,
                query: query,
                options: options.union(.backwards),
                range: NSRange(location: end, length: textLength - end)
            )
        }
    }

    private static func firstMatch(
        in source: NSString,
        query: String,
        options: NSString.CompareOptions,
        range: NSRange
    ) -> NSRange? {
        guard range.location >= 0,
              range.length >= 0,
              range.location <= source.length,
              range.length <= source.length - range.location else {
            return nil
        }
        let match = source.range(of: query, options: options, range: range)
        return match.location == NSNotFound ? nil : match
    }

    private static func forwardSearchStart(currentRange: NSRange?, textLength: Int) -> Int {
        guard let currentRange else { return 0 }
        guard currentRange.location != NSNotFound else { return 0 }
        let location = min(textLength, max(0, currentRange.location))
        let length = max(0, currentRange.length)
        if currentRange.length > 0 {
            return min(textLength, location + min(length, textLength - location))
        }
        return location
    }

    private static func backwardSearchEnd(currentRange: NSRange?, textLength: Int) -> Int {
        guard let currentRange else { return textLength }
        guard currentRange.location != NSNotFound else { return textLength }
        return min(textLength, max(0, currentRange.location))
    }
}

enum CodeEditorReleasePolicy {
    static let semanticSidebarEnabled = false
    static let aiPartnerEnabled = false
}

nonisolated enum CodeEditorSemanticLSP {
    private static let supportedLanguages: Set<String> = ["rust", "swift"]
    private static let pollIntervalNanos: UInt64 = 1_000_000

    static var runtimeAvailable: Bool {
        #if canImport(agent_coreFFI)
        true
        #else
        false
        #endif
    }

    static func supportsLanguage(language: String) -> Bool {
        supportedLanguages.contains(language.lowercased())
    }

    static func canRun(language: String) -> Bool {
        runtimeAvailable && supportsLanguage(language: language)
    }

    static func unavailableMessage(language: String) -> String {
        if !supportsLanguage(language: language) {
            return "Semantic LSP is not available for \(CodeLanguage.displayName(for: language))."
        }
        if !runtimeAvailable {
            return "Semantic LSP unavailable: in-process Rust runtime is not linked in this build."
        }
        return "Semantic LSP unavailable."
    }

    static func documentURL(filePath: String?, language: String) -> URL {
        if let filePath, !filePath.isEmpty {
            return URL(fileURLWithPath: filePath)
        }

        let fileExtension: String
        switch language.lowercased() {
        case "rust": fileExtension = "rs"
        case "swift": fileExtension = "swift"
        default: fileExtension = "txt"
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos-code-editor")
            .appendingPathExtension(fileExtension)
    }

    static func lspPosition(text: String, oneBasedLine: Int, oneBasedColumn: Int) -> LSPPosition {
        let targetLine = max(0, oneBasedLine - 1)
        let targetColumn = max(0, oneBasedColumn - 1)
        var currentLine = 0
        var lineStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            if currentLine == targetLine {
                let lineEnd = text[index...].firstIndex(where: \.isNewline) ?? text.endIndex
                let lineWidth = text[lineStart..<lineEnd].utf16.count
                return LSPPosition(line: currentLine, character: min(targetColumn, lineWidth))
            }

            if text[index].isNewline {
                currentLine += 1
                text.formIndex(after: &index)
                lineStart = index
            } else {
                text.formIndex(after: &index)
            }
        }

        let lineWidth = text[lineStart..<text.endIndex].utf16.count
        return LSPPosition(line: currentLine, character: min(targetColumn, lineWidth))
    }

    static func hoverSummary(
        text: String,
        language: String,
        filePath: String?,
        cursorLine: Int,
        cursorColumn: Int
    ) async throws -> String? {
        let languageId = language.lowercased()
        guard canRun(language: languageId), !text.isEmpty else { return nil }

        let uri = documentURL(filePath: filePath, language: languageId)
        let position = lspPosition(
            text: text,
            oneBasedLine: cursorLine,
            oneBasedColumn: cursorColumn
        )
        let transport = RustLSPTransport(pollIntervalNanos: pollIntervalNanos)
        await transport.startPolling()

        let client = LSPClient(transport: transport)
        await client.startRouting()

        do {
            _ = try await client.initialize(workspaceRoot: uri.deletingLastPathComponent())
            try await client.didOpen(uri: uri, languageId: languageId, version: 1, text: text)
            let hover = try await client.hover(
                uri: uri,
                line: position.line,
                character: position.character
            )
            try? await client.didClose(uri: uri)
            await transport.shutdown()
            return summarizedHover(hover)
        } catch {
            await transport.shutdown()
            throw error
        }
    }

    static func definitionLocation(
        text: String,
        language: String,
        filePath: String?,
        cursorLine: Int,
        cursorColumn: Int
    ) async throws -> LSPLocation? {
        let languageId = language.lowercased()
        guard canRun(language: languageId), !text.isEmpty else { return nil }

        let uri = documentURL(filePath: filePath, language: languageId)
        let position = lspPosition(
            text: text,
            oneBasedLine: cursorLine,
            oneBasedColumn: cursorColumn
        )
        let transport = RustLSPTransport(pollIntervalNanos: pollIntervalNanos)
        await transport.startPolling()

        let client = LSPClient(transport: transport)
        await client.startRouting()

        do {
            _ = try await client.initialize(workspaceRoot: uri.deletingLastPathComponent())
            try await client.didOpen(uri: uri, languageId: languageId, version: 1, text: text)
            let definitions = try await client.definition(
                uri: uri,
                line: position.line,
                character: position.character
            )
            try? await client.didClose(uri: uri)
            await transport.shutdown()
            return definitions.first
        } catch {
            await transport.shutdown()
            throw error
        }
    }

    static func nsRange(for range: LSPRange, in text: String) -> NSRange? {
        guard let start = utf16Offset(in: text, line: range.start.line, character: range.start.character),
              let end = utf16Offset(in: text, line: range.end.line, character: range.end.character),
              end >= start else {
            return nil
        }
        return NSRange(location: start, length: end - start)
    }

    static func utf16Offset(in text: String, line targetLine: Int, character targetCharacter: Int) -> Int? {
        let source = text as NSString
        let clampedLine = max(0, targetLine)
        let clampedCharacter = max(0, targetCharacter)
        var currentLine = 0
        var lineStart = 0

        while lineStart <= source.length {
            let lineRange = source.lineRange(for: NSRange(location: lineStart, length: 0))
            if currentLine == clampedLine {
                let contentLength = lineContentLength(source: source, lineRange: lineRange)
                return lineRange.location + min(clampedCharacter, contentLength)
            }

            let nextLineStart = lineRange.location + lineRange.length
            guard nextLineStart > lineStart, nextLineStart <= source.length else { break }
            lineStart = nextLineStart
            currentLine += 1
        }

        return nil
    }

    private static func lineContentLength(source: NSString, lineRange: NSRange) -> Int {
        var length = lineRange.length
        while length > 0 {
            let scalar = source.character(at: lineRange.location + length - 1)
            if scalar == 10 || scalar == 13 {
                length -= 1
            } else {
                break
            }
        }
        return length
    }

    static func summarizedHover(_ hover: LSPHoverResult?) -> String? {
        guard let hover else { return nil }
        let lines = hover.contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let joined = lines.joined(separator: " ")
        guard !joined.isEmpty else { return nil }
        if joined.count > 360 {
            return String(joined.prefix(357)) + "..."
        }
        return joined
    }

    static func userFacingError(_ error: any Error) -> String {
        let description = String(describing: error)
        if description.contains("agent_coreFFI not linked") {
            return "Semantic LSP unavailable: in-process Rust runtime is not linked in this build."
        }
        return "Semantic LSP unavailable: \(description)"
    }
}

// MARK: - Language Detection

nonisolated enum CodeLanguage {
    static func isMarkdownDocument(path: String?) -> Bool {
        guard let path, !path.isEmpty else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "mdx"
    }

    static func isMarkdownDocument(filePath: String?, language: String) -> Bool {
        let languageID = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if languageID == "markdown" || languageID == "md" || languageID == "mdx" {
            return true
        }
        return isMarkdownDocument(path: filePath)
    }

    /// Detect language from file extension. Returns nil for markdown/plain text/unknown.
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
        case "md", "markdown", "mdx", "txt": return nil
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

    static func detectEditorLanguage(from path: String) -> String? {
        if isMarkdownDocument(path: path) {
            return "markdown"
        }
        return detect(from: path)
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
        case "markdown", "md": return "Markdown"
        case "gdscript": return "GDScript"
        default: return language.capitalized
        }
    }
}

private enum CodeEditorLivePreviewKind: String {
    case html
    case css
    case javascript
    case json
    case other

    init(language: String) {
        switch language.lowercased() {
        case "html":
            self = .html
        case "css":
            self = .css
        case "javascript", "typescript":
            self = .javascript
        case "json":
            self = .json
        default:
            self = .other
        }
    }
}

// MARK: - CodeEditorView (SwiftUI)

// MARK: - Metal Compute Engine (GPU-Accelerated)

@preconcurrency import Metal
@preconcurrency import MetalPerformanceShaders

/// High-performance GPU compute engine for semantic operations
actor MetalComputeEngine {
    
    static let shared = MetalComputeEngine()
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var cosineSimilarityPipeline: MTLComputePipelineState?
    private var batchNormalizePipeline: MTLComputePipelineState?
    
    // Thread-safe buffer cache
    private var bufferCache: [String: MTLBuffer] = [:]
    private let maxBufferCacheSize = 32
    private var bufferAccessOrder: [String] = []
    
    init() {
        // Setup Metal synchronously on init
        let (device, queue, cosinePipeline, normalizePipeline) = Self.setupMetalCore()
        self.device = device
        self.commandQueue = queue
        self.cosineSimilarityPipeline = cosinePipeline
        self.batchNormalizePipeline = normalizePipeline
    }
    
    /// Non-isolated Metal setup that can be called from init
    private nonisolated static func setupMetalCore() -> (
        MTLDevice?, MTLCommandQueue?, MTLComputePipelineState?, MTLComputePipelineState?
    ) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            os_log(.info, "Metal not available — using CPU fallback")
            return (nil, nil, nil, nil)
        }
        
        let commandQueue = device.makeCommandQueue()

        // Wave 4.1: load compute pipelines from the precompiled
        // default.metallib (compiled offline by Xcode's Metal build phase
        // from Epistemos/Shaders/CodeEditorEmbedding.metal). Eliminates
        // the multi-millisecond runtime compile cost the inline-source
        // path used to pay on every CodeEditorView instantiation.
        let library = device.makeDefaultLibrary()

        var cosineSimilarityPipeline: MTLComputePipelineState?
        var batchNormalizePipeline: MTLComputePipelineState?

        if let cosineFunc = library?.makeFunction(name: "cosineSimilarityBatch") {
            cosineSimilarityPipeline = try? device.makeComputePipelineState(function: cosineFunc)
        }

        if let normalizeFunc = library?.makeFunction(name: "batchNormalize") {
            batchNormalizePipeline = try? device.makeComputePipelineState(function: normalizeFunc)
        }

        return (device, commandQueue, cosineSimilarityPipeline, batchNormalizePipeline)
    }
    
    /// GPU-accelerated batch cosine similarity (~100x faster than CPU for large batches)
    func batchCosineSimilarity(
        query: [Float],
        documents: [[Float]],
        threshold: Float = 0.0
    ) async -> [Float] {
        guard let device = device,
              let pipeline = cosineSimilarityPipeline,
              !documents.isEmpty else {
            return cpuBatchCosineSimilarity(query: query, documents: documents)
        }
        
        let vectorDim = query.count
        let numDocuments = documents.count
        
        // Flatten documents into contiguous array
        var flattenedDocuments: [Float] = []
        flattenedDocuments.reserveCapacity(numDocuments * vectorDim)
        for doc in documents {
            flattenedDocuments.append(contentsOf: doc)
        }
        
        // Create buffers
        guard let queryBuffer = getOrCreateBuffer(
            bytes: query,
            length: vectorDim * MemoryLayout<Float>.stride,
            label: "query"
        ),
        let docsBuffer = getOrCreateBuffer(
            bytes: flattenedDocuments,
            length: numDocuments * vectorDim * MemoryLayout<Float>.stride,
            label: "docs"
        ),
        let outputBuffer = device.makeBuffer(
            length: numDocuments * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else {
            return cpuBatchCosineSimilarity(query: query, documents: documents)
        }
        
        // Encode compute command
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return cpuBatchCosineSimilarity(query: query, documents: documents)
        }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(queryBuffer, offset: 0, index: 0)
        encoder.setBuffer(docsBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        
        var dim = UInt32(vectorDim)
        var count = UInt32(numDocuments)
        encoder.setBytes(&dim, length: MemoryLayout<UInt32>.stride, index: 3)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 4)
        
        // Optimize thread groups for Apple Silicon
        let threadGroupSize = MTLSize(width: min(256, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let gridSize = MTLSize(width: numDocuments, height: 1, depth: 1)
        
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        // Use completion handler for async compatibility
        return await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                // Read results
                let results = Array(UnsafeBufferPointer(
                    start: outputBuffer.contents().assumingMemoryBound(to: Float.self),
                    count: numDocuments
                ))
                continuation.resume(returning: results)
            }
            commandBuffer.commit()
        }
    }
    
    /// Fast top-k selection using GPU + CPU hybrid
    func topKSimilarity(
        query: [Float],
        documents: [[Float]],
        k: Int,
        threshold: Float = 0.55
    ) async -> [(index: Int, score: Float)] {
        let allScores = await batchCosineSimilarity(query: query, documents: documents)
        
        var indexedScores = allScores.enumerated()
            .filter { $0.element >= threshold }
            .map { (index: $0.offset, score: $0.element) }
        
        indexedScores.sort { $0.score > $1.score }
        return Array(indexedScores.prefix(k))
    }
    
    // MARK: - Buffer Management
    
    private func getOrCreateBuffer(bytes: [Float], length: Int, label: String) -> MTLBuffer? {
        let key = "\(label)_\(length)"
        
        if let cached = bufferCache[key], cached.length >= length {
            bufferAccessOrder.removeAll { $0 == key }
            bufferAccessOrder.append(key)
            memcpy(cached.contents(), bytes, length)
            return cached
        }
        
        guard let newBuffer = device?.makeBuffer(bytes: bytes, length: length, options: .storageModeShared) else {
            return nil
        }
        
        bufferCache[key] = newBuffer
        bufferAccessOrder.append(key)
        
        while bufferCache.count > maxBufferCacheSize, let oldest = bufferAccessOrder.first {
            bufferAccessOrder.removeFirst()
            bufferCache.removeValue(forKey: oldest)
        }
        
        return newBuffer
    }
    
    // MARK: - CPU Fallback
    
    private func cpuBatchCosineSimilarity(query: [Float], documents: [[Float]]) -> [Float] {
        documents.map { cosineSimilarityCPU(query, $0) }
    }
    
    private func cosineSimilarityCPU(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, a.count > 0 else { return 0 }
        
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))
        
        guard normA > 0 && normB > 0 else { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }
    
    // MARK: - Metal Shaders
    
    // Wave 4.1: the inline `metalSource` string was lifted into
    // `Epistemos/Shaders/CodeEditorEmbedding.metal`. Xcode's Metal
    // build phase compiles it offline into `default.metallib`; the
    // setupGPU() path above loads from there via makeDefaultLibrary().
}

// MARK: - Concurrent Analysis Queue

/// Thread-safe queue for background AI operations with priority
actor AnalysisQueue {
    static let shared = AnalysisQueue()
    
    private var taskQueue: [AnalysisTask] = []
    private var isProcessing = false
    private let maxConcurrentTasks = 3
    private var activeTasks = 0
    
    struct AnalysisTask: Identifiable {
        let id = UUID()
        let priority: TaskPriority
        let operation: @Sendable () async -> Void
        let timestamp = Date()
    }
    
    enum TaskPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case immediate = 3
        
        static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    func enqueue(priority: TaskPriority = .normal, operation: @escaping @Sendable () async -> Void) {
        let task = AnalysisTask(priority: priority, operation: operation)
        taskQueue.append(task)
        taskQueue.sort { $0.priority > $1.priority }
        processQueue()
    }
    
    func cancelAll() {
        taskQueue.removeAll()
    }
    
    private func processQueue() {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task {
            while !taskQueue.isEmpty && activeTasks < maxConcurrentTasks {
                let task = taskQueue.removeFirst()
                activeTasks += 1
                
                Task {
                    await task.operation()
                    activeTasks -= 1
                    processQueue()
                }
            }
            isProcessing = false
        }
    }
}

// MARK: - Performance Monitor

@Observable
final class ComputePerformanceMonitor {
    static let shared = ComputePerformanceMonitor()
    
    private(set) var gpuUtilization: Double = 0
    private(set) var averageLatencyMs: Double = 0
    private(set) var operationsPerSecond: Double = 0
    
    private var latencyHistory: [Double] = []
    private let maxHistorySize = 100
    private var lastUpdate = Date()
    
    func recordOperation(latencyMs: Double) {
        latencyHistory.append(latencyMs)
        if latencyHistory.count > maxHistorySize {
            latencyHistory.removeFirst()
        }
        
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdate)
        
        if elapsed >= 1.0 {
            averageLatencyMs = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
            operationsPerSecond = Double(latencyHistory.count) / elapsed
            lastUpdate = now
            latencyHistory.removeAll(keepingCapacity: true)
        }
    }
}

// MARK: - AI Code Companion (Metal-Optimized)

/// Proactive coding assistant with GPU-accelerated semantic search
/// and multi-threaded analysis pipeline
@MainActor
@Observable
final class CodeCompanionService {

    private(set) var currentMessage: CompanionMessage?
    private(set) var isAnalyzing = false
    var isEnabled = true
    var mode: CompanionMode = .balanced
    
    // Graph state for semantic search (injected from view)
    private weak var graphState: GraphState?
    
    enum CompanionMode: String, CaseIterable, Sendable {
        case passive = "Passive"
        case balanced = "Balanced"
        case proactive = "Proactive"
        
        var interval: TimeInterval {
            switch self {
            case .passive: return 0
            case .balanced: return 30
            case .proactive: return 10
            }
        }
    }
    
    // Services
    private let appleIntelligence = AppleIntelligenceService.shared
    private let metalEngine = MetalComputeEngine.shared
    private let analysisQueue = AnalysisQueue.shared
    
    // State (thread-safe via MainActor)
    private var currentCode: String = ""
    private var currentLanguage: String = ""
    private var lastAnalysisHash: Int = 0
    private var lastMessageTime: Date = .distantPast
    private let minimumMessageInterval: TimeInterval = 15
    
    // Concurrent processing
    private var analysisTask: Task<Void, Never>?
    private var periodicTimer: Timer?
    private let feedbackGenerator = NSHapticFeedbackManager.defaultPerformer
    
    // Performance tuning (actor-based synchronization)
    private var isProcessing = false
    
    func configure(graphState: GraphState?) {
        self.graphState = graphState
    }
    
    func startSession(code: String, language: String) {
        guard isEnabled else { return }
        currentCode = code
        currentLanguage = language
        
        // Initial analysis on background queue
        Task.detached(priority: .utility) { [weak self] in
            await self?.performAnalysisAsync()
        }
        
        schedulePeriodicAnalysis()
    }
    
    func updateCode(_ code: String) {
        currentCode = code
        
        if mode == .proactive {
            // Debounced analysis on background queue
            analysisTask?.cancel()
            analysisTask = Task.detached(priority: .utility) { [weak self] in
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.performAnalysisAsync()
            }
        }
    }
    
    func endSession() {
        periodicTimer?.invalidate()
        periodicTimer = nil
        analysisTask?.cancel()
        
        Task {
            await analysisQueue.cancelAll()
        }
        
        currentMessage = nil
    }
    
    private func schedulePeriodicAnalysis() {
        periodicTimer?.invalidate()
        guard mode != .passive else { return }
        
        periodicTimer = Timer.scheduledTimer(withTimeInterval: mode.interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.performAnalysisAsync()
            }
        }
    }
    
    /// Main analysis pipeline with GPU acceleration
    private func performAnalysisAsync() async {
        // Actor-based synchronization - prevents concurrent analyses
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        // Check preconditions
        let codeHash = currentCode.hashValue
        guard codeHash != lastAnalysisHash else { return }
        
        let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTime)
        guard timeSinceLastMessage >= minimumMessageInterval else { return }
        
        await MainActor.run { isAnalyzing = true }
        defer { Task { @MainActor in isAnalyzing = false } }
        
        // Parallel analysis pipeline
        async let complexityTask = analyzeComplexityAsync(currentCode)
        async let semanticTask = performSemanticAnalysisAsync()
        
        let (complexity, semanticContext) = await (complexityTask, semanticTask)
        
        // Route to appropriate AI
        let message = await generateInsight(
            complexity: complexity,
            semanticContext: semanticContext
        )
        
        guard let msg = message else { return }
        
        lastAnalysisHash = codeHash
        lastMessageTime = Date()
        
        await MainActor.run {
            self.currentMessage = msg
            self.presentMessage()
        }
    }
    
    /// GPU-accelerated semantic analysis with parallel result building
    private func performSemanticAnalysisAsync() async -> SemanticContext {
        // Get embedding for current code
        let embeddingService = graphState?.embeddingService ?? EmbeddingService()
        guard let codeEmbedding = embeddingService.queryEmbedding(for: currentCode) else {
            return SemanticContext.empty
        }
        
        // Fetch candidate documents from graph
        guard let graphState = self.graphState else {
            return SemanticContext.empty
        }
        
        let candidates = graphState.semanticSearch(query: "semantic:", limit: 100)
        guard !candidates.isEmpty else { return SemanticContext.empty }
        
        // Collect embeddings (embeddingService is MainActor-isolated)
        var documentEmbeddings: [[Float]] = []
        var documentIds: [String] = []
        var labels: [String] = []
        var snippets: [String] = []
        documentEmbeddings.reserveCapacity(candidates.count)
        documentIds.reserveCapacity(candidates.count)
        labels.reserveCapacity(candidates.count)
        snippets.reserveCapacity(candidates.count)
        
        for candidate in candidates {
            if let embedding = embeddingService.embedding(for: candidate.id) {
                documentEmbeddings.append(embedding)
                documentIds.append(candidate.id)
                labels.append(candidate.node.label)
                snippets.append(candidate.node.metadata.quoteText ?? candidate.node.metadata.abstract ?? "")
            }
        }
        
        guard !documentEmbeddings.isEmpty else { return SemanticContext.empty }
        
        // GPU-accelerated top-k similarity (includes batch compute + threshold filter)
        let startTime = CFAbsoluteTimeGetCurrent()
        let topKResults = await metalEngine.topKSimilarity(
            query: codeEmbedding,
            documents: documentEmbeddings,
            k: 10,
            threshold: 0.55
        )
        
        // Record performance
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        ComputePerformanceMonitor.shared.recordOperation(latencyMs: latency)
        
        // Build results (topK is small, sequential is fine)
        var matches: [SemanticMatch] = []
        matches.reserveCapacity(topKResults.count)
        for result in topKResults {
            matches.append(SemanticMatch(
                id: documentIds[result.index],
                title: labels[result.index],
                snippet: snippets[result.index],
                score: result.score
            ))
        }
        
        matches.sort { $0.score > $1.score }
        
        return SemanticContext(
            topMatches: Array(matches.prefix(5)),
            averageScore: matches.prefix(5).map { $0.score }.reduce(0, +) / Float(min(matches.count, 5))
        )
    }
    
    /// Async complexity analysis
    private func analyzeComplexityAsync(_ code: String) async -> Double {
        // Run on background queue
        await Task.detached(priority: .utility) {
            let factors: [Double] = [
                Double(code.count) / 1000.0,
                Double(code.components(separatedBy: "func ").count - 1) * 0.2,
                Double(code.components(separatedBy: "class ").count - 1) * 0.3,
                Double(code.components(separatedBy: "if ").count - 1) * 0.1,
                code.contains("async") || code.contains("await") ? 0.3 : 0,
                code.contains("Task") || code.contains("Actor") ? 0.2 : 0,
            ]
            return min(factors.reduce(0, +), 1.0)
        }.value
    }
    
    /// Generate insight with context
    private func generateInsight(
        complexity: Double,
        semanticContext: SemanticContext
    ) async -> CompanionMessage? {
        
        let vaultContext = semanticContext.topMatches.prefix(2)
            .map { "- \($0.title)" }
            .joined(separator: "\n")
        
        let prompt = """
        Quick insight about this \(currentLanguage) code (1 sentence max):
        
        ```\(currentLanguage)
        \(currentCode.prefix(500))
        ```
        
        \(semanticContext.averageScore > 0.7 ? "Strong semantic match with vault." : "")
        \(vaultContext.isEmpty ? "" : "Related notes:\n\(vaultContext)")
        
        Provide a brief observation, pattern, or suggestion.
        """
        
        do {
            let response = try await appleIntelligence.generate(
                prompt: prompt,
                systemPrompt: "You are a helpful coding assistant. Be concise and actionable."
            )
            
            return CompanionMessage(
                source: .hybrid,
                type: semanticContext.averageScore > 0.7 ? .connection : .insight,
                content: response.trimmingCharacters(in: .whitespacesAndNewlines),
                timestamp: Date(),
                actions: generateActions(for: semanticContext),
                context: CompanionMessage.MessageContext(
                    codeSnippet: String(currentCode.prefix(200)),
                    language: currentLanguage
                )
            )
        } catch {
            return nil
        }
    }
    
    private func generateActions(for context: SemanticContext) -> [CompanionMessage.MessageAction] {
        var actions: [CompanionMessage.MessageAction] = [
            .init(id: "explain", title: "Explain More", icon: "text.bubble", type: .explainMore),
            .init(id: "dismiss", title: "Dismiss", icon: "xmark", type: .dismiss)
        ]
        
        if let topMatch = context.topMatches.first {
            actions.insert(.init(
                id: "open-note",
                title: "Open Note",
                icon: "doc.text",
                type: .openNote(topMatch.id)
            ), at: 0)
        }
        
        return actions
    }
    
    private func presentMessage() {
        feedbackGenerator.perform(.levelChange, performanceTime: .default)
    }
    
    func dismissCurrentMessage() {
        currentMessage = nil
    }
}

// MARK: - Semantic Context

struct SemanticContext: Sendable {
    let topMatches: [SemanticMatch]
    let averageScore: Float
    
    static let empty = SemanticContext(topMatches: [], averageScore: 0)
}

struct SemanticMatch: Sendable {
    let id: String
    let title: String
    let snippet: String
    let score: Float
}

/// Message from the AI companion
struct CompanionMessage: Identifiable {
    let id = UUID()
    let source: Source
    let type: MessageType
    let content: String
    let timestamp: Date
    let actions: [MessageAction]
    let context: MessageContext
    
    struct MessageContext: Sendable {
        let codeSnippet: String
        let language: String
    }
    
    enum Source: String, Sendable {
        case appleIntelligence = "Apple Intelligence"
        case qwenLocal = "Provider Assist"
        case hybrid = "AI Fusion"
        
        var icon: String {
            switch self {
            case .appleIntelligence: return "apple.logo"
            case .qwenLocal: return "cpu"
            case .hybrid: return "sparkles"
            }
        }
        
        var color: Color {
            switch self {
            case .appleIntelligence: return .gray
            case .qwenLocal: return .blue
            case .hybrid: return .purple
            }
        }
    }
    
    enum MessageType: Sendable {
        case insight
        case suggestion
        case question
        case connection
        case completion
        case summary
        
        var description: String {
            switch self {
            case .insight: return "Insight"
            case .suggestion: return "Suggestion"
            case .question: return "Question"
            case .connection: return "Connection"
            case .completion: return "Completion"
            case .summary: return "Summary"
            }
        }
    }
    
    struct MessageAction: Sendable {
        let id: String
        let title: String
        let icon: String
        let type: ActionType
        
        enum ActionType: Sendable {
            case openNote(String)
            case applyEdit(String)
            case explainMore
            case dismiss
            case generateTests
            case createNote
        }
    }
}

/// Toast notification view for companion messages
struct CodeCompanionToast: View {
    let message: CompanionMessage
    let onAction: (CompanionMessage.MessageAction) -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    @ScaledMetric(relativeTo: .body) private var toastWidth: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: message.source.icon)
                    .foregroundStyle(message.source.color)
                    .font(.body)

                Text(message.source.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(message.type.description)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(message.source.color.opacity(0.15))
                    .foregroundStyle(message.source.color)
                    .cornerRadius(4)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(message.content)
                .font(.body)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(message.actions.prefix(2), id: \.id) { action in
                    Button {
                        onAction(action)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.caption)
                            Text(action.title)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(width: toastWidth)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.source.color.opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - CodeEditorView

struct CodeEditorView: View {
    let initialContent: String
    let language: String
    let filePath: String?  // Optional: for code-to-graph linking
    let onContentChange: ((String) -> Void)?
    /// SS-GC (owner 2026-06-20): when the code editor is mounted inside the embedded
    /// home-graph surface, its top bar must paint the GRAPH backdrop so it isn't a white
    /// card slab against the darker landing surround. nil = the standalone / notes /
    /// detached-window appearance (the card top bar), unchanged. Mirrors the prose
    /// branch's `themeOverride` (NoteDetailWorkspaceView).
    let themeOverride: EpistemosTheme?

    @Environment(UIState.self) private var ui
    @Environment(GraphState.self) private var graphState: GraphState?
    @Environment(TriageService.self) private var triageService: TriageService?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .body) private var toolbarMenuWidth: CGFloat = 20

    @State private var text: String
    @State private var cursorLine: Int = 1
    @State private var cursorCol: Int = 1
    @State private var totalLines: Int
    @State private var outlineRefreshTask: Task<Void, Never>?
    @State private var semanticRefreshTask: Task<Void, Never>?
    @State private var semanticLookupTask: Task<Void, Never>?
    @State private var contentDebouncer: CodeEditorContentDebouncer?
    @State private var coreEditorSelectionRequest: CoreEditorSelectionRequest?
    @State private var webKitSelectionRequest: WebKitCodeEditorSelectionRequest?
    
    // MARK: - Editor Preferences (persisted via AppStorage)
    
    @AppStorage("codeEditor.wrapLines") private var wrapLines = false
    // Minimap removed — outline navigator replaces it
    @AppStorage("codeEditor.showInvisibles") private var showInvisibles = false
    // Keep the code surface at the native-editor scale by default. The
    // CoreEditor owns rendering now, but code notes should still feel like
    // a Mac code editor rather than a compact web preview panel.
    @AppStorage("codeEditor.fontSize") private var fontSize: Double = 15
    @AppStorage("codeEditor.useSpaces") private var useSpaces = true
    @AppStorage("codeEditor.tabWidth") private var tabWidth = 4
    @AppStorage("codeEditor.useLegacyV1Editor") private var useLegacyV1Editor = false
    @AppStorage("epistemos.codeEditor.showLineGutter") private var showLineGutter = true

    private var isMarkdownDocument: Bool {
        CodeLanguage.isMarkdownDocument(filePath: filePath, language: language)
    }

    private var usesLegacyV1Editor: Bool {
        useLegacyV1Editor && !isMarkdownDocument
    }
    
    // MARK: - UI State

    @State private var showSemanticSidebar = false
    @State private var showSearchBar = false
    @State private var showGoToLineSheet = false
    @State private var searchQuery = ""
    @State private var searchCaseSensitive = false
    @State private var activeSearchRange: NSRange?
    @State private var goToLineNumber = ""
    @State private var codeContextBridge: CodeContextBridge?
    @State private var semanticStatusMessage: String?
    @State private var semanticStatusIsError = false
    @State private var semanticStatusIsLoading = false
    @State private var showLivePreview = false
    @State private var livePreviewText = ""
    @State private var livePreviewTask: Task<Void, Never>?
    
    // MARK: - Outline Navigation (Xcode-style)
    @State private var outlineItems: [OutlineItem] = []
    /// T+8 Phase-S item 3 — hash-keyed memoization around
    /// `OutlineParser.parse`. Skips re-walking the document when the
    /// (content, language) pair hasn't changed since the last refresh
    /// (common when an outline refresh is triggered by cursor / focus
    /// events, not actual edits). See
    /// `Epistemos/Engine/OutlineParserCache.swift`.
    @State private var outlineCache = OutlineParserCache()
    @State private var showOutlineNavigator = false

    init(
        content: String,
        language: String,
        filePath: String? = nil,
        onContentChange: ((String) -> Void)? = nil,
        themeOverride: EpistemosTheme? = nil
    ) {
        self.initialContent = content
        self.language = language
        self.filePath = filePath
        self.onContentChange = onContentChange
        self.themeOverride = themeOverride
        _text = State(initialValue: content)
        _totalLines = State(initialValue: CodeEditorLineMetrics.lineCount(content))
    }

    /// SS-GC: the code-editor top-bar fill. With a `themeOverride` (embedded home graph) it paints
    /// the SAME fill as the graph PAGE surround the editor sits inside —
    /// `GraphWorkspaceContainer.embeddedPageSurface`, i.e. `theme.resolved.background.color` with the
    /// theme already `surfaceVariant(.landing)` — so the bar truly blends. (It previously used
    /// `AppWindowBackdropStyle.background`, which re-applies `surfaceVariant(.mainChat)` on top and
    /// yields a LIGHTER mainChat background that popped as a white bar over the darker landing page —
    /// the reopened SS-GC white-bar.) Without an override (standalone / notes / detached window) it
    /// keeps the existing card slab — byte-for-byte unchanged. Pure + testable.
    static func resolvedTopBarBackground(
        themeOverride: EpistemosTheme?,
        base: EpistemosTheme
    ) -> Color {
        if let themeOverride {
            return themeOverride.resolved.background.color
        }
        return MarkdownPreviewSurfaceStyle.flatBackground(for: base.surfaceVariant(.other))
    }

    var body: some View {
        editorContent
            .onAppear {
                _ = ensureContentDebouncer()
                showSemanticSidebar = false
                livePreviewText = text
            }
            .onDisappear {
                outlineRefreshTask?.cancel()
                semanticRefreshTask?.cancel()
                semanticLookupTask?.cancel()
                livePreviewTask?.cancel()
                livePreviewTask = nil
                contentDebouncer?.flush(text)
                contentDebouncer?.detach()
                contentDebouncer = nil
                codeContextBridge?.cancelPendingWork()
            }
            .onChange(of: text) { _, newText in
                activeSearchRange = nil
                semanticLookupTask?.cancel()
                semanticStatusMessage = nil
                semanticStatusIsLoading = false
                ensureContentDebouncer().enqueue(newText)
                if showOutlineNavigator {
                    scheduleOutlineRefresh(for: newText)
                }
                if showLivePreview {
                    scheduleLivePreviewUpdate(for: newText)
                }
            }
            .onChange(of: initialContent) { oldValue, newValue in
                guard newValue != text else { return }
                guard text == oldValue || text.isEmpty else { return }
                text = newValue
                totalLines = CodeEditorLineMetrics.lineCount(newValue)
                if showOutlineNavigator {
                    scheduleOutlineRefresh(for: newValue, immediate: true)
                }
            }
            .onChange(of: cursorLine) { _, newLine in
                updateBreadcrumbs()
            }
            .onChange(of: showLivePreview) { _, enabled in
                if enabled {
                    livePreviewText = text
                } else {
                    livePreviewTask?.cancel()
                    livePreviewTask = nil
                }
            }
            .onChange(of: searchQuery) { _, _ in
                activeSearchRange = nil
            }
            .onChange(of: searchCaseSensitive) { _, _ in
                activeSearchRange = nil
            }
            .onChange(of: showOutlineNavigator) { _, isVisible in
                if isVisible {
                    scheduleOutlineRefresh(for: text, immediate: true)
                } else {
                    outlineRefreshTask?.cancel()
                    outlineItems = []
                }
            }
    }

    @discardableResult
    private func ensureContentDebouncer() -> CodeEditorContentDebouncer {
        if let contentDebouncer {
            return contentDebouncer
        }
        let debouncer = CodeEditorContentDebouncer { newText in
            onContentChange?(newText)
            updateSemanticContext(newText)
        }
        contentDebouncer = debouncer
        return debouncer
    }
    
    // MARK: - Outline Management
    
    private func scheduleOutlineRefresh(for content: String, immediate: Bool = false) {
        outlineRefreshTask?.cancel()
        let refreshDelay = CodeEditorPerformancePolicy.outlineRefreshDelay(characterCount: content.count)
        let currentLanguage = language

        outlineRefreshTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(for: refreshDelay)
            }
            guard !Task.isCancelled else { return }
            // T+8 Phase-S item 3 — outline cache + diff. The hash-keyed
            // memo short-circuits when (content, language) hasn't
            // changed since last refresh; on miss the parser runs and
            // the result is memoized for the next refresh. Files
            // above OutlineParserCache.maxParseBytes return an empty
            // outline (the parser is MainActor-bound and would hang
            // the UI on multi-hundred-KB blobs like graph.json).
            outlineItems = outlineCache.parse(content: content, language: currentLanguage)
        }
    }
    
    private func updateBreadcrumbs() {
        // Breadcrumbs are computed on-the-fly based on cursor position
        // No state update needed - computed property
    }
    
    @ViewBuilder
    private var editorContent: some View {
        if isMarkdownDocument {
            MarkEditMarkdownEditorRepresentable(
                text: $text,
                cursorLine: $cursorLine,
                cursorColumn: $cursorCol,
                totalLines: $totalLines,
                theme: ui.theme,
                fontSize: fontSize,
                wrapLines: wrapLines,
                showLineNumbers: showLineGutter,
                showInvisibles: showInvisibles,
                useSpaces: useSpaces,
                tabWidth: tabWidth,
                selectionRequest: coreEditorSelectionRequest
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme))
        } else {
            codeEditorChromeContent
        }
    }

    private var codeEditorChromeContent: some View {
        VStack(spacing: 8) {
            codeEditorTopBar
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)

            HStack(spacing: 0) {
                editorWithSearch
                outlineNavigator
                if CodeEditorReleasePolicy.semanticSidebarEnabled {
                    semanticSidebar
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var codeEditorTopBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(ui.theme.resolved.accent.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(codeEditorDisplayName)
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ui.theme.resolved.foreground.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(CodeLanguage.displayName(for: language)) · \(totalLines) lines")
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(ui.theme.resolved.mutedForeground.color.opacity(0.85))
            }

            Spacer(minLength: 12)

            Text("Ln \(cursorLine), Col \(cursorCol)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(ui.theme.resolved.mutedForeground.color.opacity(0.92))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    ui.theme.resolved.foreground.color.opacity(ui.theme.isDark ? 0.07 : 0.045),
                    in: Capsule()
                )

            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                    showLivePreview.toggle()
                }
            } label: {
                Image(systemName: showLivePreview ? "play.rectangle.fill" : "play.rectangle")
                    .foregroundStyle(showLivePreview ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isLivePreviewCapable)
            .help(livePreviewHelpText)

            Button {
                showSearchBar.toggle()
            } label: {
                Image(systemName: showSearchBar ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .foregroundStyle(showSearchBar ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Find")

            Button {
                showGoToLineSheet = true
            } label: {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Go to line")

            viewOptionsMenu
            editorSettingsMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // SS-GC: in the embedded home graph this paints the graph backdrop (no white
        // card slab); standalone / notes / detached keeps the card. See resolvedTopBarBackground.
        .background(Self.resolvedTopBarBackground(themeOverride: themeOverride, base: ui.theme))
        .sheet(isPresented: $showGoToLineSheet) {
            GoToLineSheet(
                lineNumber: $goToLineNumber,
                totalLines: totalLines,
                onGoToLine: { line in
                    goToLine(line: line)
                    goToLineNumber = ""
                    showGoToLineSheet = false
                }
            )
        }
    }

    private var codeEditorDisplayName: String {
        guard let filePath,
              !filePath.isEmpty else {
            return "Untitled Code"
        }
        return URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    private func goToLine(line: Int) {
        cursorLine = line
        navigateToLine(line)
    }
    
    // MARK: - Breadcrumb Bar
    
    private var breadcrumbBar: some View {
        let breadcrumbs = BreadcrumbBuilder.buildBreadcrumbs(
            filePath: filePath,
            outlineItems: outlineItems,
            currentLine: cursorLine
        )

        return EditorBreadcrumbBar(
            items: breadcrumbs,
            currentLine: cursorLine,
            onSelect: { item in
                navigateToLine(item.lineNumber)
            }
        )
        .overlay(alignment: .trailing) {
            HStack(spacing: 6) {
                Button {
                    showSearchBar.toggle()
                } label: {
                    Image(systemName: showSearchBar ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .foregroundStyle(showSearchBar ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Find (Cmd-F)")

                Button {
                    requestSemanticHover()
                } label: {
                    Image(systemName: semanticStatusIsLoading ? "info.circle.fill" : "info.circle")
                        .foregroundStyle(semanticStatusIsLoading ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!CodeEditorSemanticLSP.canRun(language: language) || semanticStatusIsLoading)
                .help(semanticLSPHelpText)

                Button {
                    requestSemanticDefinition()
                } label: {
                    Image(systemName: "arrow.down.right.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!CodeEditorSemanticLSP.canRun(language: language) || semanticStatusIsLoading)
                .help(definitionLSPHelpText)

                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                        showOutlineNavigator.toggle()
                    }
                } label: {
                    Image(systemName: showOutlineNavigator ? "sidebar.trailing" : "sidebar.right")
                        .foregroundStyle(showOutlineNavigator ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Outline")

                viewOptionsMenu
                editorSettingsMenu
            }
            .padding(.trailing, 12)
        }
        .sheet(isPresented: $showGoToLineSheet) {
            GoToLineSheet(
                lineNumber: $goToLineNumber,
                totalLines: totalLines,
                onGoToLine: { line in
                    goToLine(line: line)
                    goToLineNumber = ""
                    showGoToLineSheet = false
                }
            )
        }
    }
    
    // MARK: - Outline Navigator
    
    @ViewBuilder
    private var outlineNavigator: some View {
        if showOutlineNavigator {
            OutlineNavigatorView(
                items: outlineItems,
                currentLine: cursorLine,
                onSelect: { item in
                    navigateToLine(item.lineNumber)
                }
            )
            .transition(AnyTransition.move(edge: .trailing))
        }
    }
    
    private func navigateToLine(_ line: Int) {
        let starts = CodeEditorLineMetrics.lineStartUTF16Offsets(in: text)
        let index = min(max(line - 1, 0), max(starts.count - 1, 0))
        let location = starts.isEmpty ? 0 : starts[index]
        requestEditorSelection(NSRange(location: location, length: 0))
    }

    private func requestEditorSelection(_ range: NSRange) {
        coreEditorSelectionRequest = CoreEditorSelectionRequest(range: range)
        webKitSelectionRequest = WebKitCodeEditorSelectionRequest(range: range)
    }
    
    private var editorWithSearch: some View {
        ZStack(alignment: .top) {
            HStack(spacing: showLivePreview ? 10 : 0) {
                codeEditorSurface
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showLivePreview, isLivePreviewCapable {
                    codeLivePreview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            searchBarOverlay
        }
        .overlay(alignment: .bottomLeading) {
            semanticLSPStatusOverlay
        }
        .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme))
    }

    @ViewBuilder
    private var codeEditorSurface: some View {
        if usesLegacyV1Editor {
            WebKitCodeEditorView(
                text: $text,
                cursorLine: $cursorLine,
                cursorColumn: $cursorCol,
                totalLines: $totalLines,
                language: language,
                theme: ui.theme,
                fontSize: fontSize,
                wrapLines: wrapLines,
                showLineNumbers: showLineGutter,
                selectionRequest: webKitSelectionRequest
            )
        } else {
            MarkEditCodeEditorRepresentable(
                text: $text,
                cursorLine: $cursorLine,
                cursorColumn: $cursorCol,
                totalLines: $totalLines,
                language: language,
                theme: ui.theme,
                fontSize: fontSize,
                wrapLines: wrapLines,
                showLineNumbers: showLineGutter,
                showInvisibles: showInvisibles,
                useSpaces: useSpaces,
                tabWidth: tabWidth,
                selectionRequest: coreEditorSelectionRequest
            )
        }
    }

    private var codeLivePreview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(ui.theme.resolved.accent.color)
                Text("Live Preview")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(CodeLanguage.displayName(for: language))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("sandboxed")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // SS-GC (owner 2026-06-20, reopened): the Live Preview header is code-editor chrome
            // that sits at the very top of a preview-capable file — it must respect themeOverride
            // exactly like codeEditorTopBar (:2193), or it paints a white card slab over the dark
            // embedded-graph backdrop (the "white bar at the top"). nil override (detached/notes)
            // keeps the card, unchanged.
            .background(Self.resolvedTopBarBackground(themeOverride: themeOverride, base: ui.theme))

            Divider()

            HTMLWorkspacePreviewView(
                package: livePreviewPackage,
                previewTheme: ui.theme.isDark ? .dark : .light,
                themeGuardCSSOverride: livePreviewThemeGuardCSS,
                themeIdentity: livePreviewThemeIdentity
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    private var isLivePreviewCapable: Bool {
        switch livePreviewLanguageKind {
        case .html, .css, .javascript, .json:
            return true
        case .other:
            return false
        }
    }

    private var livePreviewHelpText: String {
        isLivePreviewCapable
            ? "Toggle live preview"
            : "Live preview is available for HTML, CSS, JavaScript, and JSON code notes."
    }

    private var livePreviewThemeIdentity: String {
        [
            ui.theme.isDark ? "dark" : "light",
            ui.theme.resolved.accent.nsColor.codePreviewCSSColor,
        ].joined(separator: "|")
    }

    private var livePreviewPackage: HTMLWorkspacePackage {
        var package = HTMLWorkspacePackage.defaultPackage(title: "\(codeEditorDisplayName) Preview")
        let text = livePreviewText
        switch livePreviewLanguageKind {
        case .html:
            package.indexHTML = text.isEmpty ? livePreviewEmptyHTML : text
            package.styleCSS = livePreviewBaseCSS
            package.scriptJS = ""
            package.dataJSON = "{}"
        case .css:
            package.indexHTML = livePreviewCSSHostHTML
            package.styleCSS = livePreviewBaseCSS + "\n\n" + text
            package.scriptJS = ""
            package.dataJSON = "{}"
        case .javascript:
            package.indexHTML = livePreviewJavaScriptHostHTML
            package.styleCSS = livePreviewBaseCSS
            package.scriptJS = livePreviewConsoleShim + "\n\n" + text.escapingClosingScriptTag()
            package.dataJSON = "{}"
        case .json:
            package.indexHTML = livePreviewJSONHostHTML
            package.styleCSS = livePreviewBaseCSS
            package.scriptJS = livePreviewJSONScript(json: text)
            package.dataJSON = text
        case .other:
            package.indexHTML = livePreviewUnsupportedHTML
            package.styleCSS = livePreviewBaseCSS
            package.scriptJS = ""
            package.dataJSON = "{}"
        }
        return package
    }

    private var livePreviewLanguageKind: CodeEditorLivePreviewKind {
        CodeEditorLivePreviewKind(language: language)
    }

    private var livePreviewThemeGuardCSS: String {
        let surfaceTheme = ui.theme.surfaceVariant(.other)
        let background = MarkdownPreviewSurfaceStyle
            .canvasNSColor(for: surfaceTheme)
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
            .codePreviewCSSColor
        let foregroundSource = surfaceTheme.isDark
            ? NSColor(deviceWhite: 0.94, alpha: 1.0)
            : surfaceTheme.resolved.foreground.nsColor
        let mutedSource = surfaceTheme.isDark
            ? NSColor(deviceWhite: 0.80, alpha: 1.0)
            : surfaceTheme.resolved.mutedForeground.nsColor
        let foreground = foregroundSource
            .rgbSafeForCodeEditorTheme()
            .codePreviewCSSColor
        let muted = mutedSource
            .rgbSafeForCodeEditorTheme()
            .codePreviewCSSColor
        let card = surfaceTheme.resolved.card.nsColor
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
            .codePreviewCSSColor
        let border = surfaceTheme.resolved.glassBorder.nsColor
            .rgbSafeForCodeEditorTheme()
            .codePreviewCSSColor(opacity: surfaceTheme.isDark ? 0.48 : 0.32)
        let accent = surfaceTheme.resolved.accent.nsColor
            .rgbSafeForCodeEditorTheme()
            .codePreviewCSSColor
        let scheme = surfaceTheme.isDark ? "dark" : "light"

        return """
        :root {
          color-scheme: \(scheme);
          --epistemos-workspace-bg: \(background);
          --epistemos-workspace-fg: \(foreground);
          --epistemos-workspace-muted: \(muted);
          --epistemos-workspace-card: \(card);
          --epistemos-workspace-border: \(border);
          --epistemos-workspace-accent: \(accent);
          --epistemos-workspace-title-font: "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-heading-font: "ChonkyPixels", "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-body-font: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
        }

        html[data-epistemos-theme],
        html[data-epistemos-theme] body,
        html[data-epistemos-theme] main.workspace {
          background: var(--epistemos-workspace-bg) !important;
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme="dark"] body,
        html[data-epistemos-theme="dark"] body :where(*):not(svg):not(path),
        html[data-epistemos-theme="dark"] body :is(p, li, span, div, small, strong, em, label, td, th, blockquote, pre, code, dd, dt, figcaption, summary, legend) {
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme="dark"] body :is(.muted, .secondary, .subtle, .caption, .eyebrow, .meta, [data-muted]) {
          color: var(--epistemos-workspace-muted) !important;
        }

        html[data-epistemos-theme="light"] body :is(p, li, span, small, strong, em, label, td, th, blockquote, pre, code, dd, dt, figcaption, summary, legend) {
          color: inherit;
        }

        html[data-epistemos-theme] body :is(h1, h2, h3, h4, h5, h6) {
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme] body a {
          color: var(--epistemos-workspace-accent) !important;
        }

        html[data-epistemos-theme] body :is(hr, table, th, td, fieldset, input, textarea, select, button) {
          border-color: var(--epistemos-workspace-border) !important;
        }

        html[data-epistemos-theme] body :is(input, textarea, select, button) {
          background: var(--epistemos-workspace-card) !important;
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme] :is(.metric-card, [data-metrics] article, .card, section[data-card], .preview-card) {
          background: var(--epistemos-workspace-card);
          border-color: var(--epistemos-workspace-border);
        }
        """
    }

    private var livePreviewBaseCSS: String {
        """
        body {
          min-height: 100vh;
          margin: 0;
          background: var(--epistemos-workspace-bg);
          color: var(--epistemos-workspace-fg);
          font: 15px/1.55 var(--epistemos-workspace-body-font);
        }

        .workspace {
          width: min(780px, calc(100vw - 48px));
          margin: 0 auto;
          padding: 42px 24px;
        }

        .preview-card {
          border: 1px solid var(--epistemos-workspace-border);
          border-radius: 14px;
          padding: 18px;
          box-shadow: 0 18px 50px rgba(0, 0, 0, 0.10);
        }

        h1, h2 {
          font-family: var(--epistemos-workspace-heading-font);
          line-height: 1.05;
        }

        pre, code, textarea {
          font-family: ui-monospace, "SF Mono", "SFMono-Regular", Menlo, Monaco, Consolas, monospace;
        }
        """
    }

    private var livePreviewEmptyHTML: String {
        """
        <main class="workspace">
          <section class="preview-card">
            <h1>Empty HTML</h1>
            <p>Type HTML in the editor to render it here.</p>
          </section>
        </main>
        """
    }

    private var livePreviewCSSHostHTML: String {
        """
        <main class="workspace">
          <section class="preview-card">
            <h1>CSS Preview</h1>
            <p>This host document lets the current stylesheet render against real text, cards, buttons, and lists.</p>
            <button type="button">Button</button>
            <ul>
              <li>Layout sample</li>
              <li>Color sample</li>
              <li>Typography sample</li>
            </ul>
          </section>
        </main>
        """
    }

    private var livePreviewJavaScriptHostHTML: String {
        """
        <main class="workspace">
          <section class="preview-card">
            <h1>JavaScript Preview</h1>
            <p>Console output and DOM changes appear below.</p>
            <div id="app"></div>
            <pre id="epistemos-run-log"></pre>
          </section>
        </main>
        """
    }

    private var livePreviewJSONHostHTML: String {
        """
        <main class="workspace">
          <section class="preview-card">
            <h1>JSON Preview</h1>
            <pre id="epistemos-json-output"></pre>
          </section>
        </main>
        """
    }

    private var livePreviewUnsupportedHTML: String {
        """
        <main class="workspace">
          <section class="preview-card">
            <h1>No Preview</h1>
            <p>This language does not have a runnable preview yet.</p>
          </section>
        </main>
        """
    }

    private var livePreviewConsoleShim: String {
        """
        (() => {
          const logNode = document.getElementById('epistemos-run-log');
          const write = (level, values) => {
            if (!logNode) return;
            const line = values.map(value => {
              try { return typeof value === 'string' ? value : JSON.stringify(value, null, 2); }
              catch { return String(value); }
            }).join(' ');
            logNode.textContent += `[${level}] ${line}\\n`;
          };
          ['log', 'info', 'warn', 'error'].forEach(level => {
            const original = console[level].bind(console);
            console[level] = (...values) => {
              original(...values);
              write(level, values);
            };
          });
        })();
        """
    }

    private func livePreviewJSONScript(json: String) -> String {
        """
        (() => {
          const target = document.getElementById('epistemos-json-output');
          try {
            const parsed = JSON.parse(document.getElementById('workspace-data')?.textContent || '{}');
            target.textContent = JSON.stringify(parsed, null, 2);
          } catch (error) {
            target.textContent = "Invalid JSON\\n\\n" + \(json.debugDescription);
          }
        })();
        """
    }

    private func scheduleLivePreviewUpdate(for content: String) {
        livePreviewTask?.cancel()
        livePreviewTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            livePreviewText = content
        }
    }
    
    @ViewBuilder
    private var searchBarOverlay: some View {
        if showSearchBar {
            SearchBar(
                query: $searchQuery,
                caseSensitive: $searchCaseSensitive,
                onClose: { showSearchBar = false },
                onFindNext: { findNext() },
                onFindPrevious: { findPrevious() }
            )
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var semanticLSPHelpText: String {
        if CodeEditorSemanticLSP.canRun(language: language) {
            return "Inspect Symbol"
        }
        return CodeEditorSemanticLSP.unavailableMessage(language: language)
    }

    private var definitionLSPHelpText: String {
        if CodeEditorSemanticLSP.canRun(language: language) {
            return "Go to Definition"
        }
        return CodeEditorSemanticLSP.unavailableMessage(language: language)
    }

    @ViewBuilder
    private var semanticLSPStatusOverlay: some View {
        if let message = semanticStatusMessage {
            HStack(alignment: .top, spacing: 8) {
                if semanticStatusIsLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: semanticStatusIsError ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(semanticStatusIsError ? Color.orange : Color.accentColor)
                }

                Text(message)
                    .font(.caption)
                    .lineLimit(3)
                    .textSelection(.enabled)

                Spacer(minLength: 8)

                Button {
                    semanticStatusMessage = nil
                    semanticStatusIsLoading = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 520, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(12)
        }
    }
    
    @ViewBuilder
    private var semanticSidebar: some View {
        if showSemanticSidebar, let bridge = codeContextBridge {
            CodeSemanticSidebar(
                bridge: bridge,
                codeContent: text,
                language: language,
                onOpenNote: { nodeId in
                    openNoteInWorkspace(nodeId: nodeId)
                },
                onCreateNoteFromCode: {
                    createNoteFromCode()
                }
            )
            .transition(.move(edge: .trailing))
        }
    }
    
    // MARK: - Search Functions
    
    private func findNext() {
        performSearch(direction: .forward)
    }
    
    private func findPrevious() {
        performSearch(direction: .backward)
    }
    
    private func performSearch(direction: CodeEditorSearchDirection) {
        guard !searchQuery.isEmpty else { return }
        let cursorOffset = CodeEditorSemanticLSP.utf16Offset(
            in: text,
            line: cursorLine - 1,
            character: cursorCol - 1
        )
        let currentRange = activeSearchRange ?? cursorOffset.map {
            NSRange(location: $0, length: 0)
        }
        guard let match = CodeEditorSearchEngine.find(
            in: text,
            query: searchQuery,
            caseSensitive: searchCaseSensitive,
            direction: direction,
            currentRange: currentRange
        ) else {
            NSSound.beep()
            activeSearchRange = nil
            return
        }

        activeSearchRange = match
        requestEditorSelection(match)
    }

    // MARK: - Semantic LSP Lookup

    private func requestSemanticHover() {
        guard CodeEditorSemanticLSP.canRun(language: language) else {
            semanticStatusMessage = CodeEditorSemanticLSP.unavailableMessage(language: language)
            semanticStatusIsError = true
            semanticStatusIsLoading = false
            return
        }

        let textSnapshot = text
        let languageSnapshot = language
        let filePathSnapshot = filePath
        let cursorLineSnapshot = cursorLine
        let cursorColSnapshot = cursorCol

        semanticLookupTask?.cancel()
        semanticStatusMessage = "Inspecting symbol..."
        semanticStatusIsError = false
        semanticStatusIsLoading = true

        semanticLookupTask = Task {
            do {
                let summary = try await CodeEditorSemanticLSP.hoverSummary(
                    text: textSnapshot,
                    language: languageSnapshot,
                    filePath: filePathSnapshot,
                    cursorLine: cursorLineSnapshot,
                    cursorColumn: cursorColSnapshot
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    semanticStatusMessage = summary ?? "No symbol information at cursor."
                    semanticStatusIsError = false
                    semanticStatusIsLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    semanticStatusMessage = CodeEditorSemanticLSP.userFacingError(error)
                    semanticStatusIsError = true
                    semanticStatusIsLoading = false
                }
            }
        }
    }

    private func requestSemanticDefinition() {
        guard CodeEditorSemanticLSP.canRun(language: language) else {
            semanticStatusMessage = CodeEditorSemanticLSP.unavailableMessage(language: language)
            semanticStatusIsError = true
            semanticStatusIsLoading = false
            return
        }

        let textSnapshot = text
        let languageSnapshot = language
        let filePathSnapshot = filePath
        let cursorLineSnapshot = cursorLine
        let cursorColSnapshot = cursorCol
        let documentURI = CodeEditorSemanticLSP.documentURL(
            filePath: filePathSnapshot,
            language: languageSnapshot
        ).absoluteString

        semanticLookupTask?.cancel()
        semanticStatusMessage = "Finding definition..."
        semanticStatusIsError = false
        semanticStatusIsLoading = true

        semanticLookupTask = Task {
            do {
                let definition = try await CodeEditorSemanticLSP.definitionLocation(
                    text: textSnapshot,
                    language: languageSnapshot,
                    filePath: filePathSnapshot,
                    cursorLine: cursorLineSnapshot,
                    cursorColumn: cursorColSnapshot
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let definition else {
                        semanticStatusMessage = "No definition found at cursor."
                        semanticStatusIsError = false
                        semanticStatusIsLoading = false
                        return
                    }

                    let lineNumber = definition.range.start.line + 1
                    if definition.uri == documentURI,
                       let definitionRange = CodeEditorSemanticLSP.nsRange(for: definition.range, in: textSnapshot) {
                        activeSearchRange = nil
                        requestEditorSelection(definitionRange)
                        cursorLine = lineNumber
                        cursorCol = definition.range.start.character + 1
                        semanticStatusMessage = "Definition selected at line \(lineNumber)."
                        semanticStatusIsError = false
                    } else {
                        let target = URL(string: definition.uri)?.lastPathComponent ?? "another file"
                        semanticStatusMessage = "Definition found in \(target) at line \(lineNumber); cross-file navigation is not wired yet."
                        semanticStatusIsError = false
                    }
                    semanticStatusIsLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    semanticStatusMessage = CodeEditorSemanticLSP.userFacingError(error)
                    semanticStatusIsError = true
                    semanticStatusIsLoading = false
                }
            }
        }
    }
    
    // MARK: - Editor Settings Menu
    
    private var editorSettingsMenu: some View {
        Menu {
            Button {
                showGoToLineSheet = true
            } label: {
                Label("Go to Line", systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            Section("Legacy") {
                Toggle("Use v1 Legacy Editor", isOn: $useLegacyV1Editor)
            }

            // Indentation settings
            Section("Indentation") {
                Toggle("Use Spaces", isOn: $useSpaces)
                
                Picker("Tab Width", selection: $tabWidth) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                    Text("8 spaces").tag(8)
                }
            }
            
            Section("Font") {
                Button {
                    fontSize = max(8, fontSize - 1)
                } label: {
                    Label("Decrease Font Size", systemImage: "textformat.size.smaller")
                }
                
                Button {
                    fontSize = min(32, fontSize + 1)
                } label: {
                    Label("Increase Font Size", systemImage: "textformat.size.larger")
                }
                
                Button {
                    fontSize = 15
                } label: {
                    Label("Reset Font Size", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: "gear")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        // SS-DD (owner 2026-06-20): hide the default Menu chevron so the icon-only eye/gear
        // render as clean glyphs (the chevron overlapped the SF Symbol → "deformed"). The
        // menu still opens on click; functionality unchanged.
        .menuIndicator(.hidden)
        .frame(width: toolbarMenuWidth)
    }

    // MARK: - View Options Menu
    
    private var viewOptionsMenu: some View {
        Menu {
            Section("View") {
                Toggle("Word Wrap", isOn: $wrapLines)
                Toggle("Show Line Numbers", isOn: $showLineGutter)
                Toggle("Show Invisibles", isOn: $showInvisibles)
            }

        } label: {
            Image(systemName: "eye")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        // SS-DD (owner 2026-06-20): hide the default Menu chevron so the icon-only eye/gear
        // render as clean glyphs (the chevron overlapped the SF Symbol → "deformed"). The
        // menu still opens on click; functionality unchanged.
        .menuIndicator(.hidden)
        .frame(width: toolbarMenuWidth)
    }

    // MARK: - Hybrid Features
    
    private func initializeCodeContextBridge() {
        guard codeContextBridge == nil else { return }
        
        let bridge = CodeContextBridge(
            graphState: graphState,
            triageService: triageService
        )
        codeContextBridge = bridge
    }
    
    private func updateSemanticContext(_ newText: String, immediate: Bool = false) {
        guard CodeEditorPerformancePolicy.shouldRefreshSemanticContext(isSidebarVisible: showSemanticSidebar) else {
            semanticRefreshTask?.cancel()
            return
        }

        initializeCodeContextBridge()
        guard let bridge = codeContextBridge else { return }

        semanticRefreshTask?.cancel()
        semanticRefreshTask = Task {
            if !immediate {
                try? await Task.sleep(for: CodeEditorPerformancePolicy.semanticRefreshDelay)
            }
            guard !Task.isCancelled else { return }
            bridge.findRelatedNotes(for: newText)
        }
    }
    
    private func openNoteInWorkspace(nodeId: String) {
        // Use NoteWindowManager or similar to open the note
        NoteWindowManager.shared.open(pageId: nodeId)
    }
    
    private func createNoteFromCode() {
        // Create a new note with the code content
        let noteTitle = filePath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? "Code Snippet"
        
        let noteContent = """
        # \(noteTitle)
        
        ## Code
        
        ```\(language)
        \(text)
        ```
        
        ## Context
        
        File: `\(filePath ?? "Untitled")`
        Language: \(language)
        Lines: \(totalLines)
        """
        
        // Use NoteWindowManager to create and open the note
        Task { @MainActor in
            // Create a new page via SwiftData
            if let container = AppBootstrap.shared?.modelContainer {
                let context = ModelContext(container)
                let newPage = SDPage(title: noteTitle)
                let failedPageId = newPage.id
                newPage.saveBody(noteContent)
                newPage.wordCount = noteContent.split(separator: " ").count
                newPage.needsVaultSync = true
                newPage.updatedAt = .now
                context.insert(newPage)
                BlockMirror.sync(pageId: newPage.id, body: noteContent, modelContext: context)
                do {
                    try context.save()
                    AppBootstrap.shared?.graphState.needsRefresh = true

                    // Open the new note
                    NoteWindowManager.shared.open(pageId: newPage.id)
                } catch {
                    context.delete(newPage)
                    let blockDescriptor = FetchDescriptor<SDBlock>(
                        predicate: #Predicate<SDBlock> { $0.pageId == failedPageId }
                    )
                    do {
                        let transientBlocks = try context.fetch(blockDescriptor)
                        for block in transientBlocks {
                            context.delete(block)
                        }
                    } catch {
                        Log.app.error(
                            "CodeEditor: failed to clean transient blocks for page \(failedPageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                    }
                    NoteFileStorage.deleteBody(pageId: failedPageId)
                    Log.app.error("CodeEditor: failed to persist note from code: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

}

// MARK: - Code Inspector Views (Graph Node Preview)
// Lightweight syntax-highlighted views for the graph inspector panel.
// No minimap, no line numbers — just clean colored code.

// ──── DEAD CODE REMOVED (736 lines) ────
// Removed: CodeEditorRepresentable, Coordinator, CodeTextView, LineNumberGutter, MinimapView
// Reason: Replaced by CodeEditorView package; had Tahoe rendering bug (drawBackground overpaint)
// ────────────────────────────────────────

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
        CodeEditorScrollConfigurator.allowTwoAxisScrolling(textView: textView, scrollView: scrollView)

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
/// Optimized for large files with chunked processing and reduced allocations.
enum CodeSyntaxHighlighter {
    
    /// Maximum file size for synchronous processing (larger files use chunked async)
    private static let maxSyncSize = 50000  // 50KB
    
    /// Result from processing a chunk
    private struct ChunkResult: Sendable {
        let index: Int
        let spans: [TokenSpan]
    }
    
    /// Apply syntax highlighting with automatic optimization based on file size.
    /// When `EPISTEMOS_USE_SYNTAX_CORE=1`, uses incremental tree-sitter via syntax-core
    /// for viewport-scoped highlighting instead of whole-file markdown_parse_code_tokens.
    static func apply(to textView: NSTextView, language: String, theme: EpistemosTheme) {
        let text = textView.string
        guard !text.isEmpty, !language.isEmpty else { return }

        if SyntaxCoreService.useSyntaxCore {
            applySyntaxCore(to: textView, text: text, language: language, theme: theme)
            return
        }

        if text.utf8.count > maxSyncSize {
            Task.detached(priority: .utility) {
                await applyChunked(to: textView, text: text, language: language, theme: theme)
            }
        } else {
            applySync(to: textView, text: text, language: language, theme: theme)
        }
    }

    /// Viewport-scoped highlighting via syntax-core (incremental tree-sitter + ropey).
    private static func applySyntaxCore(to textView: NSTextView, text: String, language: String, theme: EpistemosTheme) {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let storage = textView.textStorage ?? NSTextStorage()

        storage.beginEditing()
        defer { storage.endEditing() }

        storage.addAttribute(.font, value: textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)
        storage.addAttribute(.foregroundColor, value: textView.textColor ?? .white, range: fullRange)

        let service = SyntaxCoreService(docId: 0, language: language, source: text)
        guard service.isValid else { return }

        let byteCount = UInt64(text.utf8.count)
        let tokens = service.tokensForViewport(byteStart: 0, byteEnd: byteCount)
        guard !tokens.isEmpty else { return }

        for token in tokens {
            let start16 = Int(token.utf16_start)
            let len16 = Int(token.utf16_len)
            let range = NSRange(location: start16, length: len16)
            guard range.location + range.length <= nsString.length else { continue }

            let color = theme.nsColorForSyntaxKind(token.kind_id)
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
    }
    
    /// Synchronous highlighting for small files (< 50KB)
    private static func applySync(to textView: NSTextView, text: String, language: String, theme: EpistemosTheme) {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let storage = textView.textStorage ?? NSTextStorage()
        
        storage.beginEditing()
        defer { storage.endEditing() }
        
        // Apply base attributes
        storage.addAttribute(.font, value: textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)
        storage.addAttribute(.foregroundColor, value: textView.textColor ?? .white, range: fullRange)
        
        // Tokenize using Rust FFI
        let tokens = tokenize(text: text, language: language)
        guard !tokens.isEmpty else { return }
        
        // Build UTF-8 to UTF-16 mapping once
        let utf8ToUtf16 = buildUTF8ToUTF16Mapping(text: text)
        
        // Apply token colors
        applyTokens(tokens: tokens, utf8ToUtf16: utf8ToUtf16, storage: storage, textView: textView, theme: theme, nsLength: nsString.length)
    }
    
    /// Chunked async highlighting for large files (> 50KB)
    @MainActor
    private static func applyChunked(to textView: NSTextView, text: String, language: String, theme: EpistemosTheme) async {
        let storage = textView.textStorage ?? NSTextStorage()
        
        // Apply base attributes immediately
        await MainActor.run {
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            storage.beginEditing()
            storage.addAttribute(.font, value: textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)
            storage.addAttribute(.foregroundColor, value: textView.textColor ?? .white, range: fullRange)
            storage.endEditing()
        }
        
        // Process in chunks sequentially to avoid actor isolation complexity
        // while still yielding the main thread periodically
        let chunkSize = 25000  // 25KB chunks
        let chunks = CodeSyntaxChunker.utf8AlignedChunks(in: text, maxBytes: chunkSize)
        
        // Build global UTF-8 to UTF-16 mapping on background thread
        let utf8ToUtf16 = await Task.detached(priority: .utility) {
            buildUTF8ToUTF16Mapping(text: text)
        }.value
        
        // Process chunks sequentially with yielding
        for chunk in chunks {
            // Yield to allow UI updates between chunks
            await Task.yield()

            let chunkText = String(text[chunk.range])
            let chunkOffset = chunk.utf8LowerBound
            let totalLength = (text as NSString).length
            let spans = await Task.detached(priority: .utility) {
                let tokens = tokenize(text: chunkText, language: language)
                return computeTokenSpans(
                    tokens: tokens,
                    chunkOffset: chunkOffset,
                    utf8ToUtf16: utf8ToUtf16,
                    totalLength: totalLength
                )
            }.value

            storage.beginEditing()
            for span in spans {
                storage.addAttribute(
                    .foregroundColor,
                    value: theme.nsColorForTokenType(span.tokenType),
                    range: span.range
                )
            }
            storage.endEditing()
        }
    }
    
    // MARK: - Tokenization
    
    nonisolated private static func tokenize(text: String, language: String) -> [CodeToken] {
        let maxTokens: UInt32 = 16384
        let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
        defer { buffer.deallocate() }
        
        let tokenCount = language.withCString { langPtr in
            text.withCString { codePtr in
                markdown_parse_code_tokens(codePtr, UInt32(text.utf8.count), langPtr, buffer, maxTokens)
            }
        }
        
        var tokens: [CodeToken] = []
        tokens.reserveCapacity(Int(tokenCount))
        for i in 0..<Int(tokenCount) {
            tokens.append(buffer[i])
        }
        return tokens
    }
    
    // MARK: - UTF-8 to UTF-16 Mapping
    
    nonisolated private static func buildUTF8ToUTF16Mapping(text: String) -> [Int] {
        let utf8 = Array(text.utf8)
        var mapping = [Int](repeating: 0, count: utf8.count + 1)
        var utf16Pos = 0
        var i = 0
        
        while i < utf8.count {
            mapping[i] = utf16Pos
            let byte = utf8[i]
            let seqLen: Int
            if byte < 0x80 { seqLen = 1 }
            else if byte < 0xE0 { seqLen = 2 }
            else if byte < 0xF0 { seqLen = 3 }
            else { seqLen = 4 }
            utf16Pos += (seqLen == 4) ? 2 : 1
            i += seqLen
        }
        mapping[utf8.count] = utf16Pos
        
        return mapping
    }
    
    // MARK: - Token Application
    
    private struct TokenSpan: Sendable {
        let location: Int
        let length: Int
        let tokenType: UInt8

        var range: NSRange {
            NSRange(location: location, length: length)
        }
    }
    

    
    private static func applyTokens(
        tokens: [CodeToken],
        utf8ToUtf16: [Int],
        storage: NSTextStorage,
        textView: NSTextView,
        theme: EpistemosTheme,
        nsLength: Int
    ) {
        for token in tokens {
            let start8 = Int(token.start)
            let end8 = min(Int(token.end), utf8ToUtf16.count - 1)
            guard start8 < utf8ToUtf16.count - 1, start8 < end8 else { continue }
            
            let start16 = utf8ToUtf16[start8]
            let end16 = utf8ToUtf16[end8]
            let range = NSRange(location: start16, length: end16 - start16)
            guard range.location + range.length <= nsLength else { continue }
            
            let color = theme.nsColorForTokenType(token.token_type)
            storage.addAttribute(.foregroundColor, value: color, range: range)
            
            if token.token_type == 3, let baseFont = textView.font {
                let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: italic, range: range)
            }
        }
    }
    
    nonisolated private static func computeTokenSpans(
        tokens: [CodeToken],
        chunkOffset: Int,
        utf8ToUtf16: [Int],
        totalLength: Int
    ) -> [TokenSpan] {
        var spans: [TokenSpan] = []
        spans.reserveCapacity(tokens.count)
        
        for token in tokens {
            let start8 = Int(token.start) + chunkOffset
            let end8 = min(Int(token.end) + chunkOffset, utf8ToUtf16.count - 1)
            guard start8 < utf8ToUtf16.count - 1, start8 < end8 else { continue }
            
            let start16 = utf8ToUtf16[start8]
            let end16 = utf8ToUtf16[end8]
            let range = NSRange(location: start16, length: end16 - start16)
            guard range.location + range.length <= totalLength else { continue }
            
            spans.append(TokenSpan(
                location: range.location,
                length: range.length,
                tokenType: token.token_type
            ))
        }

        return spans
    }
}

/// Builds UTF-8-budgeted chunks that always begin and end on Swift
/// `String.Index` character boundaries. The syntax inspector tokenizer
/// reports byte offsets, but Swift indexing is character-based; this
/// helper keeps those domains explicit so Unicode-heavy code previews do
/// not trap by treating byte offsets as character offsets.
nonisolated enum CodeSyntaxChunker {
    struct Chunk {
        let range: Range<String.Index>
        let utf8LowerBound: Int
        let utf8UpperBound: Int
    }

    static func utf8AlignedChunks(in text: String, maxBytes: Int) -> [Chunk] {
        guard !text.isEmpty else { return [] }

        let budget = max(1, maxBytes)
        var chunks: [Chunk] = []
        chunks.reserveCapacity((text.utf8.count / budget) + 1)

        var lower = text.startIndex
        var lowerByteOffset = 0

        while lower < text.endIndex {
            var upper = lower
            var byteLength = 0

            while upper < text.endIndex {
                let next = text.index(after: upper)
                let nextByteLength = text[upper].utf8.count
                if byteLength > 0, byteLength + nextByteLength > budget {
                    break
                }
                byteLength += nextByteLength
                upper = next
            }

            let upperByteOffset = lowerByteOffset + byteLength
            chunks.append(Chunk(
                range: lower..<upper,
                utf8LowerBound: lowerByteOffset,
                utf8UpperBound: upperByteOffset
            ))

            lower = upper
            lowerByteOffset = upperByteOffset
        }

        return chunks
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
        CodeEditorScrollConfigurator.allowTwoAxisScrolling(textView: textView, scrollView: scrollView)

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




// MARK: - Code Semantic Match

/// A note that is semantically similar to code content.
struct CodeSemanticMatch: Identifiable, Sendable, Equatable {
    let id: String
    let nodeId: String
    let title: String
    let snippet: String
    let similarityScore: Float
    let matchType: MatchType
    
    enum MatchType: Sendable, Equatable {
        case exact        // Very high similarity (>0.85)
        case related      // Good similarity (0.70-0.85)
        case contextual   // Moderate similarity (0.55-0.70)
        
        var icon: String {
            switch self {
            case .exact: return "link.circle.fill"
            case .related: return "link.circle"
            case .contextual: return "doc.text.magnifyingglass"
            }
        }
        
        var color: Color {
            switch self {
            case .exact: return .green
            case .related: return .blue
            case .contextual: return .orange
            }
        }
    }
}

// MARK: - Code Context Bridge

/// Bridges code editor content with Epistemos semantic infrastructure.
/// Provides: similarity search, AI context enrichment, code-to-graph linking.
@MainActor
@Observable
final class CodeContextBridge {

    private(set) var relatedNotes: [CodeSemanticMatch] = []
    private(set) var isSearching = false
    private(set) var lastQuery: String = ""
    private(set) var aiContextSummary: String = ""
    
    private let embeddingService: EmbeddingService
    private let graphState: GraphState?
    private let triageService: TriageService?
    
    struct Configuration {
        var similarityThreshold: Float = 0.55
        var maxResults: Int = 10
        var debounceInterval: Duration = .milliseconds(500)
        var enableAIContext: Bool = true
    }
    
    var configuration = Configuration()
    
    private var searchTask: Task<Void, Never>?
    private var aiContextTask: Task<Void, Never>?
    private var lastCodeHash: Int = 0
    
    init(
        embeddingService: EmbeddingService? = nil,
        graphState: GraphState? = nil,
        triageService: TriageService? = nil
    ) {
        if let service = embeddingService {
            self.embeddingService = service
        } else if let graphState = graphState {
            self.embeddingService = graphState.embeddingService
        } else {
            self.embeddingService = EmbeddingService()
        }
        self.graphState = graphState
        self.triageService = triageService
    }
    
    func findRelatedNotes(for codeContent: String) {
        let codeHash = codeContent.hashValue
        guard codeHash != lastCodeHash else { return }
        lastCodeHash = codeHash
        
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            isSearching = true
            defer { isSearching = false }
            
            try? await Task.sleep(for: configuration.debounceInterval)
            guard !Task.isCancelled else { return }
            
            guard let codeEmbedding = await computeEmbedding(for: codeContent) else {
                relatedNotes = []
                return
            }
            
            let matches = await performSemanticSearch(
                queryEmbedding: codeEmbedding,
                limit: configuration.maxResults
            )
            
            guard !Task.isCancelled else { return }
            relatedNotes = matches
            
            if configuration.enableAIContext && !matches.isEmpty {
                await generateAIContextSummary(code: codeContent, matches: matches)
            }
        }
    }
    
    private func computeEmbedding(for code: String) async -> [Float]? {
        return await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return nil }
            return self.embeddingService.queryEmbedding(for: code)
        }.value
    }
    
    private func performSemanticSearch(
        queryEmbedding: [Float],
        limit: Int
    ) async -> [CodeSemanticMatch] {
        guard let graphState = graphState else { return [] }
        
        // Fetch candidate documents from graph
        let searchHits = graphState.semanticSearch(
            query: "semantic:",
            limit: 50  // Fetch more for GPU batch processing
        )
        
        guard !searchHits.isEmpty else { return [] }
        
        // Collect embeddings for GPU batch processing
        var documentEmbeddings: [[Float]] = []
        var documentMetadata: [(id: String, label: String, snippet: String)] = []
        
        for hit in searchHits {
            guard let embedding = embeddingService.embedding(for: hit.id) else { continue }
            let snippet = hit.node.metadata.quoteText ?? hit.node.metadata.abstract ?? ""
            documentEmbeddings.append(embedding)
            documentMetadata.append((hit.id, hit.node.label, String(snippet.prefix(200))))
        }
        
        guard !documentEmbeddings.isEmpty else { return [] }
        
        // GPU-accelerated batch similarity computation (~50-100x faster)
        let similarities = await MetalComputeEngine.shared.batchCosineSimilarity(
            query: queryEmbedding,
            documents: documentEmbeddings,
            threshold: configuration.similarityThreshold
        )
        
        // Build matches from GPU results (already filtered by threshold)
        var matches: [CodeSemanticMatch] = []
        matches.reserveCapacity(limit)
        
        for (index, score) in similarities.enumerated() {
            guard score >= configuration.similarityThreshold else { continue }
            guard matches.count < limit else { break }
            
            let metadata = documentMetadata[index]
            let matchType: CodeSemanticMatch.MatchType
            switch score {
            case 0.85...1.0: matchType = .exact
            case 0.70..<0.85: matchType = .related
            default: matchType = .contextual
            }
            
            matches.append(CodeSemanticMatch(
                id: metadata.id,
                nodeId: metadata.id,
                title: metadata.label,
                snippet: metadata.snippet,
                similarityScore: score,
                matchType: matchType
            ))
        }
        
        // Results are already approximately sorted by similarity from GPU
        // Final sort on CPU for precision (small N, negligible cost)
        return matches.sorted { $0.similarityScore > $1.similarityScore }
    }
    
    private func generateAIContextSummary(
        code: String,
        matches: [CodeSemanticMatch]
    ) async {
        guard let triageService = triageService else { return }
        
        aiContextTask?.cancel()
        aiContextTask = Task {
            let context = matches.prefix(3).map {
                "\($0.title): \($0.snippet)"
            }.joined(separator: "\n\n")
            
            let prompt = """
            This code appears in my vault. Based on my related notes, provide a one-sentence summary of what this code does and how it connects to my knowledge:
            
            Code (first 500 chars): \(code.prefix(500))
            
            Related notes:\n\(context)
            """
            
            var summary = ""
            do {
                for try await chunk in triageService.streamGeneral(
                    prompt: prompt,
                    systemPrompt: "You are a helpful assistant. Respond with one concise sentence.",
                    operation: .brainstorm,
                    contentLength: prompt.count
                ) {
                    guard !Task.isCancelled else { break }
                    summary += chunk
                    aiContextSummary = summary
                }
            } catch {
                aiContextSummary = ""
            }
        }
    }
    
    func explainCodeWithVaultContext(
        code: String,
        language: String
    ) -> AsyncThrowingStream<String, Error>? {
        guard let triageService = triageService else { return nil }
        
        let topNotes = relatedNotes.prefix(5)
        let notesContext = topNotes.map {
            "Note '\($0.title)' (similarity: \($0.similarityScore.isFinite ? Int($0.similarityScore * 100) : 0)%): \($0.snippet)"
        }.joined(separator: "\n\n")
        
        let prompt = """
        Explain this \(language) code using my personal notes as context:
        
        ```\(language)
        \(code)
        ```
        
        My related notes:
        \(notesContext.isEmpty ? "No directly related notes found." : notesContext)
        """
        
        return triageService.streamGeneral(
            prompt: prompt,
            systemPrompt: """
            You are explaining code to the user, incorporating insights from their personal knowledge base.
            Connect the code concepts to their notes when relevant.
            Be concise but thorough.
            """,
            operation: .chatResponse(query: "Explain code"),
            contentLength: prompt.count
        )
    }
    
    func semanticCodeSearch(query: String) async -> [CodeSemanticMatch] {
        findRelatedNotes(for: query)
        return relatedNotes
    }
    
    func cancelPendingWork() {
        searchTask?.cancel()
        aiContextTask?.cancel()
    }
}

// MARK: - Code Semantic Sidebar

struct CodeSemanticSidebar: View {
    @State private var bridge: CodeContextBridge
    @State private var insightGenerator: CodeInsightGenerator
    @State private var selectedMatch: CodeSemanticMatch?
    @State private var aiExplanation: String = ""
    @State private var isExplaining = false
    @State private var showSemanticSearch = false
    @State private var selectedTab: SidebarTab = .insights
    @State private var insightRefreshTask: Task<Void, Never>?

    @ScaledMetric(relativeTo: .body) private var sidebarWidth: CGFloat = 300
    
    enum SidebarTab {
        case insights, related
    }
    
    let codeContent: String
    let language: String
    let onOpenNote: (String) -> Void
    let onCreateNoteFromCode: () -> Void
    
    init(
        bridge: CodeContextBridge? = nil,
        insightGenerator: CodeInsightGenerator? = nil,
        codeContent: String,
        language: String,
        onOpenNote: @escaping (String) -> Void,
        onCreateNoteFromCode: @escaping () -> Void
    ) {
        self._bridge = State(initialValue: bridge ?? CodeContextBridge())
        self._insightGenerator = State(initialValue: insightGenerator ?? CodeInsightGenerator())
        self.codeContent = codeContent
        self.language = language
        self.onOpenNote = onOpenNote
        self.onCreateNoteFromCode = onCreateNoteFromCode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            
            // Tab selector
            tabSelector
            Divider()
            
            // Content based on tab
            switch selectedTab {
            case .insights:
                insightsSection
            case .related:
                relatedNotesSection
            }
            
            Divider()
            actionsSection
        }
        .frame(width: sidebarWidth)
        .background(.ultraThinMaterial)
        .onAppear {
            if bridge.relatedNotes.isEmpty {
                bridge.findRelatedNotes(for: codeContent)
            }
            scheduleInsights(for: codeContent, immediate: true)
        }
        .onChange(of: codeContent) { _, newContent in
            scheduleInsights(for: newContent)
        }
        .onChange(of: bridge.relatedNotes) { _, _ in
            scheduleInsights(for: codeContent)
        }
        .onDisappear {
            insightRefreshTask?.cancel()
            bridge.cancelPendingWork()
            insightGenerator.cancelGeneration()
        }
    }

    private func scheduleInsights(for code: String, immediate: Bool = false) {
        insightRefreshTask?.cancel()
        insightRefreshTask = Task {
            if !immediate {
                try? await Task.sleep(
                    for: CodeEditorPerformancePolicy.insightRefreshDelay(characterCount: code.count)
                )
            }
            guard !Task.isCancelled else { return }
            insightGenerator.generateInsights(
                code: code,
                language: language,
                relatedMatches: bridge.relatedNotes,
                immediate: true
            )
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Insights",
                icon: "sparkles",
                isSelected: selectedTab == .insights
            ) {
                selectedTab = .insights
            }
            
            TabButton(
                title: "Related",
                icon: "link",
                isSelected: selectedTab == .related
            ) {
                selectedTab = .related
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    private var insightsSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                // AI Insights
                if insightGenerator.insights.isEmpty && !insightGenerator.isGenerating {
                    insightsEmptyState
                } else {
                    ForEach(insightGenerator.insights) { insight in
                        InsightCard(insight: insight, onOpenNote: onOpenNote)
                            .padding(.horizontal)
                    }
                }
                
                // Context summary from bridge
                if !bridge.aiContextSummary.isEmpty {
                    vaultContextCard
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var insightsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Analyzing code...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var vaultContextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "archivebox")
                    .foregroundStyle(.green)
                Text("Vault Context")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(bridge.aiContextSummary)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(4)
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.accentColor)
                
                Text("Semantic Context")
                    .font(.headline)
                
                Spacer()
                
                if bridge.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text("Related notes from your vault")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var aiContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("AI Insight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(bridge.aiContextSummary)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
    }
    
    private var relatedNotesSection: some View {
        List(bridge.relatedNotes) { match in
            RelatedNoteRow(match: match)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedMatch = match
                    onOpenNote(match.nodeId)
                }
                .contextMenu {
                    Button {
                        onOpenNote(match.nodeId)
                    } label: {
                        Label("Open Note", systemImage: "doc.text")
                    }
                    
                    Button {
                        NSPasteboard.general.setString("[[\(match.title)]]", forType: .string)
                    } label: {
                        Label("Copy Wikilink", systemImage: "link")
                    }
                }
        }
        .listStyle(.plain)
        .overlay {
            if bridge.relatedNotes.isEmpty && !bridge.isSearching {
                emptyStateView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No related notes found")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Text("This code doesn't semantically match any notes in your vault yet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button {
                explainWithAI()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(isExplaining ? "Explaining..." : "Explain with AI")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExplaining)
            
            Button {
                showSemanticSearch = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Semantic Search")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button {
                onCreateNoteFromCode()
            } label: {
                HStack {
                    Image(systemName: "plus.square")
                    Text("Create Note")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .sheet(isPresented: $showSemanticSearch) {
            SemanticCodeSearchSheet(bridge: bridge)
        }
    }
    
    private func explainWithAI() {
        isExplaining = true
        aiExplanation = ""
        
        Task {
            guard let stream = bridge.explainCodeWithVaultContext(
                code: codeContent,
                language: language
            ) else {
                isExplaining = false
                return
            }
            
            do {
                for try await chunk in stream {
                    aiExplanation += chunk
                }
            } catch {
                aiExplanation = "Error: \(error.localizedDescription)"
            }
            
            isExplaining = false
        }
    }
}

// MARK: - Related Note Row

struct RelatedNoteRow: View {
    let match: CodeSemanticMatch
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: match.matchType.icon)
                .foregroundStyle(match.matchType.color)
                .font(.body)

            VStack(alignment: .leading, spacing: 4) {
                Text(match.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(match.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text("\(match.similarityScore.isFinite ? Int(match.similarityScore * 100) : 0)% match")
                        .font(.caption)
                        .foregroundStyle(match.matchType.color)

                    Spacer()

                    Text(match.matchTypeText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isHovered ? Color.accentColor.opacity(0.05) : Color.clear)
        .onHover { hovered in
            isHovered = hovered
        }
    }
}

extension CodeSemanticMatch {
    var matchTypeText: String {
        switch matchType {
        case .exact: return "Exact"
        case .related: return "Related"
        case .contextual: return "Context"
        }
    }
}

// MARK: - Semantic Code Search Sheet

struct SemanticCodeSearchSheet: View {
    let bridge: CodeContextBridge
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [CodeSemanticMatch] = []
    @State private var isSearching = false

    @ScaledMetric(relativeTo: .body) private var sheetWidth: CGFloat = 400
    @ScaledMetric(relativeTo: .body) private var sheetHeight: CGFloat = 500
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Semantic Code Search")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Describe what the code does...", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .padding(.horizontal)
            
            if query.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Examples:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach([
                        "authentication flow",
                        "data persistence",
                        "error handling",
                        "network requests"
                    ], id: \.self) { example in
                        Button {
                            query = example
                            performSearch()
                        } label: {
                            Text("• \(example)")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            List(results) { match in
                RelatedNoteRow(match: match)
            }
            .listStyle(.plain)

            Spacer()
        }
        .frame(width: sheetWidth, height: sheetHeight)
    }
    
    private func performSearch() {
        guard !query.isEmpty else { return }
        
        isSearching = true
        results = []
        
        Task {
            let matches = await bridge.semanticCodeSearch(query: query)
            results = matches
            isSearching = false
        }
    }
}


// MARK: - Apple Intelligence Code Insights

/// AI-powered insights about code, grounded in the user's knowledge vault.
struct CodeInsight: Identifiable, Sendable {
    let id = UUID()
    let type: InsightType
    let title: String
    let content: String
    let confidence: InsightConfidence
    let relatedNoteIds: [String]
    let generatedAt: Date
    
    enum InsightType: Sendable {
        case summary          // What this code does
        case pattern          // Design patterns used
        case vaultConnection  // How it connects to your notes
        case suggestion       // Improvement suggestions
        case security         // Security considerations
        case performance      // Performance notes
        
        var icon: String {
            switch self {
            case .summary: return "doc.text"
            case .pattern: return "flowchart"
            case .vaultConnection: return "link.circle"
            case .suggestion: return "lightbulb"
            case .security: return "shield"
            case .performance: return "gauge.with.dots.needle.67percent"
            }
        }
        
        var color: Color {
            switch self {
            case .summary: return .blue
            case .pattern: return .purple
            case .vaultConnection: return .green
            case .suggestion: return .orange
            case .security: return .red
            case .performance: return .cyan
            }
        }
    }
    
    enum InsightConfidence: String, Sendable {
        case high = "High"
        case medium = "Medium"
        case tentative = "Tentative"
        
        var color: Color {
            switch self {
            case .high: return .green
            case .medium: return .orange
            case .tentative: return .gray
            }
        }
    }
}

// MARK: - Code Insight Generator

/// Generates AI insights about code using Apple Intelligence + vault context.
@MainActor
@Observable
final class CodeInsightGenerator {

    private(set) var insights: [CodeInsight] = []
    private(set) var isGenerating = false
    private(set) var currentAnalysis: String = ""
    
    private let appleIntelligence: AppleIntelligenceService
    private let embeddingService: EmbeddingService
    private var generationTask: Task<Void, Never>?
    
    init(
        appleIntelligence: AppleIntelligenceService = .shared,
        embeddingService: EmbeddingService? = nil
    ) {
        self.appleIntelligence = appleIntelligence
        self.embeddingService = embeddingService ?? EmbeddingService()
    }
    
    /// Generate comprehensive insights about code using Apple Intelligence.
    func generateInsights(
        code: String,
        language: String,
        relatedMatches: [CodeSemanticMatch],
        immediate: Bool = false
    ) {
        generationTask?.cancel()
        generationTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(
                    for: CodeEditorPerformancePolicy.insightRefreshDelay(characterCount: code.count)
                )
            }
            guard !Task.isCancelled else { return }
            isGenerating = true
            defer { isGenerating = false }
            
            var newInsights: [CodeInsight] = []
            
            // Generate different types of insights in parallel
            async let summaryInsight = generateSummary(code: code, language: language)
            async let patternInsight = generatePatternAnalysis(code: code, language: language)
            async let vaultInsight = generateVaultConnection(code: code, matches: relatedMatches)
            async let suggestionInsight = generateSuggestions(code: code, language: language, matches: relatedMatches)
            
            if let summary = await summaryInsight {
                newInsights.append(summary)
            }
            if let pattern = await patternInsight {
                newInsights.append(pattern)
            }
            if let vault = await vaultInsight {
                newInsights.append(vault)
            }
            if let suggestion = await suggestionInsight {
                newInsights.append(suggestion)
            }
            
            guard !Task.isCancelled else { return }
            insights = newInsights.sorted { $0.confidence.rawValue > $1.confidence.rawValue }
        }
    }
    
    /// Generate a concise summary of what the code does.
    private func generateSummary(code: String, language: String) async -> CodeInsight? {
        let prompt = """
        Analyze this \(language) code and provide a one-sentence summary of what it does:
        
        ```\(language)
        \(code.prefix(2000))
        ```
        
        Respond with ONLY the summary, no markdown, no bullet points.
        """
        
        do {
            let response = try await appleIntelligence.generate(
                prompt: prompt,
                systemPrompt: "You are a code analysis expert. Provide clear, concise summaries."
            )
            
            return CodeInsight(
                type: .summary,
                title: "Code Summary",
                content: response.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: .high,
                relatedNoteIds: [],
                generatedAt: Date()
            )
        } catch {
            return nil
        }
    }
    
    /// Identify design patterns and architectural approaches.
    private func generatePatternAnalysis(code: String, language: String) async -> CodeInsight? {
        let prompt = """
        Identify the main design patterns or architectural approaches used in this \(language) code:
        
        ```\(language)
        \(code.prefix(2000))
        ```
        
        List 1-3 patterns you recognize. Be specific (e.g., "Observer Pattern", "Dependency Injection", "Factory Method").
        If no clear patterns, say "No dominant patterns detected."
        """
        
        do {
            let response = try await appleIntelligence.generate(
                prompt: prompt,
                systemPrompt: "You are a software architecture expert. Identify design patterns accurately."
            )
            
            let content = response.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.contains("No dominant") else { return nil }
            
            return CodeInsight(
                type: .pattern,
                title: "Design Patterns",
                content: content,
                confidence: .medium,
                relatedNoteIds: [],
                generatedAt: Date()
            )
        } catch {
            return nil
        }
    }
    
    /// Connect code to vault knowledge.
    private func generateVaultConnection(
        code: String,
        matches: [CodeSemanticMatch]
    ) async -> CodeInsight? {
        guard !matches.isEmpty else { return nil }
        
        let topMatches = matches.prefix(3)
        let context = topMatches.map { "- \($0.title): \($0.snippet.prefix(150))" }.joined(separator: "\n")
        
        let prompt = """
        This code appears to relate to these notes in my vault:
        
        \(context)
        
        Briefly explain (1-2 sentences) how this code conceptually connects to my existing notes.
        Focus on the conceptual link, not implementation details.
        """
        
        do {
            let response = try await appleIntelligence.generate(
                prompt: prompt,
                systemPrompt: "You help connect code to existing knowledge. Be insightful but concise."
            )
            
            return CodeInsight(
                type: .vaultConnection,
                title: "Vault Connection",
                content: response.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: matches.first?.similarityScore ?? 0 > 0.8 ? .high : .medium,
                relatedNoteIds: topMatches.map { $0.id },
                generatedAt: Date()
            )
        } catch {
            return nil
        }
    }
    
    /// Generate improvement suggestions.
    private func generateSuggestions(
        code: String,
        language: String,
        matches: [CodeSemanticMatch]
    ) async -> CodeInsight? {
        let vaultContext = matches.isEmpty ? "" : "\n\nRelated vault notes may suggest: \(matches.prefix(2).map { $0.title }.joined(separator: ", "))"
        
        let prompt = """
        Review this \(language) code and suggest 1-2 specific improvements:
        
        ```\(language)
        \(code.prefix(2000))
        ```
        \(vaultContext)
        
        Focus on: readability, best practices, or potential bugs. Be specific and actionable.
        If no improvements needed, say "No suggestions - code looks good."
        """
        
        do {
            let response = try await appleIntelligence.generate(
                prompt: prompt,
                systemPrompt: "You are a senior code reviewer. Provide actionable, specific suggestions."
            )
            
            let content = response.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.contains("No suggestions") && !content.contains("looks good") else { return nil }
            
            return CodeInsight(
                type: .suggestion,
                title: "Suggestions",
                content: content,
                confidence: .medium,
                relatedNoteIds: [],
                generatedAt: Date()
            )
        } catch {
            return nil
        }
    }
    
    func cancelGeneration() {
        generationTask?.cancel()
    }
}

// MARK: - Code Insights Panel

struct CodeInsightsPanel: View {
    @State private var generator: CodeInsightGenerator
    let code: String
    let language: String
    let relatedMatches: [CodeSemanticMatch]
    let onOpenNote: (String) -> Void

    @ScaledMetric(relativeTo: .body) private var panelWidth: CGFloat = 320

    init(
        generator: CodeInsightGenerator? = nil,
        code: String,
        language: String,
        relatedMatches: [CodeSemanticMatch],
        onOpenNote: @escaping (String) -> Void
    ) {
        self._generator = State(initialValue: generator ?? CodeInsightGenerator())
        self.code = code
        self.language = language
        self.relatedMatches = relatedMatches
        self.onOpenNote = onOpenNote
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                
                Text("Apple Intelligence Insights")
                    .font(.headline)
                
                Spacer()
                
                if generator.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        generator.generateInsights(
                            code: code,
                            language: language,
                            relatedMatches: relatedMatches,
                            immediate: true
                        )
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            
            Divider()
            
            // Insights list
            if generator.insights.isEmpty && !generator.isGenerating {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(generator.insights) { insight in
                            InsightCard(insight: insight, onOpenNote: onOpenNote)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: panelWidth)
        .background(.ultraThinMaterial)
        .onAppear {
            generator.generateInsights(
                code: code,
                language: language,
                relatedMatches: relatedMatches,
                immediate: true
            )
        }
        .onChange(of: code) { _, newCode in
            generator.generateInsights(
                code: newCode,
                language: language,
                relatedMatches: relatedMatches
            )
        }
        .onDisappear {
            generator.cancelGeneration()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No insights yet")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Tap refresh to analyze this code with Apple Intelligence")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: CodeInsight
    let onOpenNote: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: insight.type.icon)
                    .foregroundStyle(insight.type.color)
                    .font(.body)

                Text(insight.title)
                    .font(.body.weight(.semibold))

                Spacer()

                // Confidence badge
                Text(insight.confidence.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(insight.confidence.color.opacity(0.15))
                    .foregroundStyle(insight.confidence.color)
                    .cornerRadius(4)

                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Text(insight.content)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Related notes chips
                if !insight.relatedNoteIds.isEmpty {
                    CodeInsightFlowLayout(spacing: 6) {
                        ForEach(insight.relatedNoteIds, id: \.self) { noteId in
                            Button {
                                onOpenNote(noteId)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                    Text("Related Note")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(insight.type.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Code Insight Flow Layout

struct CodeInsightFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = CodeInsightFlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = CodeInsightFlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct CodeInsightFlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}


// MARK: - Search Bar

struct SearchBar: View {
    @Binding var query: String
    @Binding var caseSensitive: Bool
    let onClose: () -> Void
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Find", text: $query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    onFindNext()
                }
            
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .frame(height: 16)
            
            Button {
                caseSensitive.toggle()
            } label: {
                Image(systemName: caseSensitive ? "textformat.abc.dottedunderline" : "textformat.abc")
                    .foregroundStyle(caseSensitive ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Case Sensitive")
            
            Button {
                onFindPrevious()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(query.isEmpty)
            
            Button {
                onFindNext()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(query.isEmpty)
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 400)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Go To Line Sheet

struct GoToLineSheet: View {
    @Binding var lineNumber: String
    let totalLines: Int
    let onGoToLine: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFocused: Bool

    @ScaledMetric(relativeTo: .body) private var sheetWidth: CGFloat = 250

    var body: some View {
        VStack(spacing: 20) {
            Text("Go to Line")
                .font(.headline)

            HStack {
                TextField("Line number", text: $lineNumber)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit {
                        submit()
                    }
                    .frame(minWidth: 100)

                Text("of \(totalLines)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Go") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parseLineNumber() == nil)
            }
        }
        .padding()
        .frame(width: sheetWidth)
        .onAppear {
            isFocused = true
        }
    }
    
    private func parseLineNumber() -> Int? {
        guard let num = Int(lineNumber), num > 0, num <= totalLines else {
            return nil
        }
        return num
    }
    
    private func submit() {
        guard let line = parseLineNumber() else { return }
        onGoToLine(line)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    func escapingClosingScriptTag() -> String {
        replacingOccurrences(of: "</script", with: "<\\/script", options: [.caseInsensitive])
    }
}

private extension NSColor {
    var codePreviewCSSColor: String {
        codePreviewCSSColor(opacity: nil)
    }

    func codePreviewCSSColor(opacity overrideOpacity: CGFloat?) -> String {
        let color = usingColorSpace(.sRGB) ?? self
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        let alpha = overrideOpacity ?? color.alphaComponent
        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }
}
