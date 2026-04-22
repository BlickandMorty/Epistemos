import Foundation
import Observation

@MainActor @Observable
final class ThreadState {
    private static let miniChatThreadType = "miniChat"

    var chatThreads: [ChatThread] = []
    var activeThreadId: String = ""

    private var miniChatStreamingStateByID: [String: Bool] = [:]
    private var miniChatStreamingTextByID: [String: String] = [:]
    private var miniChatStreamingThinkingByID: [String: String] = [:]
    private var miniChatPendingContentBlocksByID: [String: [MessageContentBlock]] = [:]
    private var miniChatActiveToolNameByID: [String: String] = [:]
    private var miniChatActiveToolInputJsonByID: [String: String] = [:]

    @discardableResult
    func createThread(type: String = "chat", label: String = "Thread", pageId: String? = nil) -> String {
        let thread = ChatThread(type: type, label: label, pageId: pageId)
        chatThreads.append(thread)
        activeThreadId = thread.id
        return thread.id
    }

    func closeThread(_ threadId: String) {
        chatThreads.removeAll { $0.id == threadId }
        normalizeActiveThreadSelection()
    }

    func setActiveThread(_ threadId: String) {
        guard chatThreads.contains(where: { $0.id == threadId }) else { return }
        activeThreadId = threadId
    }

    func addThreadMessage(_ message: AssistantMessage, threadId: String? = nil) {
        let resolvedThreadID = threadId ?? activeThreadId
        guard let index = chatThreads.firstIndex(where: { $0.id == resolvedThreadID }) else { return }
        chatThreads[index].messages.append(message)
    }

    func activeThread() -> ChatThread? {
        chatThreads.first { $0.id == activeThreadId }
    }

    func updateActiveThreadLoadedNotes(ids: Set<String>, titles: [String]) {
        guard let index = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[index].loadedNoteIds = Array(ids).sorted()
        chatThreads[index].loadedNoteTitles = titles
    }

    func updateActiveThreadContextAttachments(_ attachments: [ContextAttachment]) {
        guard let index = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[index].contextAttachments = attachments
    }

    func addActiveThreadContextAttachment(_ attachment: ContextAttachment) {
        guard let index = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        if chatThreads[index].contextAttachments.contains(attachment) { return }
        chatThreads[index].contextAttachments.append(attachment)
    }

    func removeActiveThreadContextAttachment(_ attachmentID: String) {
        guard let index = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[index].contextAttachments.removeAll { $0.id == attachmentID }
    }

    func miniChatSession(id: String) -> ChatThread? {
        chatThreads.first { $0.id == id && $0.type == Self.miniChatThreadType }
    }

    @discardableResult
    func ensureMiniChatSession(
        id: String,
        label: String = "New Chat",
        pageId: String? = nil
    ) -> String {
        if miniChatSession(id: id) != nil {
            return id
        }
        return upsertMiniChatSession(id: id, label: label, pageId: pageId)
    }

    @discardableResult
    func upsertMiniChatSession(
        id: String,
        label: String = "New Chat",
        pageId: String? = nil,
        messages: [AssistantMessage] = [],
        loadedNoteIds: [String] = [],
        loadedNoteTitles: [String] = [],
        contextAttachments: [ContextAttachment] = [],
        createdAt: Date = .now,
        activate: Bool = true
    ) -> String {
        if let index = chatThreads.firstIndex(where: { $0.id == id }) {
            chatThreads[index] = ChatThread(
                id: id,
                type: Self.miniChatThreadType,
                label: label,
                messages: messages,
                pageId: pageId,
                loadedNoteIds: loadedNoteIds,
                loadedNoteTitles: loadedNoteTitles,
                contextAttachments: contextAttachments,
                createdAt: createdAt
            )
            if activate { activeThreadId = id }
            return id
        }

        chatThreads.append(
            ChatThread(
                id: id,
                type: Self.miniChatThreadType,
                label: label,
                messages: messages,
                pageId: pageId,
                loadedNoteIds: loadedNoteIds,
                loadedNoteTitles: loadedNoteTitles,
                contextAttachments: contextAttachments,
                createdAt: createdAt
            )
        )
        if activate { activeThreadId = id }
        return id
    }

