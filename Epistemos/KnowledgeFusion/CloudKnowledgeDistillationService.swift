import Foundation
import SwiftData

nonisolated struct ModelVaultTarget: Sendable, Equatable {
    let modelID: String
    let displayName: String
    let conceptLimit: Int
    let activeWindowDays: Int
}

nonisolated struct CloudKnowledgeDistillationRunSummary: Sendable, Equatable {
    let compiledModelIDs: [String]
    let sourceNoteCount: Int
    let recentChatCount: Int
}

actor CloudKnowledgeDistillationService {
    private let modelContainer: ModelContainer
    private let store: KnowledgeProfileStore
    private let targetsProvider: @MainActor @Sendable () -> [ModelVaultTarget]
    private let sourceNotesProvider: (@Sendable () throws -> [KnowledgeSourceNote])?
    private let recentChatsProvider: (@Sendable () throws -> [String])?
    private let nowProvider: @Sendable () -> Date

    init(
        modelContainer: ModelContainer,
        store: KnowledgeProfileStore = KnowledgeProfileStore(),
        targetsProvider: @escaping @MainActor @Sendable () -> [ModelVaultTarget] = {
            CloudKnowledgeDistillationService.defaultTargets()
        },
        sourceNotesProvider: (@Sendable () throws -> [KnowledgeSourceNote])? = nil,
        recentChatsProvider: (@Sendable () throws -> [String])? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.modelContainer = modelContainer
        self.store = store
        self.targetsProvider = targetsProvider
        self.sourceNotesProvider = sourceNotesProvider
        self.recentChatsProvider = recentChatsProvider
        self.nowProvider = nowProvider
    }

    func rebuildAllModelVaults() async throws -> CloudKnowledgeDistillationRunSummary {
        let targets = await targetsProvider()
        return try await rebuildModelVaults(for: targets)
    }

    func rebuildModelVaults(for targets: [ModelVaultTarget]) async throws -> CloudKnowledgeDistillationRunSummary {
        // ?? autoclosure doesn't allow `await`; split into explicit
        // if-else so the Phase R.3 async path on `loadNotes` works
        // cleanly alongside the synchronous provider override (tests
        // stub `sourceNotesProvider` with a sync closure).
        let notes: [KnowledgeSourceNote]
        if let provider = sourceNotesProvider {
            notes = try provider()
        } else {
            notes = try await Self.loadNotes(from: modelContainer)
        }
        let recentChats = try (recentChatsProvider?() ?? Self.loadRecentChats(from: modelContainer))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var compiledModelIDs: [String] = []
        for target in targets.sorted(by: Self.sortTargets) {
            let compiler = CloudKnowledgeCompiler(
                nowProvider: nowProvider,
                activeWindowDays: target.activeWindowDays,
                conceptLimit: target.conceptLimit
            )
            let vault = compiler.compile(
                modelID: target.modelID,
                displayName: target.displayName,
                notes: notes,
                recentChats: recentChats,
                instructions: nil
            )
            try await store.save(vault)
            compiledModelIDs.append(target.modelID)
        }

        return CloudKnowledgeDistillationRunSummary(
            compiledModelIDs: compiledModelIDs,
            sourceNoteCount: notes.count,
            recentChatCount: recentChats.count
        )
    }

    private nonisolated static func sortTargets(
        lhs: ModelVaultTarget,
        rhs: ModelVaultTarget
    ) -> Bool {
        if lhs.modelID == "apple-intelligence" {
            return rhs.modelID != "apple-intelligence"
        }
        if rhs.modelID == "apple-intelligence" {
            return false
        }
        return lhs.modelID < rhs.modelID
    }

    private nonisolated static func loadNotes(from container: ModelContainer) async throws -> [KnowledgeSourceNote] {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        let pages = try context.fetch(descriptor)
        var notes: [KnowledgeSourceNote] = []
        notes.reserveCapacity(pages.count)

        for page in pages {
            guard !page.isArchived, !page.isTemplate else { continue }

            // Stage Sendable primitives before awaiting so SwiftData's
            // non-Sendable @Model reference doesn't cross the async
            // call boundary (Swift 6 region-based isolation).
            let title = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let pageId = page.id
            let filePath = page.filePath
            let inlineBody = page.body
            let tags = page.tags
            let updatedAt = page.updatedAt
            let createdAt = page.createdAt

            let body = await sourceBody(pageId: pageId, filePath: filePath, inlineBody: inlineBody)
            guard !title.isEmpty || !body.isEmpty else { continue }

            notes.append(
                KnowledgeSourceNote(
                    id: pageId,
                    title: title.isEmpty ? "Untitled Note" : title,
                    body: body,
                    tags: tags,
                    updatedAt: updatedAt,
                    createdAt: createdAt
                )
            )
        }

        return notes
    }

    /// Phase R.3: body read routed through
    /// `SDPage.loadBodyAsyncFromPrimitives`, which consults the R.3
    /// gateway when ready and falls back to `NoteFileStorage.readBody`.
    /// Takes only Sendable primitives so it can be awaited from any
    /// async context without moving a SwiftData @Model across actors.
    private nonisolated static func sourceBody(
        pageId: String,
        filePath: String?,
        inlineBody: String
    ) async -> String {
        // Large synthetic and pre-migration note sets can legitimately
        // exist only in the inline `body` field. Avoid hitting the
        // managed-file path when there is no external vault file.
        if filePath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            let trimmedInline = inlineBody.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedInline.isEmpty {
                return trimmedInline
            }
        }

        return await SDPage.loadBodyAsyncFromPrimitives(
            pageId: pageId,
            filePath: filePath,
            mapped: true
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func loadRecentChats(
        from container: ModelContainer,
        limit: Int = 8
    ) throws -> [String] {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = limit
        descriptor.relationshipKeyPathsForPrefetching = [\.messages]

        let chats = try context.fetch(descriptor)
        return chats.compactMap(summarizeChat)
    }

    private nonisolated static func summarizeChat(_ chat: SDChat) -> String? {
        let title = chat.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let relevantMessages = chat.sortedMessages.filter { message in
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return !content.isEmpty && !message.isError && message.role != "system"
        }

        guard !relevantMessages.isEmpty else {
            return title.isEmpty ? nil : title
        }

        let summary = relevantMessages.suffix(2).map { message in
            "\(messageLabel(for: message.role)): \(snippet(from: message.content, limit: 120))"
        }.joined(separator: " | ")
        let heading = title.isEmpty ? "Recent Chat" : title
        return "\(heading): \(summary)"
    }

    private nonisolated static func messageLabel(for role: String) -> String {
        switch role {
        case "user":
            return "User"
        case "assistant":
            return "Assistant"
        default:
            return "Message"
        }
    }

    private nonisolated static func snippet(from text: String, limit: Int) -> String {
        String(
            text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(limit)
        )
    }

    nonisolated static func defaultTargets() -> [ModelVaultTarget] {
        var targets: [ModelVaultTarget] = [
            ModelVaultTarget(
                modelID: "apple-intelligence",
                displayName: "Apple Intelligence",
                conceptLimit: 12,
                activeWindowDays: 7
            )
        ]

        targets.append(
            contentsOf: CloudTextModelID.allCases.map {
                ModelVaultTarget(
                    modelID: $0.vendorModelID,
                    displayName: $0.displayName,
                    conceptLimit: 60,
                    activeWindowDays: 7
                )
            }
        )

        targets.append(
            contentsOf: LocalModelCatalog.allDescriptors.map {
                ModelVaultTarget(
                    modelID: $0.id,
                    displayName: $0.displayName,
                    conceptLimit: 24,
                    activeWindowDays: 7
                )
            }
        )

        var seen = Set<String>()
        return targets.filter { seen.insert($0.modelID).inserted }
    }
}
