#if EPISTEMOS_BASE_JUNE
import Foundation

#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

protocol GooseMASAgentCoreRunning: AnyObject, Sendable {
    nonisolated func streamGooseMASAgentCoreRun(
        sessionID: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: JuneCloudModel,
        vaultPath: String,
        permissionHandler: @escaping @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    ) -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error>
}

nonisolated struct GooseMASAgentCorePermissionRequest: Sendable, Equatable {
    let id: String
    let toolName: String
    let inputJson: String
    let riskLevel: String
}

nonisolated enum GooseMASAgentCoreRunEvent: Sendable, Equatable {
    case textDelta(String)
    case thinkingDelta(String)
    case toolStarted(id: String, name: String, inputJson: String)
    case toolCompleted(id: String, name: String, result: String, isError: Bool)
    case permissionRequired(id: String, toolName: String, inputJson: String, riskLevel: String)
    case complete(stopReason: String, inputTokens: Int, outputTokens: Int)
    case error(String)
}

nonisolated enum GooseMASAgentCoreAdmissionError: LocalizedError, Sendable {
    case cloudConsentRequired(String)

    var errorDescription: String? {
        switch self {
        case .cloudConsentRequired(let provider):
            "Cloud data consent is off for \(provider). Enable it in June Settings. Nothing was sent."
        }
    }
}

nonisolated enum GooseMASAgentCoreStreamError: LocalizedError, Sendable {
    case outputBackpressure

    var errorDescription: String? {
        "June could not keep up with the bounded cloud-agent output stream. The partial answer was stopped; try again."
    }
}

nonisolated final class GooseMASAgentCoreRunner: GooseMASAgentCoreRunning, @unchecked Sendable {
    private static let allowedTools = JuneMASToolPolicy.allowedAgentToolNames

    func streamGooseMASAgentCoreRun(
        sessionID: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        model: JuneCloudModel,
        vaultPath: String,
        permissionHandler: @escaping @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    ) -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let delegate = GooseMASAgentCoreDelegate(
                emit: { event in
                    switch continuation.yield(event) {
                    case .enqueued:
                        return true
                    case .dropped:
                        continuation.finish(throwing: GooseMASAgentCoreStreamError.outputBackpressure)
                        cancelAgentSession(sessionId: sessionID)
                        return false
                    case .terminated:
                        return false
                    @unknown default:
                        continuation.finish(throwing: GooseMASAgentCoreStreamError.outputBackpressure)
                        cancelAgentSession(sessionId: sessionID)
                        return false
                    }
                },
                permissionHandler: permissionHandler
            )
            let toolConfig = ToolConfig(
                vaultPath: vaultPath,
                enableBash: false,
                enableWebSearch: true,
                toolTier: "agent",
                allowedToolNames: Self.allowedTools
            )
            let agentConfig = AgentConfigFfi(
                maxTurns: 24,
                maxOutputTokens: UInt32(max(1, min(maxTokens, 16_384))),
                contextThreshold: 120_000,
                enableThinking: model.supportsReasoning,
                effort: "high",
                systemPrompt: systemPrompt,
                autoApproveReads: false,
                autoApproveWrites: false,
                promptMode: "general",
                maxCostUsd: nil
            )
            let task = Task {
                do {
                    let hasConsent = await MainActor.run {
                        JuneCloudConfigurationStore.shared.hasConsent(model.provider)
                    }
                    guard hasConsent else {
                        throw GooseMASAgentCoreAdmissionError.cloudConsentRequired(model.provider.displayName)
                    }
                    let result = try await JuneAgentCoreEnvironment.withCredential(for: model.provider) {
                        try await runAgentSession(
                            sessionId: sessionID,
                            objective: prompt,
                            providerName: model.agentCoreSlug,
                            toolConfig: toolConfig,
                            agentConfig: agentConfig,
                            delegate: delegate
                        )
                    }
                    delegate.finishIfNeeded(
                        stopReason: "end_turn",
                        inputTokens: Int(result.inputTokens),
                        outputTokens: Int(result.outputTokens)
                    )
                    continuation.finish()
                } catch {
                    delegate.emit(.error(EngineLogDiagnostics.logMessage(
                        for: error,
                        fallback: "June's in-process Goose run failed"
                    )))
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                cancelAgentSession(sessionId: sessionID)
            }
        }
    }
}

