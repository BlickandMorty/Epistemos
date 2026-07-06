import Foundation

@MainActor
enum NoteCreationCoordinator {
    /// Creates a Markdown note and opens it directly in Epdoc (Document) mode.
    ///
    /// Owner 2026-07-05: Epdoc is the default view for every note surface. The four
    /// Markdown lenses (Prose, Document, Preview, Source) are synced views of the same
    /// `.md` file, so there is no per-create "which surface?" prompt — the note opens in
    /// Epdoc and the user can switch lenses instantly from the editor toggles.
    static func createAndOpen(
        vaultSync: VaultSyncService,
        title: String = "Untitled",
        body: String = "",
        allowVaultSelectionPrompt: Bool = true,
        open: @escaping @MainActor (String, NoteWorkspaceMode) -> Void = { pageId, mode in
            NoteWindowManager.shared.open(pageId: pageId, initialMode: mode)
        }
    ) async {
        guard let pageId = await vaultSync.createPage(
            title: title,
            body: body,
            allowVaultSelectionPrompt: allowVaultSelectionPrompt
        ) else {
            return
        }
        open(pageId, .document)
    }
}
