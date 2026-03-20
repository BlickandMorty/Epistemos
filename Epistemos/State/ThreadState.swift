import Foundation
import Observation

// MARK: - Thread State
// Manages MiniChat and palette threads: selection, message appending, streaming.
// Extracted from UIState to keep UI state focused on navigation and chrome.

@MainActor @Observable
final class ThreadState {
    private static let miniChatThreadID = "mini-chat"
    private static let miniChatThreadType = "miniChat"
    private static let paletteThreadID = "palette-chat"
    private static let paletteThreadType = "palette"

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
        ensureDedicatedThread(
            id: Self.miniChatThreadID,
            type: Self.miniChatThreadType,
            label: label,
            pageId: pageId
        )
    }

    @discardableResult
    func ensurePaletteThread(
        label: String = "Chat",
        pageId: String? = nil
    ) -> String {
        ensureDedicatedThread(
            id: Self.paletteThreadID,
            type: Self.paletteThreadType,
            label: label,
            pageId: pageId
        )
    }

    @discardableResult
    func createThread(type: String = "chat", label: String = "Thread", pageId: String? = nil) -> String {
        let thread = ChatThread(type: type, label: label, pageId: pageId)
        chatThreads.append(thread)
        activeThreadId = thread.id
        return thread.id
    }

    func closeThread(_ threadId: String) {
        guard threadId != Self.miniChatThreadID, threadId != Self.paletteThreadID else { return }
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

    func addPaletteMessage(_ message: AssistantMessage) {
        let threadID = ensurePaletteThread()
        addThreadMessage(message, threadId: threadID)
    }

    func activeThread() -> ChatThread? {
        chatThreads.first { $0.id == activeThreadId }
    }

    func miniChatThread() -> ChatThread? {
        chatThreads.first { $0.id == Self.miniChatThreadID || $0.type == Self.miniChatThreadType }
    }

    func paletteThread() -> ChatThread? {
        chatThreads.first { $0.id == Self.paletteThreadID || $0.type == Self.paletteThreadType }
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

    func updatePaletteLoadedNotes(ids: Set<String>, titles: [String]) {
        let threadID = ensurePaletteThread()
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

    func addPaletteContextAttachment(_ attachment: ContextAttachment) {
        let threadID = ensurePaletteThread()
        guard let idx = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        if chatThreads[idx].contextAttachments.contains(attachment) { return }
        chatThreads[idx].contextAttachments.append(attachment)
    }

    func removeActiveThreadContextAttachment(_ attachmentID: String) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[idx].contextAttachments.removeAll { $0.id == attachmentID }
    }

    func removeMiniChatContextAttachment(_ attachmentID: String) {
        let threadID = ensureMiniChatThread()
        guard let idx = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        chatThreads[idx].contextAttachments.removeAll { $0.id == attachmentID }
    }

    func removePaletteContextAttachment(_ attachmentID: String) {
        let threadID = ensurePaletteThread()
        guard let idx = chatThreads.firstIndex(where: { $0.id == threadID }) else { return }
        chatThreads[idx].contextAttachments.removeAll { $0.id == attachmentID }
    }

    private func normalizeActiveThreadSelection() {
        if activeThreadId.isEmpty { return }
        guard chatThreads.contains(where: { $0.id == activeThreadId }) else {
            activeThreadId = chatThreads.last?.id ?? ""
            return
        }
    }

    @discardableResult
    private func ensureDedicatedThread(
        id: String,
        type: String,
        label: String,
        pageId: String?
    ) -> String {
        let matches = chatThreads.indices.filter { idx in
            let thread = chatThreads[idx]
            return thread.id == id || thread.type == type
        }

        if let keepIndex = matches.first {
            chatThreads[keepIndex].id = id
            chatThreads[keepIndex].type = type
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
            return id
        }

        chatThreads.append(
            ChatThread(
                id: id,
                type: type,
                label: label,
                pageId: pageId
            )
        )
        return id
    }
}
