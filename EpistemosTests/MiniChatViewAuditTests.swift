import Foundation
import Testing

@Suite("MiniChat View Audit")
struct MiniChatViewAuditTests {
    @Test("mini chat uses one dedicated thread without tab chrome")
    func miniChatUsesOneDedicatedThreadWithoutTabChrome() throws {
        let source = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let threadState = try loadRepoTextFile("Epistemos/State/ThreadState.swift")

        #expect(source.contains("threadState.ensureMiniChatThread()"))
        #expect(source.contains("threadState.miniChatThread()"))
        #expect(!source.contains("MiniChatTabBar"))
        #expect(!source.contains("ThreadTab"))
        #expect(!source.contains("showRecentChats"))
        #expect(!source.contains("New Chat"))
        #expect(threadState.contains("func ensureMiniChatThread("))
        #expect(threadState.contains("func miniChatThread() -> ChatThread?"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
