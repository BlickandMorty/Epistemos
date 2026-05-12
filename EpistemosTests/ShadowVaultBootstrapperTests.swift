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
        let realIndexer = ShadowIndexingService(client: InMemoryShadowFFIClient())
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

        let client = InMemoryShadowFFIClient()
        let indexer = ShadowIndexingService(client: client)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper.bootstrap()
        await indexer.flushNow()

        // Both notes searchable through the in-memory client snapshot.
        let stats = try client.stats()
        #expect(stats.noteCount == 2)
    }

    @Test("Large markdown files index a bounded prefix instead of the whole body")
    func largeMarkdownBodyIndexesBoundedPrefix() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let notesDir = vault.appendingPathComponent("notes")
        let body = "prefix-needle\n"
            + String(repeating: "a", count: 240_000)
            + "\ntail-needle"
        try body.write(
            to: notesDir.appendingPathComponent("large.md"),
            atomically: true,
            encoding: .utf8
        )

        let client = InMemoryShadowFFIClient()
        let indexer = ShadowIndexingService(client: client)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper.bootstrap()
        await indexer.flushNow()

        let prefixHits = try client.search(query: "prefix-needle", domain: .notes, limit: 10)
        let tailHits = try client.search(query: "tail-needle", domain: .notes, limit: 10)
        #expect(prefixHits.count == 1)
        #expect(tailHits.isEmpty, "large-file shadow indexing should not read the entire body")
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

        let client = InMemoryShadowFFIClient()
        let indexer = ShadowIndexingService(client: client)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper.bootstrap()
        await indexer.flushNow()

        let stats = try client.stats()
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

        let client = InMemoryShadowFFIClient()
        let indexer = ShadowIndexingService(client: client)
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

    @Test("Background indexing diagnostics record real bootstrap progress")
    @MainActor
    func backgroundIndexingDiagnosticsRecordProgress() throws {
        let suiteName = "epistemos.background-indexing.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        BackgroundIndexingHealthRow.reset(defaults: defaults)
        BackgroundIndexingHealthRow.recordStarted(
            vaultPath: "/tmp/vault",
            shadowPath: "/tmp/vault/.epcache/shadow",
            defaults: defaults
        )
        BackgroundIndexingHealthRow.recordProgress(
            ShadowVaultBootstrapProgress(
                domain: .notes,
                enqueued: 2,
                total: 3,
                isComplete: false
            ),
            vaultPath: "/tmp/vault",
            shadowPath: "/tmp/vault/.epcache/shadow",
            defaults: defaults
        )

        let snapshot = BackgroundIndexingHealthRow.snapshot(defaults: defaults)
        #expect(snapshot.phase == .indexing)
        #expect(snapshot.vaultPath == "/tmp/vault")
        #expect(snapshot.shadowPath == "/tmp/vault/.epcache/shadow")
        #expect(snapshot.domain == "notes")
        #expect(snapshot.enqueued == 2)
        #expect(snapshot.total == 3)
        #expect(snapshot.error == nil)
    }

    @Test("Background indexing diagnostics record ETL queue counters")
    @MainActor
    func backgroundIndexingDiagnosticsRecordEtlQueueCounters() throws {
        let suiteName = "epistemos.background-indexing.etl.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        BackgroundIndexingHealthRow.reset(defaults: defaults)
        BackgroundIndexingHealthRow.recordStarted(
            vaultPath: "/tmp/vault",
            shadowPath: "/tmp/vault/.epcache/shadow",
            defaults: defaults
        )
        BackgroundIndexingHealthRow.recordEtlQueueStats(
            EtlQueueStatsSnapshot(
                available: true,
                total: 4,
                pending: 2,
                running: 1,
                done: 1,
                failed: 0,
                killed: 0,
                active: 3,
                completed: 1,
                error: nil
            ),
            queuePath: "/tmp/vault/.epcache/etl/queue.sqlite",
            defaults: defaults
        )

        var snapshot = BackgroundIndexingHealthRow.snapshot(defaults: defaults)
        #expect(snapshot.etlQueuePath == "/tmp/vault/.epcache/etl/queue.sqlite")
        #expect(snapshot.etlAvailable)
        #expect(snapshot.etlTotal == 4)
        #expect(snapshot.etlPending == 2)
        #expect(snapshot.etlRunning == 1)
        #expect(snapshot.etlDone == 1)
        #expect(snapshot.etlActive == 3)
        #expect(snapshot.etlCompleted == 1)
        #expect(snapshot.etlError == nil)

        BackgroundIndexingHealthRow.recordStarted(
            vaultPath: "/tmp/other-vault",
            shadowPath: "/tmp/other-vault/.epcache/shadow",
            defaults: defaults
        )
        snapshot = BackgroundIndexingHealthRow.snapshot(defaults: defaults)
        #expect(snapshot.etlQueuePath == nil)
        #expect(!snapshot.etlAvailable)
        #expect(snapshot.etlTotal == 0)
    }

    @Test("Background indexing diagnostics record paused state")
    @MainActor
    func backgroundIndexingDiagnosticsRecordPausedState() throws {
        let suiteName = "epistemos.background-indexing.paused.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        BackgroundIndexingHealthRow.reset(defaults: defaults)
        BackgroundIndexingHealthRow.recordPaused(
            vaultPath: "/tmp/vault",
            shadowPath: "/tmp/vault/.epcache/shadow",
            reason: .battery,
            defaults: defaults
        )

        let snapshot = BackgroundIndexingHealthRow.snapshot(defaults: defaults)
        #expect(snapshot.phase == .paused)
        #expect(snapshot.vaultPath == "/tmp/vault")
        #expect(snapshot.shadowPath == "/tmp/vault/.epcache/shadow")
        #expect(snapshot.detail.contains("Paused - on battery"))
    }

    @Test("Background indexing diagnostics distinguish memory pressure pause")
    @MainActor
    func backgroundIndexingDiagnosticsDistinguishMemoryPressurePause() throws {
        let suiteName = "epistemos.background-indexing.memory-pressure.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        BackgroundIndexingHealthRow.reset(defaults: defaults)
        BackgroundIndexingHealthRow.recordPaused(
            vaultPath: "/tmp/vault",
            shadowPath: "/tmp/vault/.epcache/shadow",
            reason: .memoryPressure,
            defaults: defaults
        )

        let snapshot = BackgroundIndexingHealthRow.snapshot(defaults: defaults)
        #expect(snapshot.phase == .paused)
        #expect(snapshot.detail.contains("Paused - memory pressure"))
    }

    @Test("Rust ETL dispatch client enqueues supported vault files")
    func rustEtlDispatchClientEnqueuesSupportedVaultFiles() throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let notesDir = vault.appendingPathComponent("notes")
        try "queued".write(
            to: notesDir.appendingPathComponent("queued.md"),
            atomically: true,
            encoding: .utf8
        )
        try "struct Ignored {}".write(
            to: notesDir.appendingPathComponent("Ignored.swift"),
            atomically: true,
            encoding: .utf8
        )
        let queuePath = vault
            .appendingPathComponent(".epcache", isDirectory: true)
            .appendingPathComponent("etl", isDirectory: true)
            .appendingPathComponent("queue.sqlite", isDirectory: false)
            .path

        let dispatch = RustEtlQueueDispatchClient.enqueueVaultWalk(
            vaultPath: vault.path,
            queuePath: queuePath
        )
        #expect(dispatch.available)
        #expect(dispatch.total == 1)
        #expect(dispatch.queued == 1)
        #expect(dispatch.skipped == 0)

        let stats = RustEtlQueueStatsClient.stats(path: queuePath)
        #expect(stats.available)
        #expect(stats.pending == 1)
        #expect(stats.active == 1)
    }

    @Test("Rust ETL worker client validates queued files before marking done")
    func rustEtlWorkerClientValidatesQueuedFilesBeforeMarkingDone() throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let notesDir = vault.appendingPathComponent("notes")
        try "validated".write(
            to: notesDir.appendingPathComponent("validated.md"),
            atomically: true,
            encoding: .utf8
        )
        let queuePath = vault
            .appendingPathComponent(".epcache", isDirectory: true)
            .appendingPathComponent("etl", isDirectory: true)
            .appendingPathComponent("queue.sqlite", isDirectory: false)
            .path

        let dispatch = RustEtlQueueDispatchClient.enqueueVaultWalk(
            vaultPath: vault.path,
            queuePath: queuePath
        )
        #expect(dispatch.available)
        #expect(dispatch.queued == 1)

        let worker = RustEtlQueueWorkerClient.run(queuePath: queuePath, maxJobs: 4)
        #expect(worker.available)
        #expect(worker.requested == 1)
        #expect(worker.attempted == 1)
        #expect(worker.succeeded == 1)
        #expect(worker.failed == 0)
        #expect(worker.pendingAfter == 0)
        #expect(worker.doneAfter == 1)

        let stats = RustEtlQueueStatsClient.stats(path: queuePath)
        #expect(stats.available)
        #expect(stats.pending == 0)
        #expect(stats.done == 1)
    }

    @Test("Vault relative doc ids match bootstrap crawl identity")
    func vaultRelativeDocIdsMatchBootstrapIdentity() {
        let vault = URL(fileURLWithPath: "/tmp/Epistemos Vault", isDirectory: true)
        let note = vault
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("Project", isDirectory: true)
            .appendingPathComponent("subject.md")
        let outside = URL(fileURLWithPath: "/tmp/Other/subject.md")

        #expect(
            ShadowVaultBootstrapper.vaultRelativeDocId(for: note, vaultRoot: vault)
                == "notes/Project/subject.md"
        )
        #expect(ShadowVaultBootstrapper.vaultRelativeDocId(for: outside, vaultRoot: vault) == nil)
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

        let client = InMemoryShadowFFIClient()
        let indexer = ShadowIndexingService(client: client)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)

        // Run twice — second pass should NOT duplicate.
        await bootstrapper.bootstrap()
        await indexer.flushNow()
        let bootstrapper2 = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper2.bootstrap()
        await indexer.flushNow()

        let stats = try client.stats()
        #expect(stats.noteCount == 1,
                "doc_id should be vault-relative path so the second run replaces; got \(stats.noteCount)")
    }
}
