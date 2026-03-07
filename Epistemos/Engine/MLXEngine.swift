import Foundation
import Hub
import MLX
import MLXLMCommon
import MLXLLM
import MLXVLM
import Tokenizers

// MARK: - Generation Result Types

struct MLXGenerationMetrics: Sendable {
    var promptTokenCount: Int = 0
    var generationTokenCount: Int = 0
    var promptTimeSeconds: Double = 0
    var generateTimeSeconds: Double = 0
    var totalTimeSeconds: Double = 0
    var tokensPerSecond: Double = 0
    var promptTokensPerSecond: Double = 0
    var peakMemoryMB: Double = 0
    var baselineMemoryMB: Double = 0
}

struct MLXGenerationResult: Sendable {
    var output: String = ""
    var cleanedOutput: String = ""
    var metrics = MLXGenerationMetrics()
    var error: String?

    var success: Bool { error == nil && !output.isEmpty }
}

// MARK: - Sendable Wrapper for ModelContainer.perform

private struct GenerateValues: @unchecked Sendable {
    nonisolated(unsafe) let messages: [Chat.Message]
    nonisolated(unsafe) let tools: [ToolSpec]?
    nonisolated(unsafe) let additionalCtx: [String: any Sendable]?
    nonisolated(unsafe) let generateParams: GenerateParameters
    nonisolated(unsafe) let maxTokens: Int
}

// MARK: - MLXEngine Actor

