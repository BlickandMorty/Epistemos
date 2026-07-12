import Foundation
import GRDB
import Testing
@testable import Epistemos

@Suite("Editor provenance store")
struct EditorProvenanceStoreTests {
    @Test("suggestion spans persist, decide, and query by turn")
    func suggestionSpansPersistDecideAndQueryByTurn() async throws {
        let store = EditorProvenanceGRDBStore(databaseWriter: try DatabaseQueue())
        let span = Self.span(
            id: "span-1",
            turnID: "turn-a",
            createdAt: 10,
            claimID: "claim:span-1"
        )

        try await store.insert(span)

        let pending = try await store.pendingAgentSpans(turnID: "turn-a")
        #expect(pending.map(\.id) == ["span-1"])
        #expect(pending[0].claimID == "claim:span-1")
        #expect(pending[0].source == .agent)
        #expect(pending[0].state == .pending)

        try await store.decide(
            id: "span-1",
            state: .accepted,
            decidedAt: Date(timeIntervalSince1970: 20)
        )

        #expect(try await store.pendingAgentSpans(turnID: "turn-a").isEmpty)
        let decided = try await store.spans(turnID: "turn-a")
        #expect(decided.count == 1)
        #expect(decided[0].state == .accepted)
        #expect(decided[0].decidedAt == Date(timeIntervalSince1970: 20))
        #expect(decided[0].beforeText == "before-span-1")
        #expect(decided[0].afterText == "after-span-1")
        #expect(decided[0].sourceCitation == "source-span-1")
    }

    @Test("compaction trims resolved spans into per-turn summary but keeps pending spans")
    func compactionTrimsResolvedSpansIntoPerTurnSummary() async throws {
        let store = EditorProvenanceGRDBStore(databaseWriter: try DatabaseQueue())
        for index in 0..<4 {
            let id = "resolved-\(index)"
            try await store.insert(
                Self.span(id: id, turnID: "turn-c", createdAt: Double(index + 1), claimID: "claim:\(id)")
            )
            try await store.decide(
                id: id,
                state: index == 1 ? .rejected : .accepted,
                decidedAt: Date(timeIntervalSince1970: Double(100 + index))
            )
        }
        try await store.insert(
            Self.span(id: "pending", turnID: "turn-c", createdAt: 200, claimID: "claim:pending")
        )

        try await store.compact(keepResolvedMost: 1)

        let remaining = try await store.spans(turnID: "turn-c")
        #expect(remaining.contains { $0.id == "pending" && $0.state == .pending })
        #expect(remaining.filter { $0.state != .pending }.count == 1)
        #expect(remaining.contains { $0.id == "resolved-3" })

        let summaries = try await store.compactionSummaries()
        #expect(summaries.count == 1)
        #expect(summaries[0].noteRelativePath == "notes/lumen.md")
        #expect(summaries[0].turnID == "turn-c")
        #expect(summaries[0].acceptedCount == 2)
        #expect(summaries[0].rejectedCount == 1)
        #expect(summaries[0].claimIDs.contains("claim:resolved-0"))
        #expect(summaries[0].claimIDs.contains("claim:resolved-1"))
        #expect(summaries[0].claimIDs.contains("claim:resolved-2"))

        try await store.insert(
            Self.span(id: "resolved-4", turnID: "turn-c", createdAt: 300, claimID: "claim:resolved-4")
        )
        try await store.decide(
            id: "resolved-4",
            state: .accepted,
            decidedAt: Date(timeIntervalSince1970: 300)
        )

        try await store.compact(keepResolvedMost: 1)

        let secondPassSummaries = try await store.compactionSummaries()
        #expect(secondPassSummaries.count == 1)
        #expect(secondPassSummaries[0].acceptedCount == 3)
        #expect(secondPassSummaries[0].rejectedCount == 1)
        #expect(secondPassSummaries[0].claimIDs.contains("claim:resolved-0"))
        #expect(secondPassSummaries[0].claimIDs.contains("claim:resolved-1"))
        #expect(secondPassSummaries[0].claimIDs.contains("claim:resolved-2"))
        #expect(secondPassSummaries[0].claimIDs.contains("claim:resolved-3"))
    }

