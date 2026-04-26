import Foundation

// MARK: - EpdocQuery
//
// Wave 7.13.a of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.13.a,
//  cross-ref Logseq scan 2026-04-26 at /Users/jojo/Downloads/logseq-source).
//
// Notion + Logseq-shaped query language for the W7.13 EpdocDatabase
// actor. Borrows the s-expression grammar from Logseq's
// `frontend/db/query_dsl.cljs` (lines 22-40 doc-comment, 178+
// for the and/or/not + property + between builders) but reimplements
// it in pure Swift over our `EpdocDatabase.filtered(where:)` surface
// — Datascript itself is AGPL-v3 + Electron-coupled, both blockers
// for the MAS build (per the agent verdict 2026-04-26).
//
// V1 grammar (this commit ships the AST + evaluator; the parser is
// W7.13.b):
//
//     (and  q1 q2 …)        — every sub-query must match
//     (or   q1 q2 …)        — at least one must match
//     (not  q)              — sub-query must NOT match
//     (property <id> <val>) — property `<id>` equals `<val>` exactly
//     (between <field> <start> <end>)
//                           — date-typed property OR createdAt /
//                             updatedAt within [start, end]
//     (title-contains <s>)  — manifest.title contains substring (case-insensitive)
//     (kind <k>)            — manifest.kind matches ArtifactKind raw value
//     (rule <name> args…)   — named rule lookup (W7.13.d, hook only today)
//
// Time references inside `between`:
//     today              — the current calendar day at 00:00 local
//     -7d / -30d / +1y   — relative to `today` (parsed in W7.13.b)
//     "2026-04-26"       — explicit ISO-8601 date string
//
// Per the verdict, this gives the user composable AND/OR/NOT, the
// `between -7d today` time-window helper, and a clean growth path
// to graph relations once W7.14 lands.

// MARK: - AST

nonisolated public indirect enum EpdocQueryAST: Sendable, Hashable {
    case and([EpdocQueryAST])
    case or([EpdocQueryAST])
    case not(EpdocQueryAST)
    case property(id: String, equals: EpdocPropertyValue)
    /// True when the property value is one of `equalsAny`. Models the
    /// `(property status [todo doing])` Logseq sugar declaratively.
    case propertyAnyOf(id: String, equalsAny: [EpdocPropertyValue])
    case between(field: BetweenField, start: TimeRef, end: TimeRef)
    case titleContains(String)
    case kind(ArtifactKind)
    /// Named rule lookup. Dispatches through `EpdocBuiltInRules.evaluate(_:row:)`;
    /// returns `false` when the rule name is unknown so an out-of-date
    /// query never matches more than the user expects.
    case rule(name: String, args: [EpdocQueryAST] = [])
    /// True for every row. Useful as an `or` base case + as a sanity
    /// constructor in tests.
    case alwaysTrue
    /// False for every row. Useful as a `not(.alwaysTrue)` shorthand +
    /// to express "no docs satisfy this filter".
    case alwaysFalse
}

/// Field discriminant for `.between(…)`. Keeps the AST typed instead
/// of stringifying field names (so the evaluator never has to
/// stringly-match).
nonisolated public enum BetweenField: Sendable, Hashable {
    /// `manifest.createdAt` (Unix milliseconds).
    case createdAt
    /// `manifest.updatedAt` (Unix milliseconds).
    case updatedAt
    /// A `.date`-typed property. The evaluator parses ISO-8601 from
    /// the property's string value.
    case property(id: String)
}

/// Time reference inside a `.between` filter. The W7.13.b parser
/// reads strings like `"today"` / `"-7d"` / `"2026-04-26"` into
/// these cases; the evaluator resolves them to `Date` against the
/// `Calendar.current` clock at evaluation time.
nonisolated public enum TimeRef: Sendable, Hashable {
    /// Now (`Date()`).
    case now
    /// Today at 00:00 local time.
    case today
    /// Today + N days. Negative N is in the past.
    case daysFromToday(Int)
    /// Explicit ISO-8601 date string (`YYYY-MM-DD` or full datetime).
    case iso8601(String)
}

// MARK: - Evaluator

