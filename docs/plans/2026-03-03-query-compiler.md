# Query Compiler Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the regex heuristic `QueryParser` + switch-based `QueryExecutor` with a typed query algebra: `QueryAST` → `QueryCompiler` → `QueryPlan` → `QueryRuntime`. Add structured query syntax (`?` prefix), block-level queries (requires BTK), and reactive subscriptions.

**Architecture:** User input → parser (NL or structured) → `QueryAST` → compiler (index selection, predicate pushdown) → runtime (dispatches to 4 backends: BTK block tree, FTS5, Rust graph engine, embedding store). Reactive queries subscribe to BTK op stream and re-evaluate on change.

**Tech Stack:** Swift (`Engine/`), existing backends (GraphStore, SearchIndexService, GraphState)

**Prerequisite:** BTK (Block Transaction Kernel) must be operational for block-level queries and reactive subscriptions. Page-level queries work without BTK.

---

## What Exists Today

| File | Lines | Role |
|------|-------|------|
| `Epistemos/Models/QueryTypes.swift` | 126 | `GraphQueryDSL` enum (8 variants), `NodeFilter`, `EdgeFilter`, `QueryResult` |
| `Epistemos/Engine/QueryParser.swift` | 219 | Regex heuristic NL parser → `GraphQueryDSL`. ~60% coverage. |
| `Epistemos/Engine/QueryExecutor.swift` | 317 | Switch-based dispatch to GraphStore, SearchIndexService, GraphState |

**What works today:**
- NL queries like "most connected", "notes about X", "path from A to B"
- Type filters, date filters, tag queries, semantic search
- Compound queries with set operations (union/intersection/difference)

**What's missing:**
- No typed AST (the `GraphQueryDSL` enum is a flat dispatch target, not a composable algebra)
- No structured query syntax (power users can't write `?type=note & created:last_week`)
- No block-level queries (FTS5 is page-level only)
- No reactive subscriptions (query results are static snapshots)
- No query compilation/optimization (no predicate pushdown, no index selection)
- No block properties (`?confidence<0.5`, `?tag=claim`)

---

## New Files

```
Epistemos/Engine/
├── QueryAST.swift          # Typed query algebra (indirect enum)
├── QueryCompiler.swift     # AST → QueryPlan (index selection, join ordering)
├── QueryRuntime.swift      # Executes QueryPlan against backends
├── StructuredQueryParser.swift  # Parses ?-prefix structured syntax
└── ReactiveQuery.swift     # AsyncStream wrapper for live query subscriptions
```

**Modified files:**
- `Epistemos/Models/QueryTypes.swift` — add `QueryPlan`, keep `QueryResult`
- `Epistemos/Engine/QueryParser.swift` — upgrade to emit `QueryAST` instead of `GraphQueryDSL`

---

## Task 1: QueryAST Type System

**Files:**
- Create: `Epistemos/Engine/QueryAST.swift`

**Step 1: Define the AST**

```swift
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

// MARK: - Supporting Types

enum SearchScope: Sendable {
    case pages
    case blocks
    case all
}

enum CompOp: Sendable {
    case eq, neq, lt, gt, lte, gte, contains
}

enum PropertyValue: Sendable {
    case string(String)
    case float(Float)
    case int(Int)
    case bool(Bool)
}

enum DateField: Sendable {
    case created
    case updated
}

enum OrderBy: Sendable {
    case created(ascending: Bool)
    case updated(ascending: Bool)
    case relevance
    case connections
}
```

**Step 2: Run build**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Epistemos/Engine/QueryAST.swift
git commit -m "feat(query): add QueryAST typed query algebra"
```

---

## Task 2: Structured Query Parser

**Files:**
- Create: `Epistemos/Engine/StructuredQueryParser.swift`

Parses `?`-prefix queries from the command palette:
- `?type=note & created:last_week` — type filter AND date filter
- `?tag=claim & confidence<0.5` — block property queries
- `?supports("General Relativity")` — graph relationship
- `?"machine learning" & type=block` — FTS + type filter
- `?path("Kant" → "Hegel")` — graph path
- `?similar("consciousness", 0.8)` — semantic search

**Step 1: Write the parser**

```swift
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
        if let match = s.range(of: #"^type=(\w+)$"#, options: .regularExpression) {
            let typeName = String(s[match]).replacingOccurrences(of: "type=", with: "")
            if let nodeType = GraphNodeType.from(displayName: typeName) {
                return .typeFilter(types: [nodeType])
            }
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
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return .dateFilter(field: field, op: .gte, value: calendar.startOfDay(for: yesterday))
        case "last_week", "past_week":
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return .dateFilter(field: field, op: .gte, value: weekAgo)
        case "last_month", "past_month":
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
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
```

**Step 2: Run build**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

**Step 3: Commit**

```bash
git add Epistemos/Engine/StructuredQueryParser.swift
git commit -m "feat(query): add structured query parser (?-prefix syntax)"
```

---

## Task 3: QueryCompiler — AST → Plan

**Files:**
- Create: `Epistemos/Engine/QueryCompiler.swift`
- Modify: `Epistemos/Models/QueryTypes.swift` (add QueryPlan)

**Step 1: Add QueryPlan to QueryTypes.swift**

```swift
// MARK: - QueryPlan
// Compiled execution plan. Each step targets a specific backend.

struct QueryPlan: Sendable {
    let steps: [QueryStep]
    let combiner: PlanCombiner

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
        case difference    // NOT: subtract from first
        case sequential    // Steps executed in order, results piped
    }
}
```

**Step 2: Write the compiler**

```swift
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
            let steps = children.flatMap { compile($0).steps }
            return QueryPlan(steps: steps, combiner: .intersection)

        case .or(let children):
            let steps = children.flatMap { compile($0).steps }
            return QueryPlan(steps: steps, combiner: .union)

        case .not(let inner):
            let innerPlan = compile(inner)
            // NOT: execute inner, then subtract from full node set
            return QueryPlan(steps: innerPlan.steps, combiner: .difference)

        // ── Projection ──

        case .project(let inner, _, _, _):
            // Projection is applied post-execution by the runtime.
            // The compiler just passes through the inner plan.
            return compile(inner)
        }
    }

    // MARK: - Helpers

    private static func makeDateFilter(field: DateField, op: CompOp, value: Date) -> NodeFilter {
        var filter = NodeFilter()
        switch (field, op) {
        case (.created, .gte): filter.createdAfter = value
        case (.created, .lte): filter.createdBefore = value
        case (.created, .gt): filter.createdAfter = value
        case (.created, .lt): filter.createdBefore = value
        case (.updated, .gte): filter.createdAfter = value // TODO: add updatedAfter to NodeFilter
        default: break
        }
        return filter
    }
}
```

**Step 3: Run build**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

**Step 4: Commit**

```bash
git add Epistemos/Engine/QueryCompiler.swift Epistemos/Models/QueryTypes.swift
git commit -m "feat(query): add QueryCompiler (AST → QueryPlan)"
```

---

## Task 4: QueryRuntime — Execute Plans

**Files:**
- Create: `Epistemos/Engine/QueryRuntime.swift`

**Step 1: Write the runtime**

```swift
import Foundation
import QuartzCore

