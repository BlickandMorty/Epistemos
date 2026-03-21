import Foundation
import NaturalLanguage
import Observation
import SwiftData

enum DialogueArchetype: String, Codable, Sendable, Equatable {
    case archivist
    case examiner
    case dreamer
    case gardener
    case guide
    case sentinel

    var title: String {
        "Node"
    }

    var summaryTemplate: String {
        "contains connected context for retrieval and answer synthesis"
    }

    var openingLine: String {
        "Ask about this node."
    }
}

enum DialogueMood: String, Codable, Sendable, Equatable {
    case thriving
    case curious
    case steady
    case lonely
    case fragile

    var displayName: String {
        "Ready"
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
        let elapsedHours = max(0, now.timeIntervalSince(lastInteractionAt) / 3600)
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
        let lengthBoost = min(0.08, Double(userText.count) / 600.0)
        health = Self.clamp(health + 0.03 + lengthBoost * 0.5)
        attention = Self.clamp(attention + 0.16 + questionBoost + lengthBoost)
        interactionCount += 1
        lastInteractionAt = now
        if health > 0.82 && attention > 0.72 {
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
        min(1.0, max(0.0, value))
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
        case .idea, .source, .quote: 3
        case .tag, .block: 4
        }
        let prominence = min(1.0, Double(contentWords) / 1800.0 + Double(linkedNodeCount) * 0.04)
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

// MARK: - On-Device Content Analysis (NaturalLanguage framework)

struct ContentPersonalitySignals: Sendable, Equatable {
    let sentiment: Double          // -1.0 (negative) to +1.0 (positive)
    let questionDensity: Double    // 0.0 to 1.0
    let formalityScore: Double     // 0.0 (casual) to 1.0 (formal/academic)
    let vocabDiversity: Double     // 0.0 to 1.0 (unique words / total words)
    let entityKeywords: [String]   // NER-extracted named entities
    let dominantTopics: [String]   // top nouns by frequency

    nonisolated static let empty = ContentPersonalitySignals(
        sentiment: 0, questionDensity: 0, formalityScore: 0,
        vocabDiversity: 0, entityKeywords: [], dominantTopics: []
    )

    nonisolated static func analyze(_ text: String) -> ContentPersonalitySignals {
        let trimmed = String(text.prefix(6000))
        guard trimmed.count >= 50 else { return .empty }

        // Sentiment via NLTagger
        let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        sentimentTagger.string = trimmed
        let sentimentTag = sentimentTagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore).0
        let sentiment = Double(sentimentTag?.rawValue ?? "0") ?? 0.0

        // POS tagging for formality + topic extraction
        let posTagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        posTagger.string = trimmed

        var nounCount = 0
        var verbCount = 0
        var adjCount = 0
        var totalTokens = 0
        var uniqueWords: Set<String> = []
        var nounFreq: [String: Int] = [:]
        var entities: [String] = []
        var questionMarks = 0

        posTagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            totalTokens += 1
            let word = String(trimmed[range]).lowercased()
            uniqueWords.insert(word)

            if word == "?" { questionMarks += 1 }

            switch tag {
            case .noun:
                nounCount += 1
                if word.count >= 4 { nounFreq[word, default: 0] += 1 }
            case .verb: verbCount += 1
            case .adjective: adjCount += 1
            default: break
            }
            return true
        }

        // Named entity extraction
        posTagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag, tag != .otherWord {
                let entity = String(trimmed[range])
                if entity.count >= 2 && !entities.contains(entity) {
                    entities.append(entity)
                }
            }
            return entities.count < 6
        }

        let total = max(1, totalTokens)
        let questionDensity = min(1.0, Double(questionMarks) / max(1, Double(total) / 20.0))
        let formalityScore = min(1.0, (Double(nounCount + adjCount) / Double(total)) * 1.8)
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
        insight: DialogueNodeInsight(structureDepth: 0, contentWords: 0, childCount: 0, tier: .root, prominence: 0.0),
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

        // Use cached ML signals from NoteInsightService when available, otherwise analyze live
        let ml = cachedSignals ?? ContentPersonalitySignals.analyze(normalizedBody)

