import Dispatch
import Foundation

#if canImport(agent_coreFFI)
typealias AgentStreamEventDelegate = AgentEventDelegate
typealias AgentConfigFFI = AgentConfigFfi
typealias AgentResultFFI = AgentResultFfi
typealias ReasoningTrajectoryMetricsFFI = ReasoningTrajectoryMetricsFfi
#endif

#if !canImport(agent_coreFFI)
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
    func executeComputerAction(actionJson: String) -> String
    func waitForPermission(permissionId: String) -> Bool
    func askUserQuestion(questionJson: String) -> String
    func perceiveApp(appName: String, depth: String) -> String
    func interactWithApp(actionJson: String) -> String
    func startScreenWatch(watchJson: String) -> String
    func manageSsmState(actionJson: String) -> String
    func generateConstrained(prompt: String, grammarJson: String) -> String
    func generateImage(prompt: String, aspectRatio: String) -> String
    func triggerNightbrainJob(jobType: String, priority: String) -> String
    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String
}

struct ToolConfig: Sendable {
    let vaultPath: String
    let enableBash: Bool
    let enableWebSearch: Bool
    /// Tool tier: "none" | "chat_lite" | "chat_pro" | "agent" | "full".
    /// nil is treated as "agent" by the Rust side.
    let toolTier: String?
    /// Explicit per-tool allowlist. When non-nil, the Rust tool registry will
    /// ONLY surface / execute tools whose names are in this list (intersected
    /// with the tier). nil means tier is the only gate — backward compatible
    /// with callers that don't know about per-tool toggles. Phase 5 authority:
    /// populated by CommandCenterRequestCompiler from the ACC toggle state.
    let allowedToolNames: [String]?
}

struct ToolSchemaFFI: Sendable {
    let name: String
    let description: String
    let parametersJson: String
    let riskLevel: String
    let tier: String
}

struct ToolExecutionResultFFI: Sendable {
    let success: Bool
    let outputJson: String
    let error: String?
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
    /// Explicit mode: "code", "research", "general", or nil for auto-detect.
    let promptMode: String?
}

struct ReasoningTrajectoryMetricsFFI: Sendable {
    let displacement: Double
    let pathLength: Double
    let curvatureRatio: Double
    let loopCount: UInt32
    let errorCount: UInt32
    let totalCalls: UInt32
    let efficiency: Double
    let classification: String
}

