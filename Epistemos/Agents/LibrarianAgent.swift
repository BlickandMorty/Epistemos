import Foundation
import os

// MARK: - LibrarianAgent

@MainActor
final class LibrarianAgent: AgentProtocol {
    let id: AgentID = .librarian
    private(set) var status: AgentStatus = .idle
    var trustLevel: TrustLevel = .standard

    private let messageBus: MessageBus
    private var currentTask: Task<Void, Never>?

    init(messageBus: MessageBus) {
        self.messageBus = messageBus
    }

    // MARK: - AgentProtocol

    func handleTask(_ task: AgentTask) async {
        status = .working(task: task.instruction.prefix(40) + "…")

        await messageBus.publish(.activityLog(
            from: .librarian,
            action: "task_start",
            detail: task.instruction
        ))

        // For now, acknowledge the task and publish completion.
        // Full implementation (note indexing, embedding search, proactive scanning)
        // requires the Rust memory-engine crate (Phase 9).
        let output = "Librarian received task: \(task.instruction)"

        await messageBus.publish(.taskComplete(
            from: .librarian,
            result: AgentResult(taskId: task.id, from: .librarian, output: output)
        ))

        status = .idle
    }

    func handleMention(from: AgentID, context: String, request: String) async -> String {
        status = .thinking

        await messageBus.publish(.activityLog(
            from: .librarian,
            action: "mention",
            detail: "From \(from.displayName): \(request.prefix(60))"
        ))

        let response = "Librarian acknowledges request from \(from.displayName): \(request)"
        status = .idle
        return response
    }

    func handleInsight(_ insight: String, from: AgentID) {
        Log.engine.debug("Librarian: insight from \(from.rawValue): \(insight.prefix(80))")
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        status = .idle
    }
}
