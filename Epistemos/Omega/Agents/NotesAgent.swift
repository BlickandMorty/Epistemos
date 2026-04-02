import Foundation
import OSLog
import SwiftData

// MARK: - Notes Agent

/// Specialist agent for Epistemos note operations.
/// Uses the existing VaultSyncService and SwiftData ModelContainer to create/edit/search notes.
@MainActor
final class NotesAgent: OmegaAgent, Sendable {
    private let log = Logger(subsystem: "com.epistemos", category: "NotesAgent")
    let name = "notes"
    let description = "Epistemos note operations: create, edit, search, and organize notes"
    let toolNames = ["create_note", "edit_note", "search_notes", "list_notes",
                      "collectsnippet", "savecitation", "createresearchnote",
                      "analyzecontradiction", "scoreevidence"]

    private weak var modelContainer: ModelContainer?
    private weak var vaultSync: VaultSyncService?
    weak var triageService: TriageService?

    init(modelContainer: ModelContainer?, vaultSync: VaultSyncService?, triageService: TriageService? = nil) {
        self.modelContainer = modelContainer
        self.vaultSync = vaultSync
        self.triageService = triageService
    }

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now
        guard let container = modelContainer else {
            return .fail("Model container unavailable", stepId: step.id, durationMs: 0)
        }

