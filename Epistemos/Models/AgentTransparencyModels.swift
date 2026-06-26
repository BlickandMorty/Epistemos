import Foundation
import NaturalLanguage

struct CapturedModelInput: Sendable, Equatable {
    let capturedAt: Date
    let runtimeLabel: String
    let systemPrompt: String?
    let userPrompt: String
    let messageHistory: String?
    let toolDefinitionsJSON: String?

    init(
        capturedAt: Date = Date(),
        runtimeLabel: String,
        systemPrompt: String?,
        userPrompt: String,
        messageHistory: String?,
        toolDefinitionsJSON: String?
    ) {
        self.capturedAt = capturedAt
        self.runtimeLabel = runtimeLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedSystemPrompt = systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.systemPrompt = trimmedSystemPrompt?.isEmpty == true ? nil : trimmedSystemPrompt

        self.userPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedHistory = messageHistory?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.messageHistory = trimmedHistory?.isEmpty == true ? nil : trimmedHistory

        let trimmedToolDefinitions = toolDefinitionsJSON?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toolDefinitionsJSON = trimmedToolDefinitions?.isEmpty == true ? nil : trimmedToolDefinitions
    }
}

struct ContentPersonalitySignals: Sendable, Equatable {
    let sentiment: Double
    let questionDensity: Double
    let formalityScore: Double
    let vocabDiversity: Double
    let entityKeywords: [String]
    let dominantTopics: [String]

    nonisolated static let empty = ContentPersonalitySignals(
        sentiment: 0,
        questionDensity: 0,
        formalityScore: 0,
        vocabDiversity: 0,
        entityKeywords: [],
        dominantTopics: []
    )

    nonisolated static func analyze(_ text: String) -> ContentPersonalitySignals {
        let trimmed = String(text.prefix(6_000))
        guard trimmed.count >= 50 else { return .empty }

        let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        sentimentTagger.string = trimmed
        let sentimentTag = sentimentTagger.tag(
            at: trimmed.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        ).0
        let sentiment = Double(sentimentTag?.rawValue ?? "0") ?? 0

        let posTagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        posTagger.string = trimmed

        var nounCount = 0
        var adjCount = 0
        var totalTokens = 0
        var uniqueWords: Set<String> = []
        var nounFreq: [String: Int] = [:]
        var entities: [String] = []
        let questionMarks = trimmed.reduce(into: 0) { count, character in
            if character == "?" { count += 1 }
        }

        posTagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, range in
            totalTokens += 1
            let word = String(trimmed[range]).lowercased()
            uniqueWords.insert(word)

            switch tag {
            case .noun:
                nounCount += 1
                if word.count >= 4 { nounFreq[word, default: 0] += 1 }
            case .adjective:
                adjCount += 1
            default:
                break
            }
            return true
        }

        posTagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .nameType
        ) { tag, range in
            if let tag, tag != .otherWord {
                let entity = String(trimmed[range])
                if entity.count >= 2, !entities.contains(entity) {
                    entities.append(entity)
                }
            }
            return entities.count < 6
        }

        let total = max(1, totalTokens)
        let questionDensity = min(1, Double(questionMarks) / max(1, Double(total) / 20))
        let formalityScore = min(1, (Double(nounCount + adjCount) / Double(total)) * 1.8)
        let vocabDiversity = Double(uniqueWords.count) / Double(total)
        let topNouns = nounFreq
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(5)
            .map(\.key)

        return ContentPersonalitySignals(
            sentiment: sentiment,
            questionDensity: questionDensity,
            formalityScore: formalityScore,
            vocabDiversity: vocabDiversity,
            entityKeywords: entities,
            dominantTopics: topNouns
        )
    }
}

enum DialogueArchetype: String, Codable, Sendable, Equatable {
    case archivist
    case examiner
    case dreamer
    case gardener
    case guide
    case sentinel

    var title: String {
        switch self {
        case .archivist: "Archivist"
        case .examiner: "Examiner"
        case .dreamer: "Dreamer"
        case .gardener: "Gardener"
        case .guide: "Guide"
        case .sentinel: "Sentinel"
        }
    }

