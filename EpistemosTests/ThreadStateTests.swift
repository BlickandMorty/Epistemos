import Testing
@testable import Epistemos

@Suite("Thread State")
struct ThreadStateTests {
    @MainActor
    @Test("utility chat surfaces reuse one dedicated thread each and do not steal active selection")
    func utilityThreadsReuseDedicatedThreadsWithoutStealingSelection() {
        let state = ThreadState()
        let mainThreadID = state.createThread(type: "chat", label: "Main")
        state.setActiveThread(mainThreadID)

        let firstMiniChatID = state.ensureMiniChatThread()
        let secondMiniChatID = state.ensureMiniChatThread()
        let firstPaletteID = state.ensurePaletteThread()
        let secondPaletteID = state.ensurePaletteThread()

        #expect(firstMiniChatID == secondMiniChatID)
        #expect(firstPaletteID == secondPaletteID)
        #expect(state.chatThreads.filter { $0.type == "miniChat" }.count == 1)
        #expect(state.chatThreads.filter { $0.type == "palette" }.count == 1)
        #expect(state.activeThreadId == mainThreadID)

        state.addMiniChatMessage(AssistantMessage(role: .user, content: "hello"))
        state.addPaletteMessage(AssistantMessage(role: .assistant, content: "world"))

        #expect(state.miniChatThread()?.messages.map(\.content) == ["hello"])
        #expect(state.paletteThread()?.messages.map(\.content) == ["world"])
        #expect(state.activeThreadId == mainThreadID)
    }
}
