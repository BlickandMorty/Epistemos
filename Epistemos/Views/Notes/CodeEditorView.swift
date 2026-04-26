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
@preconcurrency import CodeEditSourceEditor
@preconcurrency import CodeEditLanguages
import os.signpost
import SwiftUI
import SwiftData
import Accelerate

// MARK: - Flat Epistemos Themes (matching prose editor simplicity)
// Minimal syntax highlighting - uses Epistemos theme colors for consistency
// with the note system. No layered/Xcode-style color complexity.
extension EditorTheme {
    private static func normalized(_ color: NSColor) -> NSColor {
        color.rgbSafeForCodeEditorTheme()
    }

    /// Flat light theme - matches prose editor's simplicity.
    /// Text and subtle colors default to the neutral grays tuned for the
    /// base light theme, but callers should pass the active EpistemosTheme's
    /// foreground + mutedForeground so syntax colors track the app theme
    /// instead of fighting it.
    static func flatLight(
        accent: NSColor,
        background: NSColor,
        text: NSColor? = nil,
        subtle: NSColor? = nil
    ) -> EditorTheme {
        let accent = normalized(accent)
        let background = normalized(background)
        let textColor = normalized(text ?? NSColor(hex: "1C1C1E"))
        let subtleColor = normalized(subtle ?? NSColor(hex: "6B6B6B"))
        let lineHighlightColor = normalized(
            background.blended(withFraction: 0.05, of: .black) ?? NSColor(hex: "F5F5F7")
        )
        let selectionColor = normalized(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.28))

        return EditorTheme(
            text: .init(color: textColor),
            insertionPoint: accent,
            invisibles: .init(color: normalized(NSColor(hex: "D1D1D6"))),
            background: background,
            lineHighlight: lineHighlightColor,
            selection: selectionColor,
            // Minimal syntax highlighting - just accent for keywords, rest are text color
            keywords: .init(color: accent, bold: false),
            commands: .init(color: textColor),
            types: .init(color: textColor),
            attributes: .init(color: textColor),
            variables: .init(color: textColor),
            values: .init(color: textColor),
            numbers: .init(color: accent),
            strings: .init(color: accent),
            characters: .init(color: accent),
            comments: .init(color: subtleColor, italic: false)
        )
    }
    
    /// Flat dark theme - matches prose editor's simplicity.
    /// Text and subtle colors default to the neutral grays tuned for the
    /// base dark theme, but callers should pass the active EpistemosTheme's
    /// foreground + mutedForeground so syntax colors track the app theme
    /// instead of fighting it.
    static func flatDark(
        accent: NSColor,
        background: NSColor,
        text: NSColor? = nil,
        subtle: NSColor? = nil
    ) -> EditorTheme {
        let accent = normalized(accent)
        let background = normalized(background)
        let textColor = normalized(text ?? NSColor(hex: "DFDFE0"))
        let subtleColor = normalized(subtle ?? NSColor(hex: "8A8A8A"))
        let lineHighlightColor = normalized(
            background.blended(withFraction: 0.07, of: .white) ?? NSColor(hex: "2C2C2E")
        )
        let selectionColor = normalized(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.22))
        
        return EditorTheme(
            text: .init(color: textColor),
            insertionPoint: accent,
            invisibles: .init(color: normalized(NSColor(hex: "535353"))),
            background: background,
            lineHighlight: lineHighlightColor,
            selection: selectionColor,
            // Minimal syntax highlighting - just accent for keywords, rest are text color
            keywords: .init(color: accent, bold: false),
            commands: .init(color: textColor),
            types: .init(color: textColor),
            attributes: .init(color: textColor),
            variables: .init(color: textColor),
            values: .init(color: textColor),
            numbers: .init(color: accent),
            strings: .init(color: accent),
            characters: .init(color: accent),
            comments: .init(color: subtleColor, italic: false)
        )
    }
    
    /// Ultra-minimal: no syntax highlighting at all (everything same color).
    /// Text color defaults to the base light tone; pass the app theme's
    /// foreground when you want the editor to move with the theme.
    static func minimalLight(
        accent: NSColor,
        background: NSColor,
        text: NSColor? = nil
    ) -> EditorTheme {
        let accent = normalized(accent)
        let background = normalized(background)
        let textColor = normalized(text ?? NSColor(hex: "1C1C1E"))
        let selectionColor = normalized(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.28))
        
        return EditorTheme(
            text: .init(color: textColor),
            insertionPoint: accent,
            invisibles: .init(color: normalized(textColor.withAlphaComponent(0.3))),
            background: background,
            lineHighlight: normalized(.clear),  // No line highlight
            selection: selectionColor,
            // Everything same color - truly no syntax highlighting
            keywords: .init(color: textColor),
            commands: .init(color: textColor),
            types: .init(color: textColor),
            attributes: .init(color: textColor),
            variables: .init(color: textColor),
            values: .init(color: textColor),
            numbers: .init(color: textColor),
            strings: .init(color: textColor),
            characters: .init(color: textColor),
            comments: .init(color: normalized(textColor.withAlphaComponent(0.6)))
        )
    }
    
    /// Ultra-minimal dark: no syntax highlighting at all.
    /// Text color defaults to the base dark tone; pass the app theme's
    /// foreground when you want the editor to move with the theme.
    static func minimalDark(
        accent: NSColor,
        background: NSColor,
        text: NSColor? = nil
    ) -> EditorTheme {
        let accent = normalized(accent)
        let background = normalized(background)
        let textColor = normalized(text ?? NSColor(hex: "DFDFE0"))
        let selectionColor = normalized(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.22))
        
        return EditorTheme(
            text: .init(color: textColor),
            insertionPoint: accent,
            invisibles: .init(color: normalized(textColor.withAlphaComponent(0.3))),
            background: background,
            lineHighlight: normalized(.clear),  // No line highlight
            selection: selectionColor,
            // Everything same color - truly no syntax highlighting
            keywords: .init(color: textColor),
            commands: .init(color: textColor),
            types: .init(color: textColor),
            attributes: .init(color: textColor),
            variables: .init(color: textColor),
            values: .init(color: textColor),
            numbers: .init(color: textColor),
            strings: .init(color: textColor),
            characters: .init(color: textColor),
            comments: .init(color: normalized(textColor.withAlphaComponent(0.6)))
        )
    }
}

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

