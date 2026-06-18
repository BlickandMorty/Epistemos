import Testing
@testable import Epistemos

/// P7.6 — locks the cowork CONTEXT extraction: it must read the REAL tool-use
/// content blocks the runtime records (deduped, in order) and build an honest
/// summary, never invent activity.
@Suite("Cowork run context")
struct CoworkRunContextTests {

    @Test("tool names are the distinct .toolUse blocks, in first-use order")
    func toolNamesUsedDedupesInOrder() {
        let blocks: [MessageContentBlock] = [
            .text("thinking"),
            .toolUse(id: "1", name: "vault.search", input: [:]),
            .toolResult(toolUseId: "1", content: "{}", isError: false),
            .toolUse(id: "2", name: "vault.read", input: [:]),
            .toolUse(id: "3", name: "vault.search", input: [:]),  // duplicate
            .text("answer"),
        ]
        #expect(CoworkRunContext.toolNamesUsed(in: blocks) == ["vault.search", "vault.read"])
    }

    @Test("no blocks / no tool blocks → empty")
    func toolNamesEmptyWhenNone() {
        #expect(CoworkRunContext.toolNamesUsed(in: nil).isEmpty)
        #expect(CoworkRunContext.toolNamesUsed(in: [.text("hi")]).isEmpty)
    }

    @Test("summary names tools + note count; nil when nothing used (panel hides)")
    func summaryComposesHonestly() {
        #expect(CoworkRunContext.summary(toolNames: [], noteTitles: []) == nil)
        #expect(CoworkRunContext.summary(toolNames: ["vault.search"], noteTitles: []) == "Tools: vault.search")
        #expect(CoworkRunContext.summary(toolNames: [], noteTitles: ["A"]) == "1 note")
        #expect(CoworkRunContext.summary(toolNames: [], noteTitles: ["A", "B"]) == "2 notes")
        #expect(
            CoworkRunContext.summary(toolNames: ["vault.search", "vault.read"], noteTitles: ["A", "B"])
                == "Tools: vault.search, vault.read · 2 notes"
        )
    }

    // MARK: - WORKING-FOLDER

    @Test("filesTouched reads only mutating file ops, deduped, first-touch order")
    func filesTouchedMutatingOnly() {
        let blocks: [MessageContentBlock] = [
            // read-only ops are NOT mutations → excluded
            .toolUse(id: "r1", name: "file_ops", input: ["action": .string("read"), "path": .string("/v/a.md")]),
            .toolUse(id: "s1", name: "vault.search", input: ["query": .string("x")]),
            // mutations
            .toolUse(id: "w1", name: "file_ops", input: ["action": .string("write"), "path": .string("/v/notes/b.md")]),
            .toolUse(id: "p1", name: "file.patch", input: ["path": .string("/v/notes/c.md")]),
            // a later action on the same path wins, order preserved by first touch
            .toolUse(id: "p2", name: "file_ops", input: ["action": .string("patch"), "path": .string("/v/notes/b.md")]),
        ]
        let touched = CoworkRunContext.filesTouched(in: blocks)
        #expect(touched.map(\.path) == ["/v/notes/b.md", "/v/notes/c.md"])
        #expect(touched.first?.action == .patch)  // patch supersedes the earlier write
        #expect(touched.first?.fileName == "b.md")
        #expect(touched.last?.action == .patch)
    }

    @Test("aliased + dotted mutation names all map; delete/move recognized")
    func filesTouchedNameAliases() {
        let blocks: [MessageContentBlock] = [
            .toolUse(id: "1", name: "write_file", input: ["path": .string("/w/x.txt")]),
            .toolUse(id: "2", name: "delete_file", input: ["file_path": .string("/w/y.txt")]),
            .toolUse(id: "3", name: "file.move", input: ["path": .string("/w/z.txt")]),
            .toolUse(id: "4", name: "edit_file", input: ["target": .string("/w/q.txt")]),
        ]
        let touched = CoworkRunContext.filesTouched(in: blocks)
        #expect(touched.count == 4)
        #expect(touched[0].action == .write)
        #expect(touched[1].action == .delete)
        #expect(touched[2].action == .move)
        #expect(touched[3].action == .patch)  // edit_file → patch
    }

    @Test("no mutations (read-only run) → empty, panel hides")
    func filesTouchedEmptyWhenReadOnly() {
        #expect(CoworkRunContext.filesTouched(in: nil).isEmpty)
        let readOnly: [MessageContentBlock] = [
            .toolUse(id: "1", name: "file_ops", input: ["action": .string("read"), "path": .string("/a")]),
            .toolUse(id: "2", name: "file_ops", input: ["action": .string("list"), "path": .string("/a")]),
            .toolUse(id: "3", name: "file.read", input: ["path": .string("/a")]),
            .text("answer"),
        ]
        #expect(CoworkRunContext.filesTouched(in: readOnly).isEmpty)
    }

    @Test("missing/empty path is skipped (honest — no phantom files)")
    func filesTouchedSkipsMissingPath() {
        let blocks: [MessageContentBlock] = [
            .toolUse(id: "1", name: "file_ops", input: ["action": .string("write")]),  // no path
            .toolUse(id: "2", name: "file_ops", input: ["action": .string("write"), "path": .string("   ")]),  // blank
            .toolUse(id: "3", name: "file_ops", input: ["action": .string("write"), "path": .string("/ok.md")]),
        ]
        #expect(CoworkRunContext.filesTouched(in: blocks).map(\.path) == ["/ok.md"])
    }

    @Test("workingFolder is the common parent directory of touched files")
    func workingFolderCommonParent() {
        let files = [
            CoworkRunContext.TouchedFile(path: "/v/notes/a/x.md", action: .write),
            CoworkRunContext.TouchedFile(path: "/v/notes/b/y.md", action: .patch),
        ]
        #expect(CoworkRunContext.workingFolder(for: files) == "/v/notes")
        // single file → its own directory
        #expect(
            CoworkRunContext.workingFolder(for: [
                CoworkRunContext.TouchedFile(path: "/v/notes/only.md", action: .write)
            ]) == "/v/notes"
        )
        // no files → nil (panel hides)
        #expect(CoworkRunContext.workingFolder(for: []) == nil)
    }
}
