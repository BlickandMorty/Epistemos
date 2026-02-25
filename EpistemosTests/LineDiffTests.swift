import Testing
@testable import Epistemos

@Suite("LineDiff")
@MainActor
struct LineDiffTests {

    @Test("identical strings produce no changes")
    func identicalStrings() {
        let diff = LineDiff.compute(old: "hello\nworld", new: "hello\nworld")
        #expect(diff.stats.added == 0)
        #expect(diff.stats.removed == 0)
        #expect(diff.stats.modified == 0)
        #expect(diff.lines.count == 2)
    }

    @Test("added line detected")
    func addedLine() {
        let diff = LineDiff.compute(old: "line1", new: "line1\nline2")
        #expect(diff.stats.added == 1)
        #expect(diff.stats.removed == 0)
    }

    @Test("removed line detected")
    func removedLine() {
        let diff = LineDiff.compute(old: "line1\nline2", new: "line1")
        #expect(diff.stats.removed == 1)
        #expect(diff.stats.added == 0)
    }

    @Test("modified line detected when similar")
    func modifiedLine() {
        let diff = LineDiff.compute(
            old: "the quick brown fox",
            new: "the quick red fox"
        )
        #expect(diff.stats.modified == 1)
    }

    @Test("empty strings produce empty diff")
    func emptyStrings() {
        let diff = LineDiff.compute(old: "", new: "")
        #expect(diff.lines.count == 1)
        #expect(diff.stats.added == 0)
        #expect(diff.stats.removed == 0)
    }

    @Test("completely different strings are removals + additions")
    func completelyDifferent() {
        let diff = LineDiff.compute(old: "aaa\nbbb", new: "xxx\nyyy")
        let totalChanges = diff.stats.added + diff.stats.removed + diff.stats.modified
        let changedLines = diff.lines.filter {
            if case .unchanged = $0 { return false }
            return true
        }.count
        #expect(totalChanges == changedLines)
    }

    @Test("word-level diffs identify changed words")
    func wordDiffs() {
        let (removed, added) = LineDiff.wordDiffs(
            old: "the quick brown fox",
            new: "the quick red fox"
        )
        #expect(!removed.isEmpty)
        #expect(!added.isEmpty)
    }

    @Test("sectioned groups changes with context lines")
    func sectioning() {
        let oldLines = (0..<21).map { "line \($0)" }
        var newLines = oldLines
        newLines[10] = "CHANGED line 10"
        let diff = LineDiff.compute(
            old: oldLines.joined(separator: "\n"),
            new: newLines.joined(separator: "\n")
        )
        let sections = diff.sectioned(contextLines: 2)
        // With a change at line 10 and context=2, we expect at least:
        // collapsed (0-7), visible (8-12), collapsed (13-20)
        #expect(sections.count >= 2)
    }

    @Test("chunkStartIndices finds contiguous change blocks")
    func chunkStarts() {
        let diff = LineDiff.compute(
            old: "a\nb\nc\nd\ne",
            new: "a\nB\nC\nd\nE"
        )
        let chunks = diff.chunkStartIndices
        // Two contiguous change blocks: (B,C) and (E)
        #expect(chunks.count == 2)
    }

    @Test("multiple added lines counted correctly")
    func multipleAdded() {
        let diff = LineDiff.compute(old: "a", new: "a\nb\nc\nd")
        #expect(diff.stats.added == 3)
        #expect(diff.stats.removed == 0)
        #expect(diff.stats.modified == 0)
    }

    @Test("multiple removed lines counted correctly")
    func multipleRemoved() {
        let diff = LineDiff.compute(old: "a\nb\nc\nd", new: "a")
        #expect(diff.stats.removed == 3)
        #expect(diff.stats.added == 0)
    }

    @Test("word diffs on identical strings produce no changes")
    func wordDiffsIdentical() {
        let (removed, added) = LineDiff.wordDiffs(
            old: "hello world",
            new: "hello world"
        )
        #expect(removed.isEmpty)
        #expect(added.isEmpty)
    }

    @Test("sectioned with no changes returns single visible section")
    func sectionedNoChanges() {
        let diff = LineDiff.compute(old: "a\nb\nc", new: "a\nb\nc")
        let sections = diff.sectioned(contextLines: 1)
        #expect(sections.count == 1)
    }

    @Test("chunkStartIndices on unchanged diff returns empty")
    func chunkStartsNoChanges() {
        let diff = LineDiff.compute(old: "a\nb\nc", new: "a\nb\nc")
        #expect(diff.chunkStartIndices.isEmpty)
    }
}
