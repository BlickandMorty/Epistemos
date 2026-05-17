import Foundation

typealias LocalAgentGenerationHandler = @Sendable (
    _ prompt: String,
    _ systemPrompt: String?,
    _ maxTokens: Int,
    _ reasoningMode: LocalReasoningMode,
    _ modelID: String?,
    _ onToken: @escaping @MainActor (String) -> Void
) async throws -> String

typealias LocalAgentStructuredGenerationHandler = @Sendable (
    _ prompt: String,
    _ systemPrompt: String?,
    _ toolPlan: LocalToolGrammar.ToolCallingPlan,
    _ maxTokens: Int,
    _ reasoningMode: LocalReasoningMode,
    _ modelID: String?,
    _ onToken: @escaping @MainActor (String) -> Void
) async throws -> String?

typealias LocalAgentStreamingGeneratorFactory = @Sendable (
    _ prompt: String,
    _ systemPrompt: String?,
    _ maxTokens: Int,
    _ reasoningMode: LocalReasoningMode,
    _ modelID: String?
) async -> AsyncThrowingStream<String, Error>

typealias LocalAgentToolExecutor = @Sendable (
    _ name: String,
    _ argumentsJson: String
) async -> LocalToolResult

nonisolated enum LocalAgentLoopError: LocalizedError, Equatable {
    case maxTurnsExceeded(Int)
    case invisibleRepairLoop(Int)
    case unsupportedModel(String)
    case streamingGeneratorUnavailable

    var errorDescription: String? {
        switch self {
        case .maxTurnsExceeded(let maxTurns):
            return "Local agent exceeded turn limit (\(maxTurns) turns)."
        case .invisibleRepairLoop(let attempts):
            return "Local agent stopped after \(attempts) consecutive empty repair turns."
        case .unsupportedModel(let modelID):
            return "\(modelID) is not approved for the local agent loop."
        case .streamingGeneratorUnavailable:
            return "Local agent reflex streaming is unavailable for this turn."
        }
    }
}

private final class MainActorLocalModelClientBox: @unchecked Sendable {
    // Safe because the boxed client is only touched from MainActor.run inside mlxGenerator.
    let client: any LocalConfigurableLLMClient

    init(client: any LocalConfigurableLLMClient) {
        self.client = client
    }
}

