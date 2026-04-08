import Dispatch
import Foundation

#if canImport(agent_core)
import agent_core
#endif

#if !canImport(agent_core)
protocol AgentStreamEventDelegate: AnyObject, Sendable {
    func onThinkingDelta(thought: String)
    func onTextDelta(delta: String)
    func onToolInputDelta(index: UInt32, partialJson: String)
    func onToolStarted(toolUseId: String, name: String, inputJson: String)
    func onToolCompleted(toolUseId: String, result: String, isError: Bool)
    func onSubagentSpawned(agentId: String, role: String)
    func onPermissionRequired(
        permissionId: String,
        toolName: String,
        inputJson: String,
        riskLevel: String
    )
    func onContextCompacting(currentTokens: UInt32)
    func onContextCompacted(newMessageCount: UInt32)
    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32)
    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32)
    func onError(message: String)
    func waitForPermission(permissionId: String) -> Bool
}

struct ToolConfig: Sendable {
    let vaultPath: String
    let enableBash: Bool
    let enableWebSearch: Bool
}

struct AgentConfigFFI: Sendable {
    let maxTurns: UInt32
    let maxOutputTokens: UInt32
    let contextThreshold: UInt32
    let enableThinking: Bool
    let effort: String
    let systemPrompt: String?
    let autoApproveReads: Bool
    let autoApproveWrites: Bool
}

struct AgentResultFFI: Sendable {
    let turns: UInt32
    let inputTokens: UInt32
    let outputTokens: UInt32
}

enum AgentRuntimeBridgeError: Error, LocalizedError, Sendable {
    case bindingsUnavailable

    var errorDescription: String? {
        switch self {
        case .bindingsUnavailable:
            return "Cloud agent runtime is not available. Using standard pipeline."
        }
    }
}

func runAgentSession(
    sessionId: String,
    objective: String,
    providerName: String,
    toolConfig: ToolConfig,
    agentConfig: AgentConfigFFI,
    delegate: any AgentStreamEventDelegate
) async throws -> AgentResultFFI {
    throw AgentRuntimeBridgeError.bindingsUnavailable
}

func cancelAgentSession(sessionId: String) {}
#endif

// MARK: - Agent Stream Types (self-contained, no external dependencies)

enum AgentStreamEvent: Sendable {
    case thinkingDelta(String)
    case textDelta(String)
    case toolInputStreaming(index: UInt32, partialJson: String)
    case toolStarted(id: String, name: String, inputJson: String)
    case toolCompleted(id: String, result: String, isError: Bool)
    case subagentSpawned(id: String, role: String)
    case permissionRequired(AgentPermissionRequest)
    case contextCompacting(tokens: Int)
    case contextCompacted(messageCount: Int)
    case turnStarted(turn: Int, messageCount: Int)
    case complete(stopReason: String, inputTokens: Int, outputTokens: Int, history: [[String: String]]?)
    case error(AgentRuntimeError)
}

struct AgentPermissionRequest: Sendable, Identifiable {
    let id: String
    let toolName: String
    let inputJson: String
    let riskLevel: AgentRuntimeRiskLevel
    let description: String
}

enum AgentRuntimeRiskLevel: Sendable {
    case readOnly
    case modification
    case destructive

    init(rustValue: String) {
        switch rustValue.lowercased() {
        case "read", "readonly", "read_only": self = .readOnly
        case "destructive": self = .destructive
        default: self = .modification
        }
    }
}

struct AgentRuntimeError: Error, Sendable {
    let message: String
}

final class StreamingDelegate: AgentStreamEventDelegate, @unchecked Sendable {
    private let continuation: AsyncStream<AgentStreamEvent>.Continuation
    private var pendingPermissions: [String: DispatchSemaphore] = [:]
    private var permissionResults: [String: Bool] = [:]
    private let permissionLock = NSLock()
    private let permissionTimeout: TimeInterval = 120

    init(continuation: AsyncStream<AgentStreamEvent>.Continuation) {
        self.continuation = continuation
    }

    func onThinkingDelta(thought: String) {
        continuation.yield(.thinkingDelta(thought))
    }

    func onTextDelta(delta: String) {
        continuation.yield(.textDelta(delta))
    }

    func onToolInputDelta(index: UInt32, partialJson: String) {
        continuation.yield(.toolInputStreaming(index: index, partialJson: partialJson))
    }

    func onToolStarted(toolUseId: String, name: String, inputJson: String) {
        continuation.yield(.toolStarted(id: toolUseId, name: name, inputJson: inputJson))
    }

    func onToolCompleted(toolUseId: String, result: String, isError: Bool) {
        continuation.yield(.toolCompleted(id: toolUseId, result: result, isError: isError))
    }

    func onSubagentSpawned(agentId: String, role: String) {
        continuation.yield(.subagentSpawned(id: agentId, role: role))
    }

    func onPermissionRequired(
        permissionId: String,
        toolName: String,
        inputJson: String,
        riskLevel: String
    ) {
        let semaphore = DispatchSemaphore(value: 0)
        permissionLock.lock()
        pendingPermissions[permissionId] = semaphore
        permissionLock.unlock()

        let request = AgentPermissionRequest(
            id: permissionId,
            toolName: toolName,
            inputJson: inputJson,
            riskLevel: AgentRuntimeRiskLevel(rustValue: riskLevel),
            description: "Tool '\(toolName)' requires approval."
        )
        continuation.yield(.permissionRequired(request))
    }

    func onContextCompacting(currentTokens: UInt32) {
        continuation.yield(.contextCompacting(tokens: Int(currentTokens)))
    }

    func onContextCompacted(newMessageCount: UInt32) {
        continuation.yield(.contextCompacted(messageCount: Int(newMessageCount)))
    }

    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {
        continuation.yield(.turnStarted(turn: Int(turnNumber), messageCount: Int(messageCount)))
    }

    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        continuation.yield(
            .complete(
                stopReason: stopReason,
                inputTokens: Int(inputTokens),
                outputTokens: Int(outputTokens),
                history: nil
            )
        )
        continuation.finish()
    }

    func onError(message: String) {
        continuation.yield(.error(AgentRuntimeError(message: message)))
        continuation.finish()
    }

    func waitForPermission(permissionId: String) -> Bool {
        permissionLock.lock()
        guard let semaphore = pendingPermissions[permissionId] else {
            permissionLock.unlock()
            return false
        }
        permissionLock.unlock()

        let result = semaphore.wait(timeout: .now() + permissionTimeout)

        permissionLock.lock()
        defer { permissionLock.unlock() }

        if result == .timedOut {
            pendingPermissions.removeValue(forKey: permissionId)
            permissionResults.removeValue(forKey: permissionId)
            return false
        }

        let approved = permissionResults.removeValue(forKey: permissionId) ?? false
        pendingPermissions.removeValue(forKey: permissionId)
        return approved
    }

    func resolvePermission(permissionId: String, approved: Bool) {
        permissionLock.lock()
        permissionResults[permissionId] = approved
        let semaphore = pendingPermissions[permissionId]
        permissionLock.unlock()
        semaphore?.signal()
    }
}
