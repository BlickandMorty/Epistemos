import AppIntents
import SwiftData

// MARK: - System Search Intent (.system domain)
// Universal search across all Lucid content: notes, research, chat history.
// This is the most powerful schema — Apple Intelligence can compose it with
// any other intent: "Find my notes about quantum and summarize them"

@AppIntent(schema: .system.search)
struct SystemSearchIntent: AppIntent {
    static var title: LocalizedStringResource { "Search Epistemos" }
    static var description: IntentDescription {
        IntentDescription("Searches across all your Epistemos notes, research, and chat history.")
    }
    static var openAppWhenRun: Bool { true }

    @Parameter
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some ReturnsValue<[NoteEntity]> {
        guard let bootstrap = AppBootstrap.shared else { return .result(value: []) }
        let context = ModelContext(bootstrap.modelContainer)
        // Use SQLite predicate via localizedStandardContains —
        // avoids reading every disk-backed note body just to answer a shortcut search.
        var descriptor = SDPage.searchDescriptor(query: criteria.term)
        descriptor.fetchLimit = 20
        let pages: [SDPage]
        do {
            pages = try context.fetch(descriptor)
        } catch {
            Log.app.error(
                "SystemSearchIntent: failed to fetch search results: \(error.localizedDescription, privacy: .public)"
            )
            return .result(value: [])
        }
        let matched = pages.map { $0.toNoteEntity() }

        return .result(value: matched)
    }
}
