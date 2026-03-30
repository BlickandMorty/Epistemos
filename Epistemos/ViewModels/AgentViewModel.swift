import Foundation
import Observation

@MainActor @Observable
final class AgentViewModel {
    var phase: AgentPhase = .idle
    var thinkingText = ""
    var responseText = ""
    var contentBlocks: [RenderedBlock] = []
    var errorMessage: String?
    var tokenUsage: (input: Int, output: Int) = (0, 0)
    var turnCount = 0
    var latestStopReason = ""
    var sessions: [AgentSessionSummary] = []
    var activeSessionID: String?
    var sessionSearchQuery = ""
    var sessionSearchResults: [AgentSessionSummary] = []

    private var currentTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private let hermesManager: HermesSubprocessManager
    private let inferenceState: InferenceState?
    private var localLLMClient: (any LLMClientProtocol)?
    private var awaitingPrompt = false
    private var isAwaitingApproval = false
    private var activeContinuation: AsyncStream<AgentStreamEvent>.Continuation?
    private var installedBridgeHandler = false
    private var lastSubmittedPrompt = ""
    var adminViewModel: HermesAdminViewModel?
    private(set) var localInferencePort: Int?

    init(
        hermesManager: HermesSubprocessManager? = nil,
        inferenceState: InferenceState? = nil,
        localLLMClient: (any LLMClientProtocol)? = nil
    ) {
        self.hermesManager = hermesManager ?? HermesSubprocessManager()
        self.inferenceState = inferenceState
        self.localLLMClient = localLLMClient
    }

    var isRunning: Bool {
        switch phase {
        case .idle, .complete, .failed:
            return false
        default:
            return true
        }
    }

    var activeSessionSummary: AgentSessionSummary? {
        guard let activeSessionID else { return nil }
        return sessions.first(where: { $0.id == activeSessionID })
    }

    func prepareRuntimeIfNeeded() async {
        do {
            try await connectIfNeeded()
            requestSessionList()
        } catch {
            handleError(error.localizedDescription)
        }
    }

    func send(prompt: String, providerName: String = "claude_sonnet") {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isRunning {
            stop()
        }
        prepareTurnStateForNewPrompt(prompt: trimmed)

        let (stream, continuation) = AsyncStream<AgentStreamEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(256)
        )
        activeContinuation = continuation

        let startPayload = makeStartPayload(prompt: trimmed, providerName: providerName)

        currentTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await self.connectIfNeeded()
                self.sendHermesCommand(startPayload)
            } catch {
                self.handleError(error.localizedDescription)
            }
        }

        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.consume(stream)
        }
    }

    func performQuickAction(_ action: HermesQuickAction) {
        send(prompt: action.slashCommand)
    }

    func stop() {
        if isRunning {
            sendHermesCommand([
                "command": "interrupt",
                "message": "Stop requested by the user.",
            ])
        }

        currentTask?.cancel()
        streamTask?.cancel()
        currentTask = nil
        streamTask = nil
        awaitingPrompt = false
        isAwaitingApproval = false
        activeContinuation?.finish()
        activeContinuation = nil

        if isRunning {
            phase = .idle
        }
    }

    func refreshSessions() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.connectIfNeeded()
                self.requestSessionList()
            } catch {
                self.handleError(error.localizedDescription)
            }
        }
    }

    func searchSessions(query: String) {
        sessionSearchQuery = query
        guard !query.isEmpty else {
            sessionSearchResults = []
            return
        }
        let payload: [String: Any] = [
            "command": "admin",
            "domain": "sessions",
            "action": "search",
            "query": query,
        ]
        sendHermesCommand(payload, handlesRuntimeFailure: false)
    }

    func startNewSession() {
        switchSession(command: "new_session")
    }

    func forkCurrentSession() {
        guard let activeSessionID else {
            startNewSession()
            return
        }
        switchSession(command: "fork_session", extraPayload: ["session_id": activeSessionID])
    }

    func resume(sessionID: String) {
        switchSession(command: "resume_session", extraPayload: ["session_id": sessionID])
    }

    func resolvePermission(id: String, approved: Bool) {
        sendHermesCommand([
            "command": "approval",
            "permission_id": id,
            "approved": approved,
        ])
        isAwaitingApproval = false
        phase = .thinking(tokenCount: max(1, thinkingText.count / 4))
    }

    private func consume(_ stream: AsyncStream<AgentStreamEvent>) async {
        var thinkingTokens = 0
        var responseTokens = 0

        // Token coalescing: buffer deltas and flush at ~30fps to avoid
        // triggering @Observable mutations on every single token.
        var pendingThinking = ""
        var pendingResponse = ""
        var lastFlush = ContinuousClock.now
        let flushInterval: Duration = .milliseconds(32)

        func flushTokens() {
            if !pendingThinking.isEmpty {
                thinkingText.append(pendingThinking)
                pendingThinking = ""
                phase = .thinking(tokenCount: thinkingTokens)
            }
            if !pendingResponse.isEmpty {
                responseText.append(pendingResponse)
                pendingResponse = ""
                phase = .responding(tokenCount: responseTokens)
            }
            lastFlush = ContinuousClock.now
        }

        for await event in stream {
            // Fast path: buffer token deltas and coalesce updates.
            let isDelta: Bool
            switch event {
            case .thinkingDelta(let text):
                pendingThinking.append(text)
                thinkingTokens += max(1, text.count / 4)
                isDelta = true

            case .textDelta(let text):
                pendingResponse.append(text)
                responseTokens += max(1, text.count / 4)
                isDelta = true

            default:
                isDelta = false
            }

            if isDelta {
                if ContinuousClock.now - lastFlush >= flushInterval {
                    flushTokens()
                }
                continue
            }

            // Non-delta event: flush any pending tokens first.
            flushTokens()

            switch event {
            case .thinkingDelta, .textDelta:
                break

            case .toolInputStreaming:
                break

            case .toolStarted(_, let name, let inputJson):
                flushBuffers()
                phase = .executing(toolName: name)
                contentBlocks.append(
                    .toolExecution(
                        name: name,
                        input: inputJson,
                        result: nil,
                        isError: false
                    )
                )

            case .toolCompleted(_, let result, let isError):
                if let lastIndex = contentBlocks.indices.last,
                   case .toolExecution(let name, let input, _, _) = contentBlocks[lastIndex] {
                    contentBlocks[lastIndex] = .toolExecution(
                        name: name,
                        input: input,
                        result: result,
                        isError: isError
                    )
                }
                phase = .reasoning(tokenCount: max(1, thinkingText.count / 4))

            case .subagentSpawned(let id, let role):
                contentBlocks.append(.status("Spawned \(role) subagent \(id)"))

            case .permissionRequired(let request):
                isAwaitingApproval = true
                phase = .awaitingApproval(request)

            case .contextCompacting(let tokens):
                contentBlocks.append(.status("Compacting context at ~\(tokens) tokens"))

            case .contextCompacted(let messageCount):
                contentBlocks.append(.status("Context compacted to \(messageCount) messages"))

            case .turnStarted(let turn, _):
                turnCount = turn
                if turn > 1 {
                    flushBuffers()
                    thinkingTokens = 0
                    responseTokens = 0
                }

            case .complete(let stopReason, let inputTokens, let outputTokens, let history):
                flushBuffers()
                if let history,
                   HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: lastSubmittedPrompt) {
                    hydrateSessionSurface(with: history)
                }
                latestStopReason = stopReason
                tokenUsage = (inputTokens, outputTokens)
                phase = .complete
                awaitingPrompt = false
                isAwaitingApproval = false
                activeContinuation = nil

            case .error(let error):
                handleError(error.message)
            }
        }

        // Final flush for any remaining buffered tokens.
        flushTokens()
    }

    private func flushBuffers() {
        if !thinkingText.isEmpty {
            contentBlocks.append(
                .thinking(
                    text: thinkingText,
                    tokenCount: max(1, thinkingText.count / 4)
                )
            )
            thinkingText = ""
        }

        if !responseText.isEmpty {
            contentBlocks.append(.text(responseText))
            responseText = ""
        }
    }

    private func handleError(_ message: String) {
        errorMessage = message
        phase = .failed(message)
        awaitingPrompt = false
        isAwaitingApproval = false
        activeContinuation = nil
        lastSubmittedPrompt = ""
    }

    private func makeStartPayload(prompt: String, providerName: String) -> [String: Any] {
        var payload: [String: Any] = [
            "command": "start",
            "prompt": prompt,
            "cwd": AgentRuntimeDefaults.vaultPath,
        ]
        appendRuntimeOverrides(to: &payload, providerName: providerName)
        return payload
    }

    private func makeSessionPayload(command: String) -> [String: Any] {
        var payload: [String: Any] = [
            "command": command,
            "cwd": AgentRuntimeDefaults.vaultPath,
        ]
        appendRuntimeOverrides(to: &payload, providerName: nil)
        return payload
    }

    private func appendRuntimeOverrides(
        to payload: inout [String: Any],
        providerName: String?
    ) {
        guard let inferenceState else {
            if let providerName, !providerName.isEmpty {
                payload["provider_name"] = providerName
            }
            return
        }

        // Try cloud route first.
        if let route = HermesRuntimeRoute.resolve(
            for: inferenceState.preferredChatModelSelection,
            apiKeyLookup: { inferenceState.apiKey(for: $0) }
        ) {
            applyRoute(route, to: &payload)
            return
        }

        // Try local agent route (agent-capable local model → local inference server).
        if case .localQwen(let modelID) = inferenceState.preferredChatModelSelection,
           let port = localInferencePort,
           let route = HermesRuntimeRoute.resolveLocal(modelID: modelID, inferencePort: port) {
            applyRoute(route, to: &payload)
            return
        }

        if let providerName, !providerName.isEmpty {
            payload["provider_name"] = providerName
        }
    }

    private func applyRoute(_ route: HermesRuntimeRoute, to payload: inout [String: Any]) {
        payload["model"] = route.model
        payload["requested_provider"] = route.requestedProvider
        payload["env"] = route.environmentOverrides
        if let baseURL = route.baseURL {
            payload["base_url"] = baseURL
        }
        if let apiMode = route.apiMode {
            payload["api_mode"] = apiMode
        }
    }

    private func connectIfNeeded() async throws {
        if !installedBridgeHandler {
            hermesManager.setRequestHandler { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.handleHermesBridgeLine(line)
                }
            }
            installedBridgeHandler = true
        }

        if !hermesManager.isRunning {
            try await hermesManager.launch()
        }
    }

    private func handleHermesBridgeLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = payload["type"] as? String else {
            if let activeContinuation {
                activeContinuation.yield(.error(AgentRuntimeError(message: "Invalid Hermes bridge event")))
                activeContinuation.finish()
                self.activeContinuation = nil
            } else {
                handleError("Invalid Hermes bridge event")
            }
            return
        }

        if let sessionID = payload["session_id"] as? String,
           !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeSessionID = sessionID
        }

        switch type {
        case "ready":
            if let port = payload["inference_port"] as? Int, port > 0 {
                localInferencePort = port
            }
            requestSessionList()

        case "inference_request":
            handleInferenceRequest(payload)

        case "session_list":
            let activeID = (payload["active_session_id"] as? String) ?? activeSessionID
            let parsedSessions = (payload["sessions"] as? [[String: Any]] ?? [])
                .compactMap { AgentSessionSummary(payload: $0, activeSessionID: activeID) }
                .sorted(by: Self.sessionSort)
            sessions = parsedSessions
            if let activeID, !activeID.isEmpty {
                activeSessionID = activeID
            } else {
                activeSessionID = sessions.first?.id
            }

        case "session_changed":
            if let sessionPayload = payload["session"] as? [String: Any],
               let session = AgentSessionSummary(
                payload: sessionPayload,
                activeSessionID: sessionPayload["session_id"] as? String ?? activeSessionID
               ) {
                activeSessionID = session.id
                upsertSession(session)
            }
            if let history = parseSessionHistory(from: (payload["session"] as? [String: Any])?["history"]) {
                hydrateSessionSurface(with: history)
            }

        case "status":
            if let message = payload["message"] as? String,
               !message.isEmpty,
               !awaitingPrompt,
               !isAwaitingApproval,
               let activeContinuation {
                activeContinuation.yield(.thinkingDelta(message))
            }

        case "thinking":
            if let text = payload["text"] as? String,
               let activeContinuation {
                awaitingPrompt = false
                activeContinuation.yield(.thinkingDelta(text))
            }

        case "text":
            if let text = payload["text"] as? String,
               let activeContinuation {
                awaitingPrompt = false
                activeContinuation.yield(.textDelta(text))
            }

        case "tool_started":
            let id = payload["id"] as? String ?? UUID().uuidString
            let name = payload["name"] as? String ?? "tool"
            let inputJSON = payload["input_json"] as? String ?? "{}"
            awaitingPrompt = false
            activeContinuation?.yield(.toolStarted(id: id, name: name, inputJson: inputJSON))

        case "tool_completed":
            let id = payload["id"] as? String ?? UUID().uuidString
            let result = payload["result"] as? String ?? ""
            let isError = payload["is_error"] as? Bool ?? false
            activeContinuation?.yield(.toolCompleted(id: id, result: result, isError: isError))

        case "permission_required":
            let request = AgentPermissionRequest(
                id: payload["permission_id"] as? String ?? UUID().uuidString,
                toolName: payload["tool_name"] as? String ?? "terminal",
                inputJson: payload["input_json"] as? String ?? "{}",
                riskLevel: AgentRuntimeRiskLevel(rustValue: payload["risk_level"] as? String ?? "modification"),
                description: payload["description"] as? String ?? "Hermes requires approval."
            )
            activeContinuation?.yield(.permissionRequired(request))

        case "complete":
            let stopReason = payload["stop_reason"] as? String ?? "completed"
            let inputTokens = payload["input_tokens"] as? Int ?? 0
            let outputTokens = payload["output_tokens"] as? Int ?? 0
            let history = parseSessionHistory(from: payload["history"])
            activeContinuation?.yield(
                .complete(
                    stopReason: stopReason,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    history: history
                )
            )
            activeContinuation?.finish()
            activeContinuation = nil
            requestSessionList()

        case "error":
            let message = payload["message"] as? String ?? "Hermes bridge error"
            if let activeContinuation {
                activeContinuation.yield(.error(AgentRuntimeError(message: message)))
                activeContinuation.finish()
                self.activeContinuation = nil
            } else {
                handleError(message)
            }

        case "admin_result":
            if let domain = payload["domain"] as? String,
               domain == "sessions",
               let action = payload["action"] as? String,
               action == "search" {
                let activeID = activeSessionID
                let rawSessions = (payload["results"] as? [[String: Any]]) ?? []
                sessionSearchResults = rawSessions
                    .compactMap { AgentSessionSummary(payload: $0, activeSessionID: activeID) }
                    .sorted(by: Self.sessionSort)
            }
            adminViewModel?.handleAdminResult(payload)

        default:
            break
        }
    }

    private func handleInferenceRequest(_ payload: [String: Any]) {
        let requestId = payload["request_id"] as? String ?? ""
        let prompt = payload["prompt"] as? String ?? ""
        let systemPrompt = payload["system_prompt"] as? String
        let maxTokens = payload["max_tokens"] as? Int ?? 2048

        guard !requestId.isEmpty, !prompt.isEmpty else {
            sendHermesCommand([
                "command": "inference_response",
                "request_id": requestId,
                "result": ["text": "", "error": "missing request_id or prompt"],
            ])
            return
        }

        Task { @MainActor [weak self] in
            guard let self, let client = self.localLLMClient else {
                self?.sendHermesCommand([
                    "command": "inference_response",
                    "request_id": requestId,
                    "result": ["text": "", "error": "local LLM client not available"],
                ])
                return
            }

            do {
                let text = try await client.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens
                )
                self.sendHermesCommand([
                    "command": "inference_response",
                    "request_id": requestId,
                    "result": [
                        "text": text,
                        "prompt_tokens": max(1, prompt.utf8.count / 4),
                        "completion_tokens": max(1, text.utf8.count / 4),
                    ],
                ])
            } catch {
                self.sendHermesCommand([
                    "command": "inference_response",
                    "request_id": requestId,
                    "result": ["text": "", "error": error.localizedDescription],
                ])
            }
        }
    }

    private func requestSessionList() {
        sendHermesCommand(["command": "list_sessions"], handlesRuntimeFailure: false)
    }

    private func switchSession(command: String, extraPayload: [String: Any] = [:]) {
        if isRunning {
            stop()
        }
        resetSessionSurfaceState()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.connectIfNeeded()
                var payload = self.makeSessionPayload(command: command)
                for (key, value) in extraPayload {
                    payload[key] = value
                }
                self.sendHermesCommand(payload)
            } catch {
                self.handleError(error.localizedDescription)
            }
        }
    }

    private func prepareTurnStateForNewPrompt(prompt: String) {
        phase = .thinking(tokenCount: 0)
        thinkingText = ""
        responseText = ""
        lastSubmittedPrompt = prompt
        if !prompt.isEmpty {
            contentBlocks.append(.userPrompt(prompt))
        }
        errorMessage = nil
        tokenUsage = (0, 0)
        latestStopReason = ""
        awaitingPrompt = true
        isAwaitingApproval = false
    }

    private func resetSessionSurfaceState() {
        phase = .idle
        thinkingText = ""
        responseText = ""
        contentBlocks = []
        errorMessage = nil
        tokenUsage = (0, 0)
        turnCount = 0
        latestStopReason = ""
        awaitingPrompt = false
        isAwaitingApproval = false
        lastSubmittedPrompt = ""
    }

    private func upsertSession(_ session: AgentSessionSummary) {
        if let existingIndex = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[existingIndex] = session
        } else {
            sessions.append(session)
        }

        sessions.sort(by: Self.sessionSort)
    }

    private func hydrateSessionSurface(with history: [AgentSessionMessage]) {
        thinkingText = ""
        responseText = ""
        contentBlocks = RenderedBlock.sessionHistory(history)
        errorMessage = nil
        turnCount = history.reduce(into: 0) { count, message in
            if message.role == "user" {
                count += 1
            }
        }
        awaitingPrompt = false
        isAwaitingApproval = false
    }

    private func parseSessionHistory(from value: Any?) -> [AgentSessionMessage]? {
        guard let rawMessages = value as? [Any] else { return nil }
        return rawMessages.compactMap { item in
            guard let payload = item as? [String: Any] else { return nil }
            return AgentSessionMessage(payload: payload)
        }
    }

    private static func sessionSort(_ lhs: AgentSessionSummary, _ rhs: AgentSessionSummary) -> Bool {
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }
        switch (lhs.lastActive, rhs.lastActive) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }
        if lhs.historyCount != rhs.historyCount {
            return lhs.historyCount > rhs.historyCount
        }
        return lhs.id < rhs.id
    }

    private func sendHermesCommand(
        _ payload: [String: Any],
        handlesRuntimeFailure: Bool = true
    ) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else {
            if handlesRuntimeFailure {
                handleError("Failed to encode Hermes bridge command.")
            }
            return
        }

        do {
            try hermesManager.writeLine(line)
        } catch {
            if handlesRuntimeFailure {
                handleError(error.localizedDescription)
            }
        }
    }
}

