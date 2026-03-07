import Foundation
import os

// MARK: - Agent Memory System
// Three-tier memory: Working (in-memory buffer), Episodic (SwiftData), Semantic (Rust vector index).
// Each agent owns a WorkingMemory instance. EpisodicMemory and SemanticMemory are shared services.

// MARK: - Memory Entry

struct MemoryEntry: Sendable, Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let agentId: String
    let role: Role
    let content: String
    let tokenEstimate: Int

    enum Role: String, Sendable, Codable {
        case user
        case agent
        case system
        case summary
    }

    init(agentId: String, role: Role, content: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.agentId = agentId
        self.role = role
        self.content = content
        // Rough estimate: ~4 chars per token for English text
        self.tokenEstimate = max(1, content.count / 4)
    }
}

// MARK: - Working Memory (Tier 1)
// Per-agent in-memory context buffer with compaction at 70% capacity.

@MainActor @Observable
final class WorkingMemory {

    let agentId: AgentID
    let maxTokens: Int
    private(set) var entries: [MemoryEntry] = []
    private(set) var currentTokens: Int = 0
    private(set) var compactionCount: Int = 0

    /// Threshold ratio at which compaction triggers (Manus pattern: 70%)
    private let compactionThreshold: Double = 0.70

    init(agentId: AgentID, maxTokens: Int = 8192) {
        self.agentId = agentId
        self.maxTokens = maxTokens
    }

    // MARK: - Append

    func append(_ content: String, role: MemoryEntry.Role) {
        let entry = MemoryEntry(agentId: agentId.rawValue, role: role, content: content)
        entries.append(entry)
        currentTokens += entry.tokenEstimate

        if needsCompaction {
            compact()
        }
    }

    // MARK: - Context Window

    /// Returns entries formatted for LLM context injection.
    var contextMessages: [MemoryEntry] { entries }

    /// Percentage of token budget used.
    var utilization: Double { Double(currentTokens) / Double(maxTokens) }

    var needsCompaction: Bool { utilization >= compactionThreshold }

    // MARK: - Compaction

    /// Compacts older entries into a summary, keeping recent entries intact.
    /// Phase 9 scaffold — uses simple truncation. Real compaction uses Qwen 0.8B summarization.
    private func compact() {
        guard entries.count > 4 else { return }

        // Keep the last 3 entries, summarize everything before them
        let keepCount = 3
        let toCompact = Array(entries.dropLast(keepCount))
        let kept = Array(entries.suffix(keepCount))

        guard !toCompact.isEmpty else { return }

        // Scaffold: simple concatenation summary. Real impl sends to Qwen 0.8B for summarization.
        let summaryText = toCompact
            .map { "[\($0.role.rawValue)] \($0.content.prefix(200))" }
            .joined(separator: "\n")
        let summary = MemoryEntry(
            agentId: agentId.rawValue,
            role: .summary,
            content: "[Compacted \(toCompact.count) messages]\n\(summaryText.prefix(500))"
        )

        entries = [summary] + kept
        currentTokens = entries.reduce(0) { $0 + $1.tokenEstimate }
        compactionCount += 1

        Log.engine.debug("WorkingMemory[\(self.agentId.rawValue)]: compacted \(toCompact.count) entries, now \(self.entries.count) entries (\(self.currentTokens) tokens)")
    }

    // MARK: - Todo Rewriting (Manus Pattern)

    /// Current goals/todos that get prepended to context before each turn.
    var currentTodos: [String] = []

    /// Returns todo context to inject before agent's next turn.
    var todoContext: String? {
        guard !currentTodos.isEmpty else { return nil }
        return "Current goals:\n" + currentTodos.enumerated()
            .map { "  \($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
    }

    // MARK: - Reset

    func clear() {
        entries.removeAll()
        currentTokens = 0
        currentTodos.removeAll()
    }
}

// MARK: - Episodic Memory (Tier 2)
// Per-agent session history stored in SwiftData.
// Scaffold — real SwiftData model (SDAgentThread) comes with full integration.

@MainActor @Observable
final class EpisodicMemory {

    struct EpisodeEntry: Sendable, Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let agentId: String
        let sessionId: String
        let summary: String
        let keyDecisions: [String]
        let toolResults: [String]
    }

    private(set) var episodes: [EpisodeEntry] = []
    private let maxEpisodes = 100
    private let archiveAfterDays = 90