actor MLXEngine {

    private var modelContainer: ModelContainer?
    private var currentModelId: String?
    private var isVLM = false

    init(memoryLimitGB: Int = 5) {
        GPU.set(memoryLimit: memoryLimitGB * 1024 * 1024 * 1024)
    }

    var loadedModelId: String? { currentModelId }

    func loadModel(
        id: String,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Double {
        if currentModelId == id { return 0 }

        if modelContainer != nil {
            unloadModel()
        }

        let start = CFAbsoluteTimeGetCurrent()

        let config = ModelConfiguration(
            id: id,
            toolCallFormat: Self.toolCallFormat(for: id)
        )
        let progressHandler: @Sendable (Progress) -> Void = progress ?? { _ in }

        do {
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: config, progressHandler: progressHandler)
            isVLM = false
        } catch {
            modelContainer = try await VLMModelFactory.shared.loadContainer(
                configuration: config, progressHandler: progressHandler)
            isVLM = true
        }

        currentModelId = id
        return CFAbsoluteTimeGetCurrent() - start
    }

    func clearCache() {
        Memory.cacheLimit = 0
        Memory.clearCache()
        Memory.cacheLimit = 512 * 1024 * 1024
    }

    func unloadModel() {
        modelContainer = nil
        currentModelId = nil
        Memory.cacheLimit = 0
        Memory.clearCache()
    }

    // MARK: - Generate

    func generateChat(
        messages: [Chat.Message],
        maxTokens: Int = 500,
        temperature: Float = 0.6,
        topP: Float = 0.95,
        repetitionPenalty: Float? = nil,
        enableThinking: Bool? = nil,
        tools: [ToolSpec]? = nil,
        toolDispatch: (@Sendable (String, [String: String]) async -> (name: String, result: String))? = nil,
        onChunk: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> MLXGenerationResult {
        guard let container = modelContainer else {
            var result = MLXGenerationResult()
            result.error = "No model loaded"
            return result
        }

        Memory.cacheLimit = 0
        Memory.clearCache()
        Memory.cacheLimit = 512 * 1024 * 1024
        let baselineMemory = Double(Memory.activeMemory) / (1024 * 1024)
        Memory.peakMemory = 0

        var additionalCtx: [String: any Sendable]?
        if let enableThinking {
            additionalCtx = ["enable_thinking": enableThinking]
        }

        var currentMessages = messages

        var generateParams = GenerateParameters(temperature: temperature, topP: topP)
        if let repetitionPenalty {
            generateParams.repetitionPenalty = repetitionPenalty
            generateParams.repetitionContextSize = 64
        }

        let promptStart = CFAbsoluteTimeGetCurrent()
        var finalOutput = ""
        var finalInfo: GenerateCompletionInfo?
        var toolCallCount = 0
        var lastToolResult: String?
        let maxToolCalls = 5

        while toolCallCount < maxToolCalls {
            let wrappedValues = GenerateValues(
                messages: currentMessages,
                tools: tools,
                additionalCtx: additionalCtx,
                generateParams: generateParams,
                maxTokens: maxTokens
            )
            let loopResult: (text: String, info: GenerateCompletionInfo?, toolCall: ToolCall?) =
                try await container.perform(values: wrappedValues) { context, values in
                    let input = try await Self.prepareInput(
                        context: context,
                        messages: values.messages,
                        tools: values.tools,
                        additionalContext: values.additionalCtx
                    )
                    let iterator = try TokenIterator(
                        input: input,
                        model: context.model,
                        parameters: values.generateParams
                    )
                    let (stream, task) = MLXLMCommon.generateTask(
                        promptTokenCount: input.text.tokens.size,
                        modelConfiguration: context.configuration,
                        tokenizer: context.tokenizer,
                        iterator: iterator
                    )

                    var generatedText = ""
                    var completionInfo: GenerateCompletionInfo?
                    var detectedToolCall: ToolCall?
                    var cancelledEarly = false
                    var chunkCount = 0

                    for await generation in stream {
                        try Task.checkCancellation()

                        switch generation {
                        case .chunk(let chunk):
                            guard detectedToolCall == nil else { continue }
                            generatedText += chunk
                            chunkCount += 1
                            if let onChunk, !chunk.isEmpty {
                                await onChunk(chunk)
                            }
                            if chunkCount >= values.maxTokens
                                || (generatedText.contains("<think>")
                                    && !generatedText.contains("</think>")
                                    && generatedText.count >= min(values.maxTokens, 160))
                                || (generatedText.count >= 60 && Self.hasRepetition(generatedText))
                            {
                                cancelledEarly = true
                                task.cancel()
                                break
                            }
                        case .info(let info):
                            completionInfo = info
                        case .toolCall(let toolCall):
                            detectedToolCall = toolCall
                            task.cancel()
                        }
                    }

                    if cancelledEarly || detectedToolCall != nil {
                        task.cancel()
                    }
                    await task.value
                    return (generatedText, completionInfo, detectedToolCall)
                }

            let detectedToolCall: ToolCall?
            if loopResult.toolCall == nil, tools != nil {
                detectedToolCall = Self.parseToolCall(from: loopResult.text).map(Self.makeToolCall(from:))
            } else {
                detectedToolCall = loopResult.toolCall
            }

            if let call = detectedToolCall, let dispatch = toolDispatch {
                let assistantText = loopResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !assistantText.isEmpty {
                    currentMessages.append(.assistant(assistantText))
                }

                let toolResult = await dispatch(call.function.name, Self.stringArguments(from: call))
                currentMessages.append(.tool(toolResult.result))
                lastToolResult = toolResult.result

                toolCallCount += 1
                finalInfo = loopResult.info
                continue
            }

            finalOutput = Self.trimRepetition(loopResult.text)
            finalInfo = loopResult.info
            break
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - promptStart
        let peakMemory = Double(Memory.peakMemory) / (1024 * 1024)

        var result = MLXGenerationResult()
        result.output = finalOutput
        let cleaned = Self.stripThinkingTags(finalOutput)
        if cleaned.isEmpty, let toolResult = lastToolResult {
            result.cleanedOutput = toolResult
        } else {
            result.cleanedOutput = cleaned
        }

        if let info = finalInfo {
            result.metrics.promptTokenCount = info.promptTokenCount
            result.metrics.generationTokenCount = info.generationTokenCount
            result.metrics.promptTimeSeconds = info.promptTime
            result.metrics.generateTimeSeconds = info.generateTime
            result.metrics.tokensPerSecond = info.tokensPerSecond
            result.metrics.promptTokensPerSecond = info.promptTokensPerSecond
        } else {
            result.metrics.generateTimeSeconds = totalTime
        }

        result.metrics.totalTimeSeconds = totalTime
        result.metrics.peakMemoryMB = peakMemory
        result.metrics.baselineMemoryMB = baselineMemory

        return result
    }

    // MARK: - Model Configuration

    private static func toolCallFormat(for modelId: String) -> ToolCallFormat? {
        let normalized = modelId.lowercased()
        if normalized.contains("qwen3.5") || normalized.contains("qwen3_5") {
            return .xmlFunction
        }
        return nil
    }

    private static func prepareInput(
        context: ModelContext,
        messages: [Chat.Message],
        tools: [ToolSpec]?,
        additionalContext: [String: any Sendable]?
    ) async throws -> LMInput {
        if let chatTemplate = correctedChatTemplateIfNeeded(
            configuration: context.configuration,
            additionalContext: additionalContext
        ) {
            let rawMessages = DefaultMessageGenerator().generate(messages: messages)
            let promptTokens = try context.tokenizer.applyChatTemplate(
                messages: rawMessages,
                chatTemplate: .literal(chatTemplate),
                addGenerationPrompt: true,
                truncation: false,
                maxLength: nil,
                tools: tools,
                additionalContext: additionalContext
            )
            return LMInput(tokens: MLXArray(promptTokens))
        }

        let userInput = UserInput(
            chat: messages,
            tools: tools,
            additionalContext: additionalContext
        )
        return try await context.processor.prepare(input: userInput)
    }

    // MARK: - Qwen 3.5 4B Template Patch

    private static func correctedChatTemplateIfNeeded(
        configuration: ModelConfiguration,
        additionalContext: [String: any Sendable]?
    ) -> String? {
        guard
            isQwen35_4B(configuration.name),
            let enableThinking = additionalContext?["enable_thinking"] as? Bool,
            enableThinking == false,
            let chatTemplate = loadChatTemplate(for: configuration)
        else {
            return nil
        }
        return patchQwen35_4BNonThinkingTemplate(chatTemplate)
    }

    private static func loadChatTemplate(for configuration: ModelConfiguration) -> String? {
        let modelDirectory = configuration.modelDirectory(hub: HubApi())
        let templateURL = modelDirectory.appending(path: "chat_template.jinja")
        return try? String(contentsOf: templateURL, encoding: .utf8)
    }

    private static func patchQwen35_4BNonThinkingTemplate(_ chatTemplate: String) -> String {
        let brokenBlock = """
        {%- if enable_thinking is defined and enable_thinking is false %}
                {{- '<think>\\n\\n</think>\\n\\n' }}
            {%- else %}
                {{- '<think>\\n' }}
            {%- endif %}
        """
        let fixedBlock = """
        {%- if enable_thinking is defined and enable_thinking is false %}
                {{- '' }}
            {%- else %}
                {{- '<think>\\n' }}
            {%- endif %}
        """

        if chatTemplate.contains(brokenBlock) {
            return chatTemplate.replacingOccurrences(of: brokenBlock, with: fixedBlock)
        }
        return chatTemplate.replacingOccurrences(
            of: "{{- '<think>\\n\\n</think>\\n\\n' }}",
            with: "{{- '' }}"
        )
    }

    private static func isQwen35_4B(_ name: String) -> Bool {
        let normalized = name.lowercased()
        return (normalized.contains("qwen3.5") || normalized.contains("qwen3_5"))
            && normalized.contains("4b")
    }

    // MARK: - Tool Call Parsing

    private struct ParsedToolCall {
        let name: String
        let arguments: [String: String]
    }

    private static func parseToolCall(from text: String) -> ParsedToolCall? {
        let patterns: [(String, Bool)] = [
            (#"<tool_call>\s*<function=([^>]+)>(.*?)</function>\s*</tool_call>"#, true),
            (#"<function=([^>]+)>(.*?)</function>"#, true),
            (#"<tool_call>\s*<function=([a-z_]+)\s*>?\s*[\s\S]*?</tool_call>"#, false),
            (#"<function=([a-z_]+)\s*/?>"#, false),
        ]

        for (pattern, hasBody) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let nameRange = Range(match.range(at: 1), in: text) else { continue }

            let name = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let body: String
            if hasBody, match.numberOfRanges > 2, let bodyRange = Range(match.range(at: 2), in: text) {
                body = String(text[bodyRange])
            } else if let fullRange = Range(match.range, in: text) {
                body = String(text[fullRange])
            } else {
                body = text
            }
            return ParsedToolCall(name: name, arguments: parseXMLParameters(body))
        }

        // Pattern 5: JSON in <tool_call> tags
        let jsonPattern = #"<tool_call>\s*(\{[\s\S]*?\})\s*</tool_call>"#
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let jsonRange = Range(match.range(at: 1), in: text) {
                let jsonStr = String(text[jsonRange])
                if let data = jsonStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let name = dict["name"] as? String {
                    let argsDict = dict["arguments"] as? [String: Any] ?? [:]
                    var args: [String: String] = [:]
                    for (k, v) in argsDict { args[k] = "\(v)" }
                    return ParsedToolCall(name: name, arguments: args)
                }
            }
        }

        return nil
    }

    private static func parseXMLParameters(_ body: String) -> [String: String] {
        var args: [String: String] = [:]
        let paramPattern = #"<parameter=([^>]+)>([\s\S]*?)</parameter>"#
        guard let regex = try? NSRegularExpression(pattern: paramPattern, options: [.dotMatchesLineSeparators]) else { return args }
        let range = NSRange(body.startIndex..., in: body)
        for match in regex.matches(in: body, range: range) {
            if let keyRange = Range(match.range(at: 1), in: body),
               let valRange = Range(match.range(at: 2), in: body) {
                let key = String(body[keyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(body[valRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                args[key] = value
            }
        }
        return args
    }

    private static func makeToolCall(from parsed: ParsedToolCall) -> ToolCall {
        ToolCall(function: .init(name: parsed.name, arguments: parsed.arguments))
    }

    private static func stringArguments(from toolCall: ToolCall) -> [String: String] {
        var args: [String: String] = [:]
        for (key, value) in toolCall.function.arguments {
            args[key] = value.stringValue ?? "\(value.anyValue)"
        }
        return args
    }

    // MARK: - Repetition Detection

    private static func hasRepetition(_ text: String) -> Bool {
        if hasRepeatedLine(text, minimumRepeats: 3) { return true }

        let checkLen = min(text.count, 600)
        guard checkLen >= 48 else { return false }
        let tail = String(text.suffix(checkLen))

        for patternLen in stride(from: 12, through: min(160, checkLen / 3), by: 4) {
            let pattern = String(tail.suffix(patternLen))
            var count = 0
            var remaining = tail
            while remaining.hasSuffix(pattern) {
                count += 1
                remaining = String(remaining.dropLast(patternLen))
            }
            if count >= 3 { return true }
        }
        return false
    }

    private static func trimRepetition(_ text: String) -> String {
        if let deduped = trimRepeatedLines(text, minimumRepeats: 3) { return deduped }

        let checkLen = min(text.count, 800)
        guard checkLen >= 48 else { return text }
        let tail = String(text.suffix(checkLen))

        for patternLen in stride(from: 12, through: min(160, checkLen / 3), by: 4) {
            let pattern = String(tail.suffix(patternLen))
            var count = 0
            var remaining = tail
            while remaining.hasSuffix(pattern) {
                count += 1
                remaining = String(remaining.dropLast(patternLen))
            }
            if count >= 3 {
                let trimPoint = text.count - (count * patternLen) + patternLen
                return String(text.prefix(trimPoint)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }

    private static func hasRepeatedLine(_ text: String, minimumRepeats: Int) -> Bool {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count >= minimumRepeats else { return false }
        let suffix = Array(lines.suffix(minimumRepeats))
        guard let first = suffix.first else { return false }
        return suffix.allSatisfy { $0 == first && $0.count >= 12 }
    }

    private static func trimRepeatedLines(_ text: String, minimumRepeats: Int) -> String? {
        var lines = text.components(separatedBy: .newlines)
        guard lines.count >= minimumRepeats else { return nil }

        while lines.count >= minimumRepeats {
            let trimmed = lines.suffix(minimumRepeats).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let first = trimmed.first, !first.isEmpty, first.count >= 12 else { break }
            if trimmed.allSatisfy({ $0 == first }) {
                lines.removeLast()
            } else {
                break
            }
        }

        let result = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    // MARK: - Think Tag Stripping

    static func stripThinkingTags(_ text: String) -> String {
        var result = text
        let pattern = #"<think>[\s\S]*?</think>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        if let closeRange = result.range(of: "</think>") {
            let after = String(result[closeRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if after.count >= 2 {
                result = after
            } else {
                result = result.replacingOccurrences(of: "</think>", with: "")
            }
        }
        if let openRange = result.range(of: "<think>") {
            let before = String(result[..<openRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if before.count >= 2 {
                result = before
            } else {
                result = result.replacingOccurrences(of: "<think>", with: "")
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - JSONValue Helpers

extension JSONValue {
    nonisolated var stringValue: String? {
        switch self {
        case .string(let s): return s
        default: return nil
        }
    }
}
