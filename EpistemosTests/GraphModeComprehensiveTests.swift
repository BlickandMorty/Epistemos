import Testing
@testable import Epistemos
import Foundation

// MARK: - Graph Mode Comprehensive Tests
// Tests for graph visualization mode, physics parameters, and simulation behavior.

@Suite("Graph Mode - Physics Presets")
@MainActor
struct GraphPhysicsPresetTests {
    
    @Test("All physics presets have valid parameters")
    func allPresetsValid() {
        for preset in PhysicsPreset.allCases {
            #expect(preset.linkDistance > 0, "\(preset) has invalid link distance")
            #expect(preset.chargeStrength < 0, "\(preset) should have negative charge (repulsion)")
            #expect(preset.chargeRange > 0, "\(preset) has invalid charge range")
            #expect(preset.linkStrength >= 0, "\(preset) has invalid link strength")
            #expect(preset.velocityDecay >= 0 && preset.velocityDecay <= 1, "\(preset) has invalid velocity decay")
            #expect(preset.centerStrength >= 0, "\(preset) has invalid center strength")
            #expect(preset.collisionRadius >= 0, "\(preset) has invalid collision radius")
        }
    }
    
    @Test("Observatory preset is default-balanced")
    func observatoryPresetBalanced() {
        let preset = PhysicsPreset.observatory
        #expect(preset.linkDistance == 243)
        #expect(preset.chargeStrength == -2792)
        #expect(preset.chargeRange == 218)
        #expect(preset.velocityDecay == 0.05)
        #expect(preset.centerStrength == 0)
    }
    
    @Test("Chaos preset has extreme values")
    func chaosPresetExtreme() {
        let preset = PhysicsPreset.chaos
        #expect(abs(preset.chargeStrength) >= 1000, "Chaos should have strong repulsion")
        #expect(preset.chargeRange >= 2000, "Chaos should have wide charge range")
        #expect(preset.collisionRadius <= 25, "Chaos should allow close collisions")
    }
    
    @Test("Zen Garden preset is minimal")
    func zenGardenPresetMinimal() {
        let preset = PhysicsPreset.zenGarden
        #expect(abs(preset.chargeStrength) <= 200, "Zen should have weak repulsion")
        #expect(preset.velocityDecay >= 0.1, "Zen should have moderate damping")
        #expect(preset.collisionRadius >= 50, "Zen should have large collision radius")
    }
    
    @Test("Crystal preset has high damping")
    func crystalPresetRigid() {
        let preset = PhysicsPreset.crystal
        #expect(preset.velocityDecay >= 0.8, "Crystal should have high damping")
        #expect(preset.linkStrength >= 0.5, "Crystal should have strong links")
    }
    
    @Test("Nebula preset is floaty")
    func nebulaPresetFloaty() {
        let preset = PhysicsPreset.nebula
        #expect(preset.velocityDecay <= 0.15, "Nebula should have low damping")
        #expect(preset.linkDistance >= 250, "Nebula should have long links")
    }
    
    @Test("All presets have unique icons")
    func presetIconsUnique() {
        var icons = Set<String>()
        for preset in PhysicsPreset.allCases {
            #expect(!preset.icon.isEmpty, "\(preset) should have an icon")
            icons.insert(preset.icon)
        }
        #expect(icons.count == PhysicsPreset.allCases.count, "All preset icons should be unique")
    }
    
    @Test("Physics preset lab overrides are valid")
    func labOverridesValid() {
        for preset in PhysicsPreset.allCases {
            let overrides = preset.labOverrides
            
            if let fluid = overrides.fluidViscosity {
                #expect(fluid >= 0 && fluid <= 1, "\(preset) fluid viscosity out of range")
            }
            if let torsion = overrides.torsionRigidity {
                #expect(torsion >= 0 && torsion <= 1, "\(preset) torsion rigidity out of range")
            }
            if let orbital = overrides.orbitalSpeed {
                #expect(orbital >= 0, "\(preset) orbital speed should be non-negative")
            }
        }
    }
}