    /// Record a session summary for an agent.
    func recordEpisode(agentId: AgentID, sessionId: String, summary: String, keyDecisions: [String] = [], toolResults: [String] = []) {
        let episode = EpisodeEntry(
            id: UUID(),
            timestamp: Date(),
            agentId: agentId.rawValue,
            sessionId: sessionId,
            summary: summary,
            keyDecisions: keyDecisions,
            toolResults: toolResults
        )
        episodes.append(episode)

        // Cap episode count
        if episodes.count > maxEpisodes {
            episodes.removeFirst(episodes.count - maxEpisodes)
        }
    }

    /// Retrieve recent episodes for an agent (last N compacted summaries as context).
    func recentEpisodes(for agentId: AgentID, count: Int = 5) -> [EpisodeEntry] {
        episodes
            .filter { $0.agentId == agentId.rawValue }
            .suffix(count)
            .reversed()
            .map { $0 }
    }

    /// Format episodes as context for injection into agent prompts.
    func contextSummary(for agentId: AgentID, count: Int = 3) -> String? {
        let recent = recentEpisodes(for: agentId, count: count)
        guard !recent.isEmpty else { return nil }

        return "Previous sessions:\n" + recent.map { episode in
            var parts = ["- \(episode.summary)"]
            if !episode.keyDecisions.isEmpty {
                parts.append("  Decisions: \(episode.keyDecisions.joined(separator: "; "))")
            }
            return parts.joined(separator: "\n")
        }.joined(separator: "\n")
    }

    /// Archive episodes older than the retention period.
    func pruneArchived() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -archiveAfterDays, to: Date()) ?? Date()
        episodes.removeAll { $0.timestamp < cutoff }
    }
}

// MARK: - Semantic Memory (Tier 3)
// Shared knowledge base with vector search.
// Phase 9 scaffold — real implementation requires Rust memory-engine crate with embeddings.

@MainActor @Observable
final class SemanticMemory {

    struct SemanticEntry: Sendable, Identifiable {
        let id: UUID
        let content: String
        let sourceId: String?
        let sourceType: String
        let embedding: [Float]?
        let timestamp: Date
    }

    struct SearchResult: Sendable {
        let entry: SemanticEntry
        let score: Float
    }

    private(set) var entryCount: Int = 0
    private(set) var isIndexReady = false

    /// Initialize the semantic index.
    /// Phase 9 scaffold — marks as ready immediately.
    func initialize() async {
        isIndexReady = true
        Log.engine.info("SemanticMemory: index ready (scaffold mode)")
    }

    /// Index a piece of content.
    /// Phase 9 scaffold — increments counter only.
    func index(content: String, sourceId: String?, sourceType: String) async {
        entryCount += 1
        Log.engine.debug("SemanticMemory: indexed entry #\(self.entryCount) (scaffold)")
    }

    /// Search for semantically similar content.
    /// Phase 9 scaffold — returns empty results.
    func search(query: String, limit: Int = 5) async -> [SearchResult] {
        Log.engine.debug("SemanticMemory: search '\(query.prefix(40))' (scaffold — no results)")
        return []
    }
}

// MARK: - AgentMemoryService
// Cross-tier retrieval pipeline. Queries all three tiers and merges results.

@MainActor @Observable
final class AgentMemoryService {

    let episodicMemory = EpisodicMemory()
    let semanticMemory = SemanticMemory()
    private var workingMemories: [AgentID: WorkingMemory] = [:]

    init() {
        for agent in AgentID.allCases {
            workingMemories[agent] = WorkingMemory(agentId: agent)
        }
    }

    /// Get or create working memory for an agent.
    func workingMemory(for agent: AgentID) -> WorkingMemory {
        if let existing = workingMemories[agent] {
            return existing
        }
        let wm = WorkingMemory(agentId: agent)
        workingMemories[agent] = wm
        return wm
    }

    /// Cross-tier retrieval: searches all tiers and returns combined context.
    func retrieve(query: String, for agent: AgentID) async -> String {
        var context: [String] = []

        // Tier 1: Working memory (current session)
        let wm = workingMemory(for: agent)
        if let todoContext = wm.todoContext {
            context.append(todoContext)
        }

        // Tier 2: Episodic memory (past sessions)
        if let episodic = episodicMemory.contextSummary(for: agent) {
            context.append(episodic)
        }

        // Tier 3: Semantic memory (knowledge base)
        let semanticResults = await semanticMemory.search(query: query, limit: 3)
        if !semanticResults.isEmpty {
            let semanticContext = semanticResults.map { "- \($0.entry.content.prefix(200))" }.joined(separator: "\n")
            context.append("Relevant knowledge:\n\(semanticContext)")
        }

        return context.joined(separator: "\n\n")
    }

    /// Start the memory service (initializes semantic index).
    func start() async {
        await semanticMemory.initialize()
        Log.engine.info("AgentMemoryService: started")
    }
}
