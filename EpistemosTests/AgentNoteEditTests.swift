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

    @Test("resolveTextEdit maps an edit to an NSRange TextEdit for the LIVE buffer (reuse the apply path)")
    func resolveTextEdit() {
        // replaceFirst → the range of the find + the replacement.
        let buf = "# Title\nfoo bar"
        let edit = AgentNoteEdit.replaceFirst(find: "foo", with: "BAZ").resolveTextEdit(in: buf)
        #expect(edit?.replacementRange == NSRange(location: 8, length: 3))   // "foo" at UTF-16 offset 8
        #expect(edit?.replacementText == "BAZ")
        // Applying it to the buffer matches apply(to:).
        if let e = edit {
            let applied = (buf as NSString).replacingCharacters(in: e.replacementRange, with: e.replacementText)
            #expect(applied == AgentNoteEdit.replaceFirst(find: "foo", with: "BAZ").apply(to: buf))
        }
        // append → a zero-length range at the end.
        let appendEdit = AgentNoteEdit.append("end").resolveTextEdit(in: "a")
        #expect(appendEdit?.replacementRange == NSRange(location: 1, length: 0))
        #expect(appendEdit?.replacementText == "\nend")
        // Honest: missing anchor → nil (never an out-of-range edit on the live buffer).
        #expect(AgentNoteEdit.replaceFirst(find: "absent", with: "x").resolveTextEdit(in: buf) == nil)
        #expect(AgentNoteEdit.insertAfter(anchor: "## Missing", text: "y").resolveTextEdit(in: buf) == nil)
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