enum HermesQuickAction: String, CaseIterable, Identifiable, Sendable {
    case help
    case model
    case tools
    case context
    case compact
    case reset
    case version

    var id: String { rawValue }

    var title: String {
        switch self {
        case .help: "Help"
        case .model: "Model"
        case .tools: "Tools"
        case .context: "Context"
        case .compact: "Compact"
        case .reset: "Reset"
        case .version: "Version"
        }
    }

    var detail: String {
        switch self {
        case .help: "Show the Hermes command list"
        case .model: "Show the current Hermes model"
        case .tools: "List enabled Hermes tools"
        case .context: "Inspect the current session context"
        case .compact: "Compress session history"
        case .reset: "Clear the current session history"
        case .version: "Show the Hermes runtime version"
        }
    }

    var systemImage: String {
        switch self {
        case .help: "questionmark.circle"
        case .model: "cpu"
        case .tools: "wrench.and.screwdriver"
        case .context: "text.alignleft"
        case .compact: "arrow.down.left.and.arrow.up.right"
        case .reset: "arrow.counterclockwise"
        case .version: "number"
        }
    }

    var slashCommand: String {
        "/\(rawValue)"
    }

    var isDestructive: Bool {
        self == .reset
    }
}

enum HermesSessionRefreshPolicy {
    static func shouldHydrateSurface(afterSubmittedPrompt prompt: String) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return true }

        let slashCommand = trimmed
            .split(whereSeparator: \.isWhitespace)
            .first?
            .lowercased() ?? ""

        switch slashCommand {
        case "/reset", "/compact":
            return true
        default:
            return false
        }
    }
}

