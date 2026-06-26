import Foundation
import Observation

@MainActor @Observable
final class ThreadState {
    var chatThreads: [ChatThread] = []
    var activeThreadId: String = ""

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
