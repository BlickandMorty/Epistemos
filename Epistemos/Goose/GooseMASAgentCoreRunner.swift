import Foundation

protocol GooseMASAgentCoreRunning: AnyObject, Sendable {
    nonisolated func streamGooseMASAgentCoreRun(
        sessionID: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        providerName: String,
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
    case providerNotConnectedToJune
    case cloudConsentRequired(String)

    var errorDescription: String? {
        switch self {
        case .providerNotConnectedToJune:
            return "The selected provider is not connected to MAS June. Nothing was sent."
        case .cloudConsentRequired(let provider):
            return "Cloud data consent is off for \(provider). Enable it in Settings > June Models. Nothing was sent."
        }
    }
}

nonisolated enum GooseMASAgentCoreStreamError: LocalizedError, Sendable {
    case outputBackpressure

    var errorDescription: String? {
        "June could not keep up with the bounded cloud-agent output stream. The partial answer was stopped; try again."
    }
}

nonisolated enum GooseMASAgentCoreVaultPaths {
    static let fallbackScratchPath = makeFallbackScratchPath()

    private static func makeFallbackScratchPath() -> String {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let scratch = base
            .appendingPathComponent("Epistemos/JuneAgentCore/agent-core-scratch", isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        return scratch.path
    }
}

nonisolated final class GooseMASAgentCoreRunner: GooseMASAgentCoreRunning, @unchecked Sendable {
    private static let defaultVaultPath = GooseMASAgentCoreVaultPaths.fallbackScratchPath
    private static let allowedMASTools = JuneMASToolPolicy.allowedAgentToolNames

    func streamGooseMASAgentCoreRun(
        sessionID: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        providerName: String,
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
                        Task {
                            cancelAgentSession(sessionId: sessionID)
                        }
                        return false
                    case .terminated:
                        return false
                    @unknown default:
                        continuation.finish(throwing: GooseMASAgentCoreStreamError.outputBackpressure)
                        Task {
                            cancelAgentSession(sessionId: sessionID)
                        }
                        return false
                    }
                },
                permissionHandler: permissionHandler
            )
            let normalizedVaultPath = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let toolConfig = ToolConfig(
                vaultPath: normalizedVaultPath.isEmpty ? Self.defaultVaultPath : normalizedVaultPath,
                enableBash: false,
                enableWebSearch: true,
                toolTier: "agent",
                allowedToolNames: Self.allowedMASTools
            )
            let agentConfig = AgentConfigFFI(
                maxTurns: 24,
                maxOutputTokens: UInt32(max(1, min(maxTokens, 16_384))),
                contextThreshold: 120_000,
                enableThinking: true,
                effort: "high",
                systemPrompt: systemPrompt,
                autoApproveReads: false,
                autoApproveWrites: false,
                promptMode: "general",
                maxCostUsd: nil
            )
            let task = Task {
                do {
                    #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                    guard let provider = GooseMASAgentCoreProviderSlug.juneProvider(forResolvedSlug: providerName) else {
                        throw GooseMASAgentCoreAdmissionError.providerNotConnectedToJune
                    }
                    let hasConsent = await MainActor.run {
                        AgentCloudConsentStore.shared.hasConsent(for: provider)
                    }
                    guard hasConsent else {
                        throw GooseMASAgentCoreAdmissionError.cloudConsentRequired(provider.displayName)
                    }
                    #endif
                    let result = try await AppBootstrap.withScopedAgentCoreEnvironment {
                        try await runAgentSession(
                            sessionId: sessionID,
                            objective: prompt,
                            providerName: providerName,
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
                        fallback: "MAS June agent run failed"
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

// SAFETY: the callbacks are @Sendable and immutable; the mutable state
// (didComplete, pendingPermissionRequests) is guarded by `lock` on every access.
nonisolated private final class GooseMASAgentCoreDelegate: AgentStreamEventDelegate, @unchecked Sendable {
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
        self.emitEvent = emit
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
        if shouldFinish {
            didComplete = true
        }
        lock.unlock()
        guard shouldFinish else { return }
        emit(.complete(stopReason: stopReason, inputTokens: inputTokens, outputTokens: outputTokens))
    }

    func onThinkingDelta(thought: String) {
        emit(.thinkingDelta(thought))
    }

    func onTextDelta(delta: String) {
        emit(.textDelta(delta))
    }

    func onToolInputDelta(index: UInt32, partialJson: String) {
        _ = index
        _ = partialJson
    }

    func onToolStarted(toolUseId: String, name: String, inputJson: String) {
        emit(.toolStarted(id: toolUseId, name: name, inputJson: inputJson))
    }

    func onToolCompleted(toolUseId: String, result: String, isError: Bool) {
        emit(.toolCompleted(id: toolUseId, name: "", result: result, isError: isError))
    }

    func onSubagentSpawned(agentId: String, role: String) {
        emit(.toolStarted(id: agentId, name: "subagent.\(role)", inputJson: "{}"))
    }

    func onPermissionRequired(
        permissionId: String,
        toolName: String,
        inputJson: String,
        riskLevel: String
    ) {
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

    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {
        _ = turnNumber
        _ = messageCount
    }

    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        finishIfNeeded(
            stopReason: stopReason,
            inputTokens: Int(inputTokens),
            outputTokens: Int(outputTokens)
        )
    }

    func onError(message: String) {
        emit(.error(EngineLogDiagnostics.agentCoreCallbackMessage(
            message,
            fallback: "MAS June agent run failed"
        )))
    }

    func executeComputerAction(actionJson: String) -> String {
        _ = actionJson
        return #"{"success":false,"error":"Computer-use is unavailable in MAS June."}"#
    }

    func waitForPermission(permissionId: String) -> Bool {
        lock.lock()
        let request = pendingPermissionRequests.removeValue(forKey: permissionId)
        lock.unlock()
        guard let request else { return false }
        return permissionHandler(request)
    }

    func askUserQuestion(questionJson: String) -> String {
        _ = questionJson
        return #"{"response":"","choice_index":null}"#
    }

    func perceiveApp(appName: String, depth: String) -> String {
        _ = appName
        _ = depth
        return #"{"elements":[],"screenshot_path":null,"latency_ms":0,"error":"macOS app perception is unavailable in MAS June."}"#
    }

    func interactWithApp(actionJson: String) -> String {
        _ = actionJson
        return #"{"success":false,"element_found":false,"action_performed":false,"error":"macOS app control is unavailable in MAS June."}"#
    }

    func startScreenWatch(watchJson: String) -> String {
        _ = watchJson
        return #"{"triggered":false,"reason":"Screen watch is unavailable in MAS June.","elapsed_ms":0}"#
    }

    func manageSsmState(actionJson: String) -> String {
        _ = actionJson
        return #"{"success":false,"state_size_mb":0,"layers":0,"dtype":"none","duration_ms":0,"states":[],"error":"SSM state is unavailable in MAS June."}"#
    }

    func generateConstrained(prompt: String, grammarJson: String) -> String {
        _ = prompt
        _ = grammarJson
        return #"{"output":"","tokens_generated":0,"constraint_violations_masked":0,"error":"Constrained local generation is unavailable in MAS June."}"#
    }

    func generateImage(prompt: String, aspectRatio: String) -> String {
        _ = prompt
        _ = aspectRatio
        return #"{"error":"Image generation is unavailable in MAS June."}"#
    }

    func triggerNightbrainJob(jobType: String, priority: String) -> String {
        _ = jobType
        _ = priority
        return #"{"job_id":"","status":"unavailable","estimated_duration_s":0,"error":"Background model training is unavailable in MAS June."}"#
    }

    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String {
        _ = noteId
        _ = cursorOffset
        return #"{"matches":[],"complexity":0,"suggestions":[]}"#
    }
}
