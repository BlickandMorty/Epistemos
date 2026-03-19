import Foundation
import Observation

// MARK: - Thread State
// Manages MiniChat threads: creation, selection, message appending, streaming.
// Extracted from UIState to keep UI state focused on navigation and chrome.

@MainActor @Observable
final class ThreadState {
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
    func createThread(type: String = "chat", label: String = "Thread", pageId: String? = nil) -> String {
        let thread = ChatThread(type: type, label: label, pageId: pageId)
        chatThreads.append(thread)
        activeThreadId = thread.id
        return thread.id
    }

    func closeThread(_ threadId: String) {
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

    func activeThread() -> ChatThread? {
        chatThreads.first { $0.id == activeThreadId }
    }

    func updateActiveThreadLoadedNotes(ids: Set<String>, titles: [String]) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
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

    func removeActiveThreadContextAttachment(_ attachmentID: String) {
        guard let idx = chatThreads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        chatThreads[idx].contextAttachments.removeAll { $0.id == attachmentID }
    }
}