struct AgentSessionSummary: Identifiable, Equatable, Sendable {
    let id: String
    let cwd: String
    let model: String
    let historyCount: Int
    let isActive: Bool
    let preview: String
    let lastActive: Date?
    private let explicitTitle: String?

    init?(payload: [String: Any], activeSessionID: String?) {
        guard let sessionID = payload["session_id"] as? String,
              !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.id = sessionID
        self.cwd = payload["cwd"] as? String ?? "."
        self.model = payload["model"] as? String ?? ""
        self.historyCount = payload["history_len"] as? Int ?? 0
        let rawPreview = payload["preview"] as? String ?? ""
        self.preview = rawPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawTitle = (payload["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !rawTitle.isEmpty {
            self.explicitTitle = rawTitle
        } else {
            self.explicitTitle = nil
        }
        if let seconds = payload["last_active"] as? Double {
            self.lastActive = Date(timeIntervalSince1970: seconds)
        } else if let seconds = payload["last_active"] as? Int {
            self.lastActive = Date(timeIntervalSince1970: TimeInterval(seconds))
        } else if let seconds = payload["last_active"] as? NSNumber {
            self.lastActive = Date(timeIntervalSince1970: seconds.doubleValue)
        } else {
            self.lastActive = nil
        }

        if let explicitActive = payload["is_active"] as? Bool {
            self.isActive = explicitActive
        } else {
            self.isActive = sessionID == activeSessionID
        }
    }

    var shortID: String {
        String(id.prefix(8))
    }

    var title: String {
        if let explicitTitle {
            return explicitTitle
        }
        let lastComponent = URL(fileURLWithPath: cwd).lastPathComponent
        if !lastComponent.isEmpty {
            return lastComponent
        }
        if !preview.isEmpty {
            return String(preview.prefix(40))
        }
        return shortID
    }

    var detail: String {
        let modelText = model.isEmpty ? "Hermes session" : model
        return "\(modelText) • \(historyCount) messages"
    }
}

enum AgentPhase: Equatable {
    case idle
    case thinking(tokenCount: Int)
    case searching(query: String)
    case executing(toolName: String)
    case reasoning(tokenCount: Int)
    case responding(tokenCount: Int)
    case awaitingApproval(AgentPermissionRequest)
    case complete
    case failed(String)
}

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
    case complete(stopReason: String, inputTokens: Int, outputTokens: Int, history: [AgentSessionMessage]?)
    case error(AgentRuntimeError)
}

