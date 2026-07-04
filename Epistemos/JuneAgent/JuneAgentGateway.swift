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
        // Session ids are UUIDs we minted; keep the path safe regardless.
        let safe = sessionID.replacingOccurrences(of: "/", with: "_")
        return rootDir.appendingPathComponent("messages-\(safe).json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        sessions = (try? JSONDecoder().decode([Session].self, from: data)) ?? []
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

    func renameSession(id: String, title: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].title = Self.boundedTitle(title)
        persistIndex()
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
        guard let data = try? Data(contentsOf: messagesURL(sessionID)) else { return [] }
        return (try? JSONDecoder().decode([Message].self, from: data)) ?? []
    }

    /// Newest-first snapshot for native chrome (the all-chats sheet).
    func allSessions() -> [Session] { sessions }

    /// JSON shape for the `hermes_bridge_sessions` invoke.
    func sessionsPayload() -> [String: Any] {
        let rows: [[String: Any]] = sessions.map { s in
            [
                "id": s.id,
                "title": s.title,
                "started_at": s.startedAt,
                "last_active": s.lastActive,
                "message_count": s.messageCount,
                "preview": s.preview,
                "status": "idle",
                "source": "epistemos",
            ]
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

    var errorDescription: String? {
        switch self {
        case .cloudNotConfigured:
            return "Epistemos Cloud isn't available yet in this build. Pick an on-device model to continue."
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
    private var runningTurns: [String: Task<Void, Never>] = [:]
    private static let defaultModelKey = "epistemos.june.generationModel"

    // Local-lane instructions: honest capability tier per Plan 1-MAS §0.5.
    private static let instructions =
        "You are June, a helpful on-device assistant inside Epistemos. " +
        "Answer concisely. You cannot browse the web or use tools in this local mode."

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
            let title = (params["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "New session"
            var chosenModel: String?
            if let model = params["model"] as? String, availableModelIDs().contains(model) {
                chosenModel = model
            }
            store.createSession(id: sessionID, title: title, model: chosenModel)
            reply(id: id, result: ["session_id": sessionID])
        case "session.resume":
            guard let sessionID = params["session_id"] as? String else {
                replyError(id: id, code: -32602, message: "session_id required")
                return
            }
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
            guard runningTurns[sessionID] == nil else {
                // 4009 = "session busy", the code June's UI branches on.
                replyError(id: id, code: 4009, message: "session busy")
                return
            }
            reply(id: id, result: [String: Any]())
            startTurn(sessionID: sessionID, prompt: text)
        case "session.interrupt":
            if let sessionID = params["session_id"] as? String {
                runningTurns[sessionID]?.cancel()
                runningTurns[sessionID] = nil
            }
            reply(id: id, result: [String: Any]())
        default:
            // Matches the proven Phase-0 spike behavior: unknown control-plane
            // methods resolve null (June's panels tolerate it); honest
            // per-method support arrives with later phases.
            Self.log.info("gateway rpc defaulted: \(method, privacy: .public)")
            reply(id: id, result: nil)
        }
    }

    private func startTurn(sessionID: String, prompt: String) {
        store.appendMessage(sessionID: sessionID, role: "user", content: prompt)
        emit(type: "message.start", sessionID: sessionID, payload: [:])
        // Lane resolution from the persisted record (single source of truth —
        // written at session.create, survives relaunch), revalidated because a
        // lane can disappear (e.g. an uninstalled GGUF), else the default.
        let persisted = store.model(for: sessionID).flatMap {
            availableModelIDs().contains($0) ? $0 : nil
        }
        let modelID = persisted ?? currentDefaultModelID()

        let submittedAt = Date()
        let turn = Task { [weak self] in
            guard let self else { return }
            var full = ""
            do {
                var stream = try self.makeStream(prompt: prompt, modelID: modelID)
                do {
                    for try await delta in stream {
                        if Task.isCancelled { break }
                        if full.isEmpty {
                            // Budget contract [agent_surface].first_token_ms_max.
                            JuneAgentPerfMetrics.shared.recordFirstToken(
                                milliseconds: Date().timeIntervalSince(submittedAt) * 1000
                            )
                        }
                        full += delta
                        self.emit(type: "message.delta", sessionID: sessionID, payload: ["text": delta])
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
                    stream = self.localGGUF.stream(
                        prompt: prompt, instructions: Self.instructions, maxNewTokens: 1024
                    )
                    for try await delta in stream {
                        if Task.isCancelled { break }
                        full += delta
                        self.emit(type: "message.delta", sessionID: sessionID, payload: ["text": delta])
                    }
                }
                let status = Task.isCancelled ? "cancelled" : "ok"
                self.emit(
                    type: "message.complete", sessionID: sessionID,
                    payload: ["text": full, "status": status]
                )
                if !full.isEmpty {
                    self.store.appendMessage(sessionID: sessionID, role: "assistant", content: full)
                }
            } catch {
                let described = Self.describeEngineError(error)
                Self.log.error("local turn failed: \(described, privacy: .public)")
                self.emit(
                    type: "message.complete", sessionID: sessionID,
                    payload: ["text": full.isEmpty ? "Error: \(described)" : full, "status": "error"]
                )
            }
            self.runningTurns[sessionID] = nil
        }
        runningTurns[sessionID] = turn
    }

    /// Engine routing (Plan 1-MAS §2): the session's chosen lane, defaulting
    /// to the best available local engine.
    private func makeStream(prompt: String, modelID: String) throws -> AsyncThrowingStream<String, Error> {
        switch modelID {
        case JuneModelID.appleFM:
            return appleFM.stream(prompt: prompt, instructions: Self.instructions)
        case JuneModelID.localGGUF:
            return localGGUF.stream(prompt: prompt, instructions: Self.instructions, maxNewTokens: 1024)
        case JuneModelID.cloud:
            // Honest gate (Plan 1-MAS §0.5/§5): a real Keychain session token
            // (minted by the Phase-4 StoreKit receipt exchange) is required —
            // never fake a cloud turn. With a session, this streams from the
            // receipt-gated proxy; without one, JuneCloudEngine throws
            // .notSubscribed and June shows the honest error.
            return JuneCloudEngine.shared.stream(prompt: prompt, instructions: Self.instructions)
        default:
            if AppleFMQuickChatBackend.unavailability() == nil {
                return appleFM.stream(prompt: prompt, instructions: Self.instructions)
            }
            return localGGUF.stream(prompt: prompt, instructions: Self.instructions, maxNewTokens: 1024)
        }
    }

    // MARK: - Model catalog (drives June's composer model chip)

    /// Cancels an in-flight turn when a session is deleted (bridge delete path).
    func forgetSession(_ sessionID: String) {
        runningTurns[sessionID]?.cancel()
        runningTurns[sessionID] = nil
    }

    func availableModelIDs() -> [String] {
        var ids: [String] = []
        if AppleFMQuickChatBackend.unavailability() == nil { ids.append(JuneModelID.appleFM) }
        if localGGUF.unavailability() == nil { ids.append(JuneModelID.localGGUF) }
        ids.append(JuneModelID.cloud)
        return ids
    }

    func currentDefaultModelID() -> String {
        let available = availableModelIDs()
        if let saved = UserDefaults.standard.string(forKey: Self.defaultModelKey),
           available.contains(saved) {
            return saved
        }
        // Best local lane first; cloud is never a silent default.
        return available.first { $0 != JuneModelID.cloud } ?? JuneModelID.cloud
    }

    @discardableResult
    func setDefaultModel(_ id: String) -> Bool {
        guard availableModelIDs().contains(id) else { return false }
        UserDefaults.standard.set(id, forKey: Self.defaultModelKey)
        return true
    }

    /// VeniceModelDto-shaped rows for `list_venice_models`. Capability truth:
    /// no `supportsFunctionCalling` on local entries (chat tier); the cloud
    /// entry carries it because the cloud lane is the full agentic tier.
    func modelsPayload() -> [[String: Any]] {
        var rows: [[String: Any]] = []
        if AppleFMQuickChatBackend.unavailability() == nil {
            rows.append([
                "provider": "epistemos", "id": JuneModelID.appleFM,
                "name": "Apple Intelligence (on-device)", "modelType": "text",
                "description": "Apple's on-device foundation model. Fast, free, fully private. Chat only — no agent tools.",
                "privacy": "private", "traits": ["on-device"], "capabilities": [String](),
            ])
        }
        if localGGUF.unavailability() == nil, let entry = localGGUF.resolvedEntry() {
            rows.append([
                "provider": "epistemos", "id": JuneModelID.localGGUF,
                "name": "\(entry.displayName) (on-device)", "modelType": "text",
                "description": "\(entry.subtitle). Runs locally, free, fully private. Chat only — no agent tools.",
                "privacy": "private", "traits": ["on-device"], "capabilities": [String](),
                "contextTokens": entry.defaultContextTokens,
            ])
        }
        rows.append([
            "provider": "epistemos", "id": JuneModelID.cloud,
            "name": "Epistemos Cloud", "modelType": "text",
            "description": "Full agent capability via the Epistemos cloud. Requires an active subscription.",
            "privacy": "anonymous", "traits": ["cloud"],
            "capabilities": ["supportsFunctionCalling"],
        ])
        return rows
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
                return "This conversation is too long for the on-device model. Start a new session."
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
