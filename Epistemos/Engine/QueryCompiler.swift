import Foundation

// MARK: - QueryCompiler
// Compiles QueryAST into an executable QueryPlan.
// Handles: index selection, predicate pushdown, leaf extraction.

enum QueryCompiler {

    static func compile(_ ast: QueryAST) -> QueryPlan {
        switch ast {
        // ── Leaf nodes → single-step plans ──

        case .ftsMatch(let query, let scope):
            return QueryPlan(
                steps: [.fts5Search(query: query, scope: scope)],
                combiner: .single
            )

        case .propertyFilter(let key, let op, let value):
            return QueryPlan(
                steps: [.btkPropertyFilter(key: key, op: op, value: value)],
                combiner: .single
            )

        case .typeFilter(let types):
            return QueryPlan(
                steps: [.graphStoreFilter(NodeFilter(types: types))],
                combiner: .single
            )

        case .dateFilter(let field, let op, let value):
            let filter = makeDateFilter(field: field, op: op, value: value)
            return QueryPlan(
                steps: [.graphStoreFilter(filter)],
                combiner: .single
            )

        case .depthFilter(let op, let value):
            return QueryPlan(
                steps: [.btkDepthFilter(op: op, value: value)],
                combiner: .single
            )

        case .graphNeighbors(let nodeRef, let edgeTypes, let depth):
            return QueryPlan(
                steps: [.graphStoreNeighbors(of: nodeRef, edgeTypes: edgeTypes, depth: depth)],
                combiner: .single
            )

        case .graphPath(let from, let to, let maxHops):
            return QueryPlan(
                steps: [.graphStorePath(from: from, to: to, maxHops: maxHops)],
                combiner: .single
            )

        case .semanticSimilar(let query, let threshold, let limit):
            return QueryPlan(
                steps: [.semanticSearch(query: query, threshold: threshold, limit: limit)],
                combiner: .single
            )

        case .labelContains(let text):
            return QueryPlan(
                steps: [.inMemoryLabelFilter(text)],
                combiner: .single
            )

        // ── Combinators ──

        case .and(let children):
            let subPlans = children.map { compile($0) }
            return QueryPlan(subPlans: subPlans, combiner: .intersection)

        case .or(let children):
            let subPlans = children.map { compile($0) }
            return QueryPlan(subPlans: subPlans, combiner: .union)

        case .not(let inner):
            let innerPlan = compile(inner)
            return QueryPlan(subPlans: [innerPlan], combiner: .complement)

        // ── Projection ──

        case .project(let inner, let limit, let offset, let orderBy):
            let innerPlan = compile(inner)
            return QueryPlan(inner: innerPlan, limit: limit, offset: offset, orderBy: orderBy)
        }
    }

    // MARK: - Helpers

    private static func makeDateFilter(field: DateField, op: CompOp, value: Date) -> NodeFilter {
        var filter = NodeFilter()
        switch (field, op) {
        case (.created, .gte), (.created, .gt): filter.createdAfter = value
        case (.created, .lte), (.created, .lt): filter.createdBefore = value
        case (.updated, .gte), (.updated, .gt): filter.updatedAfter = value
        case (.updated, .lte), (.updated, .lt): filter.updatedBefore = value
        default: break
        }
        return filter
    }
}
