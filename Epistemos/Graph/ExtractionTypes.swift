import Foundation

// MARK: - ExtractionResult
// Codable struct for parsing LLM JSON responses from note entity extraction.
// Each field maps to a category of knowledge graph entity the AI can identify.

nonisolated struct ExtractionResult: Codable, Sendable {
    var thinkers: [ExtractedThinker]
    var concepts: [ExtractedConcept]
    var quotes: [ExtractedQuote]
    var sources: [ExtractedSource]

    nonisolated struct ExtractedThinker: Codable, Sendable {
        var name: String
        var role: String?
        var confidence: Double?
    }

    nonisolated struct ExtractedConcept: Codable, Sendable {
        var name: String
        var description: String?
    }

    nonisolated struct ExtractedQuote: Codable, Sendable {
        var text: String
        var attribution: String?
        var context: String?
    }

    nonisolated struct ExtractedSource: Codable, Sendable {
        var url: String?
        var title: String?
        var type: String?
    }
}

// MARK: - InsightExtractionResult
// Codable struct for parsing LLM JSON responses from chat insight extraction.

nonisolated struct InsightExtractionResult: Codable, Sendable {
    var insights: [ExtractedInsight]
    var sourcesShared: [ExtractedSource]
    var thinkersDiscussed: [ExtractedThinker]

    nonisolated struct ExtractedInsight: Codable, Sendable {
        var summary: String
        var evidenceGrade: String?
        var relatedEntities: [String]?
    }

    nonisolated struct ExtractedThinker: Codable, Sendable {
        var name: String
        var context: String?
    }

    nonisolated struct ExtractedSource: Codable, Sendable {
        var url: String?
        var title: String?
    }
}
