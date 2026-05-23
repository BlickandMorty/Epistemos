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
