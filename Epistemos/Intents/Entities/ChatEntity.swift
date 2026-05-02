import Foundation
import AppIntents
import CoreSpotlight
import SwiftData

// MARK: - Chat Entity
// Maps to SDChat in SwiftData. Used by custom intents for chat search and access.

struct ChatEntity: AppEntity, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Chat")
    }
    static var defaultQuery: ChatEntityQuery {
        ChatEntityQuery()
    }

    var id: String
    @Property(title: "Title") var title: String
    @Property(title: "Chat Type") var chatType: String
    @Property(title: "Linked Page ID") var linkedPageId: String?
    @Property(title: "Preview") var contentPreview: String?
    @Property(title: "Created") var createdAt: Date
    @Property(title: "Updated") var updatedAt: Date

    init(
        id: String,
        title: String,
        chatType: String = "chat",
        linkedPageId: String? = nil,
        contentPreview: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.chatType = chatType
        self.linkedPageId = linkedPageId
        self.contentPreview = contentPreview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

// MARK: - ChatEntity + IndexedEntity

extension ChatEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = title
        let fallbackDescription = linkedPageId.map { "Linked to note \($0)" } ?? "Chat thread"
        if let preview = contentPreview?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty {
            set.contentDescription = String(preview.prefix(160))
        } else {
            set.contentDescription = fallbackDescription
        }
        set.contentCreationDate = createdAt
        set.contentModificationDate = updatedAt
        set.displayName = title
        set.kind = "Epistemos Chat"
        return set
    }
}

// MARK: - Chat Entity Query

struct ChatEntityQuery: EntityStringQuery {
    private static let matchingFetchLimit = 100
    private static let matchingResultLimit = 20
    private static let suggestionLimit = 10

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ChatEntity] {
        guard let bootstrap = AppBootstrap.shared else { return [] }
        let context = ModelContext(bootstrap.modelContainer)
        var results: [ChatEntity] = []
        for id in identifiers {
            let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == id })
            do {
                if let chat = try context.fetch(descriptor).first {
                    results.append(chat.toChatEntity())
                }
            } catch {
                Log.app.error(
                    "ChatEntityQuery: failed to fetch chat \(String(id.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        return results
    }

    @MainActor
    func entities(matching string: String) async throws -> IntentItemCollection<ChatEntity> {
        guard let bootstrap = AppBootstrap.shared else { return IntentItemCollection(items: []) }
        let context = ModelContext(bootstrap.modelContainer)
        let trimmedQuery = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return IntentItemCollection(items: []) }

        var descriptor = FetchDescriptor<SDChat>(
            sortBy: [SortDescriptor(\SDChat.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.matchingFetchLimit

        let chats: [SDChat]
        do {
            chats = try context.fetch(descriptor)
        } catch {
            Log.app.error(
                "ChatEntityQuery: failed to fetch chats: \(error.localizedDescription, privacy: .public)"
            )
            return IntentItemCollection(items: [])
        }

        let matched = chats.filter {
            Self.chatMatches($0, query: trimmedQuery)
        }
        return IntentItemCollection(items: Array(matched.prefix(Self.matchingResultLimit).map {
            $0.toChatEntity(contentPreview: Self.preview(for: $0))
        }))
    }

    @MainActor
    func suggestedEntities() async throws -> IntentItemCollection<ChatEntity> {
        guard let bootstrap = AppBootstrap.shared else { return IntentItemCollection(items: []) }
        let context = ModelContext(bootstrap.modelContainer)
        var descriptor = FetchDescriptor<SDChat>(
            sortBy: [SortDescriptor(\SDChat.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.suggestionLimit

        let chats: [SDChat]
        do {
            chats = try context.fetch(descriptor)
        } catch {
            Log.app.error(
                "ChatEntityQuery: failed to fetch suggested chats: \(error.localizedDescription, privacy: .public)"
            )
            return IntentItemCollection(items: [])
        }

        return IntentItemCollection(items: chats.map {
            $0.toChatEntity(contentPreview: Self.preview(for: $0))
        })
    }

    private static func chatMatches(_ chat: SDChat, query: String) -> Bool {
        chat.title.localizedStandardContains(query)
            || chat.chatType.localizedStandardContains(query)
            || (chat.linkedPageId?.localizedStandardContains(query) ?? false)
            || (preview(for: chat)?.localizedStandardContains(query) ?? false)
    }

    private static func preview(for chat: SDChat) -> String? {
        for message in chat.sortedMessages.reversed() {
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(500))
            }
        }
        return nil
    }
}

// MARK: - SDChat to ChatEntity

extension SDChat {
    func toChatEntity(contentPreview: String? = nil) -> ChatEntity {
        ChatEntity(
            id: id,
            title: title.isEmpty ? "Untitled Chat" : title,
            chatType: chatType,
            linkedPageId: linkedPageId,
            contentPreview: Self.normalizedPreview(contentPreview),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func normalizedPreview(_ contentPreview: String?) -> String? {
        guard let contentPreview else { return nil }
        let trimmed = contentPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(500))
    }
}
