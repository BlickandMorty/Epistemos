import Foundation
import Testing

@testable import Epistemos

/// Wave 7.13.a source-guard for the Logseq-borrowed query AST + evaluator.
@Suite("EpdocQuery (Wave 7.13.a)")
nonisolated struct EpdocQueryTests {

    private static let now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    private static let dayMs: Int64 = 24 * 60 * 60 * 1000

    private static func manifest(id: String, title: String, createdAtOffsetDays: Int = 0) -> EpdocManifest {
        EpdocManifest(
            id: id,
            createdAt: now + Int64(createdAtOffsetDays) * dayMs,
            updatedAt: now + Int64(createdAtOffsetDays) * dayMs,
            title: title,
            contentHash: "",
            provenance: EpdocProvenance(producer: .human)
        )
    }

    private static func row(id: String, title: String, props: [String: EpdocPropertyValue], createdAtOffsetDays: Int = 0) throws -> EpdocDatabaseRow {
        var m = Self.manifest(id: id, title: title, createdAtOffsetDays: createdAtOffsetDays)
        for (pid, value) in props {
            m = try EpdocPropertyMetadata.withProperty(m, id: pid, value: value)
        }
        return EpdocDatabaseRow(manifest: m)
    }

    // MARK: - Boolean composition

    @Test(".alwaysTrue / .alwaysFalse pin the trivial endpoints")
    func trivialEndpoints() throws {
        let row = try Self.row(id: "x", title: "x", props: [:])
        #expect(EpdocQueryEvaluator.evaluate(.alwaysTrue, row: row))
        #expect(!EpdocQueryEvaluator.evaluate(.alwaysFalse, row: row))
    }

    @Test(".and short-circuits on first false; .or short-circuits on first true")
    func andOrComposition() throws {
        let row = try Self.row(id: "x", title: "alpha", props: ["status": .select("doing")])
        // and: matches the title AND the property → both true → composite true
        let goodAnd: EpdocQueryAST = .and([
            .titleContains("alph"),
            .property(id: "status", equals: .select("doing")),
        ])
        #expect(EpdocQueryEvaluator.evaluate(goodAnd, row: row))

        // and: one false → composite false
        let badAnd: EpdocQueryAST = .and([
            .titleContains("alph"),
            .property(id: "status", equals: .select("done")),
        ])
        #expect(!EpdocQueryEvaluator.evaluate(badAnd, row: row))

        // or: any true → composite true
        let mixedOr: EpdocQueryAST = .or([
            .property(id: "status", equals: .select("done")),
            .titleContains("ALPHA"),  // case-insensitive
        ])
        #expect(EpdocQueryEvaluator.evaluate(mixedOr, row: row))

        // or: every false → composite false
        let allFalseOr: EpdocQueryAST = .or([
            .titleContains("zzz"),
            .property(id: "status", equals: .select("blocked")),
        ])
        #expect(!EpdocQueryEvaluator.evaluate(allFalseOr, row: row))
    }

    @Test(".not flips its child")
    func notInverts() throws {
        let row = try Self.row(id: "x", title: "x", props: ["status": .select("doing")])
        #expect(!EpdocQueryEvaluator.evaluate(.not(.alwaysTrue), row: row))
        #expect(EpdocQueryEvaluator.evaluate(.not(.property(id: "status", equals: .select("done"))), row: row))
    }

    // MARK: - Property predicates

    @Test(".property and .propertyAnyOf match exact equality")
    func propertyMatch() throws {
        let row = try Self.row(id: "x", title: "x", props: ["status": .select("doing")])
        #expect(EpdocQueryEvaluator.evaluate(
            .property(id: "status", equals: .select("doing")), row: row))
        #expect(!EpdocQueryEvaluator.evaluate(
            .property(id: "status", equals: .select("done")), row: row))

        // anyOf
        let anyOf: EpdocQueryAST = .propertyAnyOf(id: "status",
                                                  equalsAny: [.select("todo"), .select("doing")])
        #expect(EpdocQueryEvaluator.evaluate(anyOf, row: row))
        let anyOfMiss: EpdocQueryAST = .propertyAnyOf(id: "status",
                                                      equalsAny: [.select("done"), .select("blocked")])
        #expect(!EpdocQueryEvaluator.evaluate(anyOfMiss, row: row))

        // missing property → false
        let missing: EpdocQueryAST = .property(id: "missing", equals: .select("any"))
        #expect(!EpdocQueryEvaluator.evaluate(missing, row: row))
    }

    // MARK: - between (createdAt + property dates)

    @Test("between createdAt today-7d today MUST include rows from the last 7 days")
    func betweenCreatedAt() throws {
        let yesterday = try Self.row(id: "y", title: "y", props: [:], createdAtOffsetDays: -1)
        let lastWeek  = try Self.row(id: "w", title: "w", props: [:], createdAtOffsetDays: -6)
        let lastMonth = try Self.row(id: "m", title: "m", props: [:], createdAtOffsetDays: -45)
        let q: EpdocQueryAST = .between(field: .createdAt, start: .daysFromToday(-7), end: .now)
        #expect(EpdocQueryEvaluator.evaluate(q, row: yesterday))
        #expect(EpdocQueryEvaluator.evaluate(q, row: lastWeek))
        #expect(!EpdocQueryEvaluator.evaluate(q, row: lastMonth))
    }

    @Test("between with property date field reads the ISO-8601 string off the property bag (wide window straddles tz)")
    func betweenPropertyDate() throws {
        let dateFmt = ISO8601DateFormatter()
        dateFmt.formatOptions = [.withFullDate]
        let today = dateFmt.string(from: Calendar.current.startOfDay(for: Date()))
        let row = try Self.row(id: "x", title: "x", props: ["due": .date(today)])
        // ISO `YYYY-MM-DD` parses to UTC midnight; .today uses local
        // midnight. Use a ±2 day window so the test is deterministic
        // regardless of caller timezone (UTC-12 to UTC+14).
        let q: EpdocQueryAST = .between(field: .property(id: "due"),
                                        start: .daysFromToday(-2),
                                        end: .daysFromToday(2))
        #expect(EpdocQueryEvaluator.evaluate(q, row: row),
                "row whose `due` is today-ish MUST be inside [today-2d, today+2d]")

        // Out-of-window date is definitively rejected.
        let oldRow = try Self.row(id: "old", title: "old",
                                  props: ["due": .date("2020-01-01")])
        #expect(!EpdocQueryEvaluator.evaluate(q, row: oldRow))
    }

    @Test("between bounds are inclusive — start == end == today returns today's rows")
    func betweenInclusive() throws {
        let today = try Self.row(id: "t", title: "t", props: [:], createdAtOffsetDays: 0)
        let q: EpdocQueryAST = .between(field: .createdAt, start: .today, end: .now)
        #expect(EpdocQueryEvaluator.evaluate(q, row: today))
    }

    // MARK: - Title + kind

    @Test(".titleContains is case-insensitive")
    func titleContainsCaseInsensitive() throws {
        let row = try Self.row(id: "x", title: "Quarterly Report Q3", props: [:])
        #expect(EpdocQueryEvaluator.evaluate(.titleContains("quarterly"), row: row))
        #expect(EpdocQueryEvaluator.evaluate(.titleContains("Q3"), row: row))
        #expect(!EpdocQueryEvaluator.evaluate(.titleContains("nope"), row: row))
    }

    @Test(".kind matches the manifest's ArtifactKind")
    func kindMatch() throws {
        let row = try Self.row(id: "x", title: "x", props: [:])
        // Sample manifest defaults to .document
        #expect(EpdocQueryEvaluator.evaluate(.kind(.document), row: row))
    }

    // MARK: - Built-in rules

    @Test(".rule has-property matches when the property id is present at all")
    func hasPropertyRule() throws {
        let withStatus = try Self.row(id: "with", title: "x", props: ["status": .select("doing")])
        let without    = try Self.row(id: "no",   title: "y", props: [:])
        let q: EpdocQueryAST = .rule(name: "has-property", args: [
            .property(id: "status", equals: .select("doing"))  // value ignored; only id matters
        ])
        #expect(EpdocQueryEvaluator.evaluate(q, row: withStatus))
        #expect(!EpdocQueryEvaluator.evaluate(q, row: without))
    }

    @Test(".rule with unknown name returns false (not crash)")
    func unknownRuleSafelyFalse() throws {
        let row = try Self.row(id: "x", title: "x", props: [:])
        let q: EpdocQueryAST = .rule(name: "definitely-not-a-real-rule", args: [])
        #expect(!EpdocQueryEvaluator.evaluate(q, row: row))
    }

    // MARK: - W7.13.d named-rule registry

    @Test("EpdocBuiltInRules.allRuleNames advertises the V1 catalogue (auto-complete + parser source)")
    func ruleCatalogueExposed() {
        let names = Set(EpdocBuiltInRules.allRuleNames)
        let expected: Set<String> = [
            "has-property", "is-empty",
            "recently-updated", "older-than",
            "has-attached-thoughts",
            "complexity-above", "complexity-below",
        ]
        #expect(names == expected,
                "the slash-menu + parser MUST see the same rule list; got \(names.sorted())")
    }

    @Test(".rule is-empty matches rows with zero typed properties")
    func ruleIsEmpty() throws {
        let withProps = try Self.row(id: "p", title: "x", props: ["status": .select("doing")])
        let bare      = try Self.row(id: "b", title: "y", props: [:])
        let q: EpdocQueryAST = .rule(name: "is-empty", args: [])
        #expect(!EpdocQueryEvaluator.evaluate(q, row: withProps))
        #expect(EpdocQueryEvaluator.evaluate(q, row: bare))
    }

    @Test(".rule recently-updated <days> + .rule older-than <days> partition rows around the wall clock")
    func ruleRecentlyUpdatedAndOlderThan() throws {
        let yesterday = try Self.row(id: "y", title: "y", props: [:], createdAtOffsetDays: -1)
        let lastMonth = try Self.row(id: "m", title: "m", props: [:], createdAtOffsetDays: -45)

        // recently-updated 7 → yesterday yes, lastMonth no
        let recent7: EpdocQueryAST = .rule(name: "recently-updated",
                                            args: [.titleContains("7")])
        #expect(EpdocQueryEvaluator.evaluate(recent7, row: yesterday))
        #expect(!EpdocQueryEvaluator.evaluate(recent7, row: lastMonth))

        // older-than 7 → yesterday no, lastMonth yes
        let stale7: EpdocQueryAST = .rule(name: "older-than",
                                          args: [.titleContains("7")])
        #expect(!EpdocQueryEvaluator.evaluate(stale7, row: yesterday))
        #expect(EpdocQueryEvaluator.evaluate(stale7, row: lastMonth))
    }

    @Test(".rule has-attached-thoughts reads the W7.15 metadata key")
    func ruleHasAttachedThoughts() throws {
        let m = EpdocManifest(
            id: "x",
            createdAt: 0,
            updatedAt: 0,
            title: "x",
            contentHash: "",
            provenance: EpdocProvenance(producer: .human),
            metadata: ["attached-thoughts": "run-1,run-2"]
        )
        let withThoughts = EpdocDatabaseRow(manifest: m)
        let bare = try Self.row(id: "b", title: "b", props: [:])

        let q: EpdocQueryAST = .rule(name: "has-attached-thoughts", args: [])
        #expect(EpdocQueryEvaluator.evaluate(q, row: withThoughts))
        #expect(!EpdocQueryEvaluator.evaluate(q, row: bare))
    }

    @Test(".rule complexity-above + complexity-below read the W7.12 metadata key")
    func ruleComplexityThresholds() throws {
        let mAt08 = EpdocManifest(
            id: "x",
            createdAt: 0,
            updatedAt: 0,
            title: "x",
            contentHash: "",
            provenance: EpdocProvenance(producer: .human),
            metadata: ["complexity": "0.8"]
        )
        let highComplexity = EpdocDatabaseRow(manifest: mAt08)

        let above05: EpdocQueryAST = .rule(name: "complexity-above",
                                           args: [.titleContains("0.5")])
        #expect(EpdocQueryEvaluator.evaluate(above05, row: highComplexity))

        let below05: EpdocQueryAST = .rule(name: "complexity-below",
                                           args: [.titleContains("0.5")])
        #expect(!EpdocQueryEvaluator.evaluate(below05, row: highComplexity))

        // Missing complexity metadata → both rules return false (rule
        // failure, NOT a panic; the user expects "no match" not a crash)
        let bare = try Self.row(id: "b", title: "b", props: [:])
        #expect(!EpdocQueryEvaluator.evaluate(above05, row: bare))
        #expect(!EpdocQueryEvaluator.evaluate(below05, row: bare))
    }

    @Test("Built-in rules tolerate malformed args by returning false (defensive evaluation)")
    func ruleArgCoercionDefensive() throws {
        let row = try Self.row(id: "x", title: "x", props: [:])

        // recently-updated with no arg → false
        #expect(!EpdocQueryEvaluator.evaluate(
            .rule(name: "recently-updated", args: []), row: row))

        // recently-updated with non-numeric arg → false
        #expect(!EpdocQueryEvaluator.evaluate(
            .rule(name: "recently-updated", args: [.titleContains("forever")]),
            row: row))

        // complexity-above with non-numeric threshold → false
        #expect(!EpdocQueryEvaluator.evaluate(
            .rule(name: "complexity-above", args: [.titleContains("zero")]),
            row: row))
    }

    // MARK: - End-to-end via EpdocDatabase

    @Test("EpdocDatabase.rows(matching:) projects + filters in one call")
    func databaseRowsMatching() async throws {
        let db = EpdocDatabase()
        await db.add(try Self.row(id: "a", title: "alpha", props: ["status": .select("doing")]))
        await db.add(try Self.row(id: "b", title: "beta",  props: ["status": .select("done")]))
        await db.add(try Self.row(id: "c", title: "gamma", props: ["status": .select("doing")]))

        let q: EpdocQueryAST = .property(id: "status", equals: .select("doing"))
        let hits = await db.rows(matching: q).map(\.manifest.title)
        #expect(Set(hits) == ["alpha", "gamma"], "got \(hits)")
    }

    @Test("Composed and/or/not query: 'doing AND title contains alpha' / 'NOT done'")
    func endToEndComposition() async throws {
        let db = EpdocDatabase()
        await db.add(try Self.row(id: "a", title: "alpha report", props: ["status": .select("doing")]))
        await db.add(try Self.row(id: "b", title: "alpha follow",  props: ["status": .select("done")]))
        await db.add(try Self.row(id: "c", title: "beta",          props: ["status": .select("doing")]))

        // Doing AND title contains alpha
        let andQuery: EpdocQueryAST = .and([
            .property(id: "status", equals: .select("doing")),
            .titleContains("alpha"),
        ])
        let andHits = await db.rows(matching: andQuery).map(\.manifest.title)
        #expect(andHits == ["alpha report"], "got \(andHits)")

        // NOT done
        let notDone: EpdocQueryAST = .not(.property(id: "status", equals: .select("done")))
        let notHits = Set(await db.rows(matching: notDone).map(\.manifest.title))
        #expect(notHits == ["alpha report", "beta"], "got \(notHits)")
    }
}
