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
}