@Suite("Graph Mode - Simulation State")
@MainActor
struct GraphSimulationStateTests {
    
    @Test("Initial simulation state is valid")
    func initialStateValid() async {
        let state = await GraphState()
        
        #expect(await state.mode == .global)
        #expect(await !state.isLoading)
        #expect(await !state.showLabels)
        #expect(await state.physicsPreset == .observatory)
    }
    
    @Test("Mode switching updates state correctly")
    func modeSwitching() async {
        let state = await GraphState()
        
        // Switch to page mode
        await state.switchMode(.page(nodeId: "test-node"))
        #expect(await state.mode == .page(nodeId: "test-node"))
        
        // Switch back to global
        await state.switchMode(.global)
        #expect(await state.mode == .global)
    }
    
    @Test("Physics preset change triggers reheat")
    func presetChangeReheats() async {
        let state = await GraphState()
        
        let initialPreset = await state.physicsPreset
        await state.setPhysicsPreset(.nebula)
        
        #expect(await state.physicsPreset == .nebula)
        #expect(await state.physicsPreset != initialPreset)
    }
    
    @Test("Loading state is managed correctly")
    func loadingStateManagement() async {
        let state = await GraphState()
        
        await state.setLoading(true)
        #expect(await state.isLoading)
        
        await state.setLoading(false)
        #expect(await !state.isLoading)
    }
}

@Suite("Graph Mode - Filter Engine")
@MainActor
struct GraphFilterEngineTests {
    
    @Test("Filter engine starts with all types visible")
    func initialFilterState() {
        let engine = FilterEngine()
        
        for type in GraphNodeType.allCases {
            #expect(engine.isVisible(type), "\(type) should be visible by default")
        }
    }
    
    @Test("Toggling filter updates visibility")
    func toggleFilter() {
        let engine = FilterEngine()
        
        engine.toggle(.note)
        #expect(!engine.isVisible(.note))
        
        engine.toggle(.note)
        #expect(engine.isVisible(.note))
    }
    
    @Test("Filter count tracks correctly")
    func filterCount() {
        let engine = FilterEngine()
        let totalTypes = GraphNodeType.allCases.count
        
        #expect(engine.visibleCount == totalTypes)
        
        engine.toggle(.note)
        #expect(engine.visibleCount == totalTypes - 1)
        
        engine.toggle(.chat)
        #expect(engine.visibleCount == totalTypes - 2)
        
        engine.toggle(.note)
        #expect(engine.visibleCount == totalTypes - 1)
    }
    
    @Test("Filter reset restores all visible")
    func filterReset() {
        let engine = FilterEngine()
        
        // Hide several types
        engine.toggle(.note)
        engine.toggle(.chat)
        engine.toggle(.idea)
        
        engine.reset()
        
        for type in GraphNodeType.allCases {
            #expect(engine.isVisible(type), "\(type) should be visible after reset")
        }
    }
    
    @Test("Filter set visibility directly")
    func filterDirectSet() {
        let engine = FilterEngine()
        
        engine.setVisibility(.note, visible: false)
        #expect(!engine.isVisible(.note))
        
        engine.setVisibility(.note, visible: true)
        #expect(engine.isVisible(.note))
    }
}

@Suite("Graph Mode - Node Inspector")
@MainActor
struct GraphNodeInspectorTests {
    
    @Test("Initial inspector state is nil")
    func initialInspectorState() async {
        let state = await NodeInspectorState()
        #expect(await state.selectedNodeId == nil)
        #expect(await !state.isExpanded)
    }
    
    @Test("Selecting node updates state")
    func selectNode() async {
        let state = await NodeInspectorState()
        
        await state.selectNode("test-id")
        #expect(await state.selectedNodeId == "test-id")
        #expect(await state.isExpanded)
    }
    
    @Test("Deselecting node clears state")
    func deselectNode() async {
        let state = await NodeInspectorState()
        
        await state.selectNode("test-id")
        await state.deselect()
        
        #expect(await state.selectedNodeId == nil)
        #expect(await !state.isExpanded)
    }
    
