import AppKit

enum NoteCreationSurface {
    case prose
    case document

    var initialMode: NoteWorkspaceMode {
        switch self {
        case .prose:
            .edit
        case .document:
            .document
        }
    }
}

@MainActor
enum NoteCreationCoordinator {
    static func createAndOpen(
        vaultSync: VaultSyncService,
        title: String = "Untitled",
        body: String = "",
        allowVaultSelectionPrompt: Bool = true,
        open: @escaping @MainActor (String, NoteWorkspaceMode) -> Void = { pageId, mode in
            NoteWindowManager.shared.open(pageId: pageId, initialMode: mode)
        }
    ) async {
        guard let surface = chooseSurface() else { return }
        guard let pageId = await vaultSync.createPage(
            title: title,
            body: body,
            allowVaultSelectionPrompt: allowVaultSelectionPrompt
        ) else {
            return
        }
        open(pageId, surface.initialMode)
    }

    static func chooseSurface() -> NoteCreationSurface? {
        let alert = NSAlert()
        alert.messageText = "Create Note"
        alert.informativeText = """
        Choose the Markdown surface to open first. You can switch between Prose, Document, Preview, and Source later.
        """
        alert.addButton(withTitle: "Prose")
        alert.addButton(withTitle: "Document")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .prose
        case .alertSecondButtonReturn:
            return .document
        default:
            return nil
        }
    }
}
