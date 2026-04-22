import Testing
@testable import Epistemos

@Suite("NoteLineDiff — Pass 12 Myers line-diff engine")
struct NoteLineDiffTests {

    @Test("identical input has zero changes and no hunks")
    func identical() {
        let result = NoteLineDiff.summarize(
            oldText: "alpha\nbeta\ngamma",
            newText: "alpha\nbeta\ngamma"
        )
        #expect(result.addedLines == 0)
        #expect(result.removedLines == 0)
        #expect(result.hunks.isEmpty)
        #expect(result.isUnchanged)
        #expect(result.oldChecksum == result.newChecksum)
    }

    @Test("single-line insertion reports one added line and one hunk")
    func singleInsertion() {
        let result = NoteLineDiff.summarize(
            oldText: "alpha\ngamma",
            newText: "alpha\nbeta\ngamma"
        )
        #expect(result.addedLines == 1)
        #expect(result.removedLines == 0)
        #expect(result.hunks.count == 1)
        #expect(result.hunks.first?.lines.contains { $0.kind == .insertion && $0.text == "beta" } == true)
    }

    @Test("single-line deletion reports one removed line")
    func singleDeletion() {
        let result = NoteLineDiff.summarize(
            oldText: "alpha\nbeta\ngamma",
            newText: "alpha\ngamma"
        )
        #expect(result.addedLines == 0)
        #expect(result.removedLines == 1)
        #expect(result.hunks.count == 1)
        #expect(result.hunks.first?.lines.contains { $0.kind == .deletion && $0.text == "beta" } == true)
    }

    @Test("pure rewrite reports matching insert + delete counts")
    func pureRewrite() {
        let result = NoteLineDiff.summarize(
            oldText: "alpha\nbeta",
            newText: "delta\nepsilon"
        )
        #expect(result.addedLines == 2)
        #expect(result.removedLines == 2)
    }

    @Test("empty to populated returns all lines as insertions")
    func emptyToPopulated() {
        let result = NoteLineDiff.summarize(oldText: "", newText: "one\ntwo")
        #expect(result.addedLines == 2)
        #expect(result.removedLines == 0)
    }

    @Test("populated to empty returns all lines as deletions")
    func populatedToEmpty() {
        let result = NoteLineDiff.summarize(oldText: "one\ntwo", newText: "")
        #expect(result.addedLines == 0)
        #expect(result.removedLines == 2)
    }

    @Test("hunks carry correct 1-based line numbers")
    func lineNumbers() {
        let result = NoteLineDiff.summarize(
            oldText: "a\nb\nc",
            newText: "a\nB\nc"
        )
        #expect(result.hunks.count == 1)
        let hunk = result.hunks[0]
        let deletions = hunk.lines.filter { $0.kind == .deletion }
        let insertions = hunk.lines.filter { $0.kind == .insertion }
        #expect(deletions.count == 1)
        #expect(insertions.count == 1)
        #expect(deletions.first?.oldLineNumber == 2)
        #expect(insertions.first?.newLineNumber == 2)
    }

    @Test("checksum differs whenever content differs, matches on identical input")
    func checksumBehaviour() {
        let a = NoteLineDiff.summarize(oldText: "foo", newText: "foo")
        #expect(a.oldChecksum == a.newChecksum)

        let b = NoteLineDiff.summarize(oldText: "foo", newText: "bar")
        #expect(b.oldChecksum != b.newChecksum)
    }
}