        // Merge ML entities with frequency-based keywords
        let freqKeywords = focusKeywords(in: normalizedBody, linkedNodeLabels: linkedNodeLabels)
        var keywords: [String] = []
        for kw in ml.entityKeywords + ml.dominantTopics + freqKeywords {
            let lower = kw.lowercased()
            if !keywords.contains(where: { $0.lowercased() == lower }) {
                keywords.append(kw)
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
            health: min(1.0, max(0.0, 0.20 + richness * 0.34 + resolvedInsight.prominence * 0.30 + depthResilience(for: resolvedInsight) * 0.14)),
            attention: min(1.0, max(0.0, 0.34 + min(0.18, Double(linkedNodeLabels.count) * 0.025) + resolvedInsight.prominence * 0.18 + depthCuriosity(for: resolvedInsight))),
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
        merged.care.health = min(1.0, max(0.0, merged.care.health * 0.75 + derived.care.health * 0.25))
        merged.care.attention = min(1.0, max(0.0, merged.care.attention * 0.65 + derived.care.attention * 0.35))
        merged.care.mood = DialogueNodeProfile.resolveMood(for: merged.care)
        return merged
    }

    mutating func recordInteraction(userText: String) {
        care.recordInteraction(userText: userText, now: .now)
    }

    private static func resolveMood(for care: DialogueCareState) -> DialogueMood {
        if care.health > 0.82 && care.attention > 0.72 { return .thriving }
        if care.attention > 0.72 { return .curious }
        if care.health < 0.32 { return .fragile }
        if care.attention < 0.28 { return .lonely }
        return .steady
    }

    private static func deriveArchetype(
        nodeType _: GraphNodeType,
        body _: String,
        tokens _: [String],
        linkedNodeLabels _: [String],
        ml _: ContentPersonalitySignals = .empty
    ) -> DialogueArchetype {
        return .sentinel
    }

    private static func deriveMood(
        body _: String,
        tokens _: [String],
        richness _: Double,
        linkedNodeLabels _: [String],
        ml _: ContentPersonalitySignals = .empty
    ) -> DialogueMood {
        return .steady
    }

    private static func contentRichness(
        body: String,
        linkedNodeLabels: [String],
        keywords: [String]
    ) -> Double {
        let bodyScore = min(0.72, Double(body.count) / 2200.0)
        let linkScore = min(0.18, Double(linkedNodeLabels.count) * 0.03)
        let keywordScore = min(0.10, Double(keywords.count) * 0.03)
        return min(1.0, bodyScore + linkScore + keywordScore)
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

    private static func portraitAsset(for _: DialogueArchetype, mood _: DialogueMood) -> DialoguePortraitAsset {
        return DialoguePortraitAsset(symbol: "square.stack.3d.up.fill", crestLabel: "Node")
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
        "your", "note", "notes", "page", "pages"
    ]
}

/// Manages AI chat for the FFT-style graph dialogue box.
/// One shared instance — only one dialogue active at a time.
/// Architecture mirrors NoteChatState's streaming/buffering pattern
/// but targets a multi-message conversation instead of inline editor insertion.
@MainActor @Observable
final class DialogueChatState {

    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        var text: String

        enum Role { case user, assistant }
    }

    // MARK: - Public State

    var messages: [Message] = []
    var inputText = ""
    var isStreaming = false
    var activeNodeId: String?
    var activeNodeLabel = ""
    var revealedCharCount = 0
    var activeProfile = DialogueNodeProfile.placeholder

    // MARK: - Callbacks

    /// Drives mouth animation via FFI when streaming starts/stops.
    var onStreamingChanged: ((Bool) -> Void)?

    // MARK: - Private

    @ObservationIgnored private var streamingTask: Task<Void, Never>?
    @ObservationIgnored
    private lazy var streamBuffer = DisplayPacedTextBuffer { [weak self] delta in
        guard let self, !self.messages.isEmpty else { return }
        self.messages[self.messages.count - 1].text += delta
        self.startTypewriter()
    }
    @ObservationIgnored private var typewriterTask: Task<Void, Never>?
    @ObservationIgnored private var nodeProfiles: [String: DialogueNodeProfile] = [:]

    // MARK: - Lifecycle

    func open(
        nodeId: String,
        label: String,
        nodeType: GraphNodeType,
        noteBody: String,
        linkedNodeLabels: [String],
        insight: DialogueNodeInsight? = nil
    ) {
        if activeNodeId != nodeId {
            streamingTask?.cancel()
            streamingTask = nil
            streamBuffer.reset()
            typewriterTask?.cancel()
            isStreaming = false
            onStreamingChanged?(false)
        }
        // Look up cached ML signals from NoteInsightService (avoids live NLTagger on open)
        let cached = Self.cachedSignals(for: nodeId)

        let now = Date.now
        if activeNodeId == nodeId {
            var profile = nodeProfiles[nodeId] ?? DialogueNodeProfile.derive(
                nodeId: nodeId,
                label: label,
                nodeType: nodeType,
                noteBody: noteBody,
                linkedNodeLabels: linkedNodeLabels,
                insight: insight,
                cachedSignals: cached
            )
            profile = profile.refreshed(noteBody: noteBody, linkedNodeLabels: linkedNodeLabels, now: now, insight: insight)
            profile.care.markOpened(now: now)
            nodeProfiles[nodeId] = profile
            activeProfile = profile
            return
        }

        var profile = nodeProfiles[nodeId] ?? DialogueNodeProfile.derive(
            nodeId: nodeId,
            label: label,
            nodeType: nodeType,
            noteBody: noteBody,
            linkedNodeLabels: linkedNodeLabels,
            insight: insight,
            cachedSignals: cached
        )
        profile = profile.refreshed(noteBody: noteBody, linkedNodeLabels: linkedNodeLabels, now: now, insight: insight)
        profile.care.markOpened(now: now)
        nodeProfiles[nodeId] = profile

        activeNodeId = nodeId
        activeNodeLabel = label
        activeProfile = profile
        messages = []
        inputText = ""
        isStreaming = false
        revealedCharCount = 0
        revealedCharCount = 0
    }

    /// Build ContentPersonalitySignals from a cached SDNoteInsight, avoiding live NLTagger work.
    private static func cachedSignals(for pageId: String) -> ContentPersonalitySignals? {
        guard let bootstrap = AppBootstrap.shared else { return nil }
        let context = bootstrap.modelContainer.mainContext
        guard let insight = bootstrap.noteInsightService.fetchInsight(pageId: pageId, context: context) else { return nil }
        return ContentPersonalitySignals(
            sentiment: insight.sentiment,
            questionDensity: insight.questionDensity,
            formalityScore: insight.formality,
            vocabDiversity: insight.vocabDiversity,
            entityKeywords: insight.entityKeywords,
            dominantTopics: insight.topicNouns
        )
    }

    func close() {
        streamingTask?.cancel()
        streamingTask = nil
        streamBuffer.reset()
        typewriterTask?.cancel()
        activeNodeId = nil
        activeNodeLabel = ""
        activeProfile = .placeholder
        isStreaming = false
        onStreamingChanged = nil
    }

    // MARK: - Query

    func submitQuery(
        noteBody: String,
        linkedNodeLabels: [String],
        neighborContext: [(label: String, relationship: String, body: String)] = [],
        nodeType: GraphNodeType,
        insight: DialogueNodeInsight? = nil,
        triageService: TriageService
    ) {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        guard !isStreaming else { return }
        inputText = ""
        streamingTask?.cancel()
        streamBuffer.reset()

        if let activeNodeId {
            var profile = nodeProfiles[activeNodeId] ?? DialogueNodeProfile.derive(
                nodeId: activeNodeId,
                label: activeNodeLabel,
                nodeType: nodeType,
                noteBody: noteBody,
                linkedNodeLabels: linkedNodeLabels,
                insight: insight
            )
            profile = profile.refreshed(noteBody: noteBody, linkedNodeLabels: linkedNodeLabels, now: .now, insight: insight)
            profile.recordInteraction(userText: query)
            nodeProfiles[activeNodeId] = profile
            activeProfile = profile
        }

        messages.append(Message(role: .user, text: query))
        messages.append(Message(role: .assistant, text: ""))
        revealedCharCount = 0

        let prompt = buildPrompt(
            query: query,
            noteBody: noteBody,
            linkedNodeLabels: linkedNodeLabels,
            neighborContext: neighborContext
        )

        isStreaming = true
        onStreamingChanged?(true)

        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = triageService.stream(
                    prompt: prompt,
                    systemPrompt: nil,
                    operation: .ask(query: query),
                    contentLength: noteBody.count,
                    query: query
                )
                for try await chunk in stream {
                    self.appendStreamingText(chunk)
                }
                self.flushTokens()
            } catch {
                self.flushTokens()
                if !Task.isCancelled, !self.messages.isEmpty {
                    self.messages[self.messages.count - 1].text += "\n[Error: \(error.localizedDescription)]"
                }
            }
            self.isStreaming = false
            self.onStreamingChanged?(false)
        }
    }

    // MARK: - Token Buffering

    private func appendStreamingText(_ text: String) {
        streamBuffer.append(text)
    }

    private func flushTokens() {
        streamBuffer.flushNow()
    }

    // MARK: - Typewriter (~30 chars/sec)

    private func startTypewriter() {
        typewriterTask?.cancel()
        let totalChars = messages.last?.text.count ?? 0
        guard revealedCharCount < totalChars else { return }
        typewriterTask = Task { @MainActor [weak self] in
            while let self, self.revealedCharCount < (self.messages.last?.text.count ?? 0) {
                self.revealedCharCount += 1
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    // MARK: - Prompt

    private func buildPrompt(
        query: String,
        noteBody: String,
        linkedNodeLabels: [String],
        neighborContext: [(label: String, relationship: String, body: String)] = []
    ) -> String {
        var neighborSection = ""
        if !neighborContext.isEmpty {
            neighborSection = "\n\n--- CONNECTED NODES ---\n"
            for neighbor in neighborContext {
                neighborSection += "[\(neighbor.relationship.uppercased())] \(neighbor.label)"
                if !neighbor.body.isEmpty {
                    neighborSection += ":\n\(neighbor.body)\n"
                }
                neighborSection += "\n"
            }
            neighborSection += "--- END CONNECTIONS ---"
        }

        // Inject related notes from NoteInsightService (cross-note intelligence)
        var relatedSection = ""
        if let nodeId = activeNodeId {
            relatedSection = Self.buildRelatedNotesSection(for: nodeId)
        }

        return """
        Selected node: \(activeNodeLabel)
        Connected labels: \(linkedNodeLabels.joined(separator: ", "))

        --- CONTENT ---
        \(noteBody.prefix(6_000))
        --- END ---
        \(String(neighborSection.prefix(3_000)))
        \(String(relatedSection.prefix(2_000)))

        Answer the user's question directly from this context. Reference connected or related notes when useful. If the context does not answer the question, say so plainly. Keep the response concise unless the user asks for more.

        User question: \(query)
        """
    }

    /// Build a concise section listing ML-identified related notes (max 3, 1000 chars each).
    private static func buildRelatedNotesSection(for pageId: String) -> String {
        guard let bootstrap = AppBootstrap.shared else { return "" }
        let context = bootstrap.modelContainer.mainContext
        guard let insight = bootstrap.noteInsightService.fetchInsight(pageId: pageId, context: context) else { return "" }

        let relatedIds = insight.relatedNoteIds
        let reasons = insight.relatednessReasons
        guard !relatedIds.isEmpty else { return "" }

        var section = "\n\n--- RELATED NOTES (ML-identified) ---\n"
        let cap = min(3, relatedIds.count)
        for i in 0..<cap {
            let relId = relatedIds[i]
            let reasonList = i < reasons.count ? reasons[i].joined(separator: ", ") : "similarity"

            // Look up the note's label
            let targetId = relId
            let page = try? context.fetch(
                FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == targetId })
            ).first
            let label = page?.title ?? relId.prefix(8).description

            // Read a snippet of the related note's body
            let body = String(NoteFileStorage.readBody(pageId: relId).prefix(1_000))

            section += "[\(reasonList.uppercased())] \(label)"
            if !body.isEmpty {
                section += ":\n\(body)\n"
            }
            section += "\n"
        }
        section += "--- END RELATED ---"
        return section
    }
}
