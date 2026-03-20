import Testing
@testable import Epistemos

@Suite("Thread State")
struct ThreadStateTests {
    @MainActor
    @Test("mini chat reuses one dedicated thread and leaves palette selection alone")
    func miniChatReusesDedicatedThreadAndLeavesPaletteSelectionAlone() {
        let state = ThreadState()
        let paletteThreadID = state.createThread(type: "palette", label: "Palette 1")
        state.setActiveThread(paletteThreadID)

        let firstMiniChatID = state.ensureMiniChatThread()
        let secondMiniChatID = state.ensureMiniChatThread()

        #expect(firstMiniChatID == secondMiniChatID)
        #expect(state.chatThreads.filter { $0.type == "miniChat" }.count == 1)
        #expect(state.activeThreadId == paletteThreadID)

        state.addMiniChatMessage(AssistantMessage(role: .user, content: "hello"))

        #expect(state.miniChatThread()?.messages.map(\.content) == ["hello"])
        #expect(state.activeThreadId == paletteThreadID)
    }
}
