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
        #expect(result.answer.contains("Vault provenance:"))
        #expect(result.answer.contains("Vault provenance:\n- **Vault Recall Alpha** (`Research/Vault Recall Alpha.md`)"))
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
        #expect(result.answer.contains("but none had title, path, or snippet evidence"))
        #expect(result.answer.contains("vault context contract"))
        #expect(!result.answer.contains("Unrelated Note"))
    }

    @Test("indexed fallback rejects ambiguous single top match")
    func indexedFallbackRejectsAmbiguousSingleTopMatch() async throws {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 2,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "page-alpha",
                    title: "Vault Recall Alpha",
                    relativePath: "Research/Vault Recall Alpha.md",
                    tags: ["vault"],
                    folderName: "Research",
                    wordCount: 120,
                    snippet: "Vault recall alpha appears in the indexed snippet.",
                    updatedAt: now,
                    createdAt: now
                ),
                VaultManifest.ManifestEntry(
                    pageId: "page-alpha-draft",
                    title: "Vault Recall Alpha Draft",
                    relativePath: "Research/Vault Recall Alpha Draft.md",
                    tags: ["vault"],
                    folderName: "Research",
                    wordCount: 118,
                    snippet: "Vault recall alpha appears in a draft indexed snippet.",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )

        let result = try #require(await ChatCoordinator.buildIndexedVaultLookupFallbackAnswer(
            query: "Which note is vault recall alpha in my vault?",
            manifest: manifest,
            limit: 1
        ) { _, _ in
            [
                SearchResult(
                    pageId: "page-alpha",
                    title: "Vault Recall Alpha",
                    snippet: "Vault recall alpha appears in the indexed snippet.",
                    rank: 10.0
                ),
                SearchResult(
                    pageId: "page-alpha-draft",
                    title: "Vault Recall Alpha Draft",
                    snippet: "Vault recall alpha appears in a draft indexed snippet.",
                    rank: 11.0
                )
            ]
        })

        #expect(result.loadedNoteIds.isEmpty)
        #expect(result.loadedNoteTitles.isEmpty)
        #expect(result.answer.contains("top score margin is too low"))
        #expect(result.answer.contains("vault context contract"))
    }

    @Test("indexed fallback labels low-margin multi-hit answers")
    func indexedFallbackLabelsLowMarginMultiHitAnswers() async throws {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 2,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "page-alpha",
                    title: "Vault Recall Alpha",
                    relativePath: "Research/Vault Recall Alpha.md",
                    tags: ["vault"],
                    folderName: "Research",
                    wordCount: 120,
                    snippet: "Vault recall alpha appears in the indexed snippet.",
                    updatedAt: now,
                    createdAt: now
                ),
                VaultManifest.ManifestEntry(
                    pageId: "page-alpha-draft",
                    title: "Vault Recall Alpha Draft",
                    relativePath: "Research/Vault Recall Alpha Draft.md",
                    tags: ["vault"],
                    folderName: "Research",
                    wordCount: 118,
                    snippet: "Vault recall alpha appears in a draft indexed snippet.",
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
            limit: 2
        ) { _, _ in
            [
                SearchResult(
                    pageId: "page-alpha",
                    title: "Vault Recall Alpha",
                    snippet: "Vault recall alpha appears in the indexed snippet.",
                    rank: 10.0
                ),
                SearchResult(
                    pageId: "page-alpha-draft",
                    title: "Vault Recall Alpha Draft",
                    snippet: "Vault recall alpha appears in a draft indexed snippet.",
                    rank: 11.0
                )
            ]
        })

        #expect(result.loadedNoteTitles.count == 2)
        #expect(result.answer.contains("Top match is ambiguous"))
        #expect(result.answer.contains("low top score margin"))
        #expect(result.answer.contains("candidate context"))
        #expect(result.answer.contains("Vault Recall Alpha"))
        #expect(result.answer.contains("Vault Recall Alpha Draft"))
    }

    @Test("all-notes context does not load arbitrary recent bodies when search misses")
    func allNotesContextDoesNotLoadArbitraryRecentBodiesWhenSearchMisses() async throws {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 2,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "recent-page",
                    title: "Recent Unrelated",
                    relativePath: "Research/Recent Unrelated.md",
                    tags: [],
                    folderName: "Research",
                    wordCount: 80,
                    snippet: "No query overlap.",
                    updatedAt: now,
                    createdAt: now
                ),
                VaultManifest.ManifestEntry(
                    pageId: "older-page",
                    title: "Older Unrelated",
                    relativePath: "Research/Older Unrelated.md",
                    tags: [],
                    folderName: "Research",
                    wordCount: 75,
                    snippet: "Still no query overlap.",
                    updatedAt: now.addingTimeInterval(-86_400),
                    createdAt: now.addingTimeInterval(-86_400)
                )
            ],
            recentBodies: [
                VaultManifest.NoteBody(
                    pageId: "recent-page",
                    title: "Recent Unrelated",
                    relativePath: "Research/Recent Unrelated.md",
                    body: "This body must not be loaded just because it is recent."
                )
            ],
            generatedAt: now
        )

        let resolution = await ChatCoordinator.resolveNotesContext(
            query: "@[All Notes] tell me about missing recall",
            manifest: manifest,
            includeAllNotesContext: true,
            findNotesByTitle: { _ in [] },
            fetchNoteBodies: { ids in
                ids.map { pageId in
                    VaultManifest.NoteBody(
                        pageId: pageId,
                        title: "Fetched \(pageId)",
                        relativePath: nil,
                        body: "This body must not be loaded just because it is recent."
                    )
                }
            },
            searchNoteIDs: { _ in [] }
        )

        #expect(resolution.loadedNoteIds.isEmpty)
        #expect(resolution.context?.contains("- title: my mind") == true)
        #expect(resolution.context?.contains("Matched Vault Notes") != true)
        #expect(resolution.context?.contains("This body must not be loaded") != true)
    }

    @Test("vault lookup prompts reject low-confidence synthesis claims")
    func vaultLookupPromptsRejectLowConfidenceSynthesisClaims() throws {
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let localPrompt = try loadMirroredSourceTextFile(
            "Epistemos/LocalAgent/LocalAgentPromptBuilder.swift"
        )

        #expect(coordinator.contains("Do not answer from source rank alone"))
        #expect(coordinator.contains("low top score margin"))
        #expect(coordinator.contains("exact_escalation_required=true"))
        #expect(coordinator.contains("top_hit_source_rank_only"))
        #expect(coordinator.contains("exact_escalation_queries"))
        #expect(coordinator.contains("vault_context_contract_schema"))
        #expect(coordinator.contains("exact_escalation_*_limit"))
        #expect(coordinator.contains("do not expand target lists, query strings, or snippets beyond the traced caps"))
        #expect(coordinator.contains("missing or inconsistent"))
        #expect(coordinator.contains("retrieval trace as stale"))
        #expect(coordinator.contains("Do not answer from exact_escalation_targets or exact_escalation_queries themselves"))
        #expect(coordinator.contains("visible title/path/snippet/body evidence"))
        #expect(coordinator.contains("must match the escalated target title/path or one of the bounded exact_escalation_queries"))
        #expect(coordinator.contains("use at least two independently retrieved vault notes"))
        #expect(coordinator.contains("ambiguous or low confidence"))
        #expect(coordinator.contains("Vault provenance:"))
        #expect(localPrompt.contains("Do not answer from source rank alone"))
        #expect(localPrompt.contains("low top score margin"))
        #expect(localPrompt.contains("exact_escalation_required=true"))
        #expect(localPrompt.contains("top_hit_source_rank_only"))
        #expect(localPrompt.contains("exact_escalation_queries"))
        #expect(localPrompt.contains("vault_context_contract_schema"))
        #expect(localPrompt.contains("exact_escalation_*_limit"))
        #expect(localPrompt.contains("do not expand target lists, query strings, or snippets beyond the traced caps"))
        #expect(localPrompt.contains("missing or inconsistent"))
        #expect(localPrompt.contains("retrieval trace as stale"))
        #expect(localPrompt.contains("Do not answer from exact_escalation_targets or exact_escalation_queries themselves"))
        #expect(localPrompt.contains("visible title/path/snippet/body evidence"))
        #expect(localPrompt.contains("must match the escalated target title/path or one of the bounded exact_escalation_queries"))
        #expect(localPrompt.contains("use at least two independently retrieved notes"))
        #expect(localPrompt.contains("name the loaded note title or vault-relative path"))
        #expect(localPrompt.contains("Vault provenance:"))
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

    @Test("note chat provenance parser extracts explicit vault provenance block")
    func noteChatProvenanceParserExtractsExplicitVaultProvenanceBlock() throws {
        let entries = NoteVaultProvenanceParser.entries(from: """
        The answer is grounded in the weekly planning notes.

        Vault provenance:
        - **Weekly Plan** (`Planning/Weekly Plan.md`)
          Why: High confidence; Title match; Snippet match
          Why: Exact verification match; Title match
        """)

        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.title == "Weekly Plan")
        #expect(entry.path == "Planning/Weekly Plan.md")
        #expect(entry.reasons.contains("High confidence"))
        #expect(entry.reasons.contains("Title match"))
        #expect(entry.reasons.contains("Snippet match"))
        #expect(entry.reasons.contains("Exact verification match"))
        #expect(entry.reasons.filter { $0 == "Title match" }.count == 1)
    }

    @Test("note chat provenance parser dedupes repeated explicit blocks")
    func noteChatProvenanceParserDedupesRepeatedExplicitBlocks() throws {
        let entries = NoteVaultProvenanceParser.entries(from: """
        I found these indexed vault matches for "vault recall alpha":
        - **Vault Recall Alpha** (`Research/Vault Recall Alpha.md`)
          Why: Indexed vault search; Source rank #1

        Vault provenance:
        - **Vault Recall Alpha** (`Research/Vault Recall Alpha.md`)
          Why: Indexed vault search; Snippet match
        """)

        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.title == "Vault Recall Alpha")
        #expect(entry.path == "Research/Vault Recall Alpha.md")
        #expect(entry.reasons.contains("Source rank #1"))
        #expect(entry.reasons.contains("Snippet match"))
    }

    @Test("note chat provenance cards prioritize exact evidence reasons")
    func noteChatProvenanceCardsPrioritizeExactEvidenceReasons() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteChatSidebar.swift")

        #expect(source.contains("private static func displayedReasons"))
        #expect(source.contains("private static func reasonPriority"))
        #expect(source.contains("private static func signalBadges"))
        #expect(source.contains("private static func badgePriority"))
        #expect(source.contains("Text(badge)"))
        #expect(source.contains("appendUnique(\"Exact\", to: &badges)"))
        #expect(source.contains("appendUnique(\"Lexical\", to: &badges)"))
        #expect(source.contains("appendUnique(\"Semantic\", to: &badges)"))
        #expect(source.contains("appendUnique(\"Graph\", to: &badges)"))
        #expect(source.contains("appendUnique(\"Recency\", to: &badges)"))
        #expect(source.contains("appendUnique(\"Escalate\", to: &badges)"))
        #expect(source.contains("case \"Exact\": return 0"))
        #expect(source.contains("case \"Escalate\": return 7"))
        #expect(source.contains("case \"Rank\": return 8"))
        #expect(source.contains("normalized.contains(\"exact verification\") { return 0 }"))
        #expect(source.contains("normalized.contains(\"title match\") { return 2 }"))
        #expect(source.contains("normalized.contains(\"snippet match\") { return 3 }"))
        #expect(source.contains("normalized.contains(\"top_hit_source_rank_only\")"))
        #expect(source.contains("normalized.contains(\"stale\")"))
        #expect(source.contains("normalized.contains(\"schema/cap\")"))
        #expect(source.contains("normalized.contains(\"source rank\") { return 8 }"))
        #expect(source.contains("ForEach(Self.displayedReasons(entry.reasons), id: \\.self)"))
    }
}
