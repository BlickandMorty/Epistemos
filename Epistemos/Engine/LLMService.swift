import Foundation
import Observation
import os

// MARK: - LLM Service
// Provider-agnostic LLM interface.
// Anthropic, OpenAI, Google: URLSession REST.
// Ollama: local REST at http://localhost:11434.
// Apple Intelligence: handled by AppleIntelligenceService.

@MainActor @Observable
final class LLMService {

    private let inference: InferenceState

    init(inference: InferenceState) {
        self.inference = inference
    }

    // MARK: - Generate (non-streaming)

    func generate(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 4096) async throws -> String {
        switch inference.apiProvider {
        case .anthropic:
            return try await anthropicGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        case .openai:
            return try await openAIGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        case .google:
            return try await geminiGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        case .kimi:
            return try await kimiGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        case .ollama:
            return try await ollamaGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        case .appleIntelligence:
            return try await AppleIntelligenceService.shared.generate(prompt: prompt, systemPrompt: systemPrompt)
        }
    }

    // MARK: - Stream

    func stream(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 0) -> AsyncThrowingStream<String, Error> {
        // 0 = use user setting (or 16000 if unset). Explicit callers always override.
        let tokens = maxTokens > 0 ? maxTokens : (inference.chatOutputTokens > 0 ? inference.chatOutputTokens : 16000)
        switch inference.apiProvider {
        case .anthropic:
            return anthropicStream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: tokens)
        case .openai:
            return openAIStream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: tokens)
        case .google:
            return geminiStream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: tokens)
        case .kimi:
            return kimiStream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: tokens)
        case .ollama:
            return ollamaStream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: tokens)
        case .appleIntelligence:
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        let result = try await AppleIntelligenceService.shared.generate(prompt: prompt, systemPrompt: systemPrompt)
                        continuation.yield(result)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    // MARK: - Connection Test

    func testConnection() async -> ConnectionTestResult {
        do {
            let response = try await generate(prompt: "Reply with exactly: OK", maxTokens: 10)
            return ConnectionTestResult(success: true, message: "Connected — \(inference.apiProvider.displayName): \(response.prefix(40))")
        } catch let error as LLMError {
            // Rate limit (429) = key IS valid, just throttled. Show as partial success
            // so the user knows their key works and doesn't panic.
            if case .apiError(let code, _) = error, code == 429 {
                return ConnectionTestResult(
                    success: true,
                    message: "Key valid ✓ — \(inference.apiProvider.displayName) is rate-limiting right now. Wait a moment before sending queries."
                )
            }
            let friendly = error.errorDescription ?? "Unknown error"
            return ConnectionTestResult(success: false, message: friendly)
        } catch {
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    // MARK: - Ollama discovery

    func checkOllama() async {
        guard let url = URL(string: "\(inference.ollamaBaseUrl)/api/tags") else {
            inference.setOllamaStatus(available: false, models: [])
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            let names = decoded.models.map { $0.name }
            inference.setOllamaStatus(available: true, models: names)
        } catch {
            inference.setOllamaStatus(available: false, models: [])
        }
    }

    // MARK: - Well-Known API URLs
    nonisolated static let anthropicURL = URL(string: "https://api.anthropic.com/v1/messages")!
    nonisolated static let openaiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    nonisolated static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models/"
    nonisolated static let kimiURL = URL(string: "https://api.moonshot.ai/v1/chat/completions")!
    nonisolated static let requestTimeout: TimeInterval = 60

    // MARK: - Anthropic

    private func anthropicGenerate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        let body = AnthropicRequest(
            model: inference.anthropicModel,
            maxTokens: maxTokens,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: prompt)]
        )
        let data = try await postJSON(
            url: Self.anthropicURL,
            body: body,
            headers: [
                "x-api-key": inference.apiKey,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json"
            ]
        )
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return response.content.first?.text ?? ""
    }

    private func anthropicStream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var body = AnthropicRequest(
                        model: self.inference.anthropicModel,
                        maxTokens: maxTokens,
                        system: systemPrompt,
                        messages: [AnthropicMessage(role: "user", content: prompt)]
                    )
                    body.stream = true
                    let encoded = try JSONEncoder().encode(body)
                    var request = URLRequest(url: Self.anthropicURL, timeoutInterval: Self.requestTimeout)
                    request.httpMethod = "POST"
                    request.httpBody = encoded
                    request.setValue(self.inference.apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    // Check HTTP status — streaming responses can also be errors
                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        // Read the error body from the stream
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }
                        throw LLMError.apiError(statusCode: http.statusCode, body: String(errorBody.prefix(300)))
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let json = String(line.dropFirst(6))
                            if json == "[DONE]" { break }
                            if let d = json.data(using: .utf8),
                               let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: d),
                               let text = event.delta?.text {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - OpenAI

    private func openAIGenerate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        var messages: [OpenAIMessage] = []
        if let sys = systemPrompt { messages.append(OpenAIMessage(role: "system", content: sys)) }
        messages.append(OpenAIMessage(role: "user", content: prompt))

        let body = OpenAIRequest(model: inference.openaiModel, messages: messages, maxTokens: maxTokens, stream: false)
        let data = try await postJSON(
            url: Self.openaiURL,
            body: body,
            headers: [
                "Authorization": "Bearer \(inference.apiKey)",
                "content-type": "application/json"
            ]
        )
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    private func openAIStream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var messages: [OpenAIMessage] = []
                    if let sys = systemPrompt { messages.append(OpenAIMessage(role: "system", content: sys)) }
                    messages.append(OpenAIMessage(role: "user", content: prompt))
                    let body = OpenAIRequest(model: self.inference.openaiModel, messages: messages, maxTokens: maxTokens, stream: true)
                    let encoded = try JSONEncoder().encode(body)
                    var request = URLRequest(url: Self.openaiURL, timeoutInterval: Self.requestTimeout)
                    request.httpMethod = "POST"
                    request.httpBody = encoded
                    request.setValue("Bearer \(self.inference.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }
                        throw LLMError.apiError(statusCode: http.statusCode, body: String(errorBody.prefix(300)))
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let json = String(line.dropFirst(6))
                            if json == "[DONE]" { break }
                            if let d = json.data(using: .utf8),
                               let event = try? JSONDecoder().decode(OpenAIStreamEvent.self, from: d),
                               let text = event.choices.first?.delta.content {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Gemini

    private func geminiGenerate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        // SECURITY: API key sent via x-goog-api-key header instead of URL query parameter
        let urlStr = "\(Self.geminiBaseURL)\(inference.googleModel):generateContent"
        guard let url = URL(string: urlStr) else {
            throw LLMError.apiError(statusCode: 0, body: "Invalid Gemini URL for model: \(inference.googleModel)")
        }
        var parts: [GeminiPart] = []
        if let sys = systemPrompt { parts.append(GeminiPart(text: "System: \(sys)\n\n")) }
        parts.append(GeminiPart(text: prompt))
        let body = GeminiRequest(contents: [GeminiContent(parts: parts)], generationConfig: GeminiGenerationConfig(maxOutputTokens: maxTokens))
        let data = try await postJSON(url: url, body: body, headers: [
            "content-type": "application/json",
            "x-goog-api-key": inference.apiKey
        ])
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return response.candidates.first?.content.parts.first?.text ?? ""
    }

    private func geminiStream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Real streaming via streamGenerateContent SSE endpoint
                    let urlStr = "\(Self.geminiBaseURL)\(self.inference.googleModel):streamGenerateContent?alt=sse"
                    guard let url = URL(string: urlStr) else {
                        continuation.finish(throwing: LLMError.apiError(statusCode: 0, body: "Invalid Gemini stream URL"))
                        return
                    }
                    var parts: [GeminiPart] = []
                    if let sys = systemPrompt { parts.append(GeminiPart(text: "System: \(sys)\n\n")) }
                    parts.append(GeminiPart(text: prompt))
                    let body = GeminiRequest(
                        contents: [GeminiContent(parts: parts)],
                        generationConfig: GeminiGenerationConfig(maxOutputTokens: maxTokens)
                    )
                    let encoded = try JSONEncoder().encode(body)

                    var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
                    request.httpMethod = "POST"
                    request.httpBody = encoded
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    request.setValue(self.inference.apiKey, forHTTPHeaderField: "x-goog-api-key")

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }
                        throw LLMError.apiError(statusCode: http.statusCode, body: String(errorBody.prefix(300)))
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        // SSE: skip empty lines and comment lines (per spec)
                        if line.isEmpty || line.hasPrefix(":") { continue }
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        // SSE: [DONE] sentinel signals end of stream
                        if json.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }
                        if let d = json.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(GeminiResponse.self, from: d),
                           let text = chunk.candidates.first?.content.parts.first?.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Kimi (Moonshot AI)
    // OpenAI-compatible API at api.moonshot.ai/v1 — reuses OpenAI request/response types.

    private func kimiGenerate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        var messages: [OpenAIMessage] = []
        if let sys = systemPrompt { messages.append(OpenAIMessage(role: "system", content: sys)) }
        messages.append(OpenAIMessage(role: "user", content: prompt))

        let body = OpenAIRequest(model: inference.kimiModel, messages: messages, maxTokens: maxTokens, stream: false)
        let data = try await postJSON(
            url: Self.kimiURL,
            body: body,
            headers: [
                "Authorization": "Bearer \(inference.apiKey)",
                "content-type": "application/json"
            ]
        )
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    private func kimiStream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var messages: [OpenAIMessage] = []
                    if let sys = systemPrompt { messages.append(OpenAIMessage(role: "system", content: sys)) }
                    messages.append(OpenAIMessage(role: "user", content: prompt))
                    let body = OpenAIRequest(model: self.inference.kimiModel, messages: messages, maxTokens: maxTokens, stream: true)
                    let encoded = try JSONEncoder().encode(body)
                    var request = URLRequest(url: Self.kimiURL, timeoutInterval: Self.requestTimeout)
                    request.httpMethod = "POST"
                    request.httpBody = encoded
                    request.setValue("Bearer \(self.inference.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }
                        throw LLMError.apiError(statusCode: http.statusCode, body: String(errorBody.prefix(300)))
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let json = String(line.dropFirst(6))
                            if json == "[DONE]" { break }
                            if let d = json.data(using: .utf8),
                               let event = try? JSONDecoder().decode(OpenAIStreamEvent.self, from: d),
                               let text = event.choices.first?.delta.content {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Ollama

    private func ollamaGenerate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(inference.ollamaBaseUrl)/api/generate") else {
            throw LLMError.apiError(statusCode: 0, body: "Invalid Ollama base URL: \(inference.ollamaBaseUrl)")
        }
        let body = OllamaRequest(model: inference.ollamaModel, prompt: prompt, system: systemPrompt, stream: false)
        let data = try await postJSON(url: url, body: body, headers: ["content-type": "application/json"])
        let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return response.response
    }

    private func ollamaStream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = OllamaRequest(model: self.inference.ollamaModel, prompt: prompt, system: systemPrompt, stream: true)
                    let encoded = try JSONEncoder().encode(body)
                    guard let ollamaURL = URL(string: "\(self.inference.ollamaBaseUrl)/api/generate") else {
                        continuation.finish(throwing: LLMError.apiError(statusCode: 0, body: "Invalid Ollama base URL"))
                        return
                    }
                    var request = URLRequest(url: ollamaURL, timeoutInterval: Self.requestTimeout)
                    request.httpMethod = "POST"
                    request.httpBody = encoded
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    for try await line in bytes.lines {
                        if let d = line.data(using: .utf8),
                           let event = try? JSONDecoder().decode(OllamaStreamChunk.self, from: d) {
                            continuation.yield(event.response)
                            if event.done { break }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Shared HTTP helper

    private func postJSON<T: Encodable>(url: URL, body: T, headers: [String: String]) async throws -> Data {
        let encoded = try JSONEncoder().encode(body)
        // Single retry for transient errors (429, 529, 502, 503)
        for attempt in 0..<2 {
            var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
            request.httpMethod = "POST"
            request.httpBody = encoded
            for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                let err = LLMError.apiError(statusCode: http.statusCode, body: String((String(data: data, encoding: .utf8) ?? "").prefix(300)))
                if attempt == 0 && err.isTransient {
                    Log.pipeline.info("Transient API error \(http.statusCode), retrying in 2s…")
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
                throw err
            }
            return data
        }
        // Should never reach here, but satisfy compiler
        throw LLMError.apiError(statusCode: 0, body: "Unexpected retry exhaustion")
    }
}

// MARK: - LLM Snapshot (nonisolated background generation)
// Captures all config needed for an API call so enrichment tasks
// can make HTTP calls without hopping to MainActor.

nonisolated struct LLMSnapshot: Sendable {
    let provider: LLMProviderType
    let apiKey: String
    let model: String
    let ollamaBaseUrl: String
}

extension LLMService {
    /// Snapshot current config for use in nonisolated contexts (e.g. enrichment Task.detached).
    func configSnapshot() -> LLMSnapshot {
        let model: String = switch inference.apiProvider {
        case .anthropic: inference.anthropicModel
        case .openai: inference.openaiModel
        case .google: inference.googleModel
        case .kimi: inference.kimiModel
        case .ollama: inference.ollamaModel
        case .appleIntelligence: ""
        }
        return LLMSnapshot(
            provider: inference.apiProvider,
            apiKey: inference.apiKey,
            model: model,
            ollamaBaseUrl: inference.ollamaBaseUrl
        )
    }

    /// Snapshot for enrichment passes (2–6).
    /// Priority: Anthropic (best JSON schema compliance) > current provider > any provider with a key.
    /// This ensures enrichment runs whenever ANY valid API key exists, not just Anthropic.
    func enrichmentSnapshot() -> LLMSnapshot {
        // 1. Prefer Anthropic — best analytical quality for enrichment prompts
        if !inference.anthropicKey.isEmpty {
            return LLMSnapshot(
                provider: .anthropic,
                apiKey: inference.anthropicKey,
                model: inference.anthropicModel,
                ollamaBaseUrl: inference.ollamaBaseUrl
            )
        }
        // 2. Try the currently selected provider
        let current = configSnapshot()
        if !current.apiKey.isEmpty || current.provider == .ollama || current.provider == .appleIntelligence {
            return current
        }
        // 3. Try any provider that has a key (priority: OpenAI > Google > Kimi)
        if !inference.openaiKey.isEmpty {
            return LLMSnapshot(provider: .openai, apiKey: inference.openaiKey,
                               model: inference.openaiModel, ollamaBaseUrl: inference.ollamaBaseUrl)
        }
        if !inference.googleKey.isEmpty {
            return LLMSnapshot(provider: .google, apiKey: inference.googleKey,
                               model: inference.googleModel, ollamaBaseUrl: inference.ollamaBaseUrl)
        }
        if !inference.kimiKey.isEmpty {
            return LLMSnapshot(provider: .kimi, apiKey: inference.kimiKey,
                               model: inference.kimiModel, ollamaBaseUrl: inference.ollamaBaseUrl)
        }
        // 4. No keys at all — return current config (enrichmentKeyValid check will skip)
        return current
    }

    /// Generate a response without requiring MainActor — for use from Task.detached enrichment.
    /// Uses the snapshot's frozen config values rather than reading from InferenceState.
    /// `timeout` overrides the default 60s HTTP request timeout — enrichment passes use 25s
    /// to prevent a single slow request from consuming the entire enrichment budget.
    nonisolated static func generate(
        snapshot: LLMSnapshot,
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 4096,
        timeout: TimeInterval? = nil
    ) async throws -> String {
        let effectiveTimeout = timeout ?? requestTimeout
        switch snapshot.provider {
        case .anthropic:
            let body = AnthropicRequest(
                model: snapshot.model,
                maxTokens: maxTokens,
                system: systemPrompt,
                messages: [AnthropicMessage(role: "user", content: prompt)]
            )
            let data = try await postJSONStatic(
                url: anthropicURL,
                body: body,
                headers: [
                    "x-api-key": snapshot.apiKey,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json"
                ],
                timeout: effectiveTimeout
            )
            let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return response.content.first?.text ?? ""

        case .openai:
            var messages: [OpenAIMessage] = []
            if let sys = systemPrompt { messages.append(OpenAIMessage(role: "system", content: sys)) }
            messages.append(OpenAIMessage(role: "user", content: prompt))
            let body = OpenAIRequest(model: snapshot.model, messages: messages, maxTokens: maxTokens, stream: false)
            let data = try await postJSONStatic(
                url: openaiURL,
                body: body,
                headers: [
                    "Authorization": "Bearer \(snapshot.apiKey)",
                    "content-type": "application/json"
                ],
                timeout: effectiveTimeout
            )
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return response.choices.first?.message.content ?? ""

        case .google:
            let urlStr = "\(geminiBaseURL)\(snapshot.model):generateContent"
            guard let url = URL(string: urlStr) else {
                throw LLMError.apiError(statusCode: 0, body: "Invalid Gemini URL for model: \(snapshot.model)")
            }
            var parts: [GeminiPart] = []
            if let sys = systemPrompt { parts.append(GeminiPart(text: "System: \(sys)\n\n")) }
            parts.append(GeminiPart(text: prompt))
            let body = GeminiRequest(contents: [GeminiContent(parts: parts)], generationConfig: GeminiGenerationConfig(maxOutputTokens: maxTokens))
            let data = try await postJSONStatic(url: url, body: body, headers: [
                "content-type": "application/json",
                "x-goog-api-key": snapshot.apiKey
            ], timeout: effectiveTimeout)
            let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
            return response.candidates.first?.content.parts.first?.text ?? ""

        case .kimi:
            var messages: [OpenAIMessage] = []
            if let sys = systemPrompt { messages.append(OpenAIMessage(role: "system", content: sys)) }
            messages.append(OpenAIMessage(role: "user", content: prompt))
            let kimiBody = OpenAIRequest(model: snapshot.model, messages: messages, maxTokens: maxTokens, stream: false)
            let kimiData = try await postJSONStatic(
                url: kimiURL,
                body: kimiBody,
                headers: [
                    "Authorization": "Bearer \(snapshot.apiKey)",
                    "content-type": "application/json"
                ],
                timeout: effectiveTimeout
            )
            let kimiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: kimiData)
            return kimiResponse.choices.first?.message.content ?? ""

        case .ollama:
            guard let url = URL(string: "\(snapshot.ollamaBaseUrl)/api/generate") else {
                throw LLMError.apiError(statusCode: 0, body: "Invalid Ollama base URL: \(snapshot.ollamaBaseUrl)")
            }
            let body = OllamaRequest(model: snapshot.model, prompt: prompt, system: systemPrompt, stream: false)
            let data = try await postJSONStatic(url: url, body: body, headers: ["content-type": "application/json"], timeout: effectiveTimeout)
            let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
            return response.response

        case .appleIntelligence:
            return try await AppleIntelligenceService.shared.generate(prompt: prompt, systemPrompt: systemPrompt)
        }
    }

    /// Nonisolated HTTP helper — same logic as postJSON but callable from any context.
    /// `timeout` overrides the default 60s request timeout (enrichment passes use 25s).
    nonisolated private static func postJSONStatic<T: Encodable>(url: URL, body: T, headers: [String: String], timeout: TimeInterval = requestTimeout) async throws -> Data {
        let encoded = try JSONEncoder().encode(body)
        for attempt in 0..<2 {
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "POST"
            request.httpBody = encoded
            for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                let err = LLMError.apiError(statusCode: http.statusCode, body: String((String(data: data, encoding: .utf8) ?? "").prefix(300)))
                if attempt == 0 && err.isTransient {
                    Log.pipeline.info("Transient API error \(http.statusCode), retrying in 2s…")
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
                throw err
            }
            return data
        }
        throw LLMError.apiError(statusCode: 0, body: "Unexpected retry exhaustion")
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

    /// True when the error indicates an authentication or authorization failure.
    /// Used by triage to decide whether to fall back to Apple Intelligence.
    /// Only 401 (unauthorized) and 403 (forbidden) are auth errors.
    /// 400 (bad request) is a validation error — NOT auth, and should surface to user.
    var isAuthError: Bool {
        switch self {
        case .apiError(let code, _): code == 401 || code == 403
        }
    }

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body):
            switch code {
            case 429: return "The API is rate-limited. Please wait a moment and try again."
            case 529: return "The AI service is temporarily overloaded. Please try again in a few seconds."
            case 503: return "The AI service is temporarily unavailable. Please try again shortly."
            case 502: return "The AI service returned a bad gateway error. Please try again."
            case 401: return "Invalid API key. Check your key in Settings."
            case 403: return "Access denied. Your API key may not have the required permissions."
            case 400:
                // Surface the API's validation error — it usually explains exactly what's wrong
                let detail = body.isEmpty ? "" : " — \(body.prefix(200))"
                return "Bad request (400)\(detail)"
            default: return "API error \(code). Please try again or check your connection."
            }
        }
    }
}

