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
    private let targetsProvider: @Sendable () -> [ModelVaultTarget]
    private let sourceNotesProvider: (@Sendable () throws -> [KnowledgeSourceNote])?
    private let recentChatsProvider: (@Sendable () throws -> [String])?
    private let nowProvider: @Sendable () -> Date

    init(
        modelContainer: ModelContainer,
        store: KnowledgeProfileStore = KnowledgeProfileStore(),
        targetsProvider: @escaping @Sendable () -> [ModelVaultTarget] = {
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
        let notes = try sourceNotesProvider?() ?? Self.loadNotes(from: modelContainer)
        let recentChats = try (recentChatsProvider?() ?? Self.loadRecentChats(from: modelContainer))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var compiledModelIDs: [String] = []
        for target in targetsProvider().sorted(by: Self.sortTargets) {
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

    private nonisolated static func loadNotes(from container: ModelContainer) throws -> [KnowledgeSourceNote] {
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

            let title = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = sourceBody(for: page)
            guard !title.isEmpty || !body.isEmpty else { continue }

            notes.append(
                KnowledgeSourceNote(
                    id: page.id,
                    title: title.isEmpty ? "Untitled Note" : title,
                    body: body,
                    tags: page.tags,
                    updatedAt: page.updatedAt,
                    createdAt: page.createdAt
                )
            )
        }

        return notes
    }

    private nonisolated static func sourceBody(for page: SDPage) -> String {
        // Large synthetic and pre-migration note sets can legitimately exist only
        // in the inline `body` field. Avoid hitting the managed-file path for
        // every such note when there is no external vault file to consult.
        if page.filePath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            let inlineBody = page.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !inlineBody.isEmpty {
                return inlineBody
            }
        }

        return page.loadBody(mapped: true).trimmingCharacters(in: .whitespacesAndNewlines)
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
            contentsOf: LocalTextModelID.allCases.map {
                ModelVaultTarget(
                    modelID: $0.rawValue,
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
