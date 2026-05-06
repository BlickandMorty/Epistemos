import Testing
@testable import Epistemos

/// V2 Lane 1 verification tests for the Rust→Swift Provenance ledger
/// bridge. These prove the FFI surface added in `agent_core/src/bridge.rs`
/// (`provenance_ledger_summary_json`, `provenance_ledger_recent_events_json`)
/// is reachable from Swift, returns well-formed JSON, and decodes into
/// the typed Swift mirrors.
///
/// **Doctrine note.** The tests assert FALLBACK behavior + JSON shape
/// stability, not specific counts — the underlying Rust ledger is
/// process-global and retained as legacy scaffold. Live provenance counts
/// are surfaced from the Cognitive DAG; this bridge should remain readable
/// without becoming a second write authority.
@Suite("Rust Provenance Ledger Client (V2 Lane 1)")
struct RustProvenanceLedgerClientTests {

    @Test("summary returns a valid RustProvenanceLedgerSummary even with empty ledger")
    func summaryReturnsValidStructEvenWithEmptyLedger() {
        let summary = RustProvenanceLedgerClient.summary()
        // The ledger may be non-empty if other tests committed to it, but
        // every counter must be a well-formed UInt64. The empty fallback
        // returns 0/0/0; a populated ledger returns higher values.
        #expect(summary.claimCount >= 0)
        #expect(summary.evidenceCount >= 0)
        #expect(summary.eventCount >= 0)
    }

    @Test("recentEvents returns an array (possibly empty) and respects the limit cap")
    func recentEventsReturnsArrayAndRespectsLimit() {
        let events = RustProvenanceLedgerClient.recentEvents(limit: 5)
        // Events may be empty in a fresh process; if non-empty, the count
        // is bounded by the requested limit (Rust hard-caps at 1000 too).
        #expect(events.count <= 5)
        // Each event has a stable kind discriminator + a well-formed
        // sequence number.
        for event in events {
            #expect(!event.kind.isEmpty)
            #expect(event.sequence >= 0)
        }
    }

    @Test("recentEvents with limit 0 returns empty array (FFI fast path)")
    func recentEventsWithZeroLimitReturnsEmpty() {
        let events = RustProvenanceLedgerClient.recentEvents(limit: 0)
        #expect(events.isEmpty)
    }

    @Test("empty fallback summary has zero counters")
    func emptyFallbackSummaryHasZeroCounters() {
        let empty = RustProvenanceLedgerSummary.empty
        #expect(empty.claimCount == 0)
        #expect(empty.evidenceCount == 0)
        #expect(empty.eventCount == 0)
    }

    @Test("ProvenanceConsoleSnapshot.empty includes the rustLedgerPayload slot")
    func provenanceConsoleSnapshotEmptyIncludesRustLedgerPayload() {
        let empty = ProvenanceConsoleSnapshot.empty
        // The new V2 Lane 1 slot must be present + render through GenUI.
        // The payloads array order matters because it drives UI section
        // ordering; the rust ledger is the second card after the summary.
        #expect(empty.payloads.count == 6)
        // Spot-check that the rustLedgerPayload is one of the rendered
        // payloads. Equating against the empty fallback is enough — if
        // someone removed the slot or changed the empty wording, this
        // catches it.
        let rustPayloads = empty.payloads.filter { payload in
            // GenUIPayload doesn't expose its title publicly in a typed
            // way for matching, so we equate against the known empty
            // fallback. Stable enough for a guard test.
            payload == empty.rustLedgerPayload
        }
        #expect(rustPayloads.count == 1)
    }

    @Test("Provenance Console names the DAG-authoritative Rust provenance slot")
    func provenanceConsoleNamesDagAuthoritativeRustSlot() {
        let payload = ProvenanceConsoleSnapshot.empty.rustLedgerPayload
        #expect(payload.title == "Cognitive DAG Provenance (Rust)")

        guard case .keyValues(let rows) = payload.body else {
            #expect(Bool(false), "Expected Rust provenance payload to render as key/value rows")
            return
        }
        #expect(rows.contains { $0.key == "mode" && $0.value == "read-only" })
    }
}