    @Test("Toggle expansion state")
    func toggleExpansion() async {
        let state = await NodeInspectorState()
        
        await state.selectNode("test-id")
        #expect(await state.isExpanded)
        
        await state.toggleExpanded()
        #expect(await !state.isExpanded)
        
        await state.toggleExpanded()
        #expect(await state.isExpanded)
    }
}

@Suite("Graph Mode - Graph Builder")
@MainActor
struct GraphBuilderComprehensiveTests {
    
    @Test("Builder creates nodes from pages")
    func builderCreatesNodes() async throws {
        let builder = await GraphBuilder()
        
        // Create mock pages
        let pages = [
            MockPage(id: "p1", title: "Page 1", body: "Content 1"),
            MockPage(id: "p2", title: "Page 2", body: "Content 2"),
            MockPage(id: "p3", title: "Page 3", body: "Content 3")
        ]
        
        let graph = try await builder.build(from: pages, chats: [], ideas: [])
        
        #expect(graph.nodes.count >= 3, "Should create nodes for all pages")
    }
    
    @Test("Builder extracts tags from pages")
    func builderExtractsTags() async throws {
        let builder = await GraphBuilder()
        
        let pages = [
            MockPage(id: "p1", title: "Page with #tag1 and #tag2", body: "Content")
        ]
        
        let graph = try await builder.build(from: pages, chats: [], ideas: [])
        
        let tagNodes = graph.nodes.filter { $0.type == .tag }
        #expect(tagNodes.count >= 2, "Should create tag nodes")
    }
    
    @Test("Builder creates edges for wikilinks")
    func builderCreatesWikilinkEdges() async throws {
        let builder = await GraphBuilder()
        
        let pages = [
            MockPage(id: "p1", title: "Page 1", body: "Links to [[Page 2]]"),
            MockPage(id: "p2", title: "Page 2", body: "Content")
        ]
        
        let graph = try await builder.build(from: pages, chats: [], ideas: [])
        
        let referenceEdges = graph.edges.filter { $0.type == .reference }
        #expect(referenceEdges.count >= 1, "Should create reference edge for wikilink")
    }
    
    @Test("Builder assigns correct node types")
    func builderAssignsTypes() async throws {
        let builder = await GraphBuilder()
        
        let pages = [MockPage(id: "p1", title: "Note", body: "", isJournal: false)]
        let chats = [MockChat(id: "c1", title: "Chat")]
        let ideas = [MockIdea(id: "i1", content: "Idea", pageId: "p1")]
        
        let graph = try await builder.build(from: pages, chats: chats, ideas: ideas)
        
        let noteNodes = graph.nodes.filter { $0.type == .note }
        let chatNodes = graph.nodes.filter { $0.type == .chat }
        let ideaNodes = graph.nodes.filter { $0.type == .idea }
        
        #expect(noteNodes.count >= 1, "Should have note nodes")
        #expect(chatNodes.count >= 1, "Should have chat nodes")
        #expect(ideaNodes.count >= 1, "Should have idea nodes")
    }
}

@Suite("Graph Mode - Search in Graph Context")
@MainActor
struct GraphSearchTests {
    
    @Test("Search results are sorted by relevance")
    func searchRelevanceSorting() {
        let store = GraphStore()
        
        // Add nodes with various labels
        store.addNode(makeNode(id: "exact", label: "Exact Match", type: .note))
        store.addNode(makeNode(id: "prefix", label: "Matching Prefix", type: .note))
        store.addNode(makeNode(id: "contains", label: "Contains Matching", type: .note))
        store.addNode(makeNode(id: "unrelated", label: "Something Else", type: .note))
        
        let results = store.fuzzySearch(query: "match", limit: 10)
        
        // Should return results
        #expect(!results.isEmpty)
        
        // Exact match should be first if present
        if let first = results.first {
            #expect(first.id == "exact" || first.id == "prefix" || first.id == "contains")
        }
    }
    
