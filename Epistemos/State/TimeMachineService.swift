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
        let contentSignature: UInt64?

        init(
            id: String,
            title: String,
            bodyPreview: String,
            wordCount: Int,
            versionDate: Date?,
            contentSignature: UInt64? = nil
        ) {
            self.id = id
            self.title = title
            self.bodyPreview = bodyPreview
            self.wordCount = wordCount
            self.versionDate = versionDate
            self.contentSignature = contentSignature
        }
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

        let snapshot: WorkspaceSnapshot?
        do {
            snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: Data(stored.snapshotJSON.utf8))
        } catch {
            Self.log.error("TimeMachine: failed to decode snapshot at \(stored.timestamp, privacy: .public): \(error)")
            snapshot = nil
        }

        var state = HistoricalState(
            timestamp: stored.timestamp,
            snapshot: snapshot,
            summary: stored.summary,
            userNote: stored.userNote
        )

        // 2. Reconstruct note content via SDPageVersion (nearest version before date)
        if let snapshot {
            for tab in snapshot.openNoteTabs {
                let pageId = tab.rootPageId
                let targetDate = date
                let versionDesc = FetchDescriptor<SDPageVersion>(
                    predicate: #Predicate<SDPageVersion> { $0.pageId == pageId && $0.createdAt <= targetDate },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                let version = fetchFirst(versionDesc, label: "note version")
                let title = version?.title ?? tab.breadcrumbs.first?.title ?? "Untitled"

                // Word count priority: snapshot-stored > version record > current file fallback
                let wordCount: Int
                let bodyPreview: String
                let contentBody: String?
                if let version, !version.body.isEmpty {
                    wordCount = version.wordCount > 0 ? version.wordCount : version.body.split(separator: " ").count
                    bodyPreview = String(version.body.prefix(500))
                    contentBody = version.body
                } else if let storedWordCount = tab.wordCount, storedWordCount > 0 {
                    // Use word count captured at snapshot time
                    wordCount = storedWordCount
                    let currentBody = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
                    bodyPreview = String(currentBody.prefix(500))
                    contentBody = currentBody.isEmpty ? nil : currentBody
                } else {
                    // Fallback: read current file (not historically accurate but better than 0)
                    let currentBody = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
                    wordCount = currentBody.split(separator: " ").count
                    bodyPreview = String(currentBody.prefix(500))
                    contentBody = currentBody.isEmpty ? nil : currentBody
                }

                state.noteSnapshots.append(NoteSnapshot(
                    id: pageId,
                    title: title,
                    bodyPreview: bodyPreview,
                    wordCount: wordCount,
                    versionDate: version?.createdAt,
                    contentSignature: contentBody.map(Self.contentSignature(for:))
                ))
            }
        }

        // 3. Reconstruct chat state via SDMessage.createdAt filter
        let chatDate = date
        let chatDesc = FetchDescriptor<SDChat>(
            predicate: #Predicate<SDChat> { $0.createdAt <= chatDate },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let chats = fetchAll(chatDesc, label: "chats")
        for chat in chats.prefix(20) {
            let chatId = chat.id
            let msgDesc = FetchDescriptor<SDMessage>(
                predicate: #Predicate<SDMessage> { $0.chat?.id == chatId && $0.createdAt <= chatDate }
            )
            let msgCount = fetchCount(msgDesc, label: "chat message count")
            state.chatSnapshots.append(ChatSnapshot(
                id: chat.id,
                title: chat.title,
                messageCount: msgCount,
                lastMessageDate: chat.updatedAt <= date ? chat.updatedAt : nil
            ))
        }

        // 4. Graph stats from SDGraphNode/Edge created before date
        let graphDate = date
        let nodeDesc = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.createdAt <= graphDate }
        )
        let edgeDesc = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate<SDGraphEdge> { $0.createdAt <= graphDate }
        )
        state.graphStats.nodeCount = fetchCount(nodeDesc, label: "node count")
        state.graphStats.edgeCount = fetchCount(edgeDesc, label: "edge count")

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

    struct NoteDiffResult {
        let addedTitles: [String]
        let removedTitles: [String]
        let modifiedNotes: [NoteDiff]
    }

    struct CurrentPageSnapshot {
        let id: String
        let title: String
        let body: String
        let wordCount: Int
        let createdAt: Date
        let contentSignature: UInt64?

        init(
            id: String,
            title: String,
            body: String,
            wordCount: Int,
            createdAt: Date,
            contentSignature: UInt64? = nil
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.wordCount = wordCount
            self.createdAt = createdAt
            self.contentSignature = contentSignature
        }
    }

    func computeDiff(from pastState: HistoricalState) -> StateDiff {
        var diff = StateDiff()
        // Current note state
        let currentPages = fetchAll(FetchDescriptor<SDPage>(), label: "current pages")
        let noteDiff = computeNoteDiff(from: pastState, currentPages: currentPages)
        diff.addedNotes = noteDiff.addedTitles
        diff.removedNotes = noteDiff.removedTitles
        diff.modifiedNotes = noteDiff.modifiedNotes

        // Chat delta
        let currentChatCount = fetchCount(
            FetchDescriptor<SDChat>(),
            label: "current chat count"
        )
        diff.addedChats = max(0, currentChatCount - pastState.chatSnapshots.count)
        diff.removedChats = max(0, pastState.chatSnapshots.count - currentChatCount)

        // Graph delta
        let currentNodeCount = fetchCount(
            FetchDescriptor<SDGraphNode>(),
            label: "current graph node count"
        )
        let currentEdgeCount = fetchCount(
            FetchDescriptor<SDGraphEdge>(),
            label: "current graph edge count"
        )
        diff.graphNodeDelta = currentNodeCount - pastState.graphStats.nodeCount
        diff.graphEdgeDelta = currentEdgeCount - pastState.graphStats.edgeCount

        return diff
    }

    func computeNoteDiff(from pastState: HistoricalState, currentPages: [SDPage]) -> NoteDiffResult {
        if let alignedDiff = computeAlignedNoteDiff(from: pastState, currentPages: currentPages) {
            return alignedDiff
        }

        return computeNoteDiff(
            from: pastState,
            currentPageSnapshots: currentPages.map(Self.snapshot(for:))
        )
    }

    func computeNoteDiff(
        from pastState: HistoricalState,
        currentPageSnapshots: [CurrentPageSnapshot]
    ) -> NoteDiffResult {
        if let alignedDiff = computeAlignedNoteDiff(
            from: pastState,
            currentPageSnapshots: currentPageSnapshots
        ) {
            return alignedDiff
        }

        let currentPagesByID = dictionaryByID(currentPageSnapshots, id: \.id, label: "current page")
        let prefetchedBodiesByID = prefetchedPersistedBodies(for: currentPageSnapshots)
        let currentPageIds = Set(currentPagesByID.keys)
        let modifiedNotes = computeModifiedNotes(
            pastNotes: pastState.noteSnapshots,
            currentPagesByID: currentPagesByID,
            prefetchedBodiesByID: prefetchedBodiesByID
        )

        guard let snapshotAllIds = pastState.snapshot?.allPageIds, !snapshotAllIds.isEmpty else {
            let addedTitles = currentPageSnapshots
                .filter { $0.createdAt > pastState.timestamp }
                .map(\.title)
                .sorted()
            return NoteDiffResult(
                addedTitles: addedTitles,
                removedTitles: [],
                modifiedNotes: modifiedNotes
            )
        }

        let pastPageIds = Set(snapshotAllIds)
        let pastTitlesByID = dictionaryByID(pastState.noteSnapshots, id: \.id, label: "historical note")

        let addedTitles = currentPageIds
            .subtracting(pastPageIds)
            .compactMap { currentPagesByID[$0]?.title }
            .sorted()

        let removedTitles = pastPageIds
            .subtracting(currentPageIds)
            .map { pastTitlesByID[$0]?.title ?? "Untitled" }
            .sorted()

        return NoteDiffResult(
            addedTitles: addedTitles,
            removedTitles: removedTitles,
            modifiedNotes: modifiedNotes
        )
    }

    private func computeAlignedNoteDiff(
        from pastState: HistoricalState,
        currentPageSnapshots: [CurrentPageSnapshot]
    ) -> NoteDiffResult? {
        let pastNotes = pastState.noteSnapshots
        guard pastNotes.count == currentPageSnapshots.count,
              let snapshotAllIds = pastState.snapshot?.allPageIds,
              snapshotAllIds.count == currentPageSnapshots.count else {
            return nil
        }
        guard currentPagesAreAligned(pastNotes: pastNotes, currentPages: currentPageSnapshots) else {
            return nil
        }

        return computeAlignedModifiedNotes(
            pastNotes: pastNotes,
            currentPages: currentPageSnapshots,
            hasLiveEditors: false
        )
    }

    private func computeAlignedNoteDiff(
        from pastState: HistoricalState,
        currentPages: [SDPage]
    ) -> NoteDiffResult? {
        let pastNotes = pastState.noteSnapshots
        guard pastNotes.count == currentPages.count,
              let snapshotAllIds = pastState.snapshot?.allPageIds,
              snapshotAllIds.count == currentPages.count else {
            return nil
        }
        guard currentPagesAreAligned(pastNotes: pastNotes, currentPages: currentPages) else {
            return nil
        }

        return computeAlignedModifiedNotes(
            pastNotes: pastNotes,
            currentPages: currentPages.map(Self.snapshot(for:)),
            hasLiveEditors: NoteWindowManager.shared.hasOpenNoteWindows
        )
    }

    private func computeAlignedModifiedNotes(
        pastNotes: [NoteSnapshot],
        currentPages: [CurrentPageSnapshot],
        hasLiveEditors: Bool
    ) -> NoteDiffResult {
        if !hasLiveEditors {
            return computeAlignedModifiedNotesWithoutLiveEditors(
                pastNotes: pastNotes,
                currentPages: currentPages
            )
        }

        var modifiedNotes: [NoteDiff] = []
        modifiedNotes.reserveCapacity(Self.modifiedNoteReserveCapacity(
            pastCount: pastNotes.count,
            currentCount: currentPages.count
        ))
        let prefetchedBodiesByID = prefetchedPersistedBodies(for: currentPages)

        var index = 0
        while index < currentPages.count {
            defer { index += 1 }
            let currentPage = currentPages[index]
            let pastNote = pastNotes[index]
            let currentWordCount = currentWordCount(
                for: currentPage,
                hasLiveEditors: hasLiveEditors,
                prefetchedBodiesByID: prefetchedBodiesByID
            )
            if let noteDiff = buildModifiedNoteDiff(
                pastNote: pastNote,
                currentPage: currentPage,
                currentWordCount: currentWordCount,
                hasLiveEditors: hasLiveEditors,
                prefetchedBodiesByID: prefetchedBodiesByID
            ) {
                modifiedNotes.append(noteDiff)
            }
        }

        return NoteDiffResult(
            addedTitles: [],
            removedTitles: [],
            modifiedNotes: modifiedNotes
        )
    }

    private func computeAlignedModifiedNotesWithoutLiveEditors(
        pastNotes: [NoteSnapshot],
        currentPages: [CurrentPageSnapshot]
    ) -> NoteDiffResult {
        let prefetchedBodiesByID = prefetchedPersistedBodies(for: currentPages)
        var modifiedNotes: [NoteDiff] = []
        modifiedNotes.reserveCapacity(Self.modifiedNoteReserveCapacity(
            pastCount: pastNotes.count,
            currentCount: currentPages.count
        ))

        var index = 0
        while index < currentPages.count {
            let currentPage = currentPages[index]
            let pastNote = pastNotes[index]
            let currentWordCount = currentWordCount(
                for: currentPage,
                hasLiveEditors: false,
                prefetchedBodiesByID: prefetchedBodiesByID
            )
            if let noteDiff = buildModifiedNoteDiff(
                pastNote: pastNote,
                currentPage: currentPage,
                currentWordCount: currentWordCount,
                hasLiveEditors: false,
                prefetchedBodiesByID: prefetchedBodiesByID
            ) {
                modifiedNotes.append(noteDiff)
            }

            index += 1
        }

        return NoteDiffResult(
            addedTitles: [],
            removedTitles: [],
            modifiedNotes: modifiedNotes
        )
    }

    private func computeModifiedNotes(
        pastNotes: [NoteSnapshot],
        currentPagesByID: [String: CurrentPageSnapshot],
        prefetchedBodiesByID: [String: String]
    ) -> [NoteDiff] {
        let hasLiveEditors = NoteWindowManager.shared.hasOpenNoteWindows
        var modifiedNotes: [NoteDiff] = []
        modifiedNotes.reserveCapacity(Self.modifiedNoteReserveCapacity(
            pastCount: pastNotes.count,
            currentCount: currentPagesByID.count
        ))

        for pastNote in pastNotes {
            guard let currentPage = currentPagesByID[pastNote.id] else {
                continue
            }

            let currentWordCount = currentWordCount(
                for: currentPage,
                hasLiveEditors: hasLiveEditors,
                prefetchedBodiesByID: prefetchedBodiesByID
            )
            if let noteDiff = buildModifiedNoteDiff(
                pastNote: pastNote,
                currentPage: currentPage,
                currentWordCount: currentWordCount,
                hasLiveEditors: hasLiveEditors,
                prefetchedBodiesByID: prefetchedBodiesByID
            ) {
                modifiedNotes.append(noteDiff)
            }
        }

        return modifiedNotes
    }

    private func buildModifiedNoteDiff(
        pastNote: NoteSnapshot,
        currentPage: CurrentPageSnapshot,
        currentWordCount: Int,
        hasLiveEditors: Bool,
        prefetchedBodiesByID: [String: String]
    ) -> NoteDiff? {
        let wordCountDelta = currentWordCount - pastNote.wordCount
        let contentChanged = {
            guard let pastContentSignature = pastNote.contentSignature,
                  let currentContentSignature = currentContentSignature(
                    for: currentPage,
                    hasLiveEditors: hasLiveEditors,
                    prefetchedBodiesByID: prefetchedBodiesByID
                  ) else {
                return false
            }
            return pastContentSignature != currentContentSignature
        }()

        var paragraphDelta = 0
        if (contentChanged || wordCountDelta != 0),
           let currentBody = currentBodyForDiff(
                for: currentPage,
                hasLiveEditors: hasLiveEditors,
                prefetchedBodiesByID: prefetchedBodiesByID
           ) {
            let pastHasParagraphBreaks = pastNote.bodyPreview.contains("\n\n")
            let currentHasParagraphBreaks = currentBody.contains("\n\n")
            if pastHasParagraphBreaks || currentHasParagraphBreaks {
                let currentParagraphs = Self.paragraphCount(in: currentBody)
                let pastParagraphs = Self.paragraphCount(in: pastNote.bodyPreview)
                paragraphDelta = abs(currentParagraphs - pastParagraphs)
            }
        }

        guard contentChanged || wordCountDelta != 0 || paragraphDelta != 0 else {
            return nil
        }

        return NoteDiff(
            id: pastNote.id,
            title: pastNote.title,
            wordCountDelta: wordCountDelta,
            paragraphsChanged: paragraphDelta
        )
    }

    private func dictionaryByID<T>(
        _ values: [T],
        id: KeyPath<T, String>,
        label: String
    ) -> [String: T] {
        var byID: [String: T] = [:]
        byID.reserveCapacity(values.count)

        var duplicateCount = 0
        for value in values {
            let valueID = value[keyPath: id]
            if byID[valueID] == nil {
                byID[valueID] = value
            } else {
                duplicateCount += 1
            }
        }

        if duplicateCount > 0 {
            let message = "Duplicate \(label) IDs detected: \(values.count) values, \(byID.count) unique IDs"
            Self.log.fault("\(message, privacy: .public)")
        }

        return byID
    }

    private func currentPagesAreAligned(
        pastNotes: [NoteSnapshot],
        currentPages: [SDPage]
    ) -> Bool {
        var index = 0
        while index < currentPages.count {
            if pastNotes[index].id != currentPages[index].id {
                return false
            }
            index += 1
        }
        return true
    }

    private func currentPagesAreAligned(
        pastNotes: [NoteSnapshot],
        currentPages: [CurrentPageSnapshot]
    ) -> Bool {
        var index = 0
        while index < currentPages.count {
            if pastNotes[index].id != currentPages[index].id {
                return false
            }
            index += 1
        }
        return true
    }

    private func currentWordCount(
        for page: CurrentPageSnapshot,
        hasLiveEditors: Bool,
        prefetchedBodiesByID: [String: String]
    ) -> Int {
        if hasLiveEditors, let liveBody = NoteWindowManager.shared.editorBody(for: page.id) {
            return Self.wordCount(in: liveBody)
        }
        if page.wordCount > 0 {
            return page.wordCount
        }
        if let currentBody = currentBodyForDiff(
            for: page,
            hasLiveEditors: hasLiveEditors,
            prefetchedBodiesByID: prefetchedBodiesByID
        ) {
            return Self.wordCount(in: currentBody)
        }
        return 0
    }

    private func currentBodyForDiff(
        for page: CurrentPageSnapshot,
        hasLiveEditors: Bool,
        prefetchedBodiesByID: [String: String]
    ) -> String? {
        if hasLiveEditors, let liveBody = NoteWindowManager.shared.editorBody(for: page.id) {
            return liveBody
        }
        if !page.body.isEmpty {
            return page.body
        }
        return prefetchedBodiesByID[page.id]
    }

    private func currentContentSignature(
        for page: CurrentPageSnapshot,
        hasLiveEditors: Bool,
        prefetchedBodiesByID: [String: String]
    ) -> UInt64? {
        if hasLiveEditors, let liveBody = NoteWindowManager.shared.editorBody(for: page.id) {
            return Self.contentSignature(for: liveBody)
        }
        if let contentSignature = page.contentSignature {
            return contentSignature
        }
        if let currentBody = currentBodyForDiff(
            for: page,
            hasLiveEditors: hasLiveEditors,
            prefetchedBodiesByID: prefetchedBodiesByID
        ) {
            return Self.contentSignature(for: currentBody)
        }
        return nil
    }

    private static func wordCount(in body: String) -> Int {
        body.split(whereSeparator: \.isWhitespace).count
    }

    nonisolated static func contentSignature(for body: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in body.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private func prefetchedPersistedBodies(for currentPages: [CurrentPageSnapshot]) -> [String: String] {
        let candidates = currentPages.filter { $0.body.isEmpty && $0.contentSignature == nil }
        guard !candidates.isEmpty else { return [:] }

        var bodiesByID: [String: String] = [:]
        bodiesByID.reserveCapacity(candidates.count)
        for page in candidates {
            let pageId = page.id
            let persistedBody = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
            if !persistedBody.isEmpty {
                bodiesByID[pageId] = persistedBody
            }
        }
        return bodiesByID
    }

    private func prefetchedPersistedBodies(for currentPages: [SDPage]) -> [String: String] {
        let candidates = currentPages.filter { $0.body.isEmpty }
        guard !candidates.isEmpty else { return [:] }

        var bodiesByID: [String: String] = [:]
        bodiesByID.reserveCapacity(candidates.count)
        for page in candidates {
            let pageId = page.id
            let persistedBody = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
            if !persistedBody.isEmpty {
                bodiesByID[pageId] = persistedBody
            }
        }
        return bodiesByID
    }

    private static func snapshot(for page: SDPage) -> CurrentPageSnapshot {
        CurrentPageSnapshot(
            id: page.id,
            title: page.title,
            body: page.body,
            wordCount: page.wordCount,
            createdAt: page.createdAt,
            contentSignature: page.body.isEmpty ? nil : contentSignature(for: page.body)
        )
    }

    private static func paragraphCount(in body: String) -> Int {
        let paragraphs = body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return max(paragraphs.count, body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }

    private static func modifiedNoteReserveCapacity(pastCount: Int, currentCount: Int) -> Int {
        let upperBound = min(pastCount, currentCount)
        guard upperBound > 64 else { return upperBound }
        return max(64, upperBound / 8)
    }

    private func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> T? {
        do {
            return try modelContainer.mainContext.fetch(descriptor).first
        } catch {
            Self.log.error("TimeMachine: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func fetchAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> [T] {
        do {
            return try modelContainer.mainContext.fetch(descriptor)
        } catch {
            Self.log.error("TimeMachine: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func fetchCount<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> Int {
        do {
            return try modelContainer.mainContext.fetchCount(descriptor)
        } catch {
            Self.log.error("TimeMachine: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    // MARK: - Session Timeline

    func sessionTimeline() -> [EventStore.SnapshotMeta] {
        EventStore.shared?.allSnapshots() ?? []
    }

    func eventDensity(days: Int = 90) -> [Date: Int] {
        EventStore.shared?.eventDensityByDay(days: days) ?? [:]
    }
}