// SAFETY: callback state is guarded by `lock`; all unavailable non-MAS,
// computer-use, and sidecar callbacks fail closed.
nonisolated private final class GooseMASAgentCoreDelegate: AgentEventDelegate, @unchecked Sendable {
    private let emitEvent: @Sendable (GooseMASAgentCoreRunEvent) -> Bool
    private let permissionHandler: @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    private let lock = NSLock()
    private var didComplete = false
    private var streamTerminated = false
    private var pendingPermissionRequests: [String: GooseMASAgentCorePermissionRequest] = [:]

    init(
        emit: @escaping @Sendable (GooseMASAgentCoreRunEvent) -> Bool,
        permissionHandler: @escaping @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    ) {
        emitEvent = emit
        self.permissionHandler = permissionHandler
    }

    @discardableResult
    func emit(_ event: GooseMASAgentCoreRunEvent) -> Bool {
        lock.lock()
        let canEmit = !streamTerminated
        lock.unlock()
        guard canEmit else { return false }
        let accepted = emitEvent(event)
        if !accepted {
            lock.lock()
            streamTerminated = true
            didComplete = true
            pendingPermissionRequests.removeAll(keepingCapacity: false)
            lock.unlock()
        }
        return accepted
    }

    func finishIfNeeded(stopReason: String, inputTokens: Int, outputTokens: Int) {
        lock.lock()
        let shouldFinish = !didComplete && !streamTerminated
        if shouldFinish { didComplete = true }
        lock.unlock()
        guard shouldFinish else { return }
        emit(.complete(stopReason: stopReason, inputTokens: inputTokens, outputTokens: outputTokens))
    }

    func onThinkingDelta(thought: String) { emit(.thinkingDelta(thought)) }
    func onTextDelta(delta: String) { emit(.textDelta(delta)) }
    func onToolInputDelta(index: UInt32, partialJson: String) { _ = (index, partialJson) }
    func onToolStarted(toolUseId: String, name: String, inputJson: String) {
        emit(.toolStarted(id: toolUseId, name: name, inputJson: inputJson))
    }
    func onToolCompleted(toolUseId: String, result: String, isError: Bool) {
        emit(.toolCompleted(id: toolUseId, name: "", result: result, isError: isError))
    }
    func onSubagentSpawned(agentId: String, role: String) {
        emit(.toolStarted(id: agentId, name: "subagent.\(role)", inputJson: "{}"))
    }
    func onPermissionRequired(permissionId: String, toolName: String, inputJson: String, riskLevel: String) {
        let request = GooseMASAgentCorePermissionRequest(
            id: permissionId,
            toolName: toolName,
            inputJson: inputJson,
            riskLevel: riskLevel
        )
        lock.lock()
        pendingPermissionRequests[permissionId] = request
        lock.unlock()
        emit(.permissionRequired(id: permissionId, toolName: toolName, inputJson: inputJson, riskLevel: riskLevel))
    }
    func onContextCompacting(currentTokens: UInt32) {
        emit(.thinkingDelta("Compacting context at \(currentTokens) tokens."))
    }
    func onContextCompacted(newMessageCount: UInt32) {
        emit(.thinkingDelta("Context compacted to \(newMessageCount) messages."))
    }
    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) { _ = (turnNumber, messageCount) }
    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        finishIfNeeded(stopReason: stopReason, inputTokens: Int(inputTokens), outputTokens: Int(outputTokens))
    }
    func onError(message: String) {
        let detail = message.trimmingCharacters(in: .whitespacesAndNewlines)
        emit(.error(detail.isEmpty ? "June's in-process Goose run failed" : detail))
    }
    func waitForPermission(permissionId: String) -> Bool {
        lock.lock()
        let request = pendingPermissionRequests.removeValue(forKey: permissionId)
        lock.unlock()
        return request.map(permissionHandler) ?? false
    }

    func executeComputerAction(actionJson: String) -> String { Self.unavailable("computer-use") }
    func askUserQuestion(questionJson: String) -> String { #"{"response":"","choice_index":null}"# }
    func perceiveApp(appName: String, depth: String) -> String { Self.unavailable("app perception") }
    func interactWithApp(actionJson: String) -> String { Self.unavailable("app control") }
    func startScreenWatch(watchJson: String) -> String { Self.unavailable("screen watch") }
    func manageSsmState(actionJson: String) -> String { Self.unavailable("SSM state") }
    func generateConstrained(prompt: String, grammarJson: String) -> String { Self.unavailable("constrained generation") }
    func generateImage(prompt: String, aspectRatio: String) -> String { Self.unavailable("image generation") }
    func triggerNightbrainJob(jobType: String, priority: String) -> String { Self.unavailable("NightBrain") }
    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String { Self.unavailable("partner context") }

    private static func unavailable(_ capability: String) -> String {
        "{\"success\":false,\"error\":\"\(capability) is unavailable in June.\"}"
    }
}
#endif
