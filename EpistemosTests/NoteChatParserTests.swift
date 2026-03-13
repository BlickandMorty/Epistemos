import Foundation
import Testing
@testable import Epistemos

private func hasKind(_ items: [TOCItem], _ kind: TOCItem.TOCKind) -> Bool {
    items.contains { $0.kind == kind }
}

@Suite("Generated Notes - TOC 1000")
struct GeneratedNotesTOC1000Tests {
    @Test("generated notes TOC case", arguments: Array(0..<1000))
    func generatedTOC(_ i: Int) {
        let level = (i % 5) + 1
        let heading = String(repeating: "#", count: level)
        let markdown = """
        \(heading) Heading \(i)
        > This is citation snippet number \(i) with enough context to qualify.
        [Source \(i)](https://example.com/source/\(i))
        """

        let items = TOCParser.parse(markdown)
        #expect(items.count >= 3)
        #expect(hasKind(items, .heading))
        #expect(hasKind(items, .citation))
        #expect(hasKind(items, .source))
    }
}

@Suite("Generated Notes - LineDiff 1000")
struct GeneratedNotesLineDiff1000Tests {
    @Test("generated notes line diff case", arguments: Array(0..<1000))
    func generatedLineDiff(_ i: Int) {
        let old = "alpha \(i)\ncommon line\nshared"
        let new = "alpha \(i) updated\ncommon line\nshared\nextra \(i)"

        let diff = LineDiff.compute(old: old, new: new)
        #expect(diff.lines.count >= 3)
        #expect(diff.stats.added + diff.stats.removed + diff.stats.modified <= diff.lines.count)

        let sections = diff.sectioned(contextLines: i % 4)
        #expect(!sections.isEmpty)
    }
}

@Suite("Generated Chat - QueryParser 1000")
struct GeneratedChatQueryParser1000Tests {
    @Test("generated chat parser routing case", arguments: Array(0..<1000))
    func generatedQueryParserRouting(_ i: Int) {
        switch i % 5 {
        case 0:
            let q = "find topic \(i)"
            let parsed = QueryParser.parseToAST(q)
            if case .ftsMatch(let query, _) = parsed {
                #expect(query.contains("topic \(i)"))
            } else {
                Issue.record("Expected ftsMatch for case \(i)")
            }

        case 1:
            let parsed = QueryParser.parseToAST("all notes")
            if case .typeFilter(let types) = parsed {
                #expect(types.contains(.note))
            } else {
                Issue.record("Expected typeFilter(.note) for case \(i)")
            }

        case 2:
            let parsed = QueryParser.parseToAST("how many notes")
            // No aggregation in QueryAST — falls through to FTS
            if case .ftsMatch = parsed {
                #expect(Bool(true))
            } else {
                Issue.record("Expected ftsMatch fallback for case \(i)")
            }

        case 3:
            let parsed = QueryParser.parseToAST("path from alpha\(i) to beta\(i)")
            if case .graphPath(from: let from, to: let to, maxHops: let hops) = parsed {
                #expect(hops == 6)
                if case .label(let fromLabel) = from {
                    #expect(fromLabel.contains("alpha\(i)"))
                } else {
                    Issue.record("Expected from NodeRef.label for case \(i)")
                }
                if case .label(let toLabel) = to {
                    #expect(toLabel.contains("beta\(i)"))
                } else {
                    Issue.record("Expected to NodeRef.label for case \(i)")
                }
            } else {
                Issue.record("Expected graphPath for case \(i)")
            }

        default:
            let parsed = QueryParser.parseToAST("similar to topic \(i)")
            if case .semanticSimilar(let query, _, let limit) = parsed {
                #expect(query.contains("topic \(i)"))
                #expect(limit == 10)
            } else {
                Issue.record("Expected semanticSimilar for case \(i)")
            }
        }
    }
}

@Suite("Generated Chat - NoteChatState 1000")
@MainActor
struct GeneratedChatNoteState1000Tests {
    @Test("generated note chat state lifecycle case", arguments: Array(0..<1000))
    func generatedNoteChatStateLifecycle(_ i: Int) {
        let state = NoteChatState(pageId: "generated-page-\(i)")

        state.isStreaming = true
        state.hasResponse = true
        state.appendStreamingText("token-\(i)")
        state.stopStreaming()

        #expect(!state.isStreaming)
        #expect(state.responseText.contains("token-\(i)"))

        state.acceptResponse()
        #expect(!state.hasResponse)
        #expect(state.responseText.isEmpty)

        state.clear()
        #expect(state.inputText.isEmpty)
        #expect(state.error == nil)
    }
}
