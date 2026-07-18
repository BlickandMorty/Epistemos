import Foundation
import OSLog

// MARK: - ShadowVaultBootstrapper
//
// Wave 8.7 — first-launch + idle-time vault crawl that populates the
// Halo Shadow index with the user's actual content. Without this,
// every first-launch user opens Halo to an empty panel and the V1
// "type a sentence, see a related thought appear" demo fails on day
// one.
//
// Per the audit agent's 2026-04-26 verdict: this is the #1 V1 must-
// ship to close the W8 chain. RealBackend (W8.4.e) + persistence
// (W8.4.f) + singleton flip (W8.4.g) are all green; this commit is
// the missing wiring that gets real user notes into the index.
//
// ## Discovery
//
// Walks only deterministic note Markdown:
//   <vault>/notes/**/*.md     → ShadowDomain.note
//
// ## Throughput
//
// Per-batch enqueue against ShadowIndexingService — the existing
// debounce + coalescer absorbs the burst without blocking the
// lexical index. Batch size 64 keeps the writer cadence bounded.
//
// ## Progress reporting
//
// `progress: AsyncStream<BootstrapProgress>` lets a SwiftUI surface
// (the EpdocEditorChromeController right-cluster, or a dedicated
// onboarding view) render an "Indexing N/M docs…" chip without
// blocking the bootstrapper's actor.
//
// ## Idempotence
//
// Re-running on a populated vault is safe: ShadowIndexingService's
// coalescer + the LexicalIndex's delete-then-add insert semantics
// turn re-inserts into in-place updates. The first-launch crawl is
// the canonical entry; subsequent file-system changes are the
// follow-up watcher's job (W8.7.b — defers FSEvents wiring).

nonisolated public enum ShadowVaultDomain: Sendable, Hashable {
    case notes  // .md files under <vault>/notes/
    /// Retained only so persisted bootstrap-progress payloads remain
    /// decodable. Free bootstrap never discovers or emits this case.
    case chats
}

nonisolated public struct ShadowVaultBootstrapProgress: Sendable, Hashable {
    public let domain: ShadowVaultDomain
    /// Docs successfully enqueued so far in this run.
    public let enqueued: Int
    /// Total docs we'll enqueue across this domain. -1 while we're
    /// still discovering files (the SwiftUI chip shows a
    /// "scanning…" state until the count becomes ≥0).
    public let total: Int
    /// Set when we hit the final doc of a domain. The SwiftUI chip
    /// flips to ✓ then auto-dismisses.
    public let isComplete: Bool

    public init(domain: ShadowVaultDomain, enqueued: Int, total: Int, isComplete: Bool) {
        self.domain = domain
        self.enqueued = enqueued
        self.total = total
        self.isComplete = isComplete
    }
}

public actor ShadowVaultBootstrapper {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "ShadowVaultBootstrapper"
    )
    private static let maxMarkdownBodyBytes = 200_000

    /// Pluggable file walker so tests can hand a fixture directory
    /// without writing to the user's vault.
    private let vaultRoot: URL
    private let indexer: ShadowIndexingService
    /// Batch size bounds one cooperative lexical indexing burst.
    private let batchSize: Int

    public let progress: AsyncStream<ShadowVaultBootstrapProgress>
    private let progressContinuation: AsyncStream<ShadowVaultBootstrapProgress>.Continuation

    public init(
        vaultRoot: URL,
        indexer: ShadowIndexingService,
        batchSize: Int = 64
    ) {
        self.vaultRoot = vaultRoot
        self.indexer = indexer
        self.batchSize = batchSize
        var continuation: AsyncStream<ShadowVaultBootstrapProgress>.Continuation!
        self.progress = AsyncStream(bufferingPolicy: .bufferingNewest(64)) { c in
            continuation = c
        }
        self.progressContinuation = continuation
    }

    // MARK: - Crawl

    /// Walk the vault + enqueue every discovered doc into the indexer.
    /// Idempotent — re-running on a populated vault updates in place
    /// thanks to the indexer's delete-then-add semantics.
    public func bootstrap() async {
        await crawlNotes()
        progressContinuation.finish()
    }

    nonisolated public static func vaultRelativeDocId(for url: URL, vaultRoot: URL) -> String? {
        let absolute = url.standardizedFileURL.path
        let root = vaultRoot.standardizedFileURL.path
        guard absolute.hasPrefix(root + "/") else { return nil }

        let relative = absolute.dropFirst(root.count + 1)
        guard !relative.isEmpty else { return nil }
        return String(relative)
    }

    private func crawlNotes() async {
        let files = discoverNotes()
        // Pre-emit a "scanning complete, total = N" tick so the chip
        // can switch from spinner → progress bar.
        progressContinuation.yield(.init(
            domain: .notes,
            enqueued: 0,
            total: files.count,
            isComplete: files.isEmpty
        ))
        if files.isEmpty { return }

        var enqueued = 0
        for batch in files.chunked(into: batchSize) {
            for url in batch {
                guard let dto = await loadNoteDocument(url: url) else { continue }
                await indexer.enqueueInsert(dto)
                enqueued += 1
            }
            progressContinuation.yield(.init(
                domain: .notes,
                enqueued: enqueued,
                total: files.count,
                isComplete: enqueued == files.count
            ))
            // Yield to the cooperative executor so the indexer's
            // own debounce + the SwiftUI redraw get a chance.
            await Task.yield()
        }
    }

    // MARK: - Discovery

    /// Enumerate note Markdown only. The chats directory is deliberately
    /// not addressed or enumerated in the Free bootstrap path.
    nonisolated private func discoverNotes() -> [URL] {
        let root = vaultRoot.appendingPathComponent("notes", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var found: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "md" else { continue }
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?
                .isRegularFile ?? false
            guard isFile else { continue }
            found.append(url)
        }
        return found.sorted { $0.path < $1.path }
    }

    // MARK: - Loaders

    /// Read a bounded Markdown prefix into a notes-only document. Returns nil
    /// on read failure without aborting the rest of the crawl.
    nonisolated private func loadNoteDocument(url: URL) async -> ShadowDocumentDTO? {
        // Sidecar metadata (commit 389ba93f3 + e1f8a1862): tag every
        // emitted doc with the vault directory's name as
        // `originVaultKey` so a note can be associated with its vault
        // without recording an absolute path.
        //
        // Absolute path would be over-fitted (user moving their vault
        // breaks the key); the folder name stays stable across
        // location moves. Pre-2026-05-15 indexed docs continue to
        // round-trip with nil via the optional default.
        let vaultKey = vaultRoot.lastPathComponent.isEmpty
            ? nil
            : vaultRoot.lastPathComponent
        do {
            let body = try Self.loadMarkdownBodyPrefix(from: url)
            let title = url.deletingPathExtension().lastPathComponent
            let docID = vaultRelativePath(url) ?? url.path
            return ShadowDocumentDTO(
                docId: docID,
                title: title,
                body: body,
                domain: .notes,
                originVaultKey: vaultKey
            )
        } catch {
            Self.log.warning(
                "ShadowVaultBootstrapper: failed to load \(url.path, privacy: .public) — \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    nonisolated private static func loadMarkdownBodyPrefix(from url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maxMarkdownBodyBytes) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    nonisolated private func vaultRelativePath(_ url: URL) -> String? {
        Self.vaultRelativeDocId(for: url, vaultRoot: vaultRoot)
    }
}

// MARK: - Array.chunked

nonisolated private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
