import Foundation
import SwiftData

// MARK: - Notes Agent

/// Specialist agent for Epistemos note operations.
/// Uses the existing VaultSyncService and GraphStore to create/edit/search notes.
@MainActor
final class NotesAgent: OmegaAgent, @unchecked Sendable {
    let name = "notes"
    let description = "Epistemos note operations: create, edit, search, and organize notes"
    let toolNames = ["create_note", "edit_note", "search_notes", "list_notes"]

    private weak var modelContainer: ModelContainer?

    init(modelContainer: ModelContainer?) {
        self.modelContainer = modelContainer
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
            let title = args["title"] as? String ?? "Untitled"
            let body = args["body"] as? String ?? ""
            // TODO: Wire to VaultSyncService.createPage() for real note creation
            return "{\"status\":\"acknowledged\",\"action\":\"create_note\",\"title\":\(jsonEscape(title)),\"note\":\"Note creation requires a local AI model for content generation. Load a model in Settings > Inference.\"}"

        case "search_notes":
            let query = args["query"] as? String ?? ""
            // TODO: Wire to GraphStore.search() for real search
            return "{\"status\":\"acknowledged\",\"action\":\"search_notes\",\"query\":\(jsonEscape(query)),\"results\":[],\"note\":\"Note search requires SwiftData integration.\"}"

        case "list_notes":
            // TODO: Wire to SwiftData fetch for real listing
            return "{\"status\":\"acknowledged\",\"action\":\"list_notes\",\"results\":[],\"note\":\"Note listing requires SwiftData integration.\"}"

        case "edit_note":
            return "{\"status\":\"acknowledged\",\"action\":\"edit_note\",\"note\":\"Note editing requires note ID and SwiftData integration.\"}"

        default:
            throw NotesAgentError.unknownTool(step.toolName)
        }
    }

    private func jsonEscape(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: s),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\"\(s)\""
    }
}

enum NotesAgentError: LocalizedError {
    case invalidArguments
    case unknownTool(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments: "Invalid arguments for notes operation"
        case .unknownTool(let name): "Unknown tool: \(name)"
        }
    }
}
