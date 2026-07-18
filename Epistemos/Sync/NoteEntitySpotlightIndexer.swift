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

nonisolated enum NoteEntitySpotlightDiagnostics {
    static let maxLogMessageCharacters = 240
    private static let maxDomainCharacters = 80

    static func logMessage(for error: Error, fallback: String) -> String {
        let nsError = error as NSError
        return logMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func logMessage(_ message: String, fallback: String = "Spotlight entity indexing failed") -> String {
        let bounded = String(message.prefix(maxLogMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxLogMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxLogMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= maxDomainCharacters else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: maxDomainCharacters)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}

public enum NoteEntitySpotlightIndexer {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "NoteEntitySpotlightIndexer"
    )

    /// Bulk-index a batch of NoteEntities. Called from VaultIndexActor's
    /// Spotlight reindex loop alongside the legacy CSSearchableItem
    /// indexing pass. Idempotent — re-donating the same entity by id
    /// updates the existing index row.
    @discardableResult
    static func indexBulk(_ entities: [NoteEntity]) async -> Bool {
        guard !entities.isEmpty else { return true }
        do {
            try await CSSearchableIndex.default().indexAppEntities(entities)
            log.info("indexAppEntities donated \(entities.count, privacy: .public) note entities")
            return true
        } catch {
            let message = NoteEntitySpotlightDiagnostics.logMessage(
                for: error,
                fallback: "indexAppEntities donation failed"
            )
            log.error(
                "\(message, privacy: .public)"
            )
            return false
        }
    }

    /// Single-note donation — call after a user-driven mutation so
    /// the Spotlight index stays current with the in-app state. Use
    /// from NotesSidebar create/save call sites + VaultIndexActor's
    /// per-page persist path.
    static func donate(_ entity: NoteEntity) async {
        _ = await indexBulk([entity])
    }

    /// Remove a NoteEntity from the Spotlight index. Call when a
    /// note is deleted so Spotlight stops surfacing stale matches.
    static func unindex(noteIds: [String]) async {
        guard !noteIds.isEmpty else { return }
        do {
            try await CSSearchableIndex.default().deleteAppEntities(identifiedBy: noteIds, ofType: NoteEntity.self)
            log.info("deleteAppEntities removed \(noteIds.count, privacy: .public) typed note ids")
        } catch {
            let message = NoteEntitySpotlightDiagnostics.logMessage(
                for: error,
                fallback: "deleteAppEntities failed"
            )
            log.error(
                "\(message, privacy: .public)"
            )
        }
    }

    /// Remove all donated NoteEntity rows while preserving the separate legacy
    /// Spotlight domain owned by SpotlightIndexer.
    static func removeAll() async {
        do {
            try await CSSearchableIndex.default().deleteAppEntities(ofType: NoteEntity.self)
            log.info("deleteAppEntities removed all typed note entities")
        } catch {
            let message = NoteEntitySpotlightDiagnostics.logMessage(
                for: error,
                fallback: "deleteAppEntities type-wide removal failed"
            )
            log.error(
                "\(message, privacy: .public)"
            )
        }
    }
}
