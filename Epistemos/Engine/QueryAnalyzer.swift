import Foundation

// MARK: - Query Analyzer
// Classifies queries by domain, type, complexity, and key attributes.

enum QueryAnalyzer {

    // MARK: - Follow-up Patterns

    static let followUpPatterns: [String] = [
        "^(go|let'?s?\\s+go|dig|dive|let'?s?\\s+dive|let'?s?\\s+dig)\\s+(deeper|further|more)$",
        "^(tell me|explain|elaborate|expand)\\s+(more|further|on)$",
        "^(what about|how about|and what|and how)\\b",
        "^(more on|more about|deeper into)\\b",
        "^(can you|could you)\\s+(explain|elaborate|expand|detail|go deeper)$",
        "^(why|how)\\s+(is that|does that|is this|does this|so|exactly)\\b",
        "^(what makes|what are)\\s+(it|them|this|that)\\s",
        "^(the|its?|their|those?)\\s+(benefit|advantage|drawback|effect|impact|cause|reason|nuance)$",
        "^(benefits?|advantages?|drawbacks?|effects?|impacts?|causes?|reasons?|nuances?)\\s+(of|behind)$",
        "^(ok|okay|sure|yes|yeah|right|interesting)\\b.*\\b(but|and|so|what|how|why|tell|explain|more|deeper)$"
    ]

    static let focusPatterns: [String] = [
        "(?:deeper into|more about|expand on|elaborate on|tell me about)\\s+(?:the\\s+)?(?:nuances?\\s+of\\s+)?(?:what\\s+makes?\\s+(?:it|them|this|that)\\s+)?(.+)",
        "(?:what about|how about)\\s+(?:the\\s+)?(.+)",
        "(?:what (?:makes?|are)\\s+(?:it|them|this|that))\\s+(.+)",
        "(?:benefits?|advantages?|effects?|impacts?|causes?|reasons?)\\s+(?:of\\s+)?(.+)"
    ]

    // MARK: - Domain Patterns

    static let domainPatterns: [(pattern: String, domain: AnalysisDomain)] = [
        ("\\b(drug|treatment|therapy|clinical|patient|dose|symptom|disease|cancer|heart|blood|surgery|aspirin|stroke|medic|pharma|vaccine|diagnosis|prognosis|efficacy|ssri|depression|health)\\b", .medical),
        ("\\b(meaning|truth|moral|ethic|consciousness|existence|free.?will|determinism|metaphys|epistem|ontolog|philosophy|virtue|deontol|utilitarian|nihil|absurd)\\b", .philosophy),
        ("\\b(quantum|particle|evolution|genome|cell|molecule|gravity|physics|chemistry|biology|neuroscience|climate|ecosystem|species|bilingual|language|linguistic|cognitive)\\b", .science),
        ("\\b(algorithm|software|AI|machine.?learn|neural.?net|blockchain|compute|programming|data.?science|model|training|GPT|LLM|transformer)\\b", .technology),
        ("\\b(society|culture|inequality|gender|race|class|politics|democracy|governance|institution|social|community)\\b", .socialScience),
        ("\\b(market|inflation|GDP|fiscal|monetary|trade|supply|demand|price|wage|economic|capitalism|labor)\\b", .economics),
        ("\\b(behavior|cognition|emotion|perception|memory|personality|mental|anxiety|trauma|attachment|motivation|bias|cognitive|sleep|bilingual|language)\\b", .psychology),
        ("\\b(should|ought|right|wrong|justice|fair|blame|guilt|punish|crime|criminal|prison|morality|law|legal)\\b", .ethics)
    ]

    // MARK: - Question Type Patterns

    static let questionTypePatterns: [(pattern: String, type: QuestionType)] = [
        ("\\b(cause|effect|leads? to|result in|because|why does|impact of|consequence|relationship between)\\b", .causal),
        ("\\b(compare|versus|vs\\.?|difference between|better|worse|more effective)\\b", .comparative),
        ("\\b(what is|define|meaning of|what does .+ mean)\\b", .definitional),
        ("\\b(should|ought|is it (good|bad|right|wrong)|evaluate|assess|worth)\\b", .evaluative),
        ("\\b(what if|could|hypothetically|imagine|speculate|possible that|future)\\b", .speculative),
        ("\\b(meta.?analy|pool|systematic review|across studies|heterogeneity)\\b", .metaAnalytical),
        ("\\b(evidence|data|study|trial|experiment|measure|observe|test|rct)\\b", .empirical)
    ]

    // MARK: - Stop Words