actor LocalAgentLoop {
    private nonisolated static let invisibleRepairLoopLimit = 2

    nonisolated struct ParsedToolCall: Sendable, Equatable {
        let name: String
        let argumentsJson: String
    }

    private let generator: LocalAgentGenerationHandler
    private let repairGenerator: LocalAgentGenerationHandler
    private let streamingGenerator: LocalAgentStreamingGeneratorFactory?
    private let structuredGenerator: LocalAgentStructuredGenerationHandler?
    private let toolExecutor: LocalAgentToolExecutor
    private var agentProvenanceRecorder: AgentToolProvenanceRecorder?
    private var toolCallSequenceByRunID: [String: Int] = [:]
    private let modelID: String?
    private let maxTokenBudget: Int
    private let maxResponseTokens: Int
    private let defaultReasoningMode: LocalReasoningMode

    init(
        generator: @escaping LocalAgentGenerationHandler,
        repairGenerator: LocalAgentGenerationHandler? = nil,
        streamingGenerator: LocalAgentStreamingGeneratorFactory? = nil,
        structuredGenerator: LocalAgentStructuredGenerationHandler? = nil,
        toolExecutor: @escaping LocalAgentToolExecutor,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil,
        modelID: String? = nil,
        maxTokenBudget: Int = 6_144,
        maxResponseTokens: Int = 2_048,
        defaultReasoningMode: LocalReasoningMode = .fast
    ) {
        self.generator = generator
        self.repairGenerator = repairGenerator ?? generator
        self.streamingGenerator = streamingGenerator
        self.structuredGenerator = structuredGenerator
        self.toolExecutor = toolExecutor
        self.agentProvenanceRecorder = agentProvenanceRecorder
        self.modelID = modelID
        self.maxTokenBudget = maxTokenBudget
        self.maxResponseTokens = maxResponseTokens
        self.defaultReasoningMode = defaultReasoningMode
    }

    @MainActor
    static func mlxGenerator(
        using modelClient: any LocalConfigurableLLMClient,
        steeringHintsJSON: String? = nil
    ) -> LocalAgentGenerationHandler {
        let clientBox = MainActorLocalModelClientBox(client: modelClient)
        return { prompt, systemPrompt, maxTokens, reasoningMode, modelID, onToken in
            let stream = await MainActor.run {
                clientBox.client.stream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    steeringHintsJSON: steeringHintsJSON
                )
            }

            var output = ""
            for try await chunk in stream {
                output.append(chunk)
                await onToken(chunk)
            }
            if !output.isEmpty {
                return output
            }

            let fallbackOutput = try await Task { @MainActor in
                try await clientBox.client.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    steeringHintsJSON: steeringHintsJSON
                )
            }.value
            if !fallbackOutput.isEmpty {
                await onToken(fallbackOutput)
            }
            return fallbackOutput
        }
    }

    @MainActor
    static func mlxOneShotGenerator(
        using modelClient: any LocalConfigurableLLMClient,
        steeringHintsJSON: String? = nil
    ) -> LocalAgentGenerationHandler {
        let clientBox = MainActorLocalModelClientBox(client: modelClient)
        return { prompt, systemPrompt, maxTokens, reasoningMode, modelID, onToken in
            let output = try await Task { @MainActor in
                try await clientBox.client.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    steeringHintsJSON: steeringHintsJSON
                )
            }.value
            await onToken(output)
            return output
        }
    }

    @MainActor
    static func constrainedGenerator(
        using constrainedDecoding: ConstrainedDecodingService
    ) -> LocalAgentStructuredGenerationHandler {
        { prompt, systemPrompt, toolPlan, maxTokens, _, _, _ in
            try await constrainedDecoding.generateCompiledGrammarOutput(
                prompt: prompt,
                systemPrompt: systemPrompt,
                grammar: toolPlan.fallbackGrammar,
                maxTokens: maxTokens
            )
        }
    }

    @MainActor
    static func mlxStreamingGenerator(
        using modelClient: any LocalConfigurableLLMClient,
        steeringHintsJSON: String? = nil
    ) -> LocalAgentStreamingGeneratorFactory {
        let clientBox = MainActorLocalModelClientBox(client: modelClient)
        return { prompt, systemPrompt, maxTokens, reasoningMode, modelID in
            await MainActor.run {
                clientBox.client.stream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    steeringHintsJSON: steeringHintsJSON
                )
            }
        }
    }

    @MainActor
    static func liveLoop(
        using modelClient: any LocalConfigurableLLMClient,
        constrainedDecoding: ConstrainedDecodingService? = nil,
        toolExecutor: @escaping LocalAgentToolExecutor,
        modelID: String? = nil,
        steeringHintsJSON: String? = nil,
        maxTokenBudget: Int? = nil,
        maxResponseTokens: Int = 2_048,
        defaultReasoningMode: LocalReasoningMode = .fast
    ) -> LocalAgentLoop {
        // Derive token budget from model config: use 70% of maxContextTokens
        // to leave room for system prompt + response. Falls back to 6K for unknown models.
        let resolvedBudget: Int
        if let budget = maxTokenBudget {
            resolvedBudget = budget
        } else if let id = modelID, let model = LocalTextModelID(rawValue: id) {
            resolvedBudget = model.maxContextTokens * 70 / 100
        } else {
            resolvedBudget = 6_144
        }

        return LocalAgentLoop(
            generator: mlxGenerator(using: modelClient, steeringHintsJSON: steeringHintsJSON),
            repairGenerator: mlxOneShotGenerator(
                using: modelClient,
                steeringHintsJSON: steeringHintsJSON
            ),
            streamingGenerator: mlxStreamingGenerator(using: modelClient, steeringHintsJSON: steeringHintsJSON),
            structuredGenerator: constrainedDecoding.map { constrainedGenerator(using: $0) },
            toolExecutor: toolExecutor,
            modelID: modelID,
            maxTokenBudget: resolvedBudget,
            maxResponseTokens: maxResponseTokens,
            defaultReasoningMode: defaultReasoningMode
        )
    }

    /// Run the local agent loop.
    ///
    /// - Parameters:
    ///   - reflexMode: When `true` and a `streamingGenerator` is available, tool calls
    ///     are detected incrementally during token streaming and fired the instant the
    ///     closing `</tool_call>` tag completes — remaining generation is cancelled.
    ///   - onTreeMutated: Optional callback for reflex mode. Called after a tool executes;
    ///     if the UI changed (new window, popup), returns fresh AX tree JSON to inject
    ///     into the conversation context. Return `nil` if no mutation detected.
    func run(
        objective: String,
        tools: [OmegaToolDefinition],
        maxTurns: Int = 8,
        reasoningMode: LocalReasoningMode? = nil,
        additionalSystemPrompt: String? = nil,
        reflexMode: Bool = false,
        onTreeMutated: (@Sendable () async -> String?)? = nil,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        if let modelID,
           let resolvedModel = LocalTextModelID(rawValue: modelID),
           !resolvedModel.canActAsAgent {
            throw LocalAgentLoopError.unsupportedModel(modelID)
        }

        let tools = AgentToolNameAliases.canonicalizedDefinitions(for: tools)
        let runID = Self.makeLocalAgentRunID()
        defer {
            toolCallSequenceByRunID[runID] = nil
        }

        let systemPrompt = LocalAgentPromptBuilder.systemPrompt(
            tools: tools,
            additionalInstructions: additionalSystemPrompt,
            modelID: modelID
        )
        let effectiveReasoningMode = reasoningMode ?? defaultReasoningMode
        let historyBudget = max(512, maxTokenBudget - Self.approximateTokenCount(of: systemPrompt))
        var history = [LocalMessage(role: .user, content: objective)]
        var turnCount = 0
        let useReflex = reflexMode && streamingGenerator != nil
        let requiredFileToolSequence = Self.requiredExplicitFileToolSequence(
            for: objective,
            availableTools: tools
        )
        let requiredExplicitFilePath = Self.requestedExplicitFilePath(
            in: objective,
            requiredToolSequence: requiredFileToolSequence
        )
        let requiredNoteToolSequence = Self.requiredExplicitNoteToolSequence(
            for: objective,
            availableTools: tools
        )
        let requestedExplicitNoteTitle = Self.requestedExplicitNoteTitle(
            in: objective,
            requiredToolSequence: requiredNoteToolSequence
        )
        var completedToolNames = Set<String>()
        var consecutiveInvisibleTurns = 0

        func resetInvisibleTurnStreak() {
            consecutiveInvisibleTurns = 0
        }

        func recordInvisibleTurnOrThrow() throws {
            consecutiveInvisibleTurns += 1
            guard consecutiveInvisibleTurns < Self.invisibleRepairLoopLimit else {
                Log.pipeline.error(
                    "Local agent stopped after \(consecutiveInvisibleTurns, privacy: .public) consecutive invisible repair turns"
                )
                throw LocalAgentLoopError.invisibleRepairLoop(consecutiveInvisibleTurns)
            }
        }

        while turnCount < maxTurns {
            turnCount += 1

            history = Self.trimHistory(history, targetTokens: historyBudget)
            let messages = LocalAgentPromptBuilder.buildMessages(
                systemPrompt: systemPrompt,
                history: history
            )
            let promptText = Self.formatPlainMarkdownPrompt(messages: messages)

            // ── Reflex path: incremental tool call detection ──
            if useReflex {
                let output = try await runReflexTurn(
                    runID: runID,
                    objective: objective,
                    promptText: promptText,
                    tools: tools,
                    systemPrompt: systemPrompt,
                    historyBudget: historyBudget,
                    effectiveReasoningMode: effectiveReasoningMode,
                    requiredFileToolSequence: requiredFileToolSequence,
                    requiredExplicitFilePath: requiredExplicitFilePath,
                    requiredNoteToolSequence: requiredNoteToolSequence,
                    requestedExplicitNoteTitle: requestedExplicitNoteTitle,
                    completedToolNames: &completedToolNames,
                    consecutiveInvisibleTurns: &consecutiveInvisibleTurns,
                    history: &history,
                    onTreeMutated: onTreeMutated,
                    onToken: onToken
                )
                if let finalOutput = output {
                    return finalOutput
                }
                continue
            }

            // ── Standard path: generate fully, then parse ──
            let toolPlan = LocalToolGrammar.buildToolCallingPlan(
                tools: tools,
                forceThinking: turnCount == 1,
                modelID: modelID
            )
            var output: String
            var usedStructuredGenerator = false
            if let structuredGenerator {
                if let structuredOutput = try await structuredGenerator(
                    promptText,
                    nil,
                    toolPlan,
                    maxResponseTokens,
                    effectiveReasoningMode,
                    modelID,
                    onToken
                ) {
                    output = structuredOutput
                    usedStructuredGenerator = true
                } else {
                    recordSoftGuidanceToolPlan(nativeGrammar: toolPlan.nativeGrammar)
                    output = try await generator(
                        promptText,
                        nil,
                        maxResponseTokens,
                        effectiveReasoningMode,
                        modelID,
                        onToken
                    )
                }
            } else {
                recordSoftGuidanceToolPlan(nativeGrammar: toolPlan.nativeGrammar)
                output = try await generator(
                    promptText,
                    nil,
                    maxResponseTokens,
                    effectiveReasoningMode,
                    modelID,
                    onToken
                )
            }

            let parsedToolCalls = Self.parseToolCalls(from: output)
            recordToolParseFailureIfNeeded(output: output, parsedToolCalls: parsedToolCalls)
            var toolCalls = Self.canonicalizeToolCalls(parsedToolCalls, availableTools: tools)
            if toolCalls.isEmpty,
               Self.stripAssistantMeta(from: output).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               Self.salvagedHiddenAnswer(from: output) == nil,
               usedStructuredGenerator {
                output = try await immediateRepairOutput(
                    invisibleOutput: output,
                    systemPrompt: systemPrompt,
                    history: history,
                    historyBudget: historyBudget,
                    effectiveReasoningMode: effectiveReasoningMode,
                    repairPrompt: Self.repairPromptForInvisibleTurn(
                        requiredToolSequence: requiredFileToolSequence,
                        completedToolNames: completedToolNames,
                        requestedPath: requiredExplicitFilePath,
                        requiredNoteToolSequence: requiredNoteToolSequence,
                        requestedNoteTitle: requestedExplicitNoteTitle
                    )
                )
                let repairedParsedToolCalls = Self.parseToolCalls(from: output)
                recordToolParseFailureIfNeeded(output: output, parsedToolCalls: repairedParsedToolCalls)
                toolCalls = Self.canonicalizeToolCalls(repairedParsedToolCalls, availableTools: tools)
            }

            if toolCalls.isEmpty {
                if let repairPrompt = Self.repairPromptForSkippedExplicitFileToolStep(
                    output: output,
                    requiredToolSequence: requiredFileToolSequence,
                    completedToolNames: completedToolNames,
                    requestedPath: requiredExplicitFilePath
                ) {
                    let repairSummary = Self.explicitFileRepairSummary(
                        output: output,
                        nextRequiredTool: Self.nextIncompleteTool(
                            in: requiredFileToolSequence,
                            completedToolNames: completedToolNames
                        ),
                        requestedPath: requiredExplicitFilePath
                    )
                    Log.pipeline.info(
                        "Local agent explicit-file repair (skipped step) — \(repairSummary, privacy: .public)"
                    )
                    resetInvisibleTurnStreak()
                    history.append(LocalMessage(role: .assistant, content: output))
                    history.append(LocalMessage(role: .user, content: repairPrompt))
                    continue
                }
                if let repairPrompt = Self.repairPromptForSkippedExplicitNoteToolStep(
                    output: output,
                    requiredToolSequence: requiredNoteToolSequence,
                    completedToolNames: completedToolNames,
                    requestedNoteTitle: requestedExplicitNoteTitle
                ) {
                    resetInvisibleTurnStreak()
                    history.append(LocalMessage(role: .assistant, content: output))
                    history.append(LocalMessage(role: .user, content: repairPrompt))
                    continue
                }
                let visibleOutput = Self.stripAssistantMeta(from: output)
                if !visibleOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resetInvisibleTurnStreak()
                    return visibleOutput
                }
                if let salvagedOutput = Self.salvagedHiddenAnswer(from: output) {
                    resetInvisibleTurnStreak()
                    return salvagedOutput
                }
                history.append(LocalMessage(role: .assistant, content: output))
                history.append(LocalMessage(
                    role: .user,
                    content: Self.repairPromptForInvisibleTurn(
                        requiredToolSequence: requiredFileToolSequence,
                        completedToolNames: completedToolNames,
                        requestedPath: requiredExplicitFilePath,
                        requiredNoteToolSequence: requiredNoteToolSequence,
                        requestedNoteTitle: requestedExplicitNoteTitle
                    )
                ))
                try recordInvisibleTurnOrThrow()
                continue
            }

            resetInvisibleTurnStreak()
            if let repairPrompt = Self.repairPromptForInvalidExplicitFileToolCall(
                toolCalls: toolCalls,
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames,
                requestedPath: requiredExplicitFilePath
            ) {
                recordExplicitToolRepair()
                let repairSummary = Self.explicitFileRepairSummary(
                    toolCalls: toolCalls,
                    completedToolNames: completedToolNames,
                    requiredToolSequence: requiredFileToolSequence,
                    requestedPath: requiredExplicitFilePath
                )
                Log.pipeline.info(
                    "Local agent explicit-file repair (invalid tool call) — \(repairSummary, privacy: .public)"
                )
                history.append(LocalMessage(role: .assistant, content: output))
                history.append(LocalMessage(role: .user, content: repairPrompt))
                continue
            }
            if let repairPrompt = Self.repairPromptForInvalidExplicitNoteToolCall(
                toolCalls: toolCalls,
                requiredToolSequence: requiredNoteToolSequence,
                completedToolNames: completedToolNames,
                requestedNoteTitle: requestedExplicitNoteTitle
            ) {
                recordExplicitToolRepair()
                history.append(LocalMessage(role: .assistant, content: output))
                history.append(LocalMessage(role: .user, content: repairPrompt))
                continue
            }

            history.append(LocalMessage(role: .assistant, content: output))
            let toolResults = await executeToolCalls(toolCalls, runID: runID)
            Self.recordCompletedToolNames(toolCalls.map(\.name), into: &completedToolNames)
            history.append(Self.toolResponseMessage(for: toolResults))
            if let explicitFileAnswer = Self.explicitFileAnswerFromReadResults(
                toolResults,
                objective: objective,
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames
            ) {
                return explicitFileAnswer
            }
        }

        throw LocalAgentLoopError.maxTurnsExceeded(maxTurns)
    }

    // MARK: - Reflex Turn

    /// Execute a single turn using incremental tool call detection.
    /// Returns `nil` if a tool was executed and the loop should continue,
    /// or the final stripped response if no tool call was found.
    private func runReflexTurn(
        runID: String,
        objective: String,
        promptText: String,
        tools: [OmegaToolDefinition],
        systemPrompt: String,
        historyBudget: Int,
        effectiveReasoningMode: LocalReasoningMode,
        requiredFileToolSequence: [String],
        requiredExplicitFilePath: String?,
        requiredNoteToolSequence: [String],
        requestedExplicitNoteTitle: String?,
        completedToolNames: inout Set<String>,
        consecutiveInvisibleTurns: inout Int,
        history: inout [LocalMessage],
        onTreeMutated: (@Sendable () async -> String?)?,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String? {
        guard let streamingGenerator else {
            throw LocalAgentLoopError.streamingGeneratorUnavailable
        }

        let detector = IncrementalToolCallDetector()
        var accumulatedOutput = ""
        var reflexDetection: IncrementalToolCallDetector.Detection?
        var emittedPendingCount = 0

        let stream = await streamingGenerator(
            promptText, nil, maxResponseTokens, effectiveReasoningMode, modelID
        )

        do {
            for try await chunk in stream {
                accumulatedOutput.append(chunk)
                let detection = detector.feed(chunk)

                let pendingText = detector.pendingText
                if pendingText.count > emittedPendingCount {
                    let deltaStart = pendingText.index(
                        pendingText.startIndex,
                        offsetBy: emittedPendingCount
                    )
                    let visibleDelta = String(pendingText[deltaStart...])
                    emittedPendingCount = pendingText.count
                    if !visibleDelta.isEmpty {
                        await onToken(visibleDelta)
                    }
                }

                if let detection {
                    reflexDetection = detection
                    // Breaking exits the for-await loop, which triggers the stream's
                    // onTermination handler → cancels the MLX generation Task.
                    break
                }
            }
        } catch is CancellationError {
            // Expected when we break out or the parent task is cancelled.
        }

        // Stream EOF without a tool-call detection: the detector may
        // still hold trailing text in its private read-ahead buffer
        // (a tag-prefix candidate that never disambiguated, e.g. a
        // lone `<` near the end of the model's output). Without this
        // flush, summaries on the note-ask bar truncated deterministically
        // at the same character every time. See
        // `IncrementalToolCallDetector.flushOnStreamEnd()` for the
        // privacy semantics on hidden tags + malformed tool opens.
        if reflexDetection == nil {
            let flushed = detector.flushOnStreamEnd()
            if !flushed.isEmpty {
                await onToken(flushed)
            }
        }

        let output = accumulatedOutput

        if let detection = reflexDetection {
            // Immediate tool execution — the core latency win.
            let toolCall = Self.canonicalizeToolCall(detection.toolCall, availableTools: tools)
            if let repairPrompt = Self.repairPromptForInvalidExplicitFileToolCall(
                toolCalls: [toolCall],
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames,
                requestedPath: requiredExplicitFilePath
            ) {
                recordExplicitToolRepair()
                let repairSummary = Self.explicitFileRepairSummary(
                    toolCalls: [toolCall],
                    completedToolNames: completedToolNames,
                    requiredToolSequence: requiredFileToolSequence,
                    requestedPath: requiredExplicitFilePath
                )
                Log.pipeline.info(
                    "Local agent explicit-file repair (reflex invalid tool call) — \(repairSummary, privacy: .public)"
                )
                consecutiveInvisibleTurns = 0
                history.append(LocalMessage(role: .assistant, content: output))
                history.append(LocalMessage(role: .user, content: repairPrompt))
                return nil
            }
            if let repairPrompt = Self.repairPromptForInvalidExplicitNoteToolCall(
                toolCalls: [toolCall],
                requiredToolSequence: requiredNoteToolSequence,
                completedToolNames: completedToolNames,
                requestedNoteTitle: requestedExplicitNoteTitle
            ) {
                recordExplicitToolRepair()
                consecutiveInvisibleTurns = 0
                history.append(LocalMessage(role: .assistant, content: output))
                history.append(LocalMessage(role: .user, content: repairPrompt))
                return nil
            }
            consecutiveInvisibleTurns = 0
            history.append(LocalMessage(role: .assistant, content: output))
            let result = await executeToolCall(toolCall, runID: runID)
            Self.recordCompletedToolNames([toolCall.name], into: &completedToolNames)

            // Check for AX tree mutation (new window, popup, etc.)
            if let onTreeMutated, let freshTree = await onTreeMutated() {
                let responseContent = """
                <tool_response>
                \(result.resultJson)
                </tool_response>
                [UI state changed. Updated AX tree:
                \(freshTree)]
                """
                history.append(LocalMessage(role: .tool, content: responseContent))
            } else {
                history.append(Self.toolResponseMessage(for: [result]))
            }
            if let explicitFileAnswer = Self.explicitFileAnswerFromReadResults(
                [result],
                objective: objective,
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames
            ) {
                return explicitFileAnswer
            }
            return nil // continue the loop
        }

        // No tool call detected — check if the full output has one (fallback parse).
        let parsedToolCalls = Self.parseToolCalls(from: output)
        recordToolParseFailureIfNeeded(output: output, parsedToolCalls: parsedToolCalls)
        let toolCalls = Self.canonicalizeToolCalls(parsedToolCalls, availableTools: tools)
        if toolCalls.isEmpty,
           Self.stripAssistantMeta(from: output).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           Self.salvagedHiddenAnswer(from: output) == nil,
           output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let repairResult = try await reflexRepairOutput(
                promptText: promptText,
                tools: tools,
                invisibleOutput: output,
                systemPrompt: systemPrompt,
                history: history,
                historyBudget: historyBudget,
                effectiveReasoningMode: effectiveReasoningMode,
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames,
                requestedPath: requiredExplicitFilePath,
                requiredNoteToolSequence: requiredNoteToolSequence,
                requestedNoteTitle: requestedExplicitNoteTitle
            )
            let repairedOutput = repairResult.output
            let repairedParsedToolCalls = Self.parseToolCalls(from: repairedOutput)
            recordToolParseFailureIfNeeded(output: repairedOutput, parsedToolCalls: repairedParsedToolCalls)
            let repairedToolCalls = Self.canonicalizeToolCalls(
                repairedParsedToolCalls,
                availableTools: tools
            )
            Log.pipeline.info(
                "Local agent repair turn summary — source=\(repairResult.source, privacy: .public) \(Self.invisibleTurnSummary(for: repairedOutput), privacy: .public)"
            )
            if repairedToolCalls.isEmpty {
                let repairedVisibleOutput = Self.stripAssistantMeta(from: repairedOutput)
                if !repairedVisibleOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    consecutiveInvisibleTurns = 0
                    return repairedVisibleOutput
                }
                if let salvagedOutput = Self.salvagedHiddenAnswer(from: repairedOutput) {
                    consecutiveInvisibleTurns = 0
                    return salvagedOutput
                }
                if let syntheticToolCall = Self.syntheticExplicitFileToolCall(
                    objective: objective,
                    requiredToolSequence: requiredFileToolSequence,
                    completedToolNames: completedToolNames,
                    requestedPath: requiredExplicitFilePath
                ) {
                    return await executeSyntheticExplicitFileToolCall(
                        syntheticToolCall,
                        runID: runID,
                        objective: objective,
                        requiredToolSequence: requiredFileToolSequence,
                        completedToolNames: &completedToolNames,
                        history: &history
                    )
                }
                history.append(LocalMessage(role: .assistant, content: repairedOutput))
                history.append(LocalMessage(
                    role: .user,
                    content: Self.repairPromptForInvisibleTurn(
                        requiredToolSequence: requiredFileToolSequence,
                        completedToolNames: completedToolNames,
                        requestedPath: requiredExplicitFilePath,
                        requiredNoteToolSequence: requiredNoteToolSequence,
                        requestedNoteTitle: requestedExplicitNoteTitle
                    )
                ))
                consecutiveInvisibleTurns += 1
                let invisibleTurnCount = consecutiveInvisibleTurns
                guard invisibleTurnCount < Self.invisibleRepairLoopLimit else {
                    Log.pipeline.error(
                        "Local agent stopped after \(invisibleTurnCount, privacy: .public) consecutive invisible repair turns"
                    )
                    throw LocalAgentLoopError.invisibleRepairLoop(invisibleTurnCount)
                }
                return nil
            }

            consecutiveInvisibleTurns = 0
            history.append(LocalMessage(role: .assistant, content: repairedOutput))
            if let repairPrompt = Self.repairPromptForInvalidExplicitFileToolCall(
                toolCalls: repairedToolCalls,
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames,
                requestedPath: requiredExplicitFilePath
            ) {
                recordExplicitToolRepair()
                history.append(LocalMessage(role: .user, content: repairPrompt))
                return nil
            }
            if let repairPrompt = Self.repairPromptForInvalidExplicitNoteToolCall(
                toolCalls: repairedToolCalls,
                requiredToolSequence: requiredNoteToolSequence,
                completedToolNames: completedToolNames,
                requestedNoteTitle: requestedExplicitNoteTitle
            ) {
                recordExplicitToolRepair()
                history.append(LocalMessage(role: .user, content: repairPrompt))
                return nil
            }
            let toolResults = await executeToolCalls(repairedToolCalls, runID: runID)
            Self.recordCompletedToolNames(repairedToolCalls.map(\.name), into: &completedToolNames)
            history.append(Self.toolResponseMessage(for: toolResults))
            if let explicitFileAnswer = Self.explicitFileAnswerFromReadResults(
                toolResults,
                objective: objective,
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames
            ) {
                return explicitFileAnswer
            }
            return nil
        }
        if toolCalls.isEmpty {
            if let repairPrompt = Self.repairPromptForSkippedExplicitFileToolStep(
                output: output,
                requiredToolSequence: requiredFileToolSequence,
                completedToolNames: completedToolNames,
                requestedPath: requiredExplicitFilePath
            ) {
                let repairSummary = Self.explicitFileRepairSummary(
                    output: output,
                    nextRequiredTool: Self.nextIncompleteTool(
                        in: requiredFileToolSequence,
                        completedToolNames: completedToolNames
                    ),
                    requestedPath: requiredExplicitFilePath
                )
                Log.pipeline.info(
                    "Local agent explicit-file repair (reflex skipped step) — \(repairSummary, privacy: .public)"
                )
                consecutiveInvisibleTurns = 0
                history.append(LocalMessage(role: .assistant, content: output))
                history.append(LocalMessage(role: .user, content: repairPrompt))
                return nil
            }
            if let repairPrompt = Self.repairPromptForSkippedExplicitNoteToolStep(
                output: output,
                requiredToolSequence: requiredNoteToolSequence,
                completedToolNames: completedToolNames,
                requestedNoteTitle: requestedExplicitNoteTitle
            ) {
                consecutiveInvisibleTurns = 0
                history.append(LocalMessage(role: .assistant, content: output))
                history.append(LocalMessage(role: .user, content: repairPrompt))
                return nil
            }
            let visibleOutput = Self.stripAssistantMeta(from: output)
            if !visibleOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                consecutiveInvisibleTurns = 0
                return visibleOutput
            }
            if let salvagedOutput = Self.salvagedHiddenAnswer(from: output) {
                consecutiveInvisibleTurns = 0
                return salvagedOutput
            }
            history.append(LocalMessage(role: .assistant, content: output))
            history.append(LocalMessage(
                role: .user,
                content: Self.repairPromptForInvisibleTurn(
                    requiredToolSequence: requiredFileToolSequence,
                    completedToolNames: completedToolNames,
                    requestedPath: requiredExplicitFilePath,
                    requiredNoteToolSequence: requiredNoteToolSequence,
                    requestedNoteTitle: requestedExplicitNoteTitle
                )
            ))
            consecutiveInvisibleTurns += 1
            let invisibleTurnCount = consecutiveInvisibleTurns
            guard invisibleTurnCount < Self.invisibleRepairLoopLimit else {
                Log.pipeline.error(
                    "Local agent stopped after \(invisibleTurnCount, privacy: .public) consecutive invisible repair turns"
                )
                throw LocalAgentLoopError.invisibleRepairLoop(invisibleTurnCount)
            }
            return nil
        }

        consecutiveInvisibleTurns = 0
        history.append(LocalMessage(role: .assistant, content: output))
        if let repairPrompt = Self.repairPromptForInvalidExplicitFileToolCall(
            toolCalls: toolCalls,
            requiredToolSequence: requiredFileToolSequence,
            completedToolNames: completedToolNames,
            requestedPath: requiredExplicitFilePath
        ) {
            recordExplicitToolRepair()
            let repairSummary = Self.explicitFileRepairSummary(
                toolCalls: toolCalls,
                completedToolNames: completedToolNames,
                requiredToolSequence: requiredFileToolSequence,
                requestedPath: requiredExplicitFilePath
            )
            Log.pipeline.info(
                "Local agent explicit-file repair (fallback invalid tool call) — \(repairSummary, privacy: .public)"
            )
            history.append(LocalMessage(role: .user, content: repairPrompt))
            return nil
        }
        if let repairPrompt = Self.repairPromptForInvalidExplicitNoteToolCall(
            toolCalls: toolCalls,
            requiredToolSequence: requiredNoteToolSequence,
            completedToolNames: completedToolNames,
            requestedNoteTitle: requestedExplicitNoteTitle
        ) {
            recordExplicitToolRepair()
            history.append(LocalMessage(role: .user, content: repairPrompt))
            return nil
        }
        let toolResults = await executeToolCalls(toolCalls, runID: runID)
        Self.recordCompletedToolNames(toolCalls.map(\.name), into: &completedToolNames)
        history.append(Self.toolResponseMessage(for: toolResults))
        if let explicitFileAnswer = Self.explicitFileAnswerFromReadResults(
            toolResults,
            objective: objective,
            requiredToolSequence: requiredFileToolSequence,
            completedToolNames: completedToolNames
        ) {
            return explicitFileAnswer
        }
        return nil // continue the loop
    }

    private func executeSyntheticExplicitFileToolCall(
        _ toolCall: ParsedToolCall,
        runID: String,
        objective: String,
        requiredToolSequence: [String],
        completedToolNames: inout Set<String>,
        history: inout [LocalMessage]
    ) async -> String? {
        let requestedPath = Self.toolArgumentValue(
            named: "path",
            from: toolCall.argumentsJson
        ) ?? "unknown"
        Log.pipeline.info(
            "Local agent explicit-file repair (synthetic step) — nextRequired=\(toolCall.name, privacy: .public) requestedPath=\(requestedPath, privacy: .public)"
        )
        history.append(LocalMessage(
            role: .assistant,
            content: Self.renderedToolCallMessage(for: toolCall)
        ))
        let toolResults = await executeToolCalls([toolCall], runID: runID)
        Self.recordCompletedToolNames([toolCall.name], into: &completedToolNames)
        history.append(Self.toolResponseMessage(for: toolResults))
        return Self.explicitFileAnswerFromReadResults(
            toolResults,
            objective: objective,
            requiredToolSequence: requiredToolSequence,
            completedToolNames: completedToolNames
        )
    }

    private func reflexRepairOutput(
        promptText: String,
        tools: [OmegaToolDefinition],
        invisibleOutput: String,
        systemPrompt: String,
        history: [LocalMessage],
        historyBudget: Int,
        effectiveReasoningMode: LocalReasoningMode,
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedPath: String?,
        requiredNoteToolSequence: [String],
        requestedNoteTitle: String?
    ) async throws -> (output: String, source: String) {
        if let structuredOutput = try await structuredReflexRepairOutput(
            promptText: promptText,
            tools: tools,
            effectiveReasoningMode: effectiveReasoningMode,
            forceThinking: history.count == 1
        ) {
            return (structuredOutput, "structured")
        }

        let repairedOutput = try await immediateRepairOutput(
            invisibleOutput: invisibleOutput,
            systemPrompt: systemPrompt,
            history: history,
            historyBudget: historyBudget,
            effectiveReasoningMode: effectiveReasoningMode,
            repairPrompt: Self.repairPromptForInvisibleTurn(
                requiredToolSequence: requiredToolSequence,
                completedToolNames: completedToolNames,
                requestedPath: requestedPath,
                requiredNoteToolSequence: requiredNoteToolSequence,
                requestedNoteTitle: requestedNoteTitle
            )
        )
        return (repairedOutput, "one-shot")
    }

    private func structuredReflexRepairOutput(
        promptText: String,
        tools: [OmegaToolDefinition],
        effectiveReasoningMode: LocalReasoningMode,
        forceThinking: Bool
    ) async throws -> String? {
        guard let structuredGenerator else {
            return nil
        }

        let toolPlan = LocalToolGrammar.buildToolCallingPlan(
            tools: tools,
            forceThinking: forceThinking,
            modelID: modelID
        )
        guard let structuredOutput = try await structuredGenerator(
            promptText,
            nil,
            toolPlan,
            maxResponseTokens,
            effectiveReasoningMode,
            modelID,
            { _ in }
        ) else {
            return nil
        }

        let structuredToolCalls = Self.canonicalizeToolCalls(
            Self.parseToolCalls(from: structuredOutput),
            availableTools: tools
        )
        let structuredVisibleOutput = Self.stripAssistantMeta(from: structuredOutput)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let structuredSalvagedOutput = Self.salvagedHiddenAnswer(from: structuredOutput)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !structuredToolCalls.isEmpty
            || !structuredVisibleOutput.isEmpty
            || structuredSalvagedOutput != nil else {
            return nil
        }

        return structuredOutput
    }

    private func immediateRepairOutput(
        invisibleOutput: String,
        systemPrompt: String,
        history: [LocalMessage],
        historyBudget: Int,
        effectiveReasoningMode: LocalReasoningMode,
        repairPrompt: String
    ) async throws -> String {
        let repairHistory = Self.trimHistory(
            history + [
                LocalMessage(role: .assistant, content: invisibleOutput),
                LocalMessage(role: .user, content: repairPrompt),
            ],
            targetTokens: historyBudget
        )
        let repairMessages = LocalAgentPromptBuilder.buildMessages(
            systemPrompt: systemPrompt,
            history: repairHistory
        )
        let repairPromptText = Self.formatPlainMarkdownPrompt(messages: repairMessages)
        return try await repairGenerator(
            repairPromptText,
            nil,
            maxResponseTokens,
            effectiveReasoningMode,
            modelID,
            { _ in }
        )
    }

    private func executeToolCalls(_ toolCalls: [ParsedToolCall], runID: String) async -> [LocalToolResult] {
        var results: [LocalToolResult] = []
        results.reserveCapacity(toolCalls.count)

        for call in toolCalls {
            results.append(await executeToolCall(call, runID: runID))
        }

        return results
    }

    private func executeToolCall(_ call: ParsedToolCall, runID: String) async -> LocalToolResult {
        let toolCallID = nextLocalAgentToolCallID(runID: runID)
        await recordLocalAgentToolEvent(
            runID: runID,
            toolCallID: toolCallID,
            call: call,
            kind: .toolCallRequested,
            status: .requested
        )
        await recordLocalAgentToolEvent(
            runID: runID,
            toolCallID: toolCallID,
            call: call,
            kind: .toolCallStarted,
            status: .started
        )

        let startedAt = Date()
        let result = await toolExecutor(call.name, call.argumentsJson)
        await recordLocalAgentToolEvent(
            runID: runID,
            toolCallID: toolCallID,
            call: call,
            kind: result.isError ? .toolCallFailed : .toolCallCompleted,
            status: result.isError ? .failed : .completed,
            resultJSON: result.resultJson,
            durationMs: Self.durationMilliseconds(since: startedAt),
            errorMessage: result.isError ? String(result.resultJson.prefix(500)) : nil
        )
        return result
    }

    private func nextLocalAgentToolCallID(runID: String) -> String {
        let nextSequence = (toolCallSequenceByRunID[runID] ?? 0) + 1
        toolCallSequenceByRunID[runID] = nextSequence
        return "local-agent-tool:\(nextSequence)"
    }

    private func recordLocalAgentToolEvent(
        runID: String,
        toolCallID: String,
        call: ParsedToolCall,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        errorMessage: String? = nil
    ) async {
        let recorder = await resolvedAgentProvenanceRecorder()
        let metadata = localAgentToolMetadata()
        let actor = AgentProvenanceActor.agent(id: "local-agent-loop", modelID: modelID)
        await MainActor.run {
            _ = recorder.recordToolEvent(
                runID: runID,
                traceID: nil,
                kind: kind,
                actor: actor,
                toolCallID: toolCallID,
                toolName: call.name,
                argumentsJSON: call.argumentsJson,
                resultJSON: resultJSON,
                durationMs: durationMs,
                approvalID: nil,
                status: status,
                errorMessage: errorMessage,
                metadata: metadata
            )
        }
    }

    private func resolvedAgentProvenanceRecorder() async -> AgentToolProvenanceRecorder {
        if let agentProvenanceRecorder {
            return agentProvenanceRecorder
        }
        let recorder = await MainActor.run {
            AgentToolProvenanceRecorder()
        }
        agentProvenanceRecorder = recorder
        return recorder
    }

    private func localAgentToolMetadata() -> [String: String] {
        var metadata = [
            "source": "local_agent_loop",
            "surface": "local_agent",
        ]
        if let modelID {
            metadata["model"] = modelID
        }
        return metadata
    }

    private func recordSoftGuidanceToolPlan(nativeGrammar: LocalToolGrammar.NativeToolGrammar) {
        LocalAgentDiagnostics.record(
            .softGuidanceToolPlan,
            modelID: modelID,
            nativeGrammar: nativeGrammar
        )
    }

    private func recordToolParseFailureIfNeeded(
        output: String,
        parsedToolCalls: [ParsedToolCall]
    ) {
        guard parsedToolCalls.isEmpty, Self.outputLooksLikeToolIntent(output) else { return }
        LocalAgentDiagnostics.record(
            .toolParseFailure,
            modelID: modelID,
            nativeGrammar: LocalToolGrammar.nativeGrammar(forModelID: modelID)
        )
    }

    private func recordExplicitToolRepair() {
        LocalAgentDiagnostics.record(
            .explicitToolRepair,
            modelID: modelID,
            nativeGrammar: LocalToolGrammar.nativeGrammar(forModelID: modelID)
        )
    }

    private nonisolated static func outputLooksLikeToolIntent(_ output: String) -> Bool {
        let normalized = output.lowercased()
        if normalized.contains("<tool_call")
            || normalized.contains("<|tool_call|>")
            || normalized.contains("[tool_calls]")
            || normalized.contains("tool_call") {
            return true
        }
        return normalized.contains("\"name\"") && normalized.contains("\"arguments\"")
    }

    private nonisolated static func makeLocalAgentRunID() -> String {
        let milliseconds = Date().timeIntervalSince1970 * 1_000
        let safeMilliseconds = milliseconds.isFinite ? Int64(milliseconds.rounded()) : 0
        let suffix = String(UUID().uuidString.prefix(8))
        return "local-agent-\(safeMilliseconds)-\(suffix)"
    }

    private nonisolated static func durationMilliseconds(since startedAt: Date) -> UInt64 {
        let milliseconds = Date().timeIntervalSince(startedAt) * 1_000
        guard milliseconds.isFinite, milliseconds > 0 else {
            return 0
        }
        return UInt64(milliseconds.rounded())
    }

    nonisolated static func parseToolCalls(from output: String) -> [ParsedToolCall] {
        ToolCallParser.parse(output).map { parsed in
            ParsedToolCall(
                name: parsed.name,
                argumentsJson: parsed.argumentsJson
            )
        }
    }

    private nonisolated static func canonicalizeToolCalls(
        _ toolCalls: [ParsedToolCall],
        availableTools: [OmegaToolDefinition]
    ) -> [ParsedToolCall] {
        toolCalls.map { canonicalizeToolCall($0, availableTools: availableTools) }
    }

    private nonisolated static func canonicalizeToolCall(
        _ toolCall: ParsedToolCall,
        availableTools: [OmegaToolDefinition]
    ) -> ParsedToolCall {
        guard let tool = availableTools.first(where: {
            Self.toolNamesAreEquivalent($0.name, toolCall.name)
        }) else {
            return toolCall
        }

        guard let argumentsData = toolCall.argumentsJson.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            return ParsedToolCall(name: tool.name, argumentsJson: toolCall.argumentsJson)
        }

        let normalizedArguments = canonicalizeArguments(arguments, schemaJson: tool.schemaJson)
        guard let normalizedData = try? JSONSerialization.data(
            withJSONObject: normalizedArguments,
            options: [.sortedKeys]
        ),
        let normalizedJson = String(data: normalizedData, encoding: .utf8) else {
            return ParsedToolCall(name: tool.name, argumentsJson: toolCall.argumentsJson)
        }

        return ParsedToolCall(
            name: tool.name,
            argumentsJson: normalizedJson.replacingOccurrences(of: "\\/", with: "/")
        )
    }

    private nonisolated static func toolNamesAreEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        let lhsNames = AgentToolNameAliases.equivalentNames(for: lhs)
        let rhsNames = AgentToolNameAliases.equivalentNames(for: rhs)
        return !lhsNames.isDisjoint(with: rhsNames)
    }

    private nonisolated static func completedToolNamesContain(
        _ completedToolNames: Set<String>,
        _ toolName: String
    ) -> Bool {
        AgentToolNameAliases.containsEquivalent(completedToolNames, toolName)
    }

    private nonisolated static func nextIncompleteTool(
        in requiredToolSequence: [String],
        completedToolNames: Set<String>
    ) -> String? {
        requiredToolSequence.first {
            !completedToolNamesContain(completedToolNames, $0)
        }
    }

    private nonisolated static func recordCompletedToolNames(
        _ toolNames: [String],
        into completedToolNames: inout Set<String>
    ) {
        for toolName in toolNames {
            completedToolNames.formUnion(AgentToolNameAliases.equivalentNames(for: toolName))
        }
    }

    private nonisolated static func canonicalizeArguments(
        _ arguments: [String: Any],
        schemaJson: String
    ) -> [String: Any] {
        guard let data = schemaJson.data(using: .utf8),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let properties = schema["properties"] as? [String: Any],
              !properties.isEmpty else {
            return arguments
        }

        let canonicalKeys = Dictionary(
            uniqueKeysWithValues: properties.keys.map { ($0.lowercased(), $0) }
        )
        var normalized: [String: Any] = [:]
        normalized.reserveCapacity(arguments.count)

        for (key, value) in arguments {
            let canonicalKey = canonicalKeys[key.lowercased()] ?? key
            normalized[canonicalKey] = value
        }

        return normalized
    }

    nonisolated static func trimHistory(
        _ history: [LocalMessage],
        targetTokens: Int
    ) -> [LocalMessage] {
        guard history.count > 1 else { return history }
        guard targetTokens > 0 else {
            return Array(history.prefix(1))
        }

        // Single backward scan: always keep history[0] (the user objective).
        // Walk from the end to find how many recent messages fit the budget.
        let firstCost = approximateTokenCount(of: history[0].content) + 4
        var budget = targetTokens - firstCost
        if budget <= 0 { return Array(history.prefix(1)) }

        var keepFrom = history.count
        for i in stride(from: history.count - 1, through: 1, by: -1) {
            let cost = approximateTokenCount(of: history[i].content) + 4
            if cost > budget { break }
            budget -= cost
            keepFrom = i
        }

        if keepFrom <= 1 {
            return history
        }
        return [history[0]] + history[keepFrom...]
    }

    nonisolated static func approximateTokenCount(of messages: [LocalMessage]) -> Int {
        messages.reduce(into: 0) { total, message in
            total += approximateTokenCount(of: message.content)
            total += 4
        }
    }

    nonisolated static func approximateTokenCount(of text: String) -> Int {
        max(1, text.utf8.count / 4)
    }

    private nonisolated static func toolResponseMessage(for results: [LocalToolResult]) -> LocalMessage {
        let content = results
            .map { result in
                "<tool_response>\n\(result.resultJson)\n</tool_response>"
            }
            .joined(separator: "\n")
        return LocalMessage(role: .tool, content: content)
    }

    private nonisolated static func renderedToolCallMessage(
        for toolCall: ParsedToolCall
    ) -> String {
        """
        <tool_call>
        {"name":"\(toolCall.name)","arguments":\(toolCall.argumentsJson)}
        </tool_call>
        """
    }

    private nonisolated static func formatPlainMarkdownPrompt(messages: [LocalMessage]) -> String {
        let renderedMessages = messages.map { message in
            "## \(message.role.promptHeading)\n\(message.content)"
        }.joined(separator: "\n\n")

        return renderedMessages + "\n\n## Assistant\n"
    }

    private nonisolated static func stripAssistantMeta(from text: String) -> String {
        UserFacingModelOutput.finalVisibleText(from: text)
    }

    private nonisolated static func salvagedHiddenAnswer(from text: String) -> String? {
        let lowercased = text.lowercased()
        guard lowercased.contains("<scratch_pad>")
            || lowercased.contains("<think>")
            || lowercased.contains("<thinking>")
            || lowercased.contains("<thought>")
            || lowercased.contains("<reasoning>") else {
            return nil
        }
        guard !lowercased.contains("<tool_call") else { return nil }

        let stripped = text
            .replacingOccurrences(of: "<scratch_pad>", with: "")
            .replacingOccurrences(of: "</scratch_pad>", with: "")
            .replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .replacingOccurrences(of: "<thinking>", with: "")
            .replacingOccurrences(of: "</thinking>", with: "")
            .replacingOccurrences(of: "<thought>", with: "")
            .replacingOccurrences(of: "</thought>", with: "")
            .replacingOccurrences(of: "<reasoning>", with: "")
            .replacingOccurrences(of: "</reasoning>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return nil }

        return UserFacingModelOutput.salvagedAnswerFromThinkingTrace(from: stripped)
    }

    private nonisolated static func repairPromptForInvisibleTurn(
        requiredToolSequence: [String] = [],
        completedToolNames: Set<String> = [],
        requestedPath: String? = nil,
        requiredNoteToolSequence: [String] = [],
        requestedNoteTitle: String? = nil
    ) -> String {
        if let explicitPrompt = repairPromptForInvisibleExplicitFileToolStep(
            requiredToolSequence: requiredToolSequence,
            completedToolNames: completedToolNames,
            requestedPath: requestedPath
        ) {
            return explicitPrompt
        }
        if let explicitPrompt = repairPromptForInvisibleExplicitNoteToolStep(
            requiredToolSequence: requiredNoteToolSequence,
            completedToolNames: completedToolNames,
            requestedNoteTitle: requestedNoteTitle
        ) {
            return explicitPrompt
        }

        return """
        You have not produced any user-visible answer yet. If the needed note, file, or tool result is already present in the prompt, answer from that context directly now. Otherwise emit exactly one valid <tool_call> block right now for the next required step. Do not return only <scratch_pad>, <think>, hidden reasoning, or tool-planning text. File tools can use the exact filesystem path the user provided, including absolute paths and ~/ home expansion, or a vault-relative path inside the managed runtime vault or ScratchVault. If the user already supplied an explicit path, use that exact path instead of rewriting it to tmp/example.txt. For write-then-read requests, call file.write first and file.read second on that same exact path. For note creation or updates, use vault.write with a vault-relative .md path and full markdown content, and do not claim success before the corresponding <tool_response>.
        """
    }

    private nonisolated static func requiredExplicitFileToolSequence(
        for objective: String,
        availableTools: [OmegaToolDefinition]
    ) -> [String] {
        let request = currentRequestText(from: objective)
        let normalized = request.lowercased()
        let hasWriteTool = AgentToolNameAliases.preferredAvailableName(
            for: "file.write",
            availableTools: availableTools
        ) != nil
        let hasReadTool = AgentToolNameAliases.preferredAvailableName(
            for: "file.read",
            availableTools: availableTools
        ) != nil

        let hasConcreteFileTarget = normalized.contains("tmp/")
            || normalized.contains("/tmp/")
            || normalized.contains("~/")
            || normalized.contains(".txt")
            || normalized.contains(".md")
            || normalized.contains(".json")
            || normalized.contains(".csv")
            || normalized.contains(".log")

        let requiresWrite = hasWriteTool
            && (normalized.contains("file.write")
                || normalized.contains("write_file")
                || (hasConcreteFileTarget && (
                    normalized.contains("write ")
                        || normalized.contains("save ")
                        || normalized.contains("create ")
                )))
        let requiresRead = hasReadTool
            && (normalized.contains("file.read")
                || normalized.contains("read_file")
                || (hasConcreteFileTarget && (
                    normalized.contains("read ")
                        || normalized.contains("read it back")
                        || normalized.contains("reply with only")
                        || normalized.contains("file contents")
                        || normalized.contains("same path")
                )))

        var sequence: [String] = []
        if requiresWrite {
            sequence.append("file.write")
        }
        if requiresRead {
            sequence.append("file.read")
        }
        return sequence
    }

    private nonisolated static func requiredExplicitNoteToolSequence(
        for objective: String,
        availableTools: [OmegaToolDefinition]
    ) -> [String] {
        let request = currentRequestText(from: objective)
        let normalized = request.lowercased()
        let hasWriteTool = AgentToolNameAliases.preferredAvailableName(
            for: "vault.write",
            availableTools: availableTools
        ) != nil
        let hasReadTool = AgentToolNameAliases.preferredAvailableName(
            for: "vault.read",
            availableTools: availableTools
        ) != nil

        let createSignals = [
            "create a new note",
            "create new note",
            "create a note",
            "create note",
            "new note",
            "save a note",
            "save note",
            "write a note",
            "write note",
            "note in the vault titled",
            "note titled",
        ]
        let readBackSignals = [
            "read it back",
            "read back",
            "then read it",
            "reply with only the exact note body",
            "reply with only the note body",
            "exact note body",
        ]

        let requiresWrite = hasWriteTool
            && createSignals.contains(where: normalized.contains)
        let requiresRead = hasReadTool
            && requiresWrite
            && readBackSignals.contains(where: normalized.contains)

        var sequence: [String] = []
        if requiresWrite {
            sequence.append("vault.write")
        }
        if requiresRead {
            sequence.append("vault.read")
        }
        return sequence
    }

    private nonisolated static func currentRequestText(from objective: String) -> String {
        let marker = "Current request:\n"
        if let range = objective.range(of: marker, options: .caseInsensitive) {
            return String(objective[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return objective.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func requestedExplicitNoteTitle(
        in objective: String,
        requiredToolSequence: [String]
    ) -> String? {
        guard !requiredToolSequence.isEmpty else {
            return nil
        }

        let request = currentRequestText(from: objective)
        let patterns = [
            #"(?i)\btitled\s+`([^`\n]+)`"#,
            #"(?i)\btitled\s+\"([^\"]+)\""#,
            #"(?i)\btitled\s+'([^'\n]+)'"#,
            #"(?i)\bcalled\s+`([^`\n]+)`"#,
            #"(?i)\bcalled\s+\"([^\"]+)\""#,
            #"(?i)\bcalled\s+'([^'\n]+)'"#,
            #"(?i)\btitled\s+(.+?)(?:\s+with\b|\s+and\b|\s+then\b|[,.]|$)"#,
            #"(?i)\bcalled\s+(.+?)(?:\s+with\b|\s+and\b|\s+then\b|[,.]|$)"#,
        ]

        for pattern in patterns {
            guard let regex = FoundationSafety.regularExpression(pattern) else {
                continue
            }
            let range = NSRange(request.startIndex..<request.endIndex, in: request)
            guard let match = regex.firstMatch(in: request, options: [], range: range),
                  match.numberOfRanges > 1,
                  let titleRange = Range(match.range(at: 1), in: request) else {
                continue
            }
            let title = String(request[titleRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            if !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private nonisolated static func requestedExplicitFilePath(
        in objective: String,
        requiredToolSequence: [String]
    ) -> String? {
        guard !requiredToolSequence.isEmpty else {
            return nil
        }

        let request = currentRequestText(from: objective)

        let delimitedPatterns = [
            #"`([^`\n]+)`"#,
            #"\"([^\"\n]+)\""#,
            #"'([^'\n]+)'"#,
        ]

        for pattern in delimitedPatterns {
            guard let regex = FoundationSafety.regularExpression(pattern) else {
                continue
            }
            let range = NSRange(request.startIndex..<request.endIndex, in: request)
            let matches = regex.matches(in: request, options: [], range: range)
            for match in matches {
                guard match.numberOfRanges > 1,
                      let candidateRange = Range(match.range(at: 1), in: request) else {
                    continue
                }
                let candidate = String(request[candidateRange])
                if looksLikeExplicitFilePath(candidate) {
                    return candidate
                }
            }
        }

        let directPathPatterns = [
            #"(?:(?<=^)|(?<=[\s`"'(]))(~/\S+)"#,
            #"(?:(?<=^)|(?<=[\s`"'(]))(/(?!/)\S+)"#,
            #"\b(?:[A-Za-z0-9._-]+/)+[A-Za-z0-9._-]+\b"#,
        ]

        for pattern in directPathPatterns {
            guard let regex = FoundationSafety.regularExpression(pattern) else {
                continue
            }
            let range = NSRange(request.startIndex..<request.endIndex, in: request)
            guard let match = regex.firstMatch(in: request, options: [], range: range),
                  let candidateRange = Range(match.range(at: match.numberOfRanges > 1 ? 1 : 0), in: request) else {
                continue
            }
            let candidate = String(request[candidateRange])
            if looksLikeExplicitFilePath(candidate) {
                return candidate
            }
        }

        return nil
    }

    private nonisolated static func looksLikeExplicitFilePath(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("\n") else {
            return false
        }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~/") {
            return true
        }

        guard trimmed.contains("/") else {
            return false
        }

        return trimmed.hasPrefix("tmp/")
            || trimmed.contains(".txt")
            || trimmed.contains(".md")
            || trimmed.contains(".json")
            || trimmed.contains(".csv")
            || trimmed.contains(".log")
    }

    private nonisolated static func repairPromptForInvalidExplicitFileToolCall(
        toolCalls: [ParsedToolCall],
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedPath: String?
    ) -> String? {
        guard let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ),
        let firstToolCall = toolCalls.first else {
            return nil
        }

        let actualToolName = firstToolCall.name.lowercased()
        let actualPath = toolArgumentValue(named: "path", from: firstToolCall.argumentsJson)
        let requestedPathClause = requestedPath.map { #" using the exact path "\#($0)""# } ?? ""

        if !toolNamesAreEquivalent(actualToolName, nextRequiredTool) {
            let actualPathSentence = actualPath.map { #" on "\#($0)""# } ?? ""
            return """
            You have not satisfied the user's explicit file request yet. The next required tool step is \(nextRequiredTool)\(requestedPathClause). Your last tool call used \(firstToolCall.name)\(actualPathSentence) instead. Emit exactly one valid <tool_call> block now for \(nextRequiredTool)\(requestedPathClause). Do not skip ahead, do not reuse example paths, and wait for the next <tool_response> before continuing.
            """
        }

        guard let requestedPath else {
            return nil
        }
        guard actualPath != requestedPath else {
            return nil
        }

        let actualPathSentence = actualPath.map { #""\#($0)""# } ?? "a missing path argument"
        return """
        You have not satisfied the user's explicit file request yet. The user requested the exact path "\(requestedPath)". Your last \(nextRequiredTool) call used \(actualPathSentence) instead. Emit exactly one valid <tool_call> block now for \(nextRequiredTool) using the exact path "\(requestedPath)". Do not reuse example paths such as tmp/example.txt, do not invent nearby filenames, and wait for the next <tool_response> before continuing.
        """
    }

    private nonisolated static func repairPromptForInvalidExplicitNoteToolCall(
        toolCalls: [ParsedToolCall],
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedNoteTitle: String?
    ) -> String? {
        guard let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ),
        let firstToolCall = toolCalls.first else {
            return nil
        }

        guard !toolNamesAreEquivalent(firstToolCall.name, nextRequiredTool) else {
            return nil
        }

        let noteTargetSentence = requestedNoteTitle.map {
            #" for the requested note titled "\#($0)""#
        } ?? ""
        let followUpSentence =
            toolNamesAreEquivalent(nextRequiredTool, "vault.read")
            ? " Use the same exact note path from the successful vault.write step."
            : " If you are creating a new note from a title, choose a clear vault-relative .md path that matches that title."

        return """
        You have not satisfied the user's explicit note request yet. The next required tool step is \(nextRequiredTool)\(noteTargetSentence). Your last tool call used \(firstToolCall.name) instead. Emit exactly one valid <tool_call> block now for \(nextRequiredTool)\(noteTargetSentence).\(followUpSentence) Wait for the next <tool_response> before continuing.
        """
    }

    private nonisolated static func toolArgumentValue(
        named key: String,
        from argumentsJson: String
    ) -> String? {
        guard let argumentsData = argumentsJson.data(using: .utf8),
              let argumentsObject = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any],
              let value = argumentsObject[key] as? String else {
            return nil
        }
        return value
    }

    private nonisolated static func syntheticExplicitFileToolCall(
        objective: String,
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedPath: String?
    ) -> ParsedToolCall? {
        guard let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ) else {
            return nil
        }

        switch AgentToolNameAliases.canonical(nextRequiredTool) {
        case "file.write":
            guard let requestedPath,
                  let content = requestedExplicitWriteContent(
                    in: objective,
                    requestedPath: requestedPath
                  ),
                  let argumentsJson = toolArgumentsJSONString([
                    "content": content,
                    "path": requestedPath,
                  ]) else {
                return nil
            }
            return ParsedToolCall(name: nextRequiredTool, argumentsJson: argumentsJson)
        case "file.read":
            guard let requestedPath,
                  let argumentsJson = toolArgumentsJSONString([
                    "path": requestedPath,
                  ]) else {
                return nil
            }
            return ParsedToolCall(name: nextRequiredTool, argumentsJson: argumentsJson)
        default:
            return nil
        }
    }

    private nonisolated static func requestedExplicitWriteContent(
        in objective: String,
        requestedPath: String
    ) -> String? {
        let request = currentRequestText(from: objective)
        let escapedPath = NSRegularExpression.escapedPattern(for: requestedPath)
        guard let regex = FoundationSafety.regularExpression(
            #"(?is)\bwrite\s+exactly\s+(.+?)\s+to\s+\#(escapedPath)\b"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let range = NSRange(request.startIndex..<request.endIndex, in: request)
        guard let match = regex.firstMatch(in: request, options: [], range: range),
              match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: request) else {
            return trailingExactWriteContent(in: request, requestedPath: requestedPath)
        }

        return normalizedExplicitWriteContent(String(request[contentRange]))
    }

    private nonisolated static func trailingExactWriteContent(
        in request: String,
        requestedPath: String
    ) -> String? {
        let escapedPath = NSRegularExpression.escapedPattern(for: requestedPath)
        let patterns = [
            #"(?is)\b(?:use\s+)?(?:file\.write|write_file)\s+to\s+create\s+\#(escapedPath)\b\s+with\s+exactly\s+this\s+content(?:\s+and\s+nothing\s+else)?\s*:?"#,
            #"(?is)\bcreate\s+\#(escapedPath)\b\s+with\s+exactly\s+this\s+content(?:\s+and\s+nothing\s+else)?\s*:?"#,
            #"(?is)\bwrite\s+\#(escapedPath)\b\s+with\s+exactly\s+this\s+content(?:\s+and\s+nothing\s+else)?\s*:?"#,
        ]

        for pattern in patterns {
            guard let regex = FoundationSafety.regularExpression(
                pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            let range = NSRange(request.startIndex..<request.endIndex, in: request)
            guard let match = regex.firstMatch(in: request, options: [], range: range),
                  let markerRange = Range(match.range, in: request) else {
                continue
            }
            let trailing = String(request[markerRange.upperBound...])
            if let content = normalizedTrailingExactWriteContent(trailing) {
                return content
            }
        }

        return nil
    }

    private nonisolated static func normalizedExplicitWriteContent(_ raw: String) -> String? {
        let captured = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !captured.isEmpty else {
            return nil
        }

        if (captured.hasPrefix("\"") && captured.hasSuffix("\""))
            || (captured.hasPrefix("'") && captured.hasSuffix("'"))
            || (captured.hasPrefix("`") && captured.hasSuffix("`")) {
            return String(captured.dropFirst().dropLast())
        }
        return captured
    }

    private nonisolated static func normalizedTrailingExactWriteContent(
        _ raw: String
    ) -> String? {
        let trimmed = raw
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n:"))
        guard !trimmed.isEmpty else {
            return nil
        }

        let lines = trimmed.components(separatedBy: .newlines)
        var capturedLines: [String] = []
        capturedLines.reserveCapacity(lines.count)

        for line in lines {
            let normalizedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !capturedLines.isEmpty && looksLikeFollowUpInstructionLine(normalizedLine) {
                break
            }
            if capturedLines.isEmpty && normalizedLine.isEmpty {
                continue
            }
            capturedLines.append(line)
        }

        let captured = capturedLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedExplicitWriteContent(captured)
    }

    private nonisolated static func looksLikeFollowUpInstructionLine(_ line: String) -> Bool {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return false
        }

        let prefixes = [
            "then ",
            "then use ",
            "then call ",
            "and then ",
            "after that ",
            "next ",
            "finally ",
            "reply with ",
        ]
        guard prefixes.contains(where: normalized.hasPrefix) else {
            return false
        }

        return normalized.contains("file.read")
            || normalized.contains("read_file")
            || normalized.contains("reply")
            || normalized.contains("same path")
            || normalized.contains("tool")
    }

    private nonisolated static func toolArgumentsJSONString(
        _ object: [String: Any]
    ) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
              ),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private nonisolated static func explicitFileAnswerFromReadResults(
        _ results: [LocalToolResult],
        objective: String,
        requiredToolSequence: [String],
        completedToolNames: Set<String>
    ) -> String? {
        let wantsOnlyFileContents = requestsOnlyFileContents(in: objective)
        let wantsOnlyFirstLine = requestsOnlyFirstLine(in: objective)
        guard (wantsOnlyFileContents || wantsOnlyFirstLine),
              !requiredToolSequence.isEmpty,
              requiredToolSequence.allSatisfy({
                  completedToolNamesContain(completedToolNames, $0)
              }) else {
            return nil
        }

        for result in results.reversed() where toolNamesAreEquivalent(result.toolName, "file.read") {
            guard let content = normalizedExplicitReadContent(from: result.resultJson),
                  !content.isEmpty else {
                continue
            }
            if wantsOnlyFirstLine {
                return content
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return content
        }
        return nil
    }

    private nonisolated static func normalizedExplicitReadContent(from resultJson: String) -> String? {
        guard let resultData = resultJson.data(using: .utf8),
              let resultObject = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any],
              let content = resultObject["content"] as? String,
              !content.isEmpty else {
            return nil
        }

        guard let showing = resultObject["showing"] as? [String: Any],
              let startingLine = showing["from"] as? Int,
              startingLine > 0 else {
            return content
        }

        return strippedReadFileLineNumbers(from: content, startingAt: startingLine) ?? content
    }

    private nonisolated static func strippedReadFileLineNumbers(
        from content: String,
        startingAt startingLine: Int
    ) -> String? {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else {
            return content
        }

        var strippedLines: [String] = []
        strippedLines.reserveCapacity(lines.count)

        for (index, line) in lines.enumerated() {
            let prefix = "\(startingLine + index)\t"
            guard line.hasPrefix(prefix) else {
                return nil
            }
            strippedLines.append(String(line.dropFirst(prefix.count)))
        }

        return strippedLines.joined(separator: "\n")
    }

    private nonisolated static func requestsOnlyFileContents(in objective: String) -> Bool {
        let normalized = currentRequestText(from: objective).lowercased()
        return normalized.contains("reply with only")
            && (normalized.contains("file contents") || normalized.contains("file content"))
    }

    private nonisolated static func requestsOnlyFirstLine(in objective: String) -> Bool {
        let normalized = currentRequestText(from: objective).lowercased()
        return normalized.contains("reply with only")
            && normalized.contains("first line")
    }

    private nonisolated static func repairPromptForSkippedExplicitFileToolStep(
        output: String,
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedPath: String?
    ) -> String? {
        guard let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ) else {
            return nil
        }

        let visibleOutput = stripAssistantMeta(from: output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let salvagedOutput = salvagedHiddenAnswer(from: output)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateOutput = [visibleOutput, salvagedOutput]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty }) ?? ""

        guard !candidateOutput.isEmpty else {
            return nil
        }
        guard !looksLikeHonestFailureExplanation(candidateOutput) else {
            return nil
        }

        let requestedPathSentence = requestedPath.map {
            #" using the exact path "\#($0)""#
        } ?? ""

        return """
        You have not satisfied the user's explicit file request yet. Your previous answer guessed the result before the missing required tool step completed. Emit exactly one valid <tool_call> block now for the next missing required tool step: \(nextRequiredTool)\(requestedPathSentence). Do not answer from the user's requested file contents alone. Use the exact requested path when the user already provided one. For write-then-read file requests, wait for each <tool_response> before moving to the next step or giving the final answer.
        """
    }

    private nonisolated static func repairPromptForSkippedExplicitNoteToolStep(
        output: String,
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedNoteTitle: String?
    ) -> String? {
        guard let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ) else {
            return nil
        }

        let visibleOutput = stripAssistantMeta(from: output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let salvagedOutput = salvagedHiddenAnswer(from: output)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateOutput = [visibleOutput, salvagedOutput]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty }) ?? ""

        guard !candidateOutput.isEmpty else {
            return nil
        }
        guard !looksLikeHonestFailureExplanation(candidateOutput) else {
            return nil
        }

        let noteTargetSentence = requestedNoteTitle.map {
            #" for the requested note titled "\#($0)""#
        } ?? ""
        let followUpSentence =
            toolNamesAreEquivalent(nextRequiredTool, "vault.read")
            ? " Use the same exact note path from the successful vault.write step."
            : " If you are creating a new note from a title, choose a clear vault-relative .md path that matches that title."

        return """
        You have not satisfied the user's explicit note request yet. Your previous answer guessed note success before the missing required tool step completed. Emit exactly one valid <tool_call> block now for the next missing required tool step: \(nextRequiredTool)\(noteTargetSentence).\(followUpSentence) Wait for each <tool_response> before moving to the next step or giving the final answer.
        """
    }

    private nonisolated static func repairPromptForInvisibleExplicitFileToolStep(
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedPath: String?
    ) -> String? {
        guard let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ) else {
            return nil
        }

        let requestedPathSentence = requestedPath.map {
            #" using the exact path "\#($0)""#
        } ?? ""

        return """
        You have not satisfied the user's explicit file request yet. The next required tool step is \(nextRequiredTool)\(requestedPathSentence). Emit exactly one valid <tool_call> block now for \(nextRequiredTool)\(requestedPathSentence). Do not output prose, <think>, <scratch_pad>, or planning text before the <tool_call>. Do not answer from the user's requested file contents alone. Wait for the next <tool_response> before continuing.
        """
    }

    private nonisolated static func repairPromptForInvisibleExplicitNoteToolStep(
        requiredToolSequence: [String],
        completedToolNames: Set<String>,
        requestedNoteTitle: String?
    ) -> String? {
        guard let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ) else {
            return nil
        }

        let noteTargetSentence = requestedNoteTitle.map {
            #" for the requested note titled "\#($0)""#
        } ?? ""
        let followUpSentence =
            toolNamesAreEquivalent(nextRequiredTool, "vault.read")
            ? " Use the same exact note path from the successful vault.write step."
            : " If you are creating a new note from a title, choose a clear vault-relative .md path that matches that title."

        return """
        You have not satisfied the user's explicit note request yet. The next required tool step is \(nextRequiredTool)\(noteTargetSentence). Emit exactly one valid <tool_call> block now for \(nextRequiredTool)\(noteTargetSentence).\(followUpSentence) Do not output prose, <think>, <scratch_pad>, or planning text before the <tool_call>. Wait for the next <tool_response> before continuing.
        """
    }

    private nonisolated static func looksLikeHonestFailureExplanation(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let failureSignals = [
            "cannot",
            "can't",
            "couldn't",
            "unable",
            "failed",
            "failure",
            "error",
            "not able",
            "does not exist",
            "unsupported",
            "absolute path",
            "vault-scoped",
            "scratchvault",
        ]
        return failureSignals.contains { normalized.contains($0) }
    }

    private nonisolated static func invisibleTurnSummary(for text: String) -> String {
        let singleLinePreview = text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
            .prefix(200)
        let visibleText = stripAssistantMeta(from: text)
        let hasThink = text.localizedCaseInsensitiveContains("<think>")
        let hasScratchPad = text.localizedCaseInsensitiveContains("<scratch_pad>")
        let hasToolTag = text.localizedCaseInsensitiveContains("<tool_call>")
        let hasFence = text.contains("```")
        return [
            "chars=\(text.count)",
            "visibleChars=\(visibleText.trimmingCharacters(in: .whitespacesAndNewlines).count)",
            "toolCalls=\(parseToolCalls(from: text).count)",
            "hasThink=\(hasThink)",
            "hasScratchPad=\(hasScratchPad)",
            "hasToolTag=\(hasToolTag)",
            "hasFence=\(hasFence)",
            "preview=\(String(singleLinePreview))",
        ].joined(separator: " ")
    }

    private nonisolated static func explicitFileRepairSummary(
        toolCalls: [ParsedToolCall],
        completedToolNames: Set<String>,
        requiredToolSequence: [String],
        requestedPath: String?
    ) -> String {
        let nextRequiredTool = nextIncompleteTool(
            in: requiredToolSequence,
            completedToolNames: completedToolNames
        ) ?? "none"
        let firstToolCall = toolCalls.first
        let actualPath = firstToolCall.flatMap { toolArgumentValue(named: "path", from: $0.argumentsJson) } ?? "nil"
        return [
            "nextRequired=\(nextRequiredTool)",
            "requestedPath=\(requestedPath ?? "nil")",
            "actualTool=\(firstToolCall?.name ?? "nil")",
            "actualPath=\(actualPath)",
            "toolCalls=\(toolCalls.count)",
        ].joined(separator: " ")
    }

    private nonisolated static func explicitFileRepairSummary(
        output: String,
        nextRequiredTool: String?,
        requestedPath: String?
    ) -> String {
        let visibleOutput = stripAssistantMeta(from: output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "\\n")
            .prefix(200)
        return [
            "nextRequired=\(nextRequiredTool ?? "nil")",
            "requestedPath=\(requestedPath ?? "nil")",
            "visiblePreview=\(String(visibleOutput))",
            "toolCalls=\(parseToolCalls(from: output).count)",
            "hasFence=\(output.contains("```"))",
            "hasToolTag=\(output.localizedCaseInsensitiveContains("<tool_call>"))",
        ].joined(separator: " ")
    }
}