// MARK: - Result Type

nonisolated struct ConnectionTestResult: Sendable {
    var success: Bool
    var message: String
}

// MARK: - Anthropic Types

private nonisolated struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    var stream: Bool = false

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream
        case maxTokens = "max_tokens"
    }
}

private nonisolated struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private nonisolated struct AnthropicResponse: Decodable {
    let content: [AnthropicContent]
}

private nonisolated struct AnthropicContent: Decodable {
    let text: String
}

private nonisolated struct AnthropicStreamEvent: Decodable {
    let delta: AnthropicDelta?
}

private nonisolated struct AnthropicDelta: Decodable {
    let text: String?
}

// MARK: - OpenAI Types

private nonisolated struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case maxTokens = "max_tokens"
    }
}

private nonisolated struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private nonisolated struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
}

private nonisolated struct OpenAIChoice: Decodable {
    let message: OpenAIMessage
}

private nonisolated struct OpenAIStreamEvent: Decodable {
    let choices: [OpenAIStreamChoice]
}

private nonisolated struct OpenAIStreamChoice: Decodable {
    let delta: OpenAIDelta
}

private nonisolated struct OpenAIDelta: Decodable {
    let content: String?
}

// MARK: - Gemini Types

private nonisolated struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private nonisolated struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

private nonisolated struct GeminiPart: Encodable {
    let text: String
}

private nonisolated struct GeminiGenerationConfig: Encodable {
    let maxOutputTokens: Int
}

private nonisolated struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private nonisolated struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent
}

private nonisolated struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]
}

private nonisolated struct GeminiResponsePart: Decodable {
    let text: String
}

// MARK: - Ollama Types

private nonisolated struct OllamaRequest: Encodable {
    let model: String
    let prompt: String
    let system: String?
    let stream: Bool
}

private nonisolated struct OllamaResponse: Decodable {
    let response: String
}

private nonisolated struct OllamaStreamChunk: Decodable {
    let response: String
    let done: Bool
}

private nonisolated struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
}

private nonisolated struct OllamaModel: Decodable {
    let name: String
}
