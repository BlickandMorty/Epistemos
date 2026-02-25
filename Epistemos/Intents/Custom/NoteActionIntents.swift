import AppIntents
import SwiftData

// MARK: - Note Action Intents (Custom)
// Quick actions on notes. QuickCapture creates a pre-filled note;
// SummarizeNote runs AI on the active note. OpenVaultFile and
// MoveNoteToFolder manage vault files as custom intents.

// MARK: Quick Capture

struct QuickCaptureIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Quick Capture"
    nonisolated(unsafe) static var description: IntentDescription =
        "Creates a new note with the given text already filled in."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Title")
    var noteTitle: String

    @Parameter(title: "Body")
    var body: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }

        guard let pageId = await bootstrap.vaultSync.createPage(title: noteTitle, body: body ?? "")
        else {
            throw IntentError.creationFailed
        }

        NoteWindowManager.shared.open(pageId: pageId)
        return .result(dialog: "Captured \"\(noteTitle)\" in Epistemos.")
    }
}

// MARK: Summarize Note

struct SummarizeNoteIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Summarize Note"
    nonisolated(unsafe) static var description: IntentDescription =
        "Summarizes the currently open note using AI."
    nonisolated(unsafe) static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }

        // Get the currently active page from NotesUI
        guard let activePageId = bootstrap.notesUI.activePageId else {
            return .result(dialog: "No note is currently open. Open a note first, then try again.")
        }

        let context = ModelContext(bootstrap.modelContainer)
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == activePageId })

        guard let page = (try? context.fetch(descriptor))?.first else {
            return .result(dialog: "Could not find the active note.")
        }

        let content = page.body

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(dialog: "The note \"\(page.title)\" is empty — nothing to summarize.")
        }

        let response = try await bootstrap.triageService.generate(
            prompt: "Summarize this note:\n\n# \(page.title)\n\n\(String(content.prefix(3000)))",
            systemPrompt:
                "You are a research assistant. Produce a concise summary (3-5 sentences) of the note. Capture the key ideas, arguments, and any open questions. Use markdown for emphasis.",
            operation: .summarize,
            contentLength: content.count
        )

        return .result(dialog: "Summary of \"\(page.title)\":\n\(String(response.prefix(400)))")
    }
}

// MARK: Open Vault File

struct OpenVaultFileIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Open Vault File"
    nonisolated(unsafe) static var description: IntentDescription =
        "Opens a note from your Epistemos vault."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Note")
    var target: NoteEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        guard AppBootstrap.shared != nil else { throw IntentError.appNotReady }
        NoteWindowManager.shared.open(pageId: target.id)
        return .result()
    }
}

// MARK: Move Note to Folder

struct MoveNoteToFolderIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Move Note to Folder"
    nonisolated(unsafe) static var description: IntentDescription =
        "Moves a note to a different folder in your vault."

    @Parameter(title: "Note")
    var target: NoteEntity

    @Parameter(title: "Destination Folder")
    var destination: FolderEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let context = ModelContext(bootstrap.modelContainer)
        let targetId = target.id
        let destId = destination.id
        let pageDescriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == targetId })
        let folderDescriptor = FetchDescriptor<SDFolder>(predicate: #Predicate { $0.id == destId })

        guard let page = (try? context.fetch(pageDescriptor))?.first else {
            return .result(dialog: "Could not find the note.")
        }
        guard let folder = (try? context.fetch(folderDescriptor))?.first else {
            return .result(dialog: "Could not find the folder \"\(destination.name)\".")
        }

        page.folder = folder
        try? context.save()

        return .result(dialog: "Moved \"\(page.title)\" to \(folder.name).")
    }
}

// MARK: Search Documents

struct SearchDocumentsIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Search Documents"
    nonisolated(unsafe) static var description: IntentDescription =
        "Searches within your Epistemos documents for specific content."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Query")
    var query: String

    @MainActor
    func perform() async throws -> some ReturnsValue<[NoteEntity]> {
        guard let bootstrap = AppBootstrap.shared else { return .result(value: []) }
        let context = ModelContext(bootstrap.modelContainer)
        var descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let pages = (try? context.fetch(descriptor)) ?? []
        let queryLower = query.lowercased()

        let matched =
            pages
            .filter {
                $0.title.lowercased().contains(queryLower)
                    || $0.body.lowercased().contains(queryLower)
                    || $0.tags.contains(where: { $0.lowercased().contains(queryLower) })
            }
            .prefix(20)
            .map { $0.toNoteEntity() }

        return .result(value: Array(matched))
    }
}
