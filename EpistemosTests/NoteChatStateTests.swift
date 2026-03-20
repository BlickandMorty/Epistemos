import Foundation
import Testing
@testable import Epistemos

@Suite("NoteChatState")
struct NoteChatStateTests {

    @Test("init sets pageId and defaults")
    @MainActor func initDefaults() {
        let state = NoteChatState(pageId: "page-1")
        #expect(state.pageId == "page-1")
        #expect(state.inputText.isEmpty)
        #expect(state.responseText.isEmpty)
        #expect(!state.isStreaming)
        #expect(!state.hasResponse)
        #expect(state.error == nil)
    }

    @Test("appendStreamingText accumulates tokens and flushes on stop")
    @MainActor func tokenAccumulation() {
        let state = NoteChatState(pageId: "page-2")
        state.isStreaming = true
        state.hasResponse = true

        var flushedDeltas: [String] = []
        state.onTokenFlush = { delta in flushedDeltas.append(delta) }

        state.appendStreamingText("Hello ")
        state.appendStreamingText("World")

        // stopStreaming forces synchronous flush — no timer dependency
        state.stopStreaming()

        #expect(state.responseText == "Hello World")
        #expect(!flushedDeltas.isEmpty)
    }

    @Test("appendStreamingText flushes immediately at 64KB threshold")
    @MainActor func largeTokenFlush() {
        let state = NoteChatState(pageId: "page-3")
        state.isStreaming = true
        state.hasResponse = true

        var flushCount = 0
        state.onTokenFlush = { _ in flushCount += 1 }

        // Send a chunk larger than 64KB
        let bigChunk = String(repeating: "x", count: 70_000)
        state.appendStreamingText(bigChunk)

        // Should have flushed synchronously (no timer wait needed)
        #expect(state.responseText == bigChunk)
        #expect(flushCount == 1)
    }

    @Test("acceptResponse resets state and calls onAccept")
    @MainActor func acceptLifecycle() {
        let state = NoteChatState(pageId: "page-4")
        state.responseText = "AI response"
        state.hasResponse = true

        var acceptCalled = false
        state.onAccept = { acceptCalled = true }

        state.acceptResponse()

        #expect(acceptCalled)
        #expect(!state.hasResponse)
        #expect(state.responseText.isEmpty)
    }

    @Test("discardResponse resets state and calls onDiscard")
    @MainActor func discardLifecycle() {
        let state = NoteChatState(pageId: "page-5")
        state.responseText = "AI response"
        state.hasResponse = true

        var discardCalled = false
        state.onDiscard = { discardCalled = true }

        state.discardResponse()

        #expect(discardCalled)
        #expect(!state.hasResponse)
        #expect(state.responseText.isEmpty)
    }

    @Test("stopStreaming cancels task and flushes remaining tokens")
    @MainActor func stopStreamingFlush() async throws {
        let state = NoteChatState(pageId: "page-6")
        state.isStreaming = true
        state.hasResponse = true

        state.appendStreamingText("partial ")
        // Don't wait for timer — stop immediately
        state.stopStreaming()

        #expect(!state.isStreaming)
        #expect(state.responseText == "partial ")
    }

    @Test("clear resets everything")
    @MainActor func clearResetsAll() {
        let state = NoteChatState(pageId: "page-7")
        state.inputText = "query"
        state.responseText = "response"
        state.error = "something went wrong"
        state.hasResponse = true
        state.isStreaming = true

        state.clear()

        #expect(state.inputText.isEmpty)
        #expect(state.responseText.isEmpty)
        #expect(state.error == nil)
        #expect(!state.hasResponse)
        #expect(!state.isStreaming)
    }

    @Test("stopStreaming does not append a partial assistant message after cancellation")
    @MainActor func stopStreamingDoesNotAppendPartialAssistantMessage() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = SlowStreamingLLMClient()
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-8")
        state.noteBodyProvider = { "" }
        state.submitQuery("Explain coherentism.", triageService: triage)

        for _ in 0..<20 where state.responseText.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(state.responseText == "partial ")
        state.stopStreaming()
        try await Task.sleep(for: .milliseconds(80))

        #expect(!state.isStreaming)
        #expect(state.responseText == "partial ")
        #expect(state.messages.count == 1)
        #expect(state.messages.last?.role == .user)
    }

    @Test("operation submit does not embed hidden system formatting directives into the prompt")
    @MainActor func operationSubmitDoesNotEmbedSystemFormattingDirectives() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = CapturingStreamingLLMClient()
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-9")
        state.noteBodyProvider = { "Original note body." }
        state.submitQuery(
            "Rewrite this:\n\nSelected text",
            operation: .rewrite,
            systemPrompt: "You are a writing assistant. Output ONLY the rewritten text.",
            triageService: triage
        )

        for _ in 0..<20 where llm.lastStreamPrompt == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        let capturedPrompt = try #require(llm.lastStreamPrompt)
        #expect(!capturedPrompt.contains("Output ONLY the rewritten text."))
        #expect(!capturedPrompt.contains("You are a writing assistant."))
        #expect(capturedPrompt.contains("Rewrite this:"))
        #expect(capturedPrompt.contains("Original note body."))
    }

    @Test("note chat stores only the sanitized assistant answer")
    @MainActor func noteChatStoresOnlySanitizedAssistantAnswer() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = CapturingStreamingLLMClient()
        llm.streamTokens = [
            "<think>I should inspect the framing.</think>",
            "\n\nFinal Answer:\n",
            "Treat it as a modern hegemonic label unless the source defines it more narrowly.",
        ]
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-10")
        state.noteBodyProvider = { "A note body." }
        state.submitQuery("Explain this phrase.", triageService: triage)

        for _ in 0..<50 where state.isStreaming {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(
            state.responseText
                == "Treat it as a modern hegemonic label unless the source defines it more narrowly."
        )
        #expect(state.messages.count == 2)
        #expect(
            state.messages.last?.content
                == "Treat it as a modern hegemonic label unless the source defines it more narrowly."
        )
    }
}

@MainActor
private final class SlowStreamingLLMClient: LLMClientProtocol {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        "slow-generate"
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield("partial ")
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                continuation.yield("tail")
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
    }

}

@MainActor
private final class CapturingStreamingLLMClient: LLMClientProtocol {
    private(set) var lastStreamPrompt: String?
    var streamTokens: [String] = ["ok"]

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        "unused"
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        lastStreamPrompt = prompt
        return AsyncThrowingStream { continuation in
            let tokens = streamTokens
            Task {
                for token in tokens {
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
    }

}
