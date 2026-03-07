import Foundation
import os

// MARK: - MessageBus Actor

actor MessageBus {

    // MARK: - Message Type

    enum Message: Sendable {
        // Routing
        case taskAssignment(from: AgentID, to: AgentID, task: AgentTask)
        case taskComplete(from: AgentID, result: AgentResult)

        // Agent-to-agent
        case mention(from: AgentID, to: AgentID, context: String, request: String)
        case mentionResponse(from: AgentID, to: AgentID, response: String)

        // Proactive
        case insight(from: AgentID, relevantTo: AgentID?, content: String)
        case indexRequest(from: AgentID, content: IndexableContent)

        // UI
        case statusUpdate(from: AgentID, status: AgentStatus)
        case notification(from: AgentID, message: String, speak: Bool)
        case activityLog(from: AgentID, action: String, detail: String)

        // Learning Pool
        case searchRequest(from: AgentID, query: SearchQuery)
        case searchResult(to: AgentID, results: [SearchChunk])

        nonisolated var sender: AgentID {
            switch self {
            case .taskAssignment(let from, _, _): from
            case .taskComplete(let from, _): from
            case .mention(let from, _, _, _): from
            case .mentionResponse(let from, _, _): from
            case .insight(let from, _, _): from
            case .indexRequest(let from, _): from
            case .statusUpdate(let from, _): from
            case .notification(let from, _, _): from
            case .activityLog(let from, _, _): from
            case .searchRequest(let from, _): from
            case .searchResult: .triage
            }
        }

        nonisolated var targetAgent: AgentID? {
            switch self {
            case .taskAssignment(_, let to, _): to
            case .mention(_, let to, _, _): to
            case .mentionResponse(_, let to, _): to
            case .insight(_, let relevantTo, _): relevantTo
            case .searchResult(let to, _): to
            default: nil
            }
        }
    }

    // MARK: - Subscriber Key

    private enum SubscriberKey: Hashable {
        case agent(AgentID)
        case ui(UUID)
    }

    // MARK: - State

    private var subscribers: [SubscriberKey: AsyncStream<Message>.Continuation] = [:]
    private var activityBuffer: [Message] = []
    private let maxActivityBuffer = 100

    // MARK: - Subscribe

    func subscribe(for agent: AgentID) -> AsyncStream<Message> {
        let key = SubscriberKey.agent(agent)
        // Cancel existing subscription for this agent
        subscribers[key]?.finish()

        return AsyncStream { continuation in
            subscribers[key] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(key) }
            }
        }
    }

    func subscribeAll() -> AsyncStream<Message> {
        let key = SubscriberKey.ui(UUID())

        return AsyncStream { continuation in
            subscribers[key] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(key) }
            }
        }
    }

    private func removeSubscriber(_ key: SubscriberKey) {
        subscribers.removeValue(forKey: key)
    }

    // MARK: - Publish

    func publish(_ message: Message) {
        // Add to activity log
        activityBuffer.append(message)
        if activityBuffer.count > maxActivityBuffer {
            activityBuffer.removeFirst(activityBuffer.count - maxActivityBuffer)
        }

        // Fan out to subscribers
        for (key, continuation) in subscribers {
            switch key {
            case .agent(let agentId):
                // Agent only receives messages targeted to it, or broadcasts
                if message.targetAgent == agentId || message.targetAgent == nil {
                    continuation.yield(message)
                }
            case .ui:
                // UI receives everything
                continuation.yield(message)
            }
        }

        Log.engine.debug("MessageBus: \(message.sender.rawValue) → \(message.targetAgent?.rawValue ?? "broadcast")")
    }

    // MARK: - Activity Log

    func recentActivity() -> [Message] {
        activityBuffer
    }

    func recentActivity(for agent: AgentID) -> [Message] {
        activityBuffer.filter { $0.sender == agent || $0.targetAgent == agent }
    }

    func clearActivity() {
        activityBuffer.removeAll()
    }
}
