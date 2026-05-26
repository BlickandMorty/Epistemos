import Foundation
import Testing

@testable import Epistemos

@Suite("System sidebar mode")
nonisolated struct SystemModeViewTests {
    @Test("system sidebar scans vault-backed runtime folders")
    func scansVaultBackedRuntimeFolders() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos-system-mode-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let transcripts = root.appendingPathComponent(ChatTranscriptVaultWriter.vaultSubdirectory, isDirectory: true)
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: transcripts, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try "chat".write(
            to: transcripts.appendingPathComponent("Example Chat.md"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: sessions.appendingPathComponent("agent-run-1", isDirectory: true),
            withIntermediateDirectories: true
        )

        let sections = SystemModeView.sections(vaultURL: root)
        let chat = try #require(sections.first { $0.title == "Chat Transcripts" })
        let logs = try #require(sections.first { $0.title == "Agent Logs" })

        #expect(chat.items.map(\.title).contains("Example Chat"))
        #expect(logs.items.map(\.title).contains("agent-run-1"))
        #expect(!sections.contains { $0.status == "No items loaded" })
    }

    @Test("system sidebar source is not a static empty placeholder")
    func sourceIsNotStaticEmptyPlaceholder() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Sidebar/ModeSystem/SystemModeView.swift")

        #expect(source.contains("static func sections("))
        #expect(source.contains("contentsOfDirectory("))
        #expect(source.contains("ChatTranscriptVaultWriter.vaultSubdirectory"))
        #expect(!source.contains("Text(\"No items loaded\")"))
    }
}
