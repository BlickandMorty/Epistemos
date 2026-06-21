import Testing
import Foundation

@testable import Epistemos

// L1187 / L1184 — owner: "tell me the best essay i have in my vault… it still cant resolve things
// from simple queries." These exercise the deterministic, model-agnostic core of the ranked-vault
// responder: a conservative classifier (never hijacks normal chat), topic-term extraction, and the
// title/path/reason answer format. The flag defaults OFF so the chat pipeline is byte-identical
// until opt-in; the pipeline intercept is gated by both the flag and the classifier.
@Suite("L1187 — vault best-essay ranked responder")
struct VaultBestEssayResponderTests {

    @Test("classifies explicit vault-ranking queries; leaves normal chat alone")
    func classifier() {
        #expect(VaultBestEssayResponder.isVaultRankingQuery("tell me the best essay i have in my vault"))
        #expect(VaultBestEssayResponder.isVaultRankingQuery("what's my top note about climate in my vault"))
        #expect(VaultBestEssayResponder.isVaultRankingQuery("find my notes on swift concurrency"))
        // Normal chat — no vault reference → never intercepted (the data-loss-free safety: pure chat
        // is untouched).
        #expect(!VaultBestEssayResponder.isVaultRankingQuery("write a haiku about the sea"))
        #expect(!VaultBestEssayResponder.isVaultRankingQuery("what is the capital of France"))
        // Vault reference but no ranking/retrieval intent → not a ranking query.
        #expect(!VaultBestEssayResponder.isVaultRankingQuery("open my vault"))
    }

    @Test("extracts the topic terms, stripping ranking + vault + filler + contraction fragments")
    func terms() {
        #expect(VaultBestEssayResponder.searchTerms(from: "tell me the best essay i have in my vault") == "essay")
        #expect(VaultBestEssayResponder.searchTerms(from: "what's my best note about climate in my vault") == "climate")
    }

    @Test("formats a ranked answer with title, path, and reason; empty hits → empty")
    func formatter() {
        let hits = [
            VaultBestEssayResponder.RankedHit(title: "On Focus", path: "essays/focus.md", snippet: "deep work…", rank: 1.0),
            VaultBestEssayResponder.RankedHit(title: "Time", path: nil, snippet: "", rank: 0.5),
        ]
        let answer = VaultBestEssayResponder.rankedAnswer(query: "best essay in my vault", hits: hits)
        #expect(answer.contains("1. **On Focus**"))      // ranked + title
        #expect(answer.contains("`essays/focus.md`"))    // path
        #expect(answer.contains("deep work"))            // reason / matched excerpt
        #expect(answer.contains("ranked by relevance"))  // honest framing
        #expect(answer.contains("2. **Time**"))          // second hit, no path → still listed
        #expect(VaultBestEssayResponder.rankedAnswer(query: "x", hits: []).isEmpty)
    }

    @Test("the responder flag defaults OFF (chat pipeline byte-identical until opt-in)")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_VAULT_BEST_ESSAY_V0"] == nil {
            #expect(VaultBestEssayResponder.isEnabled == false)
        }
    }

    @Test("the pipeline intercept is gated by the flag + the classifier (no hijack of normal chat)")
    func pipelineGated() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        #expect(src.contains("VaultBestEssayResponder.isEnabled"))
        #expect(src.contains("VaultBestEssayResponder.isVaultRankingQuery(query)"))
    }
}
