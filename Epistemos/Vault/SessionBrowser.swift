import Foundation
import Observation

// MARK: - Session Browser State

/// Observable state for browsing persistent agent session folders.
///
/// Wraps the Rust FFI `list_session_folders` / `read_session_metadata` calls
/// and provides grouped, sorted session data for the SwiftUI sidebar.
@MainActor @Observable
final class SessionBrowser {
    static let shared = SessionBrowser()

    // MARK: - Types

    struct SessionInfo: Identifiable, Hashable {
        let id: String          // session_id
        let model: String
        let provider: String
        let startedAt: Date
        let status: String      // "running", "completed", "failed"
        let turnCount: UInt32
        let folderPath: String
        let trajectoryClassification: String?

        var statusBadge: String {
            switch status {
            case "completed": return "checkmark.circle.fill"
            case "failed":    return "xmark.circle.fill"
            case "running":   return "circle.fill"
            default:          return "questionmark.circle"
            }
        }

        var sessionId: String { id }
        var isCompleted: Bool { status == "completed" }
        var isFailed: Bool { status == "failed" }
        var hasTrajectoryBadge: Bool { trajectoryClassification != nil }
        var trajectoryBadgeLabel: String {
            guard let trajectoryClassification else { return "" }
            return trajectoryClassification.capitalized
        }
    }

    struct DateGroup: Identifiable {
        let id: String   // e.g. "2026-04-08"
        let label: String
        let sessions: [SessionInfo]
    }

    // MARK: - State

    var groups: [DateGroup] = []
    var selectedSession: SessionInfo?
    var isLoading = false
    var sessions: [SessionInfo] { groups.flatMap(\.sessions) }

    // MARK: - Loading

    /// Refresh the session list from a vault path.
    func refresh(vaultPath: String) {
        isLoading = true
        let ffiSessions = listSessionFolders(vaultPath: vaultPath)
        let sessions = ffiSessions.map { info in
            SessionInfo(
                id: info.sessionId,
                model: info.model,
                provider: info.provider,
                startedAt: Date(timeIntervalSince1970: info.startedAtEpoch),
                status: info.status,
                turnCount: info.turnCount,
                folderPath: info.folderPath,
                trajectoryClassification: EventStore.shared?.sessionMetricClassification(sessionId: info.sessionId)
            )
        }
        groups = Self.groupByDate(sessions)
        isLoading = false
    }

    func refreshSessions(for vaultIdentity: VaultIdentity) {
        guard let vaultPath = VaultRegistry.shared.resolveVaultPath(for: vaultIdentity) else {
            groups = []
            selectedSession = nil
            isLoading = false
            return
        }
        refresh(vaultPath: vaultPath)
    }

    /// Read full session metadata JSON from a folder path.
    func loadMetadata(for session: SessionInfo) -> String? {
        try? readSessionMetadata(sessionFolderPath: session.folderPath)
    }

    /// Read the summary markdown for a session.
    func loadSummary(for session: SessionInfo) -> String? {
        let summaryPath = URL(fileURLWithPath: session.folderPath)
            .appendingPathComponent("summary.md")
        return try? String(contentsOf: summaryPath, encoding: .utf8)
    }

    /// Read the transcript JSONL for a session.
    func loadTranscript(for session: SessionInfo) -> [String] {
        let transcriptPath = URL(fileURLWithPath: session.folderPath)
            .appendingPathComponent("transcript.jsonl")
        guard let content = try? String(contentsOf: transcriptPath, encoding: .utf8) else {
            return []
        }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    // MARK: - Grouping

    private static func groupByDate(_ sessions: [SessionInfo]) -> [DateGroup] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        var todayItems: [SessionInfo] = []
        var yesterdayItems: [SessionInfo] = []
        var weekItems: [SessionInfo] = []
        var olderItems: [SessionInfo] = []

        for session in sessions {
            let sessionDay = calendar.startOfDay(for: session.startedAt)
            if sessionDay >= today {
                todayItems.append(session)
            } else if sessionDay >= yesterday {
                yesterdayItems.append(session)
            } else if sessionDay >= weekAgo {
                weekItems.append(session)
            } else {
                olderItems.append(session)
            }
        }

        var groups: [DateGroup] = []
        if !todayItems.isEmpty {
            groups.append(DateGroup(id: "today", label: "Today", sessions: todayItems))
        }
        if !yesterdayItems.isEmpty {
            groups.append(DateGroup(id: "yesterday", label: "Yesterday", sessions: yesterdayItems))
        }
        if !weekItems.isEmpty {
            groups.append(DateGroup(id: "week", label: "Previous 7 Days", sessions: weekItems))
        }
        if !olderItems.isEmpty {
            groups.append(DateGroup(id: "older", label: "Older", sessions: olderItems))
        }

        return groups
    }
}
