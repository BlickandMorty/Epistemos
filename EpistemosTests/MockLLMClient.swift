import Foundation
@testable import Epistemos

@MainActor
final class MockLLMClient: LLMClientProtocol {
    var generateResponse = "Mock response"
    var streamTokens: [String] = []
    private(set) var generatedPrompts: [String] = []
    private(set) var streamedPrompts: [String] = []

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        generatedPrompts.append(prompt)
        return generateResponse
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        streamedPrompts.append(prompt)
        let tokens = streamTokens.isEmpty ? [generateResponse] : streamTokens
        return AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .openAI, model: "mock")
    }
}
