# Knowledge Graph Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a SpriteKit-powered knowledge graph that visualizes all entities in the user's vault (notes, ideas, chats, thinkers, papers, concepts, etc.) with AI entity extraction, a global Ideas Portal, filter pills, and temporal replay — targeting 5,000+ nodes at 60fps.

**Architecture:** Three-layer stack — SwiftData persistence (SDGraphNode/SDGraphEdge), pure-Swift graph engine (in-memory adjacency list, Barnes-Hut force simulation, filter engine, entity extractor), and SwiftUI shell wrapping a SpriteKit viewport with native overlays.

**Tech Stack:** SpriteKit, SwiftData, SwiftUI, Swift Testing, Observation framework, NSPanel/NSWindow.

**Design Doc:** `docs/plans/2026-02-25-knowledge-graph-design.md`

---

## Task 1: Data Models — SDGraphNode & SDGraphEdge

**Files:**
- Create: `Epistemos/Models/SDGraphNode.swift`
- Create: `Epistemos/Models/SDGraphEdge.swift`
- Create: `Epistemos/Models/GraphTypes.swift`
- Modify: `Epistemos/App/AppBootstrap.swift` (ModelContainer registration)
- Create: `EpistemosTests/GraphModelTests.swift`

**Context:** These two SwiftData models are the persistent backbone of the knowledge graph. Every node and edge in the graph is stored here. They use denormalized string FKs (not @Relationship) to enable #Predicate queries — same pattern as SDPageVersion.

**Step 1: Create GraphTypes.swift with enums and supporting types**

```swift
// Epistemos/Models/GraphTypes.swift
import Foundation

// MARK: - Graph Node Types

enum GraphNodeType: String, Codable, Sendable, CaseIterable {
    case note
    case folder
    case idea
    case brainDump
    case chat
    case insight
    case thinker
    case paper
    case book
    case source
    case concept
    case tag
    case quote

    var displayName: String {
        switch self {
        case .note: "Note"
        case .folder: "Folder"
        case .idea: "Idea"
        case .brainDump: "Brain Dump"
        case .chat: "Chat"
        case .insight: "Insight"
        case .thinker: "Thinker"
        case .paper: "Paper"
        case .book: "Book"
        case .source: "Source"
        case .concept: "Concept"
        case .tag: "Tag"
        case .quote: "Quote"
        }
    }

    var icon: String {
        switch self {
        case .note: "doc.text"
        case .folder: "folder"
        case .idea: "lightbulb"
        case .brainDump: "brain"
        case .chat: "bubble.left"
        case .insight: "sparkle"
        case .thinker: "person.bust"
        case .paper: "doc.richtext"
        case .book: "book.closed"
        case .source: "link"
        case .concept: "tag"
        case .tag: "number"
        case .quote: "text.quote"
        }
    }

    var filterKey: Int {
        switch self {
        case .note: 1
        case .idea: 2
        case .paper: 3
        case .thinker: 4
        case .chat: 5
        case .concept: 6
        case .source: 7
        case .insight: 8
        case .quote: 9
        case .brainDump: 0
        case .folder: 0
        case .book: 0
        case .tag: 0
        }
    }
}

// MARK: - Graph Edge Types

enum GraphEdgeType: String, Codable, Sendable {
    case livesIn            // Note -> Folder
    case wikilink           // Note -> Note
    case semanticLink       // Note -> Note (AI-detected)
    case belongsTo          // Idea/BrainDump -> Note
    case ideaLink           // Idea -> Idea (thematic)
    case referenced         // Chat -> Note
    case extractedFrom      // Insight -> Chat
    case relatesTo          // Insight -> Note
    case backedBy           // Insight -> Source
    case authored           // Thinker -> Paper
    case mentionedIn        // Thinker -> Note
    case discussedIn        // Thinker -> Chat
    case said               // Thinker -> Quote
    case citedIn            // Paper -> Note
    case discoveredIn       // Paper -> Chat
    case sharedIn           // Source -> Chat
    case referencedIn       // Source -> Note
    case linksTo            // Source -> Paper
    case appearsIn          // Quote -> Note, Concept -> Note
    case attributedTo       // Quote -> Thinker
    case relatedConcept     // Concept -> Concept
    case exploredIn         // Concept -> Chat
    case tagged             // Tag -> Note
}

// MARK: - Node Metadata (JSON-encoded in SDGraphNode.metadata)

struct GraphNodeMetadata: Codable, Sendable {
    var evidenceGrade: String?      // "A"-"F" for insights
    var researchStage: Int?         // 0-5 for notes
    var url: String?                // For sources
    var authors: [String]?          // For papers/books
    var quoteText: String?          // For quotes
    var year: Int?                  // For papers/books
    var journal: String?            // For papers
    var doi: String?                // For papers
    var abstract: String?           // For papers
    var clusterTheme: String?       // For AI-clustered concepts
    var originChatId: String?       // Provenance: chat ID
    var originNoteId: String?       // Provenance: note ID
}
```

**Step 2: Create SDGraphNode.swift**

```swift
// Epistemos/Models/SDGraphNode.swift
import Foundation
import SwiftData

@Model
final class SDGraphNode {
    #Index<SDGraphNode>([\.id], [\.type], [\.sourceId], [\.label], [\.createdAt])

    var id: String = UUID().uuidString
    var type: String = GraphNodeType.note.rawValue
    var label: String = ""
    var sourceId: String?
    var metadata: Data?
    var weight: Double = 1.0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Transient private var _metadataCache: GraphNodeMetadata?

    var nodeType: GraphNodeType {
        GraphNodeType(rawValue: type) ?? .note
    }

    var meta: GraphNodeMetadata {
        get {
            if let cached = _metadataCache { return cached }
            guard let data = metadata else { return GraphNodeMetadata() }
            let decoded = (try? JSONDecoder().decode(GraphNodeMetadata.self, from: data)) ?? GraphNodeMetadata()
            _metadataCache = decoded
            return decoded
        }
        set {
            _metadataCache = newValue
            metadata = try? JSONEncoder().encode(newValue)
            updatedAt = .now
        }
    }

    init(type: GraphNodeType, label: String, sourceId: String? = nil, weight: Double = 1.0) {
        self.type = type.rawValue
        self.label = label
        self.sourceId = sourceId
        self.weight = weight
    }
}
```

**Step 3: Create SDGraphEdge.swift**

```swift
// Epistemos/Models/SDGraphEdge.swift
import Foundation
import SwiftData

@Model
final class SDGraphEdge {
    #Index<SDGraphEdge>([\.id], [\.sourceNodeId], [\.targetNodeId], [\.type])

    var id: String = UUID().uuidString
    var sourceNodeId: String = ""
    var targetNodeId: String = ""
    var type: String = GraphEdgeType.wikilink.rawValue
    var weight: Double = 1.0
    var createdAt: Date = Date.now

    var edgeType: GraphEdgeType {
        GraphEdgeType(rawValue: type) ?? .wikilink
    }

    init(source: String, target: String, type: GraphEdgeType, weight: Double = 1.0) {
        self.sourceNodeId = source
        self.targetNodeId = target
        self.type = type.rawValue
        self.weight = weight
    }
}
```

**Step 4: Register models in AppBootstrap.swift**

In `AppBootstrap.swift`, add `SDGraphNode.self` and `SDGraphEdge.self` to the ModelContainer `for:` list:

```swift
container = try ModelContainer(
    for: SDPage.self, SDFolder.self,
         SDChat.self, SDMessage.self, SDPageVersion.self,
         SDGraphNode.self, SDGraphEdge.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: false)
)
```

**Step 5: Write tests**

```swift
// EpistemosTests/GraphModelTests.swift
import Testing
import Foundation
@testable import Epistemos

@Suite("Graph Data Models")
struct GraphModelTests {

    @Test("GraphNodeType has 13 cases")
    func nodeTypeCount() {
        #expect(GraphNodeType.allCases.count == 13)
    }

    @Test("SDGraphNode stores and retrieves metadata via JSON cache")
    func nodeMetadata() {
        let node = SDGraphNode(type: .thinker, label: "Nietzsche")
        var meta = GraphNodeMetadata()
        meta.quoteText = "God is dead"
        node.meta = meta
        #expect(node.meta.quoteText == "God is dead")
        #expect(node.metadata != nil)
    }

    @Test("SDGraphNode defaults")
    func nodeDefaults() {
        let node = SDGraphNode(type: .paper, label: "On Truth", sourceId: "abc")
        #expect(node.nodeType == .paper)
        #expect(node.label == "On Truth")
        #expect(node.sourceId == "abc")
        #expect(node.weight == 1.0)
    }

    @Test("SDGraphEdge stores relationship")
    func edgeRelationship() {
        let edge = SDGraphEdge(source: "node-1", target: "node-2", type: .authored, weight: 2.5)
        #expect(edge.sourceNodeId == "node-1")
        #expect(edge.targetNodeId == "node-2")
        #expect(edge.edgeType == .authored)
        #expect(edge.weight == 2.5)
    }

    @Test("GraphNodeType icons are all valid SF Symbol names")
    func nodeTypeIcons() {
        for nodeType in GraphNodeType.allCases {
            #expect(!nodeType.icon.isEmpty)
            #expect(!nodeType.displayName.isEmpty)
        }
    }
}
```

**Step 6: Build and run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`
Run: `xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphModelTests`

Expected: BUILD SUCCEEDED, all tests pass.

**Step 7: Commit**

```bash
git add Epistemos/Models/GraphTypes.swift Epistemos/Models/SDGraphNode.swift Epistemos/Models/SDGraphEdge.swift Epistemos/App/AppBootstrap.swift EpistemosTests/GraphModelTests.swift
git commit -m "feat(graph): add SDGraphNode, SDGraphEdge models and GraphTypes enums"
```

---

## Task 2: Graph Engine — GraphStore & ForceSimulation

**Files:**
- Create: `Epistemos/Graph/GraphStore.swift`
- Create: `Epistemos/Graph/ForceSimulation.swift`
- Create: `EpistemosTests/GraphStoreTests.swift`
- Create: `EpistemosTests/ForceSimulationTests.swift`

**Context:** The graph engine is pure Swift with no UI dependencies. GraphStore holds the in-memory adjacency list loaded from SwiftData. ForceSimulation runs Barnes-Hut force-directed layout on a background thread, publishing position updates that the SpriteKit scene consumes.

**Step 1: Create GraphStore.swift**

```swift
// Epistemos/Graph/GraphStore.swift
import Foundation
import SwiftData

// MARK: - In-Memory Graph Node

struct GraphNodeRecord: Identifiable, Sendable {
    let id: String
    let type: GraphNodeType
    let label: String
    let sourceId: String?
    let metadata: GraphNodeMetadata
    var weight: Double
    let createdAt: Date
    var position: SIMD2<Float> = .zero
    var velocity: SIMD2<Float> = .zero
    var isVisible: Bool = true
    var isPinned: Bool = false
}

// MARK: - In-Memory Graph Edge

struct GraphEdgeRecord: Identifiable, Sendable {
    let id: String
    let sourceNodeId: String
    let targetNodeId: String
    let type: GraphEdgeType
    let weight: Double
    let createdAt: Date
}

// MARK: - Graph Store

@MainActor
final class GraphStore: Observable {
    private(set) var nodes: [String: GraphNodeRecord] = [:]
    private(set) var edges: [String: GraphEdgeRecord] = [:]
    private(set) var adjacency: [String: Set<String>] = [:]  // nodeId -> Set<neighborNodeIds>
    private(set) var edgesByNode: [String: Set<String>] = [] // nodeId -> Set<edgeIds>

