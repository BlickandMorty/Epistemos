import AppIntents
import SwiftData

// MARK: - Folder Entity
// Maps to SDFolder in SwiftData. Used by MoveNoteToFolderIntent
// and RunTriageIntent for folder-scoped operations.

struct FolderEntity: AppEntity, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Folder")
    nonisolated(unsafe) static var defaultQuery = FolderEntityQuery()

    var id: String
    @Property(title: "Name") var name: String
    @Property(title: "Note Count") var noteCount: Int

    init(id: String, name: String, noteCount: Int = 0) {
        self.id = id
        self.name = name
        self.noteCount = noteCount
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - Folder Entity Query

struct FolderEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [FolderEntity] {
        guard let bootstrap = AppBootstrap.shared else { return [] }
        let context = ModelContext(bootstrap.modelContainer)
        var results: [FolderEntity] = []
        for id in identifiers {
            let descriptor = FetchDescriptor<SDFolder>(predicate: #Predicate { $0.id == id })
            if let folder = (try? context.fetch(descriptor))?.first {
                results.append(folder.toFolderEntity())
            }
        }
        return results
    }

    @MainActor
    func entities(matching string: String) async throws -> IntentItemCollection<FolderEntity> {
        guard let bootstrap = AppBootstrap.shared else { return IntentItemCollection(items: []) }
        let context = ModelContext(bootstrap.modelContainer)
        let query = string.lowercased()
        let descriptor = FetchDescriptor<SDFolder>(
            sortBy: [SortDescriptor(\SDFolder.name)]
        )
        let folders = (try? context.fetch(descriptor)) ?? []
        let matched = folders.filter { $0.name.lowercased().contains(query) }
        return IntentItemCollection(items: matched.map { $0.toFolderEntity() })
    }

    @MainActor
    func suggestedEntities() async throws -> IntentItemCollection<FolderEntity> {
        guard let bootstrap = AppBootstrap.shared else { return IntentItemCollection(items: []) }
        let context = ModelContext(bootstrap.modelContainer)
        let descriptor = FetchDescriptor<SDFolder>(
            sortBy: [SortDescriptor(\SDFolder.name)]
        )
        let folders = (try? context.fetch(descriptor)) ?? []
        return IntentItemCollection(items: folders.map { $0.toFolderEntity() })
    }
}

// MARK: - SDFolder → FolderEntity

extension SDFolder {
    func toFolderEntity() -> FolderEntity {
        FolderEntity(
            id: id,
            name: name,
            noteCount: pages?.count ?? 0
        )
    }
}
