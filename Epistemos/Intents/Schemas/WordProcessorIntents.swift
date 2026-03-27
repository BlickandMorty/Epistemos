import AppIntents
import SwiftData

// MARK: - Word Processor Intents (.wordProcessor domain)
// Lucid IS a word processor for research notes. These schema-backed intents
// let Apple Intelligence compose multi-step actions:
// "Create a note about quantum computing and summarize it"

// MARK: Word Processor Document Entity

@AppEntity(schema: .wordProcessor.document)
struct WordProcessorDocumentEntity: AppEntity {
    struct WordProcessorDocumentQuery: EntityStringQuery {
        static var persistentIdentifier: String { "WordProcessorDocumentQuery" }

        @MainActor
        func entities(for identifiers: [WordProcessorDocumentEntity.ID]) async throws
            -> [WordProcessorDocumentEntity]
        {
            guard let bootstrap = AppBootstrap.shared else { return [] }
            let context = ModelContext(bootstrap.modelContainer)
            var results: [WordProcessorDocumentEntity] = []
            for uuid in identifiers {
                let idString = uuid.uuidString
                let descriptor = FetchDescriptor<SDPage>(
                    predicate: #Predicate { $0.id == idString })
                if let page = (try? context.fetch(descriptor))?.first {
                    results.append(page.toWordProcessorEntity())
                }
            }
            return results
        }

        @MainActor
        func entities(matching string: String) async throws -> [WordProcessorDocumentEntity] {
            guard let bootstrap = AppBootstrap.shared else { return [] }
            let context = ModelContext(bootstrap.modelContainer)
            let query = string.lowercased()
            var descriptor = FetchDescriptor<SDPage>(
                sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 100
            let pages = (try? context.fetch(descriptor)) ?? []
            return pages.filter { $0.title.lowercased().contains(query) }.prefix(10).map {
                $0.toWordProcessorEntity()
            }
        }
    }

    static var defaultQuery: WordProcessorDocumentQuery {
        WordProcessorDocumentQuery()
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    let id: UUID

    @Property
    var name: String

    @Property
    var creationDate: Date?

    @Property
    var modificationDate: Date?

    init(id: UUID = UUID(), name: String = "Untitled Note") {
        self.id = id
        self.name = name
        self.creationDate = .now
        self.modificationDate = .now
    }
}

// MARK: Word Processor Template Entity

@AppEntity(schema: .wordProcessor.template)
struct WordProcessorDocumentTemplateEntity: AppEntity {
    struct WordProcessorTemplateQuery: EntityStringQuery {
        static var persistentIdentifier: String { "WordProcessorTemplateQuery" }

        func entities(for identifiers: [WordProcessorDocumentTemplateEntity.ID]) async throws
            -> [WordProcessorDocumentTemplateEntity]
        { [] }
        func entities(matching string: String) async throws -> [WordProcessorDocumentTemplateEntity]
        { [] }
    }

    static var defaultQuery: WordProcessorTemplateQuery {
        WordProcessorTemplateQuery()
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    let id: UUID

    @Property
    var name: String

    init(id: UUID = UUID(), name: String = "Blank Note") {
        self.id = id
        self.name = name
    }
}

// MARK: Create Note

@AppIntent(schema: .wordProcessor.create)
struct CreateNoteIntent: AppIntent {
    @Parameter
    var template: WordProcessorDocumentTemplateEntity?

    @MainActor
    func perform() async throws -> some ReturnsValue<WordProcessorDocumentEntity> {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let title = template?.name ?? "Untitled"
        guard let pageId = await bootstrap.vaultSync.createPage(title: title) else {
            throw IntentError.creationFailed
        }
        NoteWindowManager.shared.open(pageId: pageId)
        return .result(
            value: WordProcessorDocumentEntity(id: UUID(uuidString: pageId) ?? UUID(), name: title))
    }
}

// MARK: - SDPage → WordProcessorDocumentEntity

extension SDPage {
    func toWordProcessorEntity() -> WordProcessorDocumentEntity {
        WordProcessorDocumentEntity(
            id: UUID(uuidString: id) ?? UUID(),
            name: title.isEmpty ? "Untitled" : title
        )
    }
}