    @Test("deciding a missing span fails instead of silently mutating nothing")
    func decidingMissingSpanFails() async throws {
        let store = EditorProvenanceGRDBStore(databaseWriter: try DatabaseQueue())

        await #expect(throws: EditorProvenanceStoreError.spanNotFound("missing")) {
            try await store.decide(
                id: "missing",
                state: .accepted,
                decidedAt: Date(timeIntervalSince1970: 1)
            )
        }
    }

    @Test("duplicate span ids fail without overwriting the original row")
    func duplicateSpanIDsFailWithoutOverwritingOriginalRow() async throws {
        let store = EditorProvenanceGRDBStore(databaseWriter: try DatabaseQueue())

        try await store.insert(
            Self.span(id: "duplicate", turnID: "turn-dup", createdAt: 1, claimID: "claim:original")
        )

        var didThrow = false
        do {
            try await store.insert(
                Self.span(id: "duplicate", turnID: "turn-dup", createdAt: 2, claimID: "claim:replacement")
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        let spans = try await store.spans(turnID: "turn-dup")
        #expect(spans.count == 1)
        #expect(spans[0].claimID == "claim:original")
        #expect(spans[0].createdAt == Date(timeIntervalSince1970: 1))
    }

    @Test("bridge sink persists applied spans and resolution decisions")
    func bridgeSinkPersistsAppliedSpansAndResolutionDecisions() async throws {
        let store = EditorProvenanceGRDBStore(databaseWriter: try DatabaseQueue())
        let sink = EditorProvenanceBridgeSink(store: store, noteRelativePath: "notes/bridge.md")

        try await sink.persistApplied(
            EpdocSuggestionSpanPayload(
                id: "agent-bridge",
                author: "lumen",
                turnID: "turn-bridge",
                kind: "replacement",
                from: 2,
                to: 8,
                mapVersion: 3,
                before: "before",
                after: "after",
                rationale: "rationale",
                sourceCitation: "claim://bridge",
                claimID: "claim:bridge"
            ),
            createdAt: Date(timeIntervalSince1970: 10)
        )

        try await sink.persistResolved(
            EpdocSuggestionResolution(suggestionID: "agent-bridge", state: .rejected),
            decidedAt: Date(timeIntervalSince1970: 33)
        )

        let spans = try await store.spans(turnID: "turn-bridge")
        #expect(spans.count == 1)
        #expect(spans[0].noteRelativePath == "notes/bridge.md")
        #expect(spans[0].state == .rejected)
        #expect(spans[0].decidedAt == Date(timeIntervalSince1970: 33))
        #expect(spans[0].kind == "replacement")
        #expect(spans[0].fromPos == 2)
        #expect(spans[0].toPos == 8)
        #expect(spans[0].mapVersion == 3)
        #expect(spans[0].sourceCitation == "claim://bridge")
        #expect(spans[0].claimID == "claim:bridge")
    }

    @MainActor
    @Test("markdown document surface applies minimal writeback regions before saving")
    func markdownDocumentSurfaceAppliesMinimalWritebackRegionsBeforeSaving() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var savedMarkdown: [String] = []
        let baseline = "Alpha\n\nBravo\n\nCharlie\n"
        let edited = "Alpha\n\nBravo updated\n\nCharlie\n"

        coordinator.configure(
            pageId: "writeback-page",
            title: "Writeback Page",
            markdown: baseline,
            theme: .light,
            noteRelativePath: "notes/writeback.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )

        coordinator.controller.handleBridgeMessage(
            .markdownDidChange(
                markdown: edited,
                writeback: EpdocMarkdownWritebackRegion(
                    byteFrom: 7,
                    byteTo: 12,
                    codeUnitFrom: 7,
                    codeUnitTo: 12,
                    changedFrom: 2,
                    changedTo: 3,
                    blockIndexFrom: 1,
                    blockIndexTo: 1,
                    blockMarkdown: "Bravo updated"
                )
            ),
            epoch: 1
        )
        await coordinator.flushPendingMarkdown()

        #expect(savedMarkdown == [edited])
    }

    @MainActor
    @Test("markdown document surface falls back to full markdown when writeback validation fails")
    func markdownDocumentSurfaceFallsBackToFullMarkdownWhenWritebackValidationFails() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var savedMarkdown: [String] = []
        let baseline = "Alpha\n\nBravo\n\nCharlie\n"
        let edited = "Alpha\n\nBravo updated\n\nCharlie\n"

        coordinator.configure(
            pageId: "writeback-fallback-page",
            title: "Writeback Fallback Page",
            markdown: baseline,
            theme: .light,
            noteRelativePath: "notes/writeback-fallback.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )

        coordinator.controller.handleBridgeMessage(
            .markdownDidChange(
                markdown: edited,
                writeback: EpdocMarkdownWritebackRegion(
                    byteFrom: 7,
                    byteTo: 99,
                    codeUnitFrom: 7,
                    codeUnitTo: 12,
                    changedFrom: 2,
                    changedTo: 3,
                    blockIndexFrom: 1,
                    blockIndexTo: 1,
                    blockMarkdown: "corrupt partial"
                )
            ),
            epoch: 1
        )
        await coordinator.flushPendingMarkdown()

        #expect(savedMarkdown == [edited])
    }

    @MainActor
    @Test("markdown document surface persists suggestion events from the chrome controller")
    func markdownDocumentSurfacePersistsSuggestionEventsFromChromeController() async throws {
        let store = EditorProvenanceGRDBStore(databaseWriter: try DatabaseQueue())
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "surface-page",
            title: "Surface Page",
            markdown: "Alpha beta",
            theme: .light,
            noteRelativePath: "notes/surface.md",
            isEditable: true,
            isActive: true,
            provenanceStore: store,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )

        let payload = EpdocSuggestionSpanPayload(
            id: "surface-span",
            author: "lumen",
            turnID: "turn-surface",
            kind: "replacement",
            from: 6,
            to: 10,
            mapVersion: 4,
            before: "beta",
            after: "delta",
            rationale: "surface handoff",
            sourceCitation: "claim://surface",
            claimID: "claim:surface"
        )

        coordinator.controller.handleBridgeMessage(.suggestionApplied(payload), epoch: 1)
        coordinator.controller.handleBridgeMessage(
            .suggestionResolved(
                EpdocSuggestionResolution(suggestionID: "surface-span", state: .accepted)
            ),
            epoch: 1
        )
        await coordinator.flushPendingProvenanceWrites()

        let spans = try await store.spans(turnID: "turn-surface")
        #expect(spans.count == 1)
        #expect(spans[0].noteRelativePath == "notes/surface.md")
        #expect(spans[0].state == .accepted)
        #expect(spans[0].kind == "replacement")
        #expect(spans[0].fromPos == 6)
        #expect(spans[0].toPos == 10)
        #expect(spans[0].mapVersion == 4)
        #expect(spans[0].beforeText == "beta")
        #expect(spans[0].afterText == "delta")
        #expect(spans[0].rationale == "surface handoff")
        #expect(spans[0].sourceCitation == "claim://surface")
        #expect(spans[0].claimID == "claim:surface")
        #expect(savedMarkdown.isEmpty)
    }

    @MainActor
    @Test("markdown document surface teardown flushes markdown and provenance writes")
    func markdownDocumentSurfaceTeardownFlushesMarkdownAndProvenanceWrites() async throws {
        let store = EditorProvenanceGRDBStore(databaseWriter: try DatabaseQueue())
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "teardown-page",
            title: "Teardown Page",
            markdown: "Alpha\n\nBravo\n",
            theme: .light,
            noteRelativePath: "notes/teardown.md",
            isEditable: true,
            isActive: true,
            provenanceStore: store,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )

        coordinator.controller.handleBridgeMessage(
            .markdownDidChange(markdown: "Alpha\n\nBravo updated\n", writeback: nil),
            epoch: 1
        )
        coordinator.controller.handleBridgeMessage(
            .suggestionApplied(
                EpdocSuggestionSpanPayload(
                    id: "teardown-span",
                    author: "lumen",
                    turnID: "turn-teardown",
                    kind: "replacement",
                    from: 7,
                    to: 12,
                    mapVersion: 1,
                    before: "Bravo",
                    after: "Bravo updated",
                    sourceCitation: "claim://teardown",
                    claimID: "claim:teardown"
                )
            ),
            epoch: 1
        )
        coordinator.controller.handleBridgeMessage(
            .suggestionResolved(
                EpdocSuggestionResolution(suggestionID: "teardown-span", state: .accepted)
            ),
            epoch: 1
        )

        await coordinator.flushPendingSurfaceWrites()

        #expect(savedMarkdown == ["Alpha\n\nBravo updated\n"])
        let spans = try await store.spans(turnID: "turn-teardown")
        #expect(spans.count == 1)
        #expect(spans[0].noteRelativePath == "notes/teardown.md")
        #expect(spans[0].state == .accepted)
        #expect(spans[0].claimID == "claim:teardown")
    }

    @MainActor
    @Test("markdown document surface uses direct JS markdown snapshot before host save")
    func markdownDocumentSurfaceUsesDirectJSMarkdownSnapshotBeforeHostSave() async throws {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "fresh-snapshot-page",
            title: "Fresh Snapshot Page",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/fresh-snapshot.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            "Alpha typed before lens switch\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        coordinator.controller.handleBridgeMessage(
            .contentDidChange(
                json:
                #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Alpha typed before lens switch"}]}]}"#
                    .data(using: .utf8)!
            ),
            epoch: 1
        )
        commands.removeAll()

        let flushed = await coordinator.flushPendingMarkdown()
        #expect(flushed)
        #expect(savedMarkdown == ["Alpha typed before lens switch\n"])
        #expect(commands.isEmpty)
    }

    @MainActor
    @Test("clean markdown document surface switches do not save normalized snapshots")
    func cleanMarkdownDocumentSurfaceSwitchesDoNotSaveNormalizedSnapshots() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "clean-switch-page",
            title: "Clean Switch Page",
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |\n",
            theme: .light,
            noteRelativePath: "notes/clean-switch.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            "| A | B |\n| --- | --- |\n| 1 | 2 |\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(savedMarkdown.isEmpty)
        #expect(commands.isEmpty)
    }

    @MainActor
    @Test("same-page markdown updates do not remount the rich document tree")
    func samePageMarkdownUpdatesDoNotRemountTheRichDocumentTree() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []

        coordinator.configure(
            pageId: "same-page-reload",
            title: "Same Page Reload",
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |\n",
            theme: .light,
            noteRelativePath: "notes/same-page.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "same-page-reload",
            title: "Same Page Reload",
            markdown: "| A | B |\n| --- | --- |\n| 1 | 2 |\n\nExternal line\n",
            theme: .light,
            noteRelativePath: "notes/same-page.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands.isEmpty)
    }

    @MainActor
    @Test("same-page markdown document reloads when async body arrives after empty mount")
    func samePageMarkdownDocumentReloadsWhenAsyncBodyArrivesAfterEmptyMount() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let loadedMarkdown = """
        ---
        title: Loaded Later
        ---

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "same-page-empty-then-loaded",
            title: "Loaded Later",
            markdown: "",
            theme: .light,
            noteRelativePath: "notes/loaded-later.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "same-page-empty-then-loaded",
            title: "Loaded Later",
            markdown: loadedMarkdown,
            theme: .light,
            noteRelativePath: "notes/loaded-later.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: loadedMarkdown, epoch: 2), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == loadedMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @MainActor
    @Test("hidden markdown document surface reloads external lens changes on reactivation")
    func hiddenMarkdownDocumentSurfaceReloadsExternalLensChangesOnReactivation() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []

        coordinator.configure(
            pageId: "hidden-reload",
            title: "Hidden Reload",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/hidden-reload.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "hidden-reload",
            title: "Hidden Reload",
            markdown: "Alpha from source lens\n",
            theme: .light,
            noteRelativePath: "notes/hidden-reload.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        #expect(commands.isEmpty)

        coordinator.configure(
            pageId: "hidden-reload",
            title: "Hidden Reload",
            markdown: "Alpha from source lens\n",
            theme: .light,
            noteRelativePath: "notes/hidden-reload.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(!commands.isEmpty)
    }

    @MainActor
    @Test("hidden markdown document surface repushes non-empty Markdown when blank on reactivation")
    func hiddenMarkdownDocumentSurfaceRepushesNonEmptyMarkdownWhenBlankOnReactivation() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # Reactivation Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "hidden-blank-reactivation",
            title: "Hidden Blank Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-blank-reactivation.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(coordinator.controller.toolbarModel.characterCount == 0)

        coordinator.configure(
            pageId: "hidden-blank-reactivation",
            title: "Hidden Blank Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-blank-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @MainActor
    @Test("hidden markdown document surface probes stale stats and suppresses blank reactivation snapshots")
    func hiddenMarkdownDocumentSurfaceProbesStaleStatsAndSuppressesBlankReactivationSnapshots() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []
        var savedJSON: [Data] = []
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # Stale Stats Reactivation Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "hidden-stale-stats-reactivation",
            title: "Hidden Stale Stats Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.onContentChanged = { savedJSON.append($0) }
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.documentStatsChanged(wordCount: 7, characterCount: 64), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "hidden-stale-stats-reactivation",
            title: "Hidden Stale Stats Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-reactivation.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "hidden-stale-stats-reactivation",
            title: "Hidden Stale Stats Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.flushDocumentSnapshot])

        coordinator.controller.handleBridgeMessage(.contentDidChange(json: emptyJSON), epoch: 1)
        coordinator.controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(commands == [.flushDocumentSnapshot, .setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(savedMarkdown.isEmpty)
        #expect(savedJSON.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @MainActor
    @Test("verified clean markdown document surface reactivation skips repeated snapshot probe")
    func verifiedCleanMarkdownDocumentSurfaceReactivationSkipsRepeatedSnapshotProbe() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # Verified Reactivation

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        let normalizedMarkdown = markdown.replacingOccurrences(of: "| - | - |", with: "| --- | --- |")

        coordinator.configure(
            pageId: "verified-reactivation",
            title: "Verified Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.documentStatsChanged(wordCount: 7, characterCount: 64), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "verified-reactivation",
            title: "Verified Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "verified-reactivation",
            title: "Verified Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.flushDocumentSnapshot])
        coordinator.controller.handleBridgeMessage(.markdownDidChange(markdown: normalizedMarkdown, writeback: nil), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "verified-reactivation",
            title: "Verified Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "verified-reactivation",
            title: "Verified Reactivation",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == normalizedMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @MainActor
    @Test("accepted June Epdoc suggestion reloads from vault and provenance after restart")
    func acceptedJuneEpdocSuggestionReloadsFromVaultAndProvenanceAfterRestart() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("june-epdoc-restart-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let noteURL = directory.appendingPathComponent("notes/assist.md")
        try FileManager.default.createDirectory(
            at: noteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let databaseURL = directory.appendingPathComponent("search.sqlite")
        let baseline = "Alpha\n\nBravo\n\nCharlie\n"
        let acceptedMarkdown = "Alpha\n\nBravo updated\n\nCharlie\n"
        try AtomicVaultWriter.writeSynchronously(baseline, to: noteURL)

        var saveErrors: [String] = []
        do {
            let service = try SearchIndexService(databaseURL: databaseURL)
            let store = EditorProvenanceGRDBStore(databaseWriter: service.databaseWriter())
            let coordinator = MarkdownDocumentSurfaceCoordinator()

            coordinator.configure(
                pageId: "assist-page",
                title: "Assist Page",
                markdown: baseline,
                theme: .light,
                noteRelativePath: "notes/assist.md",
                isEditable: true,
                isActive: true,
                provenanceStore: store,
                saveMarkdown: { markdown in
                    do {
                        try AtomicVaultWriter.writeSynchronously(markdown, to: noteURL)
                        return true
                    } catch {
                        saveErrors.append(String(describing: error))
                        return false
                    }
                }
            )

            let epoch = coordinator.controller.currentLoadEpoch
            coordinator.controller.handleBridgeMessage(
                .suggestionApplied(
                    EpdocSuggestionSpanPayload(
                        id: "june-restart-span",
                        author: "june",
                        turnID: "turn-june-restart",
                        kind: "replacement",
                        from: 7,
                        to: 12,
                        mapVersion: 1,
                        before: "Bravo",
                        after: "Bravo updated",
                        rationale: "Tighten the evidence label.",
                        sourceCitation: "claim://june-restart",
                        claimID: "claim:june-restart"
                    )
                ),
                epoch: epoch
            )
            coordinator.controller.handleBridgeMessage(
                .markdownDidChange(
                    markdown: acceptedMarkdown,
                    writeback: EpdocMarkdownWritebackRegion(
                        byteFrom: 7,
                        byteTo: 12,
                        codeUnitFrom: 7,
                        codeUnitTo: 12,
                        changedFrom: 2,
                        changedTo: 3,
                        blockIndexFrom: 1,
                        blockIndexTo: 1,
                        blockMarkdown: "Bravo updated"
                    )
                ),
                epoch: epoch
            )
            coordinator.controller.handleBridgeMessage(
                .suggestionResolved(
                    EpdocSuggestionResolution(
                        suggestionID: "june-restart-span",
                        state: .accepted
                    )
                ),
                epoch: epoch
            )
            await coordinator.flushPendingSurfaceWrites()
        }

        #expect(saveErrors.isEmpty)
        #expect(try String(contentsOf: noteURL, encoding: .utf8) == acceptedMarkdown)

        do {
            let service = try SearchIndexService(databaseURL: databaseURL)
            let store = EditorProvenanceGRDBStore(databaseWriter: service.databaseWriter())
            let spans = try await store.spans(turnID: "turn-june-restart")
            #expect(spans.count == 1)
            #expect(spans[0].id == "june-restart-span")
            #expect(spans[0].noteRelativePath == "notes/assist.md")
            #expect(spans[0].author == "june")
            #expect(spans[0].state == .accepted)
            #expect(spans[0].beforeText == "Bravo")
            #expect(spans[0].afterText == "Bravo updated")
            #expect(spans[0].sourceCitation == "claim://june-restart")
            #expect(spans[0].claimID == "claim:june-restart")

            let reloadedCoordinator = MarkdownDocumentSurfaceCoordinator()
            reloadedCoordinator.configure(
                pageId: "assist-page",
                title: "Assist Page",
                markdown: acceptedMarkdown,
                theme: .light,
                noteRelativePath: "notes/assist.md",
                isEditable: true,
                isActive: true,
                provenanceStore: store,
                saveMarkdown: { _ in true }
            )
            #expect(reloadedCoordinator.controller.latestMarkdownSnapshot == acceptedMarkdown)
        }
    }

    @Test("spans survive a fresh store and writer reopen")
    func spansSurviveFreshStoreAndWriterReopen() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-provenance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("search.sqlite")

        let firstStore = EditorProvenanceGRDBStore(
            databaseWriter: try DatabaseQueue(path: databaseURL.path)
        )
        try await firstStore.insert(
            Self.span(id: "restart-span", turnID: "turn-restart", createdAt: 1, claimID: "claim:restart")
        )

        let reopenedStore = EditorProvenanceGRDBStore(
            databaseWriter: try DatabaseQueue(path: databaseURL.path)
        )
        let pending = try await reopenedStore.pendingAgentSpans(turnID: "turn-restart")
        #expect(pending.map(\.id) == ["restart-span"])
        #expect(pending[0].claimID == "claim:restart")

        try await reopenedStore.decide(
            id: "restart-span",
            state: .accepted,
            decidedAt: Date(timeIntervalSince1970: 2)
        )

        let finalStore = EditorProvenanceGRDBStore(
            databaseWriter: try DatabaseQueue(path: databaseURL.path)
        )
        let spans = try await finalStore.spans(turnID: "turn-restart")
        #expect(spans.count == 1)
        #expect(spans[0].id == "restart-span")
        #expect(spans[0].state == .accepted)
        #expect(spans[0].decidedAt == Date(timeIntervalSince1970: 2))
        #expect(spans[0].sourceCitation == "source-restart-span")
    }

    @Test("spans survive app search-service writer reopen")
    func spansSurviveAppSearchServiceWriterReopen() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-provenance-search-service-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("search.sqlite")

        do {
            let service = try SearchIndexService(databaseURL: databaseURL)
            let store = EditorProvenanceGRDBStore(databaseWriter: service.databaseWriter())
            let sink = EditorProvenanceBridgeSink(store: store, noteRelativePath: "notes/app-restart.md")
            try await sink.persistApplied(
                EpdocSuggestionSpanPayload(
                    id: "app-restart-span",
                    author: "lumen",
                    turnID: "turn-app-restart",
                    kind: "replacement",
                    from: 14,
                    to: 19,
                    mapVersion: 6,
                    before: "draft",
                    after: "claim",
                    rationale: "persist over app writer reopen",
                    sourceCitation: "claim://app-restart",
                    claimID: "claim:app-restart"
                ),
                createdAt: Date(timeIntervalSince1970: 10)
            )
        }

        do {
            let service = try SearchIndexService(databaseURL: databaseURL)
            let store = EditorProvenanceGRDBStore(databaseWriter: service.databaseWriter())
            let pending = try await store.pendingAgentSpans(turnID: "turn-app-restart")
            #expect(pending.count == 1)
            #expect(pending[0].id == "app-restart-span")
            #expect(pending[0].noteRelativePath == "notes/app-restart.md")
            #expect(pending[0].claimID == "claim:app-restart")
            #expect(pending[0].sourceCitation == "claim://app-restart")

            let sink = EditorProvenanceBridgeSink(store: store, noteRelativePath: "notes/app-restart.md")
            try await sink.persistResolved(
                EpdocSuggestionResolution(suggestionID: "app-restart-span", state: .accepted),
                decidedAt: Date(timeIntervalSince1970: 20)
            )
        }

        do {
            let service = try SearchIndexService(databaseURL: databaseURL)
            let store = EditorProvenanceGRDBStore(databaseWriter: service.databaseWriter())
            let spans = try await store.spans(turnID: "turn-app-restart")
            #expect(spans.count == 1)
            #expect(spans[0].id == "app-restart-span")
            #expect(spans[0].state == .accepted)
            #expect(spans[0].decidedAt == Date(timeIntervalSince1970: 20))
            #expect(spans[0].beforeText == "draft")
            #expect(spans[0].afterText == "claim")
        }
    }

    @Test("schema install upgrades legacy provenance tables")
    func schemaInstallUpgradesLegacyProvenanceTables() async throws {
        let queue = try DatabaseQueue()
        try await queue.write { db in
            try db.execute(sql: """
                CREATE TABLE suggestion_span (
                    id TEXT PRIMARY KEY,
                    note_rel_path TEXT NOT NULL,
                    turn_id TEXT NOT NULL,
                    author TEXT NOT NULL,
                    source TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    from_pos INTEGER NOT NULL,
                    to_pos INTEGER NOT NULL,
                    map_version INTEGER NOT NULL,
                    before_text TEXT,
                    after_text TEXT,
                    rationale TEXT,
                    state TEXT NOT NULL DEFAULT 'pending',
                    created_at REAL NOT NULL,
                    decided_at REAL
                );
                CREATE TABLE suggestion_span_summary (
                    note_rel_path TEXT NOT NULL,
                    turn_id TEXT NOT NULL,
                    compacted_at REAL NOT NULL,
                    accepted_count INTEGER NOT NULL DEFAULT 0,
                    rejected_count INTEGER NOT NULL DEFAULT 0,
                    last_decided_at REAL,
                    PRIMARY KEY(note_rel_path, turn_id)
                );
                """)
        }
        let store = EditorProvenanceGRDBStore(databaseWriter: queue)

        try await store.insert(
            Self.span(id: "legacy", turnID: "turn-legacy", createdAt: 1, claimID: "claim:legacy")
        )
        try await store.decide(
            id: "legacy",
            state: .accepted,
            decidedAt: Date(timeIntervalSince1970: 2)
        )
        try await store.compact(keepResolvedMost: 0)

        let summaries = try await store.compactionSummaries()
        #expect(summaries.count == 1)
        #expect(summaries[0].acceptedCount == 1)
        #expect(summaries[0].claimIDs == ["claim:legacy"])
    }

    private static func span(
        id: String,
        turnID: String,
        createdAt: Double,
        claimID: String? = nil
    ) -> SuggestionSpanRecord {
        SuggestionSpanRecord(
            id: id,
            noteRelativePath: "notes/lumen.md",
            turnID: turnID,
            author: "companion-a",
            source: .agent,
            kind: "insertion",
            fromPos: 10,
            toPos: 20,
            mapVersion: 1,
            beforeText: "before-\(id)",
            afterText: "after-\(id)",
            rationale: "rationale-\(id)",
            sourceCitation: "source-\(id)",
            state: .pending,
            createdAt: Date(timeIntervalSince1970: createdAt),
            decidedAt: nil,
            claimID: claimID
        )
    }
}
