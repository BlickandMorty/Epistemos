import Foundation
import Observation

// Native clone of OpenGUI's prompt QUEUE (clone-map #5; owner: "queue/pending prompt behavior"). OpenGUI's runtime
// SDK is deliberately NOT a queue (ADR 0005: send `whileBusy:"fail"|"wait"`), so the queue is an Epistemos-OWNED layer
// on top of the proven send/abort/waitUntilIdle/status seam — matching OpenGUI's QueuedPrompt + QueueMode + QueueList
// behaviors (enqueue, reorder, edit, send-now, remove, per-prompt mode). The DRAIN policy (idle → send next) lives in
// the view/supervisor wiring; this is the pure, testable queue MODEL. @Observable so the native QueueList view binds it.

// Mirrors @opengui/protocol QueueMode "queue" | "interrupt" | "after-part".
enum WorkQueueMode: String, Sendable, Hashable, CaseIterable {
    case queue        // send after the current turn finishes (default)
    case interrupt    // abort the running turn, then send now
    case afterPart    // "steer" — send after the current part

    /// The OpenGUI wire value ("after-part" hyphenated).
    var wireValue: String { self == .afterPart ? "after-part" : rawValue }

    init(wire: String) {
        switch wire {
        case "interrupt": self = .interrupt
        case "after-part", "afterPart": self = .afterPart
        default: self = .queue
        }
    }
}

struct WorkQueuedPrompt: Identifiable, Sendable, Hashable {
    let id: String
    var text: String
    var mode: WorkQueueMode
    var model: String?
    var agent: String?
    var variant: String?
}

@MainActor
@Observable
final class WorkPromptQueue {
    private(set) var pending: [WorkQueuedPrompt] = []
    private var counter = 0

    var isEmpty: Bool { pending.isEmpty }
    var count: Int { pending.count }

    @discardableResult
    func enqueue(_ text: String, mode: WorkQueueMode = .queue,
                 model: String? = nil, agent: String? = nil, variant: String? = nil) -> WorkQueuedPrompt {
        counter += 1
        let prompt = WorkQueuedPrompt(
            id: "q\(counter)", text: text, mode: mode, model: model, agent: agent, variant: variant)
        pending.append(prompt)
        return prompt
    }

    /// Pop the next prompt (front of the queue) — the drain step calls this when the session goes idle.
    func dequeue() -> WorkQueuedPrompt? {
        pending.isEmpty ? nil : pending.removeFirst()
    }

    /// Pull a specific prompt out for immediate send ("send now") — returns it and removes it from the queue.
    func takeNow(id: String) -> WorkQueuedPrompt? {
        guard let index = indexOf(id) else { return nil }
        return pending.remove(at: index)
    }

    func remove(id: String) { pending.removeAll { $0.id == id } }
    func edit(id: String, text: String) { if let index = indexOf(id) { pending[index].text = text } }
    func setMode(id: String, _ mode: WorkQueueMode) { if let index = indexOf(id) { pending[index].mode = mode } }

    func moveToTop(id: String) {
        guard let index = indexOf(id), index > 0 else { return }
        pending.insert(pending.remove(at: index), at: 0)
    }

    func moveToBottom(id: String) {
        guard let index = indexOf(id), index < pending.count - 1 else { return }
        pending.append(pending.remove(at: index))
    }

    func clear() { pending.removeAll() }

    private func indexOf(_ id: String) -> Int? { pending.firstIndex { $0.id == id } }
}
