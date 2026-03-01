import Foundation

// MARK: - QueryParser
// Converts natural language queries into GraphQueryDSL.
//
// Three-tier parsing (Wave D will add tiers 2 and 3):
//   1. HeuristicQueryParser — regex patterns for common queries. Zero latency.
//   2. (Future) Apple Intelligence — on-device structured output. ~200ms.
//   3. (Future) Cloud LLM fallback — only if on-device fails. ~800ms.
//   4. Ultimate fallback — treat as content search.
//
// Handles ~60% of queries via regex alone. Designed to be extended.

enum QueryParser {

    /// Parse a natural language query into a structured GraphQueryDSL.
    /// Returns nil only if the query is empty.
    static func parse(_ query: String) -> GraphQueryDSL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try heuristic patterns first (zero latency)
        if let result = heuristicParse(trimmed) {
            return result
        }

        // Ultimate fallback: content search
        return .contentSearch(query: trimmed, nodeTypes: nil)
    }

    // MARK: - Heuristic Patterns

    private static func heuristicParse(_ query: String) -> GraphQueryDSL? {
        let q = query.lowercased()

        // ── Aggregation queries ──

        if matches(q, patterns: ["show me all tags", "list all tags", "all tags", "what tags"]) {
            return .findNodes(NodeFilter(types: [.tag]))
        }

        if matches(q, patterns: ["how many notes", "count notes", "note count"]) {
            return .aggregation(.countByType)
        }

        if matches(q, patterns: ["most connected", "hub nodes", "most linked"]) {
            return .aggregation(.mostConnected(limit: 10))
        }

        if matches(q, patterns: ["orphan", "isolated nodes", "unconnected", "no links"]) {
            return .aggregation(.orphans)
        }

        if matches(q, patterns: ["recent notes", "recently created", "newest notes", "latest notes"]) {
            return .aggregation(.recentlyCreated(limit: 20))
        }

        // ── Type-based queries ──

        if matches(q, patterns: ["all notes", "show notes", "list notes"]) {
            return .findNodes(NodeFilter(types: [.note]))
        }

        if matches(q, patterns: ["all ideas", "show ideas", "list ideas"]) {
            return .findNodes(NodeFilter(types: [.idea]))
        }

        if matches(q, patterns: ["all sources", "show sources", "list sources"]) {
            return .findNodes(NodeFilter(types: [.source]))
        }

        if matches(q, patterns: ["all quotes", "show quotes", "list quotes"]) {
            return .findNodes(NodeFilter(types: [.quote]))
        }

        if matches(q, patterns: ["all chats", "show chats", "list chats"]) {
            return .findNodes(NodeFilter(types: [.chat]))
        }

        if matches(q, patterns: ["all blocks", "show blocks", "list blocks"]) {
            return .findNodes(NodeFilter(types: [.block]))
        }

        // ── Relationship queries ──

        // "how is X connected to Y" / "path from X to Y"
        if let (from, to) = extractPathQuery(q) {
            return .pathBetween(from: .label(from), to: .label(to), maxHops: 6)
        }

        // "what supports X" / "evidence for X"
        if let target = extractAfter(q, prefixes: ["what supports", "evidence for", "support for"]) {
            return .neighbors(of: .label(target), edgeTypes: [.supports], depth: 1)
        }

        // "what contradicts X"
        if let target = extractAfter(q, prefixes: ["what contradicts", "contradictions of", "contradicts"]) {
            return .neighbors(of: .label(target), edgeTypes: [.contradicts], depth: 1)
        }

        // "neighbors of X" / "connected to X" / "related to X"
        if let target = extractAfter(q, prefixes: ["neighbors of", "connected to", "related to", "links to", "linked to"]) {
            return .neighbors(of: .label(target), edgeTypes: nil, depth: 1)
        }

        // ── Date-based queries ──

        if let filter = extractDateFilter(q) {
            return .findNodes(filter)
        }

        // ── Tagged queries ──

        // "notes tagged X" / "tagged with X"
        if let tag = extractAfter(q, prefixes: ["notes tagged", "tagged with", "tag:"]) {
            return .compound([
                .findNodes(NodeFilter(types: [.tag], labelContains: tag)),
                .neighbors(of: .label(tag), edgeTypes: [.tagged], depth: 1)
            ], combiner: .union)
        }

        // ── Content search with type filter ──

        // "notes about X" / "notes mentioning X"
        if let topic = extractAfter(q, prefixes: ["notes about", "notes mentioning", "notes on"]) {
            return .contentSearch(query: topic, nodeTypes: [.note])
        }

        // "ideas about X"
        if let topic = extractAfter(q, prefixes: ["ideas about", "ideas on"]) {
            return .contentSearch(query: topic, nodeTypes: [.idea])
        }

        // "find X" / "search for X" / "search X"
        if let topic = extractAfter(q, prefixes: ["find", "search for", "search"]) {
            return .contentSearch(query: topic, nodeTypes: nil)
        }

        // "similar to X"
        if let topic = extractAfter(q, prefixes: ["similar to", "like"]) {
            return .semanticSearch(query: topic, limit: 10)
        }

        return nil
    }

    // MARK: - Helpers

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

    /// Extract date-based filters from queries like "notes from last week"
    private static func extractDateFilter(_ query: String) -> NodeFilter? {
        let now = Date()
        let calendar = Calendar.current

        if query.contains("last week") || query.contains("past week") {
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return NodeFilter(types: [.note], createdAfter: weekAgo)
        }

        if query.contains("last month") || query.contains("past month") {
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return NodeFilter(types: [.note], createdAfter: monthAgo)
        }

        if query.contains("today") {
            let startOfDay = calendar.startOfDay(for: now)
            return NodeFilter(types: [.note], createdAfter: startOfDay)
        }

        if query.contains("yesterday") {
            let startYesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now)!)
            let startToday = calendar.startOfDay(for: now)
            return NodeFilter(types: [.note], createdAfter: startYesterday, createdBefore: startToday)
        }

        return nil
    }
}
