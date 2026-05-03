import Foundation

// MARK: - QueryPlan Types (Shared with QueryAST)

enum SearchScope: Sendable {
    case pages
    case blocks
    case all
}

enum CompOp: Sendable {
    case eq, neq, lt, gt, lte, gte, contains

    /// Maps to Rust FFI op code: 0=eq, 1=neq, 2=lt, 3=gt, 4=lte, 5=gte, 6=contains
    var ffiCode: UInt8 {
        switch self {
        case .eq: 0
        case .neq: 1
        case .lt: 2
        case .gt: 3
        case .lte: 4
        case .gte: 5
        case .contains: 6
        }
    }
}

enum PropertyValue: Sendable, Equatable {
    case string(String)
    case float(Float)
    case int(Int)
    case bool(Bool)

    /// Returns (val_type, val_str) for FFI. val_type: 0=string, 1=float, 2=int, 3=bool
    var ffiEncoded: (UInt8, String) {
        switch self {
        case .string(let s): (0, s)
        case .float(let f): (1, String(f))
        case .int(let i): (2, String(i))
        case .bool(let b): (3, b ? "true" : "false")
        }
    }
}

enum OrderBy: Sendable {
    case created(ascending: Bool)
    case updated(ascending: Bool)
    case relevance
    case connections
}

// MARK: - NodeFilter

struct NodeFilter: Sendable {
    var types: [GraphNodeType]?
    var labelContains: String?
    var createdAfter: Date?
    var createdBefore: Date?
    var updatedAfter: Date?
    var updatedBefore: Date?
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
    let createdAt: Date
    let updatedAt: Date
    let connectionCount: UInt32
    let score: Float?
    let snippet: String?

    init(
        from record: GraphNodeRecord,
        score: Float? = nil,
        snippet: String? = nil,
        connectionCount: UInt32 = 0
    ) {
        self.id = record.id
        self.label = record.label
        self.type = record.type
        self.sourceId = record.sourceId
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.connectionCount = connectionCount
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

// MARK: - QueryPlan
// Compiled execution plan. Each step targets a specific backend.

struct QueryPlan: Sendable {
    let steps: [QueryStep]
    let subPlans: [QueryPlan]
    let combiner: PlanCombiner
    let limit: Int?
    let offset: Int?
    let orderBy: OrderBy?

    init(steps: [QueryStep], combiner: PlanCombiner) {
        self.steps = steps
        self.subPlans = []
        self.combiner = combiner
        self.limit = nil
        self.offset = nil
        self.orderBy = nil
    }

    init(subPlans: [QueryPlan], combiner: PlanCombiner) {
        self.steps = []
        self.subPlans = subPlans
        self.combiner = combiner
        self.limit = nil
        self.offset = nil
        self.orderBy = nil
    }

    init(inner: QueryPlan, limit: Int?, offset: Int?, orderBy: OrderBy?) {
        self.steps = inner.steps
        self.subPlans = inner.subPlans
        self.combiner = inner.combiner
        self.limit = limit
        self.offset = offset
        self.orderBy = orderBy
    }

    enum QueryStep: Sendable {
        case graphStoreFilter(NodeFilter)
        case graphStoreEdgeFilter(EdgeFilter)
        case graphStorePath(from: NodeRef, to: NodeRef, maxHops: Int)
        case graphStoreNeighbors(of: NodeRef, edgeTypes: [GraphEdgeType]?, depth: Int)
        case fts5Search(query: String, scope: SearchScope)
        case semanticSearch(query: String, threshold: Float, limit: Int)
        case btkPropertyFilter(key: String, op: CompOp, value: PropertyValue)
        case btkDepthFilter(op: CompOp, value: Int)
        case inMemoryLabelFilter(String)
    }

    enum PlanCombiner: Sendable {
        case single        // One step, return directly
        case intersection  // AND: intersect result sets
        case union         // OR: union result sets
        case complement    // NOT: full universe minus matched set
        case sequential    // Steps executed in order, results piped
    }
}

enum QueryDependencyKey: String, CaseIterable, Hashable, Sendable {
    case graphNodes
    case graphEdges
    case searchPages
    case searchBlocks
    case searchReadable

    private static let notificationUserInfoKey = "queryDependencyKeys"

    static func userInfo(for keys: Set<QueryDependencyKey>?) -> [AnyHashable: Any]? {
        guard let keys, !keys.isEmpty else { return nil }
        return [notificationUserInfoKey: keys.map(\.rawValue)]
    }

    static func from(_ notification: Notification) -> Set<QueryDependencyKey>? {
        guard let rawValues = notification.userInfo?[notificationUserInfoKey] as? [String] else {
            return nil
        }
        return Set(rawValues.compactMap(Self.init(rawValue:)))
    }
}

extension QueryPlan {
    var dependencies: Set<QueryDependencyKey> {
        var dependencies = Set(steps.flatMap(\.dependencies))
        for subPlan in subPlans {
            dependencies.formUnion(subPlan.dependencies)
        }
        return dependencies.isEmpty ? Set(QueryDependencyKey.allCases) : dependencies
    }
}

extension QueryPlan.QueryStep {
    var dependencies: Set<QueryDependencyKey> {
        switch self {
        case .graphStoreFilter, .inMemoryLabelFilter, .semanticSearch:
            return [.graphNodes]
        case .graphStoreEdgeFilter, .graphStorePath, .graphStoreNeighbors:
            return [.graphNodes, .graphEdges]
        case .fts5Search(_, let scope):
            switch scope {
            case .pages:
                return [.searchPages]
            case .blocks:
                return [.searchBlocks]
            case .all:
                return [.searchPages, .searchBlocks, .searchReadable]
            }
        case .btkPropertyFilter, .btkDepthFilter:
            return [.graphNodes, .graphEdges]
        }
    }
}
