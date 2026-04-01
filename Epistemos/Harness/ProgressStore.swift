import Foundation
import os

// MARK: - Progress Store
//
// Structured session handoff for multi-session continuity.
// Writes epistemos-progress.json at session end, reads at session start.
// Enables context preservation across FoundationModels session recycles,
// app restarts, and long-running multi-step tasks.

/// The structured progress record written at the end of each session
/// and read at the start of the next.
struct SessionProgress: Codable, Sendable {
    let sessionId: String
    let timestamp: String
    let harnessVersion: String

    /// High-level summary of what was accomplished.
    let accomplishedSummary: String

    /// Tasks that were completed in this session.
    let completedTasks: [String]

    /// Tasks that failed and why.
    let failedTasks: [TaskFailure]

    /// The next priority for the continuation session.
    let nextPriority: String?

    /// Important context for the next session.
    let contextNotes: [String]

    /// Git state at session end (branch, commit, dirty files).
    let gitState: RepoState?

    /// Files that were created or modified.
    let changedFiles: [String]

    /// Total tokens consumed.
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalTurns: Int

    struct TaskFailure: Codable, Sendable {
        let taskId: String
        let description: String
        let errorSummary: String
    }
}

// MARK: - Task Decomposition

/// A structured task list for multi-step agent work.
/// JSON format (not Markdown) — more resistant to accidental model overwriting.
struct TaskDecomposition: Codable, Sendable {
    let sessionId: String
    let objective: String
    let createdAt: String
    var tasks: [TaskItem]

    struct TaskItem: Codable, Sendable {
        let id: String
        let description: String
        var status: TaskStatus
        var evidence: String?
        var completedAt: String?

        enum TaskStatus: String, Codable, Sendable {
            case pending
            case inProgress = "in_progress"
            case completed
            case failed
            case blocked
        }
    }

    /// Count of tasks not yet completed.
    var pendingCount: Int {
        tasks.filter { $0.status == .pending || $0.status == .inProgress }.count
    }

    /// Count of completed tasks.
    var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }
}

// MARK: - Progress Store

/// Reads and writes session progress and task decomposition files.
/// Stored in the session directory under Application Support.
enum ProgressStore {
    private static let log = Logger(subsystem: "com.epistemos", category: "ProgressStore")

    private static var sessionsDir: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.epistemos.app/sessions")
        }
        return appSupport.appendingPathComponent("com.epistemos.app/sessions")
    }

    // MARK: - Session Progress

    /// Save session progress at session end.
    static func saveProgress(_ progress: SessionProgress) {
        let dir = sessionsDir.appendingPathComponent(progress.sessionId)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(progress)
            let path = dir.appendingPathComponent("progress.json")
            try data.write(to: path)
            log.info("Saved session progress: \(progress.sessionId)")
        } catch {
            log.error("Failed to save progress: \(error.localizedDescription)")
        }
    }

    /// Load the most recent session progress for continuation.
    static func loadLatestProgress() -> SessionProgress? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        // Find most recent session directory
        let sorted = contents.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return aDate > bDate
        }

        for dir in sorted {
            let progressPath = dir.appendingPathComponent("progress.json")
            if let data = try? Data(contentsOf: progressPath),
               let progress = try? JSONDecoder().decode(SessionProgress.self, from: data) {
                return progress
            }
        }
        return nil
    }

    /// Load progress for a specific session.
    static func loadProgress(sessionId: String) -> SessionProgress? {
        let path = sessionsDir.appendingPathComponent(sessionId).appendingPathComponent("progress.json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(SessionProgress.self, from: data)
    }

    // MARK: - Task Decomposition

    /// Save task decomposition.
    static func saveTaskDecomposition(_ decomp: TaskDecomposition) {
        let dir = sessionsDir.appendingPathComponent(decomp.sessionId)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(decomp)
            let path = dir.appendingPathComponent("tasks.json")
            try data.write(to: path)
            log.info("Saved task decomposition: \(decomp.sessionId) (\(decomp.tasks.count) tasks)")
        } catch {
            log.error("Failed to save task decomposition: \(error.localizedDescription)")
        }
    }

    /// Load task decomposition for a session.
    static func loadTaskDecomposition(sessionId: String) -> TaskDecomposition? {
        let path = sessionsDir.appendingPathComponent(sessionId).appendingPathComponent("tasks.json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(TaskDecomposition.self, from: data)
    }

    // MARK: - Bootstrap Packet Archive

    /// Save the bootstrap packet for a session (for later replay/analysis).
    static func saveBootstrapPacket(_ packet: BootstrapPacket, sessionId: String) {
        let dir = sessionsDir.appendingPathComponent(sessionId)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(packet)
            let path = dir.appendingPathComponent("bootstrap_packet.json")
            try data.write(to: path)
        } catch {
            log.error("Failed to save bootstrap packet: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Directory

    /// Get the session directory URL for storing artifacts.
    static func sessionDirectory(for sessionId: String) -> URL {
        sessionsDir.appendingPathComponent(sessionId)
    }

    /// List all session IDs, sorted by most recent first.
    static func listSessions() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return aDate > bDate
            }
            .map { $0.lastPathComponent }
    }
}
