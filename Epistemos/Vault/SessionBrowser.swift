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

    struct SummarySection: Identifiable, Hashable {
        let title: String
        let body: String

        var id: String { title }
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

    func summarySections(for session: SessionInfo) -> [SummarySection] {
        guard let summary = loadSummary(for: session) else {
            return []
        }
        return Self.extractSummarySections(from: summary)
    }

    func filteredGroups(matching query: String) -> [DateGroup] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return groups
        }

        let filteredSessions = sessions.filter { session in
            let summary = loadSummary(for: session)
            let transcriptLines = loadTranscript(for: session)
            return Self.matchesSearch(
                query: trimmedQuery,
                session: session,
                summary: summary,
                transcriptLines: transcriptLines
            )
        }

        return Self.groupByDate(filteredSessions)
    }

    func searchSessions(matching query: String, limit: Int = 12) -> [SessionInfo] {
        filteredGroups(matching: query)
            .flatMap(\.sessions)
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(max(1, limit))
            .map { $0 }
    }

    func lineage(for session: SessionInfo) -> [SessionInfo] {
        let allSessions = sessions
        let parentSession = parentSessionID(for: session)
            .flatMap { parentID in
                allSessions.first(where: { $0.id == parentID })
            }
        let childSessions = allSessions.filter { other in
            parentSessionID(for: other) == session.id
        }
        var related: [SessionInfo] = []
        if let parentSession {
            related.append(parentSession)
        }
        related.append(session)
        related.append(contentsOf: childSessions.sorted { $0.startedAt < $1.startedAt })
        return related
    }

    func lineageSummary(for session: SessionInfo) -> String? {
        let related = lineage(for: session)
        guard related.count > 1 else {
            return nil
        }

        let parentCount = parentSessionID(for: session) == nil ? 0 : 1
        let childCount = max(0, related.count - 1 - parentCount)

        if parentCount > 0 && childCount > 0 {
            return "Linked to 1 parent and \(childCount) follow-up session\(childCount == 1 ? "" : "s")."
        }
        if parentCount > 0 {
            return "Linked to an earlier parent session."
        }
        return "Linked to \(childCount) follow-up session\(childCount == 1 ? "" : "s")."
    }

    // MARK: - Grouping

    nonisolated static func extractSummarySections(from markdown: String) -> [SummarySection] {
        let lines = markdown.components(separatedBy: .newlines)
        var sections: [SummarySection] = []
        var currentTitle: String?
        var currentBody: [String] = []

        func flushSection() {
            guard let currentTitle else { return }
            let body = currentBody
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else {
                return
            }
            sections.append(SummarySection(title: currentTitle, body: body))
        }

        for line in lines {
            if line.hasPrefix("## ") {
                flushSection()
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentBody = []
            } else if currentTitle != nil {
                currentBody.append(line)
            }
        }

        flushSection()
        return sections
    }

    nonisolated static func searchCorpus(summary: String?, transcriptLines: [String]) -> String {
        let summaryBody = summary ?? ""
        let transcriptBody = transcriptLines.joined(separator: "\n")
        return [summaryBody, transcriptBody]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private nonisolated static func matchesSearch(
        query: String,
        session: SessionInfo,
        summary: String?,
        transcriptLines: [String]
    ) -> Bool {
        let metadataBlob = [
            session.id,
            session.model,
            session.provider,
            session.status,
            session.trajectoryClassification ?? "",
        ].joined(separator: " ")
        let searchBlob = metadataBlob + "\n" + searchCorpus(summary: summary, transcriptLines: transcriptLines)
        return searchBlob.localizedCaseInsensitiveContains(query)
    }

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

    private func parentSessionID(for session: SessionInfo) -> String? {
        guard let metadata = loadMetadata(for: session),
              let data = metadata.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let candidates = [
            root["parent_session_id"] as? String,
            root["parent_id"] as? String,
            root["parentID"] as? String,
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}
