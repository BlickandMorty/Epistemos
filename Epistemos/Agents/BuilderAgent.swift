import Foundation
import os

// MARK: - BuilderAgent

@MainActor
final class BuilderAgent: AgentProtocol {
    let id: AgentID = .builder
    private(set) var status: AgentStatus = .idle
    var trustLevel: TrustLevel = .sandbox

    private let messageBus: MessageBus
    private var currentTask: Task<Void, Never>?

    init(messageBus: MessageBus) {
        self.messageBus = messageBus
    }

    // MARK: - AgentProtocol

    func handleTask(_ task: AgentTask) async {
        status = .working(task: task.instruction.prefix(40) + "…")

        await messageBus.publish(.activityLog(
            from: .builder,
            action: "task_start",
            detail: task.instruction
        ))

        // Full implementation (code editor, terminal, file tree, ReACT loop, trust enforcement)
        // comes in Phase 5. For now, acknowledge and complete.
        let output = "Builder received task: \(task.instruction)"

        await messageBus.publish(.taskComplete(
            from: .builder,
            result: AgentResult(taskId: task.id, from: .builder, output: output)
        ))

        status = .idle
    }

    func handleMention(from: AgentID, context: String, request: String) async -> String {
        status = .thinking

        await messageBus.publish(.activityLog(
            from: .builder,
            action: "mention",
            detail: "From \(from.displayName): \(request.prefix(60))"
        ))

        let response = "Builder acknowledges request from \(from.displayName): \(request)"
        status = .idle
        return response
    }

    func handleInsight(_ insight: String, from: AgentID) {
        Log.engine.debug("Builder: insight from \(from.rawValue): \(insight.prefix(80))")
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        status = .idle
    }
}
