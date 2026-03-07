import Foundation
import os

// MARK: - WriterAgent

@MainActor
final class WriterAgent: AgentProtocol {
    let id: AgentID = .writer
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
            from: .writer,
            action: "task_start",
            detail: task.instruction
        ))

        // Full implementation (preset system, chain-of-thought parsing, note editor integration)
        // comes in Phase 4. For now, acknowledge and complete.
        let output = "Writer received task: \(task.instruction)"

        await messageBus.publish(.taskComplete(
            from: .writer,
            result: AgentResult(taskId: task.id, from: .writer, output: output)
        ))

        status = .idle
    }

    func handleMention(from: AgentID, context: String, request: String) async -> String {
        status = .thinking

        await messageBus.publish(.activityLog(
            from: .writer,
            action: "mention",
            detail: "From \(from.displayName): \(request.prefix(60))"
        ))

        let response = "Writer acknowledges request from \(from.displayName): \(request)"
        status = .idle
        return response
    }

    func handleInsight(_ insight: String, from: AgentID) {
        Log.engine.debug("Writer: insight from \(from.rawValue): \(insight.prefix(80))")
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        status = .idle
    }
}
