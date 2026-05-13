import Foundation

// MARK: - ExtractionResult
// Codable struct for parsing LLM JSON responses from note entity extraction.
//
// RCA-P2-012 closure 2026-05-13: only `crossNoteLinks` is currently
// persisted by `EntityExtractor.processExtractionResult`. The
// `sources` + `tags` arrays remain in the schema as optional
// back-compat fields so legacy serialized payloads still parse, but
// the extraction prompt no longer asks for them — promoting either
// to a live graph projection is future work. See audit register
// `RCA-P2-012` for the resumption plan.

nonisolated struct ExtractionResult: Codable, Sendable {
    /// Roadmap-only: serialized for back-compat with older LLM
    /// payloads that returned source mentions; not currently
    /// persisted by `EntityExtractor`.
    var sources: [ExtractedSource]?
    /// Roadmap-only: serialized for back-compat with older LLM
    /// payloads that returned tags; not currently persisted by
    /// `EntityExtractor`. Optional so newer prompts that omit the
    /// field decode without error.
    var tags: [ExtractedTag]?
    var crossNoteLinks: [CrossNoteLink]?

    nonisolated struct ExtractedSource: Codable, Sendable {
        var name: String
        var url: String?
        var title: String?
        var type: String?
        var relationship: String?
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
    var sourcesShared: [ExtractedSource]?

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
