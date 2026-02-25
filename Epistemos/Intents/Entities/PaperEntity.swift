import AppIntents

// MARK: - Paper Entity
// Maps to ResearchPaper from Semantic Scholar API results.
// Used by ResearchTopicIntent and FindGapsIntent.

struct PaperEntity: AppEntity, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Paper")
    nonisolated(unsafe) static var defaultQuery = PaperEntityQuery()

    var id: String // DOI or Semantic Scholar paper ID
    @Property(title: "Title") var title: String
    @Property(title: "Authors") var authors: String
    @Property(title: "Year") var year: Int
    @Property(title: "Citations") var citationCount: Int
    @Property(title: "Abstract") var abstract: String?

    init(id: String, title: String, authors: String = "", year: Int = 0, citationCount: Int = 0, abstract: String? = nil) {
        self.id = id
        self.title = title
        self.authors = authors
        self.year = year
        self.citationCount = citationCount
        self.abstract = abstract
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(authors) (\(year))")
    }
}

// MARK: - Paper Entity Query

struct PaperEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [PaperEntity] {
        guard let bootstrap = AppBootstrap.shared else { return [] }
        let research = bootstrap.researchState
        return research.savedPapers
            .filter { identifiers.contains($0.id) }
            .map { $0.toPaperEntity() }
    }

    @MainActor
    func entities(matching string: String) async throws -> [PaperEntity] {
        guard let bootstrap = AppBootstrap.shared else { return [] }
        let research = bootstrap.researchState
        let query = string.lowercased()
        return research.savedPapers
            .filter { $0.title.lowercased().contains(query) || $0.authors.lowercased().contains(query) }
            .map { $0.toPaperEntity() }
    }
}

// MARK: - SavedPaper → PaperEntity

extension SavedPaper {
    func toPaperEntity() -> PaperEntity {
        PaperEntity(
            id: id,
            title: title,
            authors: authors,
            year: Int(year ?? "0") ?? 0,
            citationCount: 0,
            abstract: abstract
        )
    }
}

// MARK: - ResearchPaper → PaperEntity

extension ResearchPaper {
    func toPaperEntity() -> PaperEntity {
        PaperEntity(
            id: id,
            title: title,
            authors: authors.prefix(3).joined(separator: ", "),
            year: year ?? 0,
            citationCount: citationCount ?? 0,
            abstract: abstract
        )
    }
}
