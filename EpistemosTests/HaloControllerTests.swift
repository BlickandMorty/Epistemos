import Foundation
import Testing

@testable import Epistemos

/// Wave 8 source-guard for the HaloController state machine + query
/// extraction (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 8.2,
///  cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"The state machine").
///
/// The controller is the V1 differentiator — every transition + budget
/// is asserted here so a refactor that breaks the user-facing contract
/// fails CI immediately.

@MainActor
final class MockShadowSearchService: ShadowSearchServicing, @unchecked Sendable {
    var nextResults: [ShadowHit] = []
    /// When non-nil, the next `searchReportingErrors` call surfaces this
    /// as `errorMessage` (and yields the empty hit list) — same shape
    /// the production `ShadowSearchService.searchReportingErrors` returns
    /// after catching an FFI throw. Used by the RCA-P1-013 force-failure
    /// tests so the degraded-UI contract is pinned without depending on
    /// the real Rust backend being able to crash on command.
    var nextErrorMessage: String?
    private(set) var callCount: Int = 0
    private(set) var lastQuery: String = ""
    private(set) var lastDomain: ShadowDomain = .notes
    private(set) var lastLimit: Int = 0

    nonisolated func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit] {
        await MainActor.run {
            self.callCount += 1
            self.lastQuery = text
            self.lastDomain = domain
            self.lastLimit = limit
        }
        return await MainActor.run { self.nextResults }
    }

    /// Explicit override of the error-reporting variant so the test can
    /// inject a failure message. The default extension would otherwise
    /// always report nil — bypassing the production code path that
    /// transitions HaloController to `.errorRecoverable`.
    nonisolated func searchReportingErrors(
        text: String,
        domain: ShadowDomain,
        limit: Int
    ) async -> (hits: [ShadowHit], errorMessage: String?) {
        let snapshot: (results: [ShadowHit], error: String?) = await MainActor.run {
            self.callCount += 1
            self.lastQuery = text
            self.lastDomain = domain
            self.lastLimit = limit
            return (self.nextResults, self.nextErrorMessage)
        }
        if let message = snapshot.error {
            return (hits: [], errorMessage: message)
        }
        return (hits: snapshot.results, errorMessage: nil)
    }
}

@MainActor
@Suite("HaloController state machine (Wave 8)")
struct HaloControllerTests {

    // MARK: - Helpers

    private static func waitForState(
        _ controller: HaloController,
        until predicate: @MainActor @Sendable (HaloState) -> Bool,
        timeout: TimeInterval = 1.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await MainActor.run(body: { predicate(controller.state) }) {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10 ms
        }
    }

    private func mockController(
        results: [ShadowHit] = [],
        debounceMs: Int = 20,    // tight in tests
        scoreThreshold: Float = 0.2
    ) -> (HaloController, MockShadowSearchService) {
        let mock = MockShadowSearchService()
        mock.nextResults = results
        let ctrl = HaloController(
            search: mock,
            debounceWindowMs: debounceMs,
            minQueryChars: 3,
            scoreThreshold: scoreThreshold
        )
        return (ctrl, mock)
    }

    private func sampleHit(_ id: String, score: Float = 0.8) -> ShadowHit {
        ShadowHit(
            id: id,
            title: "title \(id)",
            snippet: "snippet \(id)",
            score: score,
            domain: .notes,
            source: "stub"
        )
    }

    private func sampleHit(_ id: String, score: Float = 0.8, domain: ShadowDomain) -> ShadowHit {
        ShadowHit(
            id: id,
            title: "title \(id)",
            snippet: "snippet \(id)",
            score: score,
            domain: domain,
            source: "stub"
        )
    }

    // MARK: - Initial state

    @Test("controller starts in .dormant with no matches")
    func initialState() {
        let (ctrl, _) = mockController()
        #expect(ctrl.state == .dormant)
        #expect(ctrl.matches.isEmpty)
        #expect(ctrl.domain == .notes)
    }

    // MARK: - Dormant → Sensing → Available

    @Test("typing meaningful text drives Dormant → Sensing → Available")
    func dormantToAvailable() async {
        let (ctrl, mock) = mockController(results: [
            sampleHit("n1", score: 0.5),
            sampleHit("n2", score: 0.4),
        ])
        ctrl.editorTextDidChange("hello kant world", domain: .notes)
        // Synchronously transitioned to .sensing.
        #expect(ctrl.state == .sensing)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        #expect(ctrl.state == .available(count: 2))
        #expect(ctrl.matches.count == 2)
        #expect(mock.callCount == 1)
    }

