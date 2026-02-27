import AppIntents
import CoreLocation
import SwiftData

// MARK: - Journal Intents (.journal domain)
// Daily journal creation and search. Lucid's journal entries are SDPages
// with isJournal = true, stored in the vault like any other note.

// MARK: Journal Entity

@AppEntity(schema: .journal.entry)
struct JournalEntity: AppEntity {
    struct JournalEntityQuery: EntityStringQuery {
        static var persistentIdentifier: String { "JournalEntityQuery" }

        @MainActor
        func entities(for identifiers: [JournalEntity.ID]) async throws -> [JournalEntity] {
            guard let bootstrap = AppBootstrap.shared else { return [] }
            let context = ModelContext(bootstrap.modelContainer)
            var results: [JournalEntity] = []
            for uuid in identifiers {
                let idString = uuid.uuidString
                let descriptor = FetchDescriptor<SDPage>(
                    predicate: #Predicate { $0.id == idString && $0.isJournal == true })
                if let page = (try? context.fetch(descriptor))?.first {
                    results.append(page.toJournalEntity())
                }
            }
            return results
        }

        @MainActor
        func entities(matching string: String) async throws -> [JournalEntity] {
            guard let bootstrap = AppBootstrap.shared else { return [] }
            let context = ModelContext(bootstrap.modelContainer)
            let query = string.lowercased()
            var descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate { $0.isJournal == true },
                sortBy: [SortDescriptor(\SDPage.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 100
            let pages = (try? context.fetch(descriptor)) ?? []
            return
                pages
                .filter {
                    $0.isJournal
                        && ($0.title.lowercased().contains(query)
                            || $0.body.lowercased().contains(query))
                }
                .prefix(10)
                .map { $0.toJournalEntity() }
        }
    }

    nonisolated(unsafe) static var defaultQuery = JournalEntityQuery()
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title ?? "Journal Entry")")
    }

    let id: UUID

    @Property
    var title: String?

    @Property
    var message: AttributedString?

    @Property
    var mediaItems: [IntentFile]

    @Property
    var entryDate: Date?

    @Property
    var location: CLPlacemark?

    init(id: UUID = UUID(), title: String? = nil) {
        self.id = id
        self.title = title
        self.mediaItems = []
        self.entryDate = .now
    }
}

// MARK: Create Journal Entry

@AppIntent(schema: .journal.createEntry)
struct CreateJournalIntent: AppIntent {
    @Parameter
    var message: AttributedString

    @Parameter
    var title: String?

    @Parameter
    var entryDate: Date?

    @Parameter
    var location: CLPlacemark?

    @Parameter(default: [])
    var mediaItems: [IntentFile]

    @MainActor
    func perform() async throws -> some ReturnsValue<JournalEntity> {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        let journalTitle = title ?? "Journal — \(formatter.string(from: entryDate ?? .now))"
        let bodyText = String(message.characters)

        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        guard let pageId = await bootstrap.vaultSync.createPage(title: journalTitle) else {
            throw IntentError.creationFailed
        }

        // Mark as journal and set body content
        let context = ModelContext(bootstrap.modelContainer)
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        if let page = (try? context.fetch(descriptor))?.first {
            page.isJournal = true
            page.body = bodyText
            page.needsVaultSync = true
            do {
                try context.save()
            } catch {
                Log.app.error("Journal save failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        NoteWindowManager.shared.open(pageId: pageId)
        return .result(
            value: JournalEntity(id: UUID(uuidString: pageId) ?? UUID(), title: journalTitle))
    }
}

// MARK: Search Journal

@AppIntent(schema: .journal.search)
struct SearchJournalIntent: AppIntent {
    @Parameter
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some ReturnsValue<[JournalEntity]> {
        guard let bootstrap = AppBootstrap.shared else { return .result(value: []) }
        let context = ModelContext(bootstrap.modelContainer)
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.isJournal == true },
            sortBy: [SortDescriptor(\SDPage.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let pages = (try? context.fetch(descriptor)) ?? []
        let query = criteria.term.lowercased()

        let matched =
            pages
            .filter {
                $0.isJournal
                    && ($0.title.lowercased().contains(query)
                        || $0.body.lowercased().contains(query))
            }
            .prefix(20)
            .map { $0.toJournalEntity() }

        return .result(value: Array(matched))
    }
}

// MARK: - SDPage → JournalEntity

extension SDPage {
    func toJournalEntity() -> JournalEntity {
        let entity = JournalEntity(
            id: UUID(uuidString: id) ?? UUID(),
            title: title.isEmpty ? "Journal Entry" : title
        )
        entity.entryDate = createdAt
        entity.message = try? AttributedString(markdown: String(body.prefix(500)))
        return entity
    }
}
