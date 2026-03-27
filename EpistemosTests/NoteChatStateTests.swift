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

    @Test("operation submit discards an existing inline response before starting a new stream")
    @MainActor func operationSubmitDiscardsExistingInlineResponse() throws {
        let inference = InferenceState()
        let triage = TriageService(inference: inference, localLLMService: CapturingStreamingLLMClient())

        let state = NoteChatState(pageId: "page-inline-replace")
        state.noteBodyProvider = { "Original note body." }
        state.hasResponse = true
        state.useResponsePanel = false
        state.responseText = "stale inline response"

        var events: [String] = []
        state.onDiscard = { events.append("discard") }
        state.onStreamStart = { _ in events.append("start") }

        state.submitQuery(
            "Rewrite this paragraph",
            operation: .rewrite,
            triageService: triage
        )

        #expect(Array(events.prefix(2)) == ["discard", "start"])
    }

    @Test("note chat includes related instant recall context in the streamed prompt")
    @MainActor func noteChatInjectsInstantRecallContext() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = CapturingStreamingLLMClient()
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-live")
        state.noteBodyProvider = { "Current note body." }
        state.instantRecallSearcher = { _, _ in
            [
                InstantRecallResult(id: "page-live", text: "Current note body duplicate", score: 0.99),
                InstantRecallResult(id: "page-related", text: "Bayesian updating intersects with evidential reasoning in uncertain systems.", score: 0.88),
            ]
        }

        state.submitQuery("How does this connect?", triageService: triage)

        for _ in 0..<20 where llm.lastStreamPrompt == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        let capturedPrompt = try #require(llm.lastStreamPrompt)
        #expect(capturedPrompt.contains("Related notes from instant recall:"))
        #expect(capturedPrompt.contains("page-related"))
        #expect(capturedPrompt.contains("Bayesian updating intersects with evidential reasoning"))
        #expect(!capturedPrompt.contains("Current note body duplicate"))
    }

    @Test("note chat indexes the current note body before streaming")
    @MainActor func noteChatIndexesCurrentNoteForInstantRecall() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = CapturingStreamingLLMClient()
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-index")
        state.noteBodyProvider = { "Fresh note body for indexing." }

        var indexedNoteId: String?
        var indexedText: String?
        state.instantRecallIndexer = { noteId, text in
            indexedNoteId = noteId
            indexedText = text
        }

        state.submitQuery("Summarize the note.", triageService: triage)

        for _ in 0..<20 where llm.lastStreamPrompt == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(indexedNoteId == "page-index")
        #expect(indexedText == "Fresh note body for indexing.")
    }

    @Test("note chat forwards empty current note bodies so instant recall can remove stale entries")
    @MainActor func noteChatForwardsEmptyCurrentNoteForInstantRecall() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = CapturingStreamingLLMClient()
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-empty")
        state.noteBodyProvider = { "   \n   " }

        var indexedNoteId: String?
        var indexedText: String?
        state.instantRecallIndexer = { noteId, text in
            indexedNoteId = noteId
            indexedText = text
        }

        state.submitQuery("Summarize the note.", triageService: triage)

        for _ in 0..<20 where llm.lastStreamPrompt == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(indexedNoteId == "page-empty")
        #expect(indexedText == "   \n   ")
    }

    @Test("note chat instant recall context filters duplicates and low-signal matches")
    @MainActor func noteChatCuratesInstantRecallContext() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = CapturingStreamingLLMClient()
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-live")
        state.noteBodyProvider = { "Current note body." }
        state.instantRecallSearcher = { _, _ in
            [
                InstantRecallResult(id: "page-related-a", text: "Bayesian updating connects to evidence weighting in uncertain systems.", score: 0.91),
                InstantRecallResult(id: "page-related-b", text: "Bayesian updating connects to evidence weighting in uncertain systems.", score: 0.87),
                InstantRecallResult(id: "page-low-signal", text: "Vague unrelated fragment", score: -0.12),
                InstantRecallResult(id: "page-empty", text: "   \n   ", score: 0.66),
            ]
        }

        state.submitQuery("How does this connect?", triageService: triage)

        for _ in 0..<20 where llm.lastStreamPrompt == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        let capturedPrompt = try #require(llm.lastStreamPrompt)
        #expect(capturedPrompt.contains("page-related-a"))
        #expect(!capturedPrompt.contains("page-related-b"))
        #expect(!capturedPrompt.contains("page-low-signal"))
        #expect(!capturedPrompt.contains("page-empty"))
        #expect(!capturedPrompt.contains("score "))
    }

    @Test("streaming task is released after a successful completion")
    @MainActor func streamingTaskReleasedAfterCompletion() async throws {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = CapturingStreamingLLMClient()
        llm.streamTokens = ["done"]
        let triage = TriageService(inference: inference, localLLMService: llm)

        let state = NoteChatState(pageId: "page-complete")
        state.noteBodyProvider = { "" }
        state.submitQuery("Finish this.", triageService: triage)

        for _ in 0..<50 where state.isStreaming {
            try await Task.sleep(for: .milliseconds(10))
        }

        let mirror = Mirror(reflecting: state)
        let streamingTaskValue = mirror.children.first(where: { $0.label == "streamingTask" })?.value
        #expect(["nil", "Optional(nil)"].contains(String(describing: streamingTaskValue)))
    }
}

@Suite("DialogueChatState")
struct DialogueChatStateTests {
    @Test("related note formatter preserves order and reasons")
    func relatedNoteFormatterPreservesOrder() {
        let section = DialogueChatState.formatRelatedNotesSection(
            relatedIds: ["page-b", "page-a"],
            reasonLists: [["supports"], ["questions", "expands"]],
            noteBodies: [
                VaultManifest.NoteBody(pageId: "page-a", title: "Alpha", body: "Alpha body"),
                VaultManifest.NoteBody(pageId: "page-b", title: "Beta", body: "Beta body"),
            ]
        )

        #expect(section.contains("[SUPPORTS] Beta"))
        #expect(section.contains("[QUESTIONS, EXPANDS] Alpha"))
        #expect(section.range(of: "Beta")?.lowerBound ?? section.startIndex < section.range(of: "Alpha")?.lowerBound ?? section.endIndex)
    }
}

@Suite("DisplayPacedTextBuffer")
struct DisplayPacedTextBufferTests {

    @Test("scheduled flush coalesces appended text")
    @MainActor func scheduledFlushCoalescesAppendedText() async throws {
        var flushed: [String] = []
        let buffer = DisplayPacedTextBuffer(flushInterval: .milliseconds(5)) { delta in
            flushed.append(delta)
        }

        buffer.append("Hello")
        buffer.append(" ")
        buffer.append("World")

        for _ in 0..<20 where flushed.isEmpty {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(flushed == ["Hello World"])
    }

    @Test("reset cancels a pending scheduled flush")
    @MainActor func resetCancelsPendingScheduledFlush() async throws {
        var flushed: [String] = []
        let buffer = DisplayPacedTextBuffer(flushInterval: .milliseconds(20)) { delta in
            flushed.append(delta)
        }

        buffer.append("partial")
        buffer.reset()
        try await Task.sleep(for: .milliseconds(40))

        #expect(flushed.isEmpty)
    }

    @Test("threshold flushes immediately")
    @MainActor func thresholdFlushesImmediately() {
        var flushed: [String] = []
        let buffer = DisplayPacedTextBuffer(flushThresholdBytes: 4) { delta in
            flushed.append(delta)
        }

        buffer.append("hello")

        #expect(flushed == ["hello"])
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