    @Test("results below score threshold drop the controller back to .dormant")
    func belowThresholdReturnsToDormant() async {
        let (ctrl, _) = mockController(
            results: [sampleHit("n1", score: 0.05)],
            scoreThreshold: 0.2
        )
        ctrl.editorTextDidChange("hello kant world", domain: .notes)
        await Self.waitForState(ctrl, until: { $0 == .dormant })
        #expect(ctrl.state == .dormant)
        #expect(ctrl.matches.isEmpty)
    }

    @Test("emptying the editor cancels in-flight search and returns to .dormant")
    func emptyTextReturnsToDormant() async {
        let (ctrl, _) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hello kant world", domain: .notes)
        ctrl.editorTextDidChange("", domain: .notes)
        await Self.waitForState(ctrl, until: { $0 == .dormant })
        #expect(ctrl.state == .dormant)
        #expect(ctrl.matches.isEmpty)
    }

    // MARK: - Stop-word filter

    @Test("only stop words doesn't trigger search")
    func stopWordsOnlyNoSearch() async {
        let (ctrl, mock) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("the and a or but", domain: .notes)
        await Self.waitForState(ctrl, until: { $0 == .dormant })
        #expect(ctrl.state == .dormant)
        #expect(mock.callCount == 0,
                "all-stop-words query must not hit the search backend")
    }

    @Test("query shorter than minQueryChars doesn't trigger search")
    func shortQueryNoSearch() async {
        let (ctrl, mock) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hi", domain: .notes)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(ctrl.state == .dormant)
        #expect(mock.callCount == 0,
                "query under minQueryChars must not hit the search backend")
    }

    // MARK: - Cooperative cancellation (rapid typing)

    @Test("rapid typing cancels stale searches; only the last query lands")
    func rapidTypingCancelsStale() async {
        let (ctrl, mock) = mockController(results: [sampleHit("n1")], debounceMs: 30)
        // Three keystrokes inside the debounce window.
        ctrl.editorTextDidChange("hello kant once", domain: .notes)
        ctrl.editorTextDidChange("hello kant twice", domain: .notes)
        ctrl.editorTextDidChange("hello kant thrice", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        #expect(mock.callCount == 1,
                "rapid typing must cancel earlier searches; only the last debounce-window survivor hits the backend")
        #expect(mock.lastQuery == "hello kant thrice")
    }

    // MARK: - Panel open / close transitions

    @Test("openPanel transitions Available → Open(domain)")
    func openPanelTransition() async {
        let (ctrl, _) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hello kant world", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        ctrl.openPanel()
        #expect(ctrl.state == .open(domain: .notes))
    }

    @Test("opening Halo panel refreshes GraphEvent projection report")
    func openPanelRefreshesGraphEventProjectionReport() async {
        let mock = MockShadowSearchService()
        mock.nextResults = [sampleHit("n1")]
        var requestedLimit = 0
        let report = GraphEventAuditProjectionReport(
            generatedAtMs: 42,
            eventCount: 3,
            nodeCount: 2,
            edgeCount: 1,
            latestEventID: "graph-event-latest",
            nodeIDs: ["n1", "n2"],
            edgeIDs: ["n1->n2:mentions"]
        )
        let ctrl = HaloController(
            search: mock,
            debounceWindowMs: 1,
            minQueryChars: 3,
            scoreThreshold: 0.2,
            graphProjectionReportProvider: { limit in
                requestedLimit = limit
                return report
            }
        )

        ctrl.editorTextDidChange("hello kant world", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        ctrl.openPanel()

        #expect(ctrl.state == .open(domain: .notes))
        #expect(requestedLimit == 100)
        #expect(ctrl.graphProjectionReport == report)
    }

    @Test("openPanel ignored when not in .available")
    func openPanelIgnoredWhenNotAvailable() {
        let (ctrl, _) = mockController()
        ctrl.openPanel()
        #expect(ctrl.state == .dormant,
                "openPanel from .dormant must be a no-op (precondition: must be in .available)")
    }

    @Test("closePanel from .open returns to .available when matches present")
    func closePanelToAvailable() async {
        let (ctrl, _) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hello kant", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        ctrl.openPanel()
        ctrl.closePanel()
        #expect(ctrl.state == .available(count: 1))
    }

    @Test("closePanel from .open returns to .dormant when matches empty")
    func closePanelToDormantWhenEmpty() async {
        let (ctrl, _) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hello kant", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        ctrl.openPanel()
        // Simulate the editor cleared while panel was open.
        ctrl.editorTextDidChange("", domain: .notes)
        await Self.waitForState(ctrl, until: { $0 == .dormant })
        // The dormant transition collapses any further closePanel.
        ctrl.closePanel()
        #expect(ctrl.state == .dormant)
    }

    @Test("selectDomain re-runs the current query and keeps an open panel open")
    func selectDomainRerunsCurrentQueryWhileOpen() async {
        let (ctrl, mock) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hello kant", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        ctrl.openPanel()

        mock.nextResults = [sampleHit("c1", domain: .chats)]
        ctrl.selectDomain(.chats)

        await Self.waitForState(ctrl, until: { $0 == .open(domain: .chats) })
        #expect(mock.callCount == 2)
        #expect(mock.lastQuery == "hello kant")
        #expect(mock.lastDomain == .chats)
        #expect(ctrl.matches == [sampleHit("c1", domain: .chats)])
    }

    // MARK: - Nested action transitions

    @Test("beginEditingNote transitions Open → EditingNote(id)")
    func beginEditingNote() async {
        let (ctrl, _) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hello kant", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        ctrl.openPanel()
        ctrl.beginEditingNote(id: "n1")
        #expect(ctrl.state == .editingNote(id: "n1"))
    }

    @Test("endNestedAction returns to Open(domain)")
    func endNestedActionReturnsToOpen() async {
        let (ctrl, _) = mockController(results: [sampleHit("n1")])
        ctrl.editorTextDidChange("hello kant", domain: .notes)
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        ctrl.openPanel()
        ctrl.beginEditingNote(id: "n1")
        ctrl.endNestedAction()
        #expect(ctrl.state == .open(domain: .notes))
    }

    // MARK: - Recoverable error

    @Test("reportRecoverableError transitions to .errorRecoverable")
    func recoverableError() {
        let (ctrl, _) = mockController()
        ctrl.reportRecoverableError("backend not yet ready")
        if case let .errorRecoverable(msg) = ctrl.state {
            #expect(msg == "backend not yet ready")
        } else {
            #expect(Bool(false), "expected .errorRecoverable; got \(ctrl.state)")
        }
    }

    // MARK: - RCA-P1-013 — force-failure path

    /// RCA-P1-013 acceptance: a backend that reports an `errorMessage`
    /// during a search must surface in the controller as
    /// `.errorRecoverable(message)`, NOT a silent empty-matches state
    /// that looks like "no hits." Pins the degraded-UI contract.
    @Test("backend-reported errorMessage drives controller to .errorRecoverable")
    func backendErrorTransitionsToErrorRecoverable() async {
        let (ctrl, mock) = mockController(results: [sampleHit("n1", score: 0.9)])
        mock.nextErrorMessage = "Search backend unavailable. Try reopening the vault."
        ctrl.editorTextDidChange("kant on duty")
        await Self.waitForState(ctrl, until: { state in
            if case .errorRecoverable = state { return true }
            return false
        })
        if case let .errorRecoverable(msg) = ctrl.state {
            #expect(msg == "Search backend unavailable. Try reopening the vault.")
        } else {
            #expect(Bool(false), "expected .errorRecoverable; got \(ctrl.state)")
        }
        // Matches must be cleared so the UI doesn't render stale hits
        // alongside a "backend unavailable" banner.
        #expect(ctrl.matches.isEmpty)
        #expect(mock.callCount == 1)
    }

    /// Recovery contract: once the backend stops reporting errors, the
    /// next successful query must transition out of `.errorRecoverable`
    /// to `.available` (or `.dormant` when no hits clear the threshold).
    /// Without this, a single transient failure would latch the UI into
    /// the degraded state permanently.
    @Test("recovery from .errorRecoverable when subsequent search succeeds")
    func recoveryFromBackendErrorOnNextSearch() async {
        let (ctrl, mock) = mockController(results: [sampleHit("n1", score: 0.9)])
        mock.nextErrorMessage = "backend gone"
        ctrl.editorTextDidChange("kant on duty")
        await Self.waitForState(ctrl, until: { state in
            if case .errorRecoverable = state { return true }
            return false
        })
        // Backend recovers — clear the injected error and type a new query.
        mock.nextErrorMessage = nil
        ctrl.editorTextDidChange("kant on freedom")
        await Self.waitForState(ctrl, until: { state in
            if case .available = state { return true }
            return false
        })
        if case let .available(count) = ctrl.state {
            #expect(count == 1)
        } else {
            #expect(Bool(false), "expected .available after recovery; got \(ctrl.state)")
        }
    }

    // MARK: - extractQueryContext

    @Test("extractQueryContext returns trailing paragraph after \\n\\n split")
    func extractQueryContextParagraph() {
        let text = "old paragraph one\n\nold paragraph two\n\ncurrent paragraph mentions kant"
        let ctx = HaloController.extractQueryContext(from: text)
        #expect(ctx == "current paragraph mentions kant")
    }

    @Test("extractQueryContext returns the trailing 256 chars when no paragraph break")
    func extractQueryContextTrailingTail() {
        let big = String(repeating: "a", count: 500)
        let ctx = HaloController.extractQueryContext(from: big)
        #expect(ctx.count == 256)
    }

    @Test("extractQueryContext returns empty for empty text")
    func extractQueryContextEmpty() {
        #expect(HaloController.extractQueryContext(from: "") == "")
    }

    // MARK: - HaloState properties

    @Test("HaloState.isVisible is true only for surfaces that should render")
    func haloStateVisibility() {
        #expect(HaloState.dormant.isVisible == false)
        #expect(HaloState.sensing.isVisible == false)
        #expect(HaloState.available(count: 1).isVisible == true)
        #expect(HaloState.open(domain: .notes).isVisible == true)
        #expect(HaloState.editingNote(id: "x").isVisible == true)
        #expect(HaloState.summarizingChat(id: "x").isVisible == true)
        #expect(HaloState.errorRecoverable("e").isVisible == true)
    }

    @Test("HaloState.isPanelOpen reflects the open / nested-action states")
    func haloStatePanelOpen() {
        #expect(HaloState.dormant.isPanelOpen == false)
        #expect(HaloState.sensing.isPanelOpen == false)
        #expect(HaloState.available(count: 1).isPanelOpen == false)
        #expect(HaloState.open(domain: .notes).isPanelOpen == true)
        #expect(HaloState.editingNote(id: "x").isPanelOpen == true)
        #expect(HaloState.summarizingChat(id: "x").isPanelOpen == true)
        #expect(HaloState.errorRecoverable("e").isPanelOpen == false)
    }

    // MARK: - ShadowDomain wire format

    @Test("ShadowDomain wire format matches the Rust ShadowDocument.domain field")
    func shadowDomainWireFormat() {
        #expect(ShadowDomain.notes.wireValue == "note")
        #expect(ShadowDomain.chats.wireValue == "chat")
    }

    @Test("ShadowDomain decoder rejects unknown wire values (defensive cross-FFI contract)")
    func shadowDomainDecoderRejectsUnknownValues() throws {
        // Defensive cross-FFI decoder gate, mirroring the Rust-side
        // pattern (commits 88e529733 / bfb6a7d65 / f8899ee8e /
        // 4e347bcbb / 952311cbd / 4644336b8). A future Rust build
        // might emit a third domain ("memo", "fragment"); Swift must
        // throw a typed DecodingError rather than silently treat it
        // as one of the existing two.
        //
        // Swift's String-rawed enum decoder throws on unknown raw
        // values by default. Pin that contract here so a future
        // custom-decoder migration that catches-and-swallows the
        // error doesn't silently coerce unknown domains.
        let unknownJSON = "\"memo\"".data(using: .utf8)!
        do {
            _ = try JSONDecoder().decode(ShadowDomain.self, from: unknownJSON)
            #expect(Bool(false), "decoder should have thrown for unknown domain")
        } catch is DecodingError {
            // Expected — String-rawed enum default behavior.
        } catch {
            #expect(Bool(false), "unexpected error: \(error)")
        }

        // Known domains decode cleanly.
        let noteJSON = "\"note\"".data(using: .utf8)!
        #expect(try JSONDecoder().decode(ShadowDomain.self, from: noteJSON) == .notes)
        let chatJSON = "\"chat\"".data(using: .utf8)!
        #expect(try JSONDecoder().decode(ShadowDomain.self, from: chatJSON) == .chats)
    }
}
