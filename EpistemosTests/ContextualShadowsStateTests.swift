import Foundation
import Testing
@testable import Epistemos

@Suite("ContextualShadowsState")
struct ContextualShadowsStateTests {

    // MARK: - Helpers

    private func repoText(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    /// Mirrors the production gate. The state class reads it on demand, so we
    /// observe the live value rather than mutating env mid-test (which would
    /// race with siblings in the suite).
    private static var envFlagIsEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_AMBIENT_RECALL_V0"] == "1"
    }

    // MARK: - Flag gating

    @MainActor
    @Test("isEnabled reflects EPISTEMOS_AMBIENT_RECALL_V0 process env")
    func isEnabledMatchesEnv() {
        let state = ContextualShadowsState()
        #expect(state.isEnabled == Self.envFlagIsEnabled)
    }

    // MARK: - Panel visibility

    @MainActor
    @Test("openPanel is a no-op when V0 flag is OFF; closePanel still resets")
    func openPanelGatedByFlag() {
        let state = ContextualShadowsState()
        #expect(state.isPanelVisible == false)
        state.openPanel()
        if Self.envFlagIsEnabled {
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
        if Self.envFlagIsEnabled {
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
        guard Self.envFlagIsEnabled else {
            // Without the flag, requestRecall short-circuits and never
            // schedules — the cancellation behavior is moot.
            return
        }
        let state = ContextualShadowsState()
        let recall = InstantRecallService()
        let snapshotA = RecallContextSnapshot(
            text: "first query — longer than the minimum",
            kind: .note,
            originId: UUID()
        )
        let snapshotB = RecallContextSnapshot(
            text: "second query — longer than the minimum",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(snapshot: snapshotA, instantRecall: recall)
        let firstTask = state.pendingTask
        #expect(firstTask != nil)
        state.requestRecall(snapshot: snapshotB, instantRecall: recall)
        // Yield so the cancellation actually propagates before we observe.
        await Task.yield()
        #expect(firstTask?.isCancelled == true)
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
    @Test("configured Shadow backend feeds the production V0 recall state")
    func configuredShadowBackendFeedsV0Recall() async {
        let state = ContextualShadowsState(isEnabledOverride: true)
        let recall = InstantRecallService()
        let shadow = ContextualShadowsMockSearch(results: [
            ShadowHit(
                id: "shadow-note-1",
                title: "Shadow Note",
                snippet: "A durable shadow backend result.",
                score: 0.82,
                domain: .notes,
                source: "stub-shadow"
            ),
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
        #expect(shadow.lastDomain == .notes)
        #expect(state.currentResults.first?.id == "shadow-note-1")
        #expect(state.currentResults.first?.source == "stub-shadow")
    }

    @Test("convert falls back to the first non-empty line when no heading exists")
    func convertFirstLineFallback() {
        let raw: [InstantRecallResult] = [
            .init(id: "x", text: "    \n\nSome plain body.\nMore body.", score: 0.5),
        ]
        let hits = ContextualShadowsState.convert(raw: raw, kind: .note, originId: UUID())
        #expect(hits.first?.title == "Some plain body.")
    }

    @Test("chat-origin V0 recall classifies InstantRecall hits as note results")
    func chatOriginV0HitsRemainNoteResults() {
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

    // MARK: - Fusion source guards

    @Test("Contextual Shadows V0 is the production-mounted recall surface")
    func contextualShadowsProductionMountsArePresent() throws {
        let appBootstrap = try repoText("Epistemos/App/AppBootstrap.swift")
        let appEnvironment = try repoText("Epistemos/App/AppEnvironment.swift")
        let noteWorkspace = try repoText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let chatInputBar = try repoText("Epistemos/Views/Chat/ChatInputBar.swift")
        let proseBridge = try repoText("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(appBootstrap.contains("let contextualShadowsState = ContextualShadowsState()"))
        #expect(appEnvironment.contains(".environment(bootstrap.contextualShadowsState)"))

        #expect(noteWorkspace.contains("@Environment(ContextualShadowsState.self)"))
        #expect(noteWorkspace.contains("ContextualShadowsPanel(onOpen: openContextualShadowHit)"))
        #expect(noteWorkspace.contains("ContextualShadowsButton()"))

        #expect(chatInputBar.contains("@Environment(ContextualShadowsState.self)"))
        #expect(chatInputBar.contains("scheduleContextualShadowsRecall(for:"))
        #expect(chatInputBar.contains("ContextualShadowsPanel(onOpen: openContextualShadowHit)"))
        #expect(chatInputBar.contains("ContextualShadowsButton()"))

        #expect(proseBridge.contains("scheduleContextualShadowsRecall(newText)"))
        #expect(proseBridge.contains("state.requestRecall(snapshot: snapshot, instantRecall: instantRecall)"))
    }

    @Test("Contextual Shadows V0 prefers Shadow search without mounting the V1 Halo controller")
    func contextualShadowsCurrentBackendContract() throws {
        let stateSource = try repoText("Epistemos/State/ContextualShadowsState.swift")

        #expect(stateSource.contains("instantRecall: InstantRecallService"))
        #expect(stateSource.contains("instantRecall.searchAsync("))
        #expect(stateSource.contains("ShadowSearchServicing"),
                "The approved V0 route should prefer the Shadow backend when AppBootstrap configures it.")
        #expect(!stateSource.contains("HaloController"),
                "The production-mounted V0 surface should not silently become the unmounted V1 Halo controller.")
    }

    @Test("Contextual Shadows panel displays recall source provenance")
    func contextualShadowsPanelDisplaysSourceProvenance() throws {
        let panelSource = try repoText("Epistemos/Views/Recall/ContextualShadowsPanel.swift")

        #expect(panelSource.contains("hit.source"))
    }

    @Test("AppBootstrap ignores stale Shadow backend init during vault switches")
    func appBootstrapGuardsShadowBackendAgainstStaleVaultSwitches() throws {
        let appBootstrap = try repoText("Epistemos/App/AppBootstrap.swift")

        #expect(appBootstrap.contains("contextualShadowsState.configureShadowSearch(nil)"))
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
}

@MainActor
private final class ContextualShadowsMockSearch: ShadowSearchServicing, @unchecked Sendable {
    var results: [ShadowHit]
    private(set) var callCount = 0
    private(set) var lastQuery = ""
    private(set) var lastDomain: ShadowDomain = .notes

    init(results: [ShadowHit]) {
        self.results = results
    }

    nonisolated func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit] {
        await MainActor.run {
            self.callCount += 1
            self.lastQuery = text
            self.lastDomain = domain
        }
        return await MainActor.run { Array(self.results.prefix(limit)) }
    }
}
