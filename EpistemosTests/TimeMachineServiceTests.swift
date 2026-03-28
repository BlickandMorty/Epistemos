import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("TimeMachineService")
@MainActor
struct TimeMachineServiceTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            SDPage.self,
            SDChat.self,
            SDMessage.self,
            SDGraphNode.self,
            SDGraphEdge.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeSnapshot(allPageIds: [String]?) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            activePanel: "notes",
            activeChatId: nil,
            showChatSidebar: false,
            showLanding: false,
            openNoteTabs: [],
            activeNoteTabPageId: nil,
            openMiniChatIds: [],
            notesBrowserVisible: true,
            settingsVisible: false,
            graphOverlay: GraphOverlaySnapshot(visibility: .hidden, selectedNodeId: nil),
            expandedFolderIds: [],
            isJournalExpanded: false,
            isIdeasExpanded: false,
            activityDigest: nil,
            totalNoteCount: allPageIds?.count,
            allPageIds: allPageIds
        )
    }

    private func makePastState(
        timestamp: Date,
        noteSnapshots: [TimeMachineService.NoteSnapshot],
        allPageIds: [String]?
    ) -> TimeMachineService.HistoricalState {
        TimeMachineService.HistoricalState(
            timestamp: timestamp,
            snapshot: makeSnapshot(allPageIds: allPageIds),
            summary: "",
            userNote: "",
            noteSnapshots: noteSnapshots,
            chatSnapshots: [],
            graphStats: .init()
        )
    }

    private func makePage(id: String, title: String, body: String, createdAt: Date) -> SDPage {
        let page = SDPage(title: title)
        page.id = id
        page.createdAt = createdAt
        page.body = body
        page.wordCount = body.split(separator: " ").count
        return page
    }

    @Test("computeDiff uses vault-wide snapshot IDs for added, removed, and modified notes")
    func computeDiffUsesSnapshotAllPageIds() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = TimeMachineService(modelContainer: container)
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("time-machine-tests-\(UUID().uuidString)", isDirectory: true)
        NoteFileStorage.setStorageDirectoryOverrideForTesting(storageURL)
        defer {
            NoteFileStorage.setStorageDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: storageURL)
        }

        let kept = SDPage(title: "Kept")
        kept.id = "kept-note"
        kept.createdAt = Date(timeIntervalSince1970: 10)
        kept.saveBody("alpha beta gamma\na\n\nb\n\nc")
        context.insert(kept)

        let added = SDPage(title: "Added")
        added.id = "added-note"
        added.createdAt = Date(timeIntervalSince1970: 5)
        added.saveBody("delta epsilon")
        context.insert(added)

        try context.save()

        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [
                .init(
                    id: kept.id,
                    title: kept.title,
                    bodyPreview: "alpha beta",
                    wordCount: 2,
                    versionDate: nil
                ),
                .init(
                    id: "removed-note",
                    title: "Removed",
                    bodyPreview: "gone",
                    wordCount: 1,
                    versionDate: nil
                ),
            ],
            allPageIds: [kept.id, "removed-note"]
        )

        let diff = service.computeDiff(from: pastState)

        #expect(diff.addedNotes == ["Added"])
        #expect(diff.removedNotes == ["Removed"])
        #expect(diff.modifiedNotes.count == 1)
        #expect(diff.modifiedNotes.first?.id == kept.id)
        #expect(diff.modifiedNotes.first?.wordCountDelta == 4)
        #expect(diff.modifiedNotes.first?.paragraphsChanged == 2)
    }

    @Test("computeDiff fallback only counts notes created after the snapshot date")
    func computeDiffFallbackUsesSnapshotDateForAddedNotes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = TimeMachineService(modelContainer: container)
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("time-machine-tests-\(UUID().uuidString)", isDirectory: true)
        NoteFileStorage.setStorageDirectoryOverrideForTesting(storageURL)
        defer {
            NoteFileStorage.setStorageDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: storageURL)
        }

        let existing = SDPage(title: "Existing")
        existing.id = "existing-note"
        existing.createdAt = Date(timeIntervalSince1970: 50)
        existing.saveBody("one two three four")
        context.insert(existing)

        let olderUntracked = SDPage(title: "Older Untracked")
        olderUntracked.id = "older-untracked"
        olderUntracked.createdAt = Date(timeIntervalSince1970: 60)
        olderUntracked.saveBody("historical body")
        context.insert(olderUntracked)

        let newer = SDPage(title: "Newer")
        newer.id = "newer-note"
        newer.createdAt = Date(timeIntervalSince1970: 200)
        newer.saveBody("fresh body text")
        context.insert(newer)

        try context.save()

        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [
                .init(
                    id: existing.id,
                    title: existing.title,
                    bodyPreview: "one two",
                    wordCount: 2,
                    versionDate: nil
                ),
            ],
            allPageIds: nil
        )

        let diff = service.computeDiff(from: pastState)

        #expect(diff.addedNotes == ["Newer"])
        #expect(diff.removedNotes.isEmpty)
        #expect(diff.modifiedNotes.count == 1)
        #expect(diff.modifiedNotes.first?.id == existing.id)
        #expect(diff.modifiedNotes.first?.wordCountDelta == 2)
    }

    @Test("computeNoteDiff returns no changes for empty past and current note sets")
    func computeNoteDiffEmptySets() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [],
            allPageIds: []
        )

        let diff = service.computeNoteDiff(from: pastState, currentPages: [])

        #expect(diff.addedTitles.isEmpty)
        #expect(diff.removedTitles.isEmpty)
        #expect(diff.modifiedNotes.isEmpty)
    }

    @Test("computeNoteDiff preserves past snapshot order for modified notes")
    func computeNoteDiffPreservesPastOrderForModifiedNotes() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [
                .init(id: "b-note", title: "B note", bodyPreview: "alpha", wordCount: 1, versionDate: nil),
                .init(id: "a-note", title: "A note", bodyPreview: "alpha", wordCount: 1, versionDate: nil),
            ],
            allPageIds: ["b-note", "a-note"]
        )

        let currentPages = [
            makePage(id: "b-note", title: "B note", body: "alpha beta", createdAt: Date(timeIntervalSince1970: 10)),
            makePage(id: "a-note", title: "A note", body: "alpha beta", createdAt: Date(timeIntervalSince1970: 10)),
        ]

        let diff = service.computeNoteDiff(from: pastState, currentPages: currentPages)

        #expect(diff.modifiedNotes.map(\.id) == ["b-note", "a-note"])
    }

    @Test("computeNoteDiff keeps the first duplicate current page ID instead of crashing")
    func computeNoteDiffDuplicateCurrentIDs() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let duplicateID = "duplicate-note"
        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [
                .init(
                    id: duplicateID,
                    title: "Original",
                    bodyPreview: "alpha beta",
                    wordCount: 2,
                    versionDate: nil
                )
            ],
            allPageIds: [duplicateID]
        )

        let currentPages = [
            makePage(
                id: duplicateID,
                title: "First",
                body: "alpha beta gamma",
                createdAt: Date(timeIntervalSince1970: 50)
            ),
            makePage(
                id: duplicateID,
                title: "Second",
                body: "alpha beta gamma delta epsilon",
                createdAt: Date(timeIntervalSince1970: 60)
            ),
        ]

        let diff = service.computeNoteDiff(from: pastState, currentPages: currentPages)

        #expect(diff.addedTitles.isEmpty)
        #expect(diff.removedTitles.isEmpty)
        #expect(diff.modifiedNotes.count == 1)
        #expect(diff.modifiedNotes[0].id == duplicateID)
        #expect(diff.modifiedNotes[0].title == "Original")
        #expect(diff.modifiedNotes[0].wordCountDelta == 1)
    }

    @Test("computeNoteDiff detects same-length rewrites when content changes")
    func computeNoteDiffDetectsSameLengthRewrite() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let originalBody = "alpha beta gamma"
        let rewrittenBody = "delta beta gamma"
        let noteID = "same-length-rewrite"
        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [
                .init(
                    id: noteID,
                    title: "Original",
                    bodyPreview: String(originalBody.prefix(500)),
                    wordCount: 3,
                    versionDate: nil,
                    contentSignature: TimeMachineService.contentSignature(for: originalBody)
                )
            ],
            allPageIds: [noteID]
        )

        let currentSnapshots = [
            TimeMachineService.CurrentPageSnapshot(
                id: noteID,
                title: "Original",
                body: rewrittenBody,
                wordCount: 3,
                createdAt: Date(timeIntervalSince1970: 100),
                contentSignature: TimeMachineService.contentSignature(for: rewrittenBody)
            )
        ]

        let diff = service.computeNoteDiff(from: pastState, currentPageSnapshots: currentSnapshots)

        #expect(diff.addedTitles.isEmpty)
        #expect(diff.removedTitles.isEmpty)
        #expect(diff.modifiedNotes.count == 1)
        #expect(diff.modifiedNotes[0].id == noteID)
        #expect(diff.modifiedNotes[0].wordCountDelta == 0)
    }

    @Test("computeNoteDiff detects same-length rewrites in aligned snapshots when only persisted bodies changed")
    func computeNoteDiffDetectsPersistedSameLengthRewriteInAlignedSnapshots() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let originalBody = "alpha beta gamma"
        let rewrittenBody = "delta beta gamma"
        let noteID = "aligned-persisted-rewrite"
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("time-machine-tests-\(UUID().uuidString)", isDirectory: true)
        NoteFileStorage.setStorageDirectoryOverrideForTesting(storageURL)
        defer {
            NoteFileStorage.setStorageDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: storageURL)
        }

        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [
                .init(
                    id: noteID,
                    title: "Original",
                    bodyPreview: String(originalBody.prefix(500)),
                    wordCount: 3,
                    versionDate: nil,
                    contentSignature: TimeMachineService.contentSignature(for: originalBody)
                )
            ],
            allPageIds: [noteID]
        )

        let persistedPage = SDPage(title: "Original")
        persistedPage.id = noteID
        persistedPage.saveBody(rewrittenBody)

        let currentSnapshots = [
            TimeMachineService.CurrentPageSnapshot(
                id: noteID,
                title: "Original",
                body: "",
                wordCount: 3,
                createdAt: Date(timeIntervalSince1970: 100),
                contentSignature: nil
            )
        ]

        let diff = service.computeNoteDiff(from: pastState, currentPageSnapshots: currentSnapshots)

        #expect(diff.addedTitles.isEmpty)
        #expect(diff.removedTitles.isEmpty)
        #expect(diff.modifiedNotes.count == 1)
        #expect(diff.modifiedNotes[0].id == noteID)
        #expect(diff.modifiedNotes[0].wordCountDelta == 0)
    }

    @Test("computeNoteDiff detects same-length rewrites for live SDPage snapshots")
    func computeNoteDiffDetectsSameLengthRewriteForLivePages() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let originalBody = "alpha beta gamma"
        let rewrittenBody = "delta beta gamma"
        let noteID = "same-length-rewrite-live"
        let pastState = makePastState(
            timestamp: Date(timeIntervalSince1970: 100),
            noteSnapshots: [
                .init(
                    id: noteID,
                    title: "Original",
                    bodyPreview: String(originalBody.prefix(500)),
                    wordCount: 3,
                    versionDate: nil,
                    contentSignature: TimeMachineService.contentSignature(for: originalBody)
                )
            ],
            allPageIds: [noteID]
        )

        let currentPages = [
            makePage(
                id: noteID,
                title: "Original",
                body: rewrittenBody,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        ]

        let diff = service.computeNoteDiff(from: pastState, currentPages: currentPages)

        #expect(diff.addedTitles.isEmpty)
        #expect(diff.removedTitles.isEmpty)
        #expect(diff.modifiedNotes.count == 1)
        #expect(diff.modifiedNotes[0].id == noteID)
        #expect(diff.modifiedNotes[0].wordCountDelta == 0)
    }

    @Test("computeNoteDiff audit scenario reports exact added removed and modified counts")
    func computeNoteDiffAuditScenarioCounts() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let baseDate = Date(timeIntervalSince1970: 100)
        let totalPast = 1_000
        let removedCount = 50
        let addedCount = 50
        let modifiedCount = 100

        let pastIDs = (0..<totalPast).map { "note-\($0)" }
        let currentIDs = (removedCount..<totalPast).map { "note-\($0)" }
            + (totalPast..<(totalPast + addedCount)).map { "note-\($0)" }

        let pastState = makePastState(
            timestamp: baseDate,
            noteSnapshots: pastIDs.map { id in
                TimeMachineService.NoteSnapshot(
                    id: id,
                    title: id,
                    bodyPreview: "stable body",
                    wordCount: 2,
                    versionDate: nil,
                    contentSignature: TimeMachineService.contentSignature(for: "stable body")
                )
            },
            allPageIds: pastIDs
        )

        let currentSnapshots = currentIDs.map { id in
            let numericID = Int(id.split(separator: "-").last ?? "") ?? 0
            let body = if numericID >= removedCount && numericID < removedCount + modifiedCount {
                "changed body"
            } else {
                "stable body"
            }
            return TimeMachineService.CurrentPageSnapshot(
                id: id,
                title: id,
                body: body,
                wordCount: body.split(separator: " ").count,
                createdAt: baseDate,
                contentSignature: TimeMachineService.contentSignature(for: body)
            )
        }

        let diff = service.computeNoteDiff(from: pastState, currentPageSnapshots: currentSnapshots)

        #expect(diff.addedTitles.count == addedCount)
        #expect(diff.removedTitles.count == removedCount)
        #expect(diff.modifiedNotes.count == modifiedCount)
    }

    @Test("computeNoteDiff stays under the 10k note audit budget")
    func computeNoteDiffPerformance10KNotes() throws {
        let container = try makeContainer()
        let service = TimeMachineService(modelContainer: container)
        let count = 10_000
        let baseDate = Date(timeIntervalSince1970: 100)

        let pastNotes = (0..<count).map { index in
            TimeMachineService.NoteSnapshot(
                id: "note-\(index)",
                title: "Note \(index)",
                bodyPreview: index.isMultiple(of: 10) ? "alpha beta" : "alpha beta gamma",
                wordCount: index.isMultiple(of: 10) ? 2 : 3,
                versionDate: nil
            )
        }
        let currentSnapshots = (0..<count).map { index in
            TimeMachineService.CurrentPageSnapshot(
                id: "note-\(index)",
                title: "Note \(index)",
                body: "alpha beta gamma",
                wordCount: 3,
                createdAt: baseDate
            )
        }
        let pastState = makePastState(
            timestamp: baseDate,
            noteSnapshots: pastNotes,
            allPageIds: currentSnapshots.map(\.id)
        )

        let warmupDiff = service.computeNoteDiff(from: pastState, currentPageSnapshots: currentSnapshots)
        #expect(warmupDiff.modifiedNotes.count == count / 10)

        var measuredModifiedCount = 0
        let elapsed = measure(iterations: 3) {
            let diff = service.computeNoteDiff(from: pastState, currentPageSnapshots: currentSnapshots)
            measuredModifiedCount = diff.modifiedNotes.count
        }

        #expect(measuredModifiedCount == count / 10)
        #expect(elapsed < .milliseconds(8), "10k note diff took \(elapsed)")
    }
}
