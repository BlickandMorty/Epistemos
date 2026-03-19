import Foundation
import SwiftData

// MARK: - SDChat
// Replaces v2's GRDB-based ChatRepository with SwiftData.
// Each chat is a conversation thread with ordered messages.
// Supports CloudKit sync — chat history follows you across devices.
//
// CloudKit-compatible: all properties optional or defaulted.

@Model
final class SDChat {
    #Index<SDChat>([\.id], [\.updatedAt])

    // MARK: - Identity
    var id: String = UUID().uuidString

    // MARK: - Content
    var title: String = "New Chat"
    var chatType: String = "chat"       // "chat", "notes"
    // Legacy persisted field kept for lightweight migration compatibility.
    var hasDeepResearch: Bool? = false
    /// Page ID of the note this chat is linked to (note chats + cross-system association).
    var linkedPageId: String?

    // MARK: - Timestamps
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \SDMessage.chat)
    var messages: [SDMessage]? = []

    // MARK: - Init

    init(title: String = "New Chat", chatType: String = "chat") {
        self.id = UUID().uuidString
        self.title = title
        self.chatType = chatType
        self.createdAt = .now
        self.updatedAt = .now
    }

    private static func messageSortRank(for role: String) -> Int {
        switch role {
        case "user": 0
        case "assistant": 1
        default: 2
        }
    }

    var sortedMessages: [SDMessage] {
        (messages ?? []).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                let lhsRank = Self.messageSortRank(for: lhs.role)
                let rhsRank = Self.messageSortRank(for: rhs.role)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.id < rhs.id
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    @MainActor
    var loadedMessages: [ChatMessage] {
        sortedMessages.map { $0.chatMessage(chatId: id) }
    }
}
