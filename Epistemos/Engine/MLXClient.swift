import Foundation
import MLXLMCommon
import os

@MainActor
final class MLXClient: LLMClientProtocol {

    private let engine: MLXEngine
    private let inference: InferenceState

    init(engine: MLXEngine, inference: InferenceState) {
        self.engine = engine
        self.inference = inference
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await ensureModelLoaded()
        var messages: [Chat.Message] = []
        if let sys = systemPrompt { messages.append(.system(sys)) }
        messages.append(.user(prompt))
        let result = try await engine.generateChat(
            messages: messages,
            maxTokens: maxTokens,
            temperature: 0.6,
            enableThinking: false
        )
        if let error = result.error { throw LLMError.apiError(statusCode: 0, body: error) }
        return result.cleanedOutput
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    try await self.ensureModelLoaded()
                    var messages: [Chat.Message] = []
                    if let sys = systemPrompt { messages.append(.system(sys)) }
                    messages.append(.user(prompt))
                    let tokens = maxTokens > 0 ? maxTokens : 4096
                    let result = try await self.engine.generateChat(
                        messages: messages,
                        maxTokens: tokens,
                        temperature: 0.6,
                        enableThinking: false,
                        onChunk: { chunk in
                            continuation.yield(chunk)
                        }
                    )
                    if let error = result.error {
                        continuation.finish(throwing: LLMError.apiError(statusCode: 0, body: error))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        do {
            try await ensureModelLoaded()
            let result = try await engine.generateChat(
                messages: [.user("Reply with exactly: OK")],
                maxTokens: 20,
                temperature: 0.0,
                enableThinking: false
            )
            if let error = result.error {
                return ConnectionTestResult(success: false, message: "MLX error: \(error)")
            }
            return ConnectionTestResult(success: true, message: "MLX — \(result.cleanedOutput.prefix(40))")
        } catch {
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .mlx,
            apiKey: "",
            model: inference.mlxModelId,
            ollamaBaseUrl: ""
        )
    }

    func enrichmentSnapshot() -> LLMSnapshot {
        configSnapshot()
    }

    // MARK: - Helpers

    private func ensureModelLoaded() async throws {
        let modelId = inference.mlxModelId
        guard !modelId.isEmpty else {
            throw LLMError.apiError(statusCode: 0, body: "No MLX model selected")
        }
        guard let spec = MLXModelRegistry.find(id: modelId) else {
            throw LLMError.apiError(statusCode: 0, body: "Unknown MLX model: \(modelId)")
        }
        let loaded = await engine.loadedModelId
        if loaded != spec.hfId {
            _ = try await engine.loadModel(id: spec.hfId)
        }
    }
}
