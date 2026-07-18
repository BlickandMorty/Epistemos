import AppIntents
import SwiftData

// MARK: - Note Action Intents (Custom)
// Quick actions on notes. Free V1 compiles deterministic capture,
// open, move, and search actions; paid builds additionally compile
// model-backed note summarization.

// MARK: Quick Capture

struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource { "Quick Capture" }
    static var description: IntentDescription {
        IntentDescription("Creates a new note with the given text already filled in.")
    }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Title")
    var noteTitle: String

    @Parameter(title: "Body")
    var body: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }

        // Route through TextCapturePipeline for full entity/graph/trace extraction.
        // Build raw text from title + body.
        let rawText: String
        if let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawText = "# \(noteTitle)\n\n\(body)"
        } else {
            rawText = noteTitle
        }

        let context = ModelContext(bootstrap.modelContainer)
        let result = try await bootstrap.textCapturePipeline.run(
            rawText: rawText,
            modelContext: context
        )

        guard let noteId = result.createdNoteID else {
            throw IntentError.creationFailed
        }
        guard result.mutationEnvelopePersisted else {
            throw TextCaptureError.persistenceFailed("mutation envelope was not persisted")
        }
        NoteWindowManager.shared.open(pageId: noteId)

        let entityInfo = result.entities.isEmpty ? "" : " · \(result.entities.count) entities"
        let taskInfo = result.tasks.isEmpty ? "" : " · \(result.tasks.count) tasks"
        return .result(dialog: "Captured \"\(result.title)\" in Epistemos\(entityInfo)\(taskInfo).")
    }
}

// MARK: Open Vault File

struct OpenVaultFileIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Vault File" }
    static var description: IntentDescription {
        IntentDescription("Opens a note from your Epistemos vault.")
    }
    static var openAppWhenRun: Bool { true }

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
    static var title: LocalizedStringResource { "Move Note to Folder" }
    static var description: IntentDescription {
        IntentDescription("Moves a note to a different folder in your vault.")
    }

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

        let page: SDPage
        do {
            guard let fetchedPage = try context.fetch(pageDescriptor).first else {
                return .result(dialog: "Could not find the note.")
            }
            page = fetchedPage
        } catch {
            Log.app.error(
                "MoveNoteToFolderIntent: failed to fetch note \(String(targetId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return .result(dialog: "Could not load the note.")
        }

        let folder: SDFolder
        do {
            guard let fetchedFolder = try context.fetch(folderDescriptor).first else {
                return .result(dialog: "Could not find the folder \"\(destination.name)\".")
            }
            folder = fetchedFolder
        } catch {
            Log.app.error(
                "MoveNoteToFolderIntent: failed to fetch folder \(String(destId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return .result(dialog: "Could not load the folder \"\(destination.name)\".")
        }

        page.folder = folder
        do {
            try context.save()
        } catch {
            return .result(dialog: "Failed to save: \(error.localizedDescription)")
        }

        return .result(dialog: "Moved \"\(page.title)\" to \(folder.name).")
    }
}

// MARK: Search Documents

struct SearchDocumentsIntent: AppIntent {
    static var title: LocalizedStringResource { "Search Documents" }
    static var description: IntentDescription {
        IntentDescription("Searches within your Epistemos documents for specific content.")
    }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Query")
    var query: String

    @MainActor
    func perform() async throws -> some ReturnsValue<[NoteEntity]> {
        guard let bootstrap = AppBootstrap.shared else { return .result(value: []) }
        let matches = await AppIntentSearchSupport.rankedPages(
            query: query,
            bootstrap: bootstrap,
            limit: 20
        ) { page in
            !page.isArchived && page.templateId == nil
        }

        return .result(value: matches.map { match in
            match.page.toNoteEntity(contentPreview: match.snippet)
        })
    }
}
