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

    static let semanticRefreshDelay: Duration = .milliseconds(220)
    static let textSnapshotPublishDelay: Duration = .milliseconds(140)
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

enum CodeEditorReleasePolicy {
    static let semanticSidebarEnabled = false
    static let aiPartnerEnabled = false
}

nonisolated enum CodeEditorTextPosition {
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

// MARK: - CodeEditorView

struct CodeEditorView: View {
    let initialContent: String
    let language: String
    let filePath: String?  // Optional: for code-to-graph linking
    let onEditStarted: (@MainActor () -> Void)?
    let onTextSnapshot: ((String) -> Void)?
    let onContentChange: ((String) -> Void)?
    let isEditable: Bool
    let allowsMarkEditWindowToolbar: Bool
    let externalSelectionRequest: CoreEditorSelectionRequest?
    let liveTextQueryKey: UUID?
    let sourceLineWrapping: Bool
    let contentWidthMode: NoteWidthMode
    /// SS-GC (owner 2026-06-20): when the code editor is mounted inside the embedded
    /// home-graph surface, its top bar must paint the GRAPH backdrop so it isn't a white
    /// card slab against the darker landing surround. nil = the standalone / notes /
    /// detached-window appearance (the card top bar), unchanged. Mirrors the prose
    /// branch's `themeOverride` (NoteDetailWorkspaceView).
    let themeOverride: EpistemosTheme?

    @Environment(UIState.self) private var ui
    @Environment(GraphState.self) private var graphState: GraphState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .body) private var toolbarMenuWidth: CGFloat = 20

    @State private var text: String
    @State private var cursorLine: Int = 1
    @State private var cursorCol: Int = 1
    @State private var totalLines: Int
    @State private var outlineRefreshTask: Task<Void, Never>?
    @State private var outlineRefreshRevision: UInt64 = 0
    @State private var outlineRefreshWorkerGeneration: UInt64 = 0
    @State private var semanticRefreshTask: Task<Void, Never>?
    @State private var textSnapshotTask: Task<Void, Never>?
    @State private var textSnapshotRevision: UInt64 = 0
    @State private var textSnapshotWorkerGeneration: UInt64 = 0
    @State private var contentDebouncer: CodeEditorContentDebouncer?
    @State private var coreEditorSelectionRequest: CoreEditorSelectionRequest?
    @State private var webKitSelectionRequest: WebKitCodeEditorSelectionRequest?
    
    // MARK: - Editor Preferences (persisted via AppStorage)
    
    @AppStorage("codeEditor.wrapLines", store: FoundationSafety.runtimeUserDefaults) private var wrapLines = false
    // Minimap removed — outline navigator replaces it
    @AppStorage("codeEditor.showInvisibles", store: FoundationSafety.runtimeUserDefaults) private var showInvisibles = false
    @AppStorage("codeEditor.invisiblesDefaultReset.20260702", store: FoundationSafety.runtimeUserDefaults) private var didResetInvisiblesDefault = false
    // Keep the code surface at the native-editor scale by default. The
    // CoreEditor owns rendering now, but code notes should still feel like
    // a Mac code editor rather than a compact web preview panel.
    @AppStorage("codeEditor.fontSize", store: FoundationSafety.runtimeUserDefaults) private var fontSize: Double = 15
    @AppStorage("codeEditor.useSpaces", store: FoundationSafety.runtimeUserDefaults) private var useSpaces = true
    @AppStorage("codeEditor.tabWidth", store: FoundationSafety.runtimeUserDefaults) private var tabWidth = 4
    @AppStorage("codeEditor.useLegacyV1Editor", store: FoundationSafety.runtimeUserDefaults) private var useLegacyV1Editor = false
    @AppStorage("epistemos.codeEditor.showLineGutter", store: FoundationSafety.runtimeUserDefaults) private var showLineGutter = true

    private var isMarkdownDocument: Bool {
        CodeLanguage.isMarkdownDocument(filePath: filePath, language: language)
    }

    private var usesLegacyV1Editor: Bool {
        useLegacyV1Editor && !isMarkdownDocument
    }

    private var codeEditorTheme: EpistemosTheme {
        themeOverride ?? ui.theme
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
    @State private var showLivePreview = false
    @State private var livePreviewText = ""
    @State private var livePreviewTask: Task<Void, Never>?
    @State private var livePreviewRevision: UInt64 = 0
    @State private var livePreviewWorkerGeneration: UInt64 = 0
    
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
        onEditStarted: (@MainActor () -> Void)? = nil,
        onTextSnapshot: ((String) -> Void)? = nil,
        onContentChange: ((String) -> Void)? = nil,
        isEditable: Bool = true,
        // Security default FALSE (bridge audit 2026-07-03) — see MarkEditCoreEditorView.
        allowsMarkEditWindowToolbar: Bool = false,
        externalSelectionRequest: CoreEditorSelectionRequest? = nil,
        liveTextQueryKey: UUID? = nil,
        sourceLineWrapping: Bool = true,
        contentWidthMode: NoteWidthMode = .normal,
        themeOverride: EpistemosTheme? = nil
    ) {
        self.initialContent = content
        self.language = language
        self.filePath = filePath
        self.onEditStarted = onEditStarted
        self.onTextSnapshot = onTextSnapshot
        self.onContentChange = onContentChange
        self.isEditable = isEditable
        self.allowsMarkEditWindowToolbar = allowsMarkEditWindowToolbar
        self.externalSelectionRequest = externalSelectionRequest
        self.liveTextQueryKey = liveTextQueryKey
        self.sourceLineWrapping = sourceLineWrapping
        self.contentWidthMode = contentWidthMode.normalized
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
                registerCodeEditorReadAloudProvider()
                resetInvisiblesDefaultIfNeeded()
                if isEditable {
                    _ = ensureContentDebouncer()
                }
                showSemanticSidebar = false
                livePreviewText = text
            }
            .onDisappear {
                cancelOutlineRefreshWorker()
                semanticRefreshTask?.cancel()
                textSnapshotTask?.cancel()
                textSnapshotWorkerGeneration &+= 1
                textSnapshotTask = nil
                cancelLivePreviewWorker()
                EpistemosVisibleReadAloudRegistry.shared.unregister(.codeEditor)
                if isEditable {
                    onTextSnapshot?(text)
                    if liveTextQueryKey == nil {
                        contentDebouncer?.flush(text)
                    }
                }
                contentDebouncer?.detach()
                contentDebouncer = nil
                codeContextBridge?.cancelPendingWork()
            }
            .onChange(of: text) { _, newText in
                activeSearchRange = nil
                if isEditable {
                    scheduleTextSnapshotPublish()
                    ensureContentDebouncer().enqueue(newText)
                }
                if showOutlineNavigator {
                    scheduleOutlineRefresh()
                }
                if showLivePreview {
                    scheduleLivePreviewUpdate()
                }
            }
            .onChange(of: initialContent) { oldValue, newValue in
                guard newValue != text else { return }
                guard text == oldValue || text.isEmpty else { return }
                text = newValue
                totalLines = CodeEditorLineMetrics.lineCount(newValue)
                if showOutlineNavigator {
                    scheduleOutlineRefresh(immediate: true)
                }
            }
            .onChange(of: cursorLine) { _, newLine in
                updateBreadcrumbs()
            }
            .onChange(of: showLivePreview) { _, enabled in
                if enabled {
                    livePreviewText = text
                } else {
                    cancelLivePreviewWorker()
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
                    scheduleOutlineRefresh(immediate: true)
                } else {
                    cancelOutlineRefreshWorker()
                    outlineItems = []
                }
        }
    }

    private func scheduleTextSnapshotPublish() {
        textSnapshotRevision &+= 1
        guard textSnapshotTask == nil else { return }
        textSnapshotWorkerGeneration &+= 1
        let workerGeneration = textSnapshotWorkerGeneration
        textSnapshotTask = Task { @MainActor in
            defer {
                if textSnapshotWorkerGeneration == workerGeneration {
                    textSnapshotTask = nil
                }
            }
            while !Task.isCancelled {
                let scheduledRevision = textSnapshotRevision
                try? await Task.sleep(for: CodeEditorPerformancePolicy.textSnapshotPublishDelay)
                guard !Task.isCancelled else { break }
                guard scheduledRevision == textSnapshotRevision else { continue }
                onTextSnapshot?(text)
                break
            }
        }
    }

    private func registerCodeEditorReadAloudProvider() {
        EpistemosVisibleReadAloudRegistry.shared.register(.codeEditor, activate: false) {
            text
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
    
    private func scheduleOutlineRefresh(immediate: Bool = false) {
        outlineRefreshRevision &+= 1
        if immediate {
            cancelOutlineRefreshWorker()
        }
        guard outlineRefreshTask == nil else { return }
        outlineRefreshWorkerGeneration &+= 1
        let workerGeneration = outlineRefreshWorkerGeneration
        outlineRefreshTask = Task { @MainActor in
            defer {
                if outlineRefreshWorkerGeneration == workerGeneration {
                    outlineRefreshTask = nil
                }
            }
            while !Task.isCancelled {
                let scheduledRevision = outlineRefreshRevision
                if !immediate {
                    let refreshDelay = CodeEditorPerformancePolicy.outlineRefreshDelay(
                        characterCount: text.count
                    )
                    try? await Task.sleep(for: refreshDelay)
                    guard !Task.isCancelled else { break }
                    guard scheduledRevision == outlineRefreshRevision else { continue }
                }
                let content = text
                outlineItems = outlineCache.parse(content: content, language: language)
                break
            }
        }
    }

    private func cancelOutlineRefreshWorker() {
        outlineRefreshWorkerGeneration &+= 1
        outlineRefreshTask?.cancel()
        outlineRefreshTask = nil
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
                theme: codeEditorTheme,
                fontSize: fontSize,
                wrapLines: sourceLineWrapping,
                showLineNumbers: showLineGutter,
                showInvisibles: showInvisibles,
                useSpaces: useSpaces,
                tabWidth: tabWidth,
                filePath: filePath,
                selectionRequest: externalSelectionRequest ?? coreEditorSelectionRequest,
                isEditable: isEditable,
                onContentDirty: onEditStarted,
                liveTextQueryKey: liveTextQueryKey,
                contentWidthMode: .wide,
                allowsMarkEditWindowToolbar: allowsMarkEditWindowToolbar
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: codeEditorTheme))
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var codeEditorTopBar: some View {
        HStack(spacing: 10) {
            Text("Ln \(cursorLine), Col \(cursorCol)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(codeEditorTheme.resolved.mutedForeground.color.opacity(0.92))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    codeEditorTheme.resolved.foreground.color.opacity(codeEditorTheme.isDark ? 0.07 : 0.045),
                    in: Capsule()
                )

            Spacer(minLength: 12)

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
            .keyboardShortcut("f", modifiers: .command)
            .help("Find (Cmd-F)")

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

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    showOutlineNavigator.toggle()
                }
            } label: {
                Image(systemName: showOutlineNavigator ? "sidebar.trailing" : "sidebar.right")
                    .foregroundStyle(showOutlineNavigator ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Toggle Outline")

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

    private func resetInvisiblesDefaultIfNeeded() {
        guard !didResetInvisiblesDefault else { return }
        showInvisibles = false
        didResetInvisiblesDefault = true
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
                .keyboardShortcut("f", modifiers: .command)
                .help("Find (Cmd-F)")

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
        .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: codeEditorTheme))
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
                theme: codeEditorTheme,
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
                theme: codeEditorTheme,
                fontSize: fontSize,
                wrapLines: wrapLines,
                showLineNumbers: showLineGutter,
                showInvisibles: showInvisibles,
                useSpaces: useSpaces,
                tabWidth: tabWidth,
                isEditable: isEditable,
                selectionRequest: externalSelectionRequest ?? coreEditorSelectionRequest,
                onContentDirty: onEditStarted,
                liveTextQueryKey: liveTextQueryKey
            )
        }
    }

    private var codeLivePreview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(codeEditorTheme.resolved.accent.color)
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
                previewTheme: codeEditorTheme.isDark ? .dark : .light,
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
            codeEditorTheme.isDark ? "dark" : "light",
            codeEditorTheme.resolved.accent.nsColor.codePreviewCSSColor,
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
        let surfaceTheme = codeEditorTheme.surfaceVariant(.other)
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

    private func scheduleLivePreviewUpdate() {
        livePreviewRevision &+= 1
        guard livePreviewTask == nil else { return }
        livePreviewWorkerGeneration &+= 1
        let workerGeneration = livePreviewWorkerGeneration
        livePreviewTask = Task { @MainActor in
            defer {
                if livePreviewWorkerGeneration == workerGeneration {
                    livePreviewTask = nil
                }
            }
            while !Task.isCancelled {
                let scheduledRevision = livePreviewRevision
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { break }
                guard scheduledRevision == livePreviewRevision else { continue }
                livePreviewText = text
                break
            }
        }
    }

    private func cancelLivePreviewWorker() {
        livePreviewWorkerGeneration &+= 1
        livePreviewTask?.cancel()
        livePreviewTask = nil
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

    @ViewBuilder
    private var semanticSidebar: some View {
        if showSemanticSidebar, let bridge = codeContextBridge {
            CodeSemanticSidebar(
                bridge: bridge,
                codeContent: text,
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
        let cursorOffset = CodeEditorTextPosition.utf16Offset(
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
        .help("Editor settings")  // DISC-5: icon-only gear had no tooltip
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
        .help("View options")  // DISC-4: icon-only eye had no tooltip
    }

    // MARK: - Hybrid Features
    
    private func initializeCodeContextBridge() {
        guard codeContextBridge == nil else { return }
        
        let bridge = CodeContextBridge(
            graphState: graphState
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
        
        Task { @MainActor in
            guard let vaultSync = AppBootstrap.shared?.vaultSync,
                  let pageId = await vaultSync.createPage(
                    title: noteTitle,
                    body: noteContent,
                    allowVaultSelectionPrompt: true
                  )
            else {
                Log.app.error("CodeEditor: failed to create note from code selection")
                return
            }
            AppBootstrap.shared?.graphState.needsRefresh = true
            NoteWindowManager.shared.open(pageId: pageId)
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
        CodeEditorTextViewTheme.apply(theme, to: textView)
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
        CodeEditorTextViewTheme.apply(theme, to: tv)
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
        CodeEditorTextViewTheme.apply(theme, to: textView)
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
        guard let textView = context.coordinator.textView else { return }
        CodeEditorTextViewTheme.apply(theme, to: textView)
        if textView.string != text {
            textView.string = text
            CodeSyntaxHighlighter.apply(to: textView, language: language, theme: theme)
        }
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

/// Bridges code editor content with direct local semantic retrieval.
@MainActor
@Observable
final class CodeContextBridge {

    private(set) var relatedNotes: [CodeSemanticMatch] = []
    private(set) var isSearching = false
    
    private let embeddingService: EmbeddingService
    private let graphState: GraphState?
    
    struct Configuration {
        var similarityThreshold: Float = 0.55
        var maxResults: Int = 10
        var debounceInterval: Duration = .milliseconds(500)
    }
    
    var configuration = Configuration()
    
    private var searchTask: Task<Void, Never>?
    private var lastCodeHash: Int = 0
    
    init(
        embeddingService: EmbeddingService? = nil,
        graphState: GraphState? = nil
    ) {
        if let service = embeddingService {
            self.embeddingService = service
        } else if let graphState = graphState {
            self.embeddingService = graphState.embeddingService
        } else {
            self.embeddingService = EmbeddingService()
        }
        self.graphState = graphState
    }
    
    func findRelatedNotes(for codeContent: String) {
        guard let checkedCodeContent = try? SearchRequestBounds.validatedQuery(codeContent),
              let checkedLimit = try? SearchRequestBounds.validatedResultLimit(configuration.maxResults) else {
            searchTask?.cancel()
            lastCodeHash = 0
            relatedNotes = []
            return
        }

        let codeHash = checkedCodeContent.hashValue
        guard codeHash != lastCodeHash else { return }
        lastCodeHash = codeHash
        
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            isSearching = true
            defer { isSearching = false }
            
            try? await Task.sleep(for: configuration.debounceInterval)
            guard !Task.isCancelled else { return }
            
            let matches = await performSemanticSearch(
                query: checkedCodeContent,
                limit: checkedLimit
            )
            
            guard !Task.isCancelled else { return }
            relatedNotes = matches
        }
    }
    
    private func performSemanticSearch(
        query: String,
        limit: Int
    ) async -> [CodeSemanticMatch] {
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query),
              let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit),
              let checkedCandidateLimit = try? SearchRequestBounds.validatedResultLimit(50) else {
            return []
        }
        guard let graphState = graphState else { return [] }
        
        // Fetch candidate documents and the one graph-owned query vector.
        guard let semanticResult = graphState.semanticSearchWithQueryEmbedding(
            query: checkedQuery,
            limit: checkedCandidateLimit
        ) else { return [] }
        let searchHits = semanticResult.hits
        let queryEmbedding = semanticResult.queryEmbedding
        
        guard !searchHits.isEmpty else { return [] }
        
        // Collect embeddings for GPU batch processing
        var documentEmbeddings: [[Float]] = []
        var documentMetadata: [(id: String, label: String, snippet: String)] = []
        documentEmbeddings.reserveCapacity(searchHits.count)
        documentMetadata.reserveCapacity(searchHits.count)
        
        for hit in searchHits {
            guard let embedding = embeddingService.embedding(for: hit.id) else { continue }
            guard embedding.count == queryEmbedding.count else { continue }
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
        matches.reserveCapacity(checkedLimit)
        
        for (index, score) in similarities.enumerated() {
            guard score >= configuration.similarityThreshold else { continue }
            guard matches.count < checkedLimit else { break }
            
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
    
    func semanticCodeSearch(query: String) async -> [CodeSemanticMatch] {
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query),
              let checkedLimit = try? SearchRequestBounds.validatedResultLimit(configuration.maxResults) else {
            return []
        }
        return await performSemanticSearch(
            query: checkedQuery,
            limit: checkedLimit
        )
    }
    
    func cancelPendingWork() {
        searchTask?.cancel()
    }
}

// MARK: - Code Semantic Sidebar

struct CodeSemanticSidebar: View {
    @State private var bridge: CodeContextBridge
    @State private var showSemanticSearch = false

    @ScaledMetric(relativeTo: .body) private var sidebarWidth: CGFloat = 300
    
    let codeContent: String
    let onOpenNote: (String) -> Void
    let onCreateNoteFromCode: () -> Void
    
    init(
        bridge: CodeContextBridge? = nil,
        codeContent: String,
        onOpenNote: @escaping (String) -> Void,
        onCreateNoteFromCode: @escaping () -> Void
    ) {
        self._bridge = State(initialValue: bridge ?? CodeContextBridge())
        self.codeContent = codeContent
        self.onOpenNote = onOpenNote
        self.onCreateNoteFromCode = onCreateNoteFromCode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            relatedNotesSection
            Divider()
            actionsSection
        }
        .frame(width: sidebarWidth)
        .background(.ultraThinMaterial)
        .onAppear {
            if bridge.relatedNotes.isEmpty {
                bridge.findRelatedNotes(for: codeContent)
            }
        }
        .onChange(of: codeContent) { _, newContent in
            bridge.findRelatedNotes(for: newContent)
        }
        .onDisappear {
            bridge.cancelPendingWork()
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(Color.accentColor)
                
                Text("Related Notes")
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
    
    private var relatedNotesSection: some View {
        List(bridge.relatedNotes) { match in
            RelatedNoteRow(match: match)
                .contentShape(Rectangle())
                .onTapGesture {
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
            .help("Previous match")  // DISC-13
            
            Button {
                onFindNext()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(query.isEmpty)
            .help("Next match")  // DISC-13
            
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

private enum CodeEditorTextViewTheme {
    static func apply(_ theme: EpistemosTheme, to textView: NSTextView) {
        let surfaceTheme = theme.surfaceVariant(.other)
        let background = MarkdownPreviewSurfaceStyle
            .solidFlatBackgroundNSColor(for: surfaceTheme)
            .withAlphaComponent(1.0)
        textView.textColor = surfaceTheme.resolved.foreground.nsColor
        textView.backgroundColor = background
        textView.insertionPointColor = surfaceTheme.resolved.accent.nsColor
        textView.selectedTextAttributes = [
            .backgroundColor: surfaceTheme.resolved.accent.nsColor.withAlphaComponent(surfaceTheme.isDark ? 0.30 : 0.22),
            .foregroundColor: surfaceTheme.resolved.foreground.nsColor,
        ]
    }
}

private extension NSColor {
    var codePreviewCSSColor: String {
        EpistemosWebThemeCSS.color(self)
    }

    func codePreviewCSSColor(opacity overrideOpacity: CGFloat?) -> String {
        EpistemosWebThemeCSS.color(self, opacity: overrideOpacity)
    }
}
