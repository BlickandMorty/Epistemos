import Testing
@testable import Epistemos

@Suite("Query Parser Visibility")
struct QueryParserVisibilityTests {
    @Test("natural language parser does not expose disabled source or quote node filters")
    func naturalLanguageParserDoesNotExposeDisabledNodeFilters() {
        let sourceAST = QueryParser.parseToAST("all sources")
        let quoteAST = QueryParser.parseToAST("all quotes")

        if case .typeFilter(let types) = sourceAST {
            #expect(!types.contains(.source))
        }

        if case .typeFilter(let types) = quoteAST {
            #expect(!types.contains(.quote))
        }
    }

    @Test("structured parser rejects disabled source or quote node filters")
    func structuredParserRejectsDisabledNodeFilters() {
        #expect(StructuredQueryParser.parse("?type=source") == nil)
        #expect(StructuredQueryParser.parse("?type=quote") == nil)
    }

    @Test("enabled node filters still parse normally")
    func enabledNodeFiltersStillParse() {
        let naturalAST = QueryParser.parseToAST("all notes")
        let structuredAST = StructuredQueryParser.parse("?type=note")

        guard case .typeFilter(let naturalTypes)? = naturalAST else {
            Issue.record("Expected natural-language note query to produce a type filter")
            return
        }
        #expect(naturalTypes == [.note])

        guard case .typeFilter(let structuredTypes)? = structuredAST else {
            Issue.record("Expected structured note query to produce a type filter")
            return
        }
        #expect(structuredTypes == [.note])
    }

    // RCA13 P2-004: grammar docs claimed `|` (OR) and `( ... )`
    // grouping worked. Pre-fix, the parser only split on `&` at the
    // top level. These tests lock the actual parsing in.

    @Test("structured parser splits on | at the top level (OR)")
    func structuredParserSplitsOnOR() {
        let ast = StructuredQueryParser.parse("?type=note | type=idea")
        guard case .or(let branches)? = ast else {
            Issue.record("Expected .or for `type=note | type=idea`")
            return
        }
        #expect(branches.count == 2)
    }

    @Test("structured parser splits on & inside | branches (AND binds tighter)")
    func structuredParserSplitsAndInsideOR() {
        let ast = StructuredQueryParser.parse("?type=note & tag=draft | type=idea")
        guard case .or(let branches)? = ast else {
            Issue.record("Expected top-level .or for `note&draft | idea`")
            return
        }
        #expect(branches.count == 2)
        // The first branch should itself be an .and, not a single atom.
        if case .and(let lhsAtoms) = branches[0] {
            #expect(lhsAtoms.count == 2)
        } else {
            Issue.record("Left branch of OR should be an AND of two atoms")
        }
    }

    @Test("structured parser unwraps parenthesized groups")
    func structuredParserUnwrapsGroups() {
        let ast = StructuredQueryParser.parse("?(type=note | type=idea)")
        guard case .or? = ast else {
            Issue.record("Grouped OR should still parse as .or")
            return
        }
    }
}
