import Foundation

// MARK: - GraphQueryDSL
// Structured query language for the knowledge graph.
// Parsed from natural language by QueryParser, executed by QueryExecutor.
//
// Design: Each case maps cleanly to a backend:
//   - findNodes/findEdges → GraphStore in-memory filter
//   - pathBetween/neighbors → GraphStore BFS (already implemented)
//   - contentSearch → SearchIndexService (GRDB FTS5)
//   - semanticSearch → GraphState.hybridSearch (Rust FST + embeddings)
//   - aggregation → in-memory computation over GraphStore
//   - compound → set operations on sub-query results

enum GraphQueryDSL: Sendable {
    case findNodes(NodeFilter)
    case findEdges(EdgeFilter)
    case pathBetween(from: NodeRef, to: NodeRef, maxHops: Int)
    case neighbors(of: NodeRef, edgeTypes: [GraphEdgeType]?, depth: Int)
    case aggregation(AggregationType)
    case contentSearch(query: String, nodeTypes: [GraphNodeType]?)
    case semanticSearch(query: String, limit: Int)
    case compound([GraphQueryDSL], combiner: SetCombiner)
}

// MARK: - NodeFilter

struct NodeFilter: Sendable {
    var types: [GraphNodeType]?
    var labelContains: String?
    var createdAfter: Date?
    var createdBefore: Date?
    var metadata: MetadataFilter?
    var limit: Int = 50
}

// MARK: - EdgeFilter

struct EdgeFilter: Sendable {
    var types: [GraphEdgeType]?
    var involvingNodeRef: NodeRef?
    var limit: Int = 50
}

// MARK: - NodeRef
// Flexible node reference — either a direct ID or a label-based search.

enum NodeRef: Sendable {
    case id(String)
    case label(String)
    case type(GraphNodeType)
}

// MARK: - MetadataFilter

struct MetadataFilter: Sendable {
    var researchStage: Int?
    var hasURL: Bool?
}

// MARK: - AggregationType

enum AggregationType: Sendable {
    case countByType
    case countByEdgeType
    case mostConnected(limit: Int)
    case recentlyCreated(limit: Int)
    case orphans // Nodes with no edges
}

// MARK: - SetCombiner

enum SetCombiner: Sendable {
    case union
    case intersection
    case difference
}

// MARK: - QueryResult

struct QueryResult: Sendable {
    let nodes: [QueryResultNode]
    let edges: [QueryResultEdge]
    let aggregation: QueryAggregation?
    let executionTimeMs: Double

    static let empty = QueryResult(nodes: [], edges: [], aggregation: nil, executionTimeMs: 0)
}

// MARK: - QueryResultNode

struct QueryResultNode: Identifiable, Sendable {
    let id: String
    let label: String
    let type: GraphNodeType
    let sourceId: String?
    let score: Float?
    let snippet: String?

    init(from record: GraphNodeRecord, score: Float? = nil, snippet: String? = nil) {
        self.id = record.id
        self.label = record.label
        self.type = record.type
        self.sourceId = record.sourceId
        self.score = score
        self.snippet = snippet
    }
}

// MARK: - QueryResultEdge

struct QueryResultEdge: Identifiable, Sendable {
    let id: String
    let sourceLabel: String
    let targetLabel: String
    let type: GraphEdgeType
    let weight: Double
}

// MARK: - QueryAggregation

struct QueryAggregation: Sendable {
    let title: String
    let rows: [(label: String, value: Int)]
}
