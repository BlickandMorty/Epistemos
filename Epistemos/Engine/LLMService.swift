import Foundation
import Observation
import os

// MARK: - LLMClientProtocol

@MainActor
protocol LLMClientProtocol: AnyObject {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String
    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error>
    func testConnection() async -> ConnectionTestResult
    func configSnapshot() -> LLMSnapshot
}

@MainActor
protocol LocalConfigurableLLMClient: LLMClientProtocol {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) async throws -> String
    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error>
}

@MainActor
protocol CloudConfigurableLLMClient: LLMClientProtocol {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode
    ) async throws -> String
    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode
    ) -> AsyncThrowingStream<String, Error>

    /// Generate a structured response constrained to a JSON schema.
    /// Returns the decoded value + raw JSON string for storage/export.
    func generateStructured<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode,
        schema: CloudJSONSchema,
        type: T.Type
    ) async throws -> StructuredGenerationResult<T>
}

// Default fallback: parse generate() result as JSON. Providers that don't
// support native structured output (Google, ZAI, Kimi, etc.) use this.
extension CloudConfigurableLLMClient {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID
    ) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            model: model,
            operatingMode: .fast
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            model: model,
            operatingMode: .fast
        )
    }

    func generateStructured<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode,
        schema: CloudJSONSchema,
        type: T.Type
    ) async throws -> StructuredGenerationResult<T> {
        // Augment prompt to request JSON output
        let augmented = prompt + "\n\nRespond with valid JSON matching this schema: \(schema.name). Output ONLY the JSON object, no markdown fences."
        let raw = try await generate(
            prompt: augmented,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            model: model,
            operatingMode: operatingMode
        )
        // Strip markdown fences if the model wrapped the JSON
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8), !cleaned.isEmpty else {
            throw StructuredOutputError.emptyResponse
        }
        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            return StructuredGenerationResult(value: value, rawJSON: cleaned)
        } catch {
            throw StructuredOutputError.decodingFailed(underlyingError: error, rawJSON: cleaned)
        }
    }

    func generateStructured<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        schema: CloudJSONSchema,
        type: T.Type
    ) async throws -> StructuredGenerationResult<T> {
        try await generateStructured(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            model: model,
            operatingMode: .fast,
            schema: schema,
            type: type
        )
    }
}

extension LocalConfigurableLLMClient {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode
    ) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: nil,
            steeringHintsJSON: nil
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: nil,
            steeringHintsJSON: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            steeringHintsJSON: nil
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID,
            steeringHintsJSON: nil
        )
    }
}

extension LLMClientProtocol {
    func generate(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 4096) async throws -> String {
        try await generate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }

    func stream(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 0) -> AsyncThrowingStream<String, Error> {
        stream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }
}

// MARK: - LLM Service

extension LLMProviderType {
    nonisolated static func localProvider(runtimeKind: BackendRuntimeKind) -> Self {
        switch runtimeKind {
        case .gguf:
            .localGGUF
        case .mlx, .remote:
            .localMLX
        }
    }

    nonisolated static func localProvider(modelID: String?) -> Self {
        guard let modelID, let localModel = LocalTextModelID(rawValue: modelID) else {
            return .localMLX
        }
        return localProvider(runtimeKind: localModel.runtimeKind)
    }
}

/// Shared text generation gateway for older subsystems that still expect
/// a single generation service. It exposes the current Apple Intelligence vs.
/// local Qwen snapshot without duplicating the higher-level triage engine.
@MainActor @Observable
final class LLMService: LLMClientProtocol {
    private let inference: InferenceState
    private let localLLMClient: (any LLMClientProtocol)?
    private let cloudLLMClient: (any LLMClientProtocol)?

    init(
        inference: InferenceState,
        localLLMClient: (any LLMClientProtocol)? = nil,
        cloudLLMClient: (any LLMClientProtocol)? = nil
    ) {
        self.inference = inference
        self.localLLMClient = localLLMClient
        self.cloudLLMClient = cloudLLMClient
    }

    func generate(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 4096) async throws -> String {
        let snapshot = configSnapshot()
        return try await Self.generate(
            snapshot: snapshot,
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
    }

    func stream(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 0) -> AsyncThrowingStream<String, Error> {
        let snapshot = configSnapshot()
        switch snapshot.provider {
        case .appleIntelligence:
            return StreamingBufferPolicy.throwingStream { continuation in
                let task = Task {
                    do {
                        let result = try await AppleIntelligenceService.shared.generate(
                            prompt: prompt,
                            systemPrompt: systemPrompt
                        )
                        continuation.yield(result)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }

        case .localGGUF, .localMLX:
            guard let localLLMClient else {
                return StreamingBufferPolicy.throwingStream { continuation in
                    continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
                }
            }

            if let configurable = localLLMClient as? any LocalConfigurableLLMClient {
                return configurable.stream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: snapshot.reasoningMode,
                    modelID: snapshot.model.isEmpty ? nil : snapshot.model
                )
            }

            return localLLMClient.stream(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        case .openAI, .anthropic, .google, .zai, .kimi, .minimax, .deepseek:
            guard let cloudLLMClient else {
                return StreamingBufferPolicy.throwingStream { continuation in
                    continuation.finish(throwing: CloudLLMError.runtimeUnavailable)
                }
            }
            return cloudLLMClient.stream(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        }
    }

    func testConnection() async -> ConnectionTestResult {
        if case .cloud = inference.preferredChatModelSelection,
           let cloudLLMClient {
            return await cloudLLMClient.testConnection()
        }

        if inference.hasUsableLocalTextModel,
           let localLLMClient {
            return await localLLMClient.testConnection()
        }

        let availability = AppleIntelligenceService.shared.checkAvailability()
        if availability.available {
            return ConnectionTestResult(
                success: true,
                message: "Apple Intelligence available"
            )
        }

        return ConnectionTestResult(
            success: false,
            message: availability.reason ?? "No local model is available and Apple Intelligence is unavailable."
        )
    }

    func configSnapshot() -> LLMSnapshot {
        resolvedSnapshot()
    }

    private func resolvedSnapshot() -> LLMSnapshot {
        if case .cloud(let model) = inference.preferredChatModelSelection {
            return LLMSnapshot(
                provider: model.provider.llmProviderType,
                model: model.vendorModelID,
                reasoningMode: .fast
            )
        }

        if let localLLMClient {
            let localSnapshot = localLLMClient.configSnapshot()
            if localSnapshot.provider != .appleIntelligence || inference.hasUsableLocalTextModel {
                return localSnapshot
            }
        }

        if let modelID = inference.activeLocalTextModelID {
            return LLMSnapshot(
                provider: .localProvider(modelID: modelID),
                model: modelID,
                reasoningMode: .fast
            )
        }

        return LLMSnapshot(
            provider: .appleIntelligence,
            model: "",
            reasoningMode: .fast
        )
    }

    nonisolated static func generate(
        snapshot: LLMSnapshot,
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 4096,
        timeout: TimeInterval? = nil
    ) async throws -> String {
        _ = timeout
        switch snapshot.provider {
        case .appleIntelligence:
            return try await AppleIntelligenceService.shared.generate(
                prompt: prompt,
                systemPrompt: systemPrompt
            )

        case .localGGUF, .localMLX:
            return try await sharedLocalGenerate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: snapshot.reasoningMode,
                modelID: snapshot.model.isEmpty ? nil : snapshot.model
            )
        case .openAI, .anthropic, .google, .zai, .kimi, .minimax, .deepseek:
            return try await sharedCloudGenerate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        }
    }

    @MainActor
    private static func sharedLocalGenerate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) async throws -> String {
        guard let localLLMClient = AppBootstrap.shared?.localLLMClient else {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }

        return try await localLLMClient.generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID
        )
    }

    @MainActor
    private static func sharedCloudGenerate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        guard let cloudLLMClient = AppBootstrap.shared?.cloudLLMClient else {
            throw CloudLLMError.runtimeUnavailable
        }

        return try await cloudLLMClient.generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
    }
}

// MARK: - LLM Snapshot

nonisolated struct LLMSnapshot: Sendable {
    let provider: LLMProviderType
    let model: String
    let reasoningMode: LocalReasoningMode
}

