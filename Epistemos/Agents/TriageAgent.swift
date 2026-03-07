import Foundation
import os

// MARK: - TriageAgent

@MainActor
final class TriageAgent: AgentProtocol {
    let id: AgentID = .triage
    private(set) var status: AgentStatus = .idle
    var trustLevel: TrustLevel = .sandbox

    private let messageBus: MessageBus
    private let mlxClient: MLXClient?
    private var currentTask: Task<Void, Never>?

    init(messageBus: MessageBus, mlxClient: MLXClient?) {
        self.messageBus = messageBus
        self.mlxClient = mlxClient
    }

    // MARK: - Classification

    func classify(_ input: String) async -> TriageClassification {
        guard let client = mlxClient else {
            return classifyByKeyword(input)
        }

        let prompt = Self.classificationPrompt(for: input)

        do {
            let response = try await client.generate(
                prompt: prompt,
                systemPrompt: nil,
                maxTokens: 16
            )
            return Self.parseClassification(response)
        } catch {
            Log.engine.warning("TriageAgent: MLX classification failed, falling back to keyword: \(error.localizedDescription, privacy: .public)")
            return classifyByKeyword(input)
        }
    }

    // MARK: - AgentProtocol

    func handleTask(_ task: AgentTask) async {
        status = .thinking

        let classification = await classify(task.instruction)

        switch classification {
        case .direct:
            status = .working(task: "Answering directly")
            await messageBus.publish(.taskComplete(
                from: .triage,
                result: AgentResult(taskId: task.id, from: .triage, output: "")
            ))

        case .librarian, .writer, .builder:
            let target: AgentID = switch classification {
            case .librarian: .librarian
            case .writer: .writer
            case .builder: .builder
            default: .triage
            }

            status = .working(task: "Routing to \(target.displayName)")
            await messageBus.publish(.activityLog(
                from: .triage,
                action: "route",
                detail: "Routing to \(target.displayName): \(task.instruction.prefix(80))"
            ))

            let routed = AgentTask(from: .triage, to: target, instruction: task.instruction, context: task.context)
            await messageBus.publish(.taskAssignment(from: .triage, to: target, task: routed))

        case .learningPool:
            status = .working(task: "Querying Learning Pool")
            await messageBus.publish(.searchRequest(
                from: .triage,
                query: SearchQuery(text: task.instruction, maxResults: 5, from: .triage)
            ))
        }

        status = .idle
    }

    func handleMention(from: AgentID, context: String, request: String) async -> String {
        let classification = await classify(request)
        return "Classification: \(classification.rawValue)"
    }

    func handleInsight(_ insight: String, from: AgentID) {
        // Triage doesn't process insights
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        status = .idle
    }

    // MARK: - Classification Prompt

    static func classificationPrompt(for input: String) -> String {
        """
        You are a task router. Classify the user's message into exactly one category. \
        Reply with ONLY the category name, nothing else.

        Categories:
        - DIRECT: Greetings, simple facts, trivial questions
        - LIBRARIAN: Note organization, search, connections, tagging, finding notes
        - WRITER: Prose improvement, research writing, article drafting, editing text
        - BUILDER: Code generation, file creation, terminal commands, programming
        - LEARNING_POOL: Web search, academic research, current events, external knowledge

        Examples:
        "organize my notes from last week" -> LIBRARIAN
        "write me a swift function that parses JSON" -> BUILDER
        "help me polish this paragraph" -> WRITER
        "what's the latest on CRISPR research" -> LEARNING_POOL
        "hi" -> DIRECT
        "summarize my notes on quantum computing" -> LIBRARIAN
        "build me a parser for markdown" -> BUILDER
        "rewrite this methodology section" -> WRITER
        "search for recent papers on transformers" -> LEARNING_POOL
        "hello, how are you" -> DIRECT
        "find all notes tagged with physics" -> LIBRARIAN
        "create a unit test for this class" -> BUILDER
        "make this text more concise" -> WRITER
        "what happened in AI news today" -> LEARNING_POOL
        "thanks" -> DIRECT

        User message: \(input)
        Classification:
        """
    }

    static func parseClassification(_ response: String) -> TriageClassification {
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "->", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.contains("LIBRARIAN") { return .librarian }
        if cleaned.contains("WRITER") { return .writer }
        if cleaned.contains("BUILDER") { return .builder }
        if cleaned.contains("LEARNING_POOL") || cleaned.contains("LEARNING") { return .learningPool }
        if cleaned.contains("DIRECT") { return .direct }

        return .direct
    }

    // MARK: - Keyword Fallback

    private func classifyByKeyword(_ input: String) -> TriageClassification {
        let lower = input.lowercased()
        let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))

        let builderKeywords: Set<String> = ["code", "function", "class", "build", "compile", "run", "test", "debug",
                               "swift", "rust", "python", "javascript", "terminal", "shell", "git",
                               "parse", "implement", "refactor", "api", "endpoint"]
        let writerKeywords: Set<String> = ["write", "rewrite", "polish", "edit", "draft", "proofread", "essay",
                              "paragraph", "article", "blog", "improve", "concise", "rephrase",
                              "methodology", "abstract"]
        let librarianKeywords: Set<String> = ["note", "notes", "find", "search", "tag", "organize", "connect", "link",
                                 "folder", "move", "rename", "categorize", "index"]
        let poolKeywords: Set<String> = ["research", "latest", "news", "paper", "study", "current", "trend",
                           "explain"]

        // Multi-word phrases checked via substring
        let poolPhrases = ["what is", "how does", "look up", "summarize this text"]

        if !words.isDisjoint(with: builderKeywords) { return .builder }
        if !words.isDisjoint(with: writerKeywords) { return .writer }
        if !words.isDisjoint(with: librarianKeywords) { return .librarian }
        if !words.isDisjoint(with: poolKeywords) { return .learningPool }
        if poolPhrases.contains(where: { lower.contains($0) }) { return .learningPool }

        return .direct
    }
}
