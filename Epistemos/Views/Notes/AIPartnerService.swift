// AIPartnerService.swift
//
// Enhanced AI Coding Partner that feels like a living specialist working alongside you.
// Leverages Epistemos' unique graph architecture, semantic search, and comprehensive logging.
//
// Features:
// - Inline suggestions with ghost text rendering
// - Context highlighting showing what the AI "sees"
// - Retro-styled response boxes
// - Granular frequency/depth controls with presets
// - Full integration with vault graph and semantic memory
//
// 2026-04-07.

import SwiftUI
import SwiftData
import Combine
import os.log

// MARK: - AI Partner Service

@MainActor
@Observable
final class AIPartnerService {

    // MARK: - Observable State

    var configuration: AIPartnerConfiguration = .default
    var isEnabled: Bool = true
    var isAnalyzing: Bool = false
    var currentSuggestion: InlineSuggestion?
    var activeContextHighlights: [ContextHighlight] = []
    var partnerStatus: PartnerStatus = .idle
    var retroResponse: RetroResponse?

    // Weighted context insights
    var currentComplexity: CodeComplexityAnalyzer.ComplexityScore?
    var topWeightedMatches: [WeightedSemanticMatch] = []
    var contextInsights: ContextInsights?
    
    enum PartnerStatus: String {
        case idle = "Idle"
        case reading = "Reading Context"
        case analyzing = "Analyzing Complexity"
        case weighting = "Weighting Graph"
        case suggesting = "Synthesizing"
        case learning = "Learning"
        
        var icon: String {
            switch self {
            case .idle: return "brain.head.profile"
            case .reading: return "eye"
            case .analyzing: return "brain"
            case .weighting: return "point.3.connected.trianglepath.dotted"
            case .suggesting: return "lightbulb"
            case .learning: return "book.closed"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .secondary
            case .reading: return .blue
            case .analyzing: return .orange
            case .weighting: return .purple
            case .suggesting: return .green
            case .learning: return .pink
            }
        }
    }
    
    struct ContextInsights {
        let totalNodeWeight: Double
        let averageRelevance: Double
        let complexityTier: String
        let recommendedModel: String
        let keyPatterns: [String]
    }
    
