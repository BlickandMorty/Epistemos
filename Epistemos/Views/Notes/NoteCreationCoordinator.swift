import Foundation

@MainActor
enum NoteCreationCoordinator {
    /// Creates a Markdown note and opens the Markdown family's default Prose surface.
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
        open(pageId, .defaultMarkdown)
    }
}
