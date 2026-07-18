import Foundation

/// Note backlinks derived from the deterministic lexical Shadow index in
/// addition to mechanical `[[wikilinks]]`.
struct VaultSemanticBacklinks: Sendable {
    private let search: any ShadowSearchServicing

    init(search: any ShadowSearchServicing) {
        self.search = search
    }

    /// Related notes for a note — its (title + body) text is the query, the note itself is
    /// excluded, and the top `limit` lexical hits remain.
    /// Over-fetches by one so removing self still yields up to `limit`.
    func relatedNotes(noteID: String, queryText: String, limit: Int = 10) async -> [ShadowHit] {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        let hits = await search.search(text: trimmed, limit: limit + 1)
        return Array(hits.filter { $0.id != noteID }.prefix(limit))
    }
}
