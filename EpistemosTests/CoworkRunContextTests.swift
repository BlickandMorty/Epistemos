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
}
