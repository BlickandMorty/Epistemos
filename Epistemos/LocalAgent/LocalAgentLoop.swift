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
    case unsupportedModel(String)

    var errorDescription: String? {
        switch self {
        case .maxTurnsExceeded(let maxTurns):
            return "Local agent exceeded turn limit (\(maxTurns) turns)."
        case .unsupportedModel(let modelID):
            return "\(modelID) is not approved for the local agent loop."
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
    nonisolated struct ParsedToolCall: Sendable, Equatable {
        let name: String
        let argumentsJson: String
    }

    private let generator: LocalAgentGenerationHandler
    private let streamingGenerator: LocalAgentStreamingGeneratorFactory?
    private let structuredGenerator: LocalAgentStructuredGenerationHandler?
    private let toolExecutor: LocalAgentToolExecutor
    private let modelID: String?
    private let maxTokenBudget: Int
    private let maxResponseTokens: Int
    private let defaultReasoningMode: LocalReasoningMode

    init(
        generator: @escaping LocalAgentGenerationHandler,
        streamingGenerator: LocalAgentStreamingGeneratorFactory? = nil,
        structuredGenerator: LocalAgentStructuredGenerationHandler? = nil,
        toolExecutor: @escaping LocalAgentToolExecutor,
        modelID: String? = nil,
        maxTokenBudget: Int = 6_144,
        maxResponseTokens: Int = 2_048,
        defaultReasoningMode: LocalReasoningMode = .fast
    ) {
        self.generator = generator
        self.streamingGenerator = streamingGenerator
        self.structuredGenerator = structuredGenerator
        self.toolExecutor = toolExecutor
        self.modelID = modelID
        self.maxTokenBudget = maxTokenBudget
        self.maxResponseTokens = maxResponseTokens
        self.defaultReasoningMode = defaultReasoningMode
    }

    @MainActor
    static func mlxGenerator(
        using modelClient: any LocalConfigurableLLMClient
    ) -> LocalAgentGenerationHandler {
        let clientBox = MainActorLocalModelClientBox(client: modelClient)
        return { prompt, systemPrompt, maxTokens, reasoningMode, modelID, onToken in
            let stream = await MainActor.run {
                clientBox.client.stream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID
                )
            }

            var output = ""
            for try await chunk in stream {
                output.append(chunk)
                await onToken(chunk)
            }
            return output
        }
    }

    @MainActor
    static func mlxOneShotGenerator(
        using modelClient: any LocalConfigurableLLMClient
    ) -> LocalAgentGenerationHandler {
        let clientBox = MainActorLocalModelClientBox(client: modelClient)
        return { prompt, systemPrompt, maxTokens, reasoningMode, modelID, onToken in
            let output = try await Task { @MainActor in
                try await clientBox.client.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID
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
        using modelClient: any LocalConfigurableLLMClient
    ) -> LocalAgentStreamingGeneratorFactory {
        let clientBox = MainActorLocalModelClientBox(client: modelClient)
        return { prompt, systemPrompt, maxTokens, reasoningMode, modelID in
            await MainActor.run {
                clientBox.client.stream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID
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
            generator: mlxGenerator(using: modelClient),
            streamingGenerator: mlxStreamingGenerator(using: modelClient),
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

        let systemPrompt = HermesPromptBuilder.systemPrompt(
            tools: tools,
            additionalInstructions: additionalSystemPrompt
        )
        let effectiveReasoningMode = reasoningMode ?? defaultReasoningMode
        let historyBudget = max(512, maxTokenBudget - Self.approximateTokenCount(of: systemPrompt))
        var history = [LocalMessage(role: .user, content: objective)]
        var turnCount = 0
        let useReflex = reflexMode && streamingGenerator != nil

        while turnCount < maxTurns {
            turnCount += 1

            history = Self.trimHistory(history, targetTokens: historyBudget)
            let messages = HermesPromptBuilder.buildMessages(
                systemPrompt: systemPrompt,
                history: history
            )
            let promptText = Self.formatChatMLPrompt(messages: messages)

            // ── Reflex path: incremental tool call detection ──
            if useReflex {
                let output = try await runReflexTurn(
                    promptText: promptText,
                    effectiveReasoningMode: effectiveReasoningMode,
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
                forceThinking: turnCount == 1
            )
            let output: String
            if let structuredGenerator,
               let structuredOutput = try await structuredGenerator(
                    promptText,
                    nil,
                    toolPlan,
                    maxResponseTokens,
                    effectiveReasoningMode,
                    modelID,
                    onToken
               ) {
                output = structuredOutput
            } else {
                output = try await generator(
                    promptText,
                    nil,
                    maxResponseTokens,
                    effectiveReasoningMode,
                    modelID,
                    onToken
                )
            }

            let toolCalls = Self.parseToolCalls(from: output)
            if toolCalls.isEmpty {
                return Self.stripAssistantMeta(from: output)
            }

            history.append(LocalMessage(role: .assistant, content: output))
            let toolResults = await executeToolCalls(toolCalls)
            history.append(Self.toolResponseMessage(for: toolResults))
        }

        throw LocalAgentLoopError.maxTurnsExceeded(maxTurns)
    }

    // MARK: - Reflex Turn

    /// Execute a single turn using incremental tool call detection.
    /// Returns `nil` if a tool was executed and the loop should continue,
    /// or the final stripped response if no tool call was found.
    private func runReflexTurn(
        promptText: String,
        effectiveReasoningMode: LocalReasoningMode,
        history: inout [LocalMessage],
        onTreeMutated: (@Sendable () async -> String?)?,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String? {
        guard let streamingGenerator else {
            preconditionFailure("runReflexTurn called without streamingGenerator")
        }

        let detector = IncrementalToolCallDetector()
        var accumulatedOutput = ""
        var reflexDetection: IncrementalToolCallDetector.Detection?

        let stream = await streamingGenerator(
            promptText, nil, maxResponseTokens, effectiveReasoningMode, modelID
        )

        do {
            for try await chunk in stream {
                accumulatedOutput.append(chunk)
                await onToken(chunk)
                if let detection = detector.feed(chunk) {
                    reflexDetection = detection
                    // Breaking exits the for-await loop, which triggers the stream's
                    // onTermination handler → cancels the MLX generation Task.
                    break
                }
            }
        } catch is CancellationError {
            // Expected when we break out or the parent task is cancelled.
        }

        let output = accumulatedOutput

        if let detection = reflexDetection {
            // Immediate tool execution — the core latency win.
            history.append(LocalMessage(role: .assistant, content: output))
            let result = await toolExecutor(detection.toolCall.name, detection.toolCall.argumentsJson)

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
            return nil // continue the loop
        }

        // No tool call detected — check if the full output has one (fallback parse).
        let toolCalls = Self.parseToolCalls(from: output)
        if toolCalls.isEmpty {
            return Self.stripAssistantMeta(from: output)
        }

        history.append(LocalMessage(role: .assistant, content: output))
        let toolResults = await executeToolCalls(toolCalls)
        history.append(Self.toolResponseMessage(for: toolResults))
        return nil // continue the loop
    }

    private func executeToolCalls(_ toolCalls: [ParsedToolCall]) async -> [LocalToolResult] {
        var results: [LocalToolResult] = []
        results.reserveCapacity(toolCalls.count)

        for call in toolCalls {
            let result = await toolExecutor(call.name, call.argumentsJson)
            results.append(result)
        }

        return results
    }

    nonisolated static func parseToolCalls(from output: String) -> [ParsedToolCall] {
        ToolCallParser.parse(output).map { parsed in
            ParsedToolCall(
                name: parsed.name,
                argumentsJson: parsed.argumentsJson
            )
        }
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

    private nonisolated static func formatChatMLPrompt(messages: [LocalMessage]) -> String {
        let renderedMessages = messages.map { message in
            "<|im_start|>\(message.role.rawValue)\n\(message.content)\n<|im_end|>"
        }.joined(separator: "\n")

        return """
        \(renderedMessages)
        <|im_start|>assistant
        """
    }

    private nonisolated static let stripMetaRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?s)<(?:scratch_pad|think|tool_call)>.*?</(?:scratch_pad|think|tool_call)>"#
        )
    }()

    private nonisolated static func stripAssistantMeta(from text: String) -> String {
        guard let regex = stripMetaRegex else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
