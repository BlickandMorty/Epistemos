import Foundation

// MARK: - StructuredQueryParser
// Parses ?-prefix structured query syntax into QueryAST.
//
// Grammar (simplified):
//   query     = expr ("&" expr | "|" expr)*
//   expr      = "!" expr | atom
//   atom      = type_filter | date_filter | prop_filter | fts | graph_fn | group
//   group     = "(" query ")"
//
// Examples:
//   ?type=note & created:last_week
//   ?tag=claim & confidence<0.5
//   ?"machine learning"
//   ?path("Kant" → "Hegel")
//   ?similar("consciousness", 0.8)

enum StructuredQueryParser {

    static func parse(_ input: String) -> QueryAST? {
        // Strip leading ? if present
        let query = input.hasPrefix("?")
            ? String(input.dropFirst()).trimmingCharacters(in: .whitespaces)
            : input.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return nil }

        // Split on & (AND) at the top level, respecting quotes and parens
        let parts = splitTopLevel(query, on: "&")

        if parts.count == 1 {
            return parseAtom(parts[0].trimmingCharacters(in: .whitespaces))
        }

        let atoms = parts.compactMap {
            parseAtom($0.trimmingCharacters(in: .whitespaces))
        }
        guard !atoms.isEmpty else { return nil }
        return atoms.count == 1 ? atoms[0] : .and(atoms)
    }

    // MARK: - Atom Parsing

    private static func parseAtom(_ s: String) -> QueryAST? {
        // Negation
        if s.hasPrefix("!") {
            let inner = String(s.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard let ast = parseAtom(inner) else { return nil }
            return .not(ast)
        }

        // Type filter: type=note, type=idea
        if s.range(of: #"^type=(\w+)$"#, options: .regularExpression) != nil {
            let typeName = s.replacingOccurrences(of: "type=", with: "")
            if let nodeType = GraphNodeType.from(displayName: typeName) {
                return .typeFilter(types: [nodeType])
            }
            return nil // Unknown type — don't fall through to label search
        }

        // Date filter: created:last_week, updated:today, created:2024
        if s.hasPrefix("created:") || s.hasPrefix("updated:") {
            return parseDateAtom(s)
        }

        // Property comparison: confidence<0.5, tag=claim, depth>2
        if let ast = parsePropertyComparison(s) {
            return ast
        }

        // Graph functions: path("A" → "B"), supports("X"), neighbors("X")
        if s.hasPrefix("path(") { return parsePathFunction(s) }
        if s.hasPrefix("supports(") { return parseRelFunction(s, edgeType: .supports) }
        if s.hasPrefix("contradicts(") { return parseRelFunction(s, edgeType: .contradicts) }
        if s.hasPrefix("neighbors(") { return parseNeighborsFunction(s) }
        if s.hasPrefix("similar(") { return parseSimilarFunction(s) }

        // Quoted string: FTS match
        if s.hasPrefix("\"") && s.hasSuffix("\"") {
            let inner = String(s.dropFirst().dropLast())
            return .ftsMatch(query: inner, scope: .all)
        }

        // Bare string: label contains
        return .labelContains(s)
    }

    // MARK: - Date Parsing

    private static func parseDateAtom(_ s: String) -> QueryAST? {
        let parts = s.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let field: DateField = parts[0] == "created" ? .created : .updated
        let value = String(parts[1])
        let calendar = Calendar.current
        let now = Date()

        switch value {
        case "today":
            return .dateFilter(field: field, op: .gte, value: calendar.startOfDay(for: now))
        case "yesterday":
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
                return nil
            }
            let startYesterday = calendar.startOfDay(for: yesterday)
            let startToday = calendar.startOfDay(for: now)
            return .and([
                .dateFilter(field: field, op: .gte, value: startYesterday),
                .dateFilter(field: field, op: .lt, value: startToday),
            ])
        case "last_week", "past_week":
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
                return nil
            }
            return .dateFilter(field: field, op: .gte, value: weekAgo)
        case "last_month", "past_month":
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
                return nil
            }
            return .dateFilter(field: field, op: .gte, value: monthAgo)
        default:
            // Try parsing as year: "2024"
            if let year = Int(value) {
                var components = DateComponents()
                components.year = year
                components.month = 1
                components.day = 1
                if let date = calendar.date(from: components) {
                    return .dateFilter(field: field, op: .gte, value: date)
                }
            }
            return nil
        }
    }

    // MARK: - Property Comparison

    private static func parsePropertyComparison(_ s: String) -> QueryAST? {
        // Match: key<value, key>value, key=value, key<=value, key>=value
        let operators: [(String, CompOp)] = [
            ("<=", .lte), (">=", .gte), ("!=", .neq),
            ("<", .lt), (">", .gt), ("=", .eq),
        ]

        for (opStr, op) in operators {
            if let range = s.range(of: opStr) {
                let key = String(s[s.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let rawValue = String(s[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                // Skip if key is "type", "created", "updated" (handled elsewhere)
                guard key != "type" && key != "created" && key != "updated" else { return nil }

                // Depth is special
                if key == "depth" {
                    if let intVal = Int(rawValue) {
                        return .depthFilter(op: op, value: intVal)
                    }
                }

                // Try float, int, bool, then string
                if let fVal = Float(rawValue) {
                    return .propertyFilter(key: key, op: op, value: .float(fVal))
                }
                if let iVal = Int(rawValue) {
                    return .propertyFilter(key: key, op: op, value: .int(iVal))
                }
                if rawValue == "true" || rawValue == "false" {
                    return .propertyFilter(key: key, op: op, value: .bool(rawValue == "true"))
                }
                return .propertyFilter(key: key, op: op, value: .string(rawValue))
            }
        }
        return nil
    }

    // MARK: - Graph Functions

    private static func parsePathFunction(_ s: String) -> QueryAST? {
        // path("Kant" → "Hegel") or path("Kant", "Hegel")
        let inner = extractParens(s)
        let parts = inner.split(separator: "→").count == 2
            ? inner.split(separator: "→").map { String($0).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            : inner.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
        guard parts.count == 2 else { return nil }
        return .graphPath(from: .label(parts[0]), to: .label(parts[1]), maxHops: 6)
    }

    private static func parseRelFunction(_ s: String, edgeType: GraphEdgeType) -> QueryAST? {
        let inner = extractParens(s).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !inner.isEmpty else { return nil }
        return .graphNeighbors(of: .label(inner), edgeTypes: [edgeType], depth: 1)
    }

    private static func parseNeighborsFunction(_ s: String) -> QueryAST? {
        let inner = extractParens(s).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !inner.isEmpty else { return nil }
        return .graphNeighbors(of: .label(inner), edgeTypes: nil, depth: 1)
    }

    private static func parseSimilarFunction(_ s: String) -> QueryAST? {
        // similar("consciousness", 0.8) or similar("consciousness")
        let inner = extractParens(s)
        let parts = inner.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        guard !parts.isEmpty else { return nil }
        let threshold = parts.count > 1 ? Float(parts[1]) ?? 0.7 : 0.7
        return .semanticSimilar(to: parts[0], threshold: threshold, limit: 10)
    }

    // MARK: - Helpers

    private static func extractParens(_ s: String) -> String {
        guard let open = s.firstIndex(of: "("),
              let close = s.lastIndex(of: ")") else { return s }
        return String(s[s.index(after: open)..<close])
    }

    private static func splitTopLevel(_ s: String, on separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var parenDepth = 0
        var inQuote = false

        for ch in s {
            if ch == "\"" { inQuote.toggle() }
            if !inQuote {
                if ch == "(" { parenDepth += 1 }
                if ch == ")" { parenDepth -= 1 }
            }
            if ch == separator && parenDepth == 0 && !inQuote {
                parts.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}