    var summaryTemplate: String {
        switch self {
        case .archivist: "curates evidence, citations, and grounded context"
        case .examiner: "surfaces open questions, tensions, and stress points"
        case .dreamer: "collects speculative paths and unfinished possibilities"
        case .gardener: "tends clusters of related themes and recurring threads"
        case .guide: "orients you across branches and suggests where to look next"
        case .sentinel: "contains connected context for retrieval and answer synthesis"
        }
    }

    var openingLine: String {
        switch self {
        case .archivist: "Ask what evidence this node holds."
        case .examiner: "Ask what question this node is pressure-testing."
        case .dreamer: "Ask what possibility this node is reaching toward."
        case .gardener: "Ask how this node connects and grows with nearby threads."
        case .guide: "Ask where this node can lead you next."
        case .sentinel: "Ask about this node."
        }
    }
}

enum DialogueMood: String, Codable, Sendable, Equatable {
    case thriving
    case curious
    case steady
    case lonely
    case fragile

    var displayName: String {
        switch self {
        case .thriving: "Thriving"
        case .curious: "Curious"
        case .steady: "Steady"
        case .lonely: "Lonely"
        case .fragile: "Fragile"
        }
    }
}

struct DialoguePortraitAsset: Sendable, Equatable {
    let symbol: String
    let crestLabel: String
}

struct DialogueCareState: Sendable, Equatable {
    var health: Double
    var attention: Double
    var mood: DialogueMood
    var interactionCount: Int
    var lastInteractionAt: Date?

    mutating func applyDecay(now: Date) {
        guard let lastInteractionAt else { return }
        let elapsedHours = max(0, now.timeIntervalSince(lastInteractionAt) / 3_600)
        if elapsedHours == 0 { return }
        attention = Self.clamp(attention - elapsedHours * 0.08)
        health = Self.clamp(health - elapsedHours * 0.015)
        if health < 0.32 {
            mood = .fragile
        } else if attention < 0.28 {
            mood = .lonely
        }
    }

    mutating func recordInteraction(userText: String, now: Date) {
        applyDecay(now: now)
        let questionBoost = userText.contains("?") ? 0.08 : 0.03
        let lengthBoost = min(0.08, Double(userText.count) / 600)
        health = Self.clamp(health + 0.03 + lengthBoost * 0.5)
        attention = Self.clamp(attention + 0.16 + questionBoost + lengthBoost)
        interactionCount += 1
        lastInteractionAt = now
        if health > 0.82, attention > 0.72 {
            mood = .thriving
        } else if questionBoost > 0.05 {
            mood = .curious
        } else if health < 0.32 {
            mood = .fragile
        } else {
            mood = .steady
        }
    }

