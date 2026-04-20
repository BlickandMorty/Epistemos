import Testing
@testable import Epistemos

@Suite("Thread State")
struct ThreadStateTests {
    @MainActor
    @Test("mini chat session lookup stays isolated by chat identifier")
    func miniChatSessionLookupStaysIsolatedByChatIdentifier() {
        let state = ThreadState()
        state.upsertMiniChatSession(
            id: "chat-a",
            label: "First",
            messages: [AssistantMessage(role: .user, content: "hello")]
        )
        state.upsertMiniChatSession(
            id: "chat-b",
            label: "Second",
            messages: [AssistantMessage(role: .assistant, content: "world")]
        )

        #expect(state.miniChatSession(id: "chat-a")?.messages.map(\.content) == ["hello"])
        #expect(state.miniChatSession(id: "chat-b")?.messages.map(\.content) == ["world"])
        #expect(state.miniChatSession(id: "missing") == nil)
    }

    @MainActor
    @Test("mini chat thinking capture buffers and clears per chat identifier")
    func miniChatThinkingCaptureBuffersAndClearsPerChatIdentifier() {
        let state = ThreadState()

        state.appendMiniChatStreamingThinking("inspect", chatID: "chat-a")
        state.appendMiniChatStreamingThinking(" graph", chatID: "chat-a")
        state.appendMiniChatStreamingThinking("other", chatID: "chat-b")

        #expect(state.miniChatStreamingThinking(chatID: "chat-a") == "inspect graph")
        #expect(state.miniChatStreamingThinking(chatID: "chat-b") == "other")

        state.clearMiniChatStreamingThinking(chatID: "chat-a")

        #expect(state.miniChatStreamingThinking(chatID: "chat-a").isEmpty)
        #expect(state.miniChatStreamingThinking(chatID: "chat-b") == "other")
    }
}
