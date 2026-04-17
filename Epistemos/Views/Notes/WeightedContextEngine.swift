// WeightedContextEngine.swift
//
// Advanced context engine that leverages Epistemos' weighted graph structure
// to provide "uncanny" AI assistance. Uses node weights, complexity scoring,
// and multi-factor relevance to surface the most important information.
//
// This makes the AI feel like it truly understands the codebase depth and
// can prioritize what matters most.
//
// 2026-04-07.

import Foundation
import Accelerate

// MARK: - Weighted Semantic Match

/// A semantic match enhanced with graph weights and complexity scores
struct WeightedSemanticMatch: Identifiable, Comparable {
    let id = UUID()
    let nodeId: String
    let title: String
    let snippet: String
    let semanticScore: Float
    let nodeWeight: Double
    let complexityScore: Double
    let connectionStrength: Double
    let activityScore: Double
    let recencyScore: Double
    let finalScore: Double

    static func < (lhs: WeightedSemanticMatch, rhs: WeightedSemanticMatch) -> Bool {
        lhs.finalScore < rhs.finalScore
    }
}

// MARK: - Code Complexity Analysis

/// Analyzes code complexity to help AI prioritize understanding.
/// Results are cached per (lineCount, contentHash) with 30-second TTL
/// to avoid re-parsing on every analysis cycle for large files.
struct CodeComplexityAnalyzer {

    private static var cache: (key: Int, score: ComplexityScore, expiry: Date)?

    struct ComplexityScore: Sendable {
        let cyclomaticComplexity: Int
        let cognitiveComplexity: Int
        let nestingDepth: Int
        let lineCount: Int
        let functionCount: Int
        let hasAsync: Bool
        let hasConcurrency: Bool
        let hasRecursion: Bool
        let overallScore: Double  // 0.0 to 1.0
    }
    
    static func analyze(code: String, language: String) -> ComplexityScore {
        // Cache check: reuse result if same content within 30s TTL
        let cacheKey = code.hashValue
        if let cached = cache, cached.key == cacheKey, cached.expiry > Date() {
            return cached.score
        }

        let lines = code.components(separatedBy: .newlines)
        let lineCount = lines.count
        
        // Count branches for cyclomatic complexity
        let branchKeywords = ["if", "switch", "for", "while", "guard", "catch", "?:"]
        var branchCount = 0
        var maxNesting = 0
        var currentNesting = 0
        var functionCount = 0
        var hasAsync = false
        var hasConcurrency = false
        var hasRecursion = false
        var currentFunctionName: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Count functions/methods
            if trimmed.contains("func ") || trimmed.contains("def ") {
                functionCount += 1
                currentFunctionName = extractFunctionName(from: trimmed)
            }

            // Check for async/concurrency
            if trimmed.contains("async ") || trimmed.contains("await ") {
                hasAsync = true
            }
            if trimmed.contains("Task ") || trimmed.contains("Actor") || trimmed.contains("Dispatch") {
                hasConcurrency = true
            }

            // Check for recursion: a call to the current function from within its body
            if let funcName = currentFunctionName,
               !trimmed.hasPrefix("func ") && !trimmed.hasPrefix("def ") && !trimmed.hasPrefix("fn "),
               trimmed.contains("\(funcName)(") {
                hasRecursion = true
            }
            
            // Track nesting
            let openBraces = trimmed.filter { "{(".contains($0) }.count
            let closeBraces = trimmed.filter { "})".contains($0) }.count
            currentNesting += openBraces - closeBraces
            maxNesting = max(maxNesting, currentNesting)
            
            // Count branches
            for keyword in branchKeywords {
                if trimmed.hasPrefix(keyword) || trimmed.contains(" \(keyword) ") {
                    branchCount += 1
                }
            }
        }
        
        // Calculate overall complexity score (0.0 to 1.0)
        let cyclomatic = max(1, branchCount)
        let cognitive = min(branchCount + maxNesting, 50)
        
        var score: Double = 0
        score += min(Double(cyclomatic) / 20.0, 0.3)  // Cyclomatic complexity (max 0.3)
        score += min(Double(cognitive) / 30.0, 0.3)   // Cognitive complexity (max 0.3)
        score += min(Double(maxNesting) / 5.0, 0.2)   // Nesting depth (max 0.2)
        score += min(Double(lineCount) / 100.0, 0.1)  // Line count (max 0.1)
        score += hasAsync ? 0.05 : 0
        score += hasConcurrency ? 0.05 : 0
        
