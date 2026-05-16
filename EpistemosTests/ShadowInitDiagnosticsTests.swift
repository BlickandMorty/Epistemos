import Testing
@testable import Epistemos

@Suite("Shadow init-failure diagnostics (ISSUE-2026-05-10-001)")
nonisolated struct ShadowInitDiagnosticsTests {

    @Test("recordInitFailure marks the snapshot as degraded with the failure class")
    func recordsInitFailureAndDegraded() async {
        ShadowSearchDiagnostics.shared.reset()
        defer { ShadowSearchDiagnostics.shared.reset() }

        let baseline = ShadowSearchDiagnostics.shared.snapshot()
        #expect(baseline.isDegraded == false)
        #expect(baseline.lastInitFailureClass == nil)

        ShadowSearchDiagnostics.shared.recordInitFailure(class: .handleOpen)

        let snap = ShadowSearchDiagnostics.shared.snapshot()
        #expect(snap.isDegraded)
        #expect(snap.lastInitFailureClass == "handle_open")
        #expect(snap.lastInitFailureAt != nil)
        // Init failure doesn't bump search counters.
        #expect(snap.totalSearches == 0)
        #expect(snap.totalFailures == 0)
    }

    @Test("embedderWarm init failure is independent from handleOpen")
    func embedderWarmIsDistinctFromHandleOpen() async {
        ShadowSearchDiagnostics.shared.reset()
        defer { ShadowSearchDiagnostics.shared.reset() }

        ShadowSearchDiagnostics.shared.recordInitFailure(class: .embedderWarm)
        let snap = ShadowSearchDiagnostics.shared.snapshot()
        #expect(snap.lastInitFailureClass == "embedder_warm")
        #expect(snap.isDegraded)
    }

    @Test("A subsequent successful search clears degraded state after init failure")
    func successfulSearchAfterInitFailureRecovers() async throws {
        ShadowSearchDiagnostics.shared.reset()
        defer { ShadowSearchDiagnostics.shared.reset() }

        ShadowSearchDiagnostics.shared.recordInitFailure(class: .embedderWarm)
        #expect(ShadowSearchDiagnostics.shared.snapshot().isDegraded)

        let client = InMemoryShadowFFIClient()
        let doc = ShadowDocumentDTO(
            docId: "n1",
            title: "Recovery",
            body: "smoke",
            domain: .notes,
            originVaultKey: nil
        )
        try client.insert(document: doc)
        let service = await ShadowSearchService(client: client)
        _ = await service.search(text: "smoke", domain: .notes, limit: 5)

        let snap = ShadowSearchDiagnostics.shared.snapshot()
        // Init failure record persists for diagnostics, but isDegraded
        // flips back to false once a search succeeds after the init failure.
        #expect(snap.lastInitFailureClass == "embedder_warm")
        #expect(snap.isDegraded == false)
        #expect(snap.totalSearches == 1)
    }

    @Test("Reset clears all init-failure state")
    func resetClearsInitFailureState() async {
        ShadowSearchDiagnostics.shared.reset()
        defer { ShadowSearchDiagnostics.shared.reset() }

        ShadowSearchDiagnostics.shared.recordInitFailure(class: .handleOpen)
        #expect(ShadowSearchDiagnostics.shared.snapshot().lastInitFailureClass != nil)

        ShadowSearchDiagnostics.shared.reset()
        let snap = ShadowSearchDiagnostics.shared.snapshot()
        #expect(snap.lastInitFailureClass == nil)
        #expect(snap.lastInitFailureAt == nil)
        #expect(snap.isDegraded == false)
    }
}
