import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("CloudKnowledgeDistillation")
struct CloudKnowledgeDistillationTests {
    private enum SampleFailure: Error {
        case expected
    }

    private func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(EpistemosSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeNote(
        id: String,
        title: String,
        body: String,
        tags: [String],
        updatedAt: Date
    ) -> KnowledgeSourceNote {
        KnowledgeSourceNote(
            id: id,
            title: title,
            body: body,
            tags: tags,
            updatedAt: updatedAt,
            createdAt: updatedAt.addingTimeInterval(-86400)
        )
    }

    @Test("compiler generates the four model vault documents")
    func compilerGeneratesStructuredDocuments() {
        let now = Date(timeIntervalSince1970: 1_775_150_400)
        let compiler = CloudKnowledgeCompiler(nowProvider: { now })
        let notes = [
            makeNote(
                id: "note-transformers",
                title: "Transformer Memory Notes",
                body: """
                Transformers use attention to route context across tokens.
                I care about retrieval, recurrence, and long-context memory.
                My current experiments compare attention heads with external memory.
                """,
                tags: ["transformers", "machine learning"],
                updatedAt: now.addingTimeInterval(-3600)
            ),
            makeNote(
                id: "note-retrieval",
                title: "Retrieval Practice Weekly Review",
                body: """
                Retrieval practice strengthens memory better than rereading.
                I want concise summaries with evidence and concrete examples.
                The vault should connect retrieval, spacing, and durable understanding.
                """,
                tags: ["retrieval", "learning-science"],
                updatedAt: now.addingTimeInterval(-7200)
            ),
        ]

        let compilation = compiler.compile(
            modelID: "claude-opus-4.6",
            displayName: "Claude Opus 4.6",
            notes: notes,
            recentChats: ["Discussed how retrieval supports long-context memory."],
            instructions: "Prefer concise answers with citations."
        )

        #expect(compilation.knowledgeProfile.contains("## Domain Map"))
        #expect(compilation.knowledgeProfile.contains("## Writing Style Fingerprint"))
        #expect(compilation.knowledgeProfile.contains("transformers"))
        #expect(compilation.conceptIndex.contains("## Concept Index"))
        #expect(compilation.conceptIndex.contains("retrieval"))
        #expect(compilation.activeContext.contains("## Active Context"))
        #expect(compilation.activeContext.contains("Transformer Memory Notes"))
        #expect(compilation.activeContext.contains("Discussed how retrieval supports long-context memory."))
        #expect(compilation.instructions == "Prefer concise answers with citations.")
        #expect(compilation.metadata.noteCount == 2)
        #expect(compilation.metadata.conceptCount > 0)
    }

    @Test("store round-trips compilation and preserves user instructions")
    func storeRoundTripsAndPreservesInstructions() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("knowledge-profile-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let now = Date(timeIntervalSince1970: 1_775_150_400)
        let compiler = CloudKnowledgeCompiler(nowProvider: { now })
        let compilation = compiler.compile(
            modelID: "gpt-5.4",
            displayName: "GPT-5.4",
            notes: [
                makeNote(
                    id: "note-1",
                    title: "Systems Note",
                    body: "I prefer direct, structured writing about systems design.",
                    tags: ["systems"],
                    updatedAt: now
                )
            ],
            recentChats: [],
            instructions: "Original instructions"
        )

        try await store.save(compilation)

        let instructionsURL = await store.instructionsURL(for: "gpt-5.4")
        try "User-customized instructions".write(to: instructionsURL, atomically: true, encoding: .utf8)

        let refreshedCompilation = CompiledModelVault(
            modelID: compilation.modelID,
            displayName: compilation.displayName,
            knowledgeProfile: compilation.knowledgeProfile + "\nUpdated",
            conceptIndex: compilation.conceptIndex,
            activeContext: compilation.activeContext,
            instructions: nil,
            metadata: compilation.metadata
        )

        try await store.save(refreshedCompilation)
        let loaded = try #require(await store.load(modelID: "gpt-5.4"))

        #expect(loaded.instructions == "User-customized instructions")
        #expect(loaded.knowledgeProfile.contains("Updated"))
        #expect(FileManager.default.fileExists(atPath: instructionsURL.path))
        #expect(loaded.metadata.noteCount == 1)
    }

    @Test("store augments a full system prompt with compiled model vault context")
    func storeAugmentsFullSystemPrompt() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("knowledge-profile-prompt-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let now = Date(timeIntervalSince1970: 1_775_150_400)
        let compiler = CloudKnowledgeCompiler(nowProvider: { now })
        let compilation = compiler.compile(
            modelID: "gpt-5.4",
            displayName: "GPT-5.4",
            notes: [
                makeNote(
                    id: "systems-note",
                    title: "Systems Research",
                    body: "I prefer concrete systems tradeoffs with direct language and retrieval evidence.",
                    tags: ["systems", "retrieval"],
                    updatedAt: now
                )
            ],
            recentChats: ["Recent chat about retrieval-aware prompting."],
            instructions: "Prefer concise answers with citations."
        )

        try await store.save(compilation)
        let systemPrompt = try await store.augmentedSystemPrompt(
            existingPrompt: "Base system prompt",
            modelID: "gpt-5.4",
            budget: .full
        )

        let resolvedSystemPrompt = try #require(systemPrompt)
        #expect(resolvedSystemPrompt.contains("# Model Vault Context"))
        #expect(resolvedSystemPrompt.contains("## Concept Index"))
        #expect(resolvedSystemPrompt.contains("## Active Context"))
        #expect(resolvedSystemPrompt.contains("Base system prompt"))
    }

    @Test("store uses compact prompt context for Apple Intelligence vault injection")
    func storeUsesCompactPromptContextForAppleIntelligence() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("knowledge-profile-compact-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let now = Date(timeIntervalSince1970: 1_775_150_400)
        let compiler = CloudKnowledgeCompiler(nowProvider: { now })
        let compilation = compiler.compile(
            modelID: "apple-intelligence",
            displayName: "Apple Intelligence",
            notes: [
                makeNote(
                    id: "note-1",
                    title: "Current Research",
                    body: "The current project connects retrieval, memory, and transformer interfaces.",
                    tags: ["memory", "transformers"],
                    updatedAt: now
                )
            ],
            recentChats: ["Recent chat summary"],
            instructions: "Be concise."
        )

        try await store.save(compilation)
        let systemPrompt = try await store.augmentedSystemPrompt(
            existingPrompt: nil,
            modelID: "apple-intelligence",
            budget: .compact
        )

        let resolvedSystemPrompt = try #require(systemPrompt)
        #expect(resolvedSystemPrompt.contains("# Model Vault Context"))
        #expect(resolvedSystemPrompt.contains("## Active Context"))
        #expect(!resolvedSystemPrompt.contains("## Concept Index"))
    }

    @Test("concept ranker favors recent tagged concepts over stale generic terms")
    func conceptRankerFavorsRecentTaggedConcepts() {
        let now = Date(timeIntervalSince1970: 1_775_150_400)
        let ranker = ConceptRanker(nowProvider: { now })
        let ranked = ranker.rankConcepts(
            notes: [
                makeNote(
                    id: "recent-transformers",
                    title: "Transformer Attention",
                    body: "Attention attention attention and retrieval systems.",
                    tags: ["transformers"],
                    updatedAt: now.addingTimeInterval(-1800)
                ),
                makeNote(
                    id: "stale-note",
                    title: "General Notes",
                    body: "General general general writing about notes.",
                    tags: [],
                    updatedAt: now.addingTimeInterval(-86400 * 45)
                ),
            ],
            limit: 5
        )

        let transformersIndex = ranked.firstIndex { $0.term == "transformers" }
        let generalIndex = ranked.firstIndex { $0.term == "general" }

        #expect(transformersIndex != nil)
        #expect(generalIndex != nil)
        if let transformersIndex, let generalIndex {
            #expect(transformersIndex < generalIndex)
        }
    }

    @Test("compiler preserves real recency when the domain map falls back to ranked concepts")
    func compilerPreservesRealRecencyForUntaggedConcepts() {
        let now = Date(timeIntervalSince1970: 1_775_150_400)
        let updatedAt = now.addingTimeInterval(-86400 * 12)
        let compiler = CloudKnowledgeCompiler(nowProvider: { now })
        let notes = [
            makeNote(
                id: "untagged-note",
                title: "Indexical Memory",
                body: "Indexical memory helps connect retrieval practice to durable context over time.",
                tags: [],
                updatedAt: updatedAt
            )
        ]

        let compilation = compiler.compile(
            modelID: "claude-opus-4.6",
            displayName: "Claude Opus 4.6",
            notes: notes,
            recentChats: [],
            instructions: nil
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let updatedDateString = formatter.string(from: updatedAt)
        let domainLine = compilation.knowledgeProfile
            .split(separator: "\n")
            .first { $0.contains("indexical") }

        #expect(domainLine?.contains(updatedDateString) == true)
    }

    @Test("service rebuilds model vaults from real SwiftData notes")
    func serviceRebuildsModelVaultsFromSwiftDataNotes() async throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_775_150_400)

        let systemsPage = SDPage(title: "Systems Research")
        systemsPage.tags = ["systems", "retrieval"]
        systemsPage.updatedAt = now.addingTimeInterval(-900)
        systemsPage.saveBody("I prefer direct systems design notes with concrete tradeoffs and retrieval evidence.")
        context.insert(systemsPage)

        let archivedPage = SDPage(title: "Archived Draft")
        archivedPage.tags = ["archive-only"]
        archivedPage.isArchived = true
        archivedPage.updatedAt = now.addingTimeInterval(-600)
        archivedPage.saveBody("This archived note should not enter the model vault.")
        context.insert(archivedPage)

        let researchPage = SDPage(title: "Memory Experiments")
        researchPage.tags = ["memory", "transformers"]
        researchPage.updatedAt = now.addingTimeInterval(-300)
        researchPage.saveBody("Transformers need better memory interfaces and retrieval-aware prompting.")
        context.insert(researchPage)

        try context.save()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-knowledge-service-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let service = CloudKnowledgeDistillationService(
            modelContainer: container,
            store: store,
            targetsProvider: {
                [
                    ModelVaultTarget(
                        modelID: "gpt-5.4",
                        displayName: "GPT-5.4",
                        conceptLimit: 40,
                        activeWindowDays: 7
                    ),
                    ModelVaultTarget(
                        modelID: "apple-intelligence",
                        displayName: "Apple Intelligence",
                        conceptLimit: 12,
                        activeWindowDays: 7
                    ),
                ]
            },
            recentChatsProvider: {
                ["Discussed retrieval-aware prompting for transformer memory."]
            },
            nowProvider: { now }
        )

        let summary = try await service.rebuildAllModelVaults()
        let gptVault = try #require(await store.load(modelID: "gpt-5.4"))
        let appleVault = try #require(await store.load(modelID: "apple-intelligence"))

        #expect(summary.sourceNoteCount == 2)
        #expect(summary.compiledModelIDs == ["apple-intelligence", "gpt-5.4"])
        #expect(gptVault.metadata.noteCount == 2)
        #expect(gptVault.activeContext.contains("Systems Research"))
        #expect(gptVault.knowledgeProfile.contains("transformers"))
        #expect(!gptVault.knowledgeProfile.contains("Archived Draft"))
        #expect(gptVault.activeContext.contains("retrieval-aware prompting"))
        #expect(appleVault.metadata.conceptCount <= gptVault.metadata.conceptCount)
    }

