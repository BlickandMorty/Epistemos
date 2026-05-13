import Foundation

/// Minimal message shape the AgentQueryEngine owns across turns. Kept internal to
/// the harness so the engine doesn't leak UI / SwiftData concerns — the
/// bridge layer (AgentQueryEngineCoordinator) converts between this and the
/// surface-level SDMessage / ChatState.
nonisolated struct QueryMessage: Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
        case toolResult = "tool_result"
    }

    let role: Role
    let content: String
    let toolCallID: String?

    init(role: Role, content: String, toolCallID: String? = nil) {
        self.role = role
        self.content = content
        self.toolCallID = toolCallID
    }
}

/// Emitted on the AgentQueryEngine turn stream. Richer than AgentBackendEvent
/// because AgentQueryEngine owns session state (usage totals, turn number)
/// that the raw backend stream doesn't know about.
///
/// Per RCA13 P2-006: the prior shape declared `permissionRequest` and
/// `permissionDenied` cases that the engine never actually yielded. UI
/// consumers that pattern-matched on them would silently fail closed
/// (the match never fired even when a tool call was denied). The
/// canonical approval surface is `AgentPermissionRequest` driven through
/// ChatCoordinator + PipelineService — those paths are real. The
/// engine-stream cases are removed here so the contract is honest:
/// only emit events the engine actually fires.
nonisolated enum AgentQueryEngineEvent: Sendable {
    case textDelta(String)
    case thinkingDelta(String)
    case toolStarted(id: String, name: String)
    case toolCompleted(id: String, output: String, isError: Bool)
    case usageUpdate(UsageLedger)
    case turnComplete(turnIndex: Int)
    case sessionComplete(result: AgentQueryEngineResult)
}

/// Five-way multi-exit result matching OpenClaude's shape so result-time
/// analytics can classify why a session stopped without string-matching.
nonisolated enum AgentQueryEngineResult: Sendable {
    case success(usage: UsageLedger, turns: Int)
    case errorMaxTurns(usage: UsageLedger, turns: Int)
    case errorMaxBudgetUSD(usage: UsageLedger, turns: Int)
    case errorMaxRetries(usage: UsageLedger, turns: Int, detail: String)
    case errorDuringExecution(usage: UsageLedger, turns: Int, detail: String)

    var usage: UsageLedger {
        switch self {
        case .success(let u, _),
             .errorMaxTurns(let u, _),
             .errorMaxBudgetUSD(let u, _),
             .errorMaxRetries(let u, _, _),
             .errorDuringExecution(let u, _, _):
            return u
        }
    }

    var turns: Int {
        switch self {
        case .success(_, let t),
             .errorMaxTurns(_, let t),
             .errorMaxBudgetUSD(_, let t),
             .errorMaxRetries(_, let t, _),
             .errorDuringExecution(_, let t, _):
            return t
        }
    }
}

/// A denied tool call the wrapped canUseTool closure recorded during the
/// turn. Kept on the engine so result-time telemetry can show the full
/// audit trail ("the agent tried to curl | sh but the system-protected
/// policy stopped it").
nonisolated struct AgentQueryEnginePermissionDenial: Codable, Sendable, Equatable {
    let toolID: String
    let toolName: String
    let reason: String
    let timestamp: Date
}

/// Pluggable history compactor. Matches OpenClaude's `snipReplay` injection
/// pattern — the engine calls this when the store crosses a configurable
/// threshold, and the returned replay is swapped in before the next turn.
/// Kept injectable so the compaction module can stay feature-flagged out of
/// the core engine file without leaking any feature-gated strings.
nonisolated protocol AgentQueryEngineCompactor: Sendable {
    func compact(store: [QueryMessage]) async throws -> [QueryMessage]?
}

nonisolated struct AgentQueryEngineConfig: Sendable {
    let backendIdentifier: String
    let systemPrompt: String?
    let maxTurns: Int?
    let maxBudgetUSD: Double?
    let cwd: String
    let model: String?
    let compactor: (any AgentQueryEngineCompactor)?
    let agentProvenanceRecorder: AgentToolProvenanceRecorder?

    init(
        backendIdentifier: String,
        systemPrompt: String? = nil,
        maxTurns: Int? = 32,
        maxBudgetUSD: Double? = nil,
        cwd: String,
        model: String? = nil,
        compactor: (any AgentQueryEngineCompactor)? = nil,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil
    ) {
        self.backendIdentifier = backendIdentifier
        self.systemPrompt = systemPrompt
        self.maxTurns = maxTurns
        self.maxBudgetUSD = maxBudgetUSD
        self.cwd = cwd
        self.model = model
        self.compactor = compactor
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }
}

