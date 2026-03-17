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
