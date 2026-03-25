import Foundation
import SwiftData

// MARK: - Notes Agent

/// Specialist agent for Epistemos note operations.
/// Uses the existing VaultSyncService and SwiftData ModelContainer to create/edit/search notes.
@MainActor
final class NotesAgent: OmegaAgent, @unchecked Sendable {
    let name = "notes"
    let description = "Epistemos note operations: create, edit, search, and organize notes"
    let toolNames = ["create_note", "edit_note", "search_notes", "list_notes"]

    private weak var modelContainer: ModelContainer?
    private weak var vaultSync: VaultSyncService?

    init(modelContainer: ModelContainer?, vaultSync: VaultSyncService?) {
        self.modelContainer = modelContainer
        self.vaultSync = vaultSync
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
        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any] else {
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

        default:
            throw NotesAgentError.unknownTool(step.toolName)
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
        let pages = (try? context.fetch(descriptor)) ?? []
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
        let pages = (try? context.fetch(descriptor)) ?? []
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
        guard let page = (try? context.fetch(descriptor))?.first else {
            throw NotesAgentError.operationFailed("Note '\(noteId)' not found")
        }

        if let body = newBody {
            page.saveBody(body)
            page.wordCount = body.split(separator: " ").count
            page.updatedAt = .now
            page.needsVaultSync = true
            try? context.save()
        }

        return "{\"success\":true,\"action\":\"edit_note\",\"pageId\":\(jsonEscape(page.id)),\"title\":\(jsonEscape(page.title))}"
    }

    // MARK: - Helpers

    private func jsonEscape(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [s]),
           let arr = String(data: data, encoding: .utf8) {
            return String(arr.dropFirst().dropLast())
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
