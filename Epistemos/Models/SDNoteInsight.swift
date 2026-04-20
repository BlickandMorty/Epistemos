import Foundation
import SwiftData
import CryptoKit
import OSLog

@Model
final class SDNoteInsight {
    // Derived local cache of per-note ML signals. This model is rebuilt from note bodies
    // and currently lives in the app's local SwiftData store, so a uniqueness constraint
    // on pageId is intentional to preserve the 1:1 cache invariant.
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

    private static let log = Logger(subsystem: "com.epistemos", category: "SDNoteInsight")

    var entityKeywords: [String] {
        get { Self.decodeJSONArray(entityKeywordsJSON, as: [String].self) }
        set { entityKeywordsJSON = Self.encodeJSON(newValue, fallback: entityKeywordsJSON) }
    }

    var topicNouns: [String] {
        get { Self.decodeJSONArray(topicNounsJSON, as: [String].self) }
        set { topicNounsJSON = Self.encodeJSON(newValue, fallback: topicNounsJSON) }
    }

    var relatedNoteIds: [String] {
        get { Self.decodeJSONArray(relatedNoteIdsJSON, as: [String].self) }
        set { relatedNoteIdsJSON = Self.encodeJSON(newValue, fallback: relatedNoteIdsJSON) }
    }

    var relatednessScores: [Double] {
        get { Self.decodeJSONArray(relatednessScoresJSON, as: [Double].self) }
        set { relatednessScoresJSON = Self.encodeJSON(newValue, fallback: relatednessScoresJSON) }
    }

    var relatednessReasons: [[String]] {
        get { Self.decodeJSONArray(relatednessReasonsJSON, as: [[String]].self) }
        set { relatednessReasonsJSON = Self.encodeJSON(newValue, fallback: relatednessReasonsJSON) }
    }

    private static func decodeJSONArray<Element: Decodable>(
        _ json: String,
        as type: [Element].Type
    ) -> [Element] {
        do {
            return try JSONDecoder().decode(type, from: Data(json.utf8))
        } catch {
            log.error("SDNoteInsight: JSON decode failed for \(String(describing: type), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func encodeJSON<T: Encodable>(_ value: T, fallback: String) -> String {
        do {
            let data = try JSONEncoder().encode(value)
            guard let str = String(data: data, encoding: .utf8) else {
                log.error("SDNoteInsight: UTF-8 conversion failed after encoding \(String(describing: T.self), privacy: .public)")
                return fallback
            }
            return str
        } catch {
            log.error("SDNoteInsight: JSON encode failed for \(String(describing: T.self), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return fallback
        }
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