struct AgentResultFFI: Sendable {
    let turns: UInt32
    let inputTokens: UInt32
    let outputTokens: UInt32
    let trajectoryMetrics: ReasoningTrajectoryMetricsFFI
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

func listToolsForTier(vaultPath: String, tier: String) throws -> [ToolSchemaFFI] {
    throw AgentRuntimeBridgeError.bindingsUnavailable
}

func executeToolCall(
    vaultPath: String,
    tier: String,
    toolName: String,
    inputJson: String
) async throws -> ToolExecutionResultFFI {
    throw AgentRuntimeBridgeError.bindingsUnavailable
}
#endif

// MARK: - Agent Stream Types (self-contained, no external dependencies)

nonisolated enum AgentStreamEvent: Sendable {
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

nonisolated struct AgentPermissionRequest: Sendable, Identifiable {
    let id: String
    let toolName: String
    let inputJson: String
    let riskLevel: AgentRuntimeRiskLevel
    let description: String
}

nonisolated enum AgentPermissionCategory: Sendable, Equatable {
    case genericRead
    case localDataRead
    case localDataWrite
    case modification
    case destructive

    nonisolated var approvalReason: String {
        switch self {
        case .genericRead:
            return "a read-only external action"
        case .localDataRead:
            return "a sensitive read of local vault or workspace data"
        case .localDataWrite:
            return "a write to local vault or workspace data"
        case .modification:
            return "a modification action"
        case .destructive:
            return "a destructive action"
        }
    }
}

extension AgentPermissionRequest {
    nonisolated private static let localDataReadTools: Set<String> = [
        "vault_read",
        "vault_search",
        "vault_recall",
        "vault_navigate",
        "session_search",
        "neural_recall",
        "contradiction_check",
        "read_file",
        "search_files",
        "workspace_search",
        "find_symbol",
        "get_function_source",
        "get_dependencies",
        "get_dependents",
        "get_change_impact",
        "graph_query",
        "pkm_get",
        "pkm_search",
        "pkm_list_entity",
        "pkm_graph_neighbors",
    ]

    nonisolated private static let localDataWriteTools: Set<String> = [
        "vault_write",
        "write_file",
        "patch_file",
        "pkm_write",
    ]

    nonisolated var permissionCategory: AgentPermissionCategory {
        if riskLevel == .destructive {
            return .destructive
        }

        let normalizedToolName = toolName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if Self.localDataReadTools.contains(normalizedToolName) {
            return .localDataRead
        }
        if Self.localDataWriteTools.contains(normalizedToolName) {
            return .localDataWrite
        }
        if normalizedToolName == "file_ops" {
            switch normalizedFileOpsAction {
            case "read", "list", "search":
                return .localDataRead
            case "write", "patch", "delete", "move":
                return .localDataWrite
            default:
                break
            }
        }

        if riskLevel == .readOnly {
            return .genericRead
        }
        return .modification
    }

    nonisolated var requiresHumanApproval: Bool {
        permissionCategory != .genericRead
    }

    nonisolated var approvalReason: String {
        permissionCategory.approvalReason
    }

    nonisolated var approvalTargetSummary: String? {
        let object = jsonObject
        return [
            object?["path"] as? String,
            object?["query"] as? String,
            object?["url"] as? String,
            object?["command"] as? String,
            object?["symbol"] as? String,
            object?["note_id"] as? String,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    nonisolated private var normalizedFileOpsAction: String? {
        guard toolName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "file_ops",
              let action = jsonObject?["action"] as? String else {
            return nil
        }
        return action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated private var jsonObject: [String: Any]? {
        guard let data = inputJson.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return value
    }
}

nonisolated enum AgentRuntimeRiskLevel: Sendable {
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

nonisolated struct AgentRuntimeError: Error, Sendable {
    let message: String
}

nonisolated private final class LockedStringBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String

    init(_ value: String) {
        self.value = value
    }

    func set(_ newValue: String) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func get() -> String {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

nonisolated final class StreamingDelegate: AgentStreamEventDelegate, @unchecked Sendable {
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

    func executeComputerAction(actionJson: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox(
            "{\"success\":false,\"error\":\"Timed out waiting for native computer action.\"}"
        )

        Task { @MainActor in
            let executed = await ComputerUseBridge.shared.execute(actionJSON: actionJson)
            result.set(executed)
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + permissionTimeout)
        guard waitResult != .timedOut else {
            return result.get()
        }

        return result.get()
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

    /// Phase 1 `clarify` tool callback. Forwards the agent's question to the
    /// Swift UI layer and blocks until the user answers. The agent's
    /// `question_json` shape is `{ "question": String, "choices"?: [String] }`
    /// and we must return `{ "response": String, "choice_index": Int? }`.
    ///
    /// The UI surface is implemented as a synchronous `NSAlert` shown on the
    /// key window — same pattern as `promptForToolApproval` in
    /// `ChatCoordinator`. The Rust side blocks on a `DispatchSemaphore` until
    /// the alert is dismissed. If no key window exists (e.g. teach mode),
    /// the alert falls back to `runModal()`.
    func askUserQuestion(questionJson: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"response\":\"\",\"choice_index\":null}")

        Task { @MainActor in
            let answer = await ClarifyPromptBridge.shared.ask(questionJson: questionJson)
            result.set(answer)
            semaphore.signal()
        }

        // Reuse the permission timeout — the agent should not block forever
        // waiting for a user who isn't watching the screen.
        let waitResult = semaphore.wait(timeout: .now() + permissionTimeout)
        if waitResult == .timedOut {
            return "{\"response\":\"\",\"choice_index\":null,\"timeout\":true}"
        }
        return result.get()
    }

    /// Phase 4 Specialty A1: perceive a macOS app via AX+Vision+VLM fusion.
    /// Routes through `Screen2AXFusion.perceive(appName:)` on the main actor
    /// using a semaphore so the Rust side can call this from any thread.
    func perceiveApp(appName: String, depth: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"elements\":[],\"error\":\"perceive bridge unavailable\"}")
        Task { @MainActor in
            let payload = await Phase4Bridge.shared.perceive(appName: appName, depth: depth)
            result.set(payload)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + permissionTimeout)
        return result.get()
    }

    /// Phase 4 Specialty A2: interact with a macOS app via AX + CGEvent.
    /// Decodes the action JSON and routes to `Phase4Bridge.interact`.
    func interactWithApp(actionJson: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"success\":false,\"error\":\"interact bridge unavailable\"}")
        Task { @MainActor in
            let payload = await Phase4Bridge.shared.interact(actionJson: actionJson)
            result.set(payload)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + permissionTimeout)
        return result.get()
    }

    /// Phase 4 Specialty A3: block until a screen / file / AX condition
    /// triggers. Routes through `Phase4Bridge.startScreenWatch` which polls
    /// the supplied target until the condition matches or the timeout fires.
    func startScreenWatch(watchJson: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"triggered\":false,\"error\":\"screen_watch bridge unavailable\"}")
        Task { @MainActor in
            let payload = await Phase4Bridge.shared.startScreenWatch(watchJson: watchJson)
            result.set(payload)
            semaphore.signal()
        }
        // Watches can take a while — give them up to 5 minutes.
        _ = semaphore.wait(timeout: .now() + 300)
        return result.get()
    }

    /// Phase 5 Specialty C1: save/load/list/prune Mamba-2 SSM hidden state
    /// via `SSMStateService`. Routes through Phase5Bridge so the FFI
    /// thread can wait on the @MainActor service synchronously.
    func manageSsmState(actionJson: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"success\":false,\"error\":\"ssm bridge unavailable\"}")
        Task { @MainActor in
            let payload = await Phase5Bridge.shared.manageSsmState(actionJson: actionJson)
            result.set(payload)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + permissionTimeout)
        return result.get()
    }

    /// Phase 5 Specialty C2: constrained decoding against the local MLX
    /// model. Routes through `ConstrainedDecodingService` via Phase5Bridge.
    func generateConstrained(prompt: String, grammarJson: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"output\":\"\",\"error\":\"constrained bridge unavailable\"}")
        Task { @MainActor in
            let payload = await Phase5Bridge.shared.generateConstrained(
                prompt: prompt,
                grammarJson: grammarJson
            )
            result.set(payload)
            semaphore.signal()
        }
        // Constrained decoding can take a while on big prompts — wait up to
        // five minutes before giving up.
        _ = semaphore.wait(timeout: .now() + 300)
        return result.get()
    }

    /// Phase 6 Specialty C3: MLX-first image generation per PLAN_V2 §5.1
    /// and §16. Routes through `MLXImageGenerationService` which owns the
    /// Apple-native flux.swift / MLXDiffusers integration when configured.
    /// Returns an explicit `{"error": ..., "hint": ...}` envelope when
    /// MLX Flux is not yet wired — the Rust side surfaces this as a tool
    /// error, callers can then opt into FAL by passing `provider: "fal"`.
    /// There is no silent cloud escalation (PLAN_V2 §3.4).
    func generateImage(prompt: String, aspectRatio: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox(
            "{\"error\":\"image_generate bridge unavailable\"}"
        )
        Task { @MainActor in
            let payload = await MLXImageGenerationService.shared.generate(
                prompt: prompt,
                aspectRatio: aspectRatio
            )
            result.set(payload)
            semaphore.signal()
        }
        // MLX Flux inference can take a while on larger prompts / aspect
        // ratios — wait up to five minutes before giving up, matching the
        // constrained decoding timeout.
        _ = semaphore.wait(timeout: .now() + 300)
        return result.get()
    }

    /// Phase 7 Specialty D1: trigger a NightBrain background job on demand.
    /// Routes through Phase7Bridge → NightBrainService.
    func triggerNightbrainJob(jobType: String, priority: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"status\":\"skipped\",\"error\":\"nightbrain bridge unavailable\"}")
        Task { @MainActor in
            let payload = await Phase7Bridge.shared.triggerNightbrainJob(
                jobType: jobType,
                priority: priority
            )
            result.set(payload)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + permissionTimeout)
        return result.get()
    }

    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedStringBox("{\"success\":false,\"error\":\"inline partner bridge unavailable\"}")
        Task { @MainActor in
            let payload = await AIPartnerService.partnerContext(
                noteId: noteId,
                cursorOffset: Int(cursorOffset)
            )
            result.set(payload)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + permissionTimeout)
        return result.get()
    }
}
