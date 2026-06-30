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

    @Test("store rejects symlinked persistence logs")
    func rejectsSymlinkedPersistenceLog() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apstore-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let outside = root.appendingPathComponent("outside.jsonl")
        let symlink = root.appendingPathComponent("answer_packets.jsonl")
        try Data("outside original\n".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)
        let store = AnswerPacketStore(fileURL: symlink)

        do {
            try store.append(packet("blocked"))
            Issue.record("Expected symlinked AnswerPacket log append to be rejected")
        } catch {}
        #expect(try String(contentsOf: outside, encoding: .utf8) == "outside original\n")

        do {
            _ = try store.loadRecent(limit: 10)
            Issue.record("Expected symlinked AnswerPacket log load to be rejected")
        } catch {}
    }

    @Test("store rejects non-regular persistence logs")
    func rejectsNonRegularPersistenceLog() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apstore-nonregular-\(UUID().uuidString)", isDirectory: true)
        let directoryLog = root.appendingPathComponent("answer_packets.jsonl", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryLog, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AnswerPacketStore(fileURL: directoryLog)

        do {
            _ = try store.loadRecent(limit: 10)
            Issue.record("Expected non-regular AnswerPacket log load to be rejected")
        } catch let error as NSError {
            #expect(error.domain == "AnswerPacketStore")
            #expect(error.localizedDescription.contains("not a regular file"))
        }

        do {
            try store.append(packet("blocked"))
            Issue.record("Expected non-regular AnswerPacket log append to be rejected")
        } catch let error as NSError {
            #expect(error.domain == "AnswerPacketStore")
            #expect(error.localizedDescription.contains("not a regular file")
                || error.localizedDescription.contains("could not open answer packet log"))
        }
    }

    @Test("loadRecent rejects oversized logs before decoding")
    func loadRecentRejectsOversizedLogsBeforeDecoding() throws {
        let (store, cleanup) = tempStore(); defer { cleanup() }
        try Data(#"{"id":"too-big"}"#.utf8).write(to: store.fileURL)
        let handle = try FileHandle(forWritingTo: store.fileURL)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(AnswerPacketStore.maxLogBytes + 1))

        #expect(try store.loadRecent(limit: 10).isEmpty)
        do {
            try store.append(packet("blocked"))
            Issue.record("Expected oversized AnswerPacket log append to be rejected")
        } catch {}
    }

    // The emitter's persist seam (nonisolated static → tested WITHOUT the shared singleton).
    @Test("AnswerPacketEmitter.persist writes through to the store; nil store is a no-op")
    func emitterPersistHelper() throws {
        let (store, cleanup) = tempStore(); defer { cleanup() }
        AnswerPacketEmitter.persist(packet("p1"), to: store, totalEmitted: 1, compactEvery: 200, maxEntries: 500)
        AnswerPacketEmitter.persist(packet("p2"), to: store, totalEmitted: 2, compactEvery: 200, maxEntries: 500)
        #expect(try store.loadRecent(limit: 10).map(\.id) == ["p2", "p1"])
        // nil store → no-op, never crashes (best-effort durability).
        AnswerPacketEmitter.persist(packet("p3"), to: nil, totalEmitted: 3, compactEvery: 200, maxEntries: 500)
        #expect(try store.loadRecent(limit: 10).count == 2)
    }

    @Test("AnswerPacketEmitter.persist compacts on the interval boundary")
    func emitterPersistCompacts() throws {
        let (store, cleanup) = tempStore(); defer { cleanup() }
        for i in 1...5 {
            AnswerPacketEmitter.persist(packet("p\(i)"), to: store, totalEmitted: i, compactEvery: 100, maxEntries: 500)
        }
        // totalEmitted 6 with compactEvery 6 → 6 % 6 == 0 → compact to the last 2 after appending p6.
        AnswerPacketEmitter.persist(packet("p6"), to: store, totalEmitted: 6, compactEvery: 6, maxEntries: 2)
        #expect(try store.loadRecent(limit: 10).map(\.id) == ["p6", "p5"])
    }

    // The durable read accessor delegates to the (behavior-tested) store.loadRecent, kept separate
    // from the in-session ring; and the health row now HONESTLY reflects that persistence is wired.
    @Test("persistedRecent is the durable read accessor + the health row status is honest")
    func persistedRecentAndHonestStatus() throws {
        let emitter = try loadMirroredSourceTextFile("Epistemos/Engine/AnswerPacketEmitter.swift")
        #expect(emitter.contains("func persistedRecent(limit: Int)"))
        #expect(emitter.contains("store.loadRecent(limit: limit)"))
        #expect(emitter.contains("guard let store else { return [] }"))
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AnswerPacketHealthRow.swift")
        #expect(row.contains("durable JSONL persistence log"))
        #expect(!row.contains("session ring only"))   // the stale "not persisted" claim is gone
        let store = try loadMirroredSourceTextFile("Epistemos/Models/AnswerPacketStore.swift")
        #expect(store.contains("maxLogBytes"))
        #expect(store.contains("O_NOFOLLOW"))
        #expect(store.contains("O_RDONLY | O_NOFOLLOW"))
        #expect(store.contains("readStoreFileText"))
        #expect(store.contains("destinationOfSymbolicLink"))
        #expect(store.contains("fstat(fd"))
    }

    // SUBSTRATE Phase 2 — LOAD-ON-LAUNCH RING RESTORE (the "production wiring later" slice): on relaunch
    // the in-memory ring started empty even though emit() had persisted the packets, so per-answer
    // provenance was on disk but invisible. restoreFromPersistence seeds the ring from the durable log.
    @Test("restoreFromPersistence seeds the ring oldest→newest, only when the ring is empty")
    func restoreFromPersistenceSeedsRing() async throws {
        let (store, cleanup) = tempStore()
        defer { cleanup() }
        // Persist three packets in emit order p1 → p2 → p3 (append is chronological).
        try store.append(packet("p1"))
        try store.append(packet("p2"))
        try store.append(packet("p3"))

        let emitter = AnswerPacketEmitter.makeForTesting()
        await emitter.configurePersistence(store)

        let restored = await emitter.restoreFromPersistence()
        #expect(restored == 3)
        // The ring is oldest→newest (loadRecent is most-recent-first; restore reverses it).
        let ids = await emitter.recentPackets().map(\.id)
        #expect(ids == ["p1", "p2", "p3"])

        // Idempotent / no-clobber: a second restore is a no-op because the ring is non-empty.
        #expect(await emitter.restoreFromPersistence() == 0)
        #expect(await emitter.recentPackets().map(\.id) == ["p1", "p2", "p3"])
    }

    @Test("restoreFromPersistence is a no-op with persistence disabled")
    func restoreFromPersistenceNoOpWhenDisabled() async throws {
        let emitter = AnswerPacketEmitter.makeForTesting()
        // No store configured → nothing to restore.
        #expect(await emitter.restoreFromPersistence() == 0)
        #expect(await emitter.recentPackets().isEmpty)
    }
}
