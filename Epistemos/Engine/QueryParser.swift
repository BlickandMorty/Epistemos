import Foundation

// MARK: - QueryParser
// Converts natural language queries into QueryAST.
//
// Three-tier parsing (Wave D will add tiers 2 and 3):
//   1. HeuristicQueryParser — regex patterns for common queries. Zero latency.
//   2. (Future) Apple Intelligence — on-device structured output. ~200ms.
//   3. (Future) Cloud LLM fallback — only if on-device fails. ~800ms.
//   4. Ultimate fallback — treat as FTS search.
//
// Handles ~60% of queries via regex alone. Designed to be extended.

enum QueryParser {

    /// Parse NL query to QueryAST for the compiler pipeline.
    /// Returns nil only if the query is empty.
    static func parseToAST(_ query: String) -> QueryAST? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try heuristic patterns first
        if let result = heuristicParseToAST(trimmed) {
            return result
        }

        // Ultimate fallback: FTS search
        return .ftsMatch(query: trimmed, scope: .all)
    }

    // MARK: - Heuristic Patterns → QueryAST

    private static func heuristicParseToAST(_ query: String) -> QueryAST? {
        let q = query.lowercased()

        // ── Type-based queries ──

        if matches(q, patterns: ["show me all tags", "list all tags", "all tags", "what tags"]) {
            return .typeFilter(types: [.tag])
        }

        if matches(q, patterns: ["all notes", "show notes", "list notes"]) {
            return .typeFilter(types: [.note])
        }

        if matches(q, patterns: ["all ideas", "show ideas", "list ideas"]) {
            return .typeFilter(types: [.idea])
        }

        if matches(q, patterns: ["all chats", "show chats", "list chats"]) {
            return .typeFilter(types: [.chat])
        }

        if matches(q, patterns: ["all blocks", "show blocks", "list blocks"]) {
            return .typeFilter(types: [.block])
        }

        // ── Relationship queries ──

        if let (from, to) = extractPathQuery(q) {
            return .graphPath(from: .label(from), to: .label(to), maxHops: 6)
        }

        if let target = extractAfter(q, prefixes: ["what supports", "evidence for", "support for"]) {
            return .graphNeighbors(of: .label(target), edgeTypes: [.supports], depth: 1)
        }

        if let target = extractAfter(q, prefixes: ["what contradicts", "contradictions of", "contradicts"]) {
            return .graphNeighbors(of: .label(target), edgeTypes: [.contradicts], depth: 1)
        }

        if let target = extractAfter(q, prefixes: ["neighbors of", "connected to", "related to", "links to", "linked to"]) {
            return .graphNeighbors(of: .label(target), edgeTypes: nil, depth: 1)
        }

        // ── Date-based queries ──

        if let dateAST = extractDateFilterAST(q) {
            return dateAST
        }

        // ── Content search with type filter ──

        if let topic = extractAfter(q, prefixes: ["notes about", "notes mentioning", "notes on"]) {
            return .and([.typeFilter(types: [.note]), .ftsMatch(query: topic, scope: .pages)])
        }

        if let topic = extractAfter(q, prefixes: ["ideas about", "ideas on"]) {
            return .and([.typeFilter(types: [.idea]), .ftsMatch(query: topic, scope: .pages)])
        }

        if let topic = extractAfter(q, prefixes: ["find", "search for", "search"]) {
            return .ftsMatch(query: topic, scope: .all)
        }

        if let topic = extractAfter(q, prefixes: ["similar to", "like"]) {
            return .semanticSimilar(to: topic, threshold: 0.7, limit: 10)
        }

        return nil
    }

    // MARK: - Helpers

    private static func extractDateFilterAST(_ query: String) -> QueryAST? {
        let now = Date()
        let calendar = Calendar.current

        if query.contains("last week") || query.contains("past week") {
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
                return nil
            }
            return .and([.typeFilter(types: [.note]), .dateFilter(field: .created, op: .gte, value: weekAgo)])
        }

        if query.contains("last month") || query.contains("past month") {
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
                return nil
            }
            return .and([.typeFilter(types: [.note]), .dateFilter(field: .created, op: .gte, value: monthAgo)])
        }

        if query.contains("today") {
            let startOfDay = calendar.startOfDay(for: now)
            return .and([.typeFilter(types: [.note]), .dateFilter(field: .created, op: .gte, value: startOfDay)])
        }

        if query.contains("yesterday") {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
                return nil
            }
            let startYesterday = calendar.startOfDay(for: yesterday)
            let startToday = calendar.startOfDay(for: now)
            return .and([
                .typeFilter(types: [.note]),
                .dateFilter(field: .created, op: .gte, value: startYesterday),
                .dateFilter(field: .created, op: .lt, value: startToday)
            ])
        }

        return nil
    }

    private static func matches(_ query: String, patterns: [String]) -> Bool {
        patterns.contains { query.contains($0) }
    }

    private static func extractAfter(_ query: String, prefixes: [String]) -> String? {
        for prefix in prefixes {
            if query.hasPrefix(prefix) {
                let remainder = query.dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !remainder.isEmpty { return remainder }
            }
        }
        return nil
    }

    /// Extract "how is X connected to Y" / "path from X to Y" / "connection between X and Y"
    private static func extractPathQuery(_ query: String) -> (String, String)? {
        // "how is X connected to Y"
        let connectedPattern = /how is (.+?) connected to (.+)/
        if let match = try? connectedPattern.firstMatch(in: query) {
            return (String(match.1).trimmingCharacters(in: .whitespaces),
                    String(match.2).trimmingCharacters(in: .whitespaces))
        }

        // "path from X to Y"
        let pathPattern = /path (?:from )?(.+?) to (.+)/
        if let match = try? pathPattern.firstMatch(in: query) {
            return (String(match.1).trimmingCharacters(in: .whitespaces),
                    String(match.2).trimmingCharacters(in: .whitespaces))
        }

        // "connection between X and Y"
        let betweenPattern = /connection(?:s)? between (.+?) and (.+)/
        if let match = try? betweenPattern.firstMatch(in: query) {
            return (String(match.1).trimmingCharacters(in: .whitespaces),
                    String(match.2).trimmingCharacters(in: .whitespaces))
        }

        return nil
    }

}
