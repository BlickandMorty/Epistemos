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
}