    var nodeCount: Int { nodes.count }
    var edgeCount: Int { edges.count }

    // MARK: - Load from SwiftData

    func load(context: ModelContext) {
        let nodeFetch = FetchDescriptor<SDGraphNode>(sortBy: [SortDescriptor(\.createdAt)])
        let edgeFetch = FetchDescriptor<SDGraphEdge>(sortBy: [SortDescriptor(\.createdAt)])

        guard let sdNodes = try? context.fetch(nodeFetch),
              let sdEdges = try? context.fetch(edgeFetch) else { return }

        nodes.removeAll(keepingCapacity: true)
        edges.removeAll(keepingCapacity: true)
        adjacency.removeAll(keepingCapacity: true)
        edgesByNode.removeAll(keepingCapacity: true)

        for sd in sdNodes {
            let record = GraphNodeRecord(
                id: sd.id,
                type: sd.nodeType,
                label: sd.label,
                sourceId: sd.sourceId,
                metadata: sd.meta,
                weight: sd.weight,
                createdAt: sd.createdAt
            )
            nodes[sd.id] = record
            adjacency[sd.id] = []
            edgesByNode[sd.id] = []
        }

        for sd in sdEdges {
            let record = GraphEdgeRecord(
                id: sd.id,
                sourceNodeId: sd.sourceNodeId,
                targetNodeId: sd.targetNodeId,
                type: sd.edgeType,
                weight: sd.weight,
                createdAt: sd.createdAt
            )
            edges[sd.id] = record
            adjacency[sd.sourceNodeId, default: []].insert(sd.targetNodeId)
            adjacency[sd.targetNodeId, default: []].insert(sd.sourceNodeId)
            edgesByNode[sd.sourceNodeId, default: []].insert(sd.id)
            edgesByNode[sd.targetNodeId, default: []].insert(sd.id)
        }

        // Random initial positions for force simulation
        for key in nodes.keys {
            nodes[key]?.position = SIMD2<Float>(
                Float.random(in: -500...500),
                Float.random(in: -500...500)
            )
        }
    }

    // MARK: - Queries

    func neighbors(of nodeId: String) -> [GraphNodeRecord] {
        guard let neighborIds = adjacency[nodeId] else { return [] }
        return neighborIds.compactMap { nodes[$0] }
    }

    func edges(for nodeId: String) -> [GraphEdgeRecord] {
        guard let edgeIds = edgesByNode[nodeId] else { return [] }
        return edgeIds.compactMap { edges[$0] }
    }

    func nodes(ofType type: GraphNodeType) -> [GraphNodeRecord] {
        nodes.values.filter { $0.type == type }
    }

    func node(bySourceId sourceId: String, type: GraphNodeType) -> GraphNodeRecord? {
        nodes.values.first { $0.sourceId == sourceId && $0.type == type }
    }

    /// BFS: all nodes within `depth` hops of `startId`
    func connected(to startId: String, maxDepth: Int = 3) -> Set<String> {
        var visited = Set<String>()
        var queue: [(String, Int)] = [(startId, 0)]
        while !queue.isEmpty {
            let (current, depth) = queue.removeFirst()
            guard depth <= maxDepth, visited.insert(current).inserted else { continue }
            for neighbor in adjacency[current, default: []] {
                if !visited.contains(neighbor) {
                    queue.append((neighbor, depth + 1))
                }
            }
        }
        return visited
    }

    // MARK: - Mutations (called after SwiftData writes)

    func addNode(_ record: GraphNodeRecord) {
        nodes[record.id] = record
        adjacency[record.id] = []
        edgesByNode[record.id] = []
    }

    func addEdge(_ record: GraphEdgeRecord) {
        edges[record.id] = record
        adjacency[record.sourceNodeId, default: []].insert(record.targetNodeId)
        adjacency[record.targetNodeId, default: []].insert(record.sourceNodeId)
        edgesByNode[record.sourceNodeId, default: []].insert(record.id)
        edgesByNode[record.targetNodeId, default: []].insert(record.id)
    }

    func removeNode(_ nodeId: String) {
        nodes.removeValue(forKey: nodeId)
        let edgeIds = edgesByNode.removeValue(forKey: nodeId) ?? []
        for edgeId in edgeIds {
            if let edge = edges.removeValue(forKey: edgeId) {
                adjacency[edge.sourceNodeId]?.remove(edge.targetNodeId)
                adjacency[edge.targetNodeId]?.remove(edge.sourceNodeId)
                edgesByNode[edge.sourceNodeId]?.remove(edgeId)
                edgesByNode[edge.targetNodeId]?.remove(edgeId)
            }
        }
        adjacency.removeValue(forKey: nodeId)
    }

    func updatePosition(_ nodeId: String, position: SIMD2<Float>) {
        nodes[nodeId]?.position = position
    }

    func updateVelocity(_ nodeId: String, velocity: SIMD2<Float>) {
        nodes[nodeId]?.velocity = velocity
    }
}
```

**Step 2: Create ForceSimulation.swift**

```swift
// Epistemos/Graph/ForceSimulation.swift
import Foundation

// MARK: - Force Simulation

/// Barnes-Hut force-directed layout running on a background thread.
/// Publishes position updates that the SpriteKit scene reads at render time.
actor ForceSimulation {
    private var positions: [String: SIMD2<Float>] = [:]
    private var velocities: [String: SIMD2<Float>] = [:]
    private var edges: [(source: String, target: String, weight: Float)] = []
    private var nodeWeights: [String: Float] = [:]

    // Tuning parameters
    private let repulsionStrength: Float = 5000.0
    private let attractionStrength: Float = 0.005
    private let centeringStrength: Float = 0.01
    private let damping: Float = 0.92
    private let minVelocity: Float = 0.1

    private var isRunning = false
    private var isSleeping = false

    // MARK: - Load Topology

    func load(
        nodes: [(id: String, position: SIMD2<Float>, weight: Float)],
        edges: [(source: String, target: String, weight: Float)]
    ) {
        positions.removeAll(keepingCapacity: true)
        velocities.removeAll(keepingCapacity: true)
        self.edges = edges
        nodeWeights.removeAll(keepingCapacity: true)
        for node in nodes {
            positions[node.id] = node.position
            velocities[node.id] = .zero
            nodeWeights[node.id] = node.weight
        }
        isSleeping = false
    }

    // MARK: - Tick (one simulation step)

    func tick() -> [String: SIMD2<Float>] {
        guard !isSleeping else { return positions }

        let ids = Array(positions.keys)
        let count = ids.count
        guard count > 1 else { return positions }

        // 1. Repulsion (Barnes-Hut simplified: direct O(n^2) for < 2000, quad-tree above)
        if count < 2000 {
            directRepulsion(ids: ids)
        } else {
            quadTreeRepulsion(ids: ids)
        }

        // 2. Edge attraction
        for edge in edges {
            guard var pA = positions[edge.source],
                  var pB = positions[edge.target] else { continue }
            let delta = pB - pA
            let dist = max(simd_length(delta), 1.0)
            let force = delta * attractionStrength * edge.weight
            velocities[edge.source, default: .zero] += force
            velocities[edge.target, default: .zero] -= force
        }

        // 3. Centering force
        var centroid = SIMD2<Float>.zero
        for id in ids { centroid += positions[id] ?? .zero }
        centroid /= Float(count)
        for id in ids {
            velocities[id, default: .zero] -= centroid * centeringStrength
        }

        // 4. Apply velocities + damping
        var totalKinetic: Float = 0
        for id in ids {
            velocities[id, default: .zero] *= damping
            let vel = velocities[id] ?? .zero
            positions[id, default: .zero] += vel
            totalKinetic += simd_length_squared(vel)
        }

        // 5. Auto-sleep if settled
        if totalKinetic / Float(count) < minVelocity * minVelocity {
            isSleeping = true
        }

        return positions
    }

    // MARK: - Wake (call when topology changes or user drags)

    func wake() {
        isSleeping = false
    }

    func pinNode(_ id: String, at position: SIMD2<Float>) {
        positions[id] = position
        velocities[id] = .zero
    }

    func updateNodePosition(_ id: String, position: SIMD2<Float>) {
        positions[id] = position
        velocities[id] = .zero
        isSleeping = false
    }

    var sleeping: Bool { isSleeping }

    // MARK: - Direct Repulsion O(n^2)

    private func directRepulsion(ids: [String]) {
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                let idA = ids[i], idB = ids[j]
                guard let pA = positions[idA], let pB = positions[idB] else { continue }
                let delta = pA - pB
                let distSq = max(simd_length_squared(delta), 1.0)
                let force = simd_normalize(delta) * repulsionStrength / distSq
                velocities[idA, default: .zero] += force
                velocities[idB, default: .zero] -= force
            }
        }
    }

    // MARK: - Quad-Tree Repulsion O(n log n) for large graphs

    private func quadTreeRepulsion(ids: [String]) {
        // Build quad tree
        let allPositions = ids.compactMap { id -> (String, SIMD2<Float>)? in
            guard let p = positions[id] else { return nil }
            return (id, p)
        }
        let tree = QuadTree(nodes: allPositions)

        let theta: Float = 0.8  // Barnes-Hut threshold
        for (id, pos) in allPositions {
            let force = tree.calculateForce(on: pos, theta: theta, strength: repulsionStrength)
            velocities[id, default: .zero] += force
        }
    }
}

// MARK: - Quad Tree (Barnes-Hut)

private final class QuadTree {
    struct Bounds {
        var minX: Float, minY: Float, maxX: Float, maxY: Float
        var width: Float { maxX - minX }
        var height: Float { maxY - minY }
        var centerX: Float { (minX + maxX) / 2 }
        var centerY: Float { (minY + maxY) / 2 }
    }

    var bounds: Bounds
    var centerOfMass: SIMD2<Float> = .zero
    var totalMass: Float = 0
    var children: [QuadTree?] = [nil, nil, nil, nil]  // NW, NE, SW, SE
    var nodePosition: SIMD2<Float>?
    var isLeaf: Bool { children.allSatisfy { $0 == nil } }

