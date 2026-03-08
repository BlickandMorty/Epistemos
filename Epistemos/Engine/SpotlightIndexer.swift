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

    nonisolated(unsafe) static let domainID = "com.epistemos.notes"

    /// Build a CSSearchableItem for a single page. Centralizes attribute construction
    /// so index(), reindexAll(), and VaultIndexActor all produce identical items.
    nonisolated static func makeItem(for page: SDPage, body: String) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = page.title
        attrs.textContent = String(body.prefix(500))
        attrs.contentDescription = page.tags.isEmpty
            ? page.title
            : "Tags: \(page.tags.joined(separator: ", "))"
        attrs.keywords = page.tags
        attrs.contentModificationDate = page.updatedAt
        attrs.contentCreationDate = page.createdAt
        attrs.relatedUniqueIdentifier = page.id

        let item = CSSearchableItem(
            uniqueIdentifier: page.id,
            domainIdentifier: domainID,
            attributeSet: attrs
        )
        item.expirationDate = .distantFuture
        return item
    }

    /// Index a single SDPage in Spotlight.
    static func index(_ page: SDPage) {
        let title = page.title
        let body = page.loadBody(mapped: true)
        let item = makeItem(for: page, body: body)

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                Log.notes.error("Spotlight index failed for '\(title, privacy: .public)': \(error.localizedDescription, privacy: .private)")
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
    /// (body uses @Attribute(.externalStorage) — each access triggers a lazy disk load).
    static func reindexAll(_ pages: [SDPage]) {
        let batchSize = 50
        let total = pages.count

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, total)
            let batch = pages[batchStart..<batchEnd]

            let items = batch.map { page -> CSSearchableItem in
                let pageBody = page.loadBody(mapped: true)
                return makeItem(for: page, body: pageBody)
            }

            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if let error {
                    Log.notes.error("Spotlight batch reindex failed: \(error.localizedDescription, privacy: .private)")
                }
            }
        }

        Log.notes.info("Spotlight indexed \(total, privacy: .public) notes in batches of \(batchSize)")
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
