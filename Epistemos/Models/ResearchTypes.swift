import Foundation

// MARK: - Research Domain Types

struct ResearchPaper: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var authors: [String]
    var year: Int?
    var journal: String?
    var doi: String?
    var url: String?
    var abstract: String?
    var citationCount: Int?
    var source: String?
    var addedAt: Date
}

struct SavedPaper: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var authors: String
    var year: String?
    var journal: String?
    var doi: String?
    var abstract: String?
    var isFavorite: Bool
    var addedAt: Date

    init(id: String = UUID().uuidString, title: String, authors: String, year: String? = nil,
         journal: String? = nil, doi: String? = nil, abstract: String? = nil,
         isFavorite: Bool = false, addedAt: Date = .now) {
        self.id = id; self.title = title; self.authors = authors; self.year = year
        self.journal = journal; self.doi = doi; self.abstract = abstract
        self.isFavorite = isFavorite; self.addedAt = addedAt
    }
}

struct Citation: Identifiable, Codable, Sendable {
    var id: String
    var text: String
    var source: String?
    var pageNumber: Int?
    var authors: [String]
    var year: Int?
}

struct ResearchBook: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var authors: [String]
    var isbn: String?
    var coverUrl: String?
    var notes: String?
    var addedAt: Date
}