nonisolated struct ProcessActivityToken: Sendable {
    nonisolated(unsafe) fileprivate let raw: NSObjectProtocol

    init(raw: NSObjectProtocol) {
        self.raw = raw
    }
}

nonisolated struct ProcessActivityManager: Sendable {
    let begin: @Sendable (String, ProcessInfo.ActivityOptions) -> ProcessActivityToken
    let end: @Sendable (ProcessActivityToken) -> Void

    static let live = ProcessActivityManager(
        begin: { reason, options in
            ProcessActivityToken(
                raw: ProcessInfo.processInfo.beginActivity(options: options, reason: reason)
            )
        },
        end: { token in
            ProcessInfo.processInfo.endActivity(token.raw)
        }
    )
}

nonisolated enum ProcessActivity {
    @MainActor
    static func withActivityOnMainActor<T>(
        reason: String,
        options: ProcessInfo.ActivityOptions = .userInitiatedAllowingIdleSystemSleep,
        manager: ProcessActivityManager = .live,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let token = manager.begin(reason, options)
        defer { manager.end(token) }
        return try await operation()
    }

    static func withActivity<T>(
        reason: String,
        options: ProcessInfo.ActivityOptions = .userInitiatedAllowingIdleSystemSleep,
        manager: ProcessActivityManager = .live,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let token = manager.begin(reason, options)
        defer { manager.end(token) }
        return try await operation()
    }

    static func makeStream<Element>(
        reason: String,
        options: ProcessInfo.ActivityOptions = .userInitiatedAllowingIdleSystemSleep,
        manager: ProcessActivityManager = .live,
        _ operation: @escaping @Sendable (AsyncThrowingStream<Element, Error>.Continuation) async -> Void
    ) -> AsyncThrowingStream<Element, Error> {
        StreamingBufferPolicy.throwingStream { continuation in
            let token = manager.begin(reason, options)
            let task = Task.detached(priority: .userInitiated) {
                defer { manager.end(token) }
                await operation(continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Errors

nonisolated enum LLMError: LocalizedError {
    case apiError(statusCode: Int, body: String)

    var isTransient: Bool {
        switch self {
        case .apiError(let code, _): code == 429 || code == 529 || code == 503 || code == 502
        }
    }

    var isAuthError: Bool {
        switch self {
        case .apiError(let code, _):
            return code == 401 || code == 403
        }
    }

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body):
            if code == 0, !body.isEmpty {
                return body
            }
            switch code {
            case 401:
                return "Authentication failed (401). Check the selected provider API key in Settings."
            case 403:
                return "The selected provider rejected this request (403). Verify model access and API permissions."
            case 404:
                return "The selected AI provider could not find the requested model or endpoint (404). Re-check provider status or choose a different model."
            case 429:
                return "The selected AI provider is rate-limiting requests right now (429). Please wait a moment and try again."
            case 502:
                return "The selected AI provider returned a bad gateway response (502). Please try again shortly."
            case 503:
                return "The selected AI provider is temporarily unavailable (503). Please try again shortly."
            default:
                if code == 400, body.contains("client_version") {
                    return "OpenAI account setup is missing a required client version marker. Retry OpenAI sign-in and then run the live check again."
                }
                if !body.isEmpty {
                    return "AI provider error \(code): \(body)"
                }
                return "AI provider error \(code)."
            }
        }
    }
}

nonisolated struct ConnectionTestResult: Sendable {
    var success: Bool
    var message: String
}

extension CloudModelProvider {
    fileprivate var llmProviderType: LLMProviderType {
        switch self {
        case .openAI: .openAI
        case .anthropic: .anthropic
        case .google: .google
        case .zai: .zai
        case .kimi: .kimi
        case .minimax: .minimax
        case .deepseek: .deepseek
        }
    }
}

@MainActor
final class CloudLLMClient: CloudConfigurableLLMClient {
    private static let log = Logger(subsystem: "com.epistemos.llm", category: "CloudLLMClient")

    nonisolated struct VisionPayload: Equatable, Sendable {
        let mimeType: String
        let base64Data: String

        var dataURL: String {
            "data:\(mimeType);base64,\(base64Data)"
        }
    }

    private let inference: InferenceState
    private let urlSession: URLSession
    private let knowledgeProfileStore: KnowledgeProfileStore

    init(
        inference: InferenceState,
        urlSession: URLSession = .shared,
        knowledgeProfileStore: KnowledgeProfileStore = KnowledgeProfileStore()
    ) {
        self.inference = inference
        self.urlSession = urlSession
        self.knowledgeProfileStore = knowledgeProfileStore
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            model: try selectedCloudModel(),
            operatingMode: .fast
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode
    ) async throws -> String {
        let credential = try await resolvedCredential(for: model.provider)
        let resolvedSystemPrompt = await knowledgeAwareSystemPrompt(
            from: systemPrompt,
            modelID: model.vendorModelID
        )

        switch model.provider {
        case .openAI:
            return try await generateOpenAI(
                model: model,
                credential: credential,
                prompt: prompt,
                systemPrompt: resolvedSystemPrompt,
                maxTokens: maxTokens,
                operatingMode: operatingMode
            )
        case .anthropic:
            return try await generateAnthropic(
                model: model,
                credential: credential,
                prompt: prompt,
                systemPrompt: resolvedSystemPrompt,
                maxTokens: maxTokens
            )
        case .google:
            return try await generateGoogle(
                model: model,
                credential: credential,
                prompt: prompt,
                systemPrompt: resolvedSystemPrompt,
                maxTokens: maxTokens
            )
        case .zai, .kimi, .deepseek:
            return try await generateOpenAICompatible(
                provider: model.provider,
                model: model,
                credential: credential,
                prompt: prompt,
                systemPrompt: resolvedSystemPrompt,
                maxTokens: maxTokens
            )
        case .minimax:
            return try await generateAnthropicCompatible(
                provider: .minimax,
                model: model,
                credential: credential,
                prompt: prompt,
                systemPrompt: resolvedSystemPrompt,
                maxTokens: maxTokens
            )
        }
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        let selectedModel: CloudTextModelID
        do {
            selectedModel = try selectedCloudModel()
        } catch {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: error)
            }
        }

        return stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            model: selectedModel,
            operatingMode: .fast
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode
    ) -> AsyncThrowingStream<String, Error> {
        StreamingBufferPolicy.throwingStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                do {
                    let credential = try await self.resolvedCredential(for: model.provider)
                    let resolvedSystemPrompt = await self.knowledgeAwareSystemPrompt(
                        from: systemPrompt,
                        modelID: model.vendorModelID
                    )

                    let upstream: AsyncThrowingStream<String, Error>
                    switch model.provider {
                    case .openAI:
                        upstream = self.streamOpenAI(
                            model: model,
                            credential: credential,
                            prompt: prompt,
                            systemPrompt: resolvedSystemPrompt,
                            maxTokens: maxTokens,
                            operatingMode: operatingMode
                        )
                    case .anthropic:
                        upstream = self.streamAnthropic(
                            model: model,
                            credential: credential,
                            prompt: prompt,
                            systemPrompt: resolvedSystemPrompt,
                            maxTokens: maxTokens
                        )
                    case .google:
                        upstream = self.streamGoogle(
                            model: model,
                            credential: credential,
                            prompt: prompt,
                            systemPrompt: resolvedSystemPrompt,
                            maxTokens: maxTokens
                        )
                    case .zai, .kimi, .deepseek:
                        upstream = self.streamOpenAICompatible(
                            provider: model.provider,
                            model: model,
                            credential: credential,
                            prompt: prompt,
                            systemPrompt: resolvedSystemPrompt,
                            maxTokens: maxTokens
                        )
                    case .minimax:
                        upstream = self.streamAnthropicCompatible(
                            provider: .minimax,
                            model: model,
                            credential: credential,
                            prompt: prompt,
                            systemPrompt: resolvedSystemPrompt,
                            maxTokens: maxTokens
                        )
                    }

                    for try await token in upstream {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Structured Output (provider-native)

    func generateStructured<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode,
        schema: CloudJSONSchema,
        type: T.Type
    ) async throws -> StructuredGenerationResult<T> {
        let credential = try await resolvedCredential(for: model.provider)
        let resolvedSystemPrompt = await knowledgeAwareSystemPrompt(
            from: systemPrompt,
            modelID: model.vendorModelID
        )

        switch model.provider {
        case .openAI:
            // o3/o3-mini may not support json_schema — fall back to prompt-based
            if !model.supportsStructuredOutput {
                // Use default protocol extension (prompt-based fallback)
                let augmented = prompt + "\n\nRespond with valid JSON matching schema: \(schema.name). Output ONLY the JSON, no fences."
                let raw = try await generateOpenAI(
                    model: model,
                    credential: credential,
                    prompt: augmented,
                    systemPrompt: resolvedSystemPrompt,
                    maxTokens: maxTokens,
                    operatingMode: operatingMode
                )
                let cleaned = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard let data = cleaned.data(using: .utf8) else { throw StructuredOutputError.emptyResponse }
                do {
                    let value = try JSONDecoder().decode(T.self, from: data)
                    return StructuredGenerationResult(value: value, rawJSON: cleaned)
                } catch {
                    throw StructuredOutputError.decodingFailed(underlyingError: error, rawJSON: cleaned)
                }
            }
            return try await generateStructuredOpenAI(
                model: model, credential: credential, prompt: prompt,
                systemPrompt: resolvedSystemPrompt, maxTokens: maxTokens,
                operatingMode: operatingMode,
                schema: schema, type: type
            )
        case .anthropic:
            return try await generateStructuredAnthropic(
                model: model, credential: credential, prompt: prompt,
                systemPrompt: resolvedSystemPrompt, maxTokens: maxTokens,
                schema: schema, type: type
            )
        default:
            // Other providers: use prompt-based fallback (default protocol extension)
            let augmented = prompt + "\n\nRespond with valid JSON matching schema: \(schema.name). Output ONLY the JSON, no fences."
            let raw = try await generate(
                prompt: augmented,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                model: model,
                operatingMode: operatingMode
            )
            let cleaned = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = cleaned.data(using: .utf8) else { throw StructuredOutputError.emptyResponse }
            do {
                let value = try JSONDecoder().decode(T.self, from: data)
                return StructuredGenerationResult(value: value, rawJSON: cleaned)
            } catch {
                throw StructuredOutputError.decodingFailed(underlyingError: error, rawJSON: cleaned)
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        do {
            let model = try selectedCloudModel()
            return await testConnection(provider: model.provider, model: model)
        } catch {
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func testConnection(
        provider: CloudModelProvider,
        model: CloudTextModelID? = nil
    ) async -> ConnectionTestResult {
        do {
            let credential = try await resolvedCredential(for: provider)
            if let model {
                try await testModelConnection(provider: provider, credential: credential, model: model)
                return ConnectionTestResult(
                    success: true,
                    message: "Connected to \(provider.displayName) via \(model.compactDisplayName)"
                )
            }

            return ConnectionTestResult(
                success: true,
                message: try await validateProviderAuthorization(provider: provider, credential: credential)
            )
        } catch {
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func configSnapshot() -> LLMSnapshot {
        guard let model = try? selectedCloudModel() else {
            return LLMSnapshot(provider: .openAI, model: "", reasoningMode: .fast)
        }
        return LLMSnapshot(
            provider: model.provider.llmProviderType,
            model: model.vendorModelID,
            reasoningMode: .fast
        )
    }

    private func selectedCloudModel() throws -> CloudTextModelID {
        guard case .cloud(let model) = inference.preferredChatModelSelection else {
            throw CloudLLMError.modelRequired
        }
        return model
    }

    private func resolvedCredential(for provider: CloudModelProvider) async throws -> CloudProviderResolvedCredential {
        do {
            return try await inference.resolvedCloudCredential(for: provider)
        } catch let error as CloudProviderAuthError {
            switch error {
            case .missingOAuthSession:
                throw CloudLLMError.missingAccess(provider.displayName)
            default:
                throw error
            }
        }
    }

    private func knowledgeAwareSystemPrompt(from systemPrompt: String?, modelID: String) async -> String? {
        do {
            return try await knowledgeProfileStore.augmentedSystemPrompt(
                existingPrompt: systemPrompt,
                modelID: modelID,
                budget: .full
            )
        } catch {
            Self.log.error(
                "Failed to load model vault prompt context for \(modelID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return systemPrompt
        }
    }

    private func resolvedVisionPayloads(for model: CloudTextModelID) -> [VisionPayload] {
        guard model.supportsVision, !inference.pendingImageURLs.isEmpty else { return [] }

        var payloads: [VisionPayload] = []
        payloads.reserveCapacity(inference.pendingImageURLs.count)
        for imageURL in inference.pendingImageURLs {
            do {
                payloads.append(try Self.visionPayload(for: imageURL))
            } catch {
                Self.log.warning(
                    "Skipping unreadable vision attachment at \(imageURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        return payloads
    }

    private func testModelConnection(
        provider: CloudModelProvider,
        credential: CloudProviderResolvedCredential,
        model: CloudTextModelID
    ) async throws {
        switch provider {
        case .openAI:
            _ = try await generateOpenAI(
                model: model,
                credential: credential,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16,
                operatingMode: .fast
            )
        case .anthropic:
            _ = try await generateAnthropic(
                model: model,
                credential: credential,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16
            )
        case .google:
            _ = try await generateGoogle(
                model: model,
                credential: credential,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16
            )
        case .zai, .kimi, .deepseek:
            _ = try await generateOpenAICompatible(
                provider: provider,
                model: model,
                credential: credential,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16
            )
        case .minimax:
            _ = try await generateAnthropicCompatible(
                provider: provider,
                model: model,
                credential: credential,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16
            )
        }
    }

    private func validateProviderAuthorization(
        provider: CloudModelProvider,
        credential: CloudProviderResolvedCredential
    ) async throws -> String {
        if provider == .minimax {
            try await testModelConnection(
                provider: provider,
                credential: credential,
                model: provider.validationModel
            )
            return "Connected to \(provider.displayName) via \(provider.validationModel.compactDisplayName)."
        }

        let request = try providerAuthorizationRequest(provider: provider, credential: credential)
        let json = try await sendJSON(request)
        let supportedModelCount = supportedProviderModelCount(in: json, provider: provider)
        if supportedModelCount > 0 {
            return "Connected to \(provider.displayName). \(supportedModelCount) supported models are available."
        }
        return "Connected to \(provider.displayName)."
    }

    private func providerAuthorizationRequest(
        provider: CloudModelProvider,
        credential: CloudProviderResolvedCredential
    ) throws -> URLRequest {
        switch provider {
        case .openAI:
            guard let url = openAIRequestURL(path: "/models", credential: credential) else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(openAIAuthorizationHeader(for: credential), forHTTPHeaderField: "Authorization")
            return request
        case .anthropic:
            guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            applyAnthropicAuthorization(credential, provider: .anthropic, to: &request)
            return request
        case .google:
            return try googleModelsRequest(for: credential)
        case .zai, .kimi, .deepseek:
            guard let url = URL(string: try openAICompatibleBaseURL(for: provider, credential: credential) + "/models") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(openAICompatibleAuthorizationHeader(for: credential), forHTTPHeaderField: "Authorization")
            return request
        case .minimax:
            throw CloudLLMError.invalidResponse
        }
    }

    private func supportedProviderModelCount(
        in json: [String: Any],
        provider: CloudModelProvider
    ) -> Int {
        let supportedModelIDs = Set(CloudTextModelID.models(for: provider).map(\.vendorModelID))
        let availableModelIDs = availableProviderModelIDs(in: json, provider: provider)
        guard !availableModelIDs.isEmpty else { return 0 }
        return supportedModelIDs.intersection(availableModelIDs).count
    }

    private func availableProviderModelIDs(
        in json: [String: Any],
        provider: CloudModelProvider
    ) -> Set<String> {
        switch provider {
        case .openAI:
            let responseModels = json["data"] as? [[String: Any]] ?? []
            let responseIDs = responseModels.compactMap { $0["id"] as? String }
            if !responseIDs.isEmpty {
                return Set(responseIDs)
            }
            let codexModels = json["models"] as? [[String: Any]] ?? []
            return Set(codexModels.compactMap { $0["slug"] as? String })
        case .anthropic, .zai, .kimi, .deepseek:
            let models = json["data"] as? [[String: Any]] ?? []
            return Set(models.compactMap { $0["id"] as? String })
        case .google:
            let models = json["models"] as? [[String: Any]] ?? []
            return Set(
                models.compactMap { $0["name"] as? String }
                    .map { $0.replacingOccurrences(of: "models/", with: "") }
            )
        case .minimax:
            return []
        }
    }

    private func generateOpenAI(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        operatingMode: EpistemosOperatingMode
    ) async throws -> String {
        let resolvedModel = compatibleOpenAIModel(model, credential: credential)
        let input: [[String: Any]] = [[
            "role": "user",
            "content": Self.openAIUserContent(
                prompt: prompt,
                imagePayloads: resolvedVisionPayloads(for: resolvedModel)
            )
        ]]

        if case .openAICodex = credential {
            let request = try makeOpenAIResponsesRequest(
                model: resolvedModel,
                credential: credential,
                input: input,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                operatingMode: operatingMode,
                stream: true
            )
            return try await collectOpenAIResponseText(from: request)
        }

        var body: [String: Any] = [
            "model": resolvedModel.vendorModelID,
            "input": input,
            "store": false,
        ]
        if let instructions = openAIResponsesInstructions(
            systemPrompt: systemPrompt,
            credential: credential
        ) {
            body["instructions"] = instructions
        }
        if maxTokens > 0 {
            body["max_output_tokens"] = maxTokens
        }
        applyOpenAIResponsesControls(
            to: &body,
            model: resolvedModel,
            operatingMode: operatingMode,
            credential: credential
        )
        let tools = openAIToolsConfiguration()
        if !tools.isEmpty {
            body["tools"] = tools
        }

        guard let url = openAIRequestURL(path: "/responses", credential: credential) else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(openAIAuthorizationHeader(for: credential), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await sendJSON(request)
        if let text = json["output_text"] as? String, !text.isEmpty {
            return text
        }
        if let output = json["output"] as? [[String: Any]] {
            let text = output
                .compactMap { item in item["content"] as? [[String: Any]] }
                .flatMap { $0 }
                .compactMap { item in item["text"] as? String }
                .joined()
            if !text.isEmpty { return text }
        }
        throw CloudLLMError.invalidResponse
    }

    /// OpenAI structured output via the Responses API `text.format` block.
    /// Uses `json_schema` type to guarantee valid JSON matching the schema.
    private func generateStructuredOpenAI<T: Decodable & Sendable>(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        operatingMode: EpistemosOperatingMode,
        schema: CloudJSONSchema,
        type: T.Type
    ) async throws -> StructuredGenerationResult<T> {
        let resolvedModel = compatibleOpenAIModel(model, credential: credential)
        let input: [[String: Any]] = [[
            "role": "user",
            "content": Self.openAIUserContent(
                prompt: prompt,
                imagePayloads: resolvedVisionPayloads(for: resolvedModel)
            )
        ]]

        if case .openAICodex = credential {
            let request = try makeOpenAIResponsesRequest(
                model: resolvedModel,
                credential: credential,
                input: input,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                operatingMode: operatingMode,
                schema: schema,
                stream: true
            )
            let rawText = try await collectOpenAIResponseText(from: request)
            guard let data = rawText.data(using: .utf8) else {
                throw StructuredOutputError.emptyResponse
            }
            do {
                let value = try JSONDecoder().decode(T.self, from: data)
                return StructuredGenerationResult(value: value, rawJSON: rawText)
            } catch {
                throw StructuredOutputError.decodingFailed(underlyingError: error, rawJSON: rawText)
            }
        }

        var body: [String: Any] = [
            "model": resolvedModel.vendorModelID,
            "input": input,
            "store": false,
        ]
        if let instructions = openAIResponsesInstructions(
            systemPrompt: systemPrompt,
            credential: credential
        ) {
            body["instructions"] = instructions
        }
        if maxTokens > 0 {
            body["max_output_tokens"] = maxTokens
        }
        applyOpenAIResponsesControls(
            to: &body,
            model: resolvedModel,
            operatingMode: operatingMode,
            credential: credential
        )
        let tools = openAIToolsConfiguration()
        if !tools.isEmpty {
            body["tools"] = tools
        }

        // Structured output: constrain response to JSON schema.
        // https://platform.openai.com/docs/guides/structured-outputs
        var formatSchema: [String: Any] = [
            "type": "json_schema",
            "name": schema.name,
            "schema": schema.schema,
            "strict": schema.strict,
        ]
        if let desc = schema.description {
            formatSchema["description"] = desc
        }
        body["text"] = ["format": formatSchema]

        guard let url = openAIRequestURL(path: "/responses", credential: credential) else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(openAIAuthorizationHeader(for: credential), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await sendJSON(request)
        // Extract raw text from response
        let rawText: String
        if let text = json["output_text"] as? String, !text.isEmpty {
            rawText = text
        } else if let output = json["output"] as? [[String: Any]] {
            let text = output
                .compactMap { item in item["content"] as? [[String: Any]] }
                .flatMap { $0 }
                .compactMap { item in item["text"] as? String }
                .joined()
            guard !text.isEmpty else { throw StructuredOutputError.emptyResponse }
            rawText = text
        } else {
            throw StructuredOutputError.emptyResponse
        }

        // Decode into the requested type
        guard let data = rawText.data(using: .utf8) else {
            throw StructuredOutputError.emptyResponse
        }
        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            return StructuredGenerationResult(value: value, rawJSON: rawText)
        } catch {
            throw StructuredOutputError.decodingFailed(underlyingError: error, rawJSON: rawText)
        }
    }

    private func streamOpenAI(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        operatingMode: EpistemosOperatingMode
    ) -> AsyncThrowingStream<String, Error> {
        let resolvedModel = compatibleOpenAIModel(model, credential: credential)
        let input: [[String: Any]] = [[
            "role": "user",
            "content": Self.openAIUserContent(
                prompt: prompt,
                imagePayloads: resolvedVisionPayloads(for: resolvedModel)
            )
        ]]

        let request: URLRequest
        do {
            request = try makeOpenAIResponsesRequest(
                model: resolvedModel,
                credential: credential,
                input: input,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                operatingMode: operatingMode,
                stream: true
            )
        } catch {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }

        return streamSSE(request) { json in
            CloudStreamingParser.openAITextDelta(from: json)
        }
    }

    private func generateAnthropic(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        try await generateAnthropicCompatible(
            provider: .anthropic,
            model: model,
            credential: credential,
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
    }

    /// Anthropic structured output via forced tool_use.
    /// Defines a tool whose input_schema matches the desired JSON schema,
    /// then forces the model to call it via tool_choice. The structured
    /// JSON appears in the `input` field of the `tool_use` content block.
    private func generateStructuredAnthropic<T: Decodable & Sendable>(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        schema: CloudJSONSchema,
        type: T.Type
    ) async throws -> StructuredGenerationResult<T> {
        let resolvedMaxTokens = resolvedAnthropicMaxTokens(requestedMaxTokens: maxTokens)
        let imagePayloads = resolvedVisionPayloads(for: model)
        let messageContent: Any = imagePayloads.isEmpty
            ? prompt
            : Self.anthropicMessageContent(prompt: prompt, imagePayloads: imagePayloads)
        var body: [String: Any] = [
            "model": model.vendorModelID,
            "messages": [[
                "role": "user",
                "content": messageContent
            ]],
            "max_tokens": resolvedMaxTokens,
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }
        if let thinking = anthropicThinkingConfiguration(maxTokens: resolvedMaxTokens) {
            body["thinking"] = thinking
        }
        // Define a tool whose input_schema = the desired output schema
        var toolDef: [String: Any] = [
            "name": schema.name,
            "input_schema": schema.schema,
        ]
        if let desc = schema.description {
            toolDef["description"] = desc
        }
        body["tools"] = [toolDef]
        // Force the model to call this specific tool
        body["tool_choice"] = ["type": "tool", "name": schema.name]

        guard let url = URL(string: anthropicBaseURL(for: .anthropic) + "/v1/messages") else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAnthropicAuthorization(credential, provider: .anthropic, to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await sendJSON(request)

        // Find the tool_use content block and extract its input
        guard let content = json["content"] as? [[String: Any]] else {
            throw StructuredOutputError.emptyResponse
        }
        guard let toolBlock = content.first(where: { ($0["type"] as? String) == "tool_use" }),
              let input = toolBlock["input"] else {
            throw StructuredOutputError.emptyResponse
        }
        // Serialize input back to JSON Data for decoding
        let inputData: Data
        if let inputDict = input as? [String: Any] {
            inputData = try JSONSerialization.data(withJSONObject: inputDict)
        } else if let inputArray = input as? [Any] {
            inputData = try JSONSerialization.data(withJSONObject: inputArray)
        } else {
            throw StructuredOutputError.emptyResponse
        }
        let rawJSON = String(data: inputData, encoding: .utf8) ?? "{}"
        do {
            let value = try JSONDecoder().decode(T.self, from: inputData)
            return StructuredGenerationResult(value: value, rawJSON: rawJSON)
        } catch {
            throw StructuredOutputError.decodingFailed(underlyingError: error, rawJSON: rawJSON)
        }
    }

    private func generateAnthropicCompatible(
        provider: CloudModelProvider,
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        let resolvedMaxTokens = resolvedAnthropicMaxTokens(requestedMaxTokens: maxTokens)
        let imagePayloads = resolvedVisionPayloads(for: model)
        let messageContent: Any = imagePayloads.isEmpty
            ? prompt
            : Self.anthropicMessageContent(prompt: prompt, imagePayloads: imagePayloads)
        var body: [String: Any] = [
            "model": model.vendorModelID,
            "messages": [
                [
                    "role": "user",
                    "content": messageContent,
                ]
            ],
            "max_tokens": resolvedMaxTokens,
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }
        if let thinking = anthropicThinkingConfiguration(maxTokens: resolvedMaxTokens) {
            body["thinking"] = thinking
        }

        guard let url = URL(string: anthropicBaseURL(for: provider) + "/v1/messages") else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAnthropicAuthorization(credential, provider: provider, to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await sendJSON(request)
        if let content = json["content"] as? [[String: Any]] {
            let text = content.compactMap { item in item["text"] as? String }.joined()
            if !text.isEmpty { return text }
        }
        throw CloudLLMError.invalidResponse
    }

    private func streamAnthropic(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        streamAnthropicCompatible(
            provider: .anthropic,
            model: model,
            credential: credential,
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
    }

    private func streamAnthropicCompatible(
        provider: CloudModelProvider,
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        let resolvedMaxTokens = resolvedAnthropicMaxTokens(requestedMaxTokens: maxTokens)
        let imagePayloads = resolvedVisionPayloads(for: model)
        let messageContent: Any = imagePayloads.isEmpty
            ? prompt
            : Self.anthropicMessageContent(prompt: prompt, imagePayloads: imagePayloads)
        var body: [String: Any] = [
            "model": model.vendorModelID,
            "messages": [
                [
                    "role": "user",
                    "content": messageContent,
                ]
            ],
            "max_tokens": resolvedMaxTokens,
            "stream": true,
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            if provider == .anthropic {
                // Prompt caching: send system as content blocks with cache_control.
                // The ephemeral marker on the last block enables prefix caching.
                // Subsequent turns with identical prefix get 90% input cost reduction.
                body["system"] = [
                    [
                        "type": "text",
                        "text": systemPrompt,
                        "cache_control": ["type": "ephemeral"]
                    ] as [String: Any]
                ]
            } else {
                body["system"] = systemPrompt
            }
        }
        if let thinking = anthropicThinkingConfiguration(maxTokens: resolvedMaxTokens) {
            body["thinking"] = thinking
        }

        guard let url = URL(string: anthropicBaseURL(for: provider) + "/v1/messages") else {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAnthropicAuthorization(credential, provider: provider, to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }

        return streamSSE(request) { json in
            CloudStreamingParser.anthropicTextDelta(from: json)
        }
    }

    private func generateOpenAICompatible(
        provider: CloudModelProvider,
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        var request = try openAICompatibleChatRequest(
            provider: provider,
            modelID: model.vendorModelID,
            credential: credential
        )
        request.httpBody = try JSONSerialization.data(
            withJSONObject: OpenAICompatibleChatSupport.completionBody(
                modelID: model.vendorModelID,
                prompt: prompt,
                systemPrompt: systemPrompt,
                imagePayloads: resolvedVisionPayloads(for: model),
                maxTokens: maxTokens,
                stream: false
            )
        )

        let json = try await sendJSON(request)
        guard let text = OpenAICompatibleChatSupport.messageText(from: json), !text.isEmpty else {
            throw CloudLLMError.invalidResponse
        }
        return text
    }

    private func streamOpenAICompatible(
        provider: CloudModelProvider,
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        let request: URLRequest
        do {
            var builtRequest = try openAICompatibleChatRequest(
                provider: provider,
                modelID: model.vendorModelID,
                credential: credential
            )
            builtRequest.httpBody = try JSONSerialization.data(
                withJSONObject: OpenAICompatibleChatSupport.completionBody(
                    modelID: model.vendorModelID,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    imagePayloads: resolvedVisionPayloads(for: model),
                    maxTokens: maxTokens,
                    stream: true
                )
            )
            request = builtRequest
        } catch {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }

        return streamSSE(request) { json in
            CloudStreamingParser.openAICompatibleTextDelta(from: json)
        }
    }

    private func generateGoogle(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        var body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": Self.googleParts(
                        prompt: prompt,
                        imagePayloads: resolvedVisionPayloads(for: model)
                    ),
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": maxTokens > 0 ? maxTokens : 2048
            ]
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }
        if inference.googleGroundingEnabled {
            body["tools"] = [
                [
                    "google_search": [:]
                ]
            ]
        }
        applyGoogleThinkingConfig(to: &body, model: model)

        var request = try googleContentRequest(
            modelID: model.vendorModelID,
            suffix: ":generateContent",
            credential: credential
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await sendJSON(request)
        if let candidates = json["candidates"] as? [[String: Any]] {
            let text = candidates
                .compactMap { $0["content"] as? [String: Any] }
                .compactMap { $0["parts"] as? [[String: Any]] }
                .flatMap { $0 }
                .compactMap { $0["text"] as? String }
                .joined()
            if !text.isEmpty { return text }
        }
        throw CloudLLMError.invalidResponse
    }

    private func streamGoogle(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        var body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": Self.googleParts(
                        prompt: prompt,
                        imagePayloads: resolvedVisionPayloads(for: model)
                    ),
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": maxTokens > 0 ? maxTokens : 2048
            ]
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }
        if inference.googleGroundingEnabled {
            body["tools"] = [
                [
                    "google_search": [:]
                ]
            ]
        }
        applyGoogleThinkingConfig(to: &body, model: model)

        let baseRequest: URLRequest
        do {
            baseRequest = try googleStreamRequest(modelID: model.vendorModelID, credential: credential)
        } catch {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }
        var request = baseRequest
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }

        return streamSSE(request) { json in
            CloudStreamingParser.googleTextDelta(from: json)
        }
    }

    private func openAIBaseURL(for credential: CloudProviderResolvedCredential) -> String {
        switch credential {
        case .openAICodex:
            "https://chatgpt.com/backend-api/codex"
        case .apiKey:
            "https://api.openai.com/v1"
        case .anthropicOAuth, .googleOAuth:
            "https://api.openai.com/v1"
        }
    }

    private func openAIRequestURL(
        path: String,
        credential: CloudProviderResolvedCredential
    ) -> URL? {
        let urlString = openAIBaseURL(for: credential) + path
        switch credential {
        case .openAICodex:
            return OpenAICodexRuntimeMetadata.url(appendingClientVersionTo: urlString)
        case .apiKey, .anthropicOAuth, .googleOAuth:
            return URL(string: urlString)
        }
    }

    private func openAICompatibleBaseURL(
        for provider: CloudModelProvider,
        credential: CloudProviderResolvedCredential
    ) throws -> String {
        guard case .apiKey(let token) = credential, !token.isEmpty else {
            throw CloudLLMError.invalidResponse
        }

        switch provider {
        case .zai:
            return "https://api.z.ai/api/paas/v4"
        case .kimi:
            return token.hasPrefix("sk-kimi-")
                ? "https://api.kimi.com/coding/v1"
                : "https://api.moonshot.ai/v1"
        case .deepseek:
            return "https://api.deepseek.com/v1"
        case .openAI, .anthropic, .google, .minimax:
            throw CloudLLMError.invalidResponse
        }
    }

    private func openAIAuthorizationHeader(for credential: CloudProviderResolvedCredential) -> String {
        switch credential {
        case .apiKey(let token),
             .openAICodex(let token):
            "Bearer \(token)"
        case .anthropicOAuth, .googleOAuth:
            "Bearer "
        }
    }

    private func openAICompatibleAuthorizationHeader(for credential: CloudProviderResolvedCredential) -> String {
        switch credential {
        case .apiKey(let token):
            "Bearer \(token)"
        case .openAICodex, .anthropicOAuth, .googleOAuth:
            "Bearer "
        }
    }

    private func applyAnthropicAuthorization(
        _ credential: CloudProviderResolvedCredential,
        provider: CloudModelProvider,
        to request: inout URLRequest
    ) {
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        switch credential {
        case .apiKey(let token):
            if provider == .minimax {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue(token, forHTTPHeaderField: "x-api-key")
                // Enable prompt caching + structured outputs for direct API key auth
                request.setValue(
                    "prompt-caching-2024-07-31,structured-outputs-2025-11-13",
                    forHTTPHeaderField: "anthropic-beta"
                )
            }
        case .anthropicOAuth(let accessToken):
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(
                "interleaved-thinking-2025-05-14,fine-grained-tool-streaming-2025-05-14,claude-code-20250219,oauth-2025-04-20",
                forHTTPHeaderField: "anthropic-beta"
            )
            request.setValue("claude-cli/2.1.74 (external, cli)", forHTTPHeaderField: "User-Agent")
            request.setValue("cli", forHTTPHeaderField: "x-app")
        case .openAICodex, .googleOAuth:
            break
        }
    }

    private func anthropicBaseURL(for provider: CloudModelProvider) -> String {
        switch provider {
        case .anthropic:
            "https://api.anthropic.com"
        case .minimax:
            "https://api.minimax.io/anthropic"
        case .openAI, .google, .zai, .kimi, .deepseek:
            "https://api.anthropic.com"
        }
    }

    private func openAICompatibleChatRequest(
        provider: CloudModelProvider,
        modelID: String,
        credential: CloudProviderResolvedCredential
    ) throws -> URLRequest {
        guard let url = URL(string: try openAICompatibleBaseURL(for: provider, credential: credential) + "/chat/completions") else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(openAICompatibleAuthorizationHeader(for: credential), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func compatibleChatCompletionBody(
        modelID: String,
        prompt: String,
        systemPrompt: String?,
        imagePayloads: [VisionPayload],
        maxTokens: Int,
        stream: Bool
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": modelID,
            "messages": Self.compatibleChatMessages(
                prompt: prompt,
                systemPrompt: systemPrompt,
                imagePayloads: imagePayloads
            ),
            "stream": stream,
        ]
        if maxTokens > 0 {
            body["max_tokens"] = maxTokens
        }
        return body
    }

    nonisolated static func visionPayloads(from imageURLs: [URL]) throws -> [VisionPayload] {
        try imageURLs.map(Self.visionPayload(for:))
    }

    nonisolated static func openAIUserContent(
        prompt: String,
        imagePayloads: [VisionPayload]
    ) -> [[String: Any]] {
        var content: [[String: Any]] = [["type": "input_text", "text": prompt]]
        content.reserveCapacity(imagePayloads.count + 1)
        for payload in imagePayloads {
            content.append([
                "type": "input_image",
                "image_url": payload.dataURL,
            ])
        }
        return content
    }

    nonisolated static func anthropicMessageContent(
        prompt: String,
        imagePayloads: [VisionPayload]
    ) -> [[String: Any]] {
        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        content.reserveCapacity(imagePayloads.count + 1)
        for payload in imagePayloads {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": payload.mimeType,
                    "data": payload.base64Data,
                ]
            ])
        }
        return content
    }

    nonisolated static func googleParts(
        prompt: String,
        imagePayloads: [VisionPayload]
    ) -> [[String: Any]] {
        var parts: [[String: Any]] = [["text": prompt]]
        parts.reserveCapacity(imagePayloads.count + 1)
        for payload in imagePayloads {
            parts.append([
                "inlineData": [
                    "mimeType": payload.mimeType,
                    "data": payload.base64Data,
                ]
            ])
        }
        return parts
    }

    nonisolated static func compatibleChatMessages(
        prompt: String,
        systemPrompt: String?,
        imagePayloads: [VisionPayload]
    ) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        messages.reserveCapacity(systemPrompt?.isEmpty == false ? 2 : 1)
        if let systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }

        if imagePayloads.isEmpty {
            messages.append(["role": "user", "content": prompt])
            return messages
        }

        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        content.reserveCapacity(imagePayloads.count + 1)
        for payload in imagePayloads {
            content.append([
                "type": "image_url",
                "image_url": ["url": payload.dataURL],
            ])
        }
        messages.append(["role": "user", "content": content])
        return messages
    }

    private nonisolated static func visionPayload(for imageURL: URL) throws -> VisionPayload {
        let data = try Data(contentsOf: imageURL)
        return VisionPayload(
            mimeType: imageMimeType(for: imageURL),
            base64Data: data.base64EncodedString()
        )
    }

    private nonisolated static func imageMimeType(for imageURL: URL) -> String {
        switch imageURL.pathExtension.lowercased() {
        case "jpg", "jpeg":
            "image/jpeg"
        case "gif":
            "image/gif"
        case "webp":
            "image/webp"
        case "heic", "heif":
            "image/heic"
        case "bmp":
            "image/bmp"
        case "tif", "tiff":
            "image/tiff"
        default:
            "image/png"
        }
    }

    private func openAICompatibleMessageText(from json: [String: Any]) -> String? {
        // Only return the final `content` channel. Never fall through to
        // `reasoning_content` — that's the model's private chain-of-
        // thought and rendering it as the chat reply makes the app look
        // broken ("Okay, so I'm trying to figure out..." shown as the
        // answer). If the model returns only reasoning with no content,
        // yield nil so the empty-stream guard surfaces a real error
        // instead of rendering the monologue.
        let choices = json["choices"] as? [[String: Any]] ?? []
        let text = choices.compactMap { choice -> String? in
            guard let message = choice["message"] as? [String: Any] else { return nil }
            if let content = message["content"] as? String, !content.isEmpty {
                return content
            }
            return nil
        }
        .joined()
        return text.isEmpty ? nil : text
    }

    private func googleModelsRequest(
        for credential: CloudProviderResolvedCredential
    ) throws -> URLRequest {
        switch credential {
        case .apiKey(let token):
            var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
            components?.queryItems = [URLQueryItem(name: "key", value: token)]
            guard let url = components?.url else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            return request
        case .googleOAuth(let accessToken, let projectID):
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(projectID, forHTTPHeaderField: "x-goog-user-project")
            return request
        case .openAICodex, .anthropicOAuth:
            throw CloudLLMError.invalidResponse
        }
    }

    private func googleContentRequest(
        modelID: String,
        suffix: String,
        credential: CloudProviderResolvedCredential
    ) throws -> URLRequest {
        switch credential {
        case .apiKey(let token):
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID)\(suffix)?key=\(token)") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            return request
        case .googleOAuth(let accessToken, let projectID):
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID)\(suffix)") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(projectID, forHTTPHeaderField: "x-goog-user-project")
            return request
        case .openAICodex, .anthropicOAuth:
            throw CloudLLMError.invalidResponse
        }
    }

    private func googleStreamRequest(
        modelID: String,
        credential: CloudProviderResolvedCredential
    ) throws -> URLRequest {
        switch credential {
        case .apiKey(let token):
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):streamGenerateContent?alt=sse") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(token, forHTTPHeaderField: "x-goog-api-key")
            return request
        case .googleOAuth(let accessToken, let projectID):
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):streamGenerateContent?alt=sse") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(projectID, forHTTPHeaderField: "x-goog-user-project")
            return request
        case .openAICodex, .anthropicOAuth:
            throw CloudLLMError.invalidResponse
        }
    }

    private func streamSSE(
        _ request: URLRequest,
        chunkExtractor: @escaping @Sendable ([String: Any]) -> String?
    ) -> AsyncThrowingStream<String, Error> {
        URLSessionTransportSupport.streamSSE(
            using: urlSession,
            request: request,
            invalidResponse: { CloudLLMError.invalidResponse },
            chunkExtractor: chunkExtractor
        )
    }

    private nonisolated static func sseFieldValue(from line: String) -> String {
        let value = line.drop { $0 != ":" }.dropFirst()
        if value.first == " " {
            return String(value.dropFirst())
        }
        return String(value)
    }

    private nonisolated static func collectAsyncBytes(_ bytes: URLSession.AsyncBytes) async throws -> String {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func sendJSON(_ request: URLRequest) async throws -> [String: Any] {
        try await URLSessionTransportSupport.sendJSON(
            using: urlSession,
            request: request,
            invalidResponse: { CloudLLMError.invalidResponse }
        )
    }

    private func collectOpenAIResponseText(from request: URLRequest) async throws -> String {
        var collected = ""
        for try await chunk in streamSSE(request) { json in
            CloudStreamingParser.openAITextDelta(from: json)
        } {
            collected += chunk
        }

        guard !collected.isEmpty else {
            throw CloudLLMError.invalidResponse
        }
        return collected
    }

    private func makeOpenAIResponsesRequest(
        model: CloudTextModelID,
        credential: CloudProviderResolvedCredential,
        input: [[String: Any]],
        systemPrompt: String?,
        maxTokens: Int,
        operatingMode: EpistemosOperatingMode,
        schema: CloudJSONSchema? = nil,
        stream: Bool
    ) throws -> URLRequest {
        guard let url = openAIRequestURL(path: "/responses", credential: credential) else {
            throw CloudLLMError.invalidResponse
        }

        var body: [String: Any] = [
            "model": model.vendorModelID,
            "input": input,
            "store": false,
            "stream": stream,
        ]
        if let instructions = openAIResponsesInstructions(
            systemPrompt: systemPrompt,
            credential: credential
        ) {
            body["instructions"] = instructions
        }
        if maxTokens > 0, case .apiKey = credential {
            body["max_output_tokens"] = maxTokens
        }
        applyOpenAIResponsesControls(
            to: &body,
            model: model,
            operatingMode: operatingMode,
            credential: credential
        )
        let tools = openAIToolsConfiguration()
        if !tools.isEmpty {
            body["tools"] = tools
        }
        if let schema {
            var formatSchema: [String: Any] = [
                "type": "json_schema",
                "name": schema.name,
                "schema": schema.schema,
                "strict": schema.strict,
            ]
            if let description = schema.description {
                formatSchema["description"] = description
            }
            body["text"] = ["format": formatSchema]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(openAIAuthorizationHeader(for: credential), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private struct OpenAIResponseControls {
        let reasoningEffort: String?
        let verbosity: String?
        /// `reasoning.summary`: `auto` / `concise` / `detailed`. Only set
        /// when the user picks the Extended tier — at Standard we rely
        /// on OpenAI's default summary behavior to keep latency low.
        var reasoningSummary: String? = nil
    }

    private func openAIResponseControls(
        for model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode,
        credential: CloudProviderResolvedCredential
    ) -> OpenAIResponseControls? {
        guard case .apiKey = credential else {
            return nil
        }

        // Non-reasoning models (GPT-4.1, o3-*) hard-400 on reasoning.effort
        // per OpenAI's responses API. Gate at the model-type level.
        let isReasoningModel: Bool
        switch model {
        case .openAIGPT54, .openAIGPT52, .openAIGPT54Mini, .openAIGPT54Nano:
            isReasoningModel = true
        default:
            isReasoningModel = false
        }
        guard isReasoningModel else { return nil }

        // User-selected reasoning tier takes precedence over the operating-
        // mode defaults. `.standard` keeps the existing per-mode tuning so
        // Fast mode stays cheap and fast; `.off` forces effort=none; and
        // `.extended` forces the highest effort the model supports plus a
        // detailed summary. Per research 1 (docs.claude.com/openai/... — see
        // docs/architecture/MASTER_PLAN_2026-04-19.md §13).
        let tier = inference.chatReasoningTier

        switch tier {
        case .off:
            return OpenAIResponseControls(reasoningEffort: "none", verbosity: "low")
        case .extended:
            let effort: String
            switch model {
            case .openAIGPT54:
                effort = "high"     // xhigh exists but gated to opt-in
            case .openAIGPT52:
                effort = "high"
            case .openAIGPT54Mini:
                effort = "high"
            case .openAIGPT54Nano:
                effort = "low"      // Nano caps below high
            default:
                effort = "high"
            }
            return OpenAIResponseControls(
                reasoningEffort: effort,
                verbosity: "high",
                reasoningSummary: "detailed"
            )
        case .standard:
            break  // fall through to per-mode defaults
        }

        return switch model {
        case .openAIGPT54, .openAIGPT52:
            switch operatingMode {
            case .fast:
                OpenAIResponseControls(reasoningEffort: "none", verbosity: "low")
            case .thinking:
                OpenAIResponseControls(reasoningEffort: "medium", verbosity: "medium")
            case .pro:
                OpenAIResponseControls(reasoningEffort: "high", verbosity: "medium")
            case .agent:
                OpenAIResponseControls(reasoningEffort: "medium", verbosity: "low")
            }
        case .openAIGPT54Mini:
            switch operatingMode {
            case .fast:
                OpenAIResponseControls(reasoningEffort: "none", verbosity: "low")
            case .thinking:
                OpenAIResponseControls(reasoningEffort: "low", verbosity: "medium")
            case .pro:
                OpenAIResponseControls(reasoningEffort: "medium", verbosity: "medium")
            case .agent:
                OpenAIResponseControls(reasoningEffort: "low", verbosity: "low")
            }
        case .openAIGPT54Nano:
            switch operatingMode {
            case .fast:
                OpenAIResponseControls(reasoningEffort: "none", verbosity: "low")
            case .thinking, .pro, .agent:
                OpenAIResponseControls(reasoningEffort: "low", verbosity: "low")
            }
        default:
            nil
        }
    }

    private func applyOpenAIResponsesControls(
        to body: inout [String: Any],
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode,
        credential: CloudProviderResolvedCredential
    ) {
        guard let controls = openAIResponseControls(
            for: model,
            operatingMode: operatingMode,
            credential: credential
        ) else {
            return
        }
        if let effort = controls.reasoningEffort {
            var reasoning: [String: Any] = ["effort": effort]
            if let summary = controls.reasoningSummary {
                reasoning["summary"] = summary
            }
            body["reasoning"] = reasoning
        }
        if let verbosity = controls.verbosity {
            var text = body["text"] as? [String: Any] ?? [:]
            text["verbosity"] = verbosity
            body["text"] = text
        }
    }

    private func openAIToolsConfiguration() -> [[String: Any]] {
        var tools: [[String: Any]] = []
        if inference.openAIWebSearchEnabled {
            tools.append(["type": "web_search"])
        }
        // NOTE: code_interpreter removed — causes "Unsupported tool type" 400 errors
        // on many GPT-5.4 accounts/regions. The Responses API tool type name may have
        // changed or require specific account-level feature enablement.
        // If needed in future, re-add with the verified API format.
        return tools
    }

    private func openAIResponsesInstructions(
        systemPrompt: String?,
        credential: CloudProviderResolvedCredential
    ) -> String? {
        let trimmed = systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }

        switch credential {
        case .openAICodex:
            // The ChatGPT Codex responses backend rejects requests that omit
            // the top-level instructions field entirely.
            return "You are a helpful assistant."
        case .apiKey, .anthropicOAuth, .googleOAuth:
            return nil
        }
    }

    private func compatibleOpenAIModel(
        _ model: CloudTextModelID,
        credential: CloudProviderResolvedCredential
    ) -> CloudTextModelID {
        guard case .openAICodex = credential else {
            return model
        }

        switch model {
        case .openAIGPT54, .openAIGPT54Mini, .openAIGPT52:
            return model
        case .openAIGPT54Nano, .openAIGPT41, .openAIGPT41Mini:
            return .openAIGPT54Mini
        case .openAIO3, .openAIO3Mini:
            return .openAIGPT54
        default:
            return model
        }
    }

    private func resolvedAnthropicMaxTokens(requestedMaxTokens: Int) -> Int {
        let baseTokens = max(requestedMaxTokens, 512)
        let tier = inference.chatReasoningTier
        switch tier {
        case .off:
            return baseTokens
        case .extended:
            // Extended tier forces a 16k budget regardless of the
            // Settings slider so `max_tokens` has to grow to fit it.
            return max(baseTokens, 16_000 + 512)
        case .standard:
            guard inference.anthropicExtendedThinkingEnabled else { return baseTokens }
            return max(baseTokens, inference.anthropicThinkingBudgetTokens + 512)
        }
    }

    /// Google `generationConfig.thinkingConfig` per tier. Per research 1:
    /// - Gemini 3.x uses `thinkingLevel` ("minimal"/"low"/"medium"/"high");
    ///   Gemini 2.5 uses `thinkingBudget` (int token count; -1 = dynamic).
    /// - `thinkingBudget` and `thinkingLevel` in one request is a 400;
    ///   each model is exclusively one or the other.
    /// - `includeThoughts: true` is mandatory to actually receive any
    ///   thinking parts back — Google defaults it to false.
    /// - 2.5 Pro cannot set `thinkingBudget: 0` (can't disable thinking).
    private func googleThinkingConfiguration(
        for model: CloudTextModelID
    ) -> [String: Any]? {
        let tier = inference.chatReasoningTier
        let isGemini3 = switch model {
        case .googleGemini3FlashPreview, .googleGemini3ProPreview,
             .googleGemini31ProPreview:
            true
        default:
            false
        }
        let isGemini25Pro = model == .googleGemini25Pro

        switch tier {
        case .off:
            if isGemini3 {
                return ["thinkingLevel": "minimal", "includeThoughts": false]
            }
            // 2.5 Pro rejects thinkingBudget: 0, so we can't truly disable
            // there — fall through to standard (dynamic budget) and just
            // skip includeThoughts so the user doesn't see reasoning.
            if isGemini25Pro {
                return ["thinkingBudget": -1, "includeThoughts": false]
            }
            // 2.5 Flash / Flash-Lite: 0 is allowed.
            return ["thinkingBudget": 0, "includeThoughts": false]
        case .standard:
            if isGemini3 {
                return ["thinkingLevel": "medium", "includeThoughts": true]
            }
            return ["thinkingBudget": -1, "includeThoughts": true]
        case .extended:
            if isGemini3 {
                return ["thinkingLevel": "high", "includeThoughts": true]
            }
            return ["thinkingBudget": 16_384, "includeThoughts": true]
        }
    }

    private func applyGoogleThinkingConfig(
        to body: inout [String: Any],
        model: CloudTextModelID
    ) {
        guard let thinkingConfig = googleThinkingConfiguration(for: model) else {
            return
        }
        var generationConfig = body["generationConfig"] as? [String: Any] ?? [:]
        generationConfig["thinkingConfig"] = thinkingConfig
        body["generationConfig"] = generationConfig
    }

    private func anthropicThinkingConfiguration(maxTokens: Int) -> [String: Any]? {
        // Tier-driven thinking config. Standard respects the existing
        // Settings toggle + slider so power users keep their tuning; Off
        // force-skips; Extended forces a 16k budget per research 1's
        // recommendation. Adaptive (Opus 4.7+) would go here too, but
        // our catalog tops out at Opus 4.1 / Sonnet 4 which use manual
        // `enabled` — no 400 risk.
        let tier = inference.chatReasoningTier
        switch tier {
        case .off:
            return nil
        case .extended:
            let budget = min(16_000, max(1_024, maxTokens - 128))
            return [
                "type": "enabled",
                "budget_tokens": budget,
            ]
        case .standard:
            guard inference.anthropicExtendedThinkingEnabled else { return nil }
            let budget = min(
                inference.anthropicThinkingBudgetTokens,
                max(1_024, maxTokens - 128)
            )
            return [
                "type": "enabled",
                "budget_tokens": budget,
            ]
        }
    }
}

nonisolated enum CloudLLMError: LocalizedError {
    case modelRequired
    case missingAccess(String)
    case invalidResponse
    case runtimeUnavailable

    var errorDescription: String? {
        switch self {
        case .modelRequired:
            "No cloud model is selected."
        case .missingAccess(let provider):
            "\(provider) access is missing. Connect an account or add an API key in Settings → Inference."
        case .invalidResponse:
            "The cloud provider returned an unreadable response."
        case .runtimeUnavailable:
            "The cloud model runtime is unavailable right now."
        }
    }
}

nonisolated enum CloudStreamingParser {
    static func openAITextDelta(from json: [String: Any]) -> String? {
        guard json["type"] as? String == "response.output_text.delta" else { return nil }
        return json["delta"] as? String
    }

    static func anthropicTextDelta(from json: [String: Any]) -> String? {
        guard json["type"] as? String == "content_block_delta",
              let delta = json["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta" else {
            return nil
        }
        return delta["text"] as? String
    }

    static func googleTextDelta(from json: [String: Any]) -> String? {
        if let candidates = json["candidates"] as? [[String: Any]] {
            let text = candidates
                .compactMap { $0["content"] as? [String: Any] }
                .compactMap { $0["parts"] as? [[String: Any]] }
                .flatMap { $0 }
                .compactMap { $0["text"] as? String }
                .joined()
            return text.isEmpty ? nil : text
        }
        return nil
    }

    static func openAICompatibleTextDelta(from json: [String: Any]) -> String? {
        // Only emit `delta.content`. The `delta.reasoning_content`
        // channel is the model's private chain-of-thought and must
        // never be rendered as the chat reply — doing so made the app
        // read as a stream-of-consciousness monologue ("Okay, so I'm
        // trying to figure out...") instead of an answer. Reasoning
        // should route into the thinking popover via a separate
        // parser; that wiring is tracked in the follow-up.
        let choices = json["choices"] as? [[String: Any]] ?? []
        let text = choices.compactMap { choice -> String? in
            guard let delta = choice["delta"] as? [String: Any] else { return nil }
            if let content = delta["content"] as? String, !content.isEmpty {
                return content
            }
            return nil
        }
        .joined()
        return text.isEmpty ? nil : text
    }

    /// Emit the OpenAI-compatible reasoning delta separately from the
    /// visible text stream. Callers that want to surface thinking in a
    /// popover route this to the reasoning channel; callers that don't
    /// just ignore it. Keeping the parser available as a static so
    /// future wiring (PipelineEvent.reasoningDelta → ChatState
    /// .appendStreamingThinking) can land without changing the call
    /// site that currently uses openAICompatibleTextDelta.
    static func openAICompatibleReasoningDelta(from json: [String: Any]) -> String? {
        let choices = json["choices"] as? [[String: Any]] ?? []
        let text = choices.compactMap { choice -> String? in
            guard let delta = choice["delta"] as? [String: Any] else { return nil }
            if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                return reasoning
            }
            return nil
        }
        .joined()
        return text.isEmpty ? nil : text
    }

    static func streamError(from json: [String: Any], eventName: String?) -> LLMError? {
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? 0
            let message = error["message"] as? String ?? ""
            return .apiError(statusCode: code, body: message)
        }

        if eventName == "error" || json["type"] as? String == "error" {
            let code = json["code"] as? Int ?? 0
            let message = json["message"] as? String ?? ""
            return .apiError(statusCode: code, body: message)
        }

        return nil
    }
}
