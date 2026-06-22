import Testing
import Foundation
@testable import Epistemos

/// VAULT-DEEP-INTEGRATION §720 (#4): the editor-agnostic core of in-editor agent edits. Verifies robust
/// text-based application (append/replaceFirst/insertAfter) AND the HONEST contract: anchor-based edits
/// return nil when the anchor is absent — the agent never silently corrupts a note.
@Suite("Agent note edit — robust, honest in-editor edit core")
struct AgentNoteEditTests {
    @Test("append adds a separating newline only when needed")
    func append() {
        #expect(AgentNoteEdit.append("x").apply(to: "") == "x")
        #expect(AgentNoteEdit.append("b").apply(to: "a") == "a\nb")
        #expect(AgentNoteEdit.append("b").apply(to: "a\n") == "a\nb")
    }

    @Test("replaceFirst replaces only the first occurrence; nil when absent (no silent mangle)")
    func replaceFirst() {
        #expect(AgentNoteEdit.replaceFirst(find: "foo", with: "bar").apply(to: "foo and foo") == "bar and foo")
        #expect(AgentNoteEdit.replaceFirst(find: "zzz", with: "bar").apply(to: "foo") == nil)
        #expect(AgentNoteEdit.replaceFirst(find: "", with: "bar").apply(to: "foo") == nil)
    }

    @Test("insertAfter inserts after the anchor (e.g. a heading); nil when the anchor is absent")
    func insertAfter() {
        let out = AgentNoteEdit.insertAfter(anchor: "# Title", text: "body").apply(to: "# Title\nold")
        #expect(out == "# Title\nbody\nold")
        #expect(AgentNoteEdit.insertAfter(anchor: "## Missing", text: "x").apply(to: "# Title") == nil)
    }

    @Test("batch apply is ATOMIC: all edits land, or nil if any fails (no partial corruption)")
    func batchApplyIsAtomic() {
        // All succeed → applied in order.
        let ok = AgentNoteEdit.apply(
            [.replaceFirst(find: "foo", with: "bar"), .append("end")],
            to: "foo")
        #expect(ok == "bar\nend")
        // Second edit's anchor is missing → the WHOLE batch returns nil (the first edit is NOT committed).
        let failed = AgentNoteEdit.apply(
            [.append("ok"), .replaceFirst(find: "absent", with: "x")],
            to: "note")
        #expect(failed == nil)
        // Empty batch is a no-op (returns the input unchanged).
        #expect(AgentNoteEdit.apply([], to: "unchanged") == "unchanged")
    }
}
