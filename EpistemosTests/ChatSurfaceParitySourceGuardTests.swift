import Testing

/// P7.5 — locks chat-surface capability parity so MiniChat / NoteChat can't
/// silently drift behind the Main chat again. Every local-model chat surface
/// must wire the SHARED honesty + capability methods on `InferenceState`
/// (`localChatModelMemoryBlocker` P1.4, `fastEffortRouteReason` P1.9) — parity
/// by sharing the logic, not by forking it. Source-guard (deterministic; no
/// runtime), so a future edit that removes a capability from one surface fails
/// here at test time.
@Suite("Chat surface capability parity")
struct ChatSurfaceParitySourceGuardTests {

    @Test("Main chat composer wires the shared memory blocker + Fast effort + capability panel")
    func mainChatWiresSharedCapabilities() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        #expect(source.contains("localChatModelMemoryBlocker"))
        #expect(source.contains("fastEffortHint"))
        #expect(source.contains("AgentToolTogglePanel"))
    }

    @Test("MiniChat reaches parity: memory blocker + Fast effort + capability panel via the shared methods")
    func miniChatReachesParity() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        // P1.4 honest memory blocker (shared InferenceState method).
        #expect(source.contains("localChatModelMemoryBlocker"))
        // P1.9 Fast effort visibility (shared InferenceState method).
        #expect(source.contains("fastEffortRouteReason"))
        // P2.1/P2.4 in-chat tools + skills (shared panel component).
        #expect(source.contains("AgentToolTogglePanel"))
    }

    @Test("NoteChat ask bar reaches parity on what it can host: memory blocker + Fast effort")
    func noteChatReachesParity() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        // NoteChat is a lightweight inline ask that escalates to Main for tools,
        // so it honestly hosts the blocker + effort (not a tool panel) — both via
        // the same shared InferenceState methods as Main/Mini.
        #expect(source.contains("localChatModelMemoryBlocker"))
        #expect(source.contains("fastEffortRouteReason"))
    }
}
