import Foundation
import Observation
import os

// MARK: - Configuration

struct ReasoningLoopConfig: Sendable {
    var enabled: Bool = false
    var qualityThreshold: Double = 0.7
    var maxRounds: Int = 5
    var enableToolUse: Bool = true
    /// Minimum operation complexity to engage reasoning (skip simple transforms).
    var minComplexity: Double = 0.40
}

// MARK: - Round Record

struct ReasoningRound: Sendable {
    let roundIndex: Int
    let thinkOutput: String
    let critiqueOutput: String
    let qualityScore: Double
    let toolCalls: [ToolCallRecord]
    let refinedOutput: String
    let durationMs: UInt64
}

struct ToolCallRecord: Sendable {
    let toolName: String
    let query: String
    let result: String
    let durationMs: UInt64
}

// MARK: - ReasoningLoopService

/// Recursive inference-time reasoning loop.
///
/// Wraps TriageService with a THINK → CRITIQUE → ACT → REFINE → EVALUATE cycle.
/// Internal rounds are non-streaming; only the final refined answer streams to the user.
/// Every successful chain becomes ODIA training data via `onTracesGenerated`.
///
/// Complexity gate: engages for inherently complex operations and for ask-style queries
/// whose analyzed query complexity pushes them above the configured threshold.
/// Low-complexity operations (rewrite, summarize, grammar fix) pass through directly.
@MainActor @Observable
final class ReasoningLoopService {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "ReasoningLoop")

    var config = ReasoningLoopConfig()
    private(set) var isReasoning = false
    private(set) var currentRound = 0
    private(set) var totalRoundsLastQuery = 0

    /// Callback to deliver JSONL reasoning traces to TrainingScheduler.
    var onTracesGenerated: (([String]) -> Void)?

    @ObservationIgnored
    private let triageService: TriageService

    @ObservationIgnored
    private let traceLogger = ReasoningTraceLogger()

    init(triageService: TriageService) {
        self.triageService = triageService
    }

    // MARK: - Public API

    /// Stream with optional recursive reasoning.
    /// Drop-in replacement for `triageService.stream()` — same return type.
    func streamWithReasoning(
        prompt: String,
        systemPrompt: String? = nil,
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil,
        operatingMode: EpistemosOperatingMode = .fast
    ) -> AsyncThrowingStream<String, Error> {
        // Fast path: skip reasoning for simple operations or when disabled
        guard shouldEngageReasoning(
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: operatingMode
        ) else {
            return triageService.stream(
                prompt: prompt,
                systemPrompt: systemPrompt,
                operation: operation,
                contentLength: contentLength,
                query: query,
                operatingMode: operatingMode
            )
        }

        return AsyncThrowingStream { continuation in
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    self.isReasoning = true
                    self.currentRound = 0
                    defer {
                        self.isReasoning = false
                        self.currentRound = 0
                    }

                    let startTime = ContinuousClock.now

                    // Run internal reasoning rounds (non-streaming)
                    let (bestAnswer, rounds) = try await self.runInternalRounds(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        operation: operation,
                        contentLength: contentLength,
                        operatingMode: operatingMode
                    )

                    self.totalRoundsLastQuery = rounds.count
                    let totalMs = UInt64(startTime.duration(to: .now).components.attoseconds / 1_000_000_000_000)

                    // Log traces for ODIA training
                    let traces = self.traceLogger.logReasoningChain(
                        query: prompt,
                        rounds: rounds,
                        finalAnswer: bestAnswer,
                        totalDurationMs: totalMs
                    )
                    if !traces.isEmpty {
                        self.onTracesGenerated?(traces)
                        self.log.info("Reasoning: \(rounds.count) rounds, \(traces.count) traces logged")
                    }

                    // Stream the final polished answer to the user
                    let finalStream = self.triageService.stream(
                        prompt: self.buildFinalAnswerPrompt(reasoning: bestAnswer, query: prompt),
                        systemPrompt: systemPrompt,
                        operation: operation,
                        contentLength: contentLength,
                        query: query,
                        operatingMode: operatingMode
                    )

                    for try await chunk in finalStream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func shouldEngageReasoning(
        operation: NotesOperation,
        contentLength: Int,
        query: String?,
        operatingMode: EpistemosOperatingMode = .fast
    ) -> Bool {
        guard config.enabled else { return false }
        guard operatingMode != .fast else { return false }
        return effectiveComplexity(operation: operation, contentLength: contentLength, query: query)
            >= config.minComplexity
    }

    func effectiveComplexity(
        operation: NotesOperation,
        contentLength: Int,
        query: String?
    ) -> Double {
        _ = contentLength
        let base = operation.baseComplexity

        guard case .ask = operation,
              let query,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }

        let analysis = QueryAnalyzer.analyze(query: query)
        return min(1.0, base + analysis.complexity)
    }

    // MARK: - Internal Reasoning Loop

    private func runInternalRounds(
        prompt: String,
        systemPrompt: String?,
        operation: NotesOperation,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode
    ) async throws -> (answer: String, rounds: [ReasoningRound]) {
        var rounds: [ReasoningRound] = []
        var bestAnswer = ""
        var bestScore = 0.0

        for roundIdx in 0..<config.maxRounds {
            let roundStart = ContinuousClock.now
            currentRound = roundIdx + 1

            // THINK — initial or refined reasoning
            let thinkPrompt: String
            if roundIdx == 0 {
                thinkPrompt = buildThinkPrompt(query: prompt, systemPrompt: systemPrompt)
            } else {
                let prevRound = rounds[roundIdx - 1]
                thinkPrompt = buildRefinePrompt(
                    previousThinking: prevRound.refinedOutput.isEmpty ? prevRound.thinkOutput : prevRound.refinedOutput,
                    toolResults: prevRound.toolCalls.map { "\($0.toolName): \($0.result)" }.joined(separator: "\n"),
                    query: prompt,
                    systemPrompt: systemPrompt
                )
            }

            let thinkOutput = try await triageService.generate(
                prompt: thinkPrompt,
                systemPrompt: nil,
                operation: operation,
                contentLength: contentLength,
                operatingMode: operatingMode
            )

            log.debug("Reasoning round \(roundIdx + 1) THINK: \(thinkOutput.prefix(200))")

            // CRITIQUE — self-evaluate
            let critiquePrompt = buildCritiquePrompt(thinking: thinkOutput, query: prompt)
            let critiqueOutput = try await triageService.generate(
                prompt: critiquePrompt,
                systemPrompt: nil,
                operation: operation,
                contentLength: contentLength,
                operatingMode: operatingMode
            )

            let score = parseQualityScore(from: critiqueOutput)
            log.info("Reasoning round \(roundIdx + 1) score: \(String(format: "%.2f", score))")

            // ACT — execute tool calls if critique suggests them
            var toolCallRecords: [ToolCallRecord] = []
            if config.enableToolUse {
                let parsedCalls = ToolCallParser.parse(critiqueOutput)
                for call in parsedCalls {
                    let toolStart = ContinuousClock.now
                    let result = await executeReasoningToolCall(call)
                    let toolMs = UInt64(toolStart.duration(to: .now).components.attoseconds / 1_000_000_000_000)
                    toolCallRecords.append(ToolCallRecord(
                        toolName: call.name,
                        query: call.argumentsJson,
                        result: result,
                        durationMs: toolMs
                    ))
                }
            }

            // Build refined output if we have tool results
            var refinedOutput = ""
            if !toolCallRecords.isEmpty {
                let refinePrompt = buildRefinePrompt(
                    previousThinking: thinkOutput,
                    toolResults: toolCallRecords.map { "\($0.toolName): \($0.result)" }.joined(separator: "\n"),
                    query: prompt,
                    systemPrompt: systemPrompt
                )
                refinedOutput = try await triageService.generate(
                    prompt: refinePrompt,
                    systemPrompt: nil,
                    operation: operation,
                    contentLength: contentLength,
                    operatingMode: operatingMode
                )
            }

            let roundMs = UInt64(roundStart.duration(to: .now).components.attoseconds / 1_000_000_000_000)

            let round = ReasoningRound(
                roundIndex: roundIdx,
                thinkOutput: thinkOutput,
                critiqueOutput: critiqueOutput,
                qualityScore: score,
                toolCalls: toolCallRecords,
                refinedOutput: refinedOutput,
                durationMs: roundMs
            )
            rounds.append(round)

            // Track best answer
            let currentAnswer = refinedOutput.isEmpty ? thinkOutput : refinedOutput
            if score > bestScore {
                bestScore = score
                bestAnswer = currentAnswer
            }

            // Early exit if quality is sufficient
            if score >= config.qualityThreshold {
                log.info("Reasoning: quality threshold met at round \(roundIdx + 1)")
                break
            }
        }

        // If no round met threshold, use the best we got
        if bestAnswer.isEmpty, let last = rounds.last {
            bestAnswer = last.refinedOutput.isEmpty ? last.thinkOutput : last.refinedOutput
        }

        return (bestAnswer, rounds)
    }

    // MARK: - Tool Execution

    private func executeReasoningToolCall(_ call: ToolCallParser.ParsedToolCall) async -> String {
        let query = call.arguments["query"] as? String ?? call.argumentsJson

        switch call.name {
        case "vault_search", "search_vault", "search":
            return await executeVaultSearch(query: query)
        case "graph_search", "search_graph":
            return await executeGraphSearch(query: query)
        default:
            log.debug("Reasoning: unknown tool '\(call.name)', skipping")
            return "Tool '\(call.name)' not available in reasoning context."
        }
    }

    private func executeVaultSearch(query: String) async -> String {
        guard let bootstrap = AppBootstrap.shared else {
            return "Vault search unavailable."
        }

        let hits = bootstrap.graphState.store.fuzzySearch(query: query, limit: 5)
        if hits.isEmpty {
            return "No matching notes found for: \(query)"
        }

        return hits.enumerated().map { idx, hit in
            "[\(idx + 1)] \(hit.node.label) (score: \(String(format: "%.2f", hit.score)))"
        }.joined(separator: "\n")
    }

    private func executeGraphSearch(query: String) async -> String {
        guard let bootstrap = AppBootstrap.shared else {
            return "Graph search unavailable."
        }

        let hits = bootstrap.graphState.store.fuzzySearch(query: query, limit: 5)
        if hits.isEmpty {
            return "No graph nodes found for: \(query)"
        }

        return hits.enumerated().map { idx, hit in
            "[\(idx + 1)] \(hit.node.label) (type: \(hit.node.type), score: \(String(format: "%.2f", hit.score)))"
        }.joined(separator: "\n")
    }

    // MARK: - Quality Score Parsing

    /// Extract a quality score (0.0-1.0) from critique text.
    /// Looks for patterns like "Score: 0.85", "quality: 0.7", or standalone decimals.
    func parseQualityScore(from text: String) -> Double {
        // Try explicit score patterns first
        let patterns = [
            "(?:score|quality|rating|confidence)[:\\s]+([0-9]+\\.?[0-9]*)",
            "\\b([0-9]\\.?[0-9]*)\\s*/\\s*1(?:\\.0)?\\b",
            "\\b(0\\.\\d+|1\\.0?)\\b"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let valueStr = nsText.substring(with: match.range(at: 1))
                if let value = Double(valueStr), value >= 0.0, value <= 1.0 {
                    return value
                }
                // Handle integers like "8" → 0.8 (common LLM output: "Score: 8/10")
                if let value = Double(valueStr), value > 1.0, value <= 10.0 {
                    return value / 10.0
                }
            }
        }

        return 0.5  // Default when unparseable
    }

    // MARK: - Prompt Builders

    private func buildThinkPrompt(query: String, systemPrompt: String?) -> String {
        let sys = systemPrompt ?? ""
        return """
        Think step by step about this question. Break it down into sub-problems. \
        Identify what you know, what assumptions you're making, and what information \
        might be missing that you could look up.

        \(sys.isEmpty ? "" : "Context: \(sys)\n")
        Question: \(query)

        Think carefully:
        """
    }

    private func buildCritiquePrompt(thinking: String, query: String) -> String {
        let toolSchema = config.enableToolUse ? """

        If you need more information, you can request tool calls in JSON format:
        {"name": "vault_search", "arguments": {"query": "search terms"}}
        {"name": "graph_search", "arguments": {"query": "concept name"}}

        Include tool calls ONLY if the reasoning has clear gaps that search could fill.
        """ : ""

        return """
        Evaluate the quality of this reasoning for the question. Consider:
        - Is the reasoning logically sound?
        - Are there unsupported assumptions?
        - Is the answer complete and accurate?
        - Would additional information from the user's notes improve it?

        Question: \(query)

        Reasoning to evaluate:
        \(String(thinking.prefix(2000)))

        Rate the quality as a score from 0.0 to 1.0 (e.g., "Score: 0.85").
        Explain any weaknesses briefly.\(toolSchema)
        """
    }

    private func buildRefinePrompt(
        previousThinking: String,
        toolResults: String,
        query: String,
        systemPrompt: String?
    ) -> String {
        let context = toolResults.isEmpty ? "" : """

        New information from search:
        \(String(toolResults.prefix(3000)))
        """

        return """
        Improve your answer to this question using the new information available. \
        Be concise, accurate, and directly address the question.

        Question: \(query)

        Previous reasoning:
        \(String(previousThinking.prefix(2000)))\(context)

        Improved answer:
        """
    }

    private func buildFinalAnswerPrompt(reasoning: String, query: String) -> String {
        return """
        Based on the following reasoning, write a clear, direct answer. \
        Do not include meta-commentary about your thinking process — just answer.

        Question: \(query)

        Reasoning:
        \(String(reasoning.prefix(3000)))

        Answer:
        """
    }
}
