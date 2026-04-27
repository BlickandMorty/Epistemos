import AppIntents
import CoreSpotlight
import Foundation
import OSLog

// MARK: - NoteEntitySpotlightIndexer (W14.1 wire-up)
//
// Donates `NoteEntity` instances into Core Spotlight via the new
// macOS 26 `indexAppEntities` API so the W14.1 IndexedEntity
// conformance actually shows up in Spotlight semantic search.
//
// Coexists with the existing legacy `SpotlightIndexer` /
// `CSSearchableIndex.indexSearchableItems` path:
//
//   - Legacy CSSearchableItem path (VaultIndexActor:1918) → indexes
//     plain content. Spotlight finds the title + body via keyword
//     match. NOT eligible for "Find Note" or Apple Intelligence
//     semantic routing.
//
//   - New indexAppEntities path (this module) → indexes the typed
//     NoteEntity. Spotlight surfaces it as a first-class action card
//     ("Open Note", "Preview Note" snippet); macOS 26's Apple
//     Intelligence semantic ranker can route natural-language
//     queries ("find my notes about LLM context windows") to it.
//
// Both paths target the same default Core Spotlight index and the
// system de-dupes by id, so running both is safe + additive.
//
// Compass §"CSSearchableIndex gotcha" honoured: we never construct
// a fresh `CSSearchableItemAttributeSet(itemContentType:)` here —
// the W14.1 NoteEntity+IndexedEntity extension's `attributeSet`
// computed property is what the system actually reads.

public enum NoteEntitySpotlightIndexer {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "NoteEntitySpotlightIndexer"
    )

    /// Bulk-index a batch of NoteEntities. Called from VaultIndexActor's
    /// Spotlight reindex loop alongside the legacy CSSearchableItem
    /// indexing pass. Idempotent — re-donating the same entity by id
    /// updates the existing index row.
    static func indexBulk(_ entities: [NoteEntity]) async {
        guard !entities.isEmpty else { return }
        do {
            try await CSSearchableIndex.default().indexAppEntities(entities)
            log.info("indexAppEntities donated \(entities.count, privacy: .public) note entities")
        } catch {
            log.error(
                "indexAppEntities donation failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Single-note donation — call after a user-driven mutation so
    /// the Spotlight index stays current with the in-app state. Use
    /// from NotesSidebar create/save call sites + VaultIndexActor's
    /// per-page persist path.
    static func donate(_ entity: NoteEntity) async {
        await indexBulk([entity])
    }

    /// Remove a NoteEntity from the Spotlight index. Call when a
    /// note is deleted so Spotlight stops surfacing stale matches.
    static func unindex(noteIds: [String]) async {
        guard !noteIds.isEmpty else { return }
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(
                withIdentifiers: noteIds
            )
            log.info("deleteSearchableItems removed \(noteIds.count, privacy: .public) note ids")
        } catch {
            log.error(
                "deleteSearchableItems failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
