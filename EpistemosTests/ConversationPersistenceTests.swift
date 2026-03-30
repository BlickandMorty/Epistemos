import Foundation
import Testing
@testable import Epistemos

@Suite("Conversation Persistence")
struct ConversationPersistenceTests {
    @Test("append turn writes JSONL lines and companion markdown captures all turns")
    func appendTurnWritesJSONLAndCompanionMarkdownCapturesAllTurns() async throws {
        let root = temporaryRoot()
        let persistence = ConversationPersistence(rootURL: root)
        let sessionID = UUID()

        try await persistence.appendTurn(
            turn: ConversationTurn(
                role: .user,
                content: "What changed in the vault today?",
                model: "main-qwen",
                tokens: 21
            ),
            sessionID: sessionID
        )
        try await persistence.appendTurn(
            turn: ConversationTurn(
                role: .assistant,
                content: "Three notes changed and one contradiction was detected.",
                model: "main-qwen",
                tokens: 34,
                vaultMutations: ["pricing.md"]
            ),
            sessionID: sessionID
        )
        try await persistence.appendTurn(
            turn: ConversationTurn(
                role: .assistant,
                content: "I also queued a follow-up propagation check.",
                model: "agent-loop",
                toolCalls: ["scan_for_references"]
            ),
            sessionID: sessionID
        )

        let jsonlURL = root.appendingPathComponent("sessions/\(sessionID.uuidString).jsonl")
        let jsonl = try String(contentsOf: jsonlURL, encoding: .utf8)
        #expect(jsonl.split(separator: "\n").count == 3)

        let markdownURL = try await persistence.generateCompanionMarkdown(sessionID: sessionID)
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: markdownURL.path))
        #expect(markdown.contains("What changed in the vault today?"))
        #expect(markdown.contains("Three notes changed and one contradiction was detected."))
        #expect(markdown.contains("I also queued a follow-up propagation check."))
        #expect(markdown.contains("agentic"))

        try? FileManager.default.removeItem(at: root)
    }

    @Test("finish session triggers memory flush callback")
    func finishSessionTriggersMemoryFlushCallback() async throws {
        let root = temporaryRoot()
        let recorder = FlushRecorder()
        let persistence = ConversationPersistence(
            rootURL: root,
            sessionEndMemoryFlush: { sessionID in
                await recorder.record(sessionID)
            }
        )
        let sessionID = UUID()

        try await persistence.appendTurn(
            turn: ConversationTurn(
                role: .user,
                content: "Persist this chat to the vault.",
                model: "main-qwen"
            ),
            sessionID: sessionID
        )

        _ = try await persistence.finishSession(sessionID: sessionID)

        #expect(await recorder.count() == 1)
        #expect(await recorder.lastSessionID() == sessionID)

        try? FileManager.default.removeItem(at: root)
    }

    private func temporaryRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-conversation-persistence-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        return root
    }
}

private actor FlushRecorder {
    private var sessionIDs: [UUID] = []

    func record(_ sessionID: UUID) {
        sessionIDs.append(sessionID)
    }

    func count() -> Int {
        sessionIDs.count
    }

    func lastSessionID() -> UUID? {
        sessionIDs.last
    }
}