    func removeMiniChatSession(id: String) {
        chatThreads.removeAll { $0.id == id && $0.type == Self.miniChatThreadType }
        miniChatStreamingStateByID.removeValue(forKey: id)
        miniChatStreamingTextByID.removeValue(forKey: id)
        miniChatStreamingThinkingByID.removeValue(forKey: id)
        miniChatPendingContentBlocksByID.removeValue(forKey: id)
        miniChatActiveToolNameByID.removeValue(forKey: id)
        miniChatActiveToolInputJsonByID.removeValue(forKey: id)
        normalizeActiveThreadSelection()
    }

    func addMiniChatMessage(_ message: AssistantMessage, chatID: String) {
        let threadID = ensureMiniChatSession(id: chatID)
        addThreadMessage(message, threadId: threadID)
    }

    func updateMiniChatLoadedNotes(ids: Set<String>, titles: [String], chatID: String) {
        let threadID = ensureMiniChatSession(id: chatID)
        guard let index = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        chatThreads[index].loadedNoteIds = Array(ids).sorted()
        chatThreads[index].loadedNoteTitles = titles
    }

    func addMiniChatContextAttachment(_ attachment: ContextAttachment, chatID: String) {
        let threadID = ensureMiniChatSession(id: chatID)
        guard let index = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        if chatThreads[index].contextAttachments.contains(attachment) { return }
        chatThreads[index].contextAttachments.append(attachment)
    }

    func removeMiniChatContextAttachment(_ attachmentID: String, chatID: String) {
        let threadID = ensureMiniChatSession(id: chatID)
        guard let index = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        chatThreads[index].contextAttachments.removeAll { $0.id == attachmentID }
    }

    func miniChatIsStreaming(chatID: String) -> Bool {
        miniChatStreamingStateByID[chatID] ?? false
    }

    func setMiniChatStreaming(_ isStreaming: Bool, chatID: String) {
        miniChatStreamingStateByID[chatID] = isStreaming
    }

    func miniChatStreamingText(chatID: String) -> String {
        miniChatStreamingTextByID[chatID] ?? ""
    }

    func setMiniChatStreamingText(_ text: String, chatID: String) {
        miniChatStreamingTextByID[chatID] = text
    }

    func miniChatStreamingThinking(chatID: String) -> String {
        miniChatStreamingThinkingByID[chatID] ?? ""
    }

    func setMiniChatStreamingThinking(_ text: String, chatID: String) {
        miniChatStreamingThinkingByID[chatID] = text
    }

    func appendMiniChatStreamingThinking(_ delta: String, chatID: String) {
        guard !delta.isEmpty else { return }
        miniChatStreamingThinkingByID[chatID, default: ""].append(delta)
    }

    func clearMiniChatStreamingThinking(chatID: String) {
        miniChatStreamingThinkingByID.removeValue(forKey: chatID)
    }

    func miniChatPendingContentBlocks(chatID: String) -> [MessageContentBlock] {
        miniChatPendingContentBlocksByID[chatID] ?? []
    }

    func setMiniChatPendingContentBlocks(_ blocks: [MessageContentBlock], chatID: String) {
        if blocks.isEmpty {
            miniChatPendingContentBlocksByID.removeValue(forKey: chatID)
        } else {
            miniChatPendingContentBlocksByID[chatID] = blocks
        }
    }

    func miniChatActiveToolName(chatID: String) -> String? {
        miniChatActiveToolNameByID[chatID]
    }

    func miniChatActiveToolInputJson(chatID: String) -> String? {
        miniChatActiveToolInputJsonByID[chatID]
    }

    func setMiniChatActiveTool(name: String?, inputJson: String?, chatID: String) {
        if let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmedName.isEmpty {
            miniChatActiveToolNameByID[chatID] = trimmedName
        } else {
            miniChatActiveToolNameByID.removeValue(forKey: chatID)
        }

        if let trimmedInput = inputJson?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmedInput.isEmpty {
            miniChatActiveToolInputJsonByID[chatID] = trimmedInput
        } else {
            miniChatActiveToolInputJsonByID.removeValue(forKey: chatID)
        }
    }

    private func normalizeActiveThreadSelection() {
        if activeThreadId.isEmpty {
            activeThreadId = chatThreads.last?.id ?? ""
            return
        }
        guard chatThreads.contains(where: { $0.id == activeThreadId }) else {
            activeThreadId = chatThreads.last?.id ?? ""
            return
        }
    }
}
