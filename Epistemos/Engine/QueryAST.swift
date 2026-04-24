import Foundation

// MARK: - QueryAST
// Typed query algebra for the knowledge graph.
// Composable via AND/OR/NOT combinators. Projected via limit/offset/orderBy.
// Each leaf maps to a specific backend for execution.

indirect enum QueryAST: Sendable {

    // ── Leaf Queries (each targets a specific backend) ──

    /// Full-text search via FTS5. Scope: pages, blocks, or both.
    case ftsMatch(query: String, scope: SearchScope)

    /// Filter by block/node property (requires BTK for block properties).
    case propertyFilter(key: String, op: CompOp, value: PropertyValue)

    /// Filter by node type (note, idea, source, quote, etc.).
    case typeFilter(types: [GraphNodeType])

    /// Filter by date field.
    case dateFilter(field: DateField, op: CompOp, value: Date)

    /// Filter by block depth in the outline hierarchy (requires BTK).
    case depthFilter(op: CompOp, value: Int)

    /// Graph neighbors traversal.
    case graphNeighbors(of: NodeRef, edgeTypes: [GraphEdgeType]?, depth: Int)

    /// Shortest path between two nodes.
    case graphPath(from: NodeRef, to: NodeRef, maxHops: Int)

    /// Semantic similarity search via embeddings.
    case semanticSimilar(to: String, threshold: Float, limit: Int)

    /// Label/content substring match (fast in-memory scan).
    case labelContains(String)

    // ── Combinators ──

    case and([QueryAST])
    case or([QueryAST])
    case not(QueryAST)

    // ── Projection ──

    case project(QueryAST, limit: Int?, offset: Int?, orderBy: OrderBy?)
}

// MARK: - Supporting Types (defined in QueryTypes.swift)
// SearchScope, CompOp, PropertyValue, and OrderBy are defined in QueryTypes.swift

enum DateField: Sendable {
    case created
    case updated
}