enum CodeEditorReleasePolicy {
    static let semanticSidebarEnabled = false
    static let aiPartnerEnabled = false
}

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

// NOTE: NSTextStorage path was reverted — CodeEditSourceEditor's internal MultiStorageDelegate
// overwrites custom delegates on setTextStorage(), breaking tree-sitter highlighting.
// Using Binding<String> path instead, which the upstream coordinator handles correctly.
// The Binding<String> O(n) cost is acceptable at <100KB file sizes; for larger files,
// the NSTextStorage path would need upstream changes to support addDelegate pattern.

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
final class CodeCompanionService: ObservableObject {
    
    @Published private(set) var currentMessage: CompanionMessage?
    @Published private(set) var isAnalyzing = false
    @Published var isEnabled = true
    @Published var mode: CompanionMode = .balanced
    
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
        case qwenLocal = "Qwen 4B"
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

    @Environment(UIState.self) private var ui
    @Environment(NoteChatState.self) private var noteChatState: NoteChatState?
    @Environment(GraphState.self) private var graphState: GraphState?
    @Environment(TriageService.self) private var triageService: TriageService?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .body) private var toolbarMenuWidth: CGFloat = 20

    @State private var text: String
    @State private var editorState: SourceEditorState = .init()
    @State private var cursorLine: Int = 1
    @State private var cursorCol: Int = 1
    @State private var totalLines: Int
    @State private var contentChangeTask: Task<Void, Never>?
    @State private var outlineRefreshTask: Task<Void, Never>?
    @State private var semanticRefreshTask: Task<Void, Never>?
    @State private var sourceEditorCoordinator: EpistemosEditorCoordinator?
    
    // MARK: - Editor Preferences (persisted via AppStorage)
    
    @AppStorage("codeEditor.wrapLines") private var wrapLines = false
    // Minimap removed — outline navigator replaces it
    @AppStorage("codeEditor.showInvisibles") private var showInvisibles = false
    // Default matches the prose editor's body font size so code notes
    // share the same visual rhythm; users who previously bumped the
    // size up or down keep their saved choice.
    @AppStorage("codeEditor.fontSize") private var fontSize: Double = 15
    @AppStorage("codeEditor.useSpaces") private var useSpaces = true
    @AppStorage("codeEditor.tabWidth") private var tabWidth = 4
    // Right-side line-number gutter. Default ON; toggleable from the
    // editor View Options menu and Settings → Appearance → Editor.
    // Theme-aware (uses derived gutter tokens, not hard-coded colors).
    @AppStorage("epistemos.codeEditor.showLineGutter") private var showLineGutter = true
    
    // MARK: - UI State

    @State private var showSemanticSidebar = false
    @State private var showSearchBar = false
    @State private var showGoToLineSheet = false
    @State private var searchQuery = ""
    @State private var searchCaseSensitive = false
    @State private var goToLineNumber = ""
    @State private var codeContextBridge: CodeContextBridge?
    
    // MARK: - Outline Navigation (Xcode-style)
    @State private var outlineItems: [OutlineItem] = []
    @State private var showOutlineNavigator = false

    init(
        content: String,
        language: String,
        filePath: String? = nil,
        onContentChange: ((String) -> Void)? = nil
    ) {
        self.initialContent = content
        self.language = language
        self.filePath = filePath
        self.onContentChange = onContentChange
        _text = State(initialValue: content)
        _totalLines = State(initialValue: content.components(separatedBy: "\n").count)
    }

    var body: some View {
        editorContent
            .onAppear {
                ensureEditorCoordinator()
                bindNoteChatContext(with: text)
                showSemanticSidebar = false
                scheduleOutlineRefresh(for: text, immediate: true)
                applyGutterPreferences()
            }
            .onDisappear {
                outlineRefreshTask?.cancel()
                semanticRefreshTask?.cancel()
                codeContextBridge?.cancelPendingWork()
                clearNoteChatContextBindings()
                sourceEditorCoordinator?.destroy()
                sourceEditorCoordinator = nil
            }
            .onChange(of: text) { _, newText in
                bindNoteChatContext(with: newText)
                scheduleOutlineRefresh(for: newText)
            }
            .onChange(of: cursorLine) { _, newLine in
                updateBreadcrumbs()
            }
            .onChange(of: showLineGutter) { _, enabled in
                sourceEditorCoordinator?.setLineGutterEnabled(enabled)
            }
            .onChange(of: fontSize) { _, _ in
                applyGutterPreferences()
            }
            .onChange(of: ui.theme) { _, _ in
                applyGutterPreferences()
            }
    }

    /// Pushes gutter visibility, theme tokens, and font into the AppKit
    /// coordinator. Cheap; called on appear and whenever a relevant
    /// preference changes.
    private func applyGutterPreferences() {
        guard let coordinator = sourceEditorCoordinator else { return }
        coordinator.setLineGutterEnabled(showLineGutter)
        coordinator.applyGutterTokens(ui.theme.editorGutterTokens())
        coordinator.applyEditorBodyFont(.monospacedSystemFont(ofSize: fontSize, weight: .regular))
    }

    private func bindNoteChatContext(with text: String) {
        let capturedText = text
        let capturedGraphState = graphState
        noteChatState?.noteBodyProvider = { capturedText }
        noteChatState?.graphStateProvider = { capturedGraphState }
    }

    private func clearNoteChatContextBindings() {
        noteChatState?.noteBodyProvider = nil
        noteChatState?.graphStateProvider = nil
    }

    private func ensureEditorCoordinator() {
        guard sourceEditorCoordinator == nil else { return }
        let coordinator = EpistemosEditorCoordinator(
            cursorLine: $cursorLine,
            cursorCol: $cursorCol,
            totalLines: $totalLines,
            onContentChange: { newText in
                onContentChange?(newText)
                updateSemanticContext(newText)
            }
        )
        sourceEditorCoordinator = coordinator
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
            outlineItems = OutlineParser.parse(content: content, language: currentLanguage)
        }
    }
    
    private func updateBreadcrumbs() {
        // Breadcrumbs are computed on-the-fly based on cursor position
        // No state update needed - computed property
    }
    
    private var editorContent: some View {
        ZStack {
            HStack(spacing: 0) {
                mainEditorPane
                outlineNavigator
                if CodeEditorReleasePolicy.semanticSidebarEnabled {
                    semanticSidebar
                }
            }
            
        }
    }
    
    private var mainEditorPane: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            editorWithSearch
        }
    }
    
    private func goToLine(line: Int) {
        cursorLine = line
        editorState.cursorPositions = [CursorPosition(line: line, column: 1)]
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
        editorState.cursorPositions = [CursorPosition(line: line, column: 1)]
    }
    
    private var editorWithSearch: some View {
        ZStack(alignment: .top) {
            SourceEditor(
                $text,
                language: codeEditLanguage,
                configuration: editorConfiguration,
                state: $editorState,
                coordinators: sourceEditorCoordinator.map { [$0] } ?? []
            )
            
            searchBarOverlay
        }
        .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme))
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
        // Use NSTextFinder for native search
        // Note: This requires access to the NSTextView which is wrapped by CodeEditSourceEditor
        // For now, we'll use a simple string search approach
        performSearch(direction: .forward)
    }
    
    private func findPrevious() {
        performSearch(direction: .backward)
    }
    
    private enum SearchDirection {
        case forward, backward
    }
    
    private func performSearch(direction: SearchDirection) {
        // Get the selected range or start from beginning/end
        // This is a simplified implementation
        // Full implementation would require access to the underlying NSTextView
        guard !searchQuery.isEmpty else { return }
        _ = direction
    }
    
    // MARK: - Editor Settings Menu
    
    private var editorSettingsMenu: some View {
        Menu {
            Button {
                showGoToLineSheet = true
            } label: {
                Label("Go to Line", systemImage: "text.line.first.and.arrowtriangle.forward")
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
                    fontSize = 13
                } label: {
                    Label("Reset Font Size", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: "gear")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: toolbarMenuWidth)
    }

    // MARK: - View Options Menu
    
    private var viewOptionsMenu: some View {
        Menu {
            Section("View") {
                Toggle("Word Wrap", isOn: $wrapLines)
                Toggle("Outline Navigator", isOn: $showOutlineNavigator)
                Toggle("Show Invisibles", isOn: $showInvisibles)
                Toggle("Show Line Numbers", isOn: $showLineGutter)
            }

        } label: {
            Image(systemName: "eye")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
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

    // MARK: - Language Mapping (tree-sitter, 20+ languages)

    private var codeEditLanguage: CodeEditLanguages.CodeLanguage {
        switch language {
        case "swift":      return .swift
        case "rust":       return .rust
        case "python":     return .python
        case "javascript": return .javascript
        case "typescript":  return .typescript
        case "json":       return .json
        case "html":       return .html
        case "css":        return .css
        case "bash":       return .bash
        case "go":         return .go
        case "c":          return .c
        case "cpp":        return .cpp
        case "yaml":       return .yaml
        case "toml":       return .toml
        case "lua":        return .lua
        case "ruby":       return .ruby
        case "java":       return .java
        case "sql":        return .sql
        case "zig":        return .zig
        default:           return .default
        }
    }

    // MARK: - Editor Configuration

    private var editorConfiguration: SourceEditorConfiguration {
        return SourceEditorConfiguration(
            appearance: .init(
                theme: editorTheme,
                useThemeBackground: true,
                font: .monospacedSystemFont(ofSize: fontSize, weight: .regular),
                lineHeightMultiple: 1.35,
                wrapLines: wrapLines,
                tabWidth: tabWidth,
                bracketPairEmphasis: .flash
            ),
            behavior: .init(),
            peripherals: .init(
                // Matching the prose editor's chrome — no gutter, no
                // folding ribbon, no minimap. The code pane is "prose
                // that happens to be monospaced with syntax colors."
                showGutter: false,
                showMinimap: false,
                showFoldingRibbon: false
            )
        )
    }

    // MARK: - Theme (Flat Epistemos Themes)
    // Uses minimal syntax highlighting to match prose editor's simplicity.
    // Change `useMinimalTheme` to true for zero syntax highlighting.

    private let useMinimalTheme = false  // Set to true for no syntax highlighting at all

    @MainActor private var editorTheme: EditorTheme {
        let resolved = ui.theme.resolved
        let accent = resolved.accent.nsColor.rgbSafeForCodeEditorTheme()
        // Reuse the shared note canvas color so the code editor sits on
        // the same surface as prose/markdown instead of inventing a
        // competing background tone.
        let background = MarkdownPreviewSurfaceStyle
            .canvasNSColor(for: ui.theme)
            .rgbSafeForCodeEditorTheme()
        let text = resolved.foreground.nsColor.rgbSafeForCodeEditorTheme()
        let subtle = resolved.mutedForeground.nsColor.rgbSafeForCodeEditorTheme()
        if useMinimalTheme {
            return ui.theme.isDark
                ? .minimalDark(accent: accent, background: background, text: text)
                : .minimalLight(accent: accent, background: background, text: text)
        } else {
            return ui.theme.isDark
                ? .flatDark(accent: accent, background: background, text: text, subtle: subtle)
                : .flatLight(accent: accent, background: background, text: text, subtle: subtle)
        }
    }
}

// Segmented indentation guide implementation is in SegmentedIndentationGuideView.swift

// MARK: - Editor Coordinator (cursor tracking + content change + indent guides)

/// Optimized editor coordinator with throttled UI updates, efficient line counting, and VS Code-style indent guides
final class EpistemosEditorCoordinator: NSObject, TextViewCoordinator {
    @Binding var cursorLine: Int
    @Binding var cursorCol: Int
    @Binding var totalLines: Int
    let onContentChange: ((String) -> Void)?
    private var contentChangeTask: Task<Void, Never>?
    
    // Throttled UI update state
    private var pendingCursorUpdate: (line: Int, col: Int)?
    private var cursorUpdateTask: Task<Void, Never>?
    private var lastCursorUpdate = Date()
    private let cursorUpdateThrottle: TimeInterval = 0.016  // ~60fps
    
    // Performance instrumentation
    private static let perfLog = OSLog(subsystem: "app.epistemos", category: "CodeEditor")
    
    // Reusable buffer for line counting (avoid repeated allocations)
    private var lineCountBuffer: [UInt8] = []
    
    // Indentation guide view
    private weak var indentGuideView: SegmentedIndentationGuideView?
    private weak var textController: TextViewController?
    private var lastText: String = ""
    private var indentationGuideRefreshTask: Task<Void, Never>?

    // Line-number gutter (right-side, theme-aware). Modeled on the
    // indentation guide: a subview of the textView with scroll offset
    // applied at draw time. Hidden when `showGutter == false`.
    private weak var gutterView: CodeLineGutterView?
    private var showGutter: Bool = true
    private var gutterTokens: CodeLineGutterTokens = CodeLineGutterTokens(
        foreground: NSColor.tertiaryLabelColor,
        activeForeground: NSColor.labelColor,
        background: .clear,
        separator: NSColor.separatorColor
    )
    private var gutterDigitCount: Int = 2
    private var lastTotalLines: Int = 0

    // Selection tracking for code explanation
    var onSelectionChange: ((String) -> Void)?

    init(
        cursorLine: Binding<Int>,
        cursorCol: Binding<Int>,
        totalLines: Binding<Int>,
        onContentChange: ((String) -> Void)?
    ) {
        self._cursorLine = cursorLine
        self._cursorCol = cursorCol
        self._totalLines = totalLines
        self.onContentChange = onContentChange
        super.init()
    }

    func prepareCoordinator(controller: TextViewController) {
        setupIndentationGuides(controller: controller)
        setupLineGutter(controller: controller)
    }

    /// Installs the right-side line-number gutter. Mirrors the
    /// indent-guide setup so both views share the same scroll bridge.
    private func setupLineGutter(controller: TextViewController) {
        guard let tv = controller.textView else { return }

        let gutter = CodeLineGutterView()
        let bodyPointSize = tv.font.pointSize
        gutter.lineHeight = bodyPointSize * 1.35
        gutter.applyFont(.monospacedDigitSystemFont(
            ofSize: CodeLineGutterPolicy.gutterFontSize(forBodyPointSize: bodyPointSize),
            weight: .regular
        ))
        gutter.applyTokens(gutterTokens)
        gutter.gutterWidth = CodeLineGutterView.preferredWidth(
            digitCount: gutterDigitCount,
            font: gutter.font
        )
        gutter.autoresizingMask = [.minXMargin, .height]
        gutter.frame = NSRect(
            x: tv.bounds.maxX - gutter.gutterWidth,
            y: tv.bounds.minY,
            width: gutter.gutterWidth,
            height: tv.bounds.height
        )
        gutter.isHidden = !showGutter

        tv.addSubview(gutter)
        gutter.layer?.zPosition = 500  // above text background, below carets
        self.gutterView = gutter

        // Initial population
        gutter.updateLineCount(lastTotalLines)
        gutter.updateActiveLine(cursorLine)
    }

    /// Called from the SwiftUI view whenever the toggle changes. Cheap.
    func setLineGutterEnabled(_ enabled: Bool) {
        guard showGutter != enabled else { return }
        showGutter = enabled
        gutterView?.isHidden = !enabled
        if enabled, let tv = textController?.textView {
            gutterView?.frame = gutterFrame(in: tv)
            updateGutterScrollOffset()
        }
    }

    /// Re-applies the gutter color tokens. Call when the active theme
    /// changes; cheap (one redraw, no allocation).
    func applyGutterTokens(_ next: CodeLineGutterTokens) {
        gutterTokens = next
        gutterView?.applyTokens(next)
    }

    /// Re-applies the body font. Resizes the gutter accordingly.
    func applyEditorBodyFont(_ next: NSFont) {
        guard let gutter = gutterView else { return }
        gutter.lineHeight = next.pointSize * 1.35
        let gutterFont = NSFont.monospacedDigitSystemFont(
            ofSize: CodeLineGutterPolicy.gutterFontSize(forBodyPointSize: next.pointSize),
            weight: .regular
        )
        gutter.applyFont(gutterFont)
        gutter.gutterWidth = CodeLineGutterView.preferredWidth(
            digitCount: gutterDigitCount,
            font: gutterFont
        )
        if let tv = textController?.textView {
            gutter.frame = gutterFrame(in: tv)
        }
    }

    private func gutterFrame(in tv: NSView) -> NSRect {
        let width = gutterView?.gutterWidth ?? 28
        return NSRect(
            x: tv.bounds.maxX - width,
            y: tv.bounds.minY,
            width: width,
            height: tv.bounds.height
        )
    }

    private func updateGutterScrollOffset() {
        guard let gutter = gutterView,
              let tv = textController?.textView,
              !gutter.isHidden else { return }
        let scrollOffset: CGFloat
        if let scrollView = tv.enclosingScrollView {
            scrollOffset = -scrollView.documentVisibleRect.origin.y
        } else {
            scrollOffset = 0
        }
        // Keep the gutter pinned to the right edge as the textView width
        // changes (e.g. window resize, wrap toggle).
        gutter.frame = gutterFrame(in: tv)
        gutter.updateScrollOffset(scrollOffset)
    }

    private func updateGutterLineCount(_ count: Int) {
        lastTotalLines = count
        guard let gutter = gutterView else { return }
        gutter.updateLineCount(count)
        let nextDigits = CodeLineGutterPolicy.digitCount(for: count)
        if nextDigits != gutterDigitCount {
            gutterDigitCount = nextDigits
            gutter.gutterWidth = CodeLineGutterView.preferredWidth(
                digitCount: nextDigits,
                font: gutter.font
            )
            if let tv = textController?.textView {
                gutter.frame = gutterFrame(in: tv)
            }
        }
    }
    
    /// Sets up VS Code-style segmented indentation guide overlay
    private func setupIndentationGuides(controller: TextViewController) {
        guard let tv = controller.textView else { return }
        self.textController = controller
        
        // Use the new segmented indentation guide
        let guideView = SegmentedIndentationGuideView()
        guideView.indentWidth = 16
        guideView.lineHeight = tv.font.pointSize * 1.35
        guideView.tabWidth = 4
        guideView.autoresizingMask = [.width, .height]
        guideView.frame = tv.bounds
        
        // Add as subview of textView
        tv.addSubview(guideView)
        
        // Position at back so text renders on top
        guideView.layer?.zPosition = -1000
        
        self.indentGuideView = guideView
        
        // Set up scroll notification with debouncing
        if let scrollView = tv.enclosingScrollView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(textViewDidScroll),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        scheduleIndentationGuideRefresh(for: tv.string, immediate: true)
    }
    
    private var scrollDebounceTask: Task<Void, Never>?
    
    @objc private func textViewDidScroll() {
        // Gutter must follow scroll without debounce — line numbers feel
        // broken if they lag the cursor. Cheap (one needsDisplay).
        updateGutterScrollOffset()

        scrollDebounceTask?.cancel()
        scrollDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: CodeEditorPerformancePolicy.scrollGuideRefreshDelay)
            guard !Task.isCancelled else { return }
            self?.updateIndentationGuideScrollOffset()
        }
    }

    private func updateIndentationGuides() {
        guard let controller = textController,
              let textView = controller.textView,
              let guideView = indentGuideView else { return }
        
        // Update frame to match parent
        guideView.frame = textView.bounds
        
        let text = textView.string
        
        // Get scroll offset for proper positioning
        var scrollOffset: CGFloat = 0
        if let scrollView = textView.enclosingScrollView {
            scrollOffset = -scrollView.documentVisibleRect.origin.y
        }
        
        // Update the segmented guide with current text and cursor position
        // This parses the text and draws segmented lines per line
        guideView.updateFromText(text, cursorLine: cursorLine, scrollOffset: scrollOffset)
    }

    private func scheduleIndentationGuideRefresh(for text: String, immediate: Bool = false) {
        indentationGuideRefreshTask?.cancel()
        let delay = CodeEditorPerformancePolicy.indentationGuideRefreshDelay(characterCount: text.count)
        indentationGuideRefreshTask = Task { @MainActor [weak self] in
            if !immediate {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            self?.updateIndentationGuides()
        }
    }

    private func updateIndentationGuideScrollOffset() {
        guard let controller = textController,
              let textView = controller.textView,
              let guideView = indentGuideView else { return }

        let scrollOffset: CGFloat
        if let scrollView = textView.enclosingScrollView {
            scrollOffset = -scrollView.documentVisibleRect.origin.y
        } else {
            scrollOffset = 0
        }
        guideView.frame = textView.bounds
        guideView.updateScrollOffset(scrollOffset)
    }

    private func updateActiveIndentationGuideLevel() {
        indentGuideView?.setActiveLine(cursorLine)
    }

    func textViewDidChangeSelection(controller: TextViewController, newPositions: [CursorPosition]) {
        os_signpost(.event, log: Self.perfLog, name: "selectionChanged")
        
        guard let pos = newPositions.first else { return }
        
        // Throttle cursor updates to ~60fps
        let now = Date()
        if now.timeIntervalSince(lastCursorUpdate) >= cursorUpdateThrottle {
            // Immediate update if enough time passed
            cursorLine = pos.start.line
            cursorCol = pos.start.column
            lastCursorUpdate = now
            pendingCursorUpdate = nil
        } else {
            // Queue update
            pendingCursorUpdate = (pos.start.line, pos.start.column)
            cursorUpdateTask?.cancel()
            cursorUpdateTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.cursorUpdateThrottle ?? 0.016 * 1_000_000_000))
                guard !Task.isCancelled, let self = self else { return }
                await MainActor.run {
                    if let pending = self.pendingCursorUpdate {
                        self.cursorLine = pending.line
                        self.cursorCol = pending.col
                        self.pendingCursorUpdate = nil
                    }
                }
            }
        }
        
        // Track selected text for explanation feature
        if let textView = controller.textView {
            let selection = textView.selectedRange()
            if selection.length > 0,
               let selectedRange = Range(selection, in: textView.string) {
                onSelectionChange?(String(textView.string[selectedRange]))
            } else {
                onSelectionChange?("")
            }
        }
        
        // Cursor moves should only retarget the active guide, not reparse the document.
        updateActiveIndentationGuideLevel()
        gutterView?.updateActiveLine(cursorLine)
    }

    func textViewDidChangeText(controller: TextViewController) {
        os_signpost(.begin, log: Self.perfLog, name: "textDidChange")

        let newText = controller.textView.string
        lastText = newText

        // Fast line counting without array allocation
        let lineCount = fastLineCount(newText)
        totalLines = lineCount
        updateGutterLineCount(lineCount)

        // Debounce content change callback (500ms)
        contentChangeTask?.cancel()
        contentChangeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            onContentChange?(newText)
        }

        scheduleIndentationGuideRefresh(for: newText)

        os_signpost(.end, log: Self.perfLog, name: "textDidChange")
    }
    
    /// Fast line count without creating intermediate arrays
    private func fastLineCount(_ text: String) -> Int {
        var count = 1  // Start at 1 for the first line
        let utf8 = text.utf8
        for byte in utf8 {
            if byte == UInt8(ascii: "\n") {
                count += 1
            }
        }
        return count
    }

    func destroy() {
        contentChangeTask?.cancel()
        cursorUpdateTask?.cancel()
        scrollDebounceTask?.cancel()
        indentationGuideRefreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        indentGuideView?.removeFromSuperview()
        gutterView?.removeFromSuperview()
    }
}

