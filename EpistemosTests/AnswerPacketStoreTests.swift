import Testing
import Foundation

@testable import Epistemos

// SUBSTRATE Phase 2 (owner 2026-06-20): the durable AnswerPacket persistence primitive. These
// headless tests pin the append-only JSONL round-trip over the FROZEN AnswerPacket schema (Phase 0),
// the limit/most-recent-first contract, the bounded compaction, and corruption tolerance — all on a
// temp file so they run without the app. The live emit() wiring is a separate slice.
@Suite("Substrate Phase 2 — AnswerPacket persistence store")
struct AnswerPacketStoreTests {

    private func tempStore() -> (store: AnswerPacketStore, cleanup: () -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apstore-\(UUID().uuidString).jsonl")
        return (AnswerPacketStore(fileURL: url), { try? FileManager.default.removeItem(at: url) })
    }

    private func packet(_ id: String, _ mode: AttentionMode = .unavailable) -> AnswerPacket {
        AnswerPacket(
            id: id, attentionMode: mode, witnessedStateRef: "ws-\(id)", mutationEnvelopeRef: "me-\(id)")
    }

    @Test("append + loadRecent round-trips packets most-recent-first (frozen schema survives disk)")
    func roundTrip() throws {
        let (store, cleanup) = tempStore(); defer { cleanup() }
        #expect(try store.loadRecent(limit: 10).isEmpty)   // missing file → empty, no throw
        try store.append(packet("a", .staticFallback))
        try store.append(packet("b"))
        try store.append(packet("c", .dynamic))
        let all = try store.loadRecent(limit: 10)
        #expect(all.map(\.id) == ["c", "b", "a"])          // most-recent-first
        #expect(all.first?.attentionMode == .dynamic)
        #expect(all.last?.attentionMode == .staticFallback) // attention_mode survived the round-trip
    }

    @Test("loadRecent honors the limit (last N, most-recent-first)")
    func limit() throws {
        let (store, cleanup) = tempStore(); defer { cleanup() }
        for id in ["a", "b", "c", "d"] { try store.append(packet(id)) }
        #expect(try store.loadRecent(limit: 2).map(\.id) == ["d", "c"])
        #expect(try store.loadRecent(limit: 0).isEmpty)
    }

    @Test("compact bounds the log to the last N entries")
    func compact() throws {
        let (store, cleanup) = tempStore(); defer { cleanup() }
        for id in ["a", "b", "c", "d", "e"] { try store.append(packet(id)) }
        try store.compact(maxEntries: 2)
        #expect(try store.loadRecent(limit: 10).map(\.id) == ["e", "d"])
    }

    @Test("a corrupt line is skipped, never crashes the load")
    func corruptionTolerant() throws {
        let (store, cleanup) = tempStore(); defer { cleanup() }
        try store.append(packet("good1"))
        let handle = try FileHandle(forWritingTo: store.fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{not valid json\n".utf8))
        try handle.close()
        try store.append(packet("good2"))
        #expect(try store.loadRecent(limit: 10).map(\.id) == ["good2", "good1"])
    }
}
