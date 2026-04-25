import Foundation
import Testing
@testable import Epistemos

@Suite("ContextualShadowsState")
struct ContextualShadowsStateTests {

    // MARK: - Helpers

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
        let snapshot = RecallContextSnapshot(
            text: "abc",
            kind: .note,
            originId: UUID()
        )
        state.requestRecall(snapshot: snapshot, instantRecall: recall)
        // No task should be scheduled for a query under 6 chars.
        #expect(state.pendingTask == nil)
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
        #expect(hits.first?.snippet.hasPrefix("# Hello World") == true
                || hits.first?.snippet.contains("Hello World") == true)
    }

    @Test("convert falls back to the first non-empty line when no heading exists")
    func convertFirstLineFallback() {
        let raw: [InstantRecallResult] = [
            .init(id: "x", text: "    \n\nSome plain body.\nMore body.", score: 0.5),
        ]
        let hits = ContextualShadowsState.convert(raw: raw, kind: .note, originId: UUID())
        #expect(hits.first?.title == "Some plain body.")
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
}