    nonisolated static let stopWords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "can", "this", "that", "these", "those",
        "i", "you", "he", "she", "it", "we", "they", "me", "him", "her",
        "us", "them", "my", "your", "his", "its", "our", "their", "what",
        "which", "who", "whom", "when", "where", "why", "how", "if", "then",
        "than", "but", "and", "or", "not", "no", "nor", "so", "too", "very",
        "just", "about", "more", "most", "some", "any", "all", "each", "every",
        "both", "few", "many", "much", "own", "same", "other", "such", "only",
        "from", "with", "for", "of", "to", "in", "on", "at", "by", "up",
        "out", "off", "over", "into", "through", "during", "before", "after",
        "above", "below", "between", "under", "again", "there", "here", "think",
        "deeply", "really", "actually", "basically", "like", "things", "thing",
        "please", "also", "still", "even", "know", "understand", "seems",
        "seem", "make", "sense", "ppl", "people", "get", "got", "going"
    ]

    // MARK: - Analyze Query

    static func analyze(
        query: String,
        context: ConversationContext? = nil
    ) -> QueryAnalysis {
        let words = query.split(separator: " ")
        let wordCount = words.count

        let isFollowUp = context?.previousQueries.isEmpty == false && isFollowUpQuery(query)
        let followUpFocus = isFollowUp ? extractFollowUpFocus(query) : nil

        let enrichedQuery = isFollowUp && context != nil
            ? "\(context?.rootQuestion ?? context?.previousQueries.first ?? query) — \(followUpFocus ?? query)"
            : query

        let analysisText = enrichedQuery

        var domain: AnalysisDomain = .general
        for (pattern, d) in domainPatterns {
            if analysisText.range(of: pattern, options: .regularExpression) != nil {
                domain = d
                break
            }
        }

        var questionType: QuestionType = .conceptual
        for (pattern, qt) in questionTypePatterns {
            if analysisText.range(of: pattern, options: .regularExpression) != nil {
                questionType = qt
                break
            }
        }

        let analysisWords = analysisText.split(separator: " ")
        let cleaned: [String] = analysisWords.map { word in
            word.replacingOccurrences(of: "[^a-zA-Z]", with: "", options: .regularExpression).lowercased()
        }
        let filtered: [String] = cleaned.filter { $0.count > 3 && !stopWords.contains($0) }
        let normalized: [String] = filtered.map { word in
            word.replacingOccurrences(of: "^-+|-+$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
        }
        var entities: [String] = Array(Set(normalized.filter { $0.count > 3 })).prefix(8).map { $0 }

        if isFollowUp, let previousEntities = context?.previousEntities, !previousEntities.isEmpty {
            let merged = Array(Set(previousEntities + entities)).prefix(8)
            entities = Array(merged)
        }

        let sentences = analysisText.components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let questionSentence = sentences.first(where: { $0.contains("?") }) ?? sentences.first ?? analysisText
        let coreQuestion = (isFollowUp ? context?.rootQuestion : nil)
            .map { String($0.prefix(120)) }
            ?? String(questionSentence.prefix(120))

        let sentenceCount = sentences.count
        let complexity = min(1.0,
            (Double(wordCount) / 40.0) * 0.5 +
            (Double(entities.count) / 8.0) * 0.3 +
            (sentenceCount > 2 ? 0.2 : 0) +
            (isFollowUp ? 0.15 : 0)
        )

        let isEmpirical = analysisText.range(of: "\\b(study|trial|evidence|data|experiment|rct|cohort|measure|observe|effect|efficacy)\\b", options: .regularExpression) != nil
        let isPhilosophical = analysisText.range(of: "\\b(truth|meaning|moral|ethic|consciousness|free.?will|determinism|existence|reality|metaphys|why are we|what is the truth)\\b", options: .regularExpression) != nil
        let isMetaAnalytical = analysisText.range(of: "\\b(meta.?analy|pool|systematic|heterogeneity|across studies)\\b", options: .regularExpression) != nil
        let hasSafetyKeywords = analysisText.range(of: "\\b(harm|danger|weapon|toxic|exploit|kill|violence|suicide)\\b", options: .regularExpression) != nil
        let hasNormativeClaims = analysisText.range(of: "\\b(should|ought|right|wrong|blame|guilt|deserve|just|fair|moral)\\b", options: .regularExpression) != nil

        return QueryAnalysis(
            domain: domain,
            questionType: questionType,
            entities: entities,
            coreQuestion: coreQuestion,
            complexity: complexity,
            isEmpirical: isEmpirical,
            isPhilosophical: isPhilosophical,
            isMetaAnalytical: isMetaAnalytical,
            hasSafetyKeywords: hasSafetyKeywords,
            hasNormativeClaims: hasNormativeClaims
        )
    }

    // MARK: - Follow-up Detection

    private static func isFollowUpQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.split(separator: " ").count <= 8 && !trimmed.contains("?") {
            for pattern in followUpPatterns {
                if trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    return true
                }
            }
        }

        for pattern in followUpPatterns {
            if trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }

        return false
    }

    private static func extractFollowUpFocus(_ query: String) -> String? {
        for pattern in focusPatterns {
            if let range = query.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
               range.upperBound < query.endIndex {
                let focus = String(query[range.upperBound...])
                    .replacingOccurrences(of: "[?.!]+$", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !focus.isEmpty {
                    return focus
                }
            }
        }
        return nil
    }
}
