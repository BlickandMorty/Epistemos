import Foundation
import Testing
@testable import Epistemos

// Wiring #1 (T10 Eidos → QueryRuntime) Swift integration test.
//
// Verifies the Wiring #1 "Verified" bar:
//
//   - `EidosBridge.search` returns a decoded `EidosContextPacket`
//     against the seeded fixture corpus.
//   - Returned hits satisfy the closed-citation contract (every
//     emitted `source_id` validates against the same packet).
//   - `EidosMetrics.shared` records latency + citation count after
//     a successful query (drives `EidosHealthRow`).
//   - Empty / unmatched queries produce zero hits but do not throw —
//     callers fall through to the legacy FTS / RRF path.

@Suite("Eidos Wiring #1")
struct EidosWiringTests {

    @Test("EidosBridge.search returns citation-bearing packet for seeded fixture query")
    func eidosBridgeReturnsCitationBearingPacketForFixtureQuery() throws {
        EidosMetrics.shared.reset()

        let packet = try #require(EidosBridge.search(query: "welcome", topK: 5))
        #expect(!packet.hits.isEmpty, "fixture corpus should match 'welcome'")
        #expect(packet.manifestId.raw == "eidos-fixture-2026-05-23")

        for hit in packet.hits {
            let citation = EidosCitation(
                sourceId: hit.sourceId,
                manifestId: packet.manifestId
            )
            if case .failure(let error) = packet.validate(citation: citation) {
                Issue.record("legitimate hit citation rejected: \(error)")
            }
        }
    }

    @Test("EidosBridge.search records latency + citation count into EidosMetrics")
    func eidosBridgeRecordsMetricsOnSuccess() throws {
        EidosMetrics.shared.reset()

        _ = try #require(EidosBridge.search(query: "eidos", topK: 8))
        let snap = EidosMetrics.shared.snapshot()
        #expect(snap.totalQueries == 1, "one query should have been recorded")
        #expect(snap.lastCitationCount > 0, "fixture matches 'eidos'")
        #expect(snap.lastQueryAt != nil)
        #expect(snap.lastErrorDescription == nil)
    }

    @Test("EidosBridge.search returns empty-hits packet for unmatched query (no throw)")
    func eidosBridgeReturnsEmptyPacketForUnmatchedQuery() throws {
        EidosMetrics.shared.reset()

        let packet = try #require(EidosBridge.search(query: "zzzzz_unmatchable_zzzzz", topK: 5))
        #expect(packet.hits.isEmpty, "no fixture document matches the gibberish query")
        // Even on zero hits the metrics surface should record the call so
        // the health row can show the query happened.
        let snap = EidosMetrics.shared.snapshot()
        #expect(snap.totalQueries == 1)
        #expect(snap.lastCitationCount == 0)
    }

    @Test("EidosBridge.detectedBackend reads .fixture from the seeded fixture manifest")
    func eidosBridgeDetectsFixtureBackendFromManifestPrefix() throws {
        EidosMetrics.shared.reset()

        let packet = try #require(EidosBridge.search(query: "welcome", topK: 5))
        let backend = EidosBridge.detectedBackend(from: packet)
        #expect(backend == .fixture,
                "today the Rust side seeds a fixture corpus; Swift must surface this honestly")
    }

    @Test("EidosBridge.detectedBackend reads .real for vault-prefixed manifests (forward-compat)")
    func eidosBridgeDetectsRealBackendFromVaultManifestPrefix() throws {
        // Synthesize a packet whose manifestId carries the forward-compat
        // production prefix Terminal 2 will emit when real-vault binding
        // lands. The Swift heuristic must already know how to surface this
        // as `.real` so the day the Rust side flips, the UI stops lying.
        let json = """
        {
          "query": {
            "text": "test",
            "mode": "Lexical",
            "top_k": 5,
            "query_vector": null
          },
          "manifest_id": "vault-abc123",
          "hits": []
        }
        """
        let data = Data(json.utf8)
        let packet = try JSONDecoder().decode(EidosContextPacket.self, from: data)
        #expect(EidosBridge.detectedBackend(from: packet) == .real)
    }

    @Test("EidosMetrics.Snapshot.lastBackend reflects the most recent search's backend origin")
    func eidosMetricsSnapshotCarriesLastBackend() throws {
        EidosMetrics.shared.reset()
        let before = EidosMetrics.shared.snapshot()
        #expect(before.lastBackend == .unknown,
                "before any search the backend is unknown")

        _ = try #require(EidosBridge.search(query: "welcome", topK: 5))
        let after = EidosMetrics.shared.snapshot()
        #expect(after.lastBackend == .fixture,
                "after a fixture-backed search the snapshot must surface .fixture")
    }

    @Test("EidosFlags.isEnabled reads UserDefaults + env-var fallback")
    func eidosFlagsReadsUserDefaultsAndEnvFallback() {
        // Save state to restore after test.
        let savedDefault = UserDefaults.standard.bool(forKey: EidosFlags.userDefaultsKey)
        defer { UserDefaults.standard.set(savedDefault, forKey: EidosFlags.userDefaultsKey) }

        // Default off when both UserDefaults and env are unset.
        UserDefaults.standard.set(false, forKey: EidosFlags.userDefaultsKey)
        let envIsSet = ProcessInfo.processInfo.environment[EidosFlags.userDefaultsKey] == "1"
        if !envIsSet {
            #expect(!EidosFlags.isEnabled, "flag should default to OFF")
        }

        // On when UserDefaults flips it.
        UserDefaults.standard.set(true, forKey: EidosFlags.userDefaultsKey)
        #expect(EidosFlags.isEnabled, "flag should be ON after UserDefaults flip")
    }
}
