import Testing
import Foundation
@testable import Epistemos

/// P7.6 — locks the cowork QUEUE state machine: stage one message, auto-submit
/// it exactly once on the run-completion edge, never double-send.
@Suite("Composer message queue")
struct ComposerMessageQueueTests {

    @Test("enqueue stores a trimmed message; empty/whitespace is ignored")
    func enqueueTrimsAndIgnoresEmpty() {
        var q = ComposerMessageQueue()
        #expect(!q.hasPending)
        q.enqueue("  hello  ")
        #expect(q.pending == "hello")
        #expect(q.hasPending)
        q.enqueue("   ")
        #expect(!q.hasPending)  // empty replaces/clears
    }

    @Test("dequeue fires once on the processing true→false edge, then is empty")
    func dequeueOnCompletionEdge() {
        var q = ComposerMessageQueue()
        q.enqueue("follow up")
        // Still processing → nothing.
        #expect(q.dequeueOnCompletion(wasProcessing: true, isProcessing: true) == nil)
        #expect(q.hasPending)
        // Completion edge → the message, then empty.
        #expect(q.dequeueOnCompletion(wasProcessing: true, isProcessing: false) == "follow up")
        #expect(!q.hasPending)
        // A second completion edge does NOT re-send.
        #expect(q.dequeueOnCompletion(wasProcessing: true, isProcessing: false) == nil)
    }

    @Test("no edge / no pending → nil")
    func dequeueNoOp() {
        var q = ComposerMessageQueue()
        #expect(q.dequeueOnCompletion(wasProcessing: true, isProcessing: false) == nil)  // nothing queued
        q.enqueue("x")
        // Not a completion edge (started processing) → nil, still pending.
        #expect(q.dequeueOnCompletion(wasProcessing: false, isProcessing: true) == nil)
        #expect(q.hasPending)
    }

    @Test("clear empties the queue")
    func clearEmpties() {
        var q = ComposerMessageQueue()
        q.enqueue("x")
        q.clear()
        #expect(!q.hasPending)
    }

}
