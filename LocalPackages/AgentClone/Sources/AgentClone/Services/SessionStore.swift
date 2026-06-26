import Foundation

/// Persists conversation messages to JSONL for session resume.
/// Epistemos-hosted sessions live under the host app support root; the donor
/// `~/Documents/AgentScript/sessions` path remains a read/import fallback.
@MainActor
final class SessionStore {
    static let shared = SessionStore()

    private let legacySessionsDir: URL
    private var sessionsDir: URL

    /// Current session ID (new UUID per task, or restored).
    private(set) var currentSessionId: String = UUID().uuidString

    /// Token state for cost restoration on resume.
    private(set) var sessionInputTokens: Int = 0
    private(set) var sessionOutputTokens: Int = 0

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        legacySessionsDir = home.appendingPathComponent("Documents/AgentScript/sessions")
        sessionsDir = legacySessionsDir
        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        cleanOldSessions()
    }

    func applyEpistemosHostContext(_ context: AgentCloneHostContext) {
        guard let rootPath = context.appSupportRootPath else { return }
        let rootURL = URL(fileURLWithPath: (rootPath as NSString).expandingTildeInPath, isDirectory: true)
        configureSessionsDirectory(rootURL.appendingPathComponent("sessions", isDirectory: true))
    }

    // MARK: - Write

    /// Start a new session. Call at task start.
    func newSession() {
        currentSessionId = UUID().uuidString
        sessionInputTokens = 0
        sessionOutputTokens = 0
    }

    /// Append a message to the current session's JSONL file.
    func appendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        let url = sessionFile(currentSessionId)
        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Save token state for cost restoration.
    func saveTokenState(input: Int, output: Int) {
        sessionInputTokens = input
        sessionOutputTokens = output
        let meta: [String: Any] = [
            "_type": "session_meta",
            "inputTokens": input,
            "outputTokens": output,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        appendMessage(meta)
    }

    // MARK: - Read / Resume

    /// List available sessions, newest first. Returns (id, date, messageCount).
    func listSessions() -> [(id: String, date: Date, messageCount: Int)] {
        let fm = FileManager.default
        var merged: [String: (id: String, date: Date, messageCount: Int)] = [:]
        for dir in sessionDirectories() {
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in files where url.pathExtension == "jsonl" {
                let id = url.deletingPathExtension().lastPathComponent
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let lines = (try? String(contentsOf: url, encoding: .utf8))?.components(separatedBy: "\n").filter { !$0.isEmpty }.count ?? 0
                let candidate = (id: id, date: date, messageCount: lines)
                if let existing = merged[id], existing.date >= date {
                    continue
                }
                merged[id] = candidate
            }
        }
        return merged.values.sorted { $0.date > $1.date }
    }

    /// Load messages from a session. Returns the message array and restores token state.
    func loadSession(_ sessionId: String) -> [[String: Any]] {
        guard let url = readableSessionFile(sessionId) else { return [] }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        migrateSessionIfNeeded(from: url)

        var messages: [[String: Any]] = []
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            // Restore token state from meta entries
            if obj["_type"] as? String == "session_meta" {
                sessionInputTokens = obj["inputTokens"] as? Int ?? 0
                sessionOutputTokens = obj["outputTokens"] as? Int ?? 0
                continue
            }
            messages.append(obj)
        }
        currentSessionId = sessionId
        return messages
    }

    /// Resume the most recent session. Returns messages or empty if none.
    func resumeLatest() -> [[String: Any]] {
        guard let latest = listSessions().first else { return [] }
        return loadSession(latest.id)
    }

    // MARK: - Cleanup

    /// Delete a session.
    func deleteSession(_ sessionId: String) {
        for dir in sessionDirectories() {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(sessionId).jsonl"))
        }
    }

    /// Remove sessions older than 7 days.
    private func cleanOldSessions() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let sessions = listSessions()
        for session in sessions where session.date < cutoff {
            deleteSession(session.id)
        }
    }

    private func sessionFile(_ id: String) -> URL {
        sessionsDir.appendingPathComponent("\(id).jsonl")
    }

    private func readableSessionFile(_ id: String) -> URL? {
        let activeURL = sessionFile(id)
        if FileManager.default.fileExists(atPath: activeURL.path) {
            return activeURL
        }
        let legacyURL = legacySessionsDir.appendingPathComponent("\(id).jsonl")
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        return nil
    }

    private func configureSessionsDirectory(_ directory: URL) {
        let resolved = directory.standardizedFileURL
        guard resolved.path != sessionsDir.standardizedFileURL.path else { return }
        sessionsDir = resolved
        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        importLegacySessionsIfNeeded()
        cleanOldSessions()
    }

    private func sessionDirectories() -> [URL] {
        if sessionsDir.standardizedFileURL.path == legacySessionsDir.standardizedFileURL.path {
            return [sessionsDir]
        }
        return [sessionsDir, legacySessionsDir]
    }

    private func importLegacySessionsIfNeeded() {
        guard sessionsDir.standardizedFileURL.path != legacySessionsDir.standardizedFileURL.path else { return }
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: legacySessionsDir, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "jsonl" {
            migrateSessionIfNeeded(from: url)
        }
    }

    private func migrateSessionIfNeeded(from url: URL) {
        guard sessionsDir.standardizedFileURL.path != legacySessionsDir.standardizedFileURL.path else { return }
        guard url.deletingLastPathComponent().standardizedFileURL.path == legacySessionsDir.standardizedFileURL.path else { return }
        let target = sessionsDir.appendingPathComponent(url.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: target.path) else { return }
        try? FileManager.default.copyItem(at: url, to: target)
    }
}