/// Stateful session actor ported from OpenClaude's AgentQueryEngine.ts. One
/// instance per conversation; each `submitMessage` is a turn within that
/// same instance. State persists across turns: mutable message store,
/// accumulated usage ledger, permission-denial audit trail.
actor AgentQueryEngine {
    private let config: AgentQueryEngineConfig
    private var mutableMessages: [QueryMessage]
    private var usage: UsageLedger
    private(set) var permissionDenials: [AgentQueryEnginePermissionDenial]
    private var turnCount: Int

    init(
        config: AgentQueryEngineConfig,
        initialMessages: [QueryMessage] = []
    ) {
        self.config = config
        self.mutableMessages = initialMessages
        self.usage = .empty
        self.permissionDenials = []
        self.turnCount = 0
    }

    var messageCount: Int { mutableMessages.count }
    var totalCostUSD: Double { usage.totalCostUSD }

    /// Submit a user prompt and stream incremental events. The stream ends
    /// with exactly one `.sessionComplete(result:)` event.
    func submitMessage(_ prompt: String) -> AsyncThrowingStream<AgentQueryEngineEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.runTurn(prompt: prompt, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func runTurn(
        prompt: String,
        continuation: AsyncThrowingStream<AgentQueryEngineEvent, Error>.Continuation
    ) async throws {
        mutableMessages.append(QueryMessage(role: .user, content: prompt))

        turnCount += 1

        if let maxTurns = config.maxTurns, turnCount > maxTurns {
            continuation.yield(.sessionComplete(result: .errorMaxTurns(usage: usage, turns: turnCount)))
            return
        }

        if let budgetCap = config.maxBudgetUSD, usage.totalCostUSD >= budgetCap {
            continuation.yield(.sessionComplete(result: .errorMaxBudgetUSD(usage: usage, turns: turnCount)))
            return
        }

        if let compactor = config.compactor,
           let replay = try await compactor.compact(store: mutableMessages) {
            mutableMessages = replay
        }

        let backend = await MainActor.run { BackendRegistry.shared.resolve(config.backendIdentifier) }
        guard let backend else {
            continuation.yield(.sessionComplete(
                result: .errorDuringExecution(
                    usage: usage,
                    turns: turnCount,
                    detail: "backend \(config.backendIdentifier) not registered"
                )
            ))
            return
        }

        let options = AgentExecOptions(
            cwd: config.cwd,
            model: config.model,
            systemPrompt: config.systemPrompt,
            maxTurns: config.maxTurns
        )

        // RCA-P2-007 closure 2026-05-13: preserve role + tool_call_id
        // through the [String] history boundary by emitting each
        // QueryMessage as a `role:[ tool_call_id]:` prefixed line.
        // The AgentBackend contract is still string-typed (deferred
        // bump to `[QueryMessage]` would touch every concrete backend
        // that ever lands), but the prefixed encoding round-trips the
        // info so any future backend can reconstruct the structured
        // shape without losing roles or tool-call identifiers on
        // multi-turn continuations.
        let history = mutableMessages.map(Self.encodeHistoryLine)
        let stream = try await backend.execute(
            prompt: prompt,
            history: history,
            options: options
        )

        var assistantBuffer = ""
        var stopReason: String?
        var toolStartedAtByID: [String: Date] = [:]
        var toolNameByID: [String: String] = [:]
        let runID = "agent-query-engine-\(UUID().uuidString)"
        let actor = AgentProvenanceActor.agent(id: "agent-query-engine", modelID: config.model)
        let metadata = agentQueryEngineToolMetadata(turnIndex: turnCount)

        for try await event in stream {
            switch event {
            case .text(let delta):
                assistantBuffer.append(delta)
                continuation.yield(.textDelta(delta))

            case .thinking(let delta):
                continuation.yield(.thinkingDelta(delta))

            case .toolUse(let id, let name, _):
                toolNameByID[id] = name
                let argumentsJSON = agentQueryEngineToolArgumentsJSON(
                    toolName: name,
                    turnIndex: turnCount
                )
                await recordAgentQueryEngineToolEvent(
                    runID: runID,
                    kind: .toolCallRequested,
                    actor: actor,
                    toolCallID: id,
                    toolName: name,
                    argumentsJSON: argumentsJSON,
                    status: .requested,
                    metadata: metadata
                )
                toolStartedAtByID[id] = Date()
                await recordAgentQueryEngineToolEvent(
                    runID: runID,
                    kind: .toolCallStarted,
                    actor: actor,
                    toolCallID: id,
                    toolName: name,
                    argumentsJSON: argumentsJSON,
                    status: .started,
                    metadata: metadata
                )
                continuation.yield(.toolStarted(id: id, name: name))

            case .toolResult(let id, let output, let isError):
                let startedAt = toolStartedAtByID[id] ?? Date()
                let toolName = toolNameByID[id] ?? "backend_tool"
                let sanitizedResultJSON = agentQueryEngineToolResultJSON(
                    output: output,
                    isError: isError
                )
                await recordAgentQueryEngineToolEvent(
                    runID: runID,
                    kind: isError ? .toolCallFailed : .toolCallCompleted,
                    actor: actor,
                    toolCallID: id,
                    toolName: toolName,
                    argumentsJSON: agentQueryEngineToolArgumentsJSON(
                        toolName: toolName,
                        turnIndex: turnCount
                    ),
                    resultJSON: sanitizedResultJSON,
                    durationMs: agentQueryEngineDurationMilliseconds(since: startedAt),
                    status: isError ? .failed : .completed,
                    errorMessage: isError ? "tool_result_error" : nil,
                    metadata: metadata
                )
                continuation.yield(.toolCompleted(id: id, output: output, isError: isError))

            case .usage(let model, let usageTokens):
                usage.add(model: model, usage: usageTokens)
                continuation.yield(.usageUpdate(usage))

            case .status, .log:
                break

            case .error(let message):
                continuation.yield(.sessionComplete(
                    result: .errorDuringExecution(usage: usage, turns: turnCount, detail: message)
                ))
                return

            case .complete(_, let reason):
                stopReason = reason
            }
        }

        if !assistantBuffer.isEmpty {
            mutableMessages.append(QueryMessage(role: .assistant, content: assistantBuffer))
        }

        continuation.yield(.turnComplete(turnIndex: turnCount))

        _ = stopReason
        continuation.yield(.sessionComplete(result: .success(usage: usage, turns: turnCount)))
    }

    func recordPermissionDenial(
        toolID: String,
        toolName: String,
        reason: String,
        at timestamp: Date = Date()
    ) {
        permissionDenials.append(AgentQueryEnginePermissionDenial(
            toolID: toolID,
            toolName: toolName,
            reason: reason,
            timestamp: timestamp
        ))
    }

    /// Exposes the current mutable-message store for the bridge layer.
    /// Kept read-only at the caller side — external code must not mutate the
    /// store directly; it goes through submitMessage.
    func currentMessages() -> [QueryMessage] {
        mutableMessages
    }

    /// Encode a `QueryMessage` into a single-line role-prefixed string
    /// suitable for the `AgentBackend.execute(history:)` boundary
    /// (RCA-P2-007 closure 2026-05-13). Format:
    ///   `<role>: <content>`                                  — user / assistant / system
    ///   `<role>:[tool_call_id=<id>] <content>`               — tool_result with id
    ///
    /// The chosen syntax is hand-decodable by any future backend that
    /// wants to reconstruct the structured `QueryMessage` shape
    /// without bumping the protocol contract. Roles map to the
    /// `Role.rawValue` (which already mirrors the wire format used by
    /// Claude / OpenAI compatible APIs).
    nonisolated static func encodeHistoryLine(_ message: QueryMessage) -> String {
        let role = message.role.rawValue
        if let toolCallID = message.toolCallID, !toolCallID.isEmpty {
            return "\(role):[tool_call_id=\(toolCallID)] \(message.content)"
        }
        return "\(role): \(message.content)"
    }

    private func recordAgentQueryEngineToolEvent(
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        toolName: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) async {
        guard let recorder = config.agentProvenanceRecorder else { return }
        // Discard the MainActor.run return value explicitly — the
        // closure's last expression is `recordToolEvent(...)` which
        // returns Void; the warning fires because Swift 6's strict-
        // concurrency wraps the result and complains it's unused.
        // Codex 2026-05-05 audit flagged this as a build warning.
        _ = await MainActor.run {
            recorder.recordToolEvent(
                runID: runID,
                traceID: nil,
                kind: kind,
                actor: actor,
                toolCallID: toolCallID,
                toolName: toolName,
                argumentsJSON: argumentsJSON,
                resultJSON: resultJSON,
                durationMs: durationMs,
                status: status,
                errorMessage: errorMessage,
                metadata: metadata
            )
        }
    }

    private func agentQueryEngineToolMetadata(turnIndex: Int) -> [String: String] {
        [
            "source": "agent_query_engine",
            "surface": "agent_harness",
            "backend": config.backendIdentifier,
            "model": config.model ?? "unspecified",
            "turn_index": String(turnIndex),
        ]
    }

    private func agentQueryEngineToolArgumentsJSON(
        toolName: String,
        turnIndex: Int
    ) -> String {
        agentQueryEngineJSONPayload([
            "backend": config.backendIdentifier,
            "model": config.model ?? "unspecified",
            "tool_name": toolName,
            "turn_index": String(turnIndex),
        ])
    }

    private func agentQueryEngineToolResultJSON(output: String, isError: Bool) -> String {
        agentQueryEngineJSONPayload([
            "is_error": String(isError),
            "output_byte_count": String(Data(output.utf8).count),
        ])
    }

    private func agentQueryEngineDurationMilliseconds(since startedAt: Date) -> UInt64 {
        let milliseconds = Date().timeIntervalSince(startedAt) * 1_000
        guard milliseconds.isFinite, milliseconds > 0 else { return 0 }
        guard milliseconds < Double(UInt64.max) else { return UInt64.max }
        return UInt64(milliseconds.rounded())
    }

    private func agentQueryEngineJSONPayload(_ values: [String: String]) -> String {
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

}
