import Foundation

/// VAULT-DEEP-INTEGRATION §720 (#3): brain-powered SEMANTIC backlinks — notes semantically RELATED to a
/// given note via the REAL shadow hybrid index (BM25 + HNSW + RRF over the vault), NOT just the mechanical
/// `[[wikilinks]]`. The "LLM wiki" surfaces these as suggested connections layered ATOP the mechanical
/// wikilink graph (omega-mcp `backlinks`/`outlinks`/`dangling_links`).
///
/// HONEST CAPABILITY: this is the brain's own hybrid search (`ShadowSearchServicing`) — not a lexical
/// proxy dressed up as "semantic." Lives Swift-side because that's where the shadow index is wired
/// (`ShadowSearchService` / `RustShadowFFIClient`); omega-mcp has no shadow dependency.
struct VaultSemanticBacklinks: Sendable {
    private let search: any ShadowSearchServicing

    init(search: any ShadowSearchServicing) {
        self.search = search
    }

    /// Semantically-related notes for a note — its (title + body) text is the query, the note ITSELF is
    /// excluded, and the top `limit` notes-domain hits come back ranked by the engine's RRF score.
    /// Over-fetches by one so removing self still yields up to `limit`.
    func relatedNotes(noteID: String, queryText: String, limit: Int = 10) async -> [ShadowHit] {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        let hits = await search.search(text: trimmed, domain: .notes, limit: limit + 1)
        return Array(hits.filter { $0.id != noteID }.prefix(limit))
    }
}
