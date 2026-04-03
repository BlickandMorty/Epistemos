import Foundation
import Testing

@Suite("Composer Attachment Entry Audit")
struct ComposerAttachmentEntryAuditTests {
    @Test("shared chat composers teach @ attachment entry and drop shortcut buttons")
    func sharedChatComposersTeachAtEntryAndDropShortcutButtons() throws {
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(!mainChat.contains("ComposerContextShortcutBar("))
        #expect(!landing.contains("ComposerContextShortcutBar("))
        #expect(!miniChat.contains("ComposerContextShortcutBar("))

        #expect(mainChat.contains("ComposerAttachmentEntryHints.mainChatPlaceholder"))
        #expect(landing.contains("ComposerAttachmentEntryHints.landingPlaceholder"))
        #expect(miniChat.contains("ComposerAttachmentEntryHints.mainChatPlaceholder"))
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
