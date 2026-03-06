import Foundation
import SwiftData
import CryptoKit

@Model
final class SDNoteInsight {
    @Attribute(.unique) var pageId: String
    var contentHash: String
    var lastAnalyzedAt: Date

    // ML signals
    var sentiment: Double
    var formality: Double
    var vocabDiversity: Double
    var questionDensity: Double

    // Extracted content (JSON-encoded)
    var entityKeywordsJSON: String
    var topicNounsJSON: String

    // Cross-note relatedness (JSON-encoded, max 5)
    var relatedNoteIdsJSON: String
    var relatednessScoresJSON: String
    var relatednessReasonsJSON: String

    init(
        pageId: String,
        contentHash: String = "",
        lastAnalyzedAt: Date = .now,
        sentiment: Double = 0,
        formality: Double = 0,
        vocabDiversity: Double = 0,
        questionDensity: Double = 0,
        entityKeywordsJSON: String = "[]",
        topicNounsJSON: String = "[]",
        relatedNoteIdsJSON: String = "[]",
        relatednessScoresJSON: String = "[]",
        relatednessReasonsJSON: String = "[]"
    ) {
        self.pageId = pageId
        self.contentHash = contentHash
        self.lastAnalyzedAt = lastAnalyzedAt
        self.sentiment = sentiment
        self.formality = formality
        self.vocabDiversity = vocabDiversity
        self.questionDensity = questionDensity
        self.entityKeywordsJSON = entityKeywordsJSON
        self.topicNounsJSON = topicNounsJSON
        self.relatedNoteIdsJSON = relatedNoteIdsJSON
        self.relatednessScoresJSON = relatednessScoresJSON
        self.relatednessReasonsJSON = relatednessReasonsJSON
    }

    // MARK: - Type-Safe Accessors

    var entityKeywords: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(entityKeywordsJSON.utf8))) ?? [] }
        set { entityKeywordsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var topicNouns: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(topicNounsJSON.utf8))) ?? [] }
        set { topicNounsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var relatedNoteIds: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(relatedNoteIdsJSON.utf8))) ?? [] }
        set { relatedNoteIdsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var relatednessScores: [Double] {
        get { (try? JSONDecoder().decode([Double].self, from: Data(relatednessScoresJSON.utf8))) ?? [] }
        set { relatednessScoresJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var relatednessReasons: [[String]] {
        get { (try? JSONDecoder().decode([[String]].self, from: Data(relatednessReasonsJSON.utf8))) ?? [] }
        set { relatednessReasonsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    // MARK: - Content Hash

    static func hash(of body: String) -> String {
        let digest = SHA256.hash(data: Data(body.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - RelatednessReason

enum RelatednessReason: String, Codable, Sendable {
    case sharedEntities
    case semanticSimilarity
    case sharedKeywords
    case structuralProximity
}
