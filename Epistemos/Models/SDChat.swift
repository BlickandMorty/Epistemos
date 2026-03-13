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
    var chatType: String = "chat"       // "chat", "notes", "research"
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

    var sortedMessages: [SDMessage] {
        (messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    @MainActor
    var loadedMessages: [ChatMessage] {
        sortedMessages.map { $0.chatMessage(chatId: id) }
    }
}