struct AgentRuntimeError: Error, Sendable, Equatable {
    let message: String
}

struct AgentPermissionRequest: Sendable, Identifiable, Equatable {
    let id: String
    let toolName: String
    let inputJson: String
    let riskLevel: AgentRuntimeRiskLevel
    let description: String
}

enum AgentRuntimeRiskLevel: Sendable, Equatable {
    case readOnly
    case modification
    case destructive

    init(rustValue: String) {
        switch rustValue {
        case "read_only":
            self = .readOnly
        case "destructive":
            self = .destructive
        default:
            self = .modification
        }
    }
}

enum RenderedBlock: Identifiable, Equatable, Sendable {
    case userPrompt(String)
    case thinking(text: String, tokenCount: Int)
    case text(String)
    case toolExecution(name: String, input: String, result: String?, isError: Bool)
    case status(String)

    var id: String {
        switch self {
        case .userPrompt(let text):
            return "user-\(text.hashValue)"
        case .thinking(let text, let tokenCount):
            return "thinking-\(tokenCount)-\(text.hashValue)"
        case .text(let text):
            return "text-\(text.hashValue)"
        case .toolExecution(let name, let input, _, _):
            return "tool-\(name)-\(input.hashValue)"
        case .status(let text):
            return "status-\(text.hashValue)"
        }
    }

