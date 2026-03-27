import Foundation
import AppIntents
import SwiftData

struct IntentSearchHit: Sendable, Equatable {
    let pageId: String
    let snippet: String?
}

enum AppIntentSearchSupport {
    nonisolated static var searchableTabs: [NavTab] {
        NavTab.allCases.filter { $0 != .omega }
    }

    static func sanitizeSnippet(_ snippet: String) -> String? {
        let cleaned = snippet
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func orderedMatches(
        from results: [SearchResult],
        availablePageIds: Set<String>,
        limit: Int
    ) -> [IntentSearchHit] {
        guard limit > 0 else { return [] }

        var seen: Set<String> = []
        var matches: [IntentSearchHit] = []
        matches.reserveCapacity(min(limit, results.count))

        for result in results where availablePageIds.contains(result.pageId) {
            guard seen.insert(result.pageId).inserted else { continue }
            matches.append(IntentSearchHit(
                pageId: result.pageId,
                snippet: sanitizeSnippet(result.snippet)
            ))
            if matches.count == limit {
                break
            }
        }

        return matches
    }

    @MainActor
    static func rankedPages(
        query: String,
        bootstrap: AppBootstrap,
        limit: Int,
        include: (SDPage) -> Bool
    ) async -> [(page: SDPage, snippet: String?)] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else { return [] }

        let searchResults = await bootstrap.vaultSync.searchFullAsync(
            query: trimmedQuery,
            limit: max(limit * 3, limit)
        )
        let context = ModelContext(bootstrap.modelContainer)

        if !searchResults.isEmpty {
            var pagesById: [String: SDPage] = [:]
            pagesById.reserveCapacity(searchResults.count)

            for pageId in Set(searchResults.map(\.pageId)) {
                guard let page = fetchPage(id: pageId, in: context), include(page) else { continue }
                pagesById[pageId] = page
            }

            let matches = orderedMatches(
                from: searchResults,
                availablePageIds: Set(pagesById.keys),
                limit: limit
            )
            if !matches.isEmpty {
                return matches.compactMap { hit in
                    guard let page = pagesById[hit.pageId] else { return nil }
                    return (page: page, snippet: hit.snippet)
                }
            }
        }

        var descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(limit * 10, 300)
        let fallbackPages = (try? context.fetch(descriptor)) ?? []
        return Array(
            fallbackPages
                .filter { include($0) }
                .filter {
                    $0.title.localizedStandardContains(trimmedQuery)
                        || $0.tags.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
                }
                .prefix(limit)
                .map { (page: $0, snippet: nil) }
        )
    }

    @MainActor
    private static func fetchPage(id: String, in context: ModelContext) -> SDPage? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }
}

// MARK: - Note Entity
// Maps to SDPage in SwiftData. Used by custom intents (search, open,
// move, summarize) for Siri/Shortcuts access to individual notes.

struct NoteEntity: AppEntity, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Note")
    }
    static var defaultQuery: NoteEntityQuery {
        NoteEntityQuery()
    }

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
        let matches = await AppIntentSearchSupport.rankedPages(
            query: string,
            bootstrap: bootstrap,
            limit: 20
        ) { page in
            !page.isArchived && page.templateId == nil
        }
        return IntentItemCollection(items: matches.map { match in
            match.page.toNoteEntity(contentPreview: match.snippet)
        })
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
    @MainActor func toNoteEntity(contentPreview: String? = nil) -> NoteEntity {
        let pageBody = contentPreview ?? NoteWindowManager.shared.currentBody(for: id)
        return NoteEntity(
            id: id,
            title: title.isEmpty ? "Untitled" : title,
            content: pageBody.isEmpty ? nil : String(pageBody.prefix(500)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
