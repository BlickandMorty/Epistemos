import Foundation
import Testing

@testable import Epistemos

/// Wave 7.13.b source-guard for the Logseq-borrowed query DSL parser.
@Suite("EpdocQueryParser (Wave 7.13.b)")
nonisolated struct EpdocQueryParserTests {

    // MARK: - Trivial atoms + always-true / always-false

    @Test("Bare atom parses as title-contains shorthand (ergonomics)")
    func bareAtomShorthand() throws {
        let ast = try EpdocQueryParser.parse("alpha")
        #expect(ast == .titleContains("alpha"))
    }

    @Test("(always-true) and (always-false) parse to their leaves")
    func alwaysTrueFalse() throws {
        #expect(try EpdocQueryParser.parse("(always-true)") == .alwaysTrue)
        #expect(try EpdocQueryParser.parse("(always-false)") == .alwaysFalse)
    }

    // MARK: - and / or / not

    @Test("(and …) flattens its children into the .and case")
    func parseAnd() throws {
        let ast = try EpdocQueryParser.parse("(and (always-true) (always-false))")
        if case .and(let children) = ast {
            #expect(children == [.alwaysTrue, .alwaysFalse])
        } else {
            #expect(Bool(false), "expected .and; got \(ast)")
        }
    }

    @Test("(or …) flattens children into .or")
    func parseOr() throws {
        let ast = try EpdocQueryParser.parse("(or (always-false) (title-contains hi))")
        if case .or(let children) = ast {
            #expect(children == [.alwaysFalse, .titleContains("hi")])
        } else {
            #expect(Bool(false), "got \(ast)")
        }
    }

    @Test("(not q) negates")
    func parseNot() throws {
        let ast = try EpdocQueryParser.parse("(not (always-true))")
        #expect(ast == .not(.alwaysTrue))
    }

    // MARK: - Property forms

    @Test("(property id (select foo)) parses to .property + .select")
    func parsePropertySelect() throws {
        let ast = try EpdocQueryParser.parse("(property status (select doing))")
        #expect(ast == .property(id: "status", equals: .select("doing")))
    }

    @Test("(property id (number 3.14)) parses numeric values")
    func parsePropertyNumber() throws {
        let ast = try EpdocQueryParser.parse("(property score (number 3.14))")
        #expect(ast == .property(id: "score", equals: .number(3.14)))
    }

    @Test("(property id (checkbox true|false)) parses booleans")
    func parsePropertyCheckbox() throws {
        let astT = try EpdocQueryParser.parse("(property done (checkbox true))")
        let astF = try EpdocQueryParser.parse("(property done (checkbox false))")
        #expect(astT == .property(id: "done", equals: .checkbox(true)))
        #expect(astF == .property(id: "done", equals: .checkbox(false)))
    }

    @Test("(property id (date 2026-04-26)) parses bare ISO dates")
    func parsePropertyDate() throws {
        let ast = try EpdocQueryParser.parse("(property due (date 2026-04-26))")
        #expect(ast == .property(id: "due", equals: .date("2026-04-26")))
    }

    @Test("(property id (multi-select [a b c])) parses bracketed lists")
    func parsePropertyMultiSelect() throws {
        let ast = try EpdocQueryParser.parse("(property tag (multi-select [work urgent personal]))")
        #expect(ast == .property(id: "tag", equals: .multiSelect(["work", "urgent", "personal"])))
    }

    @Test("(property-any-of id [<vals>]) parses a list of typed values")
    func parsePropertyAnyOf() throws {
        let ast = try EpdocQueryParser.parse(
            "(property-any-of status [(select todo) (select doing)])"
        )
        #expect(ast == .propertyAnyOf(id: "status",
                                      equalsAny: [.select("todo"), .select("doing")]))
    }

    @Test("Quoted strings preserve embedded whitespace + standard escapes")
    func quotedStrings() throws {
        let ast = try EpdocQueryParser.parse("(title-contains \"hello world\")")
        #expect(ast == .titleContains("hello world"))

        let escaped = try EpdocQueryParser.parse("(title-contains \"line\\nbreak\")")
        #expect(escaped == .titleContains("line\nbreak"))
    }

    // MARK: - between

    @Test("(between created-at -7d today) parses the canonical time-window helper")
    func parseBetweenCreatedAt() throws {
        let ast = try EpdocQueryParser.parse("(between created-at -7d today)")
        #expect(ast == .between(field: .createdAt, start: .daysFromToday(-7), end: .today))
    }

    @Test("(between updated-at today now) is also valid")
    func parseBetweenUpdatedAt() throws {
        let ast = try EpdocQueryParser.parse("(between updated-at today now)")
        #expect(ast == .between(field: .updatedAt, start: .today, end: .now))
    }

    @Test("(between (property due) today +30d) recognises date property fields")
    func parseBetweenPropertyDate() throws {
        let ast = try EpdocQueryParser.parse("(between (property due) today +30d)")
        #expect(ast == .between(field: .property(id: "due"),
                                start: .today,
                                end: .daysFromToday(30)))
    }

    @Test("Time-ref grammar covers d/w/m/y suffixes with explicit signs")
    func parseTimeRefUnits() throws {
        // Use the parser directly through a between() form
        let cases: [(String, TimeRef)] = [
            ("-1d", .daysFromToday(-1)),
            ("+1d", .daysFromToday(1)),
            ("-1w", .daysFromToday(-7)),
            ("+2w", .daysFromToday(14)),
            ("-1m", .daysFromToday(-30)),
            ("+1y", .daysFromToday(365)),
        ]
        for (token, expected) in cases {
            let ast = try EpdocQueryParser.parse("(between created-at \(token) today)")
            #expect(ast == .between(field: .createdAt, start: expected, end: .today),
                    "time-ref '\(token)' MUST parse to \(expected); got \(ast)")
        }
    }

    @Test("ISO-8601 date strings flow through as .iso8601 time-refs")
    func parseTimeRefISODate() throws {
        let ast = try EpdocQueryParser.parse("(between created-at 2026-01-01 2026-12-31)")
        #expect(ast == .between(field: .createdAt,
                                start: .iso8601("2026-01-01"),
                                end: .iso8601("2026-12-31")))
    }

    // MARK: - kind + rule

    @Test("(kind <raw>) parses the ArtifactKind raw value")
    func parseKind() throws {
        // ArtifactKind is repr(UInt8) — `.document` raw value is 2.
        let ast = try EpdocQueryParser.parse("(kind 2)")
        #expect(ast == .kind(.document))
    }

    @Test("(rule has-property (property foo (select any))) parses + dispatches")
    func parseRuleWithArgs() throws {
        let ast = try EpdocQueryParser.parse(
            "(rule has-property (property foo (select any)))"
        )
        #expect(ast == .rule(name: "has-property",
                             args: [.property(id: "foo", equals: .select("any"))]))
    }

    // MARK: - Nested combinations

    @Test("Deeply nested and/or/not/property compose correctly")
    func parseDeeplyNested() throws {
        let src = """
        (and
          (or
            (property status (select doing))
            (property status (select todo)))
          (not (between created-at -30d today)))
        """
        let ast = try EpdocQueryParser.parse(src)
        let expected: EpdocQueryAST = .and([
            .or([
                .property(id: "status", equals: .select("doing")),
                .property(id: "status", equals: .select("todo")),
            ]),
            .not(.between(field: .createdAt, start: .daysFromToday(-30), end: .today)),
        ])
        #expect(ast == expected)
    }

    // MARK: - Errors

    @Test("Unknown head surfaces a typed parse error")
    func unknownHeadError() {
        do {
            _ = try EpdocQueryParser.parse("(banana foo bar)")
            #expect(Bool(false), "expected parse error")
        } catch let e as EpdocQueryParseError {
            if case .unknownHead = e {} else {
                #expect(Bool(false), "expected .unknownHead; got \(e)")
            }
        } catch {
            #expect(Bool(false), "got \(error)")
        }
    }

    @Test("Unbalanced parens surfaces a typed parse error")
    func unbalancedParensError() {
        do {
            _ = try EpdocQueryParser.parse("(and (always-true)")
            #expect(Bool(false), "expected parse error")
        } catch is EpdocQueryParseError {
            // expected
        } catch {
            #expect(Bool(false), "got \(error)")
        }
    }

    @Test("Malformed time-ref surfaces a typed parse error")
    func malformedTimeRefError() {
        do {
            _ = try EpdocQueryParser.parse("(between created-at junk today)")
            #expect(Bool(false), "expected parse error")
        } catch let e as EpdocQueryParseError {
            if case .malformedTimeRef = e {} else {
                #expect(Bool(false), "expected .malformedTimeRef; got \(e)")
            }
        } catch {
            #expect(Bool(false), "got \(error)")
        }
    }

    // MARK: - End-to-end via evaluator

    @Test("Parsed AST evaluates against an EpdocDatabase row exactly as the manually-built AST does")
    func parserEvaluatorIntegration() async throws {
        let m = EpdocManifest(
            id: "x",
            createdAt: 0,
            updatedAt: 0,
            title: "Quarterly Report",
            contentHash: "",
            provenance: EpdocProvenance(producer: .human)
        )
        let withStatus = try EpdocPropertyMetadata.withProperty(m, id: "status", value: .select("doing"))
        let row = EpdocDatabaseRow(manifest: withStatus)

        let ast = try EpdocQueryParser.parse(
            "(and (property status (select doing)) (title-contains quarterly))"
        )
        #expect(EpdocQueryEvaluator.evaluate(ast, row: row),
                "parsed AST MUST evaluate the same as a hand-built AST")
    }
}