nonisolated public enum EpdocQueryEvaluator {

    /// Evaluate the AST against a single row. The actor caller wraps
    /// this in `EpdocDatabase.filtered { row in evaluate(ast, row: row) }`.
    public static func evaluate(_ ast: EpdocQueryAST, row: EpdocDatabaseRow) -> Bool {
        switch ast {
        case .and(let children):
            return children.allSatisfy { evaluate($0, row: row) }

        case .or(let children):
            return children.contains { evaluate($0, row: row) }

        case .not(let inner):
            return !evaluate(inner, row: row)

        case .property(let id, let expected):
            return row.value(forPropertyID: id) == expected

        case .propertyAnyOf(let id, let candidates):
            guard let actual = row.value(forPropertyID: id) else { return false }
            return candidates.contains(actual)

        case .between(let field, let start, let end):
            return evaluateBetween(field: field, start: start, end: end, row: row)

        case .titleContains(let needle):
            let title = row.manifest.title.lowercased()
            return title.contains(needle.lowercased())

        case .kind(let expected):
            return row.manifest.kind == expected

        case .rule(let name, let args):
            return EpdocBuiltInRules.evaluate(name: name, args: args, row: row)

        case .alwaysTrue:
            return true

        case .alwaysFalse:
            return false
        }
    }

    // MARK: - between

    private static func evaluateBetween(
        field: BetweenField,
        start: TimeRef,
        end: TimeRef,
        row: EpdocDatabaseRow
    ) -> Bool {
        guard let lower = resolve(start),
              let upper = resolve(end) else {
            return false
        }
        let candidate: Date?
        switch field {
        case .createdAt:
            candidate = Date(timeIntervalSince1970: TimeInterval(row.manifest.createdAt) / 1000)
        case .updatedAt:
            candidate = Date(timeIntervalSince1970: TimeInterval(row.manifest.updatedAt) / 1000)
        case .property(let id):
            guard let value = row.value(forPropertyID: id),
                  case .date(let iso) = value else {
                return false
            }
            candidate = Self.parseISO8601(iso)
        }
        guard let date = candidate else { return false }
        // Inclusive bounds so users typing `(between createdAt today today)`
        // see today's docs.
        return date >= lower && date <= upper
    }

    /// Resolve a `TimeRef` against `Date()` / `Calendar.current`.
    public static func resolve(_ ref: TimeRef) -> Date? {
        let now = Date()
        switch ref {
        case .now:
            return now
        case .today:
            return Calendar.current.startOfDay(for: now)
        case .daysFromToday(let delta):
            let base = Calendar.current.startOfDay(for: now)
            return Calendar.current.date(byAdding: .day, value: delta, to: base)
        case .iso8601(let s):
            return parseISO8601(s)
        }
    }

    /// Parse an ISO-8601 date or datetime string. Tolerates both the
    /// short `YYYY-MM-DD` form (most user input) and the full
    /// `YYYY-MM-DDTHH:MM:SSZ` form.
    private static func parseISO8601(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try short form first — it's the most common date-property value.
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        if let d = dateOnly.date(from: trimmed) { return d }
        // Fall back to the full datetime form.
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime]
        return full.date(from: trimmed)
    }
}

// MARK: - Built-in rules registry (W7.13.d)