        let result = ComplexityScore(
            cyclomaticComplexity: cyclomatic,
            cognitiveComplexity: cognitive,
            nestingDepth: maxNesting,
            lineCount: lineCount,
            functionCount: functionCount,
            hasAsync: hasAsync,
            hasConcurrency: hasConcurrency,
            hasRecursion: hasRecursion,
            overallScore: min(score, 1.0)
        )

        // Cache for 30 seconds
        cache = (key: cacheKey, score: result, expiry: Date().addingTimeInterval(30))
        return result
    }
    
    private static func extractFunctionName(from line: String) -> String? {
        let patterns = [
            "func\\s+(\\w+)",
            "def\\s+(\\w+)",
            "fn\\s+(\\w+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                return String(line[range])
            }
        }
        return nil
    }
}

// MARK: - Weighted Context Engine

/// Advanced context retrieval using weighted graph semantics
@MainActor
final class WeightedContextEngine {
    
    private let graphState: GraphState?
    private let embeddingService: EmbeddingService
    private let metalEngine = MetalComputeEngine.shared

    // Context weight configuration (sums to 1.0)
    var semanticWeight: Double = 0.30
    var nodeWeightFactor: Double = 0.20
    var complexityWeight: Double = 0.15
    var connectionWeight: Double = 0.10
    var activityWeight: Double = 0.15      // User engagement: edits, visits, recency
    var recencyWeight: Double = 0.10

    init(graphState: GraphState?, embeddingService: EmbeddingService? = nil) {
        self.graphState = graphState
        self.embeddingService = embeddingService ?? graphState?.embeddingService ?? EmbeddingService()
    }
    
    // MARK: - Weighted Semantic Search
    
    /// Performs semantic search with full weight analysis
    func weightedSemanticSearch(
        query: String,
        code: String,
        language: String,
        limit: Int = 10,
        precomputedComplexity: CodeComplexityAnalyzer.ComplexityScore? = nil
    ) async -> [WeightedSemanticMatch] {
        guard let graphState = graphState else { return [] }

        guard let queryEmbedding = embeddingService.queryEmbedding(for: query) else {
            return []
        }

        let complexity = precomputedComplexity ?? CodeComplexityAnalyzer.analyze(code: code, language: language)
        
        // Get candidate nodes by semantic similarity to the actual query
        let candidates = graphState.semanticSearch(query: query, limit: 100)
        guard !candidates.isEmpty else { return [] }
        
        // Collect embeddings and metadata
        var documents: [(id: String, embedding: [Float], node: GraphNodeRecord?)] = []
        
        for candidate in candidates {
            if let embedding = embeddingService.embedding(for: candidate.id) {
                let node = graphState.store.node(bySourceId: candidate.id, type: .note) ??
                          graphState.store.nodes[candidate.id]
                documents.append((candidate.id, embedding, node))
            }
        }
        
        guard !documents.isEmpty else { return [] }
        
        // GPU-accelerated similarity
        let documentEmbeddings = documents.map { $0.embedding }
        let similarities = await metalEngine.batchCosineSimilarity(
            query: queryEmbedding,
            documents: documentEmbeddings,
            threshold: 0.2
        )
        
        // Calculate weighted scores
        let now = Date()
        var weightedMatches: [WeightedSemanticMatch] = []
        
        for (index, similarity) in similarities.enumerated() {
            let doc = documents[index]
            let node = doc.node
            
            let semanticScore = Double(similarity)
            let nodeWeight = node?.weight ?? 0.5
            let nodeComplexity = estimateNodeComplexity(node)
            let complexityAlignment = 1.0 - abs(nodeComplexity - complexity.overallScore)
            let connectionStrength = calculateConnectionStrength(nodeId: doc.id)
            let recency = calculateRecency(node: node, now: now)

            // Activity score from user engagement (edits, visits, recency of interaction)
            let activity = calculateActivityScore(sourceId: node?.sourceId)

            let finalScore =
                semanticScore * semanticWeight +
                nodeWeight * nodeWeightFactor +
                complexityAlignment * complexityWeight +
                connectionStrength * connectionWeight +
                activity * activityWeight +
                recency * recencyWeight

            weightedMatches.append(WeightedSemanticMatch(
                nodeId: doc.id,
                title: node?.label ?? "Unknown",
                snippet: node?.metadata.quoteText ?? node?.metadata.abstract ?? "",
                semanticScore: similarity,
                nodeWeight: nodeWeight,
                complexityScore: nodeComplexity,
                connectionStrength: connectionStrength,
                activityScore: activity,
                recencyScore: recency,
                finalScore: finalScore
            ))
        }
        
        // Sort by final score and return top results
        weightedMatches.sort { $0.finalScore > $1.finalScore }
        return Array(weightedMatches.prefix(limit))
    }
    
