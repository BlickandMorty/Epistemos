import Foundation
import SwiftData

/// L1187 / L1184 — owner: "tell me the best essay i have in my vault… it still cant resolve
/// things from simple queries." A natural-language vault-ranking query ("the best essay in my
/// vault", "what's my top note about X") should return a RANKED answer with title / path /
/// reason, not a generic model reply or an empty "no vault retrieval". This is the deterministic,
/// model-agnostic responder for that: it classifies the query, extracts search terms, runs the
/// existing vault search, and formats a ranked answer.
///
/// Behind EPISTEMOS_VAULT_BEST_ESSAY_V0 (default OFF): OFF → the chat pipeline is byte-identical
/// (no intercept). ON → a recognised vault-ranking query is answered directly from vault search.
/// The classifier is conservative (requires an explicit vault mention) so it never hijacks normal
/// chat. Read-only: it only searches + reads page paths, never writes.
enum VaultBestEssayResponder {

    /// Default OFF. Set `EPISTEMOS_VAULT_BEST_ESSAY_V0=1` to enable the deterministic fast-path.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_VAULT_BEST_ESSAY_V0"] == "1"
    }

    /// A ranked vault hit, ready to format. `path` is the vault-relative note path (nil if
    /// unresolved); `snippet` is the matched excerpt that justifies the ranking.
    struct RankedHit: Sendable, Equatable {
        let title: String
        let path: String?
        let snippet: String
        let rank: Double
    }

    /// Conservative classifier: only true when the query explicitly references the vault/notes
    /// AND carries a ranking/retrieval intent. This keeps normal chat ("write a haiku") out of
    /// the deterministic path entirely.
    static func isVaultRankingQuery(_ query: String) -> Bool {
        let q = query.lowercased()
        let mentionsVault =
            q.contains("my vault") || q.contains("the vault") || q.contains("from my vault")
            || q.contains("in my notes") || q.contains("my notes")
        guard mentionsVault else { return false }
        let rankingOrRetrieval = [
            "best", "top", "favorite", "favourite", "greatest", "worst", "longest",
            "most", "find", "show", "which", "what", "list", "recommend",
        ]
        return rankingOrRetrieval.contains { q.contains($0) }
    }

    /// Strip ranking + vault + filler words, leaving the topic to search for. "tell me the best
    /// essay i have in my vault" → "essay"; "what's my best note about climate in my vault" →
    /// "climate". Empty when the query has no concrete topic (then the caller declines).
    static func searchTerms(from query: String) -> String {
        let stop: Set<String> = [
            "tell", "me", "the", "best", "top", "favorite", "favourite", "greatest", "worst",
            "longest", "most", "find", "show", "which", "what", "whats", "list", "recommend",
            "my", "vault", "in", "notes", "note", "i", "have", "is", "a", "an", "about", "for",
            "from", "please", "can", "you", "do", "of", "that", "to", "give",
        ]
        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            // Drop single-char tokens too (e.g. the "s" from "what's") — never useful search terms.
            .filter { $0.count > 1 && !stop.contains($0) }
        return words.joined(separator: " ")
    }

    /// Format the ranked answer (title / path / reason per hit). Deterministic + honest: framed as
    /// "ranked by relevance" (it is a search ranking, not a quality judgement).
    static func rankedAnswer(query: String, hits: [RankedHit]) -> String {
        guard !hits.isEmpty else { return "" }
        var lines = ["Here are the top matches in your vault, ranked by relevance:", ""]
        for (index, hit) in hits.prefix(5).enumerated() {
            let title = hit.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let pathPart = hit.path.map { " — `\($0)`" } ?? ""
            var entry = "\(index + 1). **\(title.isEmpty ? "Untitled note" : title)**\(pathPart)"
            let reason = hit.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reason.isEmpty {
                entry += "\n   \(reason)"
            }
            lines.append(entry)
        }
        return lines.joined(separator: "\n")
    }

    /// Live deterministic answer: classify → extract terms → run the existing vault search →
    /// resolve each hit's path → format. Returns nil when the query isn't a vault-ranking query,
    /// has no concrete topic, or yields no results (the caller then falls through to the model).
    @MainActor
    static func liveAnswer(
        query: String,
        searchService: SearchIndexService,
        modelContext: ModelContext
    ) -> String? {
        guard isVaultRankingQuery(query) else { return nil }
        let terms = searchTerms(from: query)
        guard !terms.isEmpty else { return nil }
        let results = (try? searchService.search(query: terms, limit: 5)) ?? []
        guard !results.isEmpty else { return nil }
        let hits = results.map { result in
            RankedHit(
                title: result.title,
                path: pathForPage(id: result.pageId, modelContext: modelContext),
                snippet: result.snippet,
                rank: result.rank
            )
        }
        let answer = rankedAnswer(query: query, hits: hits)
        return answer.isEmpty ? nil : answer
    }

    @MainActor
    private static func pathForPage(id: String, modelContext: ModelContext) -> String? {
        var descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first)?.vaultRelativeNotePath
    }
}
