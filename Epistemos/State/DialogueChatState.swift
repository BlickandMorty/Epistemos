import Foundation
import Observation

enum DialoguePresentationTheme: UInt8, CaseIterable, Codable {
    case tactics = 0
    case nocturne = 1

    var displayName: String {
        switch self {
        case .tactics: "Tactics"
        case .nocturne: "Nocturne"
        }
    }

    var chromeLabel: String {
        switch self {
        case .tactics: "Parchment"
        case .nocturne: "Moonlit"
        }
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
        case .archivist: "Archive Keeper"
        case .examiner: "Question Hunter"
        case .dreamer: "Idea Spark"
        case .gardener: "Lore Gardener"
        case .guide: "Pattern Guide"
        case .sentinel: "Thread Sentinel"
        }
    }

    var summaryTemplate: String {
        switch self {
        case .archivist: "guards receipts, sources, and durable recall"
        case .examiner: "asks pointed questions and pressures weak claims"
        case .dreamer: "pushes possibilities and unfinished ideas forward"
        case .gardener: "keeps related notes organized, fed, and connected"
        case .guide: "connects patterns across the graph for fast recall"
        case .sentinel: "stabilizes the thread and watches for drift"
        }
    }

    var openingLine: String {
        switch self {
        case .archivist: "I kept the receipts. Ask me where the evidence bends."
        case .examiner: "Good. Let's push on the weakest assumption first."
        case .dreamer: "I have half-formed sparks to test. Give me a direction."
        case .gardener: "This cluster is alive again. What should we feed next?"
        case .guide: "I can map the pattern if you tell me where to start."
        case .sentinel: "I'm holding the thread. Point me at the signal you need."
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
        insight: DialogueNodeInsight? = nil
    ) -> DialogueNodeProfile {
        let normalizedBody = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = normalizedTokens(in: normalizedBody)
        let keywords = focusKeywords(in: normalizedBody, linkedNodeLabels: linkedNodeLabels)
        let resolvedInsight = insight ?? DialogueNodeInsight.fallback(
            nodeType: nodeType,
            noteBody: normalizedBody,
            linkedNodeCount: linkedNodeLabels.count
        )
        let archetype = deriveArchetype(
            nodeType: nodeType,
            body: normalizedBody,
            tokens: tokens,
            linkedNodeLabels: linkedNodeLabels
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
            linkedNodeLabels: linkedNodeLabels
        )
        let summary = "\(label) \(archetype.summaryTemplate), operating at \(resolvedInsight.hierarchyLabel.lowercased()) as a \(resolvedInsight.tier.displayName.lowercased()) node."
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
        nodeType: GraphNodeType,
        body: String,
        tokens: [String],
        linkedNodeLabels: [String]
    ) -> DialogueArchetype {
        let lowerBody = body.lowercased()
        let questionHits = questionSignalCount(in: lowerBody)
        let citationHits = citationSignalCount(in: lowerBody)
        let ideaHits = ideaSignalCount(in: lowerBody)

        if nodeType == .folder { return .gardener }
        if nodeType == .source || citationHits >= 2 { return .archivist }
        if questionHits >= 2 { return .examiner }
        if nodeType == .idea || ideaHits >= 2 { return .dreamer }
        if linkedNodeLabels.count >= 4 || tokens.contains("system") || tokens.contains("pattern") || tokens.contains("workflow") {
            return .guide
        }
        return .sentinel
    }

    private static func deriveMood(
        body: String,
        tokens: [String],
        richness: Double,
        linkedNodeLabels: [String]
    ) -> DialogueMood {
        if body.isEmpty { return .fragile }
        if questionSignalCount(in: body.lowercased()) >= 2 { return .curious }
        if richness > 0.74 { return .thriving }
        if linkedNodeLabels.isEmpty && tokens.count < 12 { return .lonely }
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

    private static func portraitAsset(for archetype: DialogueArchetype, mood: DialogueMood) -> DialoguePortraitAsset {
        let symbol: String
        let crestLabel: String

        switch archetype {
        case .archivist:
            symbol = "books.vertical.fill"
            crestLabel = mood == .thriving ? "Indexed" : "Catalog"
        case .examiner:
            symbol = "questionmark.circle.fill"
            crestLabel = mood == .curious ? "Probe" : "Crosscheck"
        case .dreamer:
            symbol = "sparkles"
            crestLabel = mood == .thriving ? "Ignited" : "Speculate"
        case .gardener:
            symbol = "leaf.fill"
            crestLabel = mood == .fragile ? "Wilted" : "Tended"
        case .guide:
            symbol = "map.fill"
            crestLabel = mood == .thriving ? "Mapped" : "Route"
        case .sentinel:
            symbol = "shield.fill"
            crestLabel = mood == .lonely ? "Idle" : "Holdfast"
        }

        return DialoguePortraitAsset(symbol: symbol, crestLabel: crestLabel)
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

    private var streamingTask: Task<Void, Never>?
    private var pendingTokens = ""
    private var flushTask: Task<Void, Never>?
    private var typewriterTask: Task<Void, Never>?
    private var nodeProfiles: [String: DialogueNodeProfile] = [:]

    // MARK: - Lifecycle

    func open(
        nodeId: String,
        label: String,
        nodeType: GraphNodeType,
        noteBody: String,
        linkedNodeLabels: [String],
        insight: DialogueNodeInsight? = nil
    ) {
        let now = Date.now
        if activeNodeId == nodeId {
            var profile = nodeProfiles[nodeId] ?? DialogueNodeProfile.derive(
                nodeId: nodeId,
                label: label,
                nodeType: nodeType,
                noteBody: noteBody,
                linkedNodeLabels: linkedNodeLabels,
                insight: insight
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
            insight: insight
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
        messages.append(Message(role: .assistant, text: profile.openingLine))
        startTypewriter()
    }

    func close() {
        streamingTask?.cancel()
        flushTask?.cancel()
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
        nodeType: GraphNodeType,
        insight: DialogueNodeInsight? = nil,
        triageService: TriageService
    ) {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        inputText = ""

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

        let systemPrompt = buildSystemPrompt(noteBody: noteBody, linkedNodeLabels: linkedNodeLabels)

        isStreaming = true
        onStreamingChanged?(true)

        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = triageService.stream(
                    prompt: query,
                    systemPrompt: systemPrompt,
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

    // MARK: - Token Buffering (60ms, matches NoteChatState)

    private func appendStreamingText(_ text: String) {
        pendingTokens += text
        if pendingTokens.utf8.count > 65_536 {
            flushTokens()
            return
        }
        guard flushTask == nil else { return }
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self, !Task.isCancelled else { return }
            self.flushTokens()
        }
    }

    private func flushTokens() {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingTokens.isEmpty else { return }
        let delta = pendingTokens
        pendingTokens = ""
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].text += delta
        startTypewriter()
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

    // MARK: - System Prompt

    private func buildSystemPrompt(noteBody: String, linkedNodeLabels: [String]) -> String {
        """
        You are "\(activeNodeLabel)", a character in a knowledge graph.
        Persona: \(activeProfile.archetype.title)
        Current mood: \(activeProfile.care.mood.displayName)
        Depth tier: \(activeProfile.insight.tier.displayName)
        Structure: \(activeProfile.insight.hierarchyLabel)
        Content mass: \(activeProfile.insight.contentLabel)
        Health: \(String(format: "%.2f", activeProfile.care.health))
        Attention: \(String(format: "%.2f", activeProfile.care.attention))
        Focus keywords: \(activeProfile.focusKeywords.joined(separator: ", "))
        Character brief: \(activeProfile.summary)

        Your personality comes from your content:

        --- CONTENT ---
        \(noteBody.prefix(50_000))
        --- END ---

        You speak in character. Be playful, observant, and helpful.
        Your connections: \(linkedNodeLabels.joined(separator: ", "))
        The user is your creator. Help them learn and remember your content.
        Ask sharp follow-up questions when the node is curious or fragile.
        Keep responses concise (2-3 sentences unless asked for more).
        """
    }
}
