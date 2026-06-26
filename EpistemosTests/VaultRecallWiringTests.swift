import Foundation
import Testing
@testable import Epistemos

// Wiring #2 (T21 Vault Recall Contract -> ResourceService) Swift
// integration test. Verifies the WRV "Verified" bar:
//
//   - `VaultRecallBridge.trace` returns a decoded production
//     `VaultRecallTrace` for a normal query when the app-side search
//     index provider is installed.
//   - The trace records the Lexical signal and at least one candidate.
//   - `VaultRecallMetrics.shared` records latency + signal summary
//     after a successful trace (drives `VaultRecallHealthRow`).
//   - `strip_query_chatter` empties chatter-only inputs and the
//     all-chatter-fallback flag fires; downstream consumers MUST treat
//     this trace as weak evidence.
//   - `VaultRecallFlags.isEnabled` toggles via UserDefaults + env.

@Suite("Vault Recall Wiring #2", .serialized)
struct VaultRecallWiringTests {
    private func resetBridge() {
        VaultRecallBridge.installTraceProvider(nil)
        VaultRecallMetrics.shared.reset()
    }

    private func makeSearchIndexService() throws -> SearchIndexService {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-recall-search-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        let service = try SearchIndexService(databaseURL: databaseURL)
        try service.upsert(
            id: "page-residency-governance",
            title: "Residency Governance",
            body: "Production-only vault recall evidence for residency governance and substrate terms.",
            tags: "architecture",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try service.upsert(
            id: "page-tier-compression",
            title: "Tier Compression Doctrine",
            body: "Tier compression doctrine keeps model and vault capabilities honest.",
            tags: "models",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        return service
    }

    private func installSearchIndexTraceProvider(_ service: SearchIndexService, limit: Int = 20) {
        VaultRecallBridge.installTraceProvider { query in
            let results = try service.search(query: query, limit: limit)
            return SearchIndexService.vaultRecallTrace(
                query: query,
                limit: limit,
                results: results
            )
        }
    }

    @Test("VaultRecallBridge.trace uses installed SearchIndexService provider for normal query")
    func vaultRecallBridgeTraceUsesInstalledSearchIndexProviderForNormalQuery() throws {
        resetBridge()
        defer { resetBridge() }
        installSearchIndexTraceProvider(try makeSearchIndexService())

        let trace = try #require(VaultRecallBridge.trace(query: "residency governance"))
        #expect(trace.query == "residency governance")
        #expect(trace.ladderTier == "vault-search-index-v1")
        #expect(VaultRecallBridge.detectedBackend(from: trace) == .real)
        #expect(trace.signalSummary.contains(.lexical), "Lexical signal must be present")
        #expect(trace.candidatesRetained > 0)
        #expect(trace.candidates.count == trace.candidatesRetained)
        #expect(!trace.candidates.contains { $0.path == "notes/sample.md" })
    }

    @Test("VaultRecallBridge.trace records latency + signal summary into VaultRecallMetrics")
    func vaultRecallBridgeRecordsMetricsOnSuccess() throws {
        resetBridge()
        defer { resetBridge() }
        installSearchIndexTraceProvider(try makeSearchIndexService())

        _ = try #require(VaultRecallBridge.trace(query: "tier compression doctrine"))
        let snap = VaultRecallMetrics.shared.snapshot()
        #expect(snap.totalQueries == 1)
        #expect(snap.lastCandidatesRetained > 0)
        #expect(snap.lastQueryAt != nil)
        #expect(snap.lastErrorDescription == nil)
        #expect(snap.lastBackend == .real)
        #expect(snap.lastSignalSummary.contains(.lexical))
    }

    @Test("VaultRecallBridge.trace flags all-chatter fallback for chatter-only inputs")
    func vaultRecallBridgeFlagsAllChatterFallback() throws {
        resetBridge()
        defer { resetBridge() }
        installSearchIndexTraceProvider(try makeSearchIndexService())

        let trace = try #require(VaultRecallBridge.trace(query: "show me my notes"))
        #expect(trace.allChatterFallback,
                "strip_query_chatter empties 'show me my notes'; fallback flag must fire")

        let snap = VaultRecallMetrics.shared.snapshot()
        #expect(snap.lastAllChatterFallback,
                "metrics must surface the fallback for the health-row warning chip")
    }

