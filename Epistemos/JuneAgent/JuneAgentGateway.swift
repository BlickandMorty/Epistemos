#if EPISTEMOS_APP_STORE
import Foundation
import Observation
import os

// MARK: - Session store

/// Durable store behind the June surface's session sidebar + transcript reload
/// (Phase-1 acceptance: a conversation survives relaunch). JSON under
/// Application Support; shapes mirror the subset of Hermes session fields
/// June's UI reads (`HermesSessionInfo` / `HermesSessionMessage` in the fork's
/// src/lib/tauri.ts at pinned commit a626597).
@MainActor
@Observable
final class JuneSessionStore {
    struct Message: Codable {
        let id: String
        let role: String
        let content: String
        let timestamp: String
    }

    struct Session: Codable {
        var id: String
        var title: String
        var startedAt: String
        var lastActive: String
        var messageCount: Int
        var preview: String
        /// Engine lane chosen for this session (JuneModelID); optional so
        /// records persisted before this field decode unchanged.
        var model: String?
    }

    private static let log = Logger(subsystem: "com.epistemos", category: "JuneSessionStore")

    private var sessions: [Session] = []
    private let rootDir: URL

    init() {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        rootDir = base.appendingPathComponent("Epistemos/JuneAgent", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        load()
    }

    private var indexURL: URL { rootDir.appendingPathComponent("sessions.json") }

    private func messagesURL(_ sessionID: String) -> URL {
        // Session ids originate from webview frames (hermes_bridge_session_
        // messages / session.resume). We mint them as UUIDs, but a compromised
        // page could send anything — so strictly allowlist to UUID-safe chars
        // (defense-in-depth: no path separator, no traversal, no odd bytes can
        // reach the filesystem). Legitimate UUIDs pass through unchanged.
        let safe = sessionID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return rootDir.appendingPathComponent("messages-\(safe.isEmpty ? "unknown" : safe).json")
    }

    private func load() {
        sessions = decodeOrQuarantine([Session].self, at: indexURL) ?? []
    }

    /// Data-integrity guard: decode persisted JSON, but if the bytes are present
    /// yet CORRUPT, move the bad file aside (`…corrupt-<epoch>`) rather than
    /// letting the caller treat it as "empty" — which would overwrite the only
    /// copy on the next save and turn one bad file into permanent data loss.
    /// Absent file = legitimately empty (returns nil quietly); corrupt file =
    /// quarantined + logged so it can be recovered/inspected.
    private func decodeOrQuarantine<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let value = try? JSONDecoder().decode(type, from: data) { return value }
        let quarantine = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.moveItem(at: url, to: quarantine)
        Self.log.error(
            "corrupt store file quarantined: \(url.lastPathComponent, privacy: .public) → \(quarantine.lastPathComponent, privacy: .public)"
        )
        return nil
    }

    private func persistIndex() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            Self.log.error("session index persist failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Titles arrive from webview frames (only 1MB-bounded overall); cap at the
    /// store boundary so no path can bloat the persisted index or the all-chats
    /// row. Matches the bridge's deriveTitle convention.
    private static func boundedTitle(_ title: String) -> String {
        String(title.prefix(120))
    }

    func createSession(id: String, title: String, model: String? = nil) {
        let now = ISO8601DateFormatter().string(from: Date())
        sessions.insert(
            Session(
                id: id, title: Self.boundedTitle(title), startedAt: now, lastActive: now,
                messageCount: 0, preview: "", model: model
            ),
            at: 0
        )
        persistIndex()
    }

    func model(for sessionID: String) -> String? {
        sessions.first { $0.id == sessionID }?.model
    }

    @discardableResult
    func setModel(sessionID: String, model: String?) -> Bool {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return false }
        sessions[idx].model = model
        persistIndex()
        return true
    }

    func renameSession(id: String, title: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].title = Self.boundedTitle(title)
        persistIndex()
    }

    /// Derives a title from the first user message when the session title is
    /// still a placeholder. June backfills its OWN title in local React state
    /// (sessionTitleOverridesRef) without a bridge round-trip, so the store —
    /// which the native all-chats reads and which survives relaunch — would
    /// otherwise keep "New chat". This keeps the persisted title connected
    /// to the actual conversation, matching June's derivation.
    func autoTitleIfPlaceholder(sessionID: String, from prompt: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let current = sessions[idx].title.trimmingCharacters(in: .whitespaces)
        guard current.isEmpty || current == "New session" || current == "New chat" else { return }
        let derived = Self.deriveTitle(from: prompt)
        guard !derived.isEmpty else { return }
        sessions[idx].title = derived
        persistIndex()
    }

    /// First ~6 words, capped — mirrors JuneAgentBridge.deriveTitle so a
    /// store-side and a June-side title agree.
    static func deriveTitle(from prompt: String) -> String {
        let words = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .prefix(6)
        return boundedTitle(words.joined(separator: " "))
    }

    func deleteSession(id: String) {
        sessions.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: messagesURL(id))
        persistIndex()
    }

    func appendMessage(sessionID: String, role: String, content: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        var messages = loadMessages(sessionID: sessionID)
        messages.append(Message(id: UUID().uuidString, role: role, content: content, timestamp: now))
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: messagesURL(sessionID), options: .atomic)
        } catch {
            Self.log.error("messages persist failed: \(error.localizedDescription, privacy: .public)")
        }
        if let idx = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[idx].lastActive = now
            sessions[idx].messageCount = messages.count
            sessions[idx].preview = String(content.prefix(120))
            persistIndex()
        }
    }

    func loadMessages(sessionID: String) -> [Message] {
        decodeOrQuarantine([Message].self, at: messagesURL(sessionID)) ?? []
    }

    /// Newest-first snapshot for native chrome (the all-chats sheet).
    func allSessions() -> [Session] { sessions }

    /// JSON shape for the `hermes_bridge_sessions` invoke.
    func sessionsPayload() -> [String: Any] {
        let rows: [[String: Any]] = sessions.map { s in
            var row: [String: Any] = [
                "id": s.id,
                "title": s.title,
                "started_at": s.startedAt,
                "last_active": s.lastActive,
                "message_count": s.messageCount,
                "preview": s.preview,
                "status": "idle",
                "source": "epistemos",
            ]
            if let model = s.model, !model.isEmpty {
                row["model"] = model
            }
            return row
        }
        return ["sessions": rows]
    }

    /// JSON shape for the `hermes_bridge_session_messages` invoke.
    func messagesPayload(sessionID: String) -> [String: Any] {
        let rows: [[String: Any]] = loadMessages(sessionID: sessionID).map { m in
            [
                "id": m.id,
                "session_id": sessionID,
                "role": m.role,
                "content": m.content,
                "timestamp": m.timestamp,
            ]
        }
        return ["messages": rows]
    }
}

