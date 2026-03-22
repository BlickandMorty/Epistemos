import AppIntents
import SwiftData

// MARK: - System Search Intent (.system domain)
// Universal search across all Lucid content: notes, research, chat history.
// This is the most powerful schema — Apple Intelligence can compose it with
// any other intent: "Find my notes about quantum and summarize them"

@AppIntent(schema: .system.search)
struct SystemSearchIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Search Epistemos"
    nonisolated(unsafe) static var description: IntentDescription = "Searches across all your Epistemos notes, research, and chat history."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some ReturnsValue<[NoteEntity]> {
        guard let bootstrap = AppBootstrap.shared else { return .result(value: []) }
        let context = ModelContext(bootstrap.modelContainer)
        // Use SQLite predicate via localizedStandardContains —
        // avoids loading every @Attribute(.externalStorage) body blob.
        var descriptor = SDPage.searchDescriptor(query: criteria.term)
        descriptor.fetchLimit = 20
        let pages = (try? context.fetch(descriptor)) ?? []
        let matched = pages.map { $0.toNoteEntity() }

        return .result(value: matched)
    }
}
