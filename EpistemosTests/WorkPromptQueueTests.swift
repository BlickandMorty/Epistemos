import Foundation
import Testing
@testable import Epistemos

// Native prompt-queue model (clone-map #5) — mirrors OpenGUI QueuedPrompt/QueueMode/QueueList ops.
@MainActor
@Suite("Work prompt queue — enqueue/dequeue/reorder/mode (OpenGUI queue clone)")
struct WorkPromptQueueTests {
    @Test("enqueue appends in order; dequeue is FIFO")
    func fifo() {
        let q = WorkPromptQueue()
        q.enqueue("a"); q.enqueue("b")
        #expect(q.count == 2)
        #expect(q.dequeue()?.text == "a")
        #expect(q.dequeue()?.text == "b")
        #expect(q.isEmpty)
    }

    @Test("enqueue carries mode + model/agent/variant")
    func carriesOptions() {
        let q = WorkPromptQueue()
        let p = q.enqueue("x", mode: .interrupt, model: "claude-x", agent: "build", variant: "v")
        #expect(p.mode == .interrupt)
        #expect(p.model == "claude-x")
        #expect(p.agent == "build")
        #expect(q.pending.first?.variant == "v")
    }

    @Test("moveToTop / moveToBottom reorder; remove + edit + setMode")
    func reorderEdit() {
        let q = WorkPromptQueue()
        let a = q.enqueue("a"); let b = q.enqueue("b"); let c = q.enqueue("c")
        q.moveToTop(id: c.id)
        #expect(q.pending.map(\.text) == ["c", "a", "b"])
        q.moveToBottom(id: c.id)
        #expect(q.pending.map(\.text) == ["a", "b", "c"])
        q.edit(id: a.id, text: "a2")
        #expect(q.pending.first?.text == "a2")
        q.setMode(id: b.id, .afterPart)
        #expect(q.pending.first(where: { $0.id == b.id })?.mode == .afterPart)
        q.remove(id: a.id)
        #expect(q.pending.map(\.text) == ["b", "c"])
    }

    @Test("interrupt contract: moveToTop + setMode(.interrupt) → prompt is front, interrupt-mode, drains first")
    func interruptOrdering() {
        // Mirrors WorkEngineSurfaceView.handleInterrupt's queue mutation (the part that doesn't need the live
        // supervisor): the interrupted prompt jumps to the front and is tagged .interrupt so the idle-drain sends it next.
        let q = WorkPromptQueue()
        q.enqueue("a"); q.enqueue("b"); let c = q.enqueue("c")
        q.moveToTop(id: c.id)
        q.setMode(id: c.id, .interrupt)
        #expect(q.pending.first?.id == c.id)
        #expect(q.pending.first?.mode == .interrupt)
        #expect(q.dequeue()?.text == "c")           // drainIfIdle pops the now-front interrupt prompt
        #expect(q.pending.map(\.text) == ["a", "b"]) // the rest keep their order
    }

    @Test("takeNow pulls a specific prompt out for immediate send")
    func takeNow() {
        let q = WorkPromptQueue()
        q.enqueue("a"); let b = q.enqueue("b")
        let taken = q.takeNow(id: b.id)
        #expect(taken?.text == "b")
        #expect(q.pending.map(\.text) == ["a"]) // b removed, a remains
    }

    @Test("QueueMode wire mapping round-trips (after-part hyphen)")
    func wireMapping() {
        #expect(WorkQueueMode.afterPart.wireValue == "after-part")
        #expect(WorkQueueMode.queue.wireValue == "queue")
        #expect(WorkQueueMode(wire: "after-part") == .afterPart)
        #expect(WorkQueueMode(wire: "interrupt") == .interrupt)
        #expect(WorkQueueMode(wire: "garbage") == .queue) // lenient default
    }

    #if os(macOS)
    @Test("Tab in the block-caret input stages a queued prompt, not a submit")
    func tabQueuesFromInput() {
        let field = WorkBlockCaretTextView()
        var submitted = false
        var queued = false
        field.onSubmit = { submitted = true }
        field.onQueue = { queued = true }

        field.insertTab(nil)

        #expect(queued)
        #expect(!submitted)
    }
    #endif

    @Test("Work surface wires Tab to the queue-only path while Enter still submits")
    func workSurfaceWiresTabQueueShortcut() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkEngineSurfaceView.swift")
        #expect(src.contains("onSubmit: submit"))
        #expect(src.contains("onQueue: queueInput"))
        #expect(src.contains("private func queueInput()"))
        #expect(src.contains("queue.enqueue(text, model: selectedModelID, agent: selectedAgent)"))
    }

    @Test("queued prompts are requeued at the front if a drained/send-now send fails")
    func queuedPromptSendFailureIsPreserved() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkEngineSurfaceView.swift")
        #expect(src.contains("requeueOnFailure prompt: WorkQueuedPrompt? = nil"))
        #expect(src.contains("queue.enqueue("))
        #expect(src.contains("prompt.text, mode: prompt.mode, model: prompt.model, agent: prompt.agent,"))
        #expect(src.contains("variant: prompt.variant"))
        #expect(src.contains("queue.moveToTop(id: requeued.id)"))
        #expect(src.contains("sendNow(next.text, model: next.model, agent: next.agent, requeueOnFailure: next)"))
        #expect(src.contains("sendNow(prompt.text, model: prompt.model, agent: prompt.agent, requeueOnFailure: prompt)"))
        #expect(src.contains("WorkServerDiagnostics.statusMessage("))
        #expect(!src.contains("error.localizedDescription"))
        #expect(!src.contains("String(describing: error)"))
    }

    @Test("after-part queue mode is exposed and bound to live part-boundary abort/drain")
    func afterPartQueueModeIsWired() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/Work/WorkEngineSurfaceView.swift")
        let queueView = try loadMirroredSourceTextFile("Epistemos/Work/WorkQueueListView.swift")
        #expect(queueView.contains(#"Button("Steer after current part")"#))
        #expect(queueView.contains("onAfterPart(prompt)"))
        #expect(queueView.contains("case .afterPart: return \"steer\""))
        #expect(surface.contains("queue.setMode(id: prompt.id, .afterPart)"))
        #expect(surface.contains(#"eventType == "part.started" || eventType == "message.finished""#))
        #expect(surface.contains("triggerAfterPartIfNeeded(sessionID: sessionID)"))
        #expect(surface.contains("afterPartAbortTriggeredSessionIDs.insert(sessionID)"))
        #expect(surface.contains("abortActiveTurn(sessionID)"))
    }

    @Test("queue rows expose the donor edit affordance")
    func queueRowsExposeEditControl() throws {
        let queueView = try loadMirroredSourceTextFile("Epistemos/Work/WorkQueueListView.swift")
        #expect(queueView.contains(#"Button("Edit")"#))
        #expect(queueView.contains(#"TextField("queued prompt""#))
        #expect(queueView.contains(".onSubmit { commitEdit(id: prompt.id) }"))
        #expect(queueView.contains("queue.edit(id: id, text: trimmed)"))
        #expect(queueView.contains("private func cancelEdit()"))
    }

    @Test("queue toolbar actions use stable compact icon hit areas")
    func queueActionsUseStableIconHitAreas() throws {
        let queueView = try loadMirroredSourceTextFile("Epistemos/Work/WorkQueueListView.swift")
        #expect(queueView.contains(#"Image(systemName: "trash")"#))
        #expect(queueView.contains(#".help("Clear queue")"#))
        #expect(queueView.contains(".frame(width: 18, height: 18)"))
        #expect(!queueView.contains(#"Button("clear")"#))
    }
}