    @Test("service loads recent chats from SwiftData when no provider override is supplied")
    func serviceLoadsRecentChatsFromSwiftDataByDefault() async throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_775_150_400)

        let page = SDPage(title: "Memory Systems")
        page.tags = ["memory"]
        page.updatedAt = now.addingTimeInterval(-600)
        page.saveBody("Memory systems need retrieval-aware prompting and stable context.")
        context.insert(page)

        let chat = SDChat(title: "Retrieval Thread")
        chat.updatedAt = now.addingTimeInterval(-120)
        let userMessage = SDMessage(
            role: "user",
            content: "How should we think about retrieval-aware prompting for transformer memory?"
        )
        userMessage.createdAt = now.addingTimeInterval(-180)
        userMessage.chat = chat

        let assistantMessage = SDMessage(
            role: "assistant",
            content: "We discussed retrieval-aware prompting as the bridge between transformer context and longer-lived memory."
        )
        assistantMessage.createdAt = now.addingTimeInterval(-90)
        assistantMessage.chat = chat
        chat.messages = [userMessage, assistantMessage]

        context.insert(chat)
        context.insert(userMessage)
        context.insert(assistantMessage)
        try context.save()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-knowledge-chat-default-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let service = CloudKnowledgeDistillationService(
            modelContainer: container,
            store: store,
            targetsProvider: {
                [
                    ModelVaultTarget(
                        modelID: "gpt-5.4",
                        displayName: "GPT-5.4",
                        conceptLimit: 40,
                        activeWindowDays: 7
                    )
                ]
            },
            nowProvider: { now }
        )

        let summary = try await service.rebuildAllModelVaults()
        let vault = try #require(await store.load(modelID: "gpt-5.4"))

        #expect(summary.recentChatCount == 1)
        #expect(vault.activeContext.contains("Retrieval Thread"))
        #expect(vault.activeContext.contains("retrieval-aware prompting"))
    }

    @Test("service does not silently cap source notes at ten thousand pages")
    func serviceDoesNotSilentlyCapSourceNotes() async throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_775_150_400)
        let noteCount = 10_025

        for index in 0..<noteCount {
            let page = SDPage(title: "Scale Note \(index)")
            page.updatedAt = now.addingTimeInterval(-Double(index))
            page.body = "Scaling retrieval notes should all be compiled."
            context.insert(page)
        }
        try context.save()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-knowledge-scale-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let service = CloudKnowledgeDistillationService(
            modelContainer: container,
            store: store,
            targetsProvider: {
                [
                    ModelVaultTarget(
                        modelID: "apple-intelligence",
                        displayName: "Apple Intelligence",
                        conceptLimit: 12,
                        activeWindowDays: 7
                    )
                ]
            },
            nowProvider: { now }
        )

        let summary = try await service.rebuildAllModelVaults()
        let vault = try #require(await store.load(modelID: "apple-intelligence"))

        #expect(summary.sourceNoteCount == noteCount)
        #expect(vault.metadata.noteCount == noteCount)
    }

    @Test("service propagates source note loader failures instead of compiling an empty vault")
    func servicePropagatesSourceNoteLoadFailures() async throws {
        let container = try makeModelContainer()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-knowledge-loader-failure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let service = CloudKnowledgeDistillationService(
            modelContainer: container,
            store: store,
            targetsProvider: {
                [
                    ModelVaultTarget(
                        modelID: "gpt-5.4",
                        displayName: "GPT-5.4",
                        conceptLimit: 40,
                        activeWindowDays: 7
                    )
                ]
            },
            sourceNotesProvider: {
                throw SampleFailure.expected
            }
        )

        await #expect(throws: SampleFailure.self) {
            _ = try await service.rebuildAllModelVaults()
        }
        #expect(try await store.load(modelID: "gpt-5.4") == nil)
    }
}
