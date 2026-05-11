import CoreSpotlight
import os

// MARK: - Spotlight Indexer
// Indexes note pages into Core Spotlight so users can find notes from macOS Spotlight.
// This is a moat feature — Electron apps (Obsidian, Logseq, Notion) cannot do this.
//
// v3 uses SDPage (SwiftData) instead of NotePage (in-memory arrays).
//
// Usage:
//   SpotlightIndexer.index(page)         — after create / save / rename
//   SpotlightIndexer.deindex(pageId)     — after delete
//   SpotlightIndexer.reindexAll(pages)   — on vault load

@MainActor
enum SpotlightIndexer {

    nonisolated static let domainID = "com.epistemos.notes"

    private struct PageStage: Sendable {
        let pageId: String
        let filePath: String?
        let title: String
        let tagsJoined: String
        let tags: [String]
        let createdAt: Date
        let updatedAt: Date
    }

    private static func stage(_ page: SDPage) -> PageStage {
        PageStage(
            pageId: page.id,
            filePath: page.filePath,
            title: page.title,
            tagsJoined: page.tags.joined(separator: ", "),
            tags: page.tags,
            createdAt: page.createdAt,
            updatedAt: page.updatedAt
        )
    }

    /// Build a CSSearchableItem for a single page. Centralizes attribute construction
    /// so index(), reindexAll(), and VaultIndexActor all produce identical items.
    nonisolated static func makeItem(for page: SDPage, body: String) -> CSSearchableItem {
        makeItem(
            pageId: page.id,
            title: page.title,
            tags: page.tags,
            tagsJoined: page.tags.joined(separator: ", "),
            createdAt: page.createdAt,
            updatedAt: page.updatedAt,
            body: body
        )
    }

    nonisolated private static func makeItem(
        pageId: String,
        title: String,
        tags: [String],
        tagsJoined: String,
        createdAt: Date,
        updatedAt: Date,
        body: String
    ) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = title
        // Spotlight surfaces only ~100-200 chars in its preview UI, so
        // 280 is plenty. Each `CSSearchableItem` body is held in
        // `corespotlightd`'s resident memory until the index is
        // re-flushed; on a 5K-note vault, the 500→280 trim shaves
        // 30-50 MB from the OS-side process.
        attrs.textContent = String(body.prefix(280))
        attrs.contentDescription = tags.isEmpty
            ? title
            : "Tags: \(tagsJoined)"
        attrs.keywords = tags
        attrs.contentModificationDate = updatedAt
        attrs.contentCreationDate = createdAt
        attrs.relatedUniqueIdentifier = pageId

        let item = CSSearchableItem(
            uniqueIdentifier: pageId,
            domainIdentifier: domainID,
            attributeSet: attrs
        )
        item.expirationDate = .distantFuture
        return item
    }

    /// Index a single SDPage in Spotlight.
    ///
    /// Phase R.3 async cascade: captures Sendable primitives and
    /// dispatches the body read through
    /// `SDPage.loadBodyAsyncFromPrimitives`, which preserves the
    /// managed sidecar before using the R.3 gateway fallback.
    /// `SDPage` stays on the main actor — the Task never captures
    /// the model reference.
    static func index(_ page: SDPage) {
        let stage = stage(page)
        Task { @MainActor in
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: stage.pageId,
                filePath: stage.filePath,
                mapped: true
            )
            let item = makeItem(
                pageId: stage.pageId,
                title: stage.title,
                tags: stage.tags,
                tagsJoined: stage.tagsJoined,
                createdAt: stage.createdAt,
                updatedAt: stage.updatedAt,
                body: body
            )
            do {
                try await CSSearchableIndex.default().indexSearchableItems([item])
            } catch {
                Log.notes.error("Spotlight index failed for '\(stage.title, privacy: .public)': \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    /// Remove a note from Spotlight index. Thread-safe (CSSearchableIndex is sendable).
    nonisolated static func deindex(_ pageId: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [pageId]) { error in
            if let error {
                Log.notes.error("Spotlight deindex failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    /// Bulk re-index all notes (e.g. on vault load).
    /// Processes in batches to avoid loading all page bodies into memory at once
    /// (note bodies live in sidecar markdown files, so each read is explicit disk I/O).
    ///
    /// Phase R.3 async cascade: each body read goes through
    /// `loadBodyAsyncFromPrimitives` so the managed sidecar remains
    /// authoritative before the R.3 gateway fallback is used.
    /// The work is dispatched onto the current MainActor Task so the
    /// public call signature stays sync; inside the task we await per
    /// page.
    static func reindexAll(_ pages: [SDPage]) {
        let batchSize = 50
        let total = pages.count

        // Stage Sendable primitives for every page up-front so the
        // async work doesn't need to capture the SDPage reference
        // (SwiftData @Model isn't Sendable).
        let stages: [PageStage] = pages.map(stage)

        // RCA13 P2-013: previously this loop ran inside
        // `Task { @MainActor in ... }`, pinning batch orchestration +
        // CSSearchableItem allocation to the main actor. On a medium
        // vault the awaitable body-load between batches gave the UI
        // breathing room, but on a large vault the per-page allocation
        // + dictionary-population work still serialized on MainActor.
        // PageStage is Sendable, makeItem is nonisolated, and
        // CSSearchableIndex is thread-safe — the whole loop is safe
        // off-main on a background task. Vault-load interaction stays
        // responsive even on 10k+ note vaults.
        Task.detached(priority: .utility) {
            for batchStart in stride(from: 0, to: total, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, total)
                let batch = Array(stages[batchStart..<batchEnd])

                var items: [CSSearchableItem] = []
                items.reserveCapacity(batch.count)
                for stage in batch {
                    let pageBody = await SDPage.loadBodyAsyncFromPrimitives(
                        pageId: stage.pageId,
                        filePath: stage.filePath,
                        mapped: true
                    )
                    let item = makeItem(
                        pageId: stage.pageId,
                        title: stage.title,
                        tags: stage.tags,
                        tagsJoined: stage.tagsJoined,
                        createdAt: stage.createdAt,
                        updatedAt: stage.updatedAt,
                        body: pageBody
                    )
                    items.append(item)
                }

                do {
                    try await CSSearchableIndex.default().indexSearchableItems(items)
                } catch {
                    Log.notes.error("Spotlight batch reindex failed: \(error.localizedDescription, privacy: .private)")
                }
            }

            Log.notes.info("Spotlight indexed \(total, privacy: .public) notes in batches of \(batchSize)")
        }
    }

    /// Remove all Lucid notes from Spotlight.
    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainID]) { error in
            if let error {
                Log.notes.error("Spotlight removeAll failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }
}
