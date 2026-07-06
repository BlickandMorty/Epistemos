#if EPISTEMOS_APP_STORE
import Foundation
import Observation
import os

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
        let reasoning: String?
        let toolCalls: String?
        let toolCallID: String?
        let toolName: String?
        let answerPacketID: String?

        init(
            id: String,
            role: String,
            content: String,
            timestamp: String,
            reasoning: String? = nil,
            toolCalls: String? = nil,
            toolCallID: String? = nil,
            toolName: String? = nil,
            answerPacketID: String? = nil
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.timestamp = timestamp
            self.reasoning = reasoning
            self.toolCalls = toolCalls
            self.toolCallID = toolCallID
            self.toolName = toolName
            self.answerPacketID = answerPacketID
        }
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
    /// yet CORRUPT, move the bad file aside (`...corrupt-<epoch>`) rather than
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
            "corrupt store file quarantined: \(url.lastPathComponent, privacy: .public) -> \(quarantine.lastPathComponent, privacy: .public)"
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

    func appendMessage(
        sessionID: String,
        role: String,
        content: String,
        reasoning: String? = nil,
        toolCalls: String? = nil,
        toolCallID: String? = nil,
        toolName: String? = nil,
        answerPacketID: String? = nil
    ) {
        let now = ISO8601DateFormatter().string(from: Date())
        var messages = loadMessages(sessionID: sessionID)
        messages.append(Message(
            id: UUID().uuidString,
            role: role,
            content: content,
            timestamp: now,
            reasoning: reasoning,
            toolCalls: toolCalls,
            toolCallID: toolCallID,
            toolName: toolName,
            answerPacketID: answerPacketID
        ))
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
            var row: [String: Any] = [
                "id": m.id,
                "session_id": sessionID,
                "role": m.role,
                "content": m.content,
                "timestamp": m.timestamp,
            ]
            if let reasoning = m.reasoning, !reasoning.isEmpty {
                row["reasoning"] = reasoning
                row["reasoning_content"] = reasoning
            }
            if let toolCalls = m.toolCalls, !toolCalls.isEmpty {
                row["tool_calls"] = toolCalls
            }
            if let toolCallID = m.toolCallID, !toolCallID.isEmpty {
                row["tool_call_id"] = toolCallID
            }
            if let toolName = m.toolName, !toolName.isEmpty {
                row["tool_name"] = toolName
            }
            if let answerPacketID = m.answerPacketID, !answerPacketID.isEmpty {
                row["answer_packet_id"] = answerPacketID
            }
            return row
        }
        return ["messages": rows]
    }
}
#endif
