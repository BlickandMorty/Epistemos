import Foundation
import Testing
@testable import Epistemos

struct FVaultRecall50FallbackTests {
    @Test("soft vault fallback searches a contract-sized candidate pool")
    func softVaultFallbackSearchesContractSizedCandidatePool() async {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 120,
            isInventoryComplete: true,
            entries: [],
            recentBodies: [],
            generatedAt: now
        )
        var requestedLimits: [Int] = []

        _ = await ChatCoordinator.buildIndexedVaultLookupFallbackAnswer(
            query: "What notes in my vault mention train?",
            manifest: manifest,
            limit: 3
        ) { _, limit in
            requestedLimits.append(limit)
            return []
        }

        #expect(!requestedLimits.isEmpty)
        #expect(requestedLimits.allSatisfy { $0 == 50 })
    }

    @Test("indexed fallback answer emits per-hit provenance reasons")
    func indexedFallbackAnswerEmitsPerHitProvenanceReasons() async throws {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 1,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "page-alpha",
                    title: "Vault Recall Alpha",
                    relativePath: "Research/Vault Recall Alpha.md",
                    tags: ["vault"],
                    folderName: "Research",
                    wordCount: 120,
                    snippet: "Alpha context from the manifest",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )

        let result = try #require(await ChatCoordinator.buildIndexedVaultLookupFallbackAnswer(
            query: "Which notes mention vault recall alpha in my vault?",
            manifest: manifest,
            limit: 1
        ) { phrase, _ in
            [
                SearchResult(
                    pageId: "page-alpha",
                    title: "Vault Recall Alpha",
                    snippet: "Vault recall alpha appears in the indexed snippet.",
                    rank: phrase == "vault recall alpha" ? 12.0 : 1.0
                )
            ]
        })

        #expect(result.answer.contains("Why: Indexed vault search"))
        #expect(result.answer.contains("Phrase \"vault recall alpha\""))
        #expect(result.answer.contains("Source rank #1"))
        #expect(result.answer.contains("Title match"))
        #expect(result.answer.contains("Path match"))
        #expect(result.answer.contains("Snippet match"))
    }

    @Test("indexed fallback rejects source-rank-only matches")
    func indexedFallbackRejectsSourceRankOnlyMatches() async throws {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 1,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "page-unrelated",
                    title: "Unrelated Note",
                    relativePath: "Research/Unrelated Note.md",
                    tags: [],
                    folderName: "Research",
                    wordCount: 80,
                    snippet: "Nothing overlaps here.",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )

        let result = try #require(await ChatCoordinator.buildIndexedVaultLookupFallbackAnswer(
            query: "Which notes mention vault recall alpha in my vault?",
            manifest: manifest,
            limit: 1
        ) { _, _ in
            [
                SearchResult(
                    pageId: "page-unrelated",
                    title: "Unrelated Note",
                    snippet: "Nothing overlaps here.",
                    rank: 100.0
                )
            ]
        })

        #expect(result.loadedNoteIds.isEmpty)
        #expect(result.answer.contains("I couldn't find any indexed vault notes"))
        #expect(!result.answer.contains("Unrelated Note"))
    }

    @Test("note chat provenance parser extracts fallback card reasons")
    func noteChatProvenanceParserExtractsFallbackCardReasons() throws {
        let entries = NoteVaultProvenanceParser.entries(from: """
        I found these indexed vault matches for "vault recall alpha":
        - **Vault Recall Alpha** (`Research/Vault Recall Alpha.md`)
          Why: Indexed vault search; Phrase "vault recall alpha"; Source rank #1; Snippet match
          Vault recall alpha appears in the indexed snippet.
        """)

        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.title == "Vault Recall Alpha")
        #expect(entry.path == "Research/Vault Recall Alpha.md")
        #expect(entry.reasons.contains("Indexed vault search"))
        #expect(entry.reasons.contains("Source rank #1"))
        #expect(entry.reasons.contains("Snippet match"))
    }
}
