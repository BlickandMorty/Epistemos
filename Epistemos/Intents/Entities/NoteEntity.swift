import AppIntents
import SwiftData

// MARK: - Note Entity
// Maps to SDPage in SwiftData. Used by custom intents (search, open,
// move, summarize) for Siri/Shortcuts access to individual notes.

struct NoteEntity: AppEntity, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")
    nonisolated(unsafe) static var defaultQuery = NoteEntityQuery()

    var id: String
    @Property(title: "Title") var title: String
    @Property(title: "Content") var content: String?
    @Property(title: "Created") var createdAt: Date
    @Property(title: "Updated") var updatedAt: Date

    init(id: String, title: String, content: String? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

// MARK: - Note Entity Query

struct NoteEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [NoteEntity] {
        guard let bootstrap = AppBootstrap.shared else { return [] }
        let context = ModelContext(bootstrap.modelContainer)
        var results: [NoteEntity] = []
        for id in identifiers {
            let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == id })
            if let page = (try? context.fetch(descriptor))?.first {
                results.append(page.toNoteEntity())
            }
        }
        return results
    }

    @MainActor
    func entities(matching string: String) async throws -> IntentItemCollection<NoteEntity> {
        guard let bootstrap = AppBootstrap.shared else { return IntentItemCollection(items: []) }
        let context = ModelContext(bootstrap.modelContainer)
        let query = string.lowercased()
        var descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let pages = (try? context.fetch(descriptor)) ?? []
        let matched = pages.filter {
            $0.title.lowercased().contains(query) ||
            $0.body.lowercased().contains(query) ||
            $0.tags.contains(where: { $0.lowercased().contains(query) })
        }
        return IntentItemCollection(items: matched.prefix(20).map { $0.toNoteEntity() })
    }

    @MainActor
    func suggestedEntities() async throws -> IntentItemCollection<NoteEntity> {
        guard let bootstrap = AppBootstrap.shared else { return IntentItemCollection(items: []) }
        let context = ModelContext(bootstrap.modelContainer)
        var descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let pages = (try? context.fetch(descriptor)) ?? []
        return IntentItemCollection(items: pages.map { $0.toNoteEntity() })
    }
}

// MARK: - SDPage → NoteEntity

extension SDPage {
    func toNoteEntity() -> NoteEntity {
        NoteEntity(
            id: id,
            title: title.isEmpty ? "Untitled" : title,
            content: body.isEmpty ? nil : String(body.prefix(500)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
