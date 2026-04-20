import AppIntents
import SwiftData

// MARK: - Folder Entity
// Maps to SDFolder in SwiftData. Used by MoveNoteToFolderIntent
// and RunTriageIntent for folder-scoped operations.

struct FolderEntity: AppEntity, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Folder")
    }
    static var defaultQuery: FolderEntityQuery {
        FolderEntityQuery()
    }

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
            do {
                if let folder = try context.fetch(descriptor).first {
                    results.append(folder.toFolderEntity())
                }
            } catch {
                Log.app.error(
                    "FolderEntityQuery: failed to fetch folder \(String(id.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
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
        let folders: [SDFolder]
        do {
            folders = try context.fetch(descriptor)
        } catch {
            Log.app.error(
                "FolderEntityQuery: failed to fetch folders: \(error.localizedDescription, privacy: .public)"
            )
            return IntentItemCollection(items: [])
        }
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
        let folders: [SDFolder]
        do {
            folders = try context.fetch(descriptor)
        } catch {
            Log.app.error(
                "FolderEntityQuery: failed to fetch folders: \(error.localizedDescription, privacy: .public)"
            )
            return IntentItemCollection(items: [])
        }
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