// MARK: - Code Inspector Views (Graph Node Preview)
// Lightweight syntax-highlighted views for the graph inspector panel.
// No minimap, no line numbers — just clean colored code.

// NOTE: The old CodeEditorRepresentable, CodeTextView, LineNumberGutter, and MinimapView
// were removed — replaced by the mchakravarty/CodeEditorView SwiftUI package above.
// See git history for the original NSViewRepresentable implementation.

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
/// Optimized for large files with chunked processing and reduced allocations.
enum CodeSyntaxHighlighter {
    
    /// Maximum file size for synchronous processing (larger files use chunked async)
    private static let maxSyncSize = 50000  // 50KB
    
    /// Result from processing a chunk
    private struct ChunkResult: Sendable {
        let index: Int
        let attributes: [TokenAttributes]
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
        let chunks = stride(from: 0, to: text.utf8.count, by: chunkSize).map { start -> (start: Int, end: Int) in
            let end = min(start + chunkSize, text.utf8.count)
            return (start, end)
        }
        
        // Build global UTF-8 to UTF-16 mapping on background thread
        let utf8ToUtf16 = await Task.detached(priority: .utility) {
            buildUTF8ToUTF16Mapping(text: text)
        }.value
        
        // Process chunks sequentially with yielding
        for chunk in chunks {
            // Yield to allow UI updates between chunks
            await Task.yield()
            
            let chunkText = String(text[text.index(text.startIndex, offsetBy: chunk.start)..<text.index(text.startIndex, offsetBy: chunk.end)])
            let tokens = tokenize(text: chunkText, language: language)
            let attrs = computeTokenAttributes(
                tokens: tokens,
                chunkOffset: chunk.start,
                utf8ToUtf16: utf8ToUtf16,
                theme: theme,
                totalLength: (text as NSString).length
            )
            
            storage.beginEditing()
            for attr in attrs {
                storage.addAttribute(.foregroundColor, value: attr.color, range: attr.range)
                if let font = attr.font {
                    storage.addAttribute(.font, value: font, range: attr.range)
                }
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
    
    private struct TokenAttributes: @unchecked Sendable {
        let range: NSRange
        let color: NSColor
        let font: NSFont?
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
    
    private static func computeTokenAttributes(
        tokens: [CodeToken],
        chunkOffset: Int,
        utf8ToUtf16: [Int],
        theme: EpistemosTheme,
        totalLength: Int
    ) -> [TokenAttributes] {
        var attrs: [TokenAttributes] = []
        attrs.reserveCapacity(tokens.count)
        
        for token in tokens {
            let start8 = Int(token.start) + chunkOffset
            let end8 = min(Int(token.end) + chunkOffset, utf8ToUtf16.count - 1)
            guard start8 < utf8ToUtf16.count - 1, start8 < end8 else { continue }
            
            let start16 = utf8ToUtf16[start8]
            let end16 = utf8ToUtf16[end8]
            let range = NSRange(location: start16, length: end16 - start16)
            guard range.location + range.length <= totalLength else { continue }
            
            let color = theme.nsColorForTokenType(token.token_type)
            attrs.append(TokenAttributes(range: range, color: color, font: nil))
        }
        
        return attrs
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
final class CodeContextBridge: ObservableObject {
    
    @Published private(set) var relatedNotes: [CodeSemanticMatch] = []
    @Published private(set) var isSearching = false
    @Published private(set) var lastQuery: String = ""
    @Published private(set) var aiContextSummary: String = ""
    
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
    @StateObject private var bridge: CodeContextBridge
    @StateObject private var insightGenerator: CodeInsightGenerator
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
        self._bridge = StateObject(wrappedValue: bridge ?? CodeContextBridge())
        self._insightGenerator = StateObject(wrappedValue: insightGenerator ?? CodeInsightGenerator())
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
    @ObservedObject var bridge: CodeContextBridge
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
final class CodeInsightGenerator: ObservableObject {
    
    @Published private(set) var insights: [CodeInsight] = []
    @Published private(set) var isGenerating = false
    @Published private(set) var currentAnalysis: String = ""
    
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
    @StateObject private var generator: CodeInsightGenerator
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
        self._generator = StateObject(wrappedValue: generator ?? CodeInsightGenerator())
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