    mutating func markOpened(now: Date) {
        applyDecay(now: now)
        attention = Self.clamp(max(attention, 0.52))
        lastInteractionAt = now
        if health < 0.32 {
            mood = .fragile
        } else if attention > 0.72 {
            mood = .curious
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

enum DialogueDepthTier: String, Codable, Sendable, Equatable {
    case root
    case branch
    case focus
    case detail
    case trace

    var displayName: String {
        switch self {
        case .root: "Root"
        case .branch: "Branch"
        case .focus: "Focus"
        case .detail: "Detail"
        case .trace: "Trace"
        }
    }
}

struct DialogueNodeInsight: Sendable, Equatable {
    let structureDepth: Int
    let contentWords: Int
    let childCount: Int
    let tier: DialogueDepthTier
    let prominence: Double

    static func fallback(nodeType: GraphNodeType, noteBody: String, linkedNodeCount: Int) -> DialogueNodeInsight {
        let contentWords = noteBody
            .split { !$0.isLetter && !$0.isNumber }
            .count
        let structureDepth: Int = switch nodeType {
        case .folder: 0
        case .note, .chat: 2
        case .idea, .source, .quote, .person, .project, .topic, .decision, .event, .resource: 3
        case .tag, .block: 4
        case .run, .rawThought, .toolTrace: 3
        case .proseNote, .document: 2
        case .code, .output: 3
        }
        let prominence = min(1, Double(contentWords) / 1_800 + Double(linkedNodeCount) * 0.04)
        return DialogueNodeInsight(
            structureDepth: structureDepth,
            contentWords: contentWords,
            childCount: linkedNodeCount,
            tier: Self.tier(for: structureDepth),
            prominence: prominence
        )
    }

    static func tier(for structureDepth: Int) -> DialogueDepthTier {
        switch structureDepth {
        case ..<1: .root
        case 1: .branch
        case 2...3: .focus
        case 4...5: .detail
        default: .trace
        }
    }

    var contentLabel: String {
        if contentWords > 0 { return "\(contentWords)w" }
        if childCount > 0 { return "\(childCount) links" }
        return "thin"
    }

    var hierarchyLabel: String {
        "Layer \(structureDepth)"
    }
}

struct DialogueNodeProfile: Sendable, Equatable {
    let nodeId: String
    let label: String
    let nodeType: GraphNodeType
    let archetype: DialogueArchetype
    let summary: String
    let openingLine: String
    let focusKeywords: [String]
    let portrait: DialoguePortraitAsset
    let insight: DialogueNodeInsight
    var care: DialogueCareState

    static let placeholder = DialogueNodeProfile(
        nodeId: "",
        label: "",
        nodeType: .note,
        archetype: .sentinel,
        summary: "",
        openingLine: "",
        focusKeywords: [],
        portrait: DialoguePortraitAsset(symbol: "sparkles.rectangle.stack.fill", crestLabel: "Dormant"),
        insight: DialogueNodeInsight(structureDepth: 0, contentWords: 0, childCount: 0, tier: .root, prominence: 0),
        care: DialogueCareState(health: 0.5, attention: 0.5, mood: .steady, interactionCount: 0, lastInteractionAt: nil)
    )

    static func derive(
        nodeId: String,
        label: String,
        nodeType: GraphNodeType,
        noteBody: String,
        linkedNodeLabels: [String],
        insight: DialogueNodeInsight? = nil,
        cachedSignals: ContentPersonalitySignals? = nil
    ) -> DialogueNodeProfile {
        let normalizedBody = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = normalizedTokens(in: normalizedBody)
        let ml = cachedSignals ?? ContentPersonalitySignals.analyze(normalizedBody)
        let freqKeywords = focusKeywords(in: normalizedBody, linkedNodeLabels: linkedNodeLabels)
        var keywords: [String] = []
        for keyword in ml.entityKeywords + ml.dominantTopics + freqKeywords {
            let lower = keyword.lowercased()
            if !keywords.contains(where: { $0.lowercased() == lower }) {
                keywords.append(keyword)
            }
            if keywords.count >= 6 { break }
        }

        let resolvedInsight = insight ?? DialogueNodeInsight.fallback(
            nodeType: nodeType,
            noteBody: normalizedBody,
            linkedNodeCount: linkedNodeLabels.count
        )
        let archetype = deriveArchetype(
            nodeType: nodeType,
            body: normalizedBody,
            tokens: tokens,
            linkedNodeLabels: linkedNodeLabels,
            ml: ml
        )
        let richness = contentRichness(
            body: normalizedBody,
            linkedNodeLabels: linkedNodeLabels,
            keywords: keywords
        )
        let mood = deriveMood(
            body: normalizedBody,
            tokens: tokens,
            richness: richness,
            linkedNodeLabels: linkedNodeLabels,
            ml: ml
        )
        let summary = "\(label) \(archetype.summaryTemplate). \(resolvedInsight.hierarchyLabel). \(resolvedInsight.contentLabel)."
        let portrait = portraitAsset(for: archetype, mood: mood)
        let care = DialogueCareState(
            health: min(1, max(0, 0.20 + richness * 0.34 + resolvedInsight.prominence * 0.30 + depthResilience(for: resolvedInsight) * 0.14)),
            attention: min(1, max(0, 0.34 + min(0.18, Double(linkedNodeLabels.count) * 0.025) + resolvedInsight.prominence * 0.18 + depthCuriosity(for: resolvedInsight))),
            mood: mood,
            interactionCount: 0,
            lastInteractionAt: nil
        )

        return DialogueNodeProfile(
            nodeId: nodeId,
            label: label,
            nodeType: nodeType,
            archetype: archetype,
            summary: summary,
            openingLine: archetype.openingLine,
            focusKeywords: keywords,
            portrait: portrait,
            insight: resolvedInsight,
            care: care
        )
    }

    func refreshed(
        noteBody: String,
        linkedNodeLabels: [String],
        now: Date,
        insight: DialogueNodeInsight? = nil
    ) -> DialogueNodeProfile {
        let derived = Self.derive(
            nodeId: nodeId,
            label: label,
            nodeType: nodeType,
            noteBody: noteBody,
            linkedNodeLabels: linkedNodeLabels,
            insight: insight
        )
        var merged = derived
        merged.care = care
        merged.care.applyDecay(now: now)
        merged.care.health = min(1, max(0, merged.care.health * 0.75 + derived.care.health * 0.25))
        merged.care.attention = min(1, max(0, merged.care.attention * 0.65 + derived.care.attention * 0.35))
        merged.care.mood = DialogueNodeProfile.resolveMood(for: merged.care)
        return merged
    }

    mutating func recordInteraction(userText: String) {
        care.recordInteraction(userText: userText, now: .now)
    }

    private static func resolveMood(for care: DialogueCareState) -> DialogueMood {
        if care.health > 0.82, care.attention > 0.72 { return .thriving }
        if care.attention > 0.72 { return .curious }
        if care.health < 0.32 { return .fragile }
        if care.attention < 0.28 { return .lonely }
        return .steady
    }

    private static func deriveArchetype(
        nodeType: GraphNodeType,
        body: String,
        tokens: [String],
        linkedNodeLabels: [String],
        ml: ContentPersonalitySignals
    ) -> DialogueArchetype {
        let lowerBody = body.lowercased()
        let citationSignals = citationSignalCount(in: lowerBody)
        let questionSignals = questionSignalCount(in: lowerBody)
        let ideaSignals = ideaSignalCount(in: lowerBody)
        let linkedCount = linkedNodeLabels.count
        let mlQuestionSignals = ml.questionDensity >= 0.18 ? 2 : (ml.questionDensity >= 0.08 ? 1 : 0)
        let mlCitationSignals = (ml.formalityScore >= 0.42 ? 1 : 0) + (ml.entityKeywords.isEmpty ? 0 : 1)
        let mlIdeaSignals = ml.vocabDiversity >= 0.56 ? 1 : 0

        switch nodeType {
        case .source, .quote:
            return .archivist
        case .folder:
            return .guide
        case .tag:
            return linkedCount >= 4 ? .gardener : .guide
        case .chat:
            if questionSignals + mlQuestionSignals >= 2 { return .examiner }
            return .guide
        case .note, .idea, .block, .person, .project, .topic, .decision, .event, .resource:
            break
        case .run, .rawThought, .toolTrace:
            break
        case .proseNote, .document, .code, .output:
            break
        }

        if citationSignals + mlCitationSignals >= 2 { return .archivist }
        if questionSignals + mlQuestionSignals >= 2 { return .examiner }
        if ideaSignals + mlIdeaSignals >= 2 || (nodeType == .idea && tokens.count >= 8) { return .dreamer }
        if linkedCount >= 6 { return .gardener }
        if linkedCount >= 3 { return .guide }
        return .sentinel
    }

    private static func deriveMood(
        body: String,
        tokens: [String],
        richness: Double,
        linkedNodeLabels: [String],
        ml: ContentPersonalitySignals
    ) -> DialogueMood {
        let lowerBody = body.lowercased()
        let questionSignals = questionSignalCount(in: lowerBody)
        let citationSignals = citationSignalCount(in: lowerBody)

        if questionSignals >= 2 || ml.questionDensity >= 0.18 { return .curious }
        if ml.sentiment < -0.45, richness < 0.30 { return .fragile }
        if richness < 0.12, linkedNodeLabels.isEmpty, tokens.count < 12 { return .lonely }
        if richness >= 0.58 || (citationSignals >= 2 && linkedNodeLabels.count >= 2) { return .thriving }
        if richness < 0.20, linkedNodeLabels.count <= 1 { return .lonely }
        return .steady
    }

    private static func contentRichness(
        body: String,
        linkedNodeLabels: [String],
        keywords: [String]
    ) -> Double {
        let bodyScore = min(0.72, Double(body.count) / 2_200)
        let linkScore = min(0.18, Double(linkedNodeLabels.count) * 0.03)
        let keywordScore = min(0.10, Double(keywords.count) * 0.03)
        return min(1, bodyScore + linkScore + keywordScore)
    }

    private static func depthResilience(for insight: DialogueNodeInsight) -> Double {
        switch insight.tier {
        case .root: 0.18
        case .branch: 0.14
        case .focus: 0.10
        case .detail: 0.07
        case .trace: 0.04
        }
    }

    private static func depthCuriosity(for insight: DialogueNodeInsight) -> Double {
        switch insight.tier {
        case .root: 0.02
        case .branch: 0.05
        case .focus: 0.08
        case .detail: 0.10
        case .trace: 0.12
        }
    }

    private static func portraitAsset(for archetype: DialogueArchetype, mood: DialogueMood) -> DialoguePortraitAsset {
        let base: (symbol: String, crestLabel: String) = switch archetype {
        case .archivist:
            ("books.vertical.fill", "Archivist")
        case .examiner:
            ("questionmark.bubble.fill", "Examiner")
        case .dreamer:
            ("sparkles", "Dreamer")
        case .gardener:
            ("leaf.fill", "Gardener")
        case .guide:
            ("signpost.right.fill", "Guide")
        case .sentinel:
            ("shield.fill", "Sentinel")
        }
        let crestLabel = mood == .steady ? base.crestLabel : "\(mood.displayName) \(base.crestLabel)"
        return DialoguePortraitAsset(symbol: base.symbol, crestLabel: crestLabel)
    }

    private static func focusKeywords(in body: String, linkedNodeLabels: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for token in normalizedTokens(in: body) where token.count >= 4 && !stopWords.contains(token) {
            counts[token, default: 0] += 1
        }

        let rankedBodyWords = counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .map(\.key)

        let linkedWords = linkedNodeLabels
            .flatMap { normalizedTokens(in: $0) }
            .filter { $0.count >= 4 && !stopWords.contains($0) }

        var ordered: [String] = []
        for candidate in rankedBodyWords + linkedWords {
            if !ordered.contains(candidate) {
                ordered.append(candidate)
            }
            if ordered.count == 4 { break }
        }
        return ordered
    }

    private static func normalizedTokens(in text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func questionSignalCount(in lowerBody: String) -> Int {
        let cues = ["why", "how", "what", "should", "could", "?", "unclear", "problem"]
        return cues.reduce(0) { $0 + lowerBody.components(separatedBy: $1).count - 1 }
    }

    private static func citationSignalCount(in lowerBody: String) -> Int {
        let cues = ["doi", "journal", "study", "studies", "citation", "citations", "reference", "references", "http", "www.", "202"]
        return cues.reduce(0) { $0 + lowerBody.components(separatedBy: $1).count - 1 }
    }

    private static func ideaSignalCount(in lowerBody: String) -> Int {
        let cues = ["idea", "maybe", "possibility", "explore", "hypothesis", "brainstorm", "imagine"]
        return cues.reduce(0) { $0 + lowerBody.components(separatedBy: $1).count - 1 }
    }

    private static let stopWords: Set<String> = [
        "about", "after", "again", "also", "because", "between", "could", "every", "first",
        "from", "have", "into", "just", "like", "more", "most", "other", "over", "some",
        "than", "that", "their", "them", "then", "there", "these", "they", "this", "those",
        "under", "using", "very", "what", "when", "where", "which", "while", "with", "would",
        "your", "note", "notes", "page", "pages",
    ]
}