    init(nodes: [(String, SIMD2<Float>)]) {
        guard !nodes.isEmpty else {
            bounds = Bounds(minX: 0, minY: 0, maxX: 1, maxY: 1)
            return
        }
        var minX: Float = .infinity, minY: Float = .infinity
        var maxX: Float = -.infinity, maxY: Float = -.infinity
        for (_, p) in nodes {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        let pad: Float = 10
        bounds = Bounds(minX: minX - pad, minY: minY - pad, maxX: maxX + pad, maxY: maxY + pad)
        for (_, p) in nodes { insert(p) }
    }

    private init(bounds: Bounds) { self.bounds = bounds }

    func insert(_ point: SIMD2<Float>) {
        totalMass += 1
        centerOfMass = (centerOfMass * (totalMass - 1) + point) / totalMass

        if isLeaf && nodePosition == nil {
            nodePosition = point
            return
        }

        if let existing = nodePosition {
            nodePosition = nil
            insertIntoChild(existing)
        }
        insertIntoChild(point)
    }

    private func insertIntoChild(_ point: SIMD2<Float>) {
        let midX = bounds.centerX, midY = bounds.centerY
        let index: Int
        if point.x < midX {
            index = point.y < midY ? 2 : 0  // SW : NW
        } else {
            index = point.y < midY ? 3 : 1  // SE : NE
        }

        if children[index] == nil {
            let b = bounds
            let childBounds: Bounds
            switch index {
            case 0: childBounds = Bounds(minX: b.minX, minY: midY, maxX: midX, maxY: b.maxY)
            case 1: childBounds = Bounds(minX: midX, minY: midY, maxX: b.maxX, maxY: b.maxY)
            case 2: childBounds = Bounds(minX: b.minX, minY: b.minY, maxX: midX, maxY: midY)
            default: childBounds = Bounds(minX: midX, minY: b.minY, maxX: b.maxX, maxY: midY)
            }
            children[index] = QuadTree(bounds: childBounds)
        }
        children[index]?.insert(point)
    }

    func calculateForce(on point: SIMD2<Float>, theta: Float, strength: Float) -> SIMD2<Float> {
        guard totalMass > 0 else { return .zero }

        let delta = point - centerOfMass
        let distSq = max(simd_length_squared(delta), 1.0)
        let dist = sqrt(distSq)

        // If far enough away, treat as single body
        if isLeaf || bounds.width / dist < theta {
            return simd_normalize(delta) * strength * totalMass / distSq
        }

        // Otherwise recurse into children
        var force = SIMD2<Float>.zero
        for child in children {
            if let child { force += child.calculateForce(on: point, theta: theta, strength: strength) }
        }
        return force
    }
}
```

**Step 3: Write tests**

```swift
// EpistemosTests/GraphStoreTests.swift
import Testing
import Foundation
@testable import Epistemos

@Suite("GraphStore")
@MainActor
struct GraphStoreTests {

    @Test("add and query nodes")
    func addNodes() {
        let store = GraphStore()
        let node = GraphNodeRecord(
            id: "n1", type: .note, label: "My Note", sourceId: "page-1",
            metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now
        )
        store.addNode(node)
        #expect(store.nodeCount == 1)
        #expect(store.nodes(ofType: .note).count == 1)
    }

