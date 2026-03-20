import Foundation
import Observation

// MARK: - Thread State
// Manages MiniChat and palette threads: selection, message appending, streaming.
// Extracted from UIState to keep UI state focused on navigation and chrome.

@MainActor @Observable
final class ThreadState {
    private static let miniChatThreadID = "mini-chat"
    private static let miniChatThreadType = "miniChat"

    // MARK: - Threads

    var chatThreads: [ChatThread] = []
    var activeThreadId: String = ""

    // MARK: - MiniChat Streaming

    /// Streaming state for MiniChat Chat tab — shared so thread view can display the live bubble.
    var miniChatIsStreaming = false
    var miniChatStreamingText = ""

    // MARK: - Palette Streaming

    /// Streaming state for the command palette's inline chat mode.
    var paletteIsStreaming = false
    var paletteStreamingText = ""

    // MARK: - Thread Methods

    @discardableResult
    func ensureMiniChatThread(
        label: String = "Mini Chat",
        pageId: String? = nil
    ) -> String {
        let matches = chatThreads.indices.filter { idx in
            let thread = chatThreads[idx]
            return thread.id == Self.miniChatThreadID || thread.type == Self.miniChatThreadType
        }

        if let keepIndex = matches.first {
            chatThreads[keepIndex].id = Self.miniChatThreadID
            chatThreads[keepIndex].type = Self.miniChatThreadType
            chatThreads[keepIndex].label = label
            if let pageId {
                chatThreads[keepIndex].pageId = pageId
            }

            for index in matches.dropFirst().reversed() {
                let removedID = chatThreads[index].id
                chatThreads.remove(at: index)
                if activeThreadId == removedID {
                    activeThreadId = ""
                }
            }
            normalizeActiveThreadSelection()
            return Self.miniChatThreadID
        }

        chatThreads.append(
            ChatThread(
                id: Self.miniChatThreadID,
                type: Self.miniChatThreadType,
                label: label,
                pageId: pageId
            )
        )
        return Self.miniChatThreadID
    }

    @discardableResult
    func createThread(type: String = "chat", label: String = "Thread", pageId: String? = nil) -> String {
        let thread = ChatThread(type: type, label: label, pageId: pageId)
        chatThreads.append(thread)
        activeThreadId = thread.id
        return thread.id
    }

    func closeThread(_ threadId: String) {
        guard threadId != Self.miniChatThreadID else { return }
        chatThreads.removeAll { $0.id == threadId }
        if activeThreadId == threadId {
            activeThreadId = chatThreads.last?.id ?? ""
        }
    }

    func setActiveThread(_ threadId: String) { activeThreadId = threadId }

    func addThreadMessage(_ message: AssistantMessage, threadId: String? = nil) {
        let tid = threadId ?? activeThreadId
        guard let idx = chatThreads.firstIndex(where: { $0.id == tid }) else { return }
        chatThreads[idx].messages.append(message)
    }

    func addMiniChatMessage(_ message: AssistantMessage) {
        let threadID = ensureMiniChatThread()
        addThreadMessage(message, threadId: threadID)
    }

    func activeThread() -> ChatThread? {
        chatThreads.first { $0.id == activeThreadId }
    }

    func miniChatThread() -> ChatThread? {
        chatThreads.first { $0.id == Self.miniChatThreadID || $0.type == Self.miniChatThreadType }
    }

    func updateActiveThreadLoadedNotes(ids: Set<String>, titles: [String]) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[idx].loadedNoteIds = Array(ids).sorted()
        chatThreads[idx].loadedNoteTitles = titles
    }

    func updateMiniChatLoadedNotes(ids: Set<String>, titles: [String]) {
        let threadID = ensureMiniChatThread()
        guard let idx = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        chatThreads[idx].loadedNoteIds = Array(ids).sorted()
        chatThreads[idx].loadedNoteTitles = titles
    }

    func updateActiveThreadContextAttachments(_ attachments: [ContextAttachment]) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[idx].contextAttachments = attachments
    }

    func addActiveThreadContextAttachment(_ attachment: ContextAttachment) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        if chatThreads[idx].contextAttachments.contains(attachment) { return }
        chatThreads[idx].contextAttachments.append(attachment)
    }

    func addMiniChatContextAttachment(_ attachment: ContextAttachment) {
        let threadID = ensureMiniChatThread()
        guard let idx = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        if chatThreads[idx].contextAttachments.contains(attachment) { return }
        chatThreads[idx].contextAttachments.append(attachment)
    }

    func removeActiveThreadContextAttachment(_ attachmentID: String) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[idx].contextAttachments.removeAll { $0.id == attachmentID }
    }

    func removeMiniChatContextAttachment(_ attachmentID: String) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == Self.miniChatThreadID }) else { return }
        chatThreads[idx].contextAttachments.removeAll { $0.id == attachmentID }
    }

    private func normalizeActiveThreadSelection() {
        if activeThreadId.isEmpty { return }
        guard chatThreads.contains(where: { $0.id == activeThreadId }) else {
            activeThreadId = chatThreads.last?.id ?? ""
            return
        }
    }
}
