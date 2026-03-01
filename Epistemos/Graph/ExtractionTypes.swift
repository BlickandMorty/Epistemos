import Foundation

// MARK: - ExtractionResult
// Codable struct for parsing LLM JSON responses from note entity extraction.
// Updated for 7-type model: sources (absorbs thinkers), quotes, tags (absorbs concepts).

nonisolated struct ExtractionResult: Codable, Sendable {
    var sources: [ExtractedSource]
    var quotes: [ExtractedQuote]
    var tags: [ExtractedTag]
    var crossNoteLinks: [CrossNoteLink]?

    nonisolated struct ExtractedSource: Codable, Sendable {
        var name: String
        var url: String?
        var title: String?
        var type: String?
        var relationship: String?
        var blockId: String?
    }

    nonisolated struct ExtractedQuote: Codable, Sendable {
        var text: String
        var attribution: String?
        var context: String?
        var blockId: String?
    }

    nonisolated struct ExtractedTag: Codable, Sendable {
        var name: String
        var description: String?
    }

    nonisolated struct CrossNoteLink: Codable, Sendable {
        var from: String
        var to: String
        var relationship: String
        var reason: String?
    }
}

// MARK: - InsightExtractionResult
// Codable struct for parsing LLM JSON responses from chat insight extraction.
// Insights map to .idea nodes in the 7-type model.

nonisolated struct InsightExtractionResult: Codable, Sendable {
    var ideas: [ExtractedIdea]
    var sourcesShared: [ExtractedSource]

    nonisolated struct ExtractedIdea: Codable, Sendable {
        var summary: String
        var evidenceGrade: String?
        var relatedEntities: [String]?
    }

    nonisolated struct ExtractedSource: Codable, Sendable {
        var url: String?
        var title: String?
    }
}
