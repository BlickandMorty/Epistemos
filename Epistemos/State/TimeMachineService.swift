import Foundation
import SwiftData
import os

// MARK: - Time Machine Service
// Reconstructs historical app state at any past date using the EventStore.
// Uses O(log n) snapshot lookup + delta application for near-instant reconstruction.
// Provides diff computation between past and present states.

@MainActor @Observable
final class TimeMachineService {
    private static let log = Logger(subsystem: "com.epistemos", category: "TimeMachine")

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Historical State

    struct HistoricalState {
        let timestamp: Date
        let snapshot: WorkspaceSnapshot?
        let summary: String
        let userNote: String

        // Reconstructed content
        var noteSnapshots: [NoteSnapshot] = []
        var chatSnapshots: [ChatSnapshot] = []
        var graphStats: GraphStats = GraphStats()
    }

    struct NoteSnapshot: Identifiable {
        let id: String // pageId
        let title: String
        let bodyPreview: String // first 500 chars
        let wordCount: Int
        let versionDate: Date?
    }

    struct ChatSnapshot: Identifiable {
        let id: String // chatId
        let title: String
        let messageCount: Int
        let lastMessageDate: Date?
    }

    struct GraphStats {
        var nodeCount: Int = 0
        var edgeCount: Int = 0
    }

    // MARK: - Reconstruct State at Date

    func reconstructState(at date: Date) -> HistoricalState {
        // 1. Find nearest snapshot via EventStore (O(log n))
        guard let stored = EventStore.shared?.nearestSnapshot(before: date) else {
            Self.log.info("TimeMachine: no snapshot found before \(date, privacy: .public)")
            return HistoricalState(timestamp: date, snapshot: nil, summary: "", userNote: "")
        }

        let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: Data(stored.snapshotJSON.utf8))

        var state = HistoricalState(
            timestamp: stored.timestamp,
            snapshot: snapshot,
            summary: stored.summary,
            userNote: stored.userNote
        )

        // 2. Reconstruct note content via SDPageVersion (nearest version before date)
        let context = modelContainer.mainContext
        if let snapshot {
            for tab in snapshot.openNoteTabs {
                let pageId = tab.rootPageId
                let targetDate = date
                let versionDesc = FetchDescriptor<SDPageVersion>(
                    predicate: #Predicate<SDPageVersion> { $0.pageId == pageId && $0.createdAt <= targetDate },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                let version = try? context.fetch(versionDesc).first
                let title = version?.title ?? tab.breadcrumbs.first?.title ?? "Untitled"
                let body = version?.body ?? ""

                state.noteSnapshots.append(NoteSnapshot(
                    id: pageId,
                    title: title,
                    bodyPreview: String(body.prefix(500)),
                    wordCount: version?.wordCount ?? body.split(separator: " ").count,
                    versionDate: version?.createdAt
                ))
            }
        }

        // 3. Reconstruct chat state via SDMessage.createdAt filter
        let chatDate = date
        let chatDesc = FetchDescriptor<SDChat>(
            predicate: #Predicate<SDChat> { $0.createdAt <= chatDate },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        if let chats = try? context.fetch(chatDesc) {
            for chat in chats.prefix(20) {
                let chatId = chat.id
                let msgDesc = FetchDescriptor<SDMessage>(
                    predicate: #Predicate<SDMessage> { $0.chat?.id == chatId && $0.createdAt <= chatDate }
                )
                let msgCount = (try? context.fetchCount(msgDesc)) ?? 0
                state.chatSnapshots.append(ChatSnapshot(
                    id: chat.id,
                    title: chat.title,
                    messageCount: msgCount,
                    lastMessageDate: chat.updatedAt <= date ? chat.updatedAt : nil
                ))
            }
        }

        // 4. Graph stats from SDGraphNode/Edge created before date
        let graphDate = date
        let nodeDesc = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.createdAt <= graphDate }
        )
        let edgeDesc = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate<SDGraphEdge> { $0.createdAt <= graphDate }
        )
        state.graphStats.nodeCount = (try? context.fetchCount(nodeDesc)) ?? 0
        state.graphStats.edgeCount = (try? context.fetchCount(edgeDesc)) ?? 0

        Self.log.info("TimeMachine: reconstructed state at \(date, privacy: .public) — \(state.noteSnapshots.count) notes, \(state.chatSnapshots.count) chats, \(state.graphStats.nodeCount) nodes")
        return state
    }

    // MARK: - Diff Computation (Past vs Present)

    struct StateDiff {
        var addedNotes: [String] = []    // titles
        var removedNotes: [String] = []  // titles
        var modifiedNotes: [NoteDiff] = []
        var addedChats: Int = 0
        var removedChats: Int = 0
        var graphNodeDelta: Int = 0      // positive = added, negative = removed
        var graphEdgeDelta: Int = 0
    }

    struct NoteDiff: Identifiable {
        let id: String
        let title: String
        let wordCountDelta: Int
        let paragraphsChanged: Int
    }

    func computeDiff(from pastState: HistoricalState) -> StateDiff {
        var diff = StateDiff()
        let context = modelContainer.mainContext

        // Current note state
        let currentPages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []
        let currentPageIds = Set(currentPages.map(\.id))
        let pastPageIds = Set(pastState.noteSnapshots.map(\.id))

        // Added notes (exist now, didn't exist then)
        for page in currentPages where !pastPageIds.contains(page.id) {
            diff.addedNotes.append(page.title)
        }

        // Removed notes (existed then, don't exist now)
        for note in pastState.noteSnapshots where !currentPageIds.contains(note.id) {
            diff.removedNotes.append(note.title)
        }

        // Modified notes (exist in both, check word count delta)
        for pastNote in pastState.noteSnapshots {
            guard let currentPage = currentPages.first(where: { $0.id == pastNote.id }) else { continue }
            let currentBody = NoteFileStorage.readBody(pageId: currentPage.id, mapped: true)
            let currentWordCount = currentBody.split(separator: " ").count
            let delta = currentWordCount - pastNote.wordCount
            if delta != 0 {
                diff.modifiedNotes.append(NoteDiff(
                    id: pastNote.id,
                    title: pastNote.title,
                    wordCountDelta: delta,
                    paragraphsChanged: abs(currentBody.components(separatedBy: "\n\n").count - (pastNote.bodyPreview.components(separatedBy: "\n\n").count))
                ))
            }
        }

        // Chat delta
        let currentChatCount = (try? context.fetchCount(FetchDescriptor<SDChat>())) ?? 0
        diff.addedChats = max(0, currentChatCount - pastState.chatSnapshots.count)
        diff.removedChats = max(0, pastState.chatSnapshots.count - currentChatCount)

        // Graph delta
        let currentNodeCount = (try? context.fetchCount(FetchDescriptor<SDGraphNode>())) ?? 0
        let currentEdgeCount = (try? context.fetchCount(FetchDescriptor<SDGraphEdge>())) ?? 0
        diff.graphNodeDelta = currentNodeCount - pastState.graphStats.nodeCount
        diff.graphEdgeDelta = currentEdgeCount - pastState.graphStats.edgeCount

        return diff
    }

    // MARK: - Session Timeline

    func sessionTimeline() -> [EventStore.SnapshotMeta] {
        EventStore.shared?.allSnapshots() ?? []
    }

    func eventDensity(days: Int = 90) -> [Date: Int] {
        EventStore.shared?.eventDensityByDay(days: days) ?? [:]
    }
}