    struct RetroResponse: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let actions: [RetroAIResponseBox.AIResponseAction]
    }
    
    struct ContextHighlight: Identifiable, Equatable {
        let id = UUID()
        let range: NSRange
        let color: Color
        let label: String
        let source: String
        let weight: Double  // NEW: Weight for visual intensity
    }
    
    // MARK: - Services
    
    private let triageService: TriageService?
    private let graphState: GraphState?
    private let metalEngine = MetalComputeEngine.shared
    private let embeddingService: EmbeddingService
    private let analysisQueue = AnalysisQueue.shared
    private let logger = Logger(subsystem: "app.epistemos", category: "AIPartner")

    private var weightedContextEngine: WeightedContextEngine?
    
    // MARK: - State

    private var currentCode: String = ""
    private var currentLines: [String] = []  // Cached line split — invalidated on code change
    private var currentLanguage: String = ""
    private var currentFilePath: String?
    private var cursorPosition: CursorPosition = .zero
    private var lastAnalysisTime: Date = .distantPast
    private var analysisTask: Task<Void, Never>?
    private var highlightRefreshTask: Task<Void, Never>?
    private var periodicTimer: Timer?
    private var suggestionQueue: [InlineSuggestion] = []
    
    struct CursorPosition {
        let line: Int
        let column: Int
        let absolutePosition: Int
        
        static let zero = CursorPosition(line: 1, column: 1, absolutePosition: 0)
    }
    
    // MARK: - Logging
    
    private var interactionLog: [PartnerInteraction] = []
    
    struct PartnerInteraction: Codable {
        let timestamp: Date
        let type: InteractionType
        let codeSnippet: String
        let suggestion: String?
        let contextUsed: ContextUsed
        let performance: PerformanceMetrics
        
        enum InteractionType: String, Codable {
            case suggestionGenerated
            case suggestionAccepted
            case suggestionDismissed
            case contextRead
            case insightProvided
        }
        
        struct ContextUsed: Codable {
            let semanticMatches: Int
            let graphNodesAccessed: Int
            let recentEditLines: Int
            let totalContextTokens: Int
            let totalNodeWeight: Double  // NEW
            let complexityScore: Double  // NEW
        }
        
        struct PerformanceMetrics: Codable {
            let analysisDurationMs: Double
            let semanticSearchDurationMs: Double
            let gpuUtilized: Bool
        }
    }
    
    // MARK: - Initialization
    
    init(triageService: TriageService?, graphState: GraphState?) {
        self.triageService = triageService
        self.graphState = graphState
        let svc = graphState?.embeddingService ?? EmbeddingService()
        self.embeddingService = svc
        self.weightedContextEngine = WeightedContextEngine(graphState: graphState, embeddingService: svc)
    }
    
    // MARK: - Session Management
    
    func startSession(code: String, language: String, filePath: String?) {
        guard isEnabled else { return }

        currentCode = code
        currentLines = code.components(separatedBy: .newlines)
        currentLanguage = language
        currentFilePath = filePath
        
        logger.info("🤖 AI Partner session started for \(language)")
        
        // Initial analysis
        scheduleAnalysis()
        
        // Start periodic analysis based on configuration
        schedulePeriodicAnalysis()
    }
    
    func updateCode(_ code: String, cursorLine: Int, cursorColumn: Int) {
        // Content hash guard: skip expensive re-split if code hasn't changed
        let hash = code.hashValue
        if hash != currentCode.hashValue || currentLines.isEmpty {
            currentCode = code
            currentLines = code.components(separatedBy: .newlines)
        }
        cursorPosition = CursorPosition(
            line: cursorLine,
            column: cursorColumn,
            absolutePosition: positionFromLineColumn(line: cursorLine, column: cursorColumn)
        )
        
        // Update context highlights based on new position
        updateContextHighlights()
        
        // Debounced analysis for proactive mode
        if configuration.mode == .manual || configuration.suggestionFrequency != .calm {
            scheduleAnalysis()
        }
    }
    
    func endSession() {
        periodicTimer?.invalidate()
        periodicTimer = nil
        analysisTask?.cancel()
        highlightRefreshTask?.cancel()
        
        // Save interaction log
        saveInteractionLog()
        
        logger.info("🤖 AI Partner session ended. Interactions: \(self.interactionLog.count)")
        
        currentSuggestion = nil
        activeContextHighlights.removeAll()
    }
    
    // MARK: - Analysis Pipeline
    
    private func schedulePeriodicAnalysis() {
        periodicTimer?.invalidate()
        guard isEnabled else { return }
        
        let interval = configuration.suggestionFrequency.interval
        guard interval > 0 else { return }
        
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAnalysis()
            }
        }
    }
    
    private func scheduleAnalysis() {
        analysisTask?.cancel()
        
        let debounceInterval: TimeInterval = configuration.suggestionFrequency == .aggressive ? 0.5 : 1.5
        
        analysisTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await performAnalysis()
        }
    }
    
    private func performAnalysis() async {
        guard !isAnalyzing else { return }
        guard triageService != nil else { return }
        
        isAnalyzing = true
        partnerStatus = .reading
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isAnalyzing = false
            partnerStatus = .idle
        }
        
        // Phase 1: Gather context (with highlighting)
        await gatherAndHighlightContext()
        
        partnerStatus = .analyzing
        
        // NEW: Analyze complexity
        let complexity = CodeComplexityAnalyzer.analyze(code: currentCode, language: currentLanguage)
        currentComplexity = complexity
        
        partnerStatus = .weighting
        
        // Phase 2: Weighted semantic search with GPU acceleration

        // Use weighted context engine for uncanny understanding
        let weightedContext = await weightedContextEngine?.assembleContext(
            for: "code analysis",
            code: currentCode,
            language: currentLanguage,
            cursorLine: cursorPosition.line,
            precomputedComplexity: complexity
        )
        
        // Update published weighted matches
        if let matches = weightedContext?.matches {
            topWeightedMatches = matches

            let totalWeight = matches.reduce(0) { $0 + $1.nodeWeight }
            let avgRelevance = matches.isEmpty ? 0 : matches.map { $0.finalScore }.reduce(0, +) / Double(matches.count)

            contextInsights = ContextInsights(
                totalNodeWeight: totalWeight,
                averageRelevance: avgRelevance,
                complexityTier: complexityTier(for: complexity.overallScore),
                recommendedModel: weightedContext?.routingRecommendation.modelPreference ?? "Standard",
                keyPatterns: Array(matches.map { $0.title }.prefix(3))
            )
        }
        
        // Phase 3: Generate suggestions based on weighted context
        partnerStatus = .suggesting
        
        let codeContext = extractRelevantCodeContext()

        // Use WeightedContext's own prompt formatting + code context
        var promptSections = [String]()
        if let ctx = weightedContext {
            promptSections.append(ctx.formatForPrompt())
        }
        promptSections.append("Current Code Context:\n```\(currentLanguage)\n\(codeContext)\n```")
        promptSections.append("Provide a concise suggestion based on the complexity and weighted context above.")
        let prompt = promptSections.joined(separator: "\n\n")
        
        do {
            let suggestion = try await generateWeightedSuggestion(
                prompt: prompt,
                codeContext: codeContext,
                weightedContext: weightedContext,
                complexity: complexity,
                analysisDuration: (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            )
            
            if let suggestion = suggestion {
                if suggestionQueue.count < configuration.maxConcurrentSuggestions {
                    suggestionQueue.append(suggestion)
                    showNextSuggestion()
                }
            }
        } catch {
            logger.error("Failed to generate suggestion: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Context Gathering & Highlighting
    
    private func gatherAndHighlightContext() async {
        guard configuration.showContextHighlights else {
            activeContextHighlights = []
            return
        }

        var highlights: [ContextHighlight] = []
        
        // Highlight 1: Current cursor line (high weight - primary focus)
        let cursorLineRange = rangeForLine(cursorPosition.line)
        highlights.append(ContextHighlight(
            range: cursorLineRange,
            color: .blue,
            label: "cursor",
            source: "editor",
            weight: 1.0
        ))
        
        // Highlight 2: Recent edit area (medium weight)
        let contextLines = configuration.contextWindowSize.linesBefore
        let startLine = max(1, cursorPosition.line - contextLines)
        let endLine = min(totalLines(), cursorPosition.line + configuration.contextWindowSize.linesAfter)
        
        let contextRange = NSRange(
            location: positionFromLineColumn(line: startLine, column: 1),
            length: positionFromLineColumn(line: endLine, column: 1) - positionFromLineColumn(line: startLine, column: 1)
        )
        
        highlights.append(ContextHighlight(
            range: contextRange,
            color: .green,
            label: "context",
            source: "window",
            weight: 0.6
        ))
        
        // Highlight 3: Weighted vault matches (if available)
        for match in topWeightedMatches.prefix(3) {
            // Try to find corresponding code lines
            if let lineRange = findCodeRangeForMatch(match) {
                highlights.append(ContextHighlight(
                    range: lineRange,
                    color: .purple,
                    label: match.title,
                    source: "vault (\(Int(match.finalScore * 100))%)",
                    weight: match.finalScore
                ))
            }
        }
        
        activeContextHighlights = highlights
    }
    
    private func findCodeRangeForMatch(_ match: WeightedSemanticMatch) -> NSRange? {
        let lines = currentLines
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Simple heuristic: match keywords from title
            let keywords = match.title.lowercased().components(separatedBy: .whitespacesAndNewlines)
            let lineLower = trimmed.lowercased()
            
            let matchCount = keywords.filter { lineLower.contains($0) && $0.count > 2 }.count
            if matchCount >= 1 {
                let position = positionFromLineColumn(line: index + 1, column: 1)
                return NSRange(location: position, length: line.count)
            }
        }
        
        return nil
    }
    
    private func updateContextHighlights() {
        guard configuration.showContextHighlights else {
            highlightRefreshTask?.cancel()
            activeContextHighlights = []
            return
        }

        highlightRefreshTask?.cancel()
        highlightRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await gatherAndHighlightContext()
        }
    }
    
    // MARK: - Suggestion Generation

    private func parseSuggestionType(from response: String) -> (InlineSuggestion.SuggestionType, String) {
        let lower = response.lowercased()
        
        if lower.contains("replace") || lower.contains("change") {
            return (.replacement, response)
        } else if lower.contains("add") || lower.contains("insert") {
            return (.insertion, response)
        } else if lower.contains("refactor") || lower.contains("restructure") {
            return (.refactor, response)
        } else if response.components(separatedBy: .newlines).count > 3 {
            return (.multiLine, response)
        } else {
            return (.completion, response)
        }
    }
    
    private func calculateConfidence(semanticScore: Float, response: String) -> Double {
        var confidence = Double(semanticScore) * configuration.semanticWeight
        
        // Boost for code blocks
        if response.contains("```") {
            confidence += 0.1
        }
        
        // Boost for specific suggestions
        if response.contains("func ") || response.contains("class ") || response.contains("struct ") {
            confidence += 0.05
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Suggestion Management
    
    private func showNextSuggestion() {
        guard suggestionQueue.isEmpty == false else { return }
        
        currentSuggestion = suggestionQueue.removeFirst()
        
        // Show retro response if enabled
        if configuration.useRetroStyling, let suggestion = currentSuggestion {
            showRetroResponse(for: suggestion)
        }
    }
    
    private func showRetroResponse(for suggestion: InlineSuggestion) {
        let actions = [
            RetroAIResponseBox.AIResponseAction(
                id: "accept",
                title: "Accept",
                icon: "checkmark",
                handler: { [weak self] in self?.acceptCurrentSuggestion() }
            ),
            RetroAIResponseBox.AIResponseAction(
                id: "dismiss",
                title: "Dismiss",
                icon: "xmark",
                handler: { [weak self] in self?.dismissCurrentSuggestion() }
            ),
            RetroAIResponseBox.AIResponseAction(
                id: "explain",
                title: "Explain",
                icon: "text.bubble",
                handler: { [weak self] in self?.explainCurrentSuggestion() }
            )
        ]
        
        retroResponse = RetroResponse(
            title: "AI PARTNER — \(suggestion.type.description.uppercased())",
            content: suggestion.text,
            actions: actions
        )
    }
    
    func acceptCurrentSuggestion() {
        guard let suggestion = currentSuggestion else { return }

        logInteraction(
            type: .suggestionAccepted,
            codeSnippet: "",
            suggestion: suggestion.text,
            semanticMatches: suggestion.context.relatedNoteIds.count,
            graphNodes: 0,
            analysisDuration: 0,
            semanticDuration: 0
        )

        persistSuggestionExchange(suggestion: suggestion, accepted: true)

        currentSuggestion = nil
        retroResponse = nil

        if !suggestionQueue.isEmpty {
            showNextSuggestion()
        }
    }
    
    func dismissCurrentSuggestion() {
        guard let suggestion = currentSuggestion else { return }
        
        logInteraction(
            type: .suggestionDismissed,
            codeSnippet: "",
            suggestion: suggestion.text,
            semanticMatches: suggestion.context.relatedNoteIds.count,
            graphNodes: 0,
            analysisDuration: 0,
            semanticDuration: 0
        )
        
        currentSuggestion = nil
        retroResponse = nil
        
        // Show next if available
        if !suggestionQueue.isEmpty {
            showNextSuggestion()
        }
    }
    
    func explainCurrentSuggestion() {
        // TODO: Implement detailed explanation generation
    }
    
    // MARK: - Utility
    
    private func extractRelevantCodeContext() -> String {
        let lines = currentLines
        let startLine = max(0, cursorPosition.line - configuration.contextWindowSize.linesBefore - 1)
        let endLine = min(lines.count, cursorPosition.line + configuration.contextWindowSize.linesAfter - 1)
        
        return lines[startLine..<endLine].joined(separator: "\n")
    }
    
    private func positionFromLineColumn(line: Int, column: Int) -> Int {
        let lines = currentLines
        var position = 0
        
        for i in 0..<min(line - 1, lines.count) {
            position += lines[i].count + 1 // +1 for newline
        }
        
        return position + column - 1
    }
    
    private func rangeForLine(_ line: Int) -> NSRange {
        let position = positionFromLineColumn(line: line, column: 1)
        let lineLength = currentLines[safe: line - 1]?.count ?? 0
        return NSRange(location: position, length: lineLength)
    }
    
    private func totalLines() -> Int {
        currentLines.count
    }
    
    // MARK: - Chat Persistence (Unification)

    /// Persists an AI partner suggestion exchange to SDChat.
    private func persistSuggestionExchange(suggestion: InlineSuggestion, accepted: Bool) {
        guard let ctx = AppBootstrap.shared?.modelContainer.mainContext else { return }

        let action = accepted ? "Accepted" : "Dismissed"
        let chat = SDChat(title: "\(action) AI suggestion (\(currentLanguage))", chatType: "aiPartner")

        // Resolve filePath → pageId for proper graph association
        if let path = currentFilePath {
            let targetPath = path
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate { $0.filePath == targetPath }
            )
            chat.linkedPageId = (try? ctx.fetch(descriptor).first)?.id
        }
        ctx.insert(chat)

        // Store the code context as the "user" message
        let contextSnippet = extractRelevantCodeContext()
        let userMsg = SDMessage(role: "user", content: "[\(currentLanguage)] \(contextSnippet.prefix(500))")
        userMsg.chat = chat
        ctx.insert(userMsg)

        // Store the suggestion as the "assistant" message
        let assistantMsg = SDMessage(role: "assistant", content: suggestion.text)
        assistantMsg.chat = chat
        ctx.insert(assistantMsg)

        do { try ctx.save() } catch {
            logger.error("AI partner persistence failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Logging

    private func saveInteractionLog() {
        // Persist to disk for analysis
        do {
            let data = try JSONEncoder().encode(interactionLog)
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Epistemos")
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let url = appSupport.appendingPathComponent("ai_partner_log.json")
            try data.write(to: url)
        } catch {
            logger.error("Failed to save interaction log: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Weighted Context Helpers
    
    private func complexityTier(for score: Double) -> String {
        if score > 0.8 { return "High" }
        if score > 0.5 { return "Medium" }
        return "Low"
    }
    
    private func generateWeightedSuggestion(
        prompt: String,
        codeContext: String,
        weightedContext: WeightedContext?,
        complexity: CodeComplexityAnalyzer.ComplexityScore,
        analysisDuration: Double
    ) async throws -> InlineSuggestion? {
        guard let triageService = triageService else { return nil }
        
        // Route based on complexity
        let operation: NotesOperation = complexity.overallScore > 0.7
            ? .ask(query: "complex code analysis")
            : .ask(query: "code suggestion")
        
        let response = try await triageService.generate(
            prompt: prompt,
            systemPrompt: """
            You are an expert coding assistant with deep codebase understanding.
            Consider the complexity metrics and weighted vault context provided.
            Be specific and reference relevant patterns from the vault when applicable.
            """,
            operation: operation,
            contentLength: prompt.count
        )
        
        // Parse suggestion type from response
        let (type, cleanText) = parseSuggestionType(from: response)
        
        // Calculate confidence based on weighted scores
        let avgRelevance = weightedContext?.matches.prefix(3).map { $0.finalScore }.reduce(0, +) ?? 0
        let normalizedRelevance = avgRelevance / 3.0
        let confidence = min(normalizedRelevance + 0.2, 1.0)
        
        let suggestion = InlineSuggestion(
            text: cleanText,
            type: type,
            range: nil,
            confidence: confidence,
            context: InlineSuggestion.SuggestionContext(
                relatedNoteIds: weightedContext?.matches.map { $0.nodeId } ?? [],
                semanticScore: Float(normalizedRelevance),
                contextLines: codeContext.components(separatedBy: .newlines),
                source: "AI Partner (Weighted)"
            )
        )
        
        // Log with weighted context info
        logInteraction(
            type: .suggestionGenerated,
            codeSnippet: codeContext,
            suggestion: cleanText,
            semanticMatches: weightedContext?.matches.count ?? 0,
            graphNodes: weightedContext?.matches.count ?? 0,
            analysisDuration: analysisDuration,
            semanticDuration: 0,
            totalNodeWeight: weightedContext?.summary.totalWeight ?? 0,
            complexityScore: complexity.overallScore
        )
        
        return suggestion
    }
    
    // Updated logInteraction with weighted params
    private func logInteraction(
        type: PartnerInteraction.InteractionType,
        codeSnippet: String,
        suggestion: String?,
        semanticMatches: Int,
        graphNodes: Int,
        analysisDuration: Double,
        semanticDuration: Double,
        totalNodeWeight: Double = 0,
        complexityScore: Double = 0
    ) {
        let interaction = PartnerInteraction(
            timestamp: Date(),
            type: type,
            codeSnippet: String(codeSnippet.prefix(200)),
            suggestion: suggestion?.prefix(500).description,
            contextUsed: PartnerInteraction.ContextUsed(
                semanticMatches: semanticMatches,
                graphNodesAccessed: graphNodes,
                recentEditLines: configuration.contextWindowSize.linesBefore + configuration.contextWindowSize.linesAfter,
                totalContextTokens: codeSnippet.count / 4,
                totalNodeWeight: totalNodeWeight,
                complexityScore: complexityScore
            ),
            performance: PartnerInteraction.PerformanceMetrics(
                analysisDurationMs: analysisDuration,
                semanticSearchDurationMs: semanticDuration,
                gpuUtilized: true
            )
        )
        
        interactionLog.append(interaction)
        
        if interactionLog.count > 1000 {
            interactionLog.removeFirst(interactionLog.count - 1000)
        }
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