    // MARK: - Context Assembly
    
    /// Assembles the most relevant context for AI consumption
    func assembleContext(
        for query: String,
        code: String,
        language: String,
        cursorLine: Int,
        precomputedComplexity: CodeComplexityAnalyzer.ComplexityScore? = nil
    ) async -> WeightedContext {
        let complexity = precomputedComplexity ?? CodeComplexityAnalyzer.analyze(code: code, language: language)

        let matches = await weightedSemanticSearch(
            query: query,
            code: code,
            language: language,
            limit: 5,
            precomputedComplexity: complexity
        )
        
        // Extract relevant code context around cursor
        let codeContext = extractCodeContext(code: code, aroundLine: cursorLine)
        
        // Build context summary
        let summary = ContextSummary(
            complexity: complexity,
            topMatches: matches,
            totalWeight: matches.reduce(0) { $0 + $1.nodeWeight },
            averageRelevance: matches.isEmpty ? 0 : matches.map { $0.finalScore }.reduce(0, +) / Double(matches.count)
        )
        
        return WeightedContext(
            query: query,
            codeContext: codeContext,
            matches: matches,
            summary: summary,
            complexity: complexity
        )
    }
    
    // MARK: - Helper Methods
    
    private func estimateNodeComplexity(_ node: GraphNodeRecord?) -> Double {
        guard let node = node else { return 0.5 }
        
        // Estimate based on metadata and weight
        var score = node.weight  // Base on node weight
        
        // Boost for nodes with substantial content
        let contentLength = node.metadata.quoteText?.count ?? node.metadata.abstract?.count ?? 0
        score += min(Double(contentLength) / 1000.0, 0.2)
        
        // Boost for research-grade nodes
        if node.metadata.evidenceGrade != nil {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    private func calculateConnectionStrength(nodeId: String) -> Double {
        guard let graphState = graphState else { return 0.5 }

        // O(1) lookup via adjacency index instead of O(edges) linear scan
        let neighborCount = graphState.store.adjacency[nodeId]?.count ?? 0
        return min(Double(neighborCount) / 20.0, 1.0)
    }
    
    private func calculateActivityScore(sourceId: String?) -> Double {
        guard let sourceId = sourceId,
              let tracker = AppBootstrap.shared?.activityTracker else { return 0 }
        return tracker.activityScore(for: sourceId)
    }

    private func calculateRecency(node: GraphNodeRecord?, now: Date) -> Double {
        guard let node = node else { return 0.5 }
        
        let age = now.timeIntervalSince(node.updatedAt)
        let days = age / (24 * 3600)
        
        // Exponential decay over 30 days
        return exp(-days / 30.0)
    }
    
    private func extractCodeContext(code: String, aroundLine: Int) -> String {
        let lines = code.components(separatedBy: .newlines)
        let start = max(0, aroundLine - 15)
        let end = min(lines.count, aroundLine + 15)
        return lines[start..<end].joined(separator: "\n")
    }
}

// MARK: - Weighted Context

/// Complete weighted context for AI consumption
struct WeightedContext {
    let query: String
    let codeContext: String
    let matches: [WeightedSemanticMatch]
    let summary: ContextSummary
    let complexity: CodeComplexityAnalyzer.ComplexityScore
    
    /// Formats context for AI prompt
    func formatForPrompt() -> String {
        var sections: [String] = []
        
        // Complexity context
        sections.append("""
        Code Complexity Analysis:
        - Overall Score: \(complexity.overallScore.isFinite ? Int(complexity.overallScore * 100) : 0)%
        - Cyclomatic Complexity: \(complexity.cyclomaticComplexity)
        - Cognitive Complexity: \(complexity.cognitiveComplexity)
        - Nesting Depth: \(complexity.nestingDepth)
        - Functions: \(complexity.functionCount)
        \(complexity.hasAsync ? "- Uses Async/Await" : "")
        \(complexity.hasConcurrency ? "- Has Concurrency" : "")
        \(complexity.hasRecursion ? "- Contains Recursion" : "")
        """)
        
        // Vault context with weights
        if !matches.isEmpty {
            sections.append("Relevant Context from Vault (weighted by importance):")
            for (index, match) in matches.enumerated() {
                let relevanceBar = String(repeating: "█", count: match.finalScore.isFinite ? Int(match.finalScore * 10) : 0)
                sections.append("""
                [\(index + 1)] \(match.title) \(relevanceBar)
                Relevance: \(match.finalScore.isFinite ? Int(match.finalScore * 100) : 0)% |
                Node Weight: \(match.nodeWeight.isFinite ? Int(match.nodeWeight * 100) : 0)% |
                Semantic: \(match.semanticScore.isFinite ? Int(match.semanticScore * 100) : 0)%
                \(match.snippet.prefix(200))
                """)
            }
        }
        
        return sections.joined(separator: "\n\n")
    }
    
    /// Gets complexity-aware routing recommendation
    var routingRecommendation: RoutingRecommendation {
        if complexity.overallScore > 0.8 {
            return .deepAnalysis
        } else if complexity.overallScore > 0.5 {
            return .standard
        } else {
            return .quickSuggestion
        }
    }
    
    enum RoutingRecommendation {
        case quickSuggestion
        case standard
        case deepAnalysis
        
        var modelPreference: String {
            switch self {
            case .quickSuggestion: return "Apple Intelligence"
            case .standard: return "Hybrid"
            case .deepAnalysis: return "Qwen 4B"
            }
        }
    }
}

struct ContextSummary {
    let complexity: CodeComplexityAnalyzer.ComplexityScore
    let topMatches: [WeightedSemanticMatch]
    let totalWeight: Double
    let averageRelevance: Double
}

// MARK: - Preview Helpers

extension WeightedContext {
    static var preview: WeightedContext {
        WeightedContext(
            query: "How to optimize this?",
            codeContext: "func process() { ... }",
            matches: [
                WeightedSemanticMatch(
                    nodeId: "1",
                    title: "GPU Optimization Patterns",
                    snippet: "Use Accelerate framework for vector operations...",
                    semanticScore: 0.92,
                    nodeWeight: 0.95,
                    complexityScore: 0.75,
                    connectionStrength: 0.8,
                    activityScore: 0.7,
                    recencyScore: 0.9,
                    finalScore: 0.89
                ),
                WeightedSemanticMatch(
                    nodeId: "2",
                    title: "Metal Performance Tips",
                    snippet: "Batch operations for GPU efficiency...",
                    semanticScore: 0.85,
                    nodeWeight: 0.88,
                    complexityScore: 0.9,
                    connectionStrength: 0.7,
                    activityScore: 0.5,
                    recencyScore: 0.85,
                    finalScore: 0.84
                )
            ],
            summary: ContextSummary(
                complexity: CodeComplexityAnalyzer.ComplexityScore(
                    cyclomaticComplexity: 8,
                    cognitiveComplexity: 12,
                    nestingDepth: 3,
                    lineCount: 45,
                    functionCount: 3,
                    hasAsync: true,
                    hasConcurrency: true,
                    hasRecursion: false,
                    overallScore: 0.65
                ),
                topMatches: [],
                totalWeight: 1.83,
                averageRelevance: 0.87
            ),
            complexity: CodeComplexityAnalyzer.ComplexityScore(
                cyclomaticComplexity: 8,
                cognitiveComplexity: 12,
                nestingDepth: 3,
                lineCount: 45,
                functionCount: 3,
                hasAsync: true,
                hasConcurrency: true,
                hasRecursion: false,
                overallScore: 0.65
            )
        )
    }
}
