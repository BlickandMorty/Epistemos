#if EPISTEMOS_APP_STORE
import Foundation
import os

// MARK: - Session store

/// Durable store behind the June surface's session sidebar + transcript reload
/// (Phase-1 acceptance: a conversation survives relaunch). JSON under
/// Application Support; shapes mirror the subset of Hermes session fields
/// June's UI reads (`HermesSessionInfo` / `HermesSessionMessage` in the fork's
/// src/lib/tauri.ts at pinned commit a626597).
@MainActor
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

    func createSession(id: String, title: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        sessions.insert(
            Session(id: id, title: title, startedAt: now, lastActive: now, messageCount: 0, preview: ""),
            at: 0
        )
        persistIndex()
    }

    func renameSession(id: String, title: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].title = title
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
    private let localGGUF = LocalGGUFQuickChatBackend()
    private var runningTurns: [String: Task<Void, Never>] = [:]

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
            store.createSession(id: sessionID, title: title)
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

        let turn = Task { [weak self] in
            guard let self else { return }
            var full = ""
            do {
                let stream = self.makeStream(prompt: prompt)
                for try await delta in stream {
                    if Task.isCancelled { break }
                    full += delta
                    self.emit(type: "message.delta", sessionID: sessionID, payload: ["text": delta])
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
                Self.log.error("local turn failed: \(error.localizedDescription, privacy: .public)")
                let message = "Error: the local engine could not answer (\(error.localizedDescription))."
                self.emit(
                    type: "message.complete", sessionID: sessionID,
                    payload: ["text": full.isEmpty ? message : full, "status": "error"]
                )
            }
            self.runningTurns[sessionID] = nil
        }
        runningTurns[sessionID] = turn
    }

    /// Local lane (Plan 1-MAS §2): Apple FM when available, else embedded GGUF.
    private func makeStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        if AppleFMQuickChatBackend.unavailability() == nil {
            return appleFM.stream(prompt: prompt, instructions: Self.instructions)
        }
        return localGGUF.stream(prompt: prompt, instructions: Self.instructions, maxNewTokens: 1024)
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
