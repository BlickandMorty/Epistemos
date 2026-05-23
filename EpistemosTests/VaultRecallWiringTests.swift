import Foundation
import Testing
@testable import Epistemos

// Wiring #2 (T21 Vault Recall Contract -> ResourceService) Swift
// integration test. Verifies the WRV "Verified" bar:
//
//   - `VaultRecallBridge.trace` returns a decoded `VaultRecallTrace`
//     for a normal query.
//   - The trace records the Lexical signal and at least one candidate.
//   - `VaultRecallMetrics.shared` records latency + signal summary
//     after a successful trace (drives `VaultRecallHealthRow`).
//   - `strip_query_chatter` empties chatter-only inputs and the
//     all-chatter-fallback flag fires; downstream consumers MUST treat
//     this trace as weak evidence.
//   - `VaultRecallFlags.isEnabled` toggles via UserDefaults + env.

@Suite("Vault Recall Wiring #2")
struct VaultRecallWiringTests {

    @Test("VaultRecallBridge.trace returns trace with Lexical signal for normal query")
    func vaultRecallBridgeTraceReturnsLexicalTraceForNormalQuery() throws {
        VaultRecallMetrics.shared.reset()

        let trace = try #require(VaultRecallBridge.trace(query: "residency governance"))
        #expect(trace.query == "residency governance")
        #expect(trace.signalSummary.contains(.lexical), "Lexical signal must be present")
        #expect(trace.candidatesRetained > 0)
        #expect(trace.candidates.count == trace.candidatesRetained)
    }

    @Test("VaultRecallBridge.trace records latency + signal summary into VaultRecallMetrics")
    func vaultRecallBridgeRecordsMetricsOnSuccess() throws {
        VaultRecallMetrics.shared.reset()

        _ = try #require(VaultRecallBridge.trace(query: "tier compression doctrine"))
        let snap = VaultRecallMetrics.shared.snapshot()
        #expect(snap.totalQueries == 1)
        #expect(snap.lastCandidatesRetained > 0)
        #expect(snap.lastQueryAt != nil)
        #expect(snap.lastErrorDescription == nil)
        #expect(snap.lastSignalSummary.contains(.lexical))
    }

    @Test("VaultRecallBridge.trace flags all-chatter fallback for chatter-only inputs")
    func vaultRecallBridgeFlagsAllChatterFallback() throws {
        VaultRecallMetrics.shared.reset()

        let trace = try #require(VaultRecallBridge.trace(query: "show me my notes"))
        #expect(trace.allChatterFallback,
                "strip_query_chatter empties 'show me my notes'; fallback flag must fire")

        let snap = VaultRecallMetrics.shared.snapshot()
        #expect(snap.lastAllChatterFallback,
                "metrics must surface the fallback for the health-row warning chip")
    }

    @Test("VaultRecallBridge.detectedBackend reads .stub from the scaffold-lexical ladder tier")
    func vaultRecallBridgeDetectsStubBackendFromLadderTier() throws {
        VaultRecallMetrics.shared.reset()

        let trace = try #require(VaultRecallBridge.trace(query: "residency governance"))
        let backend = VaultRecallBridge.detectedBackend(from: trace)
        #expect(backend == .stub,
                "today the Rust side returns ladder_tier=scaffold-lexical; Swift must surface this honestly")
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

    @Test("VaultRecallMetrics.Snapshot.lastBackend reflects the most recent trace's backend origin")
    func vaultRecallMetricsSnapshotCarriesLastBackend() throws {
        VaultRecallMetrics.shared.reset()
        let before = VaultRecallMetrics.shared.snapshot()
        #expect(before.lastBackend == .unknown,
                "before any trace the backend is unknown")

        _ = try #require(VaultRecallBridge.trace(query: "tier compression doctrine"))
        let after = VaultRecallMetrics.shared.snapshot()
        #expect(after.lastBackend == .stub,
                "after a scaffold-lexical trace the snapshot must surface .stub")
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
