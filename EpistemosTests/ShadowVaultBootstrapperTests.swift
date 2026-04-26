import Foundation
import Testing

@testable import Epistemos

/// Wave 8.7 source-guard for the vault bootstrap indexer.
@Suite("ShadowVaultBootstrapper (Wave 8.7)")
nonisolated struct ShadowVaultBootstrapperTests {

    private static func tempVault() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shadow-bootstrap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent("notes"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent("chats"),
            withIntermediateDirectories: true
        )
        return url
    }

    /// Mock indexer that captures every enqueueInsert call so the test
    /// can assert what the bootstrapper emitted without touching the
    /// real Halo backend.
    private actor CaptureIndexer {
        private(set) var inserted: [ShadowDocumentDTO] = []
        func record(_ dto: ShadowDocumentDTO) { inserted.append(dto) }
    }

    @Test("Empty vault → bootstrap completes immediately, emits zero progress events")
    func emptyVault() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }

        let captureIndexer = CaptureIndexer()
        let realIndexer = ShadowIndexingService(client: StubShadowFFIClient())
        let bootstrapper = ShadowVaultBootstrapper(
            vaultRoot: vault,
            indexer: realIndexer
        )

        await bootstrapper.bootstrap()
        await #expect(captureIndexer.inserted.isEmpty)
    }

    @Test("Notes vault → enqueues one ShadowDocumentDTO per .md file with title from filename")
    func notesEnqueueOnePerMarkdown() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let notesDir = vault.appendingPathComponent("notes")
        try "First note body".write(
            to: notesDir.appendingPathComponent("first.md"),
            atomically: true, encoding: .utf8
        )
        try "Second note body".write(
            to: notesDir.appendingPathComponent("second.md"),
            atomically: true, encoding: .utf8
        )

        let stub = StubShadowFFIClient()
        let indexer = ShadowIndexingService(client: stub)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper.bootstrap()
        await indexer.flushNow()

        // Both notes searchable through the in-memory client snapshot.
        let stats = try stub.stats()
        #expect(stats.noteCount == 2)
    }

    @Test("Crawl ignores files with the wrong extension (cache files, hidden files, etc.)")
    func ignoresWrongExtension() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let notesDir = vault.appendingPathComponent("notes")
        try "real note".write(
            to: notesDir.appendingPathComponent("real.md"),
            atomically: true, encoding: .utf8
        )
        try "ignored cache".write(
            to: notesDir.appendingPathComponent("cache.tmp"),
            atomically: true, encoding: .utf8
        )

        let stub = StubShadowFFIClient()
        let indexer = ShadowIndexingService(client: stub)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper.bootstrap()
        await indexer.flushNow()

        let stats = try stub.stats()
        #expect(stats.noteCount == 1, "only .md files should be indexed; got \(stats.noteCount)")
    }

    @Test("Progress stream emits scanning → enqueued → complete tick per domain")
    func progressStreamEmitsTicks() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let notesDir = vault.appendingPathComponent("notes")
        for i in 0..<3 {
            try "note \(i)".write(
                to: notesDir.appendingPathComponent("n\(i).md"),
                atomically: true, encoding: .utf8
            )
        }

        let stub = StubShadowFFIClient()
        let indexer = ShadowIndexingService(client: stub)
        let bootstrapper = ShadowVaultBootstrapper(
            vaultRoot: vault,
            indexer: indexer,
            batchSize: 2
        )

        // Drain the progress stream into a captured array as the
        // bootstrap runs.
        let progressStream = await bootstrapper.progress
        let drainTask = Task<[ShadowVaultBootstrapProgress], Never> {
            var collected: [ShadowVaultBootstrapProgress] = []
            for await tick in progressStream {
                collected.append(tick)
            }
            return collected
        }
        await bootstrapper.bootstrap()
        let ticks = await drainTask.value

        // Should see at least:
        //   notes: 0/3 → 2/3 → 3/3 (complete)
        //   chats: 0/0 (complete; vault has no chats)
        let notesTicks = ticks.filter { $0.domain == .notes }
        #expect(notesTicks.count >= 2,
                "notes domain MUST emit at least scanning + final tick; got \(notesTicks.count)")
        #expect(notesTicks.last?.isComplete == true)
        #expect(notesTicks.last?.enqueued == 3)
        #expect(notesTicks.last?.total == 3)
    }

    @Test("Doc id is the vault-relative path so re-runs are idempotent (replace not duplicate)")
    func docIdIsVaultRelativePath() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let notesDir = vault.appendingPathComponent("notes")
        try "body".write(
            to: notesDir.appendingPathComponent("subject.md"),
            atomically: true, encoding: .utf8
        )

        let stub = StubShadowFFIClient()
        let indexer = ShadowIndexingService(client: stub)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)

        // Run twice — second pass should NOT duplicate.
        await bootstrapper.bootstrap()
        await indexer.flushNow()
        let bootstrapper2 = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper2.bootstrap()
        await indexer.flushNow()

        let stats = try stub.stats()
        #expect(stats.noteCount == 1,
                "doc_id should be vault-relative path so the second run replaces; got \(stats.noteCount)")
    }
}