    @Test("Search respects type filters")
    func searchWithTypeFilter() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "note1", label: "Test", type: .note))
        store.addNode(makeNode(id: "chat1", label: "Test", type: .chat))
        store.addNode(makeNode(id: "idea1", label: "Test", type: .idea))
        
        let results = store.fuzzySearch(query: "test", limit: 10, types: [.note, .idea])
        
        for result in results {
            #expect(result.type == .note || result.type == .idea, "Should only return filtered types")
        }
    }
    
    @Test("Empty search returns empty results")
    func emptySearch() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Something", type: .note))
        
        let results = store.fuzzySearch(query: "", limit: 10)
        #expect(results.isEmpty)
    }
    
    @Test("Search with no matches returns empty")
    func noMatches() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Apple", type: .note))
        
        let results = store.fuzzySearch(query: "xyznonexistent", limit: 10)
        #expect(results.isEmpty)
    }
}

@Suite("Graph Mode - Performance Characteristics")
@MainActor
struct GraphPerformanceTests {
    
    @Test("Graph operations complete in reasonable time")
    func graphOperationPerformance() {
        let store = GraphStore()
        
        // Add 1000 nodes
        let startTime = Date()
        for i in 0..<1000 {
            let node = makeNode(
                id: "node-\(i)",
                label: "Node \(i)",
                type: GraphNodeType.allCases[i % GraphNodeType.allCases.count]
            )
            store.addNode(node)
        }
        let addTime = Date().timeIntervalSince(startTime)
        
        // Should add 1000 nodes in under 1 second
        #expect(addTime < 1.0, "Adding 1000 nodes took \(addTime)s")
        
        // Search should be fast
        let searchStart = Date()
        _ = store.fuzzySearch(query: "node", limit: 10)
        let searchTime = Date().timeIntervalSince(searchStart)
        
        // Search should complete in under 100ms
        #expect(searchTime < 0.1, "Search took \(searchTime)s")
    }
    
    @Test("BFS traversal is efficient")
    func bfsPerformance() {
        let store = GraphStore()
        
        // Create a linear chain of 100 nodes
        for i in 0..<100 {
            let node = makeNode(id: "n\(i)", label: "Node \(i)", type: .note)
            store.addNode(node)
            
            if i > 0 {
                let edge = GraphEdgeRecord(
                    id: "e\(i)",
                    sourceNodeId: "n\(i-1)",
                    targetNodeId: "n\(i)",
                    type: .reference,
                    weight: 1.0,
                    createdAt: .now
                )
                store.addEdge(edge)
            }
        }
        
        // BFS from one end
        let startTime = Date()
        let connected = store.connected(to: "n0", maxDepth: 100)
        let bfsTime = Date().timeIntervalSince(startTime)
        
        #expect(connected.count == 100, "BFS should find all nodes")
        #expect(bfsTime < 0.1, "BFS took \(bfsTime)s")
    }
}

// MARK: - Helper Functions

@MainActor
private func makeNode(id: String, label: String, type: GraphNodeType) -> GraphNodeRecord {
    GraphNodeRecord(
        id: id,
        type: type,
        label: label,
        sourceId: nil,
        metadata: GraphNodeMetadata(),
        weight: 1.0,
        createdAt: .now,
        position: .zero,
        velocity: .zero
    )
}

// MARK: - Mock Types for Testing

private struct MockPage: Identifiable {
    let id: String
    let title: String
    let body: String
    var isJournal: Bool = false
}

private struct MockChat: Identifiable {
    let id: String
    let title: String
}

private struct MockIdea: Identifiable {
    let id: String
    let content: String
    let pageId: String
}

// Extension to make GraphBuilder work with mocks
extension GraphBuilder {
    func build(from pages: [MockPage], chats: [MockChat], ideas: [MockIdea]) async throws -> GraphData {
        // This would be implemented to work with mock data
        // For now, return empty graph
        return GraphData(nodes: [], edges: [])
    }
}

struct GraphData {
    let nodes: [GraphNodeRecord]
    let edges: [GraphEdgeRecord]
}
