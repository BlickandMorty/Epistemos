import Foundation

/// Arranges ranked search results in U-curve order to combat the "Lost in the Middle" problem.
/// LLMs attend most to the beginning and end of context, with a valley in the middle.
/// Places highest-relevance items at head and tail positions.
nonisolated enum ContextCompiler {

    /// Reorder items ranked by relevance into U-curve positions.
    /// Top result → position 0, second → last, third → position 1, fourth → second-to-last, etc.
    nonisolated static func uCurveOrder<T>(_ items: [T]) -> [T] {
        guard items.count > 2 else { return items }

        var result = Array<T?>(repeating: nil, count: items.count)
        var headIndex = 0
        var tailIndex = items.count - 1

        for (rank, item) in items.enumerated() {
            if rank.isMultiple(of: 2) {
                result[headIndex] = item
                headIndex += 1
            } else {
                result[tailIndex] = item
                tailIndex -= 1
            }
        }

        return result.compactMap { $0 }
    }

    /// Apply U-curve reordering to MCP tool result strings.
    /// Typically used on vault.search results before returning them to LocalAgent.
    nonisolated static func compileSearchResults(_ results: [String]) -> [String] {
        uCurveOrder(results)
    }
}
