import Testing

@Suite("TK1 Migration Validation")
struct TK1MigrationValidationTests {
    @Test("note workspace no longer depends on legacy preview or storage pool")
    func noteWorkspaceNoLongerDependsOnLegacyPreviewOrStoragePool() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(!source.contains("private struct NotePreviewView:"))
        #expect(!source.contains("PageStoragePool.shared.bodyText(for: pageId)"))
        #expect(!source.contains("case let tv as ClickableTextView"))
        #expect(!source.contains("ClickableTextView.createIdeaNotification"))
        #expect(!source.contains("ClickableTextView.createBrainDumpNotification"))
        #expect(!source.contains("ClickableTextView.aiOperationNotification"))
        #expect(!source.contains("ClickableTextView.blockPropertyNotification"))
        #expect(!source.contains("ClickableTextView.translateNotification"))
    }

    @Test("sidebar mini chat and bootstrap no longer touch page storage pool")
    func sidebarMiniChatAndBootstrapNoLongerTouchPageStoragePool() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!sidebar.contains("PageStoragePool.shared"))
        #expect(!miniChat.contains("PageStoragePool.shared"))
        #expect(!bootstrap.contains("PageStoragePool.shared.removeAll()"))
    }

    @Test("live note editor remains pinned to the TK2 stack")
    func liveNoteEditorRemainsPinnedToTK2Stack() throws {
        let editorView = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let noteWorkspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let notesUI = try loadRepoTextFile("Epistemos/State/NotesUIState.swift")
        let repoRoot = try repoRootURL()

        #expect(editorView.contains("ProseEditorRepresentable2("))
        #expect(!editorView.contains("ProseEditorRepresentable("))
        #expect(!noteWorkspace.contains("NotePreviewRenderer"))
        #expect(!notesUI.contains("useTK2Editor"))
        #expect(!notesUI.contains("tk2DefaultsKey"))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Notes/ProseEditorRepresentable.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Notes/ClickableTextView.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Notes/PageStoragePool.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Notes/MarkdownTextStorage.swift").path))
    }

    @Test("legacy note helper files are no longer compiled into the production app target")
    func legacyNoteHelpersAreNoLongerInProduction() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let repoRoot = try repoRootURL()

        #expect(!project.contains("BlockRefAutocomplete.swift in Sources"))
        #expect(!project.contains("TransclusionOverlayManager.swift in Sources"))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Notes/BlockRefAutocomplete.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Notes/TransclusionOverlayManager.swift").path))
    }

    private func repoRootURL() throws -> URL {
        try sourceMirrorRootURL()
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
