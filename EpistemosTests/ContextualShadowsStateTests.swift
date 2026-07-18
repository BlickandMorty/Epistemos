import Foundation
import Testing
@testable import Epistemos

@Suite("ContextualShadowsState")
struct ContextualShadowsStateTests {

    // MARK: - Helpers

    private func repoText(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    private func repoFileExists(_ relativePath: String) -> Bool {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    /// Mirrors the production gate. The state class reads it on demand, so we
    /// observe the live value rather than mutating env mid-test (which would
    /// race with siblings in the suite).
    private static var ambientRecallGateIsEnabled: Bool {
        if ProcessInfo.processInfo.environment[ContextualShadowsState.userDefaultsKey] == "1" {
            return true
        }
        if let persisted = UserDefaults.standard.object(
            forKey: ContextualShadowsState.userDefaultsKey
        ) as? Bool {
            return persisted
        }
        return ContextualShadowsState.defaultEnabled
    }

    // MARK: - Flag gating

    @MainActor
    @Test("isEnabled reflects the ambient recall product gate")
    func isEnabledMatchesProductGate() {
        let state = ContextualShadowsState()
        #expect(state.isEnabled == Self.ambientRecallGateIsEnabled)
    }

    // MARK: - Panel visibility

    @MainActor
    @Test("openPanel is a no-op when V0 flag is OFF; closePanel still resets")
    func openPanelGatedByFlag() {
        let state = ContextualShadowsState()
        #expect(state.isPanelVisible == false)
        state.openPanel()
        if Self.ambientRecallGateIsEnabled {
            #expect(state.isPanelVisible == true)
        } else {
            #expect(state.isPanelVisible == false)
        }
        // closePanel must always reset, regardless of flag.
        state.closePanel()
        #expect(state.isPanelVisible == false)
    }

    @MainActor
    @Test("closePanel clears currentResults (memory hygiene)")
    func closePanelClearsResults() {
        let state = ContextualShadowsState()
        state.currentResults = [
            .init(id: "n1", title: "A", snippet: "snippet", kind: .note, similarity: 0.9),
            .init(id: "n2", title: "B", snippet: "snippet", kind: .note, similarity: 0.8),
        ]
        state.isPanelVisible = true
        state.closePanel()
        #expect(state.isPanelVisible == false)
        #expect(state.currentResults.isEmpty)
    }

    // MARK: - requestRecall gating

    @MainActor
    @Test("requestRecall is a no-op for queries shorter than minimumQueryLength")
    func shortQueryNoOp() {
        let state = ContextualShadowsState()
        let recall = InstantRecallService()
        state.currentResults = [
            .init(id: "stale-note", title: "Stale", snippet: "old", kind: .note, similarity: 0.6),
        ]
        state.isPanelVisible = true
        let snapshot = RecallContextSnapshot(
            text: "abc",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(snapshot: snapshot, instantRecall: recall)
        // No task should be scheduled for a query under 6 chars.
        #expect(state.pendingTask == nil)
        #expect(state.currentResults.isEmpty)
        #expect(state.isPanelVisible == false)
    }

    @MainActor
    @Test("requestRecall does not schedule work when V0 flag is OFF")
    func disabledFlagSchedulesNothing() {
        // Only meaningful when the env flag is OFF in the suite environment.
        // When the flag is ON we exercise the scheduling path instead.
        let state = ContextualShadowsState()
        let recall = InstantRecallService()
        let snapshot = RecallContextSnapshot(
            text: "this is plenty long for the gate",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(snapshot: snapshot, instantRecall: recall)
        if Self.ambientRecallGateIsEnabled {
            // Flag ON path — a task SHOULD be scheduled.
            #expect(state.pendingTask != nil)
            state.pendingTask?.cancel()
        } else {
            // Flag OFF path — no work, no task.
            #expect(state.pendingTask == nil)
        }
    }

    @MainActor
    @Test("requestRecall cancels in-flight task before scheduling a new one")
    func backpressureSupersedes() async {
        guard Self.ambientRecallGateIsEnabled else {
            // Without the flag, requestRecall short-circuits and never
            // schedules — the cancellation behavior is moot.
            return
        }
        let state = ContextualShadowsState()
        let recall = InstantRecallService()
        let shadow = ContextualShadowsMockSearch(
            resultsByDomain: [.notes: [], .chats: []],
            delayNanoseconds: 120_000_000
        )
        state.configureShadowSearch(shadow)
        let originId = UUID()
        let snapshotA = RecallContextSnapshot(
            text: "first query — longer than the minimum",
            kind: .note,
            originId: originId,
            originDocId: "same-note"
        )
        let snapshotB = RecallContextSnapshot(
            text: "second query — longer than the minimum",
            kind: .note,
            originId: originId,
            originDocId: "same-note"
        )
        state.requestRecall(snapshot: snapshotA, instantRecall: recall)
        let cancellationCountBeforeSecondRequest = state.recallCancellationCount
        let firstTask = state.pendingTask
        #expect(firstTask != nil)
        state.requestRecall(snapshot: snapshotB, instantRecall: recall)
        // Yield so the cancellation actually propagates before we observe.
        await Task.yield()
        #expect(state.recallCancellationCount > cancellationCountBeforeSecondRequest)
        state.pendingTask?.cancel()
    }

    // MARK: - convert helper (origin-id filter + title/snippet extraction)

    @Test("convert filters out hits whose doc id matches the origin id")
    func convertFiltersOrigin() {
        let originId = UUID()
        let originString = originId.uuidString
        let raw: [InstantRecallResult] = [
            .init(id: originString, text: "Origin note body", score: 0.99),
            .init(id: "other-1", text: "# Other Title\nbody body", score: 0.80),
        ]
        let hits = ContextualShadowsState.convert(raw: raw, kind: .note, originId: originId)
        #expect(hits.count == 1)
        #expect(hits.first?.id == "other-1")
        #expect(hits.first?.title == "Other Title")
    }

    @Test("convert prefers the first markdown heading for the title")
    func convertPrefersMarkdownHeading() {
        let raw: [InstantRecallResult] = [
            .init(id: "x", text: "# Hello World\nBody continues here.", score: 0.7),
        ]
        let hits = ContextualShadowsState.convert(raw: raw, kind: .note, originId: UUID())
        #expect(hits.first?.title == "Hello World")
        #expect(hits.first?.source == "instant-recall")
        #expect(hits.first?.snippet.hasPrefix("# Hello World") == true
                || hits.first?.snippet.contains("Hello World") == true)
    }

    @MainActor
    @Test("configured Shadow backend presents note results only")
    func configuredShadowBackendFeedsNotesOnlyRecall() async {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()
        let noteHit = ShadowHit(
                id: "shadow-note-1",
                title: "Shadow Note",
                snippet: "A durable shadow backend result.",
                score: 0.82,
                domain: .notes,
                source: "stub-shadow"
        )
        let chatHit = ShadowHit(
                id: "shadow-chat-1",
                title: "Shadow Chat",
                snippet: "A durable chat shadow backend result.",
                score: 0.77,
                domain: .chats,
                source: "stub-shadow"
        )
        let shadow = ContextualShadowsMockSearch(resultsByDomain: [
            .notes: [noteHit],
            .chats: [chatHit],
        ])
        state.configureShadowSearch(shadow)

        let snapshot = RecallContextSnapshot(
            text: "durable shadow backend query",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(snapshot: snapshot, instantRecall: recall)

        await Self.waitForResults(state, expectedCount: 1)
        #expect(shadow.callCount == 1)
        #expect(shadow.lastQuery == "durable shadow backend query")
        #expect(shadow.domains == [.notes])
        #expect(state.currentResults.map(\.id).contains("shadow-note-1"))
        #expect(!state.currentResults.map(\.id).contains("shadow-chat-1"))
        #expect(state.currentResults.allSatisfy { $0.source == "stub-shadow" })
        #expect(state.hasPanelPayload)
        #expect(!state.isPanelVisible)
        state.openPanel()
        #expect(state.isPanelVisible)
    }

    @MainActor
    @Test("chat-origin recall is fail-closed before it reaches a backend")
    func chatOriginRecallIsFailClosed() async {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()
        let chatHit = ShadowHit(
            id: "near-tie-chat",
            title: "Old Conversation",
            snippet: "Prior chat text with a slightly higher raw score.",
            score: 0.82,
            domain: .chats,
            source: "stub-shadow"
        )
        let shadow = ContextualShadowsMockSearch(resultsByDomain: [
            .chats: [chatHit],
        ])
        state.configureShadowSearch(shadow)
        state.currentResults = [
            .init(id: "stale-note", title: "Stale", snippet: "old", kind: .note, similarity: 0.4),
        ]

        state.requestRecall(
            snapshot: RecallContextSnapshot(
                text: "moral responsibility and free will",
                kind: .chat,
                originId: UUID(),
                originDocId: "main-chat-draft"
            ),
            instantRecall: recall
        )

        await Task.yield()
        #expect(shadow.callCount == 0)
        #expect(state.currentResults.isEmpty)
        #expect(!state.hasPanelPayload)
    }

    @MainActor
    @Test("scoped recall payloads isolate landing chat and note surfaces")
    func scopedRecallPayloadsIsolateSurfaces() async {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()
        let noteHit = ShadowHit(
            id: "related-note-hit",
            title: "Related Note",
            snippet: "A result that belongs only to the originating note scope.",
            score: 0.84,
            domain: .notes,
            source: "stub-shadow"
        )
        let shadow = ContextualShadowsMockSearch(resultsByDomain: [
            .notes: [noteHit],
            .chats: [],
        ])
        state.configureShadowSearch(shadow)

        let snapshot = RecallContextSnapshot(
            text: "surface scoped semantic recall query",
            kind: .note,
            originId: UUID(),
            originDocId: "note-a"
        )
        state.requestRecall(snapshot: snapshot, instantRecall: recall)

        await Self.waitForScopedPayload(
            state,
            kind: .note,
            originDocId: "note-a",
            expectedCount: 1
        )
        #expect(state.payload(kind: .note, originDocId: "note-a").results.first?.id == "related-note-hit")
        #expect(state.payload(kind: .note, originDocId: "note-b").results.isEmpty)
        #expect(state.payload(kind: .chat, originDocId: "landing:draft").results.isEmpty)

        state.openPanel(kind: .note, originDocId: "note-a")
        #expect(state.isPanelVisible(kind: .note, originDocId: "note-a"))
        #expect(!state.isPanelVisible(kind: .note, originDocId: "note-b"))

        state.closePanel(kind: .note, originDocId: "note-a")
        #expect(!state.hasPanelPayload(kind: .note, originDocId: "note-a"))
    }

    @MainActor
    @Test("Shadow backend errors surface in the mounted Contextual Shadows panel")
    func shadowBackendErrorSurfacesInMountedPanel() async {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()
        let shadow = ContextualShadowsMockSearch(
            resultsByDomain: [:],
            errorsByDomain: [
                .notes: "Search backend unavailable. Try reopening the vault.",
            ]
        )
        state.configureShadowSearch(shadow)

        let snapshot = RecallContextSnapshot(
            text: "shadow backend failure query",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(snapshot: snapshot, instantRecall: recall)

        await Self.waitForPanelPayload(state)
        #expect(state.currentResults.isEmpty)
        #expect(state.lastErrorMessage == "Search backend unavailable. Try reopening the vault.")
        #expect(state.hasPanelPayload)
        #expect(!state.isPanelVisible)
        state.openPanel()
        #expect(state.isPanelVisible)
    }

    @MainActor
    @Test("empty Shadow results fall back to app vault search and light the recall button")
    func emptyShadowFallsBackToAppVaultSearch() async throws {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()
        let shadow = ContextualShadowsMockSearch(resultsByDomain: [
            .notes: [],
        ])
        state.configureShadowSearch(shadow)

        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("contextual-shadows-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        let searchIndex = try SearchIndexService(databaseURL: databaseURL)
        try searchIndex.upsert(
            id: "vault-note-autobiography",
            title: "My Autobiography",
            body: "A note about autobiographical memory, local recall, and meaning anchors.",
            tags: "memoir recall",
            updatedAt: .now
        )

        let snapshot = RecallContextSnapshot(
            text: "autobiographical memory meaning anchors",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(
            snapshot: snapshot,
            instantRecall: recall,
            searchIndexService: searchIndex
        )

        await Self.waitForResults(state, expectedCount: 1)
        #expect(shadow.callCount == 1)
        #expect(state.currentResults.first?.id == "vault-note-autobiography")
        #expect(state.currentResults.first?.title == "My Autobiography")
        #expect(state.currentResults.first?.source == "vault-search")
        #expect(state.hasPanelPayload)
        #expect(!state.isPanelVisible)
        state.openPanel()
        #expect(state.isPanelVisible)
    }

    @MainActor
    @Test("explicit title recall outranks generated lookup artifacts")
    func explicitTitleRecallOutranksGeneratedLookupArtifacts() async throws {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()

        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("contextual-shadows-title-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        let searchIndex = try SearchIndexService(databaseURL: databaseURL)
        try searchIndex.upsert(
            id: "synthetic-lookup-artifact",
            title: "look-for-a-note-titled-all-things-must-go",
            body: "# Note titled all things must go\nGenerated chat artifact that should not outrank the note.",
            tags: "vault-search",
            updatedAt: .now
        )
        try searchIndex.upsert(
            id: "all-things-must-go",
            title: "All Things Must Go",
            body: "The actual note body that should be selected for this explicit title lookup.",
            tags: "essay",
            updatedAt: .now
        )

        let snapshot = RecallContextSnapshot(
            text: "look for a note titled All Things Must Go",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(
            snapshot: snapshot,
            instantRecall: recall,
            searchIndexService: searchIndex
        )

        await Self.waitForResults(state, expectedCount: 2)
        #expect(state.currentResults.first?.id == "all-things-must-go")
        #expect(state.currentResults.first?.title == "All Things Must Go")
    }

    @MainActor
    @Test("new scoped recall clears stale results while the next query is pending")
    func requestRecallPublishesPendingPayloadForCurrentText() async {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()
        let firstHit = ShadowHit(
            id: "old-related-note",
            title: "Old Related Note",
            snippet: "A completed result from the previous active sentence.",
            score: 0.82,
            domain: .notes,
            source: "stub-shadow"
        )
        state.configureShadowSearch(ContextualShadowsMockSearch(resultsByDomain: [
            .notes: [firstHit],
            .chats: [],
        ]))

        let originId = UUID()
        let originDocId = "note-a"
        state.requestRecall(
            snapshot: RecallContextSnapshot(
                text: "previous active sentence about older recall",
                kind: .note,
                originId: originId,
                originDocId: originDocId
            ),
            instantRecall: recall
        )

        await Self.waitForScopedPayload(
            state,
            kind: .note,
            originDocId: originDocId,
            expectedCount: 1
        )
        #expect(state.payload(kind: .note, originDocId: originDocId).results.first?.id == "old-related-note")

        let slowShadow = ContextualShadowsMockSearch(
            resultsByDomain: [.notes: [], .chats: []],
            delayNanoseconds: 120_000_000
        )
        state.configureShadowSearch(slowShadow)
        state.requestRecall(
            snapshot: RecallContextSnapshot(
                text: "fresh current sentence about entropy and moral responsibility",
                kind: .note,
                originId: originId,
                originDocId: originDocId
            ),
            instantRecall: recall
        )

        let pending = state.payload(kind: .note, originDocId: originDocId)
        #expect(pending.results.isEmpty)
        #expect(pending.isSearching)
        #expect(pending.queryText.contains("entropy"))
        #expect(!pending.queryText.contains("previous active sentence"))
        state.pendingTask?.cancel()
    }

    @Test("convert falls back to the first non-empty line when no heading exists")
    func convertFirstLineFallback() {
        let raw: [InstantRecallResult] = [
            .init(id: "x", text: "    \n\nSome plain body.\nMore body.", score: 0.5),
        ]
        let hits = ContextualShadowsState.convert(raw: raw, kind: .note, originId: UUID())
        #expect(hits.first?.title == "Some plain body.")
    }

    @Test("instant recall conversion produces note results")
    func instantRecallHitsRemainNoteResults() {
        let raw: [InstantRecallResult] = [
            .init(id: "note-1", text: "# Related Note\nBody", score: 0.74),
        ]
        let hits = ContextualShadowsState.convert(raw: raw, resultKind: .note, originId: UUID())
        #expect(hits.count == 1)
        #expect(hits.first?.kind == .note)
    }

    // MARK: - Snapshot Sendable contract

    @Test("RecallContextSnapshot is value-equal across hashable identity")
    func snapshotHashable() {
        let id = UUID()
        let a = RecallContextSnapshot(text: "hello world", kind: .note, originId: id)
        let b = RecallContextSnapshot(text: "hello world", kind: .note, originId: id)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("RecallContextSnapshot preserves non-UUID document ids for origin filtering")
    func snapshotPreservesOriginDocID() {
        let snapshot = RecallContextSnapshot(
            text: "hello world",
            kind: .note,
            originId: UUID(),
            originDocId: "My Autobiography"
        )
        #expect(snapshot.originDocId == "My Autobiography")
    }

    @Test("recallQuery tracks the current sentence window instead of the whole note")
    func recallQueryUsesRecentSemanticWindow() {
        let longPrefix = Array(repeating: "old archive paragraph about unrelated recipes", count: 80)
            .joined(separator: ". ")
        let text = """
        \(longPrefix)

        I am writing about local semantic recall, Eidos evidence, and notes that should appear while I type.
        """
        let query = ContextualShadowsState.recallQuery(from: text)
        #expect(query.contains("semantic recall"))
        #expect(query.contains("Eidos evidence"))
        #expect(!query.contains("old archive paragraph about unrelated recipes. old archive paragraph"))
        #expect(query.count <= 1_000)
    }

    @Test("recallQuery follows the active line instead of the surrounding note")
    func recallQueryUsesActiveLineOverSurroundingNoteContext() {
        let text = """
        # My Autobiography
        This older context is about caretaking, gaming, and a long autobiographical essay.
        moral responsibility and free will
        """
        let query = ContextualShadowsState.recallQuery(from: text)
        #expect(query.contains("moral responsibility"))
        #expect(query.contains("free will"))
        #expect(!query.contains("My Autobiography"))
        #expect(!query.contains("caretaking"))
    }

    @Test("recallQuery prioritizes explicit note titles")
    func recallQueryPrioritizesExplicitNoteTitles() {
        let query = ContextualShadowsState.recallQuery(
            from: "look for a note titled All Things Must Go"
        )
        #expect(query.hasPrefix("All Things Must Go"))
        #expect(query.contains("look for a note titled All Things Must Go"))
    }

    @Test("recallQuery does not carry stale title lookups into a new active line")
    func recallQueryIgnoresOldExplicitTitleWhenTypingNewLine() {
        let text = """
        look for a note titled All Things Must Go
        The previous lookup is done.

        math is one of the hardest subjects but why is entropy an interesting topic
        """
        let query = ContextualShadowsState.recallQuery(from: text)
        #expect(query.contains("entropy"))
        #expect(query.contains("hardest subjects"))
        #expect(!query.contains("All Things Must Go"))
    }

    // MARK: - Fusion source guards

    @Test("mounted recall source contains no stale chat-ranking implementation")
    func mountedRecallSourceHasNoStaleChatRankingImplementation() throws {
        let stateSource = try repoText("Epistemos/State/ContextualShadowsState.swift")

        #expect(!stateSource.contains("noteFirstBoost"),
                "Free note-only mounted recall must not retain the deleted note-versus-chat ranking boost.")
        #expect(stateSource.components(separatedBy: "func closePanel() {").count == 2,
                "Mounted recall must declare exactly one unscoped closePanel implementation.")
        #expect(stateSource.contains("let baseTerms = Set(")
                && stateSource.contains("let keywordValues = rankedKeywords"),
                "The bounded recall query must retain one syntactically complete title/base-term preparation step.")
    }

    @Test("Contextual Shadows V0 is the production-mounted recall surface")
    func contextualShadowsProductionMountsArePresent() throws {
        let appBootstrap = try repoText("Epistemos/App/AppBootstrap.swift")
        let appEnvironment = try repoText("Epistemos/App/AppEnvironment.swift")
        let noteWorkspace = try repoText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let proseBridge = try repoText("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(appBootstrap.contains("let contextualShadowsState = ContextualShadowsState()"))
        #expect(appEnvironment.contains(".environment(bootstrap.contextualShadowsState)"))

        #expect(noteWorkspace.contains("@Environment(ContextualShadowsState.self)"))
        #expect(noteWorkspace.contains("scopeKind: .note"))
        #expect(noteWorkspace.contains("ContextualShadowsButton(scopeKind: .note"))

        #expect(proseBridge.contains("scheduleContextualShadowsRecall()"))
        #expect(proseBridge.contains("state.requestRecall("))
        #expect(proseBridge.contains("searchIndexService: searchIndexService"))
        #expect(proseBridge.contains("guard let liveText = self.contextualRecallText() else { return }"))
        #expect(!proseBridge.contains("scheduleContextualShadowsRecall(_ snapshotText: String)"))
        #expect(!proseBridge.contains("HaloButton("),
                "Note pages should use the scoped Contextual Shadows chip, not the legacy clipped Halo search button.")
        #expect(!proseBridge.contains("ShadowPanelContent("),
                "Note recall should not mount the old detached Halo panel on top of the native recall panel.")
        #expect(!proseBridge.contains("trailingContext"),
                "Note recall should not include text after the cursor; trailing note context can dominate the active sentence.")
    }

    @Test("Contextual Shadows avoids native bracket frame chrome")
    func contextualShadowsAvoidNativeBracketFrameChrome() throws {
        let contextualPanel = try repoText("Epistemos/Views/Recall/ContextualShadowsPanel.swift")

        #expect(!repoFileExists("Epistemos/Views/Chat/ChatInputBar.swift"))
        #expect(!repoFileExists("Epistemos/Views/Chat/EidosRetrievedSection.swift"))
        #expect(!contextualPanel.contains("GroupBox("),
                "Current recall/evidence UI should use Epistemos flat cards, not native macOS GroupBox frames.")
    }

    @Test("Landing instant recall gets roomier than note recall")
    func landingInstantRecallGetsRoomierThanNoteRecall() throws {
        let panelSource = try repoText("Epistemos/Views/Recall/ContextualShadowsPanel.swift")

        #expect(panelSource.contains("case .landing: return 680"))
        #expect(panelSource.contains("case .landing: return 480"))
        #expect(panelSource.contains("case .note: return 390"))
    }

    @Test("Contextual Shadows V0 prefers Shadow search without mounting the V1 Halo controller")
    func contextualShadowsCurrentBackendContract() throws {
        let stateSource = try repoText("Epistemos/State/ContextualShadowsState.swift")

        #expect(stateSource.contains("instantRecall: InstantRecallService"))
        #expect(stateSource.contains("instantRecall.searchAsync("))
        #expect(stateSource.contains("ShadowSearchServicing"),
                "The approved V0 route should prefer the Shadow backend when AppBootstrap configures it.")
        #expect(stateSource.contains("searchReportingErrors("),
                "The mounted V0 route must not hide Shadow backend failures as empty recall.")
        #expect(stateSource.contains("SearchIndexService"),
                "A cold/empty Shadow route must fall back to the app-owned vault search index before going silent.")
        #expect(stateSource.contains("VaultRecallBridge.recordProductionTrace"),
                "The app-search fallback should leave VaultRecall metrics/provenance for the visible recall surface.")
        #expect(!stateSource.contains("shadowDomains(for: snapshot.kind)"),
                "Free V1 must not restore the generic note-and-chat domain fan-out.")
        #expect(stateSource.contains("let outcome = await shadowSearch.searchReportingErrors("),
                "Mounted recall must use the notes-only Shadow service contract.")
        #expect(stateSource.contains("allowsContextualShadowPresentation"),
                "Free V1 must reject chat-origin recall before scheduling backend work.")
        #expect(stateSource.contains("publishPayload(")
                && stateSource.contains("isVisible: !hits.isEmpty"),
                "Contextual Shadows must publish payloads when a live typing query produces hits.")
        #expect(stateSource.contains("hasVisiblePayload")
                && stateSource.contains("scopedPanelVisibility[scopeKey] = isVisible && hasVisiblePayload && scopeWasOpen"),
                "Contextual Shadows must light the recall affordance without auto-opening the panel mid-typing.")
        #expect(stateSource.contains("recallQuery(from: snapshot.text)"),
                "Contextual Shadows must query from the active typed sentence/topic, not the whole note body.")
        #expect(stateSource.contains("rankedUniqueHits("),
                "Contextual Shadows must dedupe and rank note recall results.")
        #expect(stateSource.contains("pendingTask = scopedPendingTasks.values.first"),
                "Completed or closed scoped recall tasks must not leave stale global searching state behind.")
        #expect(stateSource.contains("scopedPendingTasks[scopeKey]?.cancel()"),
                "Closing a scoped recall panel must cancel that scoped search so it cannot reopen itself.")
        #expect(!stateSource.contains("HaloController"),
                "The production-mounted V0 surface should not silently become the unmounted V1 Halo controller.")
    }

    @Test("Contextual Shadows panel displays recall source provenance")
    func contextualShadowsPanelDisplaysSourceProvenance() throws {
        let panelSource = try repoText("Epistemos/Views/Recall/ContextualShadowsPanel.swift")
        let buttonSource = try repoText("Epistemos/Views/Recall/ContextualShadowsButton.swift")

        #expect(panelSource.contains("hit.source"))
        #expect(panelSource.contains("Shadow backend unavailable"))
        #expect(buttonSource.contains("payload.hasPanelPayload"))
    }

    @Test("Contextual Shadows recall chrome is visible but native-feeling")
    func contextualShadowsRecallChromeIsVisibleButNativeFeeling() throws {
        let panelSource = try repoText("Epistemos/Views/Recall/ContextualShadowsPanel.swift")
        let buttonSource = try repoText("Epistemos/Views/Recall/ContextualShadowsButton.swift")

        #expect(buttonSource.contains("@Environment(UIState.self)"))
        #expect(buttonSource.contains("Text(\"IR\")"))
        #expect(buttonSource.contains(".font(.system(size: 14, weight: .bold, design: .rounded))"))
        #expect(buttonSource.contains(".font(.system(size: 12.5, weight: .bold, design: .monospaced))"))
        #expect(buttonSource.contains("recallChipBackground"))
        #expect(!buttonSource.contains("magnifyingglass"))
        #expect(panelSource.contains("RoundedRectangle(cornerRadius: 14, style: .continuous)"))
        #expect(panelSource.contains(".scale(scale: 0.97, anchor: .bottomTrailing).combined(with: .opacity)"))
        #expect(!panelSource.contains("Rectangle()\n                        .fill(theme.resolved.accent.color"))
    }

    @Test("AppBootstrap ignores stale Shadow backend init during vault switches")
    func appBootstrapGuardsShadowBackendAgainstStaleVaultSwitches() throws {
        let appBootstrap = try repoText("Epistemos/App/AppBootstrap.swift")
        let contextualShadowsState = try repoText("Epistemos/State/ContextualShadowsState.swift")

        #expect(appBootstrap.contains("contextualShadowsState.resetForVaultLifecycle()"))
        #expect(contextualShadowsState.contains("func resetForVaultLifecycle()"))
        #expect(contextualShadowsState.contains("pendingTask?.cancel()"))
        #expect(contextualShadowsState.contains("pendingTask = nil"))
        #expect(contextualShadowsState.contains("shadowSearch = nil"))
        #expect(contextualShadowsState.contains("clearResults()"))
        #expect(appBootstrap.contains("vaultSync.vaultURL?.path == vaultPath"))
        #expect(appBootstrap.contains("shadowIndexingInFlightVaultPath == vaultPath"))
        #expect(appBootstrap.contains("ignoring stale bootstrap"))
    }

    @Test("AppBootstrap guards Shadow page reindexing against stale vault switches")
    func appBootstrapGuardsShadowPageReindexAgainstStaleVaultSwitches() throws {
        let appBootstrap = try repoText("Epistemos/App/AppBootstrap.swift")

        #expect(appBootstrap.contains("guard lastShadowIndexedVaultPath == vaultPath else { return }"))
        #expect(appBootstrap.contains("self.vaultSync.vaultURL?.path == stage.vaultPath"))
        #expect(appBootstrap.contains("self.lastShadowIndexedVaultPath == stage.vaultPath"))
    }

    @MainActor
    private static func waitForResults(
        _ state: ContextualShadowsState,
        expectedCount: Int,
        timeout: TimeInterval = 1.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.currentResults.count == expectedCount {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    private static func waitForPanelPayload(
        _ state: ContextualShadowsState,
        timeout: TimeInterval = 1.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.hasPanelPayload {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    private static func waitForScopedPayload(
        _ state: ContextualShadowsState,
        kind: RecallContextKind,
        originDocId: String,
        expectedCount: Int,
        timeout: TimeInterval = 1.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.payload(kind: kind, originDocId: originDocId).results.count == expectedCount {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

@MainActor
private final class ContextualShadowsMockSearch: ShadowSearchServicing, @unchecked Sendable {
    var resultsByDomain: [ShadowDomain: [ShadowHit]]
    var errorsByDomain: [ShadowDomain: String]
    let delayNanoseconds: UInt64
    private(set) var callCount = 0
    private(set) var lastQuery = ""
    private(set) var lastDomain: ShadowDomain = .notes
    private(set) var domains: [ShadowDomain] = []

    init(
        resultsByDomain: [ShadowDomain: [ShadowHit]],
        errorsByDomain: [ShadowDomain: String] = [:],
        delayNanoseconds: UInt64 = 0
    ) {
        self.resultsByDomain = resultsByDomain
        self.errorsByDomain = errorsByDomain
        self.delayNanoseconds = delayNanoseconds
    }

    nonisolated func search(text: String, limit: Int) async -> [ShadowHit] {
        let delayNanoseconds = await MainActor.run { self.delayNanoseconds }
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        await MainActor.run {
            self.callCount += 1
            self.lastQuery = text
            self.lastDomain = .notes
            self.domains.append(.notes)
        }
        return await MainActor.run { Array((self.resultsByDomain[.notes] ?? []).prefix(limit)) }
    }

    nonisolated func searchReportingErrors(
        text: String,
        limit: Int
    ) async -> (hits: [ShadowHit], errorMessage: String?) {
        let hits = await search(text: text, limit: limit)
        let error = await MainActor.run { self.errorsByDomain[.notes] }
        return (hits: hits, errorMessage: error)
    }
}