/// Named rule registry — Logseq's `rules.cljc:1-366` ported to Swift.
/// Each rule is a small predicate over a single `EpdocDatabaseRow`.
/// Rules are addressable by name from the query DSL via
/// `(rule <name> <args>...)`. Unknown rule names safely return false
/// so an out-of-date query never matches more than the user expects.
///
/// V1 rules (this commit ships 7; the W7.14 graph follow-up adds
/// the `.parent`, `.classExtends`, `.subjectOf` graph-traversal
/// rules once the SDGraphNode index is populated):
///
///   has-property <propertyID>
///       True iff the row has any value for the given property id.
///       Sugar shape: `(rule has-property (property foo (select x)))`
///       — the value inside the .property argument is ignored; only
///       the id matters. This matches Logseq's
///       `(has-property ?b :propertyID)` predicate exactly.
///
///   is-empty
///       True iff the row has zero typed properties at all (i.e. no
///       properties.* keys in the manifest metadata bag). Useful as a
///       "show me docs that haven't been categorised yet" filter.
///
///   recently-updated <days>
///       True iff manifest.updatedAt is within the last N days of now.
///       The days arg is encoded as an .alwaysTrue/.alwaysFalse leaf
///       carrying the integer in a recognised form, OR as a bare
///       (titleContains) AST node whose body is the integer string —
///       see `extractIntArg(_:)`.
///
///   older-than <days>
///       True iff manifest.updatedAt is more than N days behind now.
///       Mirror of recently-updated.
///
///   has-attached-thoughts
///       True iff the row's `manifest.metadata["attached-thoughts"]`
///       count is non-zero (this metadata key is populated by the
///       W7.15 ThoughtAttachmentBridge integration). Surfaces the
///       Notion-like "show me docs that have backlinks" filter.
///
///   complexity-above <threshold>
///       True iff `manifest.metadata["complexity"]` (W7.12 scalar) is
///       greater than `threshold` (a Double in [0, 1]). Sugar over
///       reading + parsing the metadata value.
///
///   complexity-below <threshold>
///       True iff complexity scalar is less than `threshold`.
///
nonisolated public enum EpdocBuiltInRules {

    /// Every rule name the registry knows. Surfacing this list lets
    /// the W7.17 slash menu offer auto-complete + the W7.13.b parser
    /// emit a typed parse error on a typo'd rule name.
    public static let allRuleNames: [String] = [
        "has-property",
        "is-empty",
        "recently-updated",
        "older-than",
        "has-attached-thoughts",
        "complexity-above",
        "complexity-below",
    ]

    public static func evaluate(name: String, args: [EpdocQueryAST], row: EpdocDatabaseRow) -> Bool {
        switch name {
        case "has-property":
            guard case .property(let id, _) = args.first else { return false }
            return row.value(forPropertyID: id) != nil

        case "is-empty":
            return row.properties.isEmpty

        case "recently-updated":
            guard let days = extractIntArg(args.first), days >= 0 else { return false }
            return isUpdatedWithinDays(row.manifest.updatedAt, days: days)

        case "older-than":
            guard let days = extractIntArg(args.first), days >= 0 else { return false }
            return !isUpdatedWithinDays(row.manifest.updatedAt, days: days)

        case "has-attached-thoughts":
            // W7.15 bridge writes `attached-thoughts` into the metadata
            // bag as a comma-separated id list. Empty / missing → false.
            guard let raw = row.manifest.metadata?["attached-thoughts"] else { return false }
            return raw.split(separator: ",").contains(where: { !$0.isEmpty })

        case "complexity-above":
            guard let threshold = extractDoubleArg(args.first) else { return false }
            guard let complexity = parseComplexity(from: row.manifest) else { return false }
            return complexity > threshold

        case "complexity-below":
            guard let threshold = extractDoubleArg(args.first) else { return false }
            guard let complexity = parseComplexity(from: row.manifest) else { return false }
            return complexity < threshold

        default:
            return false
        }
    }

    // MARK: - Argument coercion

    /// Read a numeric arg the parser packed into a `.titleContains` or
    /// `.property(_, .number(_))` AST shape. Why those two shapes:
    /// the W7.13.b parser doesn't know rule signatures so it lowers
    /// every bare token to .titleContains; explicit `(property _ (number N))`
    /// is the typed escape hatch.
    static func extractIntArg(_ node: EpdocQueryAST?) -> Int? {
        guard let node else { return nil }
        switch node {
        case .titleContains(let s):
            return Int(s)
        case .property(_, .number(let d)):
            return Int(d)
        default:
            return nil
        }
    }

    static func extractDoubleArg(_ node: EpdocQueryAST?) -> Double? {
        guard let node else { return nil }
        switch node {
        case .titleContains(let s):
            return Double(s)
        case .property(_, .number(let d)):
            return d
        default:
            return nil
        }
    }

    /// Read the `manifest.metadata["complexity"]` value as a Double.
    /// Returns nil when the key is missing or unparseable. The W7.12
    /// EpdocComplexityCalculator writer emits a stringified
    /// `String(scalar)` so `Double(_:)` round-trips it cleanly.
    static func parseComplexity(from manifest: EpdocManifest) -> Double? {
        guard let raw = manifest.metadata?["complexity"] else { return nil }
        return Double(raw)
    }

    /// True iff `updatedAtMs` (Unix milliseconds) is within `days`
    /// days of now. `now` is sampled per-call against the system clock
    /// so the rule tracks the wall clock from query to query.
    private static func isUpdatedWithinDays(_ updatedAtMs: Int64, days: Int) -> Bool {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let windowMs = Int64(days) * 24 * 60 * 60 * 1000
        return (nowMs - updatedAtMs) <= windowMs
    }
}

// MARK: - EpdocDatabase convenience

extension EpdocDatabase {
    /// Filter rows via the W7.13.a query AST. Hops into the actor's
    /// rows, evaluates the AST against each row, returns a snapshot.
    public func rows(matching ast: EpdocQueryAST) -> [EpdocDatabaseRow] {
        rows.filter { EpdocQueryEvaluator.evaluate(ast, row: $0) }
    }
}
