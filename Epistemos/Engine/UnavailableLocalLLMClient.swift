import Foundation

@MainActor
final class UnavailableLocalLLMClient: LocalConfigurableLLMClient {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        throw LocalInferenceRoutingError.runtimeUnavailable
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(
            success: false,
            message: "Epistemos app-local model generation has been removed. Use Work/OpenCode or Goose for model-backed chat."
        )
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .localMLX, model: "", reasoningMode: .fast)
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) async throws -> String {
        _ = (reasoningMode, modelID, steeringHintsJSON)
        return try await generate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error> {
        _ = (reasoningMode, modelID, steeringHintsJSON)
        return stream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }
}
