import Foundation
import Observation

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
        modelID: String?
    ) async throws -> String
    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<String, Error>
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
            modelID: nil
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
            modelID: nil
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
            return AsyncThrowingStream { continuation in
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

        case .localMLX:
            guard let localLLMClient else {
                return AsyncThrowingStream { continuation in
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
        case .openAI, .anthropic, .google:
            guard let cloudLLMClient else {
                return AsyncThrowingStream { continuation in
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
            return LLMSnapshot(provider: .localMLX, model: modelID, reasoningMode: .fast)
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

        case .localMLX:
            return try await sharedLocalGenerate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: snapshot.reasoningMode,
                modelID: snapshot.model.isEmpty ? nil : snapshot.model
            )
        case .openAI, .anthropic, .google:
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
        AsyncThrowingStream { continuation in
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
        }
    }
}

@MainActor
final class CloudLLMClient: LLMClientProtocol {
    private let inference: InferenceState
    private let urlSession: URLSession

    init(
        inference: InferenceState,
        urlSession: URLSession = .shared
    ) {
        self.inference = inference
        self.urlSession = urlSession
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        let model = try selectedCloudModel()
        let apiKey = try apiKey(for: model.provider)

        switch model.provider {
        case .openAI:
            return try await generateOpenAI(
                model: model,
                apiKey: apiKey,
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        case .anthropic:
            return try await generateAnthropic(
                model: model,
                apiKey: apiKey,
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        case .google:
            return try await generateGoogle(
                model: model,
                apiKey: apiKey,
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        }
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        do {
            let model = try selectedCloudModel()
            let apiKey = try apiKey(for: model.provider)

            switch model.provider {
            case .openAI:
                return streamOpenAI(
                    model: model,
                    apiKey: apiKey,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens
                )
            case .anthropic:
                return streamAnthropic(
                    model: model,
                    apiKey: apiKey,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens
                )
            case .google:
                return streamGoogle(
                    model: model,
                    apiKey: apiKey,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens
                )
            }
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        do {
            let model = try selectedCloudModel()
            let apiKey = try apiKey(for: model.provider)
            return await testConnection(provider: model.provider, apiKey: apiKey, model: model)
        } catch {
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func testConnection(
        provider: CloudModelProvider,
        apiKey: String,
        model: CloudTextModelID? = nil
    ) async -> ConnectionTestResult {
        do {
            if let model {
                try await testModelConnection(provider: provider, apiKey: apiKey, model: model)
                return ConnectionTestResult(
                    success: true,
                    message: "Connected to \(provider.displayName) via \(model.compactDisplayName)"
                )
            }

            return ConnectionTestResult(
                success: true,
                message: try await validateProviderAuthorization(provider: provider, apiKey: apiKey)
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

    private func apiKey(for provider: CloudModelProvider) throws -> String {
        guard let value = inference.apiKey(for: provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            throw CloudLLMError.missingAPIKey(provider.displayName)
        }
        return value
    }

    private func testModelConnection(
        provider: CloudModelProvider,
        apiKey: String,
        model: CloudTextModelID
    ) async throws {
        switch provider {
        case .openAI:
            _ = try await generateOpenAI(
                model: model,
                apiKey: apiKey,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16
            )
        case .anthropic:
            _ = try await generateAnthropic(
                model: model,
                apiKey: apiKey,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16
            )
        case .google:
            _ = try await generateGoogle(
                model: model,
                apiKey: apiKey,
                prompt: "Reply with OK.",
                systemPrompt: nil,
                maxTokens: 16
            )
        }
    }

    private func validateProviderAuthorization(
        provider: CloudModelProvider,
        apiKey: String
    ) async throws -> String {
        let request = try providerAuthorizationRequest(provider: provider, apiKey: apiKey)
        let json = try await sendJSON(request)
        let supportedModelCount = supportedProviderModelCount(in: json, provider: provider)
        if supportedModelCount > 0 {
            return "Connected to \(provider.displayName). \(supportedModelCount) supported models are available."
        }
        return "Connected to \(provider.displayName)."
    }

    private func providerAuthorizationRequest(
        provider: CloudModelProvider,
        apiKey: String
    ) throws -> URLRequest {
        switch provider {
        case .openAI:
            guard let url = URL(string: "https://api.openai.com/v1/models") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            return request
        case .anthropic:
            guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            return request
        case .google:
            var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
            components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
            guard let url = components?.url else {
                throw CloudLLMError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            return request
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
        case .openAI, .anthropic:
            let models = json["data"] as? [[String: Any]] ?? []
            return Set(models.compactMap { $0["id"] as? String })
        case .google:
            let models = json["models"] as? [[String: Any]] ?? []
            return Set(
                models.compactMap { $0["name"] as? String }
                    .map { $0.replacingOccurrences(of: "models/", with: "") }
            )
        }
    }

    private func generateOpenAI(
        model: CloudTextModelID,
        apiKey: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        let input: [[String: String?]] = [
            ["role": systemPrompt?.isEmpty == false ? "system" : nil, "content": systemPrompt],
            ["role": "user", "content": prompt],
        ].compactMap { entry in
            guard let role = entry["role"] ?? nil,
                  let content = entry["content"] ?? nil,
                  !content.isEmpty else { return nil }
            return ["role": role, "content": content]
        }

        var body: [String: Any] = [
            "model": model.vendorModelID,
            "input": input,
        ]
        if maxTokens > 0 {
            body["max_output_tokens"] = maxTokens
        }

        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

    private func streamOpenAI(
        model: CloudTextModelID,
        apiKey: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        let input: [[String: String?]] = [
            ["role": systemPrompt?.isEmpty == false ? "system" : nil, "content": systemPrompt],
            ["role": "user", "content": prompt],
        ].compactMap { entry in
            guard let role = entry["role"] ?? nil,
                  let content = entry["content"] ?? nil,
                  !content.isEmpty else { return nil }
            return ["role": role, "content": content]
        }

        var body: [String: Any] = [
            "model": model.vendorModelID,
            "input": input,
            "stream": true,
        ]
        if maxTokens > 0 {
            body["max_output_tokens"] = maxTokens
        }

        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }

        return streamSSE(request) { json in
            CloudStreamingParser.openAITextDelta(from: json)
        }
    }

    private func generateAnthropic(
        model: CloudTextModelID,
        apiKey: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        var body: [String: Any] = [
            "model": model.vendorModelID,
            "messages": [
                [
                    "role": "user",
                    "content": prompt,
                ]
            ],
            "max_tokens": max(maxTokens, 512),
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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
        apiKey: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        var body: [String: Any] = [
            "model": model.vendorModelID,
            "messages": [
                [
                    "role": "user",
                    "content": prompt,
                ]
            ],
            "max_tokens": max(maxTokens, 512),
            "stream": true,
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }

        return streamSSE(request) { json in
            CloudStreamingParser.anthropicTextDelta(from: json)
        }
    }

    private func generateGoogle(
        model: CloudTextModelID,
        apiKey: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model.vendorModelID):generateContent?key=\(apiKey)"
        var body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]],
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

        guard let url = URL(string: endpoint) else {
            throw CloudLLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        apiKey: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        var body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]],
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

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.vendorModelID):streamGenerateContent?alt=sse") else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CloudLLMError.invalidResponse)
            }
        }

        return streamSSE(request) { json in
            CloudStreamingParser.googleTextDelta(from: json)
        }
    }

    private func streamSSE(
        _ request: URLRequest,
        chunkExtractor: @escaping @Sendable ([String: Any]) -> String?
    ) -> AsyncThrowingStream<String, Error> {
        ProcessActivity.makeStream(reason: "Streaming cloud response") { [self] continuation in
            do {
                let (bytes, response) = try await urlSession.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CloudLLMError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = try await Self.collectAsyncBytes(bytes)
                    throw LLMError.apiError(statusCode: httpResponse.statusCode, body: body)
                }

                var eventName: String?
                var dataLines: [String] = []

                func flushEvent() throws {
                    guard !dataLines.isEmpty else {
                        eventName = nil
                        return
                    }

                    let payload = dataLines.joined(separator: "\n")
                    let currentEventName = eventName
                    eventName = nil
                    dataLines.removeAll(keepingCapacity: true)

                    if payload == "[DONE]" {
                        return
                    }

                    guard let jsonData = payload.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        return
                    }

                    if let error = CloudStreamingParser.streamError(from: json, eventName: currentEventName) {
                        throw error
                    }

                    if let chunk = chunkExtractor(json), !chunk.isEmpty {
                        continuation.yield(chunk)
                    }
                }

                for try await line in bytes.lines {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    if line.isEmpty {
                        try flushEvent()
                        continue
                    }

                    if line.hasPrefix("event:") {
                        eventName = Self.sseFieldValue(from: line)
                        continue
                    }

                    if line.hasPrefix("data:") {
                        dataLines.append(Self.sseFieldValue(from: line))
                    }
                }

                try flushEvent()
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
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
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudLLMError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.apiError(statusCode: httpResponse.statusCode, body: body)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CloudLLMError.invalidResponse
        }
        return json
    }
}

nonisolated enum CloudLLMError: LocalizedError {
    case modelRequired
    case missingAPIKey(String)
    case invalidResponse
    case runtimeUnavailable

    var errorDescription: String? {
        switch self {
        case .modelRequired:
            "No cloud model is selected."
        case .missingAPIKey(let provider):
            "\(provider) API key is missing. Add it in Settings → Inference."
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
