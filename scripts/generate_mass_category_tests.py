#!/usr/bin/env python3
from pathlib import Path

COUNT_PER_SUITE = 1000
TARGET = Path("EpistemosTests/SOARTests.swift")
START = "// BEGIN MASS GENERATED TESTS"
END = "// END MASS GENERATED TESTS"

snippet = f'''
{START}
@Suite("Mass Generated Notes - TOC 1000")
struct MassGeneratedNotesTOC1000Tests {{
    @Test("mass generated notes TOC case", arguments: Array(0..<{COUNT_PER_SUITE}))
    func massGeneratedTOC(_ i: Int) {{
        let level = (i % 5) + 1
        let heading = String(repeating: "#", count: level)
        let markdown = """
        \\(heading) Heading \\(i)
        > This is citation snippet number \\(i) with enough context to qualify.
        [Source \\(i)](https://example.com/source/\\(i))
        """

        let items = TOCParser.parse(markdown)
        #expect(items.count >= 3)
        #expect(items.contains {{ $0.kind == .heading }})
        #expect(items.contains {{ $0.kind == .citation }})
        #expect(items.contains {{ $0.kind == .source }})
    }}
}}

@Suite("Mass Generated Notes - LineDiff 1000")
struct MassGeneratedNotesLineDiff1000Tests {{
    @Test("mass generated notes line diff case", arguments: Array(0..<{COUNT_PER_SUITE}))
    func massGeneratedLineDiff(_ i: Int) {{
        let old = "alpha \\(i)\\ncommon line\\nshared"
        let new = "alpha \\(i) updated\\ncommon line\\nshared\\nextra \\(i)"

        let diff = LineDiff.compute(old: old, new: new)
        #expect(diff.lines.count >= 3)
        #expect(diff.stats.added + diff.stats.removed + diff.stats.modified <= diff.lines.count)

        let sections = diff.sectioned(contextLines: i % 4)
        #expect(!sections.isEmpty)
    }}
}}

@Suite("Mass Generated Chat - QueryParser 1000")
struct MassGeneratedChatQueryParser1000Tests {{
    @Test("mass generated chat parser routing case", arguments: Array(0..<{COUNT_PER_SUITE}))
    func massGeneratedQueryParserRouting(_ i: Int) {{
        switch i % 5 {{
        case 0:
            let q = "find topic \\(i)"
            let parsed = QueryParser.parse(q)
            switch parsed {{
            case .contentSearch(let query, _):
                #expect(query.contains("topic \\(i)"))
            default:
                Issue.record("Expected content search for case \\(i)")
            }}

        case 1:
            let parsed = QueryParser.parse("all notes")
            switch parsed {{
            case .findNodes(let filter):
                #expect(filter.types?.contains(.note) == true)
            default:
                Issue.record("Expected findNodes(.note) for case \\(i)")
            }}

        case 2:
            let parsed = QueryParser.parse("how many notes")
            switch parsed {{
            case .aggregation(let agg):
                let isCountByType: Bool
                if case .countByType = agg {{
                    isCountByType = true
                }} else {{
                    isCountByType = false
                }}
                #expect(isCountByType)
            default:
                Issue.record("Expected aggregation for case \\(i)")
            }}

        case 3:
            let parsed = QueryParser.parse("path from alpha\\(i) to beta\\(i)")
            switch parsed {{
            case .pathBetween(from: let from, to: let to, maxHops: let hops):
                #expect(hops == 6)
                if case .label(let fromLabel) = from {{
                    #expect(fromLabel.contains("alpha\\(i)"))
                }} else {{
                    Issue.record("Expected from NodeRef.label for case \\(i)")
                }}
                if case .label(let toLabel) = to {{
                    #expect(toLabel.contains("beta\\(i)"))
                }} else {{
                    Issue.record("Expected to NodeRef.label for case \\(i)")
                }}
            default:
                Issue.record("Expected pathBetween for case \\(i)")
            }}

        default:
            let parsed = QueryParser.parse("similar to topic \\(i)")
            switch parsed {{
            case .semanticSearch(let query, let limit):
                #expect(query.contains("topic \\(i)"))
                #expect(limit == 10)
            default:
                Issue.record("Expected semanticSearch for case \\(i)")
            }}
        }}
    }}
}}

@Suite("Mass Generated Chat - NoteChatState 1000")
@MainActor
struct MassGeneratedChatNoteState1000Tests {{
    @Test("mass generated note chat state lifecycle case", arguments: Array(0..<{COUNT_PER_SUITE}))
    func massGeneratedNoteChatStateLifecycle(_ i: Int) {{
        let state = NoteChatState(pageId: "mass-generated-page-\\(i)")

        state.isStreaming = true
        state.hasResponse = true
        state.appendStreamingText("token-\\(i)")
        state.stopStreaming()

        #expect(!state.isStreaming)
        #expect(state.responseText.contains("token-\\(i)"))

        state.acceptResponse()
        #expect(!state.hasResponse)
        #expect(state.responseText.isEmpty)

        state.clear()
        #expect(state.inputText.isEmpty)
        #expect(state.error == nil)
    }}
}}

@Suite("Mass Generated Library - Writer Style 1000")
struct MassGeneratedLibraryWriterStyle1000Tests {{
    @Test("mass generated writer style case", arguments: Array(0..<{COUNT_PER_SUITE}))
    func massGeneratedWriterStyle(_ i: Int) {{
        let style = AcademicStyle.allCases[i % AcademicStyle.allCases.count]
        #expect(!style.displayName.isEmpty)

        if style == .custom {{
            #expect(style.presetValues == nil)
        }} else {{
            #expect(style.presetValues != nil)
        }}

        let spacing = LineSpacing.allCases[i % LineSpacing.allCases.count]
        #expect(spacing.multiplier >= 1.0)

        let margins = PageMargins.allCases[i % PageMargins.allCases.count]
        #expect(margins.points > 0)

        let size = PageSize.allCases[i % PageSize.allCases.count].size
        #expect(size.width > 0)
        #expect(size.height > 0)
    }}
}}
{END}
'''

text = TARGET.read_text()
if START in text and END in text:
    before = text.split(START)[0].rstrip()
    after = text.split(END)[1].lstrip()
    new_text = before + "\n\n" + snippet.strip() + "\n\n" + after
else:
    new_text = text.rstrip() + "\n\n" + snippet.strip() + "\n"

TARGET.write_text(new_text)
print(f"Injected {COUNT_PER_SUITE * 5} parameterized tests into {TARGET}.")
