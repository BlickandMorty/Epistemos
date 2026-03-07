import Foundation
import os

// MARK: - AgentEngine

@MainActor @Observable
final class AgentEngine {

    // MARK: - State

    private(set) var agents: [AgentID: any AgentProtocol] = [:]
    private(set) var statuses: [AgentID: AgentStatus] = [:]
    private(set) var isRunning = false

    let messageBus = MessageBus()

    // MARK: - Internal

    private var listenTask: Task<Void, Never>?
    private var agentTasks: [AgentID: Task<Void, Never>] = [:]

    // MARK: - Lifecycle

    func register(_ agent: any AgentProtocol) {
        agents[agent.id] = agent
        statuses[agent.id] = .idle
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        for (id, agent) in agents {
            let stream = agentTasks[id] == nil
            if stream {
                startAgentListener(for: id, agent: agent)
            }
        }

        Log.engine.info("AgentEngine: started with \(self.agents.count) agents")
    }

    func stop() {
        isRunning = false
        for (_, task) in agentTasks {
            task.cancel()
        }
        agentTasks.removeAll()
        listenTask?.cancel()
        listenTask = nil

        for agent in agents.values {
            agent.cancel()
        }

        for id in agents.keys {
            statuses[id] = .idle
        }

        Log.engine.info("AgentEngine: stopped")
    }

    // MARK: - Message Dispatch

    func send(_ message: MessageBus.Message) async {
        await messageBus.publish(message)
    }

    func submitTask(_ task: AgentTask) async {
        await messageBus.publish(.taskAssignment(from: task.from, to: task.to, task: task))
    }

    // MARK: - Agent Listeners

    private func startAgentListener(for id: AgentID, agent: any AgentProtocol) {
        let task = Task { [weak self] in
            guard let self else { return }
            let stream = await self.messageBus.subscribe(for: id)

            for await message in stream {
                guard !Task.isCancelled else { break }
                await self.handleMessage(message, for: agent)
            }
        }
        agentTasks[id] = task
    }

    private func handleMessage(_ message: MessageBus.Message, for agent: any AgentProtocol) async {
        switch message {
        case .taskAssignment(_, _, let task):
            statuses[agent.id] = .working(task: task.instruction)
            await agent.handleTask(task)
            statuses[agent.id] = agent.status

        case .mention(let from, _, let context, let request):
            statuses[agent.id] = .thinking
            let response = await agent.handleMention(from: from, context: context, request: request)
            await messageBus.publish(.mentionResponse(from: agent.id, to: from, response: response))
            statuses[agent.id] = agent.status

        case .insight(let from, _, let content):
            agent.handleInsight(content, from: from)

        default:
            break
        }
    }

    // MARK: - Query

    func agent(for id: AgentID) -> (any AgentProtocol)? {
        agents[id]
    }

    func status(for id: AgentID) -> AgentStatus {
        statuses[id] ?? .idle
    }

    var activeAgents: [AgentID] {
        statuses.filter { $0.value.isActive }.map(\.key)
    }

    var recentActivity: [MessageBus.Message] {
        get async {
            await messageBus.recentActivity()
        }
    }
}