        do {
            let result = try await executeInternal(step: step, container: container)
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .ok(result, stepId: step.id, durationMs: elapsed)
        } catch {
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .fail(error.localizedDescription, stepId: step.id, durationMs: elapsed)
        }
    }

    private func executeInternal(step: AgentStep, container: ModelContainer) async throws -> String {
        let argsObject: Any
        do {
            argsObject = try JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8))
        } catch {
            log.error(
                "NotesAgent: failed to parse step arguments for \(step.toolName, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw NotesAgentError.invalidArguments
        }

        guard let args = argsObject as? [String: Any] else {
            log.error(
                "NotesAgent: failed to parse step arguments for \(step.toolName, privacy: .public): root JSON was not an object"
            )
            throw NotesAgentError.invalidArguments
        }

        switch step.toolName {
        case "create_note":
            return try await createNote(args: args)

        case "search_notes":
            return try await searchNotes(args: args, container: container)

        case "list_notes":
            return try await listNotes(container: container)

        case "edit_note":
            return try await editNote(args: args, container: container)

        case "collectsnippet":
            return try await collectSnippet(args: args)

        case "savecitation":
            return try await saveCitation(args: args)

        case "createresearchnote":
            return try await createResearchNote(args: args)

        case "analyzecontradiction":
            return try await analyzeContradiction(args: args)

        case "scoreevidence":
            return scoreEvidence(args: args)

        default:
            throw NotesAgentError.unknownTool(step.toolName)
        }
    }

    private func fetchAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> [T]? {
        do {
            return try context.fetch(descriptor)
        } catch {
            log.error(
                "NotesAgent: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> T? {
        fetchAll(descriptor, in: context, label: label)?.first
    }

    private func saveContext(_ context: ModelContext, label: String) throws {
        do {
            try context.save()
        } catch {
            log.error(
                "NotesAgent: failed to save \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw NotesAgentError.operationFailed("Failed to save \(label)")
        }
    }

    // MARK: - Tool Implementations

    private func createNote(args: [String: Any]) async throws -> String {
        guard let sync = vaultSync else {
            throw NotesAgentError.serviceUnavailable("VaultSyncService")
        }

        let title = args["title"] as? String ?? "Untitled"
        let body = args["body"] as? String ?? ""

        guard let pageId = await sync.createPage(title: title, body: body) else {
            throw NotesAgentError.operationFailed("Failed to create note '\(title)'")
        }

        return "{\"success\":true,\"action\":\"create_note\",\"pageId\":\(jsonEscape(pageId)),\"title\":\(jsonEscape(title))}"
    }

    private func searchNotes(args: [String: Any], container: ModelContainer) async throws -> String {
        let query = args["query"] as? String ?? ""
        guard !query.isEmpty else {
            throw NotesAgentError.invalidArguments
        }

        // Use VaultSyncService FTS5 search if available
        if let sync = vaultSync {
            let results = await sync.searchFullAsync(query: query, limit: 20)
            let items = results.map { r in
                "{\"pageId\":\(jsonEscape(r.pageId)),\"title\":\(jsonEscape(r.title)),\"snippet\":\(jsonEscape(r.snippet))}"
            }
            return "{\"success\":true,\"action\":\"search_notes\",\"query\":\(jsonEscape(query)),\"count\":\(items.count),\"results\":[\(items.joined(separator: ","))]}"
        }

        // Fallback: SwiftData title search
        let context = container.mainContext
        let predicate = #Predicate<SDPage> { page in
            page.title.localizedStandardContains(query) && !page.isArchived
        }
        let descriptor = FetchDescriptor<SDPage>(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        guard let pages = fetchAll(descriptor, in: context, label: "note search") else {
            throw NotesAgentError.operationFailed("Failed to search notes")
        }
        let items = pages.prefix(20).map { p in
            "{\"pageId\":\(jsonEscape(p.id)),\"title\":\(jsonEscape(p.title))}"
        }
        return "{\"success\":true,\"action\":\"search_notes\",\"query\":\(jsonEscape(query)),\"count\":\(items.count),\"results\":[\(items.joined(separator: ","))]}"
    }

    private func listNotes(container: ModelContainer) async throws -> String {
        let context = container.mainContext
        let predicate = #Predicate<SDPage> { page in
            !page.isArchived && page.templateId == nil
        }
        var descriptor = FetchDescriptor<SDPage>(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 50
        guard let pages = fetchAll(descriptor, in: context, label: "note listing") else {
            throw NotesAgentError.operationFailed("Failed to list notes")
        }
        let items = pages.map { p in
            "{\"pageId\":\(jsonEscape(p.id)),\"title\":\(jsonEscape(p.title)),\"emoji\":\(jsonEscape(p.emoji)),\"updatedAt\":\(jsonEscape(ISO8601DateFormatter().string(from: p.updatedAt)))}"
        }
        return "{\"success\":true,\"action\":\"list_notes\",\"count\":\(items.count),\"results\":[\(items.joined(separator: ","))]}"
    }

    private func editNote(args: [String: Any], container: ModelContainer) async throws -> String {
        guard let noteId = args["id"] as? String else {
            throw NotesAgentError.invalidArguments
        }
        let newBody = args["body"] as? String

        let context = container.mainContext
        let predicate = #Predicate<SDPage> { page in page.id == noteId }
        let descriptor = FetchDescriptor<SDPage>(predicate: predicate)
        guard let page = fetchFirst(descriptor, in: context, label: "note edit") else {
            throw NotesAgentError.operationFailed("Note '\(noteId)' not found")
        }

        if let body = newBody {
            page.saveBody(body)
            page.wordCount = body.split(separator: " ").count
            page.updatedAt = .now
            page.needsVaultSync = true
            try saveContext(context, label: "edited note")
        }

        return "{\"success\":true,\"action\":\"edit_note\",\"pageId\":\(jsonEscape(page.id)),\"title\":\(jsonEscape(page.title))}"
    }

    // MARK: - Research Tools

    private func collectSnippet(args: [String: Any]) async throws -> String {
        guard let sync = vaultSync else {
            throw NotesAgentError.serviceUnavailable("VaultSyncService")
        }
        guard let text = args["text"] as? String else {
            throw NotesAgentError.invalidArguments
        }

        let sourceUrl = args["sourceUrl"] as? String ?? ""
        let sourceTitle = args["sourceTitle"] as? String ?? sourceUrl
        let sessionNoteId = args["sessionNoteId"] as? String

        let snippetBody = "> \(text)\n> -- [\(sourceTitle)](\(sourceUrl))\n\n"

        if let noteId = sessionNoteId {
            guard let context = modelContainer?.mainContext else {
                throw NotesAgentError.serviceUnavailable("Model context")
            }
            let predicate = #Predicate<SDPage> { page in page.id == noteId }
            let descriptor = FetchDescriptor<SDPage>(predicate: predicate)
            if let page = fetchFirst(descriptor, in: context, label: "snippet session note") {
                NoteFileStorage.requestFlush(pageId: noteId)
                let existingBody = page.loadBody()
                page.saveBody(existingBody + snippetBody)
                page.wordCount = (existingBody + snippetBody).split(separator: " ").count
                page.updatedAt = .now
                page.needsVaultSync = true
                try saveContext(context, label: "snippet session note")
                NoteFileStorage.notifyBodyChanged(pageId: noteId)
                return "{\"success\":true,\"action\":\"collectsnippet\",\"sessionNoteId\":\(jsonEscape(noteId)),\"sourceUrl\":\(jsonEscape(sourceUrl)),\"sourceTitle\":\(jsonEscape(sourceTitle)),\"text\":\(jsonEscape(text))}"
            }
        }

        // Create new session note
        let title = "Research Session — \(ISO8601DateFormatter().string(from: Date()).prefix(10))"
        guard let pageId = await sync.createPage(title: title, body: "# Research Session\n\n" + snippetBody) else {
            throw NotesAgentError.operationFailed("Failed to create research session note")
        }

        return "{\"success\":true,\"action\":\"collectsnippet\",\"sessionNoteId\":\(jsonEscape(pageId)),\"sourceUrl\":\(jsonEscape(sourceUrl)),\"sourceTitle\":\(jsonEscape(sourceTitle)),\"text\":\(jsonEscape(text))}"
    }

    private func saveCitation(args: [String: Any]) async throws -> String {
        guard let sync = vaultSync else {
            throw NotesAgentError.serviceUnavailable("VaultSyncService")
        }
        guard let title = args["title"] as? String,
              let url = args["url"] as? String else {
            throw NotesAgentError.invalidArguments
        }

        let authors = args["authors"] as? String ?? "Unknown"
        let date = args["date"] as? String ?? ""
        let sessionNoteId = args["sessionNoteId"] as? String

        let citationLine = "- \(authors)\(date.isEmpty ? "" : " (\(date))"). [\(title)](\(url))\n"

        if let noteId = sessionNoteId {
            guard let context = modelContainer?.mainContext else {
                throw NotesAgentError.serviceUnavailable("Model context")
            }
            let predicate = #Predicate<SDPage> { page in page.id == noteId }
            let descriptor = FetchDescriptor<SDPage>(predicate: predicate)
            if let page = fetchFirst(descriptor, in: context, label: "citation session note") {
                NoteFileStorage.requestFlush(pageId: noteId)
                var body = page.loadBody()
                // Deduplicate by URL
                guard !body.contains(url) else {
                    return "{\"success\":true,\"action\":\"savecitation\",\"deduplicated\":true}"
                }
                if body.contains("## Citations") {
                    body += citationLine
                } else {
                    body += "\n## Citations\n\n" + citationLine
                }
                page.saveBody(body)
                page.updatedAt = .now
                page.needsVaultSync = true
                try saveContext(context, label: "citation session note")
                NoteFileStorage.notifyBodyChanged(pageId: noteId)
                return "{\"success\":true,\"action\":\"savecitation\",\"sessionNoteId\":\(jsonEscape(noteId))}"
            }
        }

        // Create standalone citation note
        let noteTitle = "Citation: \(title)"
        guard let pageId = await sync.createPage(title: noteTitle, body: "## Citations\n\n" + citationLine) else {
            throw NotesAgentError.operationFailed("Failed to create citation note")
        }

        return "{\"success\":true,\"action\":\"savecitation\",\"pageId\":\(jsonEscape(pageId))}"
    }

    private func createResearchNote(args: [String: Any]) async throws -> String {
        guard let sync = vaultSync else {
            throw NotesAgentError.serviceUnavailable("VaultSyncService")
        }
        guard let question = args["question"] as? String,
              let findings = args["findings"] as? String else {
            throw NotesAgentError.invalidArguments
        }

        let evidence = args["evidence"] as? [String] ?? []
        let contradictions = args["contradictions"] as? [String] ?? []
        let citations = args["citations"] as? [String] ?? []

        var body = "# \(question)\n\n"
        body += "## Findings\n\n\(findings)\n\n"

        if !evidence.isEmpty {
            body += "## Evidence\n\n"
            for item in evidence { body += "- \(item)\n" }
            body += "\n"
        }

        if !contradictions.isEmpty {
            body += "## Contradictions\n\n"
            for item in contradictions { body += "- \(item)\n" }
            body += "\n"
        }

        if !citations.isEmpty {
            body += "## Citations\n\n"
            for item in citations { body += "- \(item)\n" }
            body += "\n"
        }

        let noteTitle = "Research: \(String(question.prefix(60)))"
        guard let pageId = await sync.createPage(title: noteTitle, body: body) else {
            throw NotesAgentError.operationFailed("Failed to create research note")
        }

        return "{\"success\":true,\"action\":\"createresearchnote\",\"pageId\":\(jsonEscape(pageId)),\"title\":\(jsonEscape(noteTitle))}"
    }

    private func analyzeContradiction(args: [String: Any]) async throws -> String {
        guard let snippetA = args["snippetA"] as? String,
              let snippetB = args["snippetB"] as? String else {
            throw NotesAgentError.invalidArguments
        }

        // Heuristic check first: look for direct numerical contradictions
        let verdict = heuristicContradictionCheck(snippetA, snippetB)
        if let verdict {
            return "{\"success\":true,\"action\":\"analyzecontradiction\",\"verdict\":\(jsonEscape(verdict)),\"method\":\"heuristic\",\"confidence\":0.75,\"snippetA\":\(jsonEscape(snippetA)),\"snippetB\":\(jsonEscape(snippetB))}"
        }

        // LLM fallback via TriageService
        if let triage = triageService {
            let prompt = """
            Compare these two passages and determine if they agree, contradict, or are orthogonal (unrelated).

            Passage A: \(String(snippetA.prefix(500)))

            Passage B: \(String(snippetB.prefix(500)))

            Respond with ONLY one word: agree, contradict, or orthogonal
            """
            do {
                let raw = try await triage.generateRawLocal(prompt: prompt, systemPrompt: "You are a precise fact-checker. Respond with exactly one word.", maxTokens: 16)
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let result: String
                if cleaned.contains("contradict") {
                    result = "contradict"
                } else if cleaned.contains("agree") {
                    result = "agree"
                } else {
                    result = "orthogonal"
                }
                return "{\"success\":true,\"action\":\"analyzecontradiction\",\"verdict\":\(jsonEscape(result)),\"method\":\"llm\",\"confidence\":0.80,\"snippetA\":\(jsonEscape(snippetA)),\"snippetB\":\(jsonEscape(snippetB))}"
            } catch {
                // Fall through to default
            }
        }

        return "{\"success\":true,\"action\":\"analyzecontradiction\",\"verdict\":\"orthogonal\",\"method\":\"default\",\"confidence\":0.50,\"snippetA\":\(jsonEscape(snippetA)),\"snippetB\":\(jsonEscape(snippetB))}"
    }

    private func scoreEvidence(args: [String: Any]) -> String {
        let url = args["url"] as? String ?? ""
        let sourceType = args["sourceType"] as? String
        let (tier, confidence) = ResearchEvidenceScorer.score(url: url, sourceType: sourceType)
        return "{\"success\":true,\"action\":\"scoreevidence\",\"url\":\(jsonEscape(url)),\"tier\":\(jsonEscape(tier.rawValue)),\"confidence\":\(confidence)}"
    }

    /// Simple heuristic contradiction check for obvious numerical/factual disagreements.
    private func heuristicContradictionCheck(_ a: String, _ b: String) -> String? {
        // Extract numbers from both snippets
        let numberPattern = /\$?[\d,]+\.?\d*\s*(%|billion|million|thousand|B|M|K)?/
        let numsA = a.matches(of: numberPattern).map { String($0.output.0) }
        let numsB = b.matches(of: numberPattern).map { String($0.output.0) }

        // If both have numbers for the same context and they differ significantly
        if !numsA.isEmpty && !numsB.isEmpty {
            let setA = Set(numsA)
            let setB = Set(numsB)
            if setA.isDisjoint(with: setB) && numsA.count <= 3 && numsB.count <= 3 {
                return "contradict"
            }
        }

        // Check for direct negation patterns
        let lowA = a.lowercased()
        let lowB = b.lowercased()
        if (lowA.contains("is not") && lowB.contains("is ") && !lowB.contains("is not")) ||
           (lowB.contains("is not") && lowA.contains("is ") && !lowA.contains("is not")) {
            return "contradict"
        }

        return nil
    }

    // MARK: - Helpers

    private func jsonEscape(_ s: String) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: [s])
            if let arr = String(data: data, encoding: .utf8) {
                return String(arr.dropFirst().dropLast())
            }
            log.error("NotesAgent: failed to encode JSON string because UTF-8 conversion returned nil")
        } catch {
            log.error(
                "NotesAgent: failed to encode JSON string: \(error.localizedDescription, privacy: .public)"
            )
        }
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
                       .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

enum NotesAgentError: LocalizedError {
    case invalidArguments
    case unknownTool(String)
    case serviceUnavailable(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments: "Invalid arguments for notes operation"
        case .unknownTool(let name): "Unknown tool: \(name)"
        case .serviceUnavailable(let svc): "\(svc) not available"
        case .operationFailed(let msg): msg
        }
    }
}