    @Test("add edges and query neighbors")
    func addEdges() {
        let store = GraphStore()
        store.addNode(GraphNodeRecord(id: "a", type: .note, label: "A", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        store.addNode(GraphNodeRecord(id: "b", type: .thinker, label: "B", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e1", sourceNodeId: "a", targetNodeId: "b", type: .mentionedIn, weight: 1, createdAt: .now))
        #expect(store.neighbors(of: "a").count == 1)
        #expect(store.neighbors(of: "b").count == 1)
        #expect(store.edges(for: "a").count == 1)
    }

    @Test("BFS connected traversal")
    func bfsConnected() {
        let store = GraphStore()
        // Chain: a -> b -> c -> d
        for id in ["a", "b", "c", "d"] {
            store.addNode(GraphNodeRecord(id: id, type: .note, label: id, sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        }
        store.addEdge(GraphEdgeRecord(id: "e1", sourceNodeId: "a", targetNodeId: "b", type: .wikilink, weight: 1, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e2", sourceNodeId: "b", targetNodeId: "c", type: .wikilink, weight: 1, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e3", sourceNodeId: "c", targetNodeId: "d", type: .wikilink, weight: 1, createdAt: .now))

        let depth1 = store.connected(to: "a", maxDepth: 1)
        #expect(depth1.count == 2)  // a, b
        let depth3 = store.connected(to: "a", maxDepth: 3)
        #expect(depth3.count == 4)  // a, b, c, d
    }

    @Test("remove node cleans up edges and adjacency")
    func removeNode() {
        let store = GraphStore()
        store.addNode(GraphNodeRecord(id: "x", type: .note, label: "X", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        store.addNode(GraphNodeRecord(id: "y", type: .note, label: "Y", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e", sourceNodeId: "x", targetNodeId: "y", type: .wikilink, weight: 1, createdAt: .now))
        store.removeNode("x")
        #expect(store.nodeCount == 1)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "y").isEmpty)
    }
}
```

```swift
// EpistemosTests/ForceSimulationTests.swift
import Testing
import Foundation
@testable import Epistemos

@Suite("ForceSimulation")
struct ForceSimulationTests {

    @Test("simulation separates overlapping nodes")
    func separatesNodes() async {
        let sim = ForceSimulation()
        await sim.load(
            nodes: [
                (id: "a", position: SIMD2<Float>(0, 0), weight: 1),
                (id: "b", position: SIMD2<Float>(1, 0), weight: 1),
            ],
            edges: []
        )
        // Run several ticks
        var positions: [String: SIMD2<Float>] = [:]
        for _ in 0..<50 {
            positions = await sim.tick()
        }
        // Nodes should have moved apart
        let dist = simd_distance(positions["a"]!, positions["b"]!)
        #expect(dist > 10)
    }

    @Test("connected nodes attract")
    func attractsConnected() async {
        let sim = ForceSimulation()
        await sim.load(
            nodes: [
                (id: "a", position: SIMD2<Float>(-200, 0), weight: 1),
                (id: "b", position: SIMD2<Float>(200, 0), weight: 1),
            ],
            edges: [(source: "a", target: "b", weight: 5.0)]
        )
        let initial = simd_distance(SIMD2<Float>(-200, 0), SIMD2<Float>(200, 0))
        var positions: [String: SIMD2<Float>] = [:]
        for _ in 0..<100 {
            positions = await sim.tick()
        }
        let final_ = simd_distance(positions["a"]!, positions["b"]!)
        #expect(final_ < initial)
    }

    @Test("simulation auto-sleeps when settled")
    func autoSleeps() async {
        let sim = ForceSimulation()
        await sim.load(
            nodes: [(id: "a", position: .zero, weight: 1)],
            edges: []
        )
        for _ in 0..<200 {
            _ = await sim.tick()
        }
        let sleeping = await sim.sleeping
        #expect(sleeping)
    }
}
```

**Step 4: Build and run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`
Run: `xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphStoreTests -only-testing:EpistemosTests/ForceSimulationTests`

**Step 5: Commit**

```bash
git add Epistemos/Graph/GraphStore.swift Epistemos/Graph/ForceSimulation.swift EpistemosTests/GraphStoreTests.swift EpistemosTests/ForceSimulationTests.swift
git commit -m "feat(graph): add GraphStore adjacency list and ForceSimulation with Barnes-Hut"
```

---

## Task 3: Graph Engine — FilterEngine

**Files:**
- Create: `Epistemos/Graph/FilterEngine.swift`
- Create: `EpistemosTests/FilterEngineTests.swift`

**Context:** The FilterEngine manages which node/edge types are currently visible. It works purely on the in-memory GraphStore — no SwiftData IO. Toggles are O(1). Also supports "show connected to X" via BFS delegation to GraphStore.

**Step 1: Create FilterEngine.swift**

```swift
// Epistemos/Graph/FilterEngine.swift
import Foundation

@MainActor @Observable
final class FilterEngine {
    private(set) var activeNodeTypes: Set<GraphNodeType> = Set(GraphNodeType.allCases)
    private(set) var focusedNodeId: String?
    private(set) var focusedConnected: Set<String>?
    private(set) var timelineDate: Date?

    var isFiltered: Bool {
        activeNodeTypes.count < GraphNodeType.allCases.count || focusedNodeId != nil || timelineDate != nil
    }

    // MARK: - Type Filters

    func toggleType(_ type: GraphNodeType) {
        if activeNodeTypes.contains(type) {
            activeNodeTypes.remove(type)
        } else {
            activeNodeTypes.insert(type)
        }
    }

    func setTypeActive(_ type: GraphNodeType, active: Bool) {
        if active { activeNodeTypes.insert(type) }
        else { activeNodeTypes.remove(type) }
    }

    func showAllTypes() {
        activeNodeTypes = Set(GraphNodeType.allCases)
    }

    func showOnlyType(_ type: GraphNodeType) {
        activeNodeTypes = [type]
    }

    // MARK: - Focus Filter (show connected to X)

    func focusOn(nodeId: String, connectedSet: Set<String>) {
        focusedNodeId = nodeId
        focusedConnected = connectedSet
    }

    func clearFocus() {
        focusedNodeId = nil
        focusedConnected = nil
    }

    // MARK: - Timeline Filter

    func setTimelineDate(_ date: Date?) {
        timelineDate = date
    }

    // MARK: - Visibility Check

    func isNodeVisible(_ node: GraphNodeRecord) -> Bool {
        // Type filter
        guard activeNodeTypes.contains(node.type) else { return false }

        // Focus filter
        if let connected = focusedConnected {
            guard connected.contains(node.id) else { return false }
        }

        // Timeline filter
        if let cutoff = timelineDate {
            guard node.createdAt <= cutoff else { return false }
        }

        return true
    }

    func isEdgeVisible(_ edge: GraphEdgeRecord, sourceVisible: Bool, targetVisible: Bool) -> Bool {
        sourceVisible && targetVisible
    }

    // MARK: - Counts

    func visibleCount(in store: GraphStore) -> [GraphNodeType: Int] {
        var counts: [GraphNodeType: Int] = [:]
        for type in GraphNodeType.allCases {
            counts[type] = store.nodes(ofType: type).filter { isNodeVisible($0) }.count
        }
        return counts
    }

    func totalCount(in store: GraphStore) -> [GraphNodeType: Int] {
        var counts: [GraphNodeType: Int] = [:]
        for type in GraphNodeType.allCases {
            counts[type] = store.nodes(ofType: type).count
        }
        return counts
    }
}
```

**Step 2: Write tests**

```swift
// EpistemosTests/FilterEngineTests.swift
import Testing
import Foundation
@testable import Epistemos

@Suite("FilterEngine")
@MainActor
struct FilterEngineTests {

    private func makeNode(id: String = "n1", type: GraphNodeType = .note, created: Date = .now) -> GraphNodeRecord {
        GraphNodeRecord(id: id, type: type, label: "Test", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: created)
    }

    @Test("all types visible by default")
    func defaultVisibility() {
        let engine = FilterEngine()
        let node = makeNode()
        #expect(engine.isNodeVisible(node))
        #expect(!engine.isFiltered)
    }

    @Test("toggle type hides and shows")
    func toggleType() {
        let engine = FilterEngine()
        engine.toggleType(.note)
        #expect(!engine.isNodeVisible(makeNode(type: .note)))
        #expect(engine.isNodeVisible(makeNode(id: "n2", type: .thinker)))
        engine.toggleType(.note)
        #expect(engine.isNodeVisible(makeNode(type: .note)))
    }

    @Test("show only type isolates one type")
    func showOnlyType() {
        let engine = FilterEngine()
        engine.showOnlyType(.paper)
        #expect(!engine.isNodeVisible(makeNode(type: .note)))
        #expect(engine.isNodeVisible(makeNode(id: "p", type: .paper)))
    }

    @Test("focus filter limits to connected set")
    func focusFilter() {
        let engine = FilterEngine()
        engine.focusOn(nodeId: "center", connectedSet: ["center", "a", "b"])
        #expect(engine.isNodeVisible(makeNode(id: "a")))
        #expect(!engine.isNodeVisible(makeNode(id: "c")))
    }

    @Test("timeline filter hides future nodes")
    func timelineFilter() {
        let engine = FilterEngine()
        let past = Date.now.addingTimeInterval(-86400)
        let future = Date.now.addingTimeInterval(86400)
        engine.setTimelineDate(.now)
        #expect(engine.isNodeVisible(makeNode(created: past)))
        #expect(!engine.isNodeVisible(makeNode(id: "n2", created: future)))
    }

    @Test("edge visible only if both endpoints visible")
    func edgeVisibility() {
        let engine = FilterEngine()
        let edge = GraphEdgeRecord(id: "e", sourceNodeId: "a", targetNodeId: "b", type: .wikilink, weight: 1, createdAt: .now)
        #expect(engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true))
        #expect(!engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: false))
    }
}
```

**Step 3: Build and run tests**

Run: `xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/FilterEngineTests`

**Step 4: Commit**

```bash
git add Epistemos/Graph/FilterEngine.swift EpistemosTests/FilterEngineTests.swift
git commit -m "feat(graph): add FilterEngine with type, focus, and timeline filters"
```

---

## Task 4: SpriteKit Scene — KnowledgeGraphScene

**Files:**
- Create: `Epistemos/Graph/KnowledgeGraphScene.swift`
- Create: `Epistemos/Graph/GraphNodeSprite.swift`

**Context:** This is the SpriteKit scene that renders the graph. It uses viewport culling (only renders nodes visible on screen) and a node pool (reuses SKNode instances). The scene reads positions from ForceSimulation and visibility from FilterEngine.

**Step 1: Create GraphNodeSprite.swift — the reusable SKNode**

```swift
// Epistemos/Graph/GraphNodeSprite.swift
import SpriteKit

/// Reusable sprite representing one graph node.
/// Pooled by KnowledgeGraphScene — assigned/recycled as viewport changes.
final class GraphNodeSprite: SKNode {
    let circle = SKShapeNode(circleOfRadius: 10)
    let iconSprite = SKSpriteNode()
    let labelNode = SKLabelNode()
    let glowNode = SKEffectNode()

    var recordId: String?

    override init() {
        super.init()

        // Circle
        circle.strokeColor = .clear
        circle.lineWidth = 0
        addChild(circle)

        // Icon (centered in circle)
        iconSprite.size = CGSize(width: 12, height: 12)
        iconSprite.position = .zero
        circle.addChild(iconSprite)

        // Label (below circle)
        labelNode.fontSize = 10
        labelNode.fontName = "SF Pro Text"
        labelNode.verticalAlignmentMode = .top
        labelNode.horizontalAlignmentMode = .center
        labelNode.position = CGPoint(x: 0, y: -16)
        addChild(labelNode)

        // Glow (for hover/selection)
        glowNode.shouldRasterize = true
        glowNode.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 8])
        glowNode.alpha = 0
        let glowCircle = SKShapeNode(circleOfRadius: 14)
        glowCircle.fillColor = .white
        glowCircle.strokeColor = .clear
        glowNode.addChild(glowCircle)
        insertChild(glowNode, at: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Configure this sprite for a specific graph node record.
    func configure(record: GraphNodeRecord, color: NSColor, radius: CGFloat, showLabel: Bool) {
        recordId = record.id

        circle.fillColor = color.withAlphaComponent(0.8)
        circle.setScale(radius / 10.0)

        labelNode.text = record.label
        labelNode.fontColor = color
        labelNode.isHidden = !showLabel
        labelNode.position = CGPoint(x: 0, y: -(radius + 4))

        iconSprite.size = CGSize(width: radius, height: radius)

        position = CGPoint(x: CGFloat(record.position.x), y: CGFloat(record.position.y))

        alpha = 1.0
        isHidden = false
    }

    /// Return to pool — clear state.
    func recycle() {
        recordId = nil
        isHidden = true
        alpha = 0
        glowNode.alpha = 0
        removeAllActions()
    }

    func showHoverGlow(color: NSColor) {
        if let glowCircle = glowNode.children.first as? SKShapeNode {
            glowCircle.fillColor = color
        }
        glowNode.run(SKAction.fadeAlpha(to: 0.6, duration: 0.2))
    }

    func hideHoverGlow() {
        glowNode.run(SKAction.fadeAlpha(to: 0, duration: 0.15))
    }

    func pulseSelection() {
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.15)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
        scaleUp.timingMode = .easeOut
        scaleDown.timingMode = .easeIn
        run(SKAction.sequence([scaleUp, scaleDown]))
    }
}
```

**Step 2: Create KnowledgeGraphScene.swift**

```swift
// Epistemos/Graph/KnowledgeGraphScene.swift
import SpriteKit
import Combine

/// The main SpriteKit scene for the knowledge graph.
/// Uses viewport culling + node pooling for 5,000+ node performance.
final class KnowledgeGraphScene: SKScene {

    // External state (set before presenting scene)
    var graphStore: GraphStore?
    var filterEngine: FilterEngine?
    var forceSimulation: ForceSimulation?

    // Callbacks
    var onNodeSelected: ((String) -> Void)?
    var onNodeRightClicked: ((String, CGPoint) -> Void)?
    var onBackgroundClicked: (() -> Void)?

    // Layers
    private let edgeLayer = SKNode()
    private let nodeLayer = SKNode()
    private let cameraNode = SKCameraNode()

    // Node pool
    private var activeSprites: [String: GraphNodeSprite] = [:]
    private var spritePool: [GraphNodeSprite] = []
    private let maxPoolSize = 400

    // Edge pool
    private var activeEdges: [String: SKShapeNode] = [:]
    private var edgePool: [SKShapeNode] = []

    // Interaction state
    private(set) var selectedNodeId: String?
    private var hoveredNodeId: String?
    private var draggedNodeId: String?
    private var lastPanPoint: CGPoint?

    // Simulation loop
    private var simulationTask: Task<Void, Never>?

    // MARK: - Node Type Colors

    static let nodeColors: [GraphNodeType: NSColor] = [
        .note: NSColor.systemBlue,
        .folder: NSColor.systemGray,
        .idea: NSColor.systemYellow,
        .brainDump: NSColor.systemPurple,
        .chat: NSColor.systemGreen,
        .insight: NSColor.systemTeal,
        .thinker: NSColor.systemOrange,
        .paper: NSColor.systemRed,
        .book: NSColor.systemBrown,
        .source: NSColor.systemIndigo,
        .concept: NSColor.systemPink,
        .tag: NSColor.tertiaryLabelColor,
        .quote: NSColor.systemCyan,
    ]

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        addChild(edgeLayer)
        addChild(nodeLayer)

        camera = cameraNode
        addChild(cameraNode)

        // Pre-populate pool
        for _ in 0..<maxPoolSize {
            let sprite = GraphNodeSprite()
            sprite.isHidden = true
            nodeLayer.addChild(sprite)
            spritePool.append(sprite)
        }

        // Start simulation loop
        startSimulationLoop()
    }

    override func willMove(from view: SKView) {
        simulationTask?.cancel()
    }

    // MARK: - Simulation Loop

    private func startSimulationLoop() {
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let sim = self.forceSimulation else {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }
                let positions = await sim.tick()
                await MainActor.run {
                    self.applyPositions(positions)
                    self.updateViewport()
                }
                try? await Task.sleep(for: .milliseconds(33))  // ~30fps physics
            }
        }
    }

    private func applyPositions(_ positions: [String: SIMD2<Float>]) {
        guard let store = graphStore else { return }
        for (id, pos) in positions {
            store.updatePosition(id, position: pos)
        }
    }

    // MARK: - Viewport Culling

    func updateViewport() {
        guard let store = graphStore, let filter = filterEngine else { return }
        guard let view else { return }

        let scale = cameraNode.xScale
        let viewSize = view.bounds.size
        let margin: CGFloat = 100 * scale
        let visibleRect = CGRect(
            x: cameraNode.position.x - (viewSize.width / 2) * scale - margin,
            y: cameraNode.position.y - (viewSize.height / 2) * scale - margin,
            width: (viewSize.width + margin * 2) * scale,
            height: (viewSize.height + margin * 2) * scale
        )

        let showLabels = scale < 1.5
        let showIcons = scale < 2.0

        // Determine which nodes should be visible
        var shouldBeActive = Set<String>()
        for (id, node) in store.nodes {
            guard filter.isNodeVisible(node) else { continue }
            let point = CGPoint(x: CGFloat(node.position.x), y: CGFloat(node.position.y))
            guard visibleRect.contains(point) else { continue }
            shouldBeActive.insert(id)
        }

        // Recycle sprites for nodes that left viewport or became hidden
        let toRecycle = Set(activeSprites.keys).subtracting(shouldBeActive)
        for id in toRecycle {
            if let sprite = activeSprites.removeValue(forKey: id) {
                sprite.recycle()
                spritePool.append(sprite)
            }
        }

        // Assign sprites to newly visible nodes
        let toAssign = shouldBeActive.subtracting(Set(activeSprites.keys))
        for id in toAssign {
            guard let node = store.nodes[id], !spritePool.isEmpty else { continue }
            let sprite = spritePool.removeLast()
            let color = Self.nodeColors[node.type] ?? .labelColor
            let radius = radiusForWeight(node.weight)
            sprite.configure(record: node, color: color, radius: radius, showLabel: showLabels && scale < 1.0)
            activeSprites[id] = sprite
        }

        // Update positions for active sprites
        for (id, sprite) in activeSprites {
            guard let node = store.nodes[id] else { continue }
            let targetPos = CGPoint(x: CGFloat(node.position.x), y: CGFloat(node.position.y))
            sprite.position = targetPos
            sprite.labelNode.isHidden = !showLabels || scale >= 1.0
        }

        // Update edges
        updateEdges(visibleNodes: shouldBeActive, store: store, filter: filter)
    }

    private func radiusForWeight(_ weight: Double) -> CGFloat {
        if weight > 10 { return 22 }
        if weight > 3 { return 14 }
        return 8
    }

    // MARK: - Edge Rendering

    private func updateEdges(visibleNodes: Set<String>, store: GraphStore, filter: FilterEngine) {
        // Recycle all edges and redraw (edges are cheap compared to nodes)
        for (_, edge) in activeEdges {
            edge.isHidden = true
            edgePool.append(edge)
        }
        activeEdges.removeAll()

        for (id, edge) in store.edges {
            let srcVisible = visibleNodes.contains(edge.sourceNodeId)
            let tgtVisible = visibleNodes.contains(edge.targetNodeId)
            guard filter.isEdgeVisible(edge, sourceVisible: srcVisible, targetVisible: tgtVisible) else { continue }

            guard let srcNode = store.nodes[edge.sourceNodeId],
                  let tgtNode = store.nodes[edge.targetNodeId] else { continue }

            let edgeShape: SKShapeNode
            if !edgePool.isEmpty {
                edgeShape = edgePool.removeLast()
            } else {
                edgeShape = SKShapeNode()
                edgeShape.lineWidth = 1
                edgeShape.lineCap = .round
                edgeLayer.addChild(edgeShape)
            }

            let start = CGPoint(x: CGFloat(srcNode.position.x), y: CGFloat(srcNode.position.y))
            let end = CGPoint(x: CGFloat(tgtNode.position.x), y: CGFloat(tgtNode.position.y))

            // Quadratic bezier for organic curves
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let offset = CGFloat(15) * (edge.weight > 1 ? 1.5 : 1.0)
            let control = CGPoint(x: mid.x + offset, y: mid.y + offset)

            let path = CGMutablePath()
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
            edgeShape.path = path

            let color = Self.nodeColors[srcNode.type] ?? .labelColor
            edgeShape.strokeColor = color.withAlphaComponent(0.3)
            edgeShape.lineWidth = CGFloat(0.5 + edge.weight * 0.5)
            edgeShape.isHidden = false
            edgeShape.zPosition = -1

            activeEdges[id] = edgeShape
        }
    }

    // MARK: - Mouse / Trackpad Interaction

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        if let sprite = nodeAt(location) {
            draggedNodeId = sprite.recordId
            selectedNodeId = sprite.recordId
            sprite.pulseSelection()
            if let id = sprite.recordId { onNodeSelected?(id) }
        } else {
            selectedNodeId = nil
            onBackgroundClicked?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)
        if let dragId = draggedNodeId {
            // Move the dragged node
            if let sprite = activeSprites[dragId] {
                sprite.position = location
                let pos = SIMD2<Float>(Float(location.x), Float(location.y))
                graphStore?.updatePosition(dragId, position: pos)
                Task { await forceSimulation?.updateNodePosition(dragId, position: pos) }
            }
        } else {
            // Pan camera
            let delta = CGPoint(x: -event.deltaX * cameraNode.xScale, y: event.deltaY * cameraNode.yScale)
            cameraNode.position = CGPoint(
                x: cameraNode.position.x + delta.x,
                y: cameraNode.position.y + delta.y
            )
        }
    }

    override func mouseUp(with event: NSEvent) {
        draggedNodeId = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        if let sprite = nodeAt(location), let id = sprite.recordId {
            let screenPoint = event.locationInWindow
            onNodeRightClicked?(id, screenPoint)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        let sprite = nodeAt(location)
        let newHoverId = sprite?.recordId

        if newHoverId != hoveredNodeId {
            // Unhover previous
            if let oldId = hoveredNodeId, let oldSprite = activeSprites[oldId] {
                oldSprite.hideHoverGlow()
            }
            // Hover new
            if let newSprite = sprite, let id = newSprite.recordId {
                let node = graphStore?.nodes[id]
                let color = Self.nodeColors[node?.type ?? .note] ?? .labelColor
                newSprite.showHoverGlow(color: color)
            }
            hoveredNodeId = newHoverId
        }
    }

    override func scrollWheel(with event: NSEvent) {
        // Zoom with scroll wheel / pinch
        let zoomDelta = event.magnification != 0 ? event.magnification : -event.deltaY * 0.02
        let newScale = max(0.05, min(5.0, cameraNode.xScale - zoomDelta))
        cameraNode.setScale(newScale)
    }

    override func magnify(with event: NSEvent) {
        let newScale = max(0.05, min(5.0, cameraNode.xScale - event.magnification))
        cameraNode.setScale(newScale)
    }

    private func nodeAt(_ point: CGPoint) -> GraphNodeSprite? {
        let hitNodes = nodes(at: point)
        return hitNodes.compactMap { $0 as? GraphNodeSprite ?? $0.parent as? GraphNodeSprite }.first
    }

    // MARK: - Public API

    func centerOnNode(_ nodeId: String) {
        guard let node = graphStore?.nodes[nodeId] else { return }
        let target = CGPoint(x: CGFloat(node.position.x), y: CGFloat(node.position.y))
        let moveAction = SKAction.move(to: target, duration: 0.4)
        moveAction.timingMode = .easeInEaseOut
        cameraNode.run(moveAction)
    }

    func resetView() {
        let moveAction = SKAction.move(to: .zero, duration: 0.3)
        let scaleAction = SKAction.scale(to: 1.0, duration: 0.3)
        moveAction.timingMode = .easeInEaseOut
        scaleAction.timingMode = .easeInEaseOut
        cameraNode.run(SKAction.group([moveAction, scaleAction]))
    }
}
```

**Step 3: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`

Expected: BUILD SUCCEEDED. (SpriteKit scene + sprite are not easily unit-testable — integration testing comes when the window is wired up.)

**Step 4: Commit**

```bash
git add Epistemos/Graph/GraphNodeSprite.swift Epistemos/Graph/KnowledgeGraphScene.swift
git commit -m "feat(graph): add SpriteKit scene with viewport culling and node pooling"
```

---

## Task 5: Graph Window & SwiftUI Shell

**Files:**
- Create: `Epistemos/Views/Graph/GraphWindowView.swift`
- Create: `Epistemos/Views/Graph/GraphSpriteView.swift`
- Create: `Epistemos/Views/Graph/GraphFilterPills.swift`
- Create: `Epistemos/Views/Graph/GraphTimelineScrubber.swift`
- Create: `Epistemos/Graph/GraphState.swift`
- Modify: `Epistemos/App/UtilityWindowManager.swift` (add `.graph` case)
- Modify: `Epistemos/App/AppBootstrap.swift` (add GraphState to bootstrap)
- Modify: `Epistemos/App/EpistemosApp.swift` (add `.environment(bootstrap.graphState)`)
- Modify: `Epistemos/Views/Landing/CommandPaletteOverlay.swift` (add "Open Knowledge Graph" command)
- Modify: `Epistemos/App/EpistemosApp.swift` (add Cmd+G keyboard shortcut in EpistemosCommands)

**Context:** The graph opens as a utility window via UtilityWindowManager. The SwiftUI shell contains a sidebar (for Ideas Portal and filters), the SpriteKit viewport (wrapped via SpriteView), floating filter pills, and a timeline scrubber. GraphState is the @Observable coordinator that owns the GraphStore, FilterEngine, and ForceSimulation.

**Step 1: Create GraphState.swift — the observable coordinator**

```swift
// Epistemos/Graph/GraphState.swift
import Foundation
import SwiftData
import Observation

@MainActor @Observable
final class GraphState {
    let store = GraphStore()
    let filter = FilterEngine()
    let simulation = ForceSimulation()

    var isLoaded = false
    var isScanning = false
    var scanProgress: Double = 0  // 0.0 - 1.0
    var scanStatus: String = ""
    var selectedNodeId: String?

    // MARK: - Load Graph from SwiftData

    func loadGraph(context: ModelContext) {
        store.load(context: context)

        // Feed topology into simulation
        let simNodes = store.nodes.values.map { node in
            (id: node.id, position: node.position, weight: Float(node.weight))
        }
        let simEdges = store.edges.values.map { edge in
            (source: edge.sourceNodeId, target: edge.targetNodeId, weight: Float(edge.weight))
        }
        Task {
            await simulation.load(nodes: simNodes, edges: simEdges)
        }
        isLoaded = true
    }

    // MARK: - Selection

    func selectNode(_ id: String?) {
        selectedNodeId = id
    }

    var selectedNode: GraphNodeRecord? {
        guard let id = selectedNodeId else { return nil }
        return store.nodes[id]
    }

    // MARK: - Focus

    func focusOnNode(_ nodeId: String, depth: Int = 3) {
        let connected = store.connected(to: nodeId, maxDepth: depth)
        filter.focusOn(nodeId: nodeId, connectedSet: connected)
    }

    func clearFocus() {
        filter.clearFocus()
    }
}
```

**Step 2: Create GraphSpriteView.swift — SpriteKit wrapped for SwiftUI**

```swift
// Epistemos/Views/Graph/GraphSpriteView.swift
import SwiftUI
import SpriteKit

struct GraphSpriteView: NSViewRepresentable {
    let graphState: GraphState

    func makeNSView(context: Context) -> SKView {
        let skView = SKView()
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true

        let scene = KnowledgeGraphScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.graphStore = graphState.store
        scene.filterEngine = graphState.filter
        scene.forceSimulation = graphState.simulation

        scene.onNodeSelected = { id in
            Task { @MainActor in graphState.selectNode(id) }
        }
        scene.onBackgroundClicked = {
            Task { @MainActor in graphState.selectNode(nil) }
        }

        context.coordinator.scene = scene
        skView.presentScene(scene)
        return skView
    }

    func updateNSView(_ skView: SKView, context: Context) {
        context.coordinator.scene?.updateViewport()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: KnowledgeGraphScene?
    }
}
```

**Step 3: Create GraphFilterPills.swift**

```swift
// Epistemos/Views/Graph/GraphFilterPills.swift
import SwiftUI

struct GraphFilterPills: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    private let pillTypes: [GraphNodeType] = [
        .note, .idea, .brainDump, .chat, .insight,
        .thinker, .paper, .book, .source, .concept, .quote, .tag
    ]

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(pillTypes, id: \.self) { type in
                let isActive = graphState.filter.activeNodeTypes.contains(type)
                let count = graphState.store.nodes(ofType: type).count

                Button {
                    withAnimation(Motion.quick) {
                        graphState.filter.toggleType(type)
                    }
                    Task { await graphState.simulation.wake() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 9, weight: .medium))
                        Text("\(count)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(isActive ? .white : theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            isActive
                                ? Color(KnowledgeGraphScene.nodeColors[type] ?? .labelColor)
                                : theme.glassTint.opacity(0.6)
                        )
                    )
                }
                .buttonStyle(.plain)
                .help(type.displayName)
                .accessibilityLabel("\(type.displayName) filter: \(isActive ? "visible" : "hidden"), \(count) nodes")
            }

            if graphState.filter.isFiltered {
                Button {
                    withAnimation(Motion.quick) {
                        graphState.filter.showAllTypes()
                        graphState.filter.clearFocus()
                        graphState.filter.setTimelineDate(nil)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear all filters")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
```

**Step 4: Create GraphTimelineScrubber.swift**

```swift
// Epistemos/Views/Graph/GraphTimelineScrubber.swift
import SwiftUI

struct GraphTimelineScrubber: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @State private var scrubDate: Date = .now
    @State private var isActive = false

    private var theme: EpistemosTheme { ui.theme }

    private var dateRange: ClosedRange<Date> {
        let earliest = graphState.store.nodes.values.map(\.createdAt).min() ?? .now
        return earliest...Date.now
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(Motion.quick) { isActive.toggle() }
                if !isActive {
                    graphState.filter.setTimelineDate(nil)
                }
            } label: {
                Image(systemName: isActive ? "clock.fill" : "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Timeline scrubber")
            .accessibilityLabel("Toggle timeline scrubber")

            if isActive {
                VStack(spacing: 2) {
                    Slider(value: Binding(
                        get: { scrubDate.timeIntervalSince1970 },
                        set: { newValue in
                            scrubDate = Date(timeIntervalSince1970: newValue)
                            graphState.filter.setTimelineDate(scrubDate)
                        }
                    ), in: dateRange.lowerBound.timeIntervalSince1970...dateRange.upperBound.timeIntervalSince1970)
                    .tint(theme.accent)

                    HStack {
                        Text(dateRange.lowerBound, style: .date)
                        Spacer()
                        Text(scrubDate, style: .date)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Now")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
```

**Step 5: Create GraphWindowView.swift — the main graph window layout**

```swift
// Epistemos/Views/Graph/GraphWindowView.swift
import SwiftUI
import SwiftData

struct GraphWindowView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext

    @State private var showSidebar = true
    @State private var sidebarTab: GraphSidebarTab = .ideas

    private var theme: EpistemosTheme { ui.theme }

    enum GraphSidebarTab: String, CaseIterable {
        case ideas = "Ideas"
        case navigate = "Navigate"
        case info = "Info"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if showSidebar {
                graphSidebar
                    .frame(width: 260)

                Rectangle()
                    .fill(theme.glassBorder)
                    .frame(width: 0.5)
            }

            // Main viewport
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    GraphSpriteView(graphState: graphState)
                        .ignoresSafeArea()

                    GraphTimelineScrubber()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                GraphFilterPills()
                    .padding(12)
            }
        }
        .background(theme.background)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    withAnimation(Motion.quick) { showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
                .accessibilityLabel(showSidebar ? "Hide Sidebar" : "Show Sidebar")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    // Reset view
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset View")
                .accessibilityLabel("Reset graph view")
                .keyboardShortcut(" ", modifiers: [])

                Button {
                    graphState.isScanning = true
                    // Trigger vault scan (Task 7)
                } label: {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise")
                }
                .help("Scan Vault")
                .accessibilityLabel("Scan vault for entities")
            }
        }
        .onAppear {
            if !graphState.isLoaded {
                graphState.loadGraph(context: modelContext)
            }
        }
    }

    // MARK: - Sidebar

    private var graphSidebar: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $sidebarTab) {
                ForEach(GraphSidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Rectangle()
                .fill(theme.glassBorder)
                .frame(height: 0.5)

            switch sidebarTab {
            case .ideas:
                Text("Ideas Portal — Task 8")
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .navigate:
                Text("Navigation — Task 8")
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .info:
                if let node = graphState.selectedNode {
                    nodeInfoPanel(node)
                } else {
                    Text("Select a node to see details")
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: - Node Info Panel

    private func nodeInfoPanel(_ node: GraphNodeRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: node.type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Color(KnowledgeGraphScene.nodeColors[node.type] ?? .labelColor))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.label)
                            .font(.epHeadline)
                            .foregroundStyle(theme.foreground)
                        Text(node.type.displayName)
                            .font(.epCaption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Divider()

                // Metadata
                if let grade = node.metadata.evidenceGrade {
                    infoRow("Evidence Grade", grade)
                }
                if let stage = node.metadata.researchStage {
                    infoRow("Research Stage", "\(stage)/5")
                }
                if let url = node.metadata.url {
                    infoRow("URL", url)
                }
                if let authors = node.metadata.authors, !authors.isEmpty {
                    infoRow("Authors", authors.joined(separator: ", "))
                }
                if let quote = node.metadata.quoteText {
                    Text("\"\(quote)\"")
                        .font(.epCaption)
                        .italic()
                        .foregroundStyle(theme.textSecondary)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.glassTint))
                }

                infoRow("Weight", String(format: "%.1f", node.weight))
                infoRow("Created", node.createdAt.formatted(date: .abbreviated, time: .shortened))

                Divider()

                // Connected nodes
                let neighbors = graphState.store.neighbors(of: node.id)
                Text("Connections (\(neighbors.count))")
                    .font(.epCaption)
                    .foregroundStyle(theme.textSecondary)

                ForEach(neighbors.prefix(20), id: \.id) { neighbor in
                    Button {
                        graphState.selectNode(neighbor.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: neighbor.type.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(KnowledgeGraphScene.nodeColors[neighbor.type] ?? .labelColor))
                            Text(neighbor.label)
                                .font(.epCaption)
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
            Spacer()
            Text(value)
                .font(.epCaption)
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
        }
    }
}
```

**Step 6: Wire into UtilityWindowManager**

Add `.graph` case to the `UtilityPanel` enum. Add title `"Knowledge Graph"`, default size `NSSize(width: 1100, height: 700)`, set `usesFullWindow` to `true`. Add the `GraphWindowView()` to the `contentView()` switch. Wire environment objects from AppBootstrap.

**Step 7: Add GraphState to AppBootstrap**

Add `let graphState = GraphState()` alongside the existing state objects. Add `.environment(bootstrap.graphState)` in EpistemosApp.swift.

**Step 8: Add Command Palette entry and Cmd+G shortcut**

In `CommandPaletteOverlay.swift`, add to `makeCommands()`:

```swift
LandingCommandItem(
    id: "open-graph", label: "Open Knowledge Graph", icon: "point.3.connected.trianglepath.dotted",
    category: "Navigate"
) {
    UtilityWindowManager.shared.show(.graph)
    dismiss()
}
```

In `EpistemosCommands`, add:

```swift
Button("Knowledge Graph") { UtilityWindowManager.shared.show(.graph) }
    .keyboardShortcut("g", modifiers: .command)
```

**Step 9: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`

Expected: BUILD SUCCEEDED. Graph window opens via Cmd+G or Command Palette.

**Step 10: Commit**

```bash
git add Epistemos/Graph/GraphState.swift Epistemos/Views/Graph/ Epistemos/App/UtilityWindowManager.swift Epistemos/App/AppBootstrap.swift Epistemos/App/EpistemosApp.swift Epistemos/Views/Landing/CommandPaletteOverlay.swift
git commit -m "feat(graph): add graph window with SpriteKit viewport, filter pills, timeline scrubber"
```

---

## Task 6: Structural Graph Builder — Build Graph from Existing Data

**Files:**
- Create: `Epistemos/Graph/StructuralGraphBuilder.swift`
- Create: `EpistemosTests/StructuralGraphBuilderTests.swift`

**Context:** Before AI extraction, build the "structural" graph from data that already exists: SDPage → SDFolder relationships, nested pages, ideas → notes, tags → notes, chats → notes (via loadedNoteTitles on SDMessage), saved papers → authors. This gives the graph an immediate skeleton without any API calls.

**Step 1: Create StructuralGraphBuilder.swift**

```swift
// Epistemos/Graph/StructuralGraphBuilder.swift
import Foundation
import SwiftData

/// Builds graph nodes/edges from existing structured data — no AI needed.
@MainActor
final class StructuralGraphBuilder {

    func build(context: ModelContext) -> (nodes: [SDGraphNode], edges: [SDGraphEdge]) {
        var nodes: [SDGraphNode] = []
        var edges: [SDGraphEdge] = []
        var existingSourceIds = Set<String>()  // Prevent duplicates

        // 1. Notes
        let pages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []
        for page in pages where !page.isArchived {
            guard existingSourceIds.insert(page.id).inserted else { continue }
            let node = SDGraphNode(type: .note, label: page.title.isEmpty ? "Untitled" : page.title, sourceId: page.id)
            node.weight = Double(max(1, page.wordCount / 100))
            var meta = GraphNodeMetadata()
            meta.researchStage = page.researchStage
            node.meta = meta
            node.createdAt = page.createdAt
            nodes.append(node)

            // Tags → edges
            for tag in page.tags {
                let tagId = "tag-\(tag.lowercased())"
                if !existingSourceIds.contains(tagId) {
                    existingSourceIds.insert(tagId)
                    nodes.append(SDGraphNode(type: .tag, label: tag, sourceId: tagId))
                }
                edges.append(SDGraphEdge(source: tagId, target: node.id, type: .tagged))
            }

            // Ideas → nodes + edges
            for idea in page.ideas {
                let ideaNode = SDGraphNode(
                    type: idea.type == .brainDump ? .brainDump : .idea,
                    label: idea.title,
                    sourceId: idea.id
                )
                ideaNode.createdAt = idea.createdAt
                nodes.append(ideaNode)
                edges.append(SDGraphEdge(source: ideaNode.id, target: node.id, type: .belongsTo))
            }
        }

        // 2. Folders
        let folders = (try? context.fetch(FetchDescriptor<SDFolder>())) ?? []
        for folder in folders {
            guard existingSourceIds.insert("folder-\(folder.id)").inserted else { continue }
            let node = SDGraphNode(type: .folder, label: folder.name, sourceId: folder.id)
            node.createdAt = folder.createdAt
            nodes.append(node)
        }

        // Note → Folder edges
        for page in pages {
            if let folder = page.folder {
                let noteNodeId = nodes.first(where: { $0.sourceId == page.id && $0.nodeType == .note })?.id
                let folderNodeId = nodes.first(where: { $0.sourceId == folder.id && $0.nodeType == .folder })?.id
                if let nid = noteNodeId, let fid = folderNodeId {
                    edges.append(SDGraphEdge(source: nid, target: fid, type: .livesIn))
                }
            }
            // Nested page → parent page
            if let parentId = page.parentPageId {
                let childNodeId = nodes.first(where: { $0.sourceId == page.id && $0.nodeType == .note })?.id
                let parentNodeId = nodes.first(where: { $0.sourceId == parentId && $0.nodeType == .note })?.id
                if let cid = childNodeId, let pid = parentNodeId {
                    edges.append(SDGraphEdge(source: cid, target: pid, type: .wikilink))
                }
            }
        }

        // 3. Chats
        let chats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []
        for chat in chats {
            guard existingSourceIds.insert("chat-\(chat.id)").inserted else { continue }
            let node = SDGraphNode(type: .chat, label: chat.title, sourceId: chat.id)
            node.createdAt = chat.createdAt
            nodes.append(node)

            // Chat → Note edges (from loadedNoteTitles on messages)
            let noteTitles = Set(chat.sortedMessages.compactMap(\.loadedNoteTitles).flatMap { $0 })
            for title in noteTitles {
                if let noteNode = nodes.first(where: { $0.nodeType == .note && $0.label == title }) {
                    edges.append(SDGraphEdge(source: node.id, target: noteNode.id, type: .referenced))
                }
            }
        }

        // 4. Saved Papers (from ResearchState — loaded from UserDefaults)
        // Papers will be added in Task 7 via EntityExtractor since they need ResearchState access

        return (nodes, edges)
    }

    /// Persist built graph into SwiftData
    func persist(nodes: [SDGraphNode], edges: [SDGraphEdge], context: ModelContext) {
        // Clear existing graph
        try? context.delete(model: SDGraphNode.self)
        try? context.delete(model: SDGraphEdge.self)

        for node in nodes { context.insert(node) }
        for edge in edges { context.insert(edge) }
        try? context.save()
    }
}
```

**Step 2: Write tests**

```swift
// EpistemosTests/StructuralGraphBuilderTests.swift
import Testing
import Foundation
@testable import Epistemos

@Suite("StructuralGraphBuilder")
struct StructuralGraphBuilderTests {

    @Test("NoteIdea types map correctly to graph node types")
    func ideaTypeMapping() {
        let idea = NoteIdea(type: .idea, title: "Test", body: "Body")
        let brainDump = NoteIdea(type: .brainDump, title: "Dump", body: "Raw")
        #expect(idea.type == .idea)
        #expect(brainDump.type == .brainDump)
    }

    @Test("GraphNodeType has correct icons for all types")
    func allTypesHaveIcons() {
        for type in GraphNodeType.allCases {
            #expect(!type.icon.isEmpty, "Missing icon for \(type)")
            #expect(!type.displayName.isEmpty, "Missing displayName for \(type)")
        }
    }
}
```

**Step 3: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`

**Step 4: Commit**

```bash
git add Epistemos/Graph/StructuralGraphBuilder.swift EpistemosTests/StructuralGraphBuilderTests.swift
git commit -m "feat(graph): add StructuralGraphBuilder for notes, folders, ideas, chats, tags"
```

---

## Task 7: Entity Extraction — AI Scanning Pipeline

**Files:**
- Create: `Epistemos/Graph/EntityExtractor.swift`
- Create: `Epistemos/Graph/ExtractionTypes.swift`
- Modify: `Epistemos/Graph/GraphState.swift` (add scan methods)

**Context:** The EntityExtractor sends note/chat content to the user's configured LLM and parses structured JSON responses to extract thinkers, concepts, quotes, sources, and insights. It batches 5 notes per call for efficiency. The initial scan processes the entire vault; incremental updates process only changed content.

**Step 1: Create ExtractionTypes.swift**

```swift
// Epistemos/Graph/ExtractionTypes.swift
import Foundation

/// JSON response from LLM entity extraction
struct ExtractionResult: Codable, Sendable {
    var thinkers: [ExtractedThinker]
    var concepts: [ExtractedConcept]
    var quotes: [ExtractedQuote]
    var sources: [ExtractedSource]

    struct ExtractedThinker: Codable, Sendable {
        var name: String
        var role: String?       // "philosopher", "scientist", "author", etc.
        var confidence: Double?  // 0-1
    }

    struct ExtractedConcept: Codable, Sendable {
        var name: String
        var description: String?
    }

    struct ExtractedQuote: Codable, Sendable {
        var text: String
        var attribution: String?
        var context: String?
    }

    struct ExtractedSource: Codable, Sendable {
        var url: String?
        var title: String?
        var type: String?       // "website", "paper", "book", etc.
    }
}

struct InsightExtractionResult: Codable, Sendable {
    var insights: [ExtractedInsight]
    var sourcesShared: [ExtractedSource]
    var thinkersDiscussed: [ExtractedThinker]

    struct ExtractedInsight: Codable, Sendable {
        var summary: String
        var evidenceGrade: String?
        var relatedEntities: [String]
    }

    struct ExtractedThinker: Codable, Sendable {
        var name: String
        var context: String?
    }

    struct ExtractedSource: Codable, Sendable {
        var url: String?
        var title: String?
    }
}
```

**Step 2: Create EntityExtractor.swift**

```swift
// Epistemos/Graph/EntityExtractor.swift
import Foundation
import SwiftData

/// AI-powered entity extraction from notes and chats.
/// Uses the user's configured LLM provider.
@MainActor
final class EntityExtractor {

    private let graphState: GraphState

    init(graphState: GraphState) {
        self.graphState = graphState
    }

    // MARK: - Full Vault Scan

    func scanVault(context: ModelContext, llmService: LLMService) async {
        graphState.isScanning = true
        graphState.scanProgress = 0
        graphState.scanStatus = "Building structural graph..."

        // Step 1: Structural graph (no AI needed)
        let builder = StructuralGraphBuilder()
        let structural = builder.build(context: context)
        builder.persist(nodes: structural.nodes, edges: structural.edges, context: context)
        graphState.loadGraph(context: context)

        // Step 2: AI entity extraction from notes
        let pages = (try? context.fetch(SDPage.activePagesDescriptor)) ?? []
        let totalNotes = pages.count
        let batchSize = 5

        graphState.scanStatus = "Extracting entities from \(totalNotes) notes..."

        for batchStart in stride(from: 0, to: totalNotes, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalNotes)
            let batch = Array(pages[batchStart..<batchEnd])

            let batchContent = batch.enumerated().map { i, page in
                "--- NOTE \(i + 1): \(page.title) ---\n\(page.body.prefix(2000))"
            }.joined(separator: "\n\n")

            let prompt = buildExtractionPrompt(content: batchContent)

            if let result = await extractEntities(prompt: prompt, llmService: llmService) {
                processExtractionResult(result, sourcePages: batch, context: context)
            }

            graphState.scanProgress = Double(batchEnd) / Double(totalNotes) * 0.8
            graphState.scanStatus = "Scanned \(batchEnd)/\(totalNotes) notes..."
        }

        // Step 3: AI entity extraction from chats
        graphState.scanStatus = "Extracting insights from chats..."
        let chats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []
        let significantChats = chats.filter { ($0.messages?.count ?? 0) > 2 }

        for (i, chat) in significantChats.enumerated() {
            let messages = chat.sortedMessages
            let content = messages.map { "\($0.role): \($0.content.prefix(500))" }.joined(separator: "\n")

            let prompt = buildInsightPrompt(content: content, chatTitle: chat.title)

            if let result = await extractInsights(prompt: prompt, llmService: llmService) {
                processInsightResult(result, sourceChat: chat, context: context)
            }

            graphState.scanProgress = 0.8 + (Double(i) / Double(significantChats.count)) * 0.2
        }

        // Step 4: Reload graph with new entities
        graphState.loadGraph(context: context)
        graphState.isScanning = false
        graphState.scanProgress = 1.0
        graphState.scanStatus = "Scan complete"
    }

    // MARK: - Incremental Update (single note)

    func updateNote(_ page: SDPage, context: ModelContext, llmService: LLMService) async {
        let prompt = buildExtractionPrompt(content: "--- NOTE: \(page.title) ---\n\(page.body.prefix(3000))")
        guard let result = await extractEntities(prompt: prompt, llmService: llmService) else { return }

        // Remove old extracted nodes for this page (keep structural nodes)
        let pageNodeId = graphState.store.node(bySourceId: page.id, type: .note)?.id
        if let pid = pageNodeId {
            removeExtractedChildren(of: pid, context: context)
        }

        processExtractionResult(result, sourcePages: [page], context: context)
        graphState.loadGraph(context: context)
    }

    // MARK: - Prompts

    private func buildExtractionPrompt(content: String) -> String {
        """
        Extract entities from the following notes. Return ONLY valid JSON matching this exact schema:
        {
          "thinkers": [{"name": "string", "role": "string or null", "confidence": 0.0-1.0}],
          "concepts": [{"name": "string", "description": "string or null"}],
          "quotes": [{"text": "string", "attribution": "string or null", "context": "string or null"}],
          "sources": [{"url": "string or null", "title": "string or null", "type": "string or null"}]
        }

        Rules:
        - Thinkers: Named real people (philosophers, scientists, authors). NOT the note author.
        - Concepts: Abstract themes/topics that appear substantively (not just mentioned in passing).
        - Quotes: Direct quotations with clear attribution.
        - Sources: URLs, paper titles, or book titles referenced.
        - If no entities found for a category, use empty array [].
        - Deduplicate within the batch (same person = one entry).

        Content:
        \(content)
        """
    }

    private func buildInsightPrompt(content: String, chatTitle: String) -> String {
        """
        Extract key insights from this conversation titled "\(chatTitle)". Return ONLY valid JSON:
        {
          "insights": [{"summary": "string", "evidenceGrade": "A/B/C/D/F or null", "relatedEntities": ["string"]}],
          "sourcesShared": [{"url": "string or null", "title": "string or null"}],
          "thinkersDiscussed": [{"name": "string", "context": "string or null"}]
        }

        Rules:
        - Insights: The 2-4 most significant conclusions or findings.
        - Only extract insights that represent genuine knowledge, not small talk.
        - Evidence grade: A = strong evidence, F = speculation.
        - Related entities: names of people, concepts, or papers mentioned in the insight.

        Conversation:
        \(content)
        """
    }

    // MARK: - LLM Calls

    private func extractEntities(prompt: String, llmService: LLMService) async -> ExtractionResult? {
        do {
            let response = try await llmService.complete(prompt: prompt, maxTokens: 2000)
            return parseJSON(response, as: ExtractionResult.self)
        } catch {
            return nil
        }
    }

    private func extractInsights(prompt: String, llmService: LLMService) async -> InsightExtractionResult? {
        do {
            let response = try await llmService.complete(prompt: prompt, maxTokens: 1500)
            return parseJSON(response, as: InsightExtractionResult.self)
        } catch {
            return nil
        }
    }

    private func parseJSON<T: Decodable>(_ text: String, as type: T.Type) -> T? {
        // Extract JSON from response (may have markdown fences)
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Process Results

    private func processExtractionResult(_ result: ExtractionResult, sourcePages: [SDPage], context: ModelContext) {
        for thinker in result.thinkers {
            let node = findOrCreateNode(type: .thinker, label: thinker.name, context: context)
            if let role = thinker.role {
                var meta = node.meta
                meta.clusterTheme = role
                node.meta = meta
            }

            // Link thinker to each source page
            for page in sourcePages {
                if let noteNode = findNode(sourceId: page.id, type: .note, context: context) {
                    createEdgeIfNeeded(source: node.id, target: noteNode.id, type: .mentionedIn, context: context)
                }
            }
        }

        for concept in result.concepts {
            let node = findOrCreateNode(type: .concept, label: concept.name, context: context)
            if let desc = concept.description {
                var meta = node.meta
                meta.clusterTheme = desc
                node.meta = meta
            }

            for page in sourcePages {
                if let noteNode = findNode(sourceId: page.id, type: .note, context: context) {
                    createEdgeIfNeeded(source: node.id, target: noteNode.id, type: .appearsIn, context: context)
                }
            }
        }

        for quote in result.quotes {
            let node = SDGraphNode(type: .quote, label: quote.text.prefix(60) + (quote.text.count > 60 ? "..." : ""))
            var meta = GraphNodeMetadata()
            meta.quoteText = quote.text
            node.meta = meta
            context.insert(node)

            // Link to attribution (thinker)
            if let attribution = quote.attribution {
                let thinkerNode = findOrCreateNode(type: .thinker, label: attribution, context: context)
                createEdgeIfNeeded(source: node.id, target: thinkerNode.id, type: .attributedTo, context: context)
            }

            // Link to source pages
            for page in sourcePages {
                if let noteNode = findNode(sourceId: page.id, type: .note, context: context) {
                    createEdgeIfNeeded(source: node.id, target: noteNode.id, type: .appearsIn, context: context)
                }
            }
        }

        for source in result.sources where source.url != nil || source.title != nil {
            let label = source.title ?? source.url ?? "Unknown Source"
            let node = findOrCreateNode(type: .source, label: label, context: context)
            if let url = source.url {
                var meta = node.meta
                meta.url = url
                node.meta = meta
            }

            for page in sourcePages {
                if let noteNode = findNode(sourceId: page.id, type: .note, context: context) {
                    createEdgeIfNeeded(source: node.id, target: noteNode.id, type: .referencedIn, context: context)
                }
            }
        }

        try? context.save()
    }

    private func processInsightResult(_ result: InsightExtractionResult, sourceChat: SDChat, context: ModelContext) {
        let chatNode = findNode(sourceId: sourceChat.id, type: .chat, context: context)

        for insight in result.insights {
            let node = SDGraphNode(type: .insight, label: insight.summary.prefix(80) + (insight.summary.count > 80 ? "..." : ""))
            var meta = GraphNodeMetadata()
            meta.evidenceGrade = insight.evidenceGrade
            node.meta = meta
            context.insert(node)

            if let cid = chatNode?.id {
                createEdgeIfNeeded(source: node.id, target: cid, type: .extractedFrom, context: context)
            }
        }

        for thinker in result.thinkersDiscussed {
            let node = findOrCreateNode(type: .thinker, label: thinker.name, context: context)
            if let cid = chatNode?.id {
                createEdgeIfNeeded(source: node.id, target: cid, type: .discussedIn, context: context)
            }
        }

        for source in result.sourcesShared where source.url != nil || source.title != nil {
            let label = source.title ?? source.url ?? "Source"
            let node = findOrCreateNode(type: .source, label: label, context: context)
            if let url = source.url {
                var meta = node.meta
                meta.url = url
                node.meta = meta
            }
            if let cid = chatNode?.id {
                createEdgeIfNeeded(source: node.id, target: cid, type: .sharedIn, context: context)
            }
        }

        try? context.save()
    }

    // MARK: - Deduplication Helpers

    private func findOrCreateNode(type: GraphNodeType, label: String, context: ModelContext) -> SDGraphNode {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try exact match first
        let predicate = #Predicate<SDGraphNode> { node in
            node.type == type.rawValue && node.label == normalizedLabel
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            existing.weight += 1.0  // Increase centrality
            return existing
        }

        // Create new
        let node = SDGraphNode(type: type, label: normalizedLabel)
        context.insert(node)
        return node
    }

    private func findNode(sourceId: String, type: GraphNodeType, context: ModelContext) -> SDGraphNode? {
        let typeRaw = type.rawValue
        let predicate = #Predicate<SDGraphNode> { node in
            node.type == typeRaw && node.sourceId == sourceId
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func createEdgeIfNeeded(source: String, target: String, type: GraphEdgeType, context: ModelContext) {
        let typeRaw = type.rawValue
        let predicate = #Predicate<SDGraphEdge> { edge in
            edge.sourceNodeId == source && edge.targetNodeId == target && edge.type == typeRaw
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if (try? context.fetch(descriptor).first) != nil { return }

        let edge = SDGraphEdge(source: source, target: target, type: type)
        context.insert(edge)
    }

    private func removeExtractedChildren(of nodeId: String, context: ModelContext) {
        // Remove insight, concept, thinker, quote, source nodes that were extracted for this note
        // (Keep structural nodes like ideas and tags which come from StructuralGraphBuilder)
        let extractedTypes: Set<String> = [
            GraphNodeType.thinker.rawValue, GraphNodeType.concept.rawValue,
            GraphNodeType.quote.rawValue, GraphNodeType.source.rawValue,
            GraphNodeType.insight.rawValue
        ]

        // Find edges from this node to extracted types and remove the target nodes
        let predicate = #Predicate<SDGraphEdge> { edge in
            edge.targetNodeId == nodeId || edge.sourceNodeId == nodeId
        }
        let relatedEdges = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []

        for edge in relatedEdges {
            let otherId = edge.sourceNodeId == nodeId ? edge.targetNodeId : edge.sourceNodeId
            let otherPredicate = #Predicate<SDGraphNode> { node in
                node.id == otherId
            }
            if let otherNode = try? context.fetch(FetchDescriptor(predicate: otherPredicate)).first {
                if extractedTypes.contains(otherNode.type) && otherNode.weight <= 1.0 {
                    // Only remove if this was the sole reference
                    context.delete(otherNode)
                }
            }
            context.delete(edge)
        }
    }
}
```

**Step 3: Wire scan into GraphState**

Add to `GraphState.swift`:

```swift
func scanVault(context: ModelContext, llmService: LLMService) {
    Task {
        let extractor = EntityExtractor(graphState: self)
        await extractor.scanVault(context: context, llmService: llmService)
    }
}
```

**Step 4: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`

**Step 5: Commit**

```bash
git add Epistemos/Graph/EntityExtractor.swift Epistemos/Graph/ExtractionTypes.swift Epistemos/Graph/GraphState.swift
git commit -m "feat(graph): add AI entity extraction pipeline with batched scanning and deduplication"
```

---

## Task 8: Ideas Portal — Global Ideas Hub

**Files:**
- Create: `Epistemos/Views/Graph/IdeasPortalView.swift`
- Modify: `Epistemos/Views/Graph/GraphWindowView.swift` (wire Ideas tab in sidebar)

**Context:** The Ideas Portal is the sidebar tab that aggregates all ideas and brain dumps from every note. Three views: By Note (collapsible sections), By Theme (AI-clustered), All Ideas (flat search). Supports create, move, link, delete, jump-to-source, center-in-graph.

**Step 1: Create IdeasPortalView.swift**

This view queries all SDPage objects that have ideas, groups them by note (By Note view), provides flat search (All view), and shows AI-clustered theme groups (By Theme view, populated during scan). Each idea row shows its title, type icon, source note, and action buttons.

Key interactions:
- Click idea → `NoteWindowManager.shared.open(pageId:)` to jump to source
- Option+Click → `graphState.centerOnNode()` to pan graph
- Create "+" button opens a picker to select target note, then appends to that note's ideasData
- Link button: select two ideas → creates SDGraphEdge between them
- Delete: removes from note's ideasData + corresponding graph node

The "By Theme" view reads Concept nodes that have edges to Idea nodes (populated by Task 7's AI clustering).

**Step 2: Wire into GraphWindowView sidebar**

Replace the placeholder `Text("Ideas Portal — Task 8")` with `IdeasPortalView()` in the `case .ideas:` branch.

**Step 3: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`

**Step 4: Commit**

```bash
git add Epistemos/Views/Graph/IdeasPortalView.swift Epistemos/Views/Graph/GraphWindowView.swift
git commit -m "feat(graph): add Ideas Portal with By Note, By Theme, and All Ideas views"
```

---

## Task 9: Radial Context Menu & Keyboard Shortcuts

**Files:**
- Modify: `Epistemos/Graph/KnowledgeGraphScene.swift` (wire right-click to callback)
- Modify: `Epistemos/Views/Graph/GraphWindowView.swift` (NSMenu on right-click, keyboard handlers)

**Context:** Right-clicking a node shows a native NSMenu with: "Show Only Connected," "Open in Editor," "Pin to Center," "Hide This Node." Keyboard shortcuts: Space (reset view), F (focus selected), 1-9 (toggle filter pills), T (toggle timeline).

**Step 1: Build the NSMenu**

In GraphWindowView, receive the `onNodeRightClicked` callback from the SpriteKit scene. Build an `NSMenu` with items:

- "Show Only Connected" → calls `graphState.focusOnNode(nodeId)`
- "Open in Editor" → if node is a note, calls `NoteWindowManager.shared.open(pageId: sourceId)`; if chat, opens chat view
- "Pin to Center" → calls `forceSimulation.pinNode()`
- "Hide This Node" → temporarily removes from visible set
- "Clear Focus" → calls `graphState.clearFocus()`

**Step 2: Add keyboard shortcuts**

Use `.onKeyPress` modifiers on the graph view:
- Space → reset camera view
- F → center camera on selected node
- T → toggle timeline scrubber
- 1-9 → toggle filter pill at that index
- / → focus sidebar search field
- Escape → clear selection and focus

**Step 3: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`

**Step 4: Commit**

```bash
git add Epistemos/Graph/KnowledgeGraphScene.swift Epistemos/Views/Graph/GraphWindowView.swift
git commit -m "feat(graph): add radial context menu and keyboard shortcuts"
```

---

## Task 10: Visual Polish — LOD, Animations, Evidence Grades, Research Stage Glow

**Files:**
- Modify: `Epistemos/Graph/KnowledgeGraphScene.swift` (LOD system, animations)
- Modify: `Epistemos/Graph/GraphNodeSprite.swift` (evidence grade ring, research glow)

**Context:** This task adds the visual refinements that make the graph feel alive. Level-of-detail rendering at different zoom levels, evidence grade gold rings on A-grade insights, research stage glow on mature notes, smooth animations for filter toggle/node appearance/hover.

**Step 1: LOD in KnowledgeGraphScene**

In `updateViewport()`, read `cameraNode.xScale` and adjust rendering:
- `scale > 2.0` → colored dots only (hide labels, hide icons, shrink radius to 3pt)
- `1.0 < scale <= 2.0` → circles with color, labels on hub nodes only (weight > 5)
- `0.5 < scale <= 1.0` → full nodes with icons + labels, hover effects active
- `scale <= 0.5` → large nodes, edge type labels appear

**Step 2: Node appearance animation**

When a sprite is configured (assigned from pool), animate in:
```swift
sprite.setScale(0)
sprite.alpha = 0
sprite.run(SKAction.group([
    SKAction.scale(to: 1.0, duration: 0.3),
    SKAction.fadeIn(withDuration: 0.2)
]))
```

**Step 3: Evidence grade ring**

In `GraphNodeSprite`, add an optional ring `SKShapeNode`:
- If metadata has evidenceGrade == "A", add a thin gold ring (2pt larger than node radius)
- If evidenceGrade == "B", add a thin silver ring
- No ring for C-F

**Step 4: Research stage glow**

If metadata has researchStage >= 4, add a subtle radial glow using `SKEffectNode` with Gaussian blur behind the node circle. Brightness proportional to stage (4 = subtle, 5 = prominent).

**Step 5: Filter toggle animation**

When a node becomes hidden (filter toggled off), animate out:
```swift
sprite.run(SKAction.sequence([
    SKAction.group([
        SKAction.scale(to: 0, duration: 0.3),
        SKAction.fadeOut(withDuration: 0.3)
    ]),
    SKAction.run { sprite.recycle() }
]))
```

**Step 6: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`

**Step 7: Commit**

```bash
git add Epistemos/Graph/KnowledgeGraphScene.swift Epistemos/Graph/GraphNodeSprite.swift
git commit -m "feat(graph): add LOD rendering, evidence grade rings, research glow, animations"
```

---

## Task 11: Integration & Final Wiring

**Files:**
- Modify: `Epistemos/App/AppBootstrap.swift` (wire GraphState, start incremental updates)
- Modify: `Epistemos/Views/Graph/GraphWindowView.swift` (wire scan button to EntityExtractor)
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift` (incremental update on note save)

**Context:** Wire everything together. The scan button in the graph toolbar triggers the full vault scan. When a note is saved, it triggers an incremental graph update. Ensure GraphState is available as an environment object everywhere it's needed.

**Step 1: Wire scan button**

In GraphWindowView's toolbar scan button, call:
```swift
graphState.scanVault(context: modelContext, llmService: llmService)
```

Add `@Environment(LLMService.self) private var llmService` to GraphWindowView.

**Step 2: Incremental updates on note save**

In NoteWindowManager, after a successful save, dispatch:
```swift
if let graphState = AppBootstrap.shared?.graphState {
    Task {
        await EntityExtractor(graphState: graphState)
            .updateNote(page, context: context, llmService: llmService)
    }
}
```

**Step 3: Ensure environment wiring is complete**

Verify that `GraphWindowView` receives all needed environment objects when opened via UtilityWindowManager. The window's content view must be wrapped with `.environment()` for: UIState, GraphState, LLMService, and `.modelContainer()`.

**Step 4: Build and run full test suite**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`
Run: `xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS'`

Expected: BUILD SUCCEEDED, all tests pass.

**Step 5: Commit**

```bash
git add Epistemos/App/AppBootstrap.swift Epistemos/Views/Graph/GraphWindowView.swift Epistemos/Views/Notes/NoteWindowManager.swift
git commit -m "feat(graph): wire scan button, incremental updates on save, environment objects"
```

---

## Task 12: Final Verification

**Files:** None created. Verification only.

**Step 1: Full build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build`
Expected: BUILD SUCCEEDED, 0 warnings in our code.

**Step 2: Full test suite**

Run: `xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS'`
Expected: All tests pass (existing 66 + new graph tests).

**Step 3: Manual verification checklist**

- [ ] Cmd+G opens graph window
- [ ] Command Palette "Knowledge Graph" entry works
- [ ] Graph shows structural nodes (notes, folders, ideas, tags, chats) before AI scan
- [ ] Filter pills toggle node types on/off
- [ ] Timeline scrubber hides future nodes
- [ ] Click node → info panel shows in sidebar
- [ ] Right-click node → context menu with "Show Only Connected," "Open in Editor"
- [ ] Trackpad zoom/pan works smoothly
- [ ] Space resets view, F focuses selected node
- [ ] "Scan Vault" button triggers AI extraction with progress bar
- [ ] After scan: thinkers, concepts, quotes, sources, insights appear as nodes
- [ ] Ideas Portal shows all ideas grouped By Note and By Theme
- [ ] Hover glow and selection pulse animations work
- [ ] Performance: graph stays responsive with 500+ nodes

**Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "feat(graph): final verification pass — knowledge graph complete"
```