// MARK: - QueryRuntime
// Executes QueryPlan against the appropriate backends.
// Replaces QueryExecutor with plan-based dispatch.

@MainActor
final class QueryRuntime {

    private let graphStore: GraphStore
    private let graphState: GraphState
    private let searchIndex: SearchIndexService

    init(graphStore: GraphStore, graphState: GraphState, searchIndex: SearchIndexService) {
        self.graphStore = graphStore
        self.graphState = graphState
        self.searchIndex = searchIndex
    }

    func execute(_ plan: QueryPlan) -> QueryResult {
        let start = CACurrentMediaTime()

        let result: QueryResult
        if plan.steps.count == 1 && plan.combiner == .single {
            result = executeStep(plan.steps[0])
        } else {
            result = executeCombined(plan)
        }

        let elapsed = (CACurrentMediaTime() - start) * 1000
        return QueryResult(
            nodes: result.nodes,
            edges: result.edges,
            aggregation: result.aggregation,
            executionTimeMs: elapsed
        )
    }

    /// Convenience: parse + compile + execute in one call.
    func query(_ input: String) -> QueryResult {
        let ast: QueryAST?
        if input.hasPrefix("?") {
            ast = StructuredQueryParser.parse(input)
        } else {
            // Use upgraded NL parser (Task 5)
            ast = QueryParser.parseToAST(input)
        }
        guard let ast else { return .empty }
        let plan = QueryCompiler.compile(ast)
        return execute(plan)
    }

    // MARK: - Step Execution