// MARK: - Model registry (Phase 2: the June composer chip is invoke-driven)

/// Engine-lane model ids surfaced through June's own model picker
/// (`list_venice_models` / `set_venice_model` / per-session `session.create`
/// model param). Capability truth (Plan 1-MAS §0.5): local = chat tier (no
/// function-calling capability advertised — June's own `modelSupportsTools`
/// gates on it); full agentic tools arrive with the cloud lane.
nonisolated enum JuneModelID {
    static let appleFM = "epistemos.apple-fm"
    static let localGGUF = "epistemos.local-gguf"
    static let cloud = "epistemos.cloud"
}

nonisolated enum JuneGatewayError: LocalizedError {
    case cloudNotConfigured
    case modelPreparing(String)

    var errorDescription: String? {
        switch self {
        case .cloudNotConfigured:
            return "Cloud access is not configured. Connect this provider or Epistemos Cloud in Settings, or pick an on-device model."
        case .modelPreparing(let detail):
            return detail
        }
    }
}

// MARK: - Gateway

/// The in-process stand-in for June's Hermes gateway (Plan 1-MAS §3): speaks
/// the JSON-RPC frame protocol the vendored UI already uses (verified against
/// src/lib/hermes-gateway.ts) and answers `prompt.submit` with a streamed
/// local-engine turn — Apple Foundation Models when available, embedded
/// llama.cpp GGUF otherwise. No server, no subprocess, no secrets in JS.
@MainActor
final class JuneAgentGateway {
    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentGateway")

    let store = JuneSessionStore()

    /// Pushes a raw JSON string at the page (wired to
    /// `__EPISTEMOS_TAURI_SHIM__.gatewayDeliver` by the surface view).
    var deliver: ((String) -> Void)?

    private let appleFM = AppleFMQuickChatBackend()
    // The shared app-lifetime instance — the loaded GGUF model must survive
    // tab churn (warm invariant, mas_model_retained_on_switch). A private
    // instance here would double-load the model.
    private let localGGUF = LocalGGUFQuickChatBackend.shared
    private let agentCoreRunner = GooseMASAgentCoreRunner()
    private let approvalGate = AgentApprovalGate()
    /// Drives download-on-select from June's model picker: the catalog's GGUF
    /// models are shown even when not installed, and picking one downloads it.
    let downloads = QuickChatModelDownloadManager()
    private var runningTurns: [String: Task<Void, Never>] = [:]
    private struct PendingApproval {
        let id: String
        let sessionID: String
        let toolName: String
    }
    private var pendingApprovals: [String: PendingApproval] = [:]
    private var pendingApprovalIDsBySession: [String: [String]] = [:]
    /// The session June is currently showing (set on resume/create/submit) so
    /// "read latest" speaks the reply the user is looking at, not merely the
    /// most-recently-messaged session. Exposed read-only so the native
    /// all-chats sheet can mark the open conversation.
    private(set) var currentSessionID: String?
    /// Generous for a single-user app (one active + a few background) yet a
    /// hard ceiling against a runaway/compromised page.
    private static let maxConcurrentTurns = 8
    /// Runaway-response ceiling (very generous for a chat reply): bounds memory
    /// if a local model loops or a cloud stream misbehaves.
    private static let maxResponseBytes = 512 * 1024
    /// Bounds pending permission prompts if a page/agent tries to flood the UI.
    private static let maxPendingApprovals = 16
    private static let maxToolPayloadCharacters = 12_000
    private static let maxApprovalChoiceCharacters = 64
    private static let defaultModelKey = "epistemos.june.generationModel"

    // Local-lane instructions: honest capability tier per Plan 1-MAS §0.5.
    private static let instructions =
        "You are Workspace, a helpful on-device assistant inside Epistemos. " +
        "Answer concisely. You cannot browse the web or use tools in this local mode."
    private static let agentCloudInstructions =
        "You are Workspace, a helpful assistant inside Epistemos. " +
        "Use MAS-approved tools only when they help, ask for approval before reading or writing vault data, " +
        "and cite vault-derived facts in the final answer."
    private static let directCloudProviders: [CloudModelProvider] = [
        .openAI,
        .anthropic,
        .google,
        .zai,
        .kimi,
    ]

