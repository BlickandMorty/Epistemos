import Foundation
import os

// MARK: - Progress Store
//
// Structured session handoff for multi-session continuity.
// Writes progress.json at session end, reads at session start.
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
    private static let sessionDirectoryResourceKeys: Set<URLResourceKey> = [
        .contentModificationDateKey,
        .isDirectoryKey,
    ]

    private static var sessionsDir: URL {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        return appSupport.appendingPathComponent("com.epistemos.app/sessions")
    }

    private static func sessionDirectoryEntries(fileManager: FileManager = .default) -> [(url: URL, modificationDate: Date)] {
        guard fileManager.fileExists(atPath: sessionsDir.path) else { return [] }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: sessionsDir,
                includingPropertiesForKeys: Array(sessionDirectoryResourceKeys),
                options: [.skipsHiddenFiles]
            )
        } catch {
            log.error("Failed to enumerate session directories: \(error.localizedDescription)")
            return []
        }

        return contents.compactMap { url in
            do {
                let values = try url.resourceValues(forKeys: sessionDirectoryResourceKeys)
                guard values.isDirectory == true else { return nil }
                return (url, values.contentModificationDate ?? .distantPast)
            } catch {
                log.error("Failed to inspect session directory \(url.lastPathComponent): \(error.localizedDescription)")
                return nil
            }
        }
    }

    private static func sortedSessionDirectories(fileManager: FileManager = .default) -> [URL] {
        sessionDirectoryEntries(fileManager: fileManager)
            .sorted { $0.modificationDate > $1.modificationDate }
            .map(\.url)
    }

    private static func loadProgress(at path: URL) -> SessionProgress? {
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode(SessionProgress.self, from: data)
        } catch {
            log.error("Failed to load progress from \(path.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private static func loadTaskDecomposition(at path: URL) -> TaskDecomposition? {
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode(TaskDecomposition.self, from: data)
        } catch {
            log.error("Failed to load task decomposition from \(path.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
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
            try data.write(to: path, options: .atomic)
            log.info("Saved session progress: \(progress.sessionId)")
        } catch {
            log.error("Failed to save progress: \(error.localizedDescription)")
        }
    }

    /// Load the most recent session progress for continuation.
    static func loadLatestProgress() -> SessionProgress? {
        for dir in sortedSessionDirectories() {
            let progressPath = dir.appendingPathComponent("progress.json")
            if let progress = loadProgress(at: progressPath) {
                return progress
            }
        }
        return nil
    }

    /// Load progress for a specific session.
    static func loadProgress(sessionId: String) -> SessionProgress? {
        let path = sessionsDir.appendingPathComponent(sessionId).appendingPathComponent("progress.json")
        return loadProgress(at: path)
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
            try data.write(to: path, options: .atomic)
            log.info("Saved task decomposition: \(decomp.sessionId) (\(decomp.tasks.count) tasks)")
        } catch {
            log.error("Failed to save task decomposition: \(error.localizedDescription)")
        }
    }

    /// Load task decomposition for a session.
    static func loadTaskDecomposition(sessionId: String) -> TaskDecomposition? {
        let path = sessionsDir.appendingPathComponent(sessionId).appendingPathComponent("tasks.json")
        return loadTaskDecomposition(at: path)
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
            try data.write(to: path, options: .atomic)
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
        sortedSessionDirectories().map(\.lastPathComponent)
    }
}