    @Test("VaultRecallBridge.trace falls back to scaffold when no production provider is installed")
    func vaultRecallBridgeTraceFallsBackToScaffoldWithoutProductionProvider() throws {
        resetBridge()
        defer { resetBridge() }

        let trace = try #require(VaultRecallBridge.trace(query: "residency governance"))
        let backend = VaultRecallBridge.detectedBackend(from: trace)
        #expect(backend == .stub,
                "without an installed production provider, the Rust scaffold must remain visibly marked as stub")
    }

    @Test("VaultRecallBridge.detectedBackend reads .real for vault-prefixed ladder tiers (forward-compat)")
    func vaultRecallBridgeDetectsRealBackendFromVaultLadderTier() throws {
        // Synthesize a trace whose ladder_tier carries the forward-compat
        // production prefix Terminal 2 will emit when VaultBackend
        // integration lands. The Swift heuristic must already know how to
        // surface this as `.real` so the day the Rust side flips, the UI
        // stops lying.
        let json = """
        {
          "query": "test",
          "effective_query": "test",
          "ladder_tier": "vault-hybrid-v1",
          "candidate_pool_size": 0,
          "candidates_retained": 0,
          "candidates": [],
          "signal_summary": [],
          "generated_at_ms": 0,
          "notes": [],
          "all_chatter_fallback": false
        }
        """
        let data = Data(json.utf8)
        let trace = try JSONDecoder().decode(VaultRecallTrace.self, from: data)
        #expect(VaultRecallBridge.detectedBackend(from: trace) == .real)
    }

    @Test("VaultRecallBridge.detectedBackend reads .stub for eidos-fixture ladder tiers")
    func vaultRecallBridgeDetectsStubBackendFromEidosFixtureLadderTier() throws {
        let json = """
        {
          "query": "test",
          "effective_query": "test",
          "ladder_tier": "eidos-fixture-v0",
          "candidate_pool_size": 0,
          "candidates_retained": 0,
          "candidates": [],
          "signal_summary": [],
          "generated_at_ms": 0,
          "notes": [],
          "all_chatter_fallback": false
        }
        """
        let trace = try JSONDecoder().decode(VaultRecallTrace.self, from: Data(json.utf8))
        #expect(VaultRecallBridge.detectedBackend(from: trace) == .stub)
    }

    @Test("VaultRecallTrace decodes honest PageGather escalation metadata")
    func vaultRecallTraceDecodesPageGatherEscalationMetadata() throws {
        let json = """
        {
          "query": "compare themes",
          "effective_query": "compare themes",
          "ladder_tier": "vault-chat-context-v1",
          "candidate_pool_size": 64,
          "candidates_retained": 4,
          "candidates": [],
          "signal_summary": ["lexical"],
          "generated_at_ms": 123,
          "notes": [],
          "all_chatter_fallback": false,
          "page_gather": {
            "status": "vault_escalated",
            "measurement_status": "deferred",
            "source": "VaultRecall.resolveNotesContext",
            "candidate_pool_size": 64,
            "candidates_retained": 4,
            "deferred_falsifier": "F-PageGather-Scatter",
            "schedule_class": "block_sorted",
            "locality_block_elements": 8192,
            "packetized_caller_consumed": true,
            "packets_emitted": 4,
            "dense_restore_deferred": true
          }
        }
        """
        let trace = try JSONDecoder().decode(VaultRecallTrace.self, from: Data(json.utf8))
        let pageGather = try #require(trace.pageGather)
        #expect(pageGather.status == .vaultEscalated)
        #expect(pageGather.measurementStatus == .deferred)
        #expect(pageGather.deferredFalsifier == "F-PageGather-Scatter")
        #expect(pageGather.candidatePoolSize == 64)
        #expect(pageGather.candidatesRetained == 4)
        #expect(pageGather.scheduleClass == .blockSorted)
        #expect(pageGather.localityBlockElements == 8_192)
        #expect(pageGather.scheduleLabel == "block_sorted 8192")
        #expect(pageGather.packetizedCallerConsumed)
        #expect(pageGather.packetsEmitted == 4)
        #expect(pageGather.denseRestoreDeferred)
    }

    @Test("VaultRecallMetrics.Snapshot.lastBackend reflects the most recent trace's backend origin")
    func vaultRecallMetricsSnapshotCarriesLastBackend() throws {
        resetBridge()
        defer { resetBridge() }
        installSearchIndexTraceProvider(try makeSearchIndexService())
        let before = VaultRecallMetrics.shared.snapshot()
        #expect(before.lastBackend == .unknown,
                "before any trace the backend is unknown")

        _ = try #require(VaultRecallBridge.trace(query: "tier compression doctrine"))
        let after = VaultRecallMetrics.shared.snapshot()
        #expect(after.lastBackend == .real,
                "after a SearchIndexService trace the snapshot must surface .real")
    }

    @Test("SearchIndexService production results emit real VaultRecall trace")
    func searchIndexServiceResultsEmitRealVaultRecallTrace() async throws {
        VaultRecallMetrics.shared.reset()
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-recall-search-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        let service = try SearchIndexService(databaseURL: databaseURL)
        try service.upsert(
            id: "page-vault-recall",
            title: "Vault Recall Production",
            body: "Production-only vault recall evidence with substrate phrase.",
            tags: "architecture",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let results = try await service.searchAsync(query: "substrate phrase", limit: 20)
        let trace = SearchIndexService.vaultRecallTrace(
            query: "substrate phrase",
            limit: 20,
            results: results,
            generatedAtMs: 42
        )

        #expect(trace.ladderTier == "vault-search-index-v1")
        #expect(VaultRecallBridge.detectedBackend(from: trace) == .real)
        #expect(trace.query == "substrate phrase")
        #expect(trace.effectiveQuery == "substrate phrase")
        #expect(trace.candidatePoolSize == results.count)
        #expect(trace.candidatesRetained == results.count)
        #expect(trace.signalSummary == [.lexical])
        #expect(trace.generatedAtMs == 42)
        let firstCandidate = try #require(trace.candidates.first)
        #expect(firstCandidate.path == "page-vault-recall")
        #expect(firstCandidate.title == "Vault Recall Production")
        #expect(firstCandidate.snippet?.contains("substrate") == true)
        #expect(!trace.candidates.contains { $0.path == "notes/sample.md" })

        VaultRecallBridge.recordProductionTrace(trace, latencyMs: 1.25)
        let snapshot = VaultRecallMetrics.shared.snapshot()
        #expect(snapshot.lastBackend == .real)
        #expect(snapshot.lastCandidatesRetained == results.count)
        #expect(snapshot.lastSignalSummary == [.lexical])
    }

    @Test("VaultRecallFlags.isEnabled reads UserDefaults + env-var fallback")
    func vaultRecallFlagsReadsUserDefaultsAndEnvFallback() {
        let savedDefault = UserDefaults.standard.bool(forKey: VaultRecallFlags.userDefaultsKey)
        defer { UserDefaults.standard.set(savedDefault, forKey: VaultRecallFlags.userDefaultsKey) }

        UserDefaults.standard.set(false, forKey: VaultRecallFlags.userDefaultsKey)
        let envIsSet = ProcessInfo.processInfo.environment[VaultRecallFlags.userDefaultsKey] == "1"
        if !envIsSet {
            #expect(!VaultRecallFlags.isEnabled, "flag should default to OFF")
        }

        UserDefaults.standard.set(true, forKey: VaultRecallFlags.userDefaultsKey)
        #expect(VaultRecallFlags.isEnabled, "flag should be ON after UserDefaults flip")
    }
}