    func handleFrame(_ raw: String) {
        guard raw.utf8.count <= 1_000_000 else {
            Self.log.warning("gateway frame over size bound; dropped")
            return
        }
        guard
            let data = raw.data(using: .utf8),
            let frame = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let method = frame["method"] as? String
        else {
            Self.log.warning("gateway frame failed validation; dropped")
            return
        }
        let id = frame["id"]
        let params = frame["params"] as? [String: Any] ?? [:]

        switch method {
        case "ping":
            reply(id: id, result: [String: Any]())
        case "session.create":
            let sessionID = UUID().uuidString
            let rawTitle = (params["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "New chat"
            let title = rawTitle == "New session" ? "New chat" : rawTitle
            var chosenModel: String?
            if let model = params["model"] as? String, selectableModelIDs().contains(model) {
                chosenModel = model
            }
            store.createSession(id: sessionID, title: title, model: chosenModel)
            currentSessionID = sessionID
            reply(id: id, result: ["session_id": sessionID])
        case "session.resume":
            guard let sessionID = params["session_id"] as? String else {
                replyError(id: id, code: -32602, message: "session_id required")
                return
            }
            currentSessionID = sessionID
            reply(id: id, result: ["session_id": sessionID])
        case "prompt.submit":
            guard
                let sessionID = params["session_id"] as? String,
                let text = params["text"] as? String,
                !text.isEmpty, text.utf8.count <= 200_000
            else {
                replyError(id: id, code: -32602, message: "session_id and bounded text required")
                return
            }
            let requestedModel = (params["model"] as? String).flatMap(validModelID)
            guard runningTurns[sessionID] == nil else {
                // 4009 = "session busy", the code June's UI branches on.
                replyError(id: id, code: 4009, message: "session busy")
                return
            }
            // Defense-in-depth: bound total concurrent turns so a compromised
            // page can't exhaust memory/CPU by spawning unbounded engine Tasks
            // across many sessions (the per-session gate above only bounds one).
            guard runningTurns.count < Self.maxConcurrentTurns else {
                replyError(id: id, code: 4009, message: "too many active turns")
                return
            }
            reply(id: id, result: [String: Any]())
            startTurn(sessionID: sessionID, prompt: text, requestedModelID: requestedModel)
        case "session.interrupt":
            if let sessionID = params["session_id"] as? String {
                runningTurns[sessionID]?.cancel()
                runningTurns[sessionID] = nil
                denyPendingApprovals(sessionID: sessionID)
            }
            reply(id: id, result: [String: Any]())
        case "approval.respond":
            guard
                let sessionID = params["session_id"] as? String,
                let choice = params["choice"] as? String,
                choice.utf8.count <= Self.maxApprovalChoiceCharacters
            else {
                replyError(id: id, code: -32602, message: "session_id and bounded choice required")
                return
            }
            guard let approved = Self.approvalDecision(from: choice) else {
                replyError(id: id, code: -32602, message: "unknown approval choice")
                return
            }
            let requestedID = (params["request_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            guard let requestID = popPendingApprovalID(sessionID: sessionID, requestedID: requestedID) else {
                replyError(id: id, code: 4040, message: "no pending approval")
                return
            }
            approvalGate.deliver(id: requestID, approved: approved)
            reply(id: id, result: ["accepted": true, "request_id": requestID])
        case "command.dispatch":
            guard
                let sessionID = params["session_id"] as? String,
                let command = params["command"] as? String
            else {
                replyError(id: id, code: -32602, message: "session_id and command required")
                return
            }
            guard let modelID = Self.modelID(fromModelCommand: command) else {
                reply(id: id, result: nil)
                return
            }
            guard setSessionModel(modelID, for: sessionID) else {
                replyError(id: id, code: -32602, message: "unknown model: \(modelID)")
                return
            }
            reply(id: id, result: ["accepted": true, "model": modelID])
        default:
            // Matches the proven Phase-0 spike behavior: unknown control-plane
            // methods resolve null (June's panels tolerate it); honest
            // per-method support arrives with later phases.
            Self.log.info("gateway rpc defaulted: \(method, privacy: .public)")
            reply(id: id, result: nil)
        }
    }

    private func startTurn(sessionID: String, prompt: String, requestedModelID: String? = nil) {
        currentSessionID = sessionID
        if let requestedModelID {
            _ = setSessionModel(requestedModelID, for: sessionID)
        }
        store.appendMessage(sessionID: sessionID, role: "user", content: prompt)
        // Keep the persisted title connected to the conversation (see
        // JuneSessionStore.autoTitleIfPlaceholder) — the native all-chats +
        // relaunch read the store, and June's own backfill never writes it.
        store.autoTitleIfPlaceholder(sessionID: sessionID, from: prompt)
        emit(type: "message.start", sessionID: sessionID, payload: [:])
        // Lane resolution from the persisted record (single source of truth —
        // written at session.create, survives relaunch), revalidated because a
        // lane can disappear (e.g. an uninstalled GGUF), else the default.
        let persisted = store.model(for: sessionID).flatMap {
            // Selectable (not just installed): a session pinned to a model that
            // is still downloading keeps it, and the turn surfaces the honest
            // download state rather than silently switching models.
            selectableModelIDs().contains($0) ? $0 : nil
        }
        let modelID = persisted ?? currentDefaultModelID()

        // Give the engine the conversation, not just the latest message — a
        // chat agent with no history is amnesiac. Bounded to the most recent
        // turns so a long thread can't overflow a local model's context (the
        // backend also guards via exceededContextWindow).
        let history = Self.boundedHistory(store.loadMessages(sessionID: sessionID))

        let submittedAt = Date()
        let turn = Task { [weak self] in
            guard let self else { return }
            var full = ""
            do {
                var completedByStream = false
                var stream = try self.makeStream(sessionID: sessionID, prompt: prompt, history: history, modelID: modelID)
                do {
                    eventLoop: for try await event in stream {
                        if Task.isCancelled { break }
                        switch event {
                        case .textDelta(let delta):
                            if full.isEmpty {
                                // Budget contract [agent_surface].first_token_ms_max.
                                JuneAgentPerfMetrics.shared.recordFirstToken(
                                    milliseconds: Date().timeIntervalSince(submittedAt) * 1000
                                )
                            }
                            full += delta
                            self.emit(type: "message.delta", sessionID: sessionID, payload: ["text": delta, "delta": delta])
                            // Runaway guard: a stuck local loop or a broken/hostile
                            // cloud stream can't grow the response without bound.
                            if full.utf8.count > Self.maxResponseBytes { break eventLoop }
                        case .thinkingDelta(let delta):
                            self.emit(type: "thinking.delta", sessionID: sessionID, payload: ["text": delta, "delta": delta])
                        case .toolStarted(let id, let name, let inputJson):
                            self.emit(
                                type: "tool.start", sessionID: sessionID,
                                payload: [
                                    "tool_call_id": id,
                                    "id": id,
                                    "tool_name": name,
                                    "name": name,
                                    "input_json": Self.boundedToolPayload(inputJson),
                                ]
                            )
                        case .toolCompleted(let id, let name, let result, let isError):
                            self.emit(
                                type: "tool.complete", sessionID: sessionID,
                                payload: [
                                    "tool_call_id": id,
                                    "id": id,
                                    "tool_name": name,
                                    "name": name,
                                    "result": Self.boundedToolPayload(result),
                                    "is_error": isError,
                                    "status": isError ? "error" : "ok",
                                ]
                            )
                        case .permissionRequired(let id, let toolName, let inputJson, let riskLevel):
                            guard self.recordPendingApproval(
                                id: id,
                                sessionID: sessionID,
                                toolName: toolName
                            ) else { break }
                            self.emit(
                                type: "approval.request", sessionID: sessionID,
                                payload: [
                                    "request_id": id,
                                    "id": id,
                                    "tool_name": toolName,
                                    "description": Self.approvalDescription(
                                        toolName: toolName,
                                        riskLevel: riskLevel,
                                        inputJson: inputJson
                                    ),
                                    "command": toolName,
                                    "risk_level": riskLevel,
                                    "input_json": Self.boundedToolPayload(inputJson),
                                    "allow_permanent": false,
                                ]
                            )
                        case .complete(let stopReason, let inputTokens, let outputTokens):
                            completedByStream = true
                            self.emit(
                                type: "message.complete", sessionID: sessionID,
                                payload: [
                                    "text": full,
                                    "status": Task.isCancelled ? "cancelled" : "ok",
                                    "stop_reason": stopReason,
                                    "input_tokens": inputTokens,
                                    "output_tokens": outputTokens,
                                ]
                            )
                            break eventLoop
                        case .error(let message):
                            throw JuneGatewayError.modelPreparing(message)
                        }
                    }
                } catch let error as QuickChatError {
                    // Plan 1-MAS §2: an Apple FM guardrail trip falls back to the
                    // embedded GGUF lane instead of failing the turn — but only
                    // when nothing streamed yet and a local model is installed.
                    guard case .guardrailBlocked = error,
                          full.isEmpty,
                          self.localGGUF.unavailability() == nil else {
                        throw error
                    }
                    Self.log.info("Apple FM guardrail tripped; falling back to GGUF")
                    self.emit(
                        type: "status.update", sessionID: sessionID,
                        payload: ["text": "Switched to the on-device model for this reply."]
                    )
                    stream = Self.textEventStream(self.localGGUF.stream(
                        prompt: prompt,
                        instructions: Self.localInstructions(withHistory: history),
                        maxNewTokens: 1024
                    ))
                    fallbackLoop: for try await event in stream {
                        if Task.isCancelled { break }
                        switch event {
                        case .textDelta(let delta):
                            full += delta
                            self.emit(type: "message.delta", sessionID: sessionID, payload: ["text": delta, "delta": delta])
                            if full.utf8.count > Self.maxResponseBytes { break fallbackLoop }
                        default:
                            break
                        }
                    }
                }
                let status = Task.isCancelled ? "cancelled" : "ok"
                if !completedByStream {
                    self.emit(
                        type: "message.complete", sessionID: sessionID,
                        payload: ["text": full, "status": status]
                    )
                }
                if !full.isEmpty {
                    self.store.appendMessage(sessionID: sessionID, role: "assistant", content: full)
                }
            } catch {
                let described = Self.describeEngineError(error)
                Self.log.error("June turn failed: \(described, privacy: .public)")
                self.emit(
                    type: "message.complete", sessionID: sessionID,
                    payload: ["text": full.isEmpty ? "Error: \(described)" : full, "status": "error"]
                )
            }
            self.denyPendingApprovals(sessionID: sessionID)
            self.runningTurns[sessionID] = nil
        }
        runningTurns[sessionID] = turn
    }

    private func makeAgentCoreCloudStream(
        sessionID: String,
        prompt: String,
        history: [JuneSessionStore.Message],
        modelID: String,
        cloudModel: CloudTextModelID?
    ) throws -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        let providerName = try agentCoreProviderName(modelID: modelID, cloudModel: cloudModel)
        let approvalGate = approvalGate
        return agentCoreRunner.streamGooseMASAgentCoreRun(
            sessionID: sessionID,
            prompt: prompt,
            systemPrompt: Self.agentCloudInstructions(withHistory: history),
            maxTokens: 4096,
            providerName: providerName,
            vaultPath: Self.vaultPathForAgentCore(),
            permissionHandler: { request in
                approvalGate.awaitDecision(id: request.id)
            }
        )
    }

    /// Engine routing (Plan 1-MAS §2/§3): local lanes stream chat-only text
    /// deltas; cloud lanes stream the full in-process agent_core event feed.
    /// `history` is the bounded recent conversation (including the current
    /// user message); local lanes fold it into the system context because the
    /// QuickChat backends take a single prompt.
    private func makeStream(
        sessionID: String,
        prompt: String,
        history: [JuneSessionStore.Message],
        modelID: String
    ) throws -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        if let cloudModel = CloudTextModelID(rawValue: modelID) {
            return try makeAgentCoreCloudStream(
                sessionID: sessionID,
                prompt: prompt,
                history: history,
                modelID: modelID,
                cloudModel: cloudModel
            )
        }

        switch modelID {
        case JuneModelID.appleFM:
            return Self.textEventStream(
                appleFM.stream(prompt: prompt, instructions: Self.localInstructions(withHistory: history))
            )
        case JuneModelID.cloud:
            return try makeAgentCoreCloudStream(
                sessionID: sessionID,
                prompt: prompt,
                history: history,
                modelID: modelID,
                cloudModel: nil
            )
        default:
            let instructions = Self.localInstructions(withHistory: history)
            // A specific GGUF model the user picked: run it when installed,
            // otherwise surface the honest download state (never a cryptic
            // engine error, never a silent fallback to a different model).
            if let entry = GGUFModelCatalog.entry(id: modelID) {
                localGGUF.setPreferredModel(modelID)
                switch downloads.state(for: entry) {
                case .installed:
                    return Self.textEventStream(
                        localGGUF.stream(prompt: prompt, instructions: instructions, maxNewTokens: 1024)
                    )
                case .downloading(let p):
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) is downloading (\(Int(p * 100))%). Try again in a moment.")
                case .verifying:
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) is finishing its download. Try again in a moment.")
                case .failed(let why):
                    throw JuneGatewayError.modelPreparing("\(entry.displayName) couldn't be downloaded (\(why)). Re-select it to retry.")
                case .notInstalled:
                    downloads.beginDownload(entry)
                    throw JuneGatewayError.modelPreparing("Downloading \(entry.displayName) now — try again once it's ready.")
                }
            }
            // Legacy/unknown local id (e.g. the old single local-gguf lane):
            // best available on-device lane.
            if AppleFMQuickChatBackend.unavailability() == nil {
                return Self.textEventStream(appleFM.stream(prompt: prompt, instructions: instructions))
            }
            return Self.textEventStream(localGGUF.stream(prompt: prompt, instructions: instructions, maxNewTokens: 1024))
        }
    }

    private static func textEventStream(
        _ stream: AsyncThrowingStream<String, Error>
    ) -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await delta in stream {
                        continuation.yield(.textDelta(delta))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func agentCoreProviderName(modelID: String, cloudModel: CloudTextModelID?) throws -> String {
        if let cloudModel {
            guard cloudModel.provider.supportsAgentTier else {
                throw JuneGatewayError.modelPreparing(
                    "\(cloudModel.provider.displayName) is not enabled for Workspace agent tools in the App Store build yet. Pick OpenAI, Anthropic, or an on-device chat model."
                )
            }
            guard AppBootstrap.shared?.inferenceState.hasConfiguredCloudAccess(for: cloudModel.provider) == true else {
                throw JuneGatewayError.cloudNotConfigured
            }
            return Self.agentCoreSlug(selectedModel: cloudModel.rawValue, provider: cloudModel.provider)
        }

        guard modelID == JuneModelID.cloud,
              let inference = AppBootstrap.shared?.inferenceState else {
            throw JuneGatewayError.cloudNotConfigured
        }
        var candidates: [CloudModelProvider] = []
        if let active = inference.activeAIProvider.cloudProvider {
            candidates.append(active)
        }
        candidates.append(contentsOf: CloudModelProvider.preferredOrder)
        var seen: Set<CloudModelProvider> = []
        for provider in candidates where seen.insert(provider).inserted {
            guard provider.supportsAgentTier,
                  inference.hasConfiguredCloudAccess(for: provider) else { continue }
            let selected = inference.preferredCloudModel(for: provider)
            return Self.agentCoreSlug(selectedModel: selected.rawValue, provider: provider)
        }
        throw JuneGatewayError.cloudNotConfigured
    }

    private static func agentCoreSlug(selectedModel: String, provider: CloudModelProvider) -> String {
        GooseInProcessACPServer.agentCoreSlug(
            forSelectedModel: selectedModel,
            providerID: provider.rawValue
        ) ?? defaultAgentCoreProviderSlug(for: provider)
    }

    private static func defaultAgentCoreProviderSlug(for provider: CloudModelProvider) -> String {
        switch provider {
        case .openAI:
            return "openai"
        case .anthropic:
            return "claude_sonnet"
        case .google:
            return "gemini_pro"
        case .zai:
            return "zai"
        case .kimi:
            return "kimi"
        case .minimax:
            return "minimax"
        case .deepseek:
            return "deepseek"
        }
    }

    private static func vaultPathForAgentCore() -> String {
        if let selectedVaultPath = watchedVaultPathForAgentCore() {
            return selectedVaultPath
        }

        let environment = ProcessInfo.processInfo.environment
        for key in ["EPISTEMOS_VAULT_PATH", "VAULT_PATH"] {
            if let raw = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty {
                return raw
            }
        }
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let scratch = base
            .appendingPathComponent("Epistemos/JuneAgent/agent-core-scratch", isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        return scratch.path
    }

    private static func watchedVaultPathForAgentCore() -> String? {
        guard let vaultSync = AppBootstrap.shared?.vaultSync,
              vaultSync.isWatching,
              let vaultURL = vaultSync.vaultURL?.standardizedFileURL else {
            return nil
        }
        return vaultURL.path
    }

    private static func boundedToolPayload(_ value: String) -> String {
        let bounded = value.count > maxToolPayloadCharacters
            ? String(value.prefix(maxToolPayloadCharacters)) + "\n[truncated]"
            : value
        return redactKnownVaultRoots(in: bounded)
    }

    private static func redactKnownVaultRoots(in value: String) -> String {
        var redacted = value
        for path in redactedVaultRootCandidates() where !path.isEmpty {
            redacted = redacted.replacingOccurrences(of: path, with: "[vault]")
        }
        return redacted
    }

    private static func redactedVaultRootCandidates() -> [String] {
        var paths: [String] = []
        if let watched = watchedVaultPathForAgentCore() {
            paths.append(watched)
        }
        let environment = ProcessInfo.processInfo.environment
        for key in ["EPISTEMOS_VAULT_PATH", "VAULT_PATH"] {
            if let raw = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty {
                paths.append(URL(fileURLWithPath: raw).standardizedFileURL.path)
            }
        }
        return Array(Set(paths))
    }

    private static func approvalDescription(
        toolName: String,
        riskLevel: String,
        inputJson: String
    ) -> String {
        let bounded = boundedToolPayload(inputJson)
        if bounded.isEmpty || bounded == "{}" {
            return "\(toolName) requests \(riskLevel) access."
        }
        return "\(toolName) requests \(riskLevel) access:\n\(bounded)"
    }

    private static func approvalDecision(from choice: String) -> Bool? {
        let normalized = choice.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("allow") || normalized.contains("approve") || normalized == "yes" {
            return true
        }
        if normalized.contains("deny") || normalized.contains("reject") || normalized == "no" {
            return false
        }
        return nil
    }

    @discardableResult
    private func recordPendingApproval(id: String, sessionID: String, toolName: String) -> Bool {
        guard !id.isEmpty, !sessionID.isEmpty, !toolName.isEmpty else {
            approvalGate.deliver(id: id, approved: false)
            return false
        }
        if pendingApprovals[id] == nil, pendingApprovals.count >= Self.maxPendingApprovals {
            approvalGate.deliver(id: id, approved: false)
            return false
        }
        pendingApprovals[id] = PendingApproval(id: id, sessionID: sessionID, toolName: toolName)
        var ids = pendingApprovalIDsBySession[sessionID] ?? []
        if !ids.contains(id) {
            ids.append(id)
        }
        pendingApprovalIDsBySession[sessionID] = ids
        return true
    }

    private func popPendingApprovalID(sessionID: String, requestedID: String? = nil) -> String? {
        if let requestedID, let pending = pendingApprovals[requestedID],
           pending.sessionID == sessionID {
            pendingApprovals.removeValue(forKey: requestedID)
            pendingApprovalIDsBySession[sessionID]?.removeAll { $0 == requestedID }
            return requestedID
        }
        guard var ids = pendingApprovalIDsBySession[sessionID] else { return nil }
        while !ids.isEmpty {
            let id = ids.removeFirst()
            if pendingApprovals.removeValue(forKey: id) != nil {
                pendingApprovalIDsBySession[sessionID] = ids.isEmpty ? nil : ids
                return id
            }
        }
        pendingApprovalIDsBySession[sessionID] = nil
        return nil
    }

    private func denyPendingApprovals(sessionID: String) {
        guard let ids = pendingApprovalIDsBySession.removeValue(forKey: sessionID) else { return }
        for id in ids {
            pendingApprovals.removeValue(forKey: id)
            approvalGate.deliver(id: id, approved: false)
        }
    }

    // MARK: - History composition

    /// Most-recent turns only, so a long thread can't overflow a local model's
    /// context window.
    private static let maxHistoryMessages = 20

    static func boundedHistory(_ messages: [JuneSessionStore.Message]) -> [JuneSessionStore.Message] {
        messages.count <= maxHistoryMessages ? messages : Array(messages.suffix(maxHistoryMessages))
    }

    /// Local engines take a single prompt; the prior conversation (everything
    /// but the just-appended current message) is folded into the system
    /// instructions as plain text so the on-device model has context.
    private static func localInstructions(withHistory history: [JuneSessionStore.Message]) -> String {
        instructions(withHistory: history, base: instructions)
    }

    private static func agentCloudInstructions(withHistory history: [JuneSessionStore.Message]) -> String {
        instructions(withHistory: history, base: agentCloudInstructions)
    }

    private static func instructions(withHistory history: [JuneSessionStore.Message], base: String) -> String {
        let prior = history.dropLast() // the current user message is the live prompt
        guard !prior.isEmpty else { return base }
        let transcript = prior.map { msg -> String in
            let who = msg.role == "assistant" ? "Workspace" : "User"
            return "\(who): \(msg.content)"
        }.joined(separator: "\n")
        // Interpolation (not `+`) to avoid a String/SQL operator-overload
        // ambiguity from GRDB's SQL type being in scope.
        return "\(base)\n\nConversation so far:\n\(transcript)"
    }

    // MARK: - Model catalog (drives June's composer model chip)

    /// The most recent assistant reply (most-recently-active session's last
    /// assistant message) — drives June's native "read aloud" control. Read
    /// from the store so it survives across turns and reflects what June shows.
    func latestAssistantReply() -> String? {
        // Prefer the session June is currently showing; fall back to the
        // most-recently-active session so "read latest" still works right after
        // launch before any resume/submit has been seen.
        let sessionID = currentSessionID
            ?? store.allSessions().max(by: { $0.lastActive < $1.lastActive })?.id
        guard let sessionID else { return nil }
        return store.loadMessages(sessionID: sessionID).last { $0.role == "assistant" }?.content
    }

    /// Cancels an in-flight turn when a session is deleted (bridge delete path).
    func forgetSession(_ sessionID: String) {
        runningTurns[sessionID]?.cancel()
        runningTurns[sessionID] = nil
        denyPendingApprovals(sessionID: sessionID)
        // Deleting the shown session: drop the pointer so "read latest" falls
        // back to the most-recently-active session rather than a dead one.
        if currentSessionID == sessionID { currentSessionID = nil }
    }

    /// Runnable-now lanes: Apple FM (if the device supports it), each INSTALLED
    /// GGUF model by its catalog id, and cloud.
    func availableModelIDs() -> [String] {
        var ids: [String] = []
        if AppleFMQuickChatBackend.unavailability() == nil { ids.append(JuneModelID.appleFM) }
        if localGGUF.isAvailableInThisBuild {
            ids.append(contentsOf: GGUFModelCatalog.installedEntries().map(\.id))
        }
        ids.append(contentsOf: directCloudModelIDs(configuredOnly: true))
        ids.append(JuneModelID.cloud)
        return ids
    }

    /// Everything the picker offers — the runnable lanes PLUS the not-yet-
    /// installed GGUF models (picking one downloads it). Selecting a
    /// downloadable model must persist, so it becomes active once it lands.
    func selectableModelIDs() -> [String] {
        var ids: [String] = []
        if AppleFMQuickChatBackend.unavailability() == nil { ids.append(JuneModelID.appleFM) }
        if localGGUF.isAvailableInThisBuild {
            ids.append(contentsOf: GGUFModelCatalog.entries.map(\.id))
        }
        ids.append(contentsOf: directCloudModelIDs(configuredOnly: false))
        ids.append(JuneModelID.cloud)
        return ids
    }

    func currentDefaultModelID() -> String {
        if let saved = UserDefaults.standard.string(forKey: Self.defaultModelKey),
           selectableModelIDs().contains(saved) {
            return saved
        }
        // Best runnable local lane first; cloud is never a silent default.
        let available = availableModelIDs()
        return available.first { $0 != JuneModelID.cloud } ?? JuneModelID.cloud
    }

    @discardableResult
    func setDefaultModel(_ id: String) -> Bool {
        guard selectableModelIDs().contains(id) else { return false }
        UserDefaults.standard.set(id, forKey: Self.defaultModelKey)
        if let currentSessionID {
            _ = store.setModel(sessionID: currentSessionID, model: id)
        }
        prepareSelectedModel(id)
        return true
    }

    @discardableResult
    func setSessionModel(_ id: String, for sessionID: String) -> Bool {
        guard selectableModelIDs().contains(id) else { return false }
        currentSessionID = sessionID
        guard store.setModel(sessionID: sessionID, model: id) else { return false }
        prepareSelectedModel(id)
        return true
    }

    private func validModelID(_ id: String) -> String? {
        selectableModelIDs().contains(id) ? id : nil
    }

    private static func modelID(fromModelCommand command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/model") else { return nil }
        let rest = trimmed.dropFirst("/model".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = rest.split(separator: " ").first else { return nil }
        return String(first)
    }

    private func prepareSelectedModel(_ id: String) {
        // A GGUF pick steers the local lane and, if it isn't downloaded yet,
        // starts the download so the next turn can run it.
        if let entry = GGUFModelCatalog.entry(id: id) {
            localGGUF.setPreferredModel(id)
            if GGUFModelCatalog.installedURL(for: entry) == nil {
                downloads.beginDownload(entry)
            }
        }
        if let cloudModel = CloudTextModelID(rawValue: id) {
            AppBootstrap.shared?.inferenceState.setActiveAIProvider(
                AIProviderSelection(cloudProvider: cloudModel.provider)
            )
            AppBootstrap.shared?.inferenceState.setPreferredChatModelSelection(.cloud(cloudModel))
        }
    }

    /// VeniceModelDto-shaped rows for `list_venice_models`.
    ///
    /// PROVIDER FIELD — local rows carry `provider: ""` DELIBERATELY (not
    /// "epistemos"). June's own `modelSupportsTools` predicate is the truth
    /// boundary for function-calling; local Apple/GGUF rows therefore expose
    /// an explicit `epistemos-local-chat` trait and an empty capability list.
    /// Cloud rows may advertise tools only when routed through agent_core.
    func modelsPayload() -> [[String: Any]] {
        var rows: [[String: Any]] = []
        if AppleFMQuickChatBackend.unavailability() == nil {
            rows.append([
                "provider": "", "id": JuneModelID.appleFM,
                "name": "Apple Intelligence (on-device)", "modelType": "text",
                "description": "Apple's on-device foundation model. Fast, free, fully private. Chat only — no agent tools.",
                "privacy": "private", "traits": ["on-device", "epistemos-local-chat"], "capabilities": [String](),
            ])
        }
        // Every catalog GGUF model, installed or not — picking a not-yet-
        // installed one downloads it (see setDefaultModel). The description
        // carries the honest state so the user knows what selecting will do.
        if localGGUF.isAvailableInThisBuild {
            for entry in GGUFModelCatalog.entries {
                let state = downloads.state(for: entry)
                let detail: String
                switch state {
                case .installed:
                    detail = "\(entry.subtitle). Runs locally, free, fully private. Chat only — no agent tools."
                case .downloading(let p):
                    detail = "\(entry.subtitle). Downloading \(Int(p * 100))%…"
                case .verifying:
                    detail = "\(entry.subtitle). Verifying download…"
                case .failed:
                    detail = "\(entry.subtitle). Download failed — select to retry."
                case .notInstalled:
                    detail = "\(entry.subtitle). Select to download (~\(Self.sizeText(entry.approxDownloadBytes))), then runs locally & fully private."
                }
                rows.append([
                    // Empty provider (see modelsPayload doc): local GGUF is an
                    // honest chat-tier engine, listable/selectable in June's
                    // pickers without claiming tool capability.
                    "provider": "", "id": entry.id,
                    "name": "\(entry.displayName) (on-device)", "modelType": "text",
                    "description": detail,
                    "privacy": "private", "traits": ["on-device", "epistemos-local-chat"], "capabilities": [String](),
                    "contextTokens": entry.defaultContextTokens,
                ])
            }
        }
        rows.append([
            "provider": "epistemos", "id": JuneModelID.cloud,
            "name": "Epistemos Cloud", "modelType": "text",
            "description": "Full agent capability via the Epistemos cloud. Requires an active subscription.",
            "privacy": "anonymous", "traits": ["cloud"],
            "capabilities": ["supportsFunctionCalling"],
        ])
        for provider in Self.directCloudProviders {
            let configured = AppBootstrap.shared?.inferenceState.hasConfiguredCloudAccess(for: provider) == true
            for model in CloudTextModelID.models(for: provider) {
                let toolCapabilities = provider.supportsAgentTier ? ["supportsFunctionCalling"] : [String]()
                rows.append([
                    "provider": provider.rawValue, "id": model.rawValue,
                    "name": "\(provider.displayName) · \(model.displayName)", "modelType": "text",
                    "description": configured
                        ? "\(model.aboutSheetPurposeSummary) Uses your saved \(provider.manualCredentialTitleLowercase) or account connection."
                        : "\(model.aboutSheetPurposeSummary) Configure \(provider.displayName) in Settings to use this model.",
                    "privacy": "provider-cloud", "traits": ["cloud", provider.rawValue],
                    "capabilities": toolCapabilities,
                    "contextTokens": model.maxContextTokens,
                ])
            }
        }
        return rows
    }

    private func directCloudModelIDs(configuredOnly: Bool) -> [String] {
        let inference = AppBootstrap.shared?.inferenceState
        return Self.directCloudProviders.flatMap { provider in
            if configuredOnly, inference?.hasConfiguredCloudAccess(for: provider) != true {
                return [String]()
            }
            return CloudTextModelID.models(for: provider).map(\.rawValue)
        }
    }

    private static func sizeText(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }

    /// User-facing engine-error text: QuickChatError carries no LocalizedError
    /// conformance, so localizedDescription would render "(…error 2.)" in the
    /// transcript. Translate the cases we own; pass real LocalizedErrors
    /// (cloud engine, gateway) through untouched.
    private static func describeEngineError(_ error: Error) -> String {
        if let quickChat = error as? QuickChatError {
            switch quickChat {
            case .guardrailBlocked:
                return "The on-device model declined this request."
            case .exceededContextWindow:
                return "This conversation is too long for the on-device model. Start a new chat."
            case .engineUnavailable(let reason):
                return reason.userCopy
            case .generationFailed(let detail):
                return "The on-device model failed to answer (\(detail))."
            }
        }
        return error.localizedDescription
    }

    private func emit(type: String, sessionID: String, payload: [String: Any]) {
        let frame: [String: Any] = [
            "method": "event",
            "params": ["type": type, "session_id": sessionID, "payload": payload],
        ]
        push(frame)
    }

    private func reply(id: Any?, result: Any?) {
        var frame: [String: Any] = ["jsonrpc": "2.0"]
        frame["id"] = id ?? NSNull()
        frame["result"] = result ?? NSNull()
        push(frame)
    }

    private func replyError(id: Any?, code: Int, message: String) {
        var frame: [String: Any] = ["jsonrpc": "2.0"]
        frame["id"] = id ?? NSNull()
        frame["error"] = ["code": code, "message": message]
        push(frame)
    }

    private func push(_ frame: [String: Any]) {
        guard
            JSONSerialization.isValidJSONObject(frame),
            let data = try? JSONSerialization.data(withJSONObject: frame),
            let json = String(data: data, encoding: .utf8)
        else {
            Self.log.error("gateway frame not serializable")
            return
        }
        deliver?(json)
    }
}
#endif
