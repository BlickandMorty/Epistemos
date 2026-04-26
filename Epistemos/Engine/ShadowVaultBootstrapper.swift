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
// Walks the vault for two known content kinds today:
//   <vault>/notes/**/*.md     → ShadowDomain.note
//   <vault>/chats/**/*.json   → ShadowDomain.chat
//
// (Future expansion: other CodeArtifactKind / ArtifactKind sources;
// the W7.14 graph projector + W7.15 thought bridge already write
// metadata that hints at additional roots.)
//
// ## Throughput
//
// Per-batch enqueue against ShadowIndexingService — the existing
// debounce + coalescer absorbs the burst without thrashing the
// embedder. Batch size 64 matches usearch's typical reserve growth
// step + tantivy's writer-heap-friendly chunk cadence.
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
    case chats  // .json files under <vault>/chats/
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

    /// Pluggable file walker so tests can hand a fixture directory
    /// without writing to the user's vault.
    private let vaultRoot: URL
    private let indexer: ShadowIndexingService
    /// Batch size — 64 matches usearch's reserve growth step.
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
        await crawl(domain: .notes)
        await crawl(domain: .chats)
        progressContinuation.finish()
    }

    private func crawl(domain: ShadowVaultDomain) async {
        let files = discover(domain: domain)
        // Pre-emit a "scanning complete, total = N" tick so the chip
        // can switch from spinner → progress bar.
        progressContinuation.yield(.init(
            domain: domain,
            enqueued: 0,
            total: files.count,
            isComplete: files.isEmpty
        ))
        if files.isEmpty { return }

        var enqueued = 0
        for batch in files.chunked(into: batchSize) {
            for url in batch {
                guard let dto = await loadDocument(url: url, domain: domain) else { continue }
                await indexer.enqueueInsert(dto)
                enqueued += 1
            }
            progressContinuation.yield(.init(
                domain: domain,
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

    /// Enumerate all files matching the domain's contract under the
    /// vault root. Returns the absolute URLs in stable lexicographic
    /// order so progress reporting is reproducible across runs.
    nonisolated private func discover(domain: ShadowVaultDomain) -> [URL] {
        let (subdirectory, fileExtension) = domainContract(domain)
        let root = vaultRoot.appendingPathComponent(subdirectory, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var found: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == fileExtension else { continue }
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?
                .isRegularFile ?? false
            guard isFile else { continue }
            found.append(url)
        }
        return found.sorted { $0.path < $1.path }
    }

    /// Map a domain to (subdirectory, file-extension).
    nonisolated private func domainContract(_ domain: ShadowVaultDomain) -> (String, String) {
        switch domain {
        case .notes: return ("notes", "md")
        case .chats: return ("chats", "json")
        }
    }

    // MARK: - Loaders

    /// Read + normalise a single file into a ShadowDocumentDTO. Returns
    /// nil on read / parse failure (logs but doesn't abort the crawl).
    nonisolated private func loadDocument(
        url: URL,
        domain: ShadowVaultDomain
    ) async -> ShadowDocumentDTO? {
        do {
            switch domain {
            case .notes:
                let body = try String(contentsOf: url, encoding: .utf8)
                let title = url.deletingPathExtension().lastPathComponent
                let docID = vaultRelativePath(url) ?? url.path
                return ShadowDocumentDTO(
                    docId: docID,
                    title: title,
                    body: body,
                    domain: .notes
                )
            case .chats:
                let data = try Data(contentsOf: url)
                let chat = try JSONDecoder().decode(ShadowVaultChatPayload.self, from: data)
                let docID = vaultRelativePath(url) ?? url.path
                return ShadowDocumentDTO(
                    docId: docID,
                    title: chat.title ?? url.deletingPathExtension().lastPathComponent,
                    body: chat.flattened(),
                    domain: .chats
                )
            }
        } catch {
            Self.log.warning(
                "ShadowVaultBootstrapper: failed to load \(url.path, privacy: .public) — \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    nonisolated private func vaultRelativePath(_ url: URL) -> String? {
        let absolute = url.standardizedFileURL.path
        let root = vaultRoot.standardizedFileURL.path
        guard absolute.hasPrefix(root) else { return nil }
        let relative = absolute.dropFirst(root.count)
        return relative.hasPrefix("/") ? String(relative.dropFirst()) : String(relative)
    }
}

// MARK: - Chat payload normalisation
//
// Minimal local decoder for chat JSON files — the canonical SDChat /
// SDMessage SwiftData types live elsewhere; we only need title +
// flattened text for the Halo encoder. Loose schema (every field
// optional) so older chat-export shapes round-trip.

nonisolated private struct ShadowVaultChatPayload: Decodable {
    let title: String?
    let messages: [ShadowVaultChatMessage]?

    func flattened() -> String {
        guard let messages else { return "" }
        return messages
            .compactMap { msg -> String? in
                guard let text = msg.content, !text.isEmpty else { return nil }
                let role = msg.role ?? "?"
                return "[\(role)] \(text)"
            }
            .joined(separator: "\n\n")
    }
}

nonisolated private struct ShadowVaultChatMessage: Decodable {
    let role: String?
    let content: String?
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
