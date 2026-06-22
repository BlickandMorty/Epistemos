import Testing
import Foundation
@testable import Epistemos

/// VAULT-DEEP-INTEGRATION §720 (#4): file-level agent note editing. Verifies the HONEST + ATOMIC contract —
/// writes only on full success, writes NOTHING when the atomic batch fails (missing anchor), and propagates
/// read/write errors. Injectable read/write so no filesystem is touched.
@Suite("Vault note editor — atomic, honest file-level agent edits")
struct VaultNoteEditorTests {
    private nonisolated final class Box: @unchecked Sendable {
        var stored: String
        var writeCount = 0
        init(_ s: String) { stored = s }
    }

    private func editor(_ box: Box, readError: Error? = nil) -> VaultNoteEditor {
        VaultNoteEditor(
            read: { _ in if let readError { throw readError }; return box.stored },
            write: { _, content in box.stored = content; box.writeCount += 1 }
        )
    }

    private let url = URL(fileURLWithPath: "/tmp/note.md")

    @Test("successful batch writes the new content once")
    func successWrites() throws {
        let box = Box("foo")
        let result = try editor(box).applyEdits([.replaceFirst(find: "foo", with: "bar"), .append("end")], to: url)
        #expect(result == "bar\nend")
        #expect(box.stored == "bar\nend")
        #expect(box.writeCount == 1)
    }

    @Test("a failing batch throws editDidNotApply and writes NOTHING (no partial corruption)")
    func atomicFailureWritesNothing() {
        let box = Box("note")
        #expect(throws: VaultNoteEditError.editDidNotApply) {
            try editor(box).applyEdits([.append("ok"), .replaceFirst(find: "absent", with: "x")], to: url)
        }
        #expect(box.stored == "note")   // unchanged
        #expect(box.writeCount == 0)    // never wrote
    }

    @Test("read errors propagate (nothing written)")
    func readErrorPropagates() {
        struct E: Error {}
        let box = Box("x")
        #expect(throws: (any Error).self) {
            try editor(box, readError: E()).applyEdits([.append("y")], to: url)
        }
        #expect(box.writeCount == 0)
    }
}
