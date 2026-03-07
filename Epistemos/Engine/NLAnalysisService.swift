import NaturalLanguage
import os

// MARK: - NLAnalysisService
// On-device natural language analysis using Apple's NaturalLanguage framework.
// Extracts named entities (people, places, organizations), detects language,
// and computes sentiment — all on-device with zero network cost.
//
// Usage:
//   let entities = NLAnalysisService.extractEntities(from: text)
//   let language = NLAnalysisService.detectLanguage(text)
//   let sentiment = NLAnalysisService.sentiment(of: text)

@MainActor
enum NLAnalysisService {

    // MARK: - Entity Extraction

    struct Entity: Hashable, Sendable {
        enum Kind: String, Sendable {
            case person
            case place
            case organization
        }
        let text: String
        let kind: Kind
    }

    /// Extracts person names, place names, and organization names from text.
    /// Returns deduplicated entities. Runs on-device via Apple NLP models.
    nonisolated static func extractEntities(from text: String) -> [Entity] {
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var seen = Set<String>()
        var entities: [Entity] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, range in
            guard let tag else { return true }

            let kind: Entity.Kind?
            switch tag {
            case .personalName:      kind = .person
            case .placeName:         kind = .place
            case .organizationName:  kind = .organization
            default:                 kind = nil
            }

            if let kind {
                let entityText = String(text[range])
                let key = "\(kind.rawValue):\(entityText.lowercased())"
                if !seen.contains(key) {
                    seen.insert(key)
                    entities.append(Entity(text: entityText, kind: kind))
                }
            }
            return true
        }

        return entities
    }

    // MARK: - Language Detection

    /// Detects the dominant language of the text. Returns BCP-47 code (e.g. "en", "es", "ja").
    nonisolated static func detectLanguage(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    // MARK: - Sentiment Analysis

    /// Returns a sentiment score for the text: -1.0 (negative) to +1.0 (positive).
    /// Returns 0.0 for neutral or undetectable sentiment.
    nonisolated static func sentiment(of text: String) -> Double {
        guard !text.isEmpty else { return 0 }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var totalScore = 0.0
        var count = 0

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .paragraph,
            scheme: .sentimentScore,
            options: [.omitWhitespace]
        ) { tag, _ in
            if let tag, let score = Double(tag.rawValue) {
                totalScore += score
                count += 1
            }
            return true
        }

        return count > 0 ? totalScore / Double(count) : 0
    }

    // MARK: - Word Count (native tokenization)

    /// Counts words using NL tokenizer — more accurate than NSSpellChecker for non-English text.
    nonisolated static func wordCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }
}