    private func executeStep(_ step: QueryPlan.QueryStep) -> QueryResult {
        switch step {
        case .graphStoreFilter(let filter):
            return executeNodeFilter(filter)

        case .graphStoreEdgeFilter(let filter):
            return executeEdgeFilter(filter)

        case .graphStorePath(let from, let to, let maxHops):
            return executePath(from: from, to: to, maxHops: maxHops)

        case .graphStoreNeighbors(let nodeRef, let edgeTypes, let depth):
            return executeNeighbors(of: nodeRef, edgeTypes: edgeTypes, depth: depth)

        case .fts5Search(let query, let scope):
            return executeFTS(query: query, scope: scope)

        case .semanticSearch(let query, _, let limit):
            return executeSemantic(query: query, limit: limit)

        case .btkPropertyFilter(let key, let op, let value):
            return executeBTKPropertyFilter(key: key, op: op, value: value)

        case .btkDepthFilter(let op, let value):
            return executeBTKDepthFilter(op: op, value: value)

        case .inMemoryLabelFilter(let text):
            return executeLabelFilter(text)
        }
    }

    // MARK: - Combined Execution

    private func executeCombined(_ plan: QueryPlan) -> QueryResult {
        var resultSets: [Set<String>] = []
        var nodeMap: [String: QueryResultNode] = [:]

        for step in plan.steps {
            let result = executeStep(step)
            var idSet = Set<String>()
            for node in result.nodes {
                idSet.insert(node.id)
                nodeMap[node.id] = node
            }
            resultSets.append(idSet)
        }

        guard !resultSets.isEmpty else { return .empty }

        var combined = resultSets[0]
        for i in 1..<resultSets.count {
            switch plan.combiner {
            case .intersection:
                combined = combined.intersection(resultSets[i])
            case .union:
                combined = combined.union(resultSets[i])
            case .difference:
                combined = combined.subtracting(resultSets[i])
            case .single, .sequential:
                break
            }
        }

        let nodes = combined.compactMap { nodeMap[$0] }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    // MARK: - Backend Implementations
    // (These reuse the exact logic from QueryExecutor, just reorganized)

    private func executeNodeFilter(_ filter: NodeFilter) -> QueryResult {
        var results = Array(graphStore.nodes.values)
        if let types = filter.types {
            results = results.filter { types.contains($0.type) }
        }
        if let labelContains = filter.labelContains {
            let lower = labelContains.lowercased()
            results = results.filter { $0.label.lowercased().contains(lower) }
        }
        if let after = filter.createdAfter {
            results = results.filter { $0.createdAt >= after }
        }
        if let before = filter.createdBefore {
            results = results.filter { $0.createdAt <= before }
        }
        results.sort { $0.createdAt > $1.createdAt }
        let nodes = Array(results.prefix(filter.limit)).map { QueryResultNode(from: $0) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeEdgeFilter(_ filter: EdgeFilter) -> QueryResult {
        var results = Array(graphStore.edges.values)
        if let types = filter.types {
            results = results.filter { types.contains($0.type) }
        }
        let edgeResults = Array(results.prefix(filter.limit)).map { edge -> QueryResultEdge in
            QueryResultEdge(
                id: edge.id,
                sourceLabel: graphStore.nodes[edge.sourceNodeId]?.label ?? "?",
                targetLabel: graphStore.nodes[edge.targetNodeId]?.label ?? "?",
                type: edge.type,
                weight: edge.weight
            )
        }
        return QueryResult(nodes: [], edges: edgeResults, aggregation: nil, executionTimeMs: 0)
    }

    private func executePath(from: NodeRef, to: NodeRef, maxHops: Int) -> QueryResult {
        guard let fromId = resolveNodeRef(from),
              let toId = resolveNodeRef(to) else { return .empty }
        let path = graphStore.query(.pathBetween(from: fromId, to: toId, maxHops: maxHops))
        let nodes = path.map { QueryResultNode(from: $0, score: nil) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeNeighbors(of nodeRef: NodeRef, edgeTypes: [GraphEdgeType]?, depth: Int) -> QueryResult {
        guard let nodeId = resolveNodeRef(nodeRef) else { return .empty }
        if let edgeTypes {
            var allNeighbors: [GraphNodeRecord] = []
            for edgeType in edgeTypes {
                allNeighbors.append(contentsOf: graphStore.query(.nodesWithEdgeType(edgeType, from: nodeId)))
            }
            var seen = Set<String>()
            let unique = allNeighbors.filter { seen.insert($0.id).inserted }
            let nodes = unique.map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        } else {
            let connectedIds = graphStore.connected(to: nodeId, maxDepth: depth)
            let nodes = connectedIds
                .compactMap { graphStore.nodes[$0] }
                .filter { $0.id != nodeId }
                .map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        }
    }

    private func executeFTS(query: String, scope: SearchScope) -> QueryResult {
        let results = (try? searchIndex.search(query: query)) ?? []
        var nodes: [QueryResultNode] = []
        for result in results {
            if let graphNode = graphStore.node(bySourceId: result.pageId, type: .note) {
                nodes.append(QueryResultNode(from: graphNode, score: Float(result.rank), snippet: result.snippet))
            }
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeSemantic(query: String, limit: Int) -> QueryResult {
        let hits = graphState.hybridSearch(query: query, limit: limit)
        let nodes = hits.map { QueryResultNode(from: $0.node, score: $0.score) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeBTKPropertyFilter(key: String, op: CompOp, value: PropertyValue) -> QueryResult {
        // TODO: Requires BTK integration. Query block properties via FFI.
        // For now, return empty. Will be wired when BTK is enabled.
        return .empty
    }

    private func executeBTKDepthFilter(op: CompOp, value: Int) -> QueryResult {
        // TODO: Requires BTK integration. Query block depth via FFI.
        return .empty
    }

    private func executeLabelFilter(_ text: String) -> QueryResult {
        let lower = text.lowercased()
        let matches = graphStore.nodes.values.filter {
            $0.label.lowercased().contains(lower)
        }
        let nodes = matches.map { QueryResultNode(from: $0) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func resolveNodeRef(_ ref: NodeRef) -> String? {
        switch ref {
        case .id(let id): return graphStore.nodes[id] != nil ? id : nil
        case .label(let label): return graphStore.fuzzySearch(query: label, limit: 1).first?.id
        case .type(let type): return graphStore.nodes.values.first { $0.type == type }?.id
        }
    }
}
```

**Step 2: Run build**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

**Step 3: Commit**

```bash
git add Epistemos/Engine/QueryRuntime.swift
git commit -m "feat(query): add QueryRuntime (plan-based execution with 4 backends)"
```

---

## Task 5: Upgrade NL Parser to Emit QueryAST

**Files:**
- Modify: `Epistemos/Engine/QueryParser.swift`

**Step 1: Add `parseToAST()` method**

Add a new static method that emits `QueryAST` instead of `GraphQueryDSL`. Keep the existing `parse()` for backwards compatibility until all callers migrate.

```swift
/// Parse natural language into QueryAST (new pipeline).
/// Falls back to FTS match for unrecognized queries.
static func parseToAST(_ query: String) -> QueryAST? {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let q = trimmed.lowercased()

    // Type queries
    if matches(q, patterns: ["all notes", "show notes", "list notes"]) {
        return .typeFilter(types: [.note])
    }
    if matches(q, patterns: ["all ideas", "show ideas", "list ideas"]) {
        return .typeFilter(types: [.idea])
    }
    if matches(q, patterns: ["all sources", "show sources", "list sources"]) {
        return .typeFilter(types: [.source])
    }
    if matches(q, patterns: ["all quotes", "show quotes", "list quotes"]) {
        return .typeFilter(types: [.quote])
    }

    // Relationship queries
    if let (from, to) = extractPathQuery(q) {
        return .graphPath(from: .label(from), to: .label(to), maxHops: 6)
    }
    if let target = extractAfter(q, prefixes: ["what supports", "evidence for"]) {
        return .graphNeighbors(of: .label(target), edgeTypes: [.supports], depth: 1)
    }
    if let target = extractAfter(q, prefixes: ["what contradicts", "contradictions of"]) {
        return .graphNeighbors(of: .label(target), edgeTypes: [.contradicts], depth: 1)
    }
    if let target = extractAfter(q, prefixes: ["neighbors of", "connected to", "related to"]) {
        return .graphNeighbors(of: .label(target), edgeTypes: nil, depth: 1)
    }

    // Date queries
    if q.contains("last week") || q.contains("past week") {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return .and([.typeFilter(types: [.note]), .dateFilter(field: .created, op: .gte, value: weekAgo)])
    }
    if q.contains("today") {
        return .dateFilter(field: .created, op: .gte, value: Calendar.current.startOfDay(for: .now))
    }

    // Semantic search
    if let topic = extractAfter(q, prefixes: ["similar to", "like"]) {
        return .semanticSimilar(to: topic, threshold: 0.7, limit: 10)
    }

    // Content search with type filter
    if let topic = extractAfter(q, prefixes: ["notes about", "notes mentioning"]) {
        return .and([.ftsMatch(query: topic, scope: .pages), .typeFilter(types: [.note])])
    }

    // Generic search
    if let topic = extractAfter(q, prefixes: ["find", "search for", "search"]) {
        return .ftsMatch(query: topic, scope: .all)
    }

    // Fallback: FTS
    return .ftsMatch(query: trimmed, scope: .all)
}
```

**Step 2: Run build**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

**Step 3: Commit**

```bash
git add Epistemos/Engine/QueryParser.swift
git commit -m "feat(query): upgrade NL parser to emit QueryAST"
```

---

## Task 6: Wire Into Command Palette

**Files:**
- Find and modify the command palette query dispatch (likely in `CommandPaletteOverlay.swift` or wherever graph queries are triggered)

**Step 1: Find the current query dispatch**

Search for where `QueryParser.parse()` and `QueryExecutor.execute()` are called. Replace with `QueryRuntime.query()`.

The command palette should detect `?` prefix and route to structured parser automatically — `QueryRuntime.query()` already handles this.

**Step 2: Add `?` hint to command palette placeholder**

If the placeholder text says "Search notes...", change to "Search notes... (? for structured queries)".

**Step 3: Run build and test**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

Manual test:
1. Open command palette
2. Type `?type=note` → should show all notes
3. Type `?created:last_week` → should show recent notes
4. Type `?supports("General Relativity")` → should show supporting nodes
5. Type normal NL query "most connected" → should still work

**Step 4: Commit**

```bash
git commit -m "feat(query): wire QueryRuntime into command palette with structured syntax"
```

---

## Task 7: Reactive Queries (Requires BTK)

**Files:**
- Create: `Epistemos/Engine/ReactiveQuery.swift`

This task depends on BTK being operational. It subscribes to the BTK op stream and re-evaluates queries when relevant blocks change.

**Step 1: Write ReactiveQuery**

```swift
import Foundation

// MARK: - ReactiveQuery
// Wraps a QueryAST + QueryRuntime into a live-updating AsyncStream.
// When BTK ops modify blocks that match the query, re-evaluates and yields new results.

@MainActor
final class ReactiveQuery {

    private let ast: QueryAST
    private let runtime: QueryRuntime
    private var continuation: AsyncStream<QueryResult>.Continuation?
    private var lastResult: QueryResult = .empty
    private var debounceTask: Task<Void, Never>?

    let results: AsyncStream<QueryResult>

    init(ast: QueryAST, runtime: QueryRuntime) {
        self.ast = ast
        self.runtime = runtime

        var continuation: AsyncStream<QueryResult>.Continuation?
        self.results = AsyncStream { continuation = $0 }
        self.continuation = continuation

        // Emit initial result
        let initial = runtime.execute(QueryCompiler.compile(ast))
        self.lastResult = initial
        continuation?.yield(initial)
    }

    /// Called when a BTK op is applied. Debounces re-evaluation to 100ms.
    func onBlockChange() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }
            let plan = QueryCompiler.compile(self.ast)
            let result = self.runtime.execute(plan)
            // Only yield if results actually changed
            if result.nodes.map(\.id) != self.lastResult.nodes.map(\.id) {
                self.lastResult = result
                self.continuation?.yield(result)
            }
        }
    }

    func cancel() {
        debounceTask?.cancel()
        continuation?.finish()
    }

    deinit {
        continuation?.finish()
    }
}
```

**Step 2: Run build**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

**Step 3: Commit**

```bash
git add Epistemos/Engine/ReactiveQuery.swift
git commit -m "feat(query): add ReactiveQuery with 100ms debounced re-evaluation"
```

---

## Exit Criteria

- [ ] `QueryAST` with all leaf/combinator/projection nodes compiles
- [ ] `StructuredQueryParser` handles: `?type=X`, `?created:last_week`, `?key<value`, `?path(A→B)`, `?similar(X)`, `?"quoted FTS"`, AND (`&`) combinations
- [ ] `QueryCompiler` maps AST → QueryPlan with correct backend selection
- [ ] `QueryRuntime` executes plans against all 4 backends (GraphStore, FTS5, GraphState, BTK stubs)
- [ ] NL parser upgraded with `parseToAST()` covering existing patterns
- [ ] Command palette routes `?` to structured parser, NL to upgraded parser
- [ ] `ReactiveQuery` provides AsyncStream with 100ms debounce
- [ ] BTK property filter and depth filter return `.empty` gracefully (wired after BTK ships)
- [ ] All existing NL queries still work (backwards compatible)
- [ ] `xcodebuild build` succeeds
- [ ] `cargo test` all pass (no Rust changes in this plan)

---

## Future Work (Not In This Plan)

These depend on BTK + Query Compiler both being operational:

1. **Block-level FTS5 index** — Index SDBlock content alongside SDPage for `scope: .blocks`
2. **Block property UI** — Right-click block → "Set property..." or inline `@type=claim` syntax
3. **Reactive query views** — SwiftUI views that subscribe to `ReactiveQuery.results`
4. **Query caching** — Cache compiled QueryPlans for repeated queries
5. **Predicate pushdown** — Push type/date filters into FTS5 WHERE clauses