    static func sessionHistory(_ messages: [AgentSessionMessage]) -> [RenderedBlock] {
        var blocks: [RenderedBlock] = []
        blocks.reserveCapacity(messages.count)

        for message in messages {
            switch message.role {
            case "user":
                if let content = message.trimmedContent {
                    blocks.append(.userPrompt(content))
                }
            case "assistant":
                if let reasoning = message.trimmedReasoning {
                    blocks.append(.thinking(text: reasoning, tokenCount: max(1, reasoning.count / 4)))
                }
                if let content = message.trimmedContent {
                    blocks.append(.text(content))
                }
            case "tool":
                let toolName = message.trimmedToolName ?? "tool"
                let result = message.trimmedContent
                blocks.append(
                    .toolExecution(
                        name: toolName,
                        input: "",
                        result: result,
                        isError: result.map(Self.looksLikeError) ?? false
                    )
                )
            case "system":
                if let content = message.trimmedContent {
                    blocks.append(.status("System: \(content)"))
                }
            default:
                if let content = message.trimmedContent {
                    blocks.append(.status("\(message.role.capitalized): \(content)"))
                }
            }
        }

        return blocks
    }

    private static func looksLikeError(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.hasPrefix("error") || lowered.contains("traceback") || lowered.contains("failed")
    }
}

struct AgentSessionMessage: Equatable, Sendable {
    let role: String
    let content: String?
    let toolName: String?
    let toolCallID: String?
    let reasoning: String?
    let finishReason: String?

    init?(payload: [String: Any]) {
        guard let rawRole = payload["role"] as? String else {
            return nil
        }
        let trimmedRole = rawRole.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRole.isEmpty else {
            return nil
        }
        self.role = trimmedRole
        self.content = payload["content"] as? String
        self.toolName = payload["tool_name"] as? String
        self.toolCallID = payload["tool_call_id"] as? String
        self.reasoning = payload["reasoning"] as? String
        self.finishReason = payload["finish_reason"] as? String
    }

    var trimmedContent: String? {
        guard let content else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedToolName: String? {
        guard let toolName else { return nil }
        let trimmed = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedReasoning: String? {
        guard let reasoning else { return nil }
        let trimmed = reasoning.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AgentRuntimeDefaults {
    static var vaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".epistemos", isDirectory: true)
            .appendingPathComponent("vault", isDirectory: true)
            .path
    }

    static let enableBash = false
    static let enableWebSearch = true
}
