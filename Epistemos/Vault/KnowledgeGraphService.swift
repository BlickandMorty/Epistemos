import Foundation
import Observation
import OSLog
import SwiftUI

// MARK: - Knowledge Graph Service

/// Service for generating and managing session knowledge graphs.
/// Wraps the Rust FFI `generate_session_graph` and `merge_vault_graph` functions.
@Observable
@MainActor
final class KnowledgeGraphService {
    
    // MARK: - Properties
    
    private let vaultRegistry: VaultRegistry
    private let sessionBrowser: SessionBrowser
    
    /// Currently loaded graph data
    var currentGraph: SessionGraph?
    
    /// Whether graph generation is in progress
    var isGenerating = false
    
    /// Graph generation progress (0.0 to 1.0)
    var generationProgress: Double = 0.0
    
    /// Error message if generation failed
    var lastError: String?
    
    /// Cache of loaded graphs by session ID
    private var graphCache: [String: SessionGraph] = [:]
    
    // MARK: - Initialization
    
    init(
        vaultRegistry: VaultRegistry = .shared,
        sessionBrowser: SessionBrowser = .shared
    ) {
        self.vaultRegistry = vaultRegistry
        self.sessionBrowser = sessionBrowser
    }
    
    // MARK: - Session Graph Generation
    
    /// Generates a knowledge graph for a specific session.
    /// - Parameters:
    ///   - sessionId: The session ID
    ///   - vaultIdentity: Which vault contains the session
    /// - Returns: The generated graph, or nil if generation failed
    func generateGraph(
        forSession sessionId: String,
        in vaultIdentity: VaultIdentity
    ) async -> SessionGraph? {
        guard vaultRegistry.resolveVaultPath(for: vaultIdentity) != nil else {
            lastError = "Vault not found"
            return nil
        }

        sessionBrowser.refreshSessions(for: vaultIdentity)
        guard let session = sessionBrowser.sessions.first(where: { $0.sessionId == sessionId }) else {
            lastError = "Session not found"
            return nil
        }

        return await generateGraph(at: session.folderPath, sessionId: session.sessionId)
    }
    
    /// Generates a graph from a session folder path.
    /// - Parameter folderPath: Path to the session folder
    /// - Returns: The generated graph
    func generateGraph(at folderPath: String, sessionId: String? = nil) async -> SessionGraph? {
        isGenerating = true
        generationProgress = 0.0
        lastError = nil
        
        defer {
            isGenerating = false
            generationProgress = 1.0
        }
        
        do {
            // Check if already cached
            let cacheKey = sessionId ?? folderPath
            if let cached = graphCache[cacheKey] {
                Logger.graph.info("Using cached graph for \(cacheKey)")
                currentGraph = cached
                return cached
            }
            
            // Generate via FFI
            generationProgress = 0.3
            let graphJson = try generate_session_graph(sessionFolder: folderPath)
            
            generationProgress = 0.7
            
            // Parse JSON response
            guard let data = graphJson.data(using: .utf8) else {
                throw GraphError.invalidResponse
            }
            
            let graphData = try decodeGraphData(from: data)
            let graph = SessionGraph(from: graphData)
            
            // Cache and return
            graphCache[cacheKey] = graph
            currentGraph = graph
            
            Logger.graph.info("Generated graph with \(graph.nodes.count) nodes, \(graph.edges.count) edges")
            return graph
            
        } catch {
            lastError = error.localizedDescription
            Logger.graph.error("Graph generation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Generates graphs for all sessions in a vault that don't have them yet.
    /// - Parameter vaultIdentity: Target vault
    /// - Returns: Number of graphs generated
    func generateMissingGraphs(in vaultIdentity: VaultIdentity) async -> Int {
        guard vaultRegistry.resolveVaultPath(for: vaultIdentity) != nil else {
            return 0
        }
        
        // Get all sessions
        sessionBrowser.refreshSessions(for: vaultIdentity)
        let sessions = sessionBrowser.sessions
        
        var generatedCount = 0
        for session in sessions {
            let sessionFolder = session.folderPath
            let graphPath = (sessionFolder as NSString).appendingPathComponent("graph.json")
            
            // Skip if already exists
            if FileManager.default.fileExists(atPath: graphPath) {
                continue
            }
            
            // Generate graph
            if await generateGraph(at: sessionFolder, sessionId: session.sessionId) != nil {
                generatedCount += 1
            }
        }
        
        return generatedCount
    }
    
    // MARK: - Vault-Level Graph
    
    /// Merges all session graphs into a vault-level knowledge graph.
    /// - Parameter vaultIdentity: Target vault
    /// - Returns: Path to the merged graph file
    func mergeVaultGraph(for vaultIdentity: VaultIdentity) async -> String? {
        guard let vaultPath = vaultRegistry.resolveVaultPath(for: vaultIdentity) else {
            lastError = "Vault not found"
            return nil
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let result = try merge_vault_graph(vaultPath: vaultPath)
            
            Logger.graph.info("Merged vault graph: \(result)")
            return result
            
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Graph Query
    
    /// Finds nodes related to a query term.
    /// - Parameters:
    ///   - query: Search term
    ///   - graph: Graph to search (defaults to current)
    /// - Returns: Matching nodes sorted by relevance
    func findRelatedNodes(query: String, in graph: SessionGraph? = nil) -> [GraphNode] {
        let targetGraph = graph ?? currentGraph
        guard let g = targetGraph else { return [] }
        
        let lowerQuery = query.lowercased()
        
        return g.nodes
            .filter { node in
                node.label.lowercased().contains(lowerQuery) ||
                node.properties.values.contains { $0.lowercased().contains(lowerQuery) }
            }
            .sorted { a, b in
                // Sort by centrality (higher = more important)
                a.centrality > b.centrality
            }
    }
    
    /// Gets the "god nodes" (highest centrality) from the graph.
    /// - Parameters:
    ///   - count: Number of top nodes to return
    ///   - graph: Graph to query (defaults to current)
    /// - Returns: Top nodes by centrality
    func godNodes(count: Int = 5, in graph: SessionGraph? = nil) -> [GraphNode] {
        let targetGraph = graph ?? currentGraph
        guard let g = targetGraph else { return [] }
        
        return g.nodes
            .sorted { $0.centrality > $1.centrality }
            .prefix(count)
            .map { $0 }
    }
    
    /// Finds the shortest path between two nodes.
    /// - Parameters:
    ///   - from: Source node ID
    ///   - to: Target node ID
    ///   - graph: Graph to search
    /// - Returns: Array of edges forming the path, or nil if no path exists
    func path(from sourceId: String, to targetId: String, in graph: SessionGraph? = nil) -> [GraphEdge]? {
        let targetGraph = graph ?? currentGraph
        guard let g = targetGraph else { return nil }
        
        // Simple BFS for shortest path
        var queue: [(nodeId: String, path: [GraphEdge])] = [(sourceId, [])]
        var visited: Set<String> = [sourceId]
        
        while !queue.isEmpty {
            let (currentId, currentPath) = queue.removeFirst()
            
            if currentId == targetId {
                return currentPath
            }
            
            // Find outgoing edges
            let outgoing = g.edges.filter { $0.source == currentId }
            
            for edge in outgoing {
                if !visited.contains(edge.target) {
                    visited.insert(edge.target)
                    queue.append((edge.target, currentPath + [edge]))
                }
            }
        }
        
        return nil // No path found
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        graphCache.removeAll()
        currentGraph = nil
    }
    
    func preloadGraph(for sessionId: String, in vaultIdentity: VaultIdentity) async {
        _ = await generateGraph(forSession: sessionId, in: vaultIdentity)
    }
}

// MARK: - Supporting Types

struct SessionGraph: Identifiable {
    let id = UUID()
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let communities: [GraphCommunity]
    
    init(from data: GraphData) {
        self.nodes = data.nodes.map { GraphNode(from: $0) }
        self.edges = data.edges.map { GraphEdge(from: $0) }
        self.communities = data.communities.map { GraphCommunity(from: $0) }
    }
}

struct GraphNode: Identifiable {
    let id: String
    let label: String
    let nodeType: NodeType
    let properties: [String: String]
    let communityId: Int
    let centrality: Double
    
    init(from data: GraphNodeData) {
        self.id = data.id
        self.label = data.label
        self.nodeType = NodeType(rawValue: data.nodeType) ?? .other
        self.properties = data.properties
        self.communityId = data.communityId
        self.centrality = data.centrality
    }
}

enum NodeType: String {
    case tool = "tool"
    case file = "file"
    case entity = "entity"
    case concept = "concept"
    case decision = "decision"
    case other = "other"
    
    var icon: String {
        switch self {
        case .tool: return "wrench"
        case .file: return "doc"
        case .entity: return "person"
        case .concept: return "lightbulb"
        case .decision: return "checkmark.shield"
        case .other: return "circle"
        }
    }
    
    var color: Color {
        switch self {
        case .tool: return .blue
        case .file: return .green
        case .entity: return .purple
        case .concept: return .orange
        case .decision: return .red
        case .other: return .gray
        }
    }
}

struct GraphEdge: Identifiable {
    let id = UUID()
    let source: String
    let target: String
    let relation: String
    let confidence: EdgeConfidence
    let score: Double
    
    init(from data: GraphEdgeData) {
        self.source = data.source
        self.target = data.target
        self.relation = data.relation
        self.confidence = EdgeConfidence(rawValue: data.confidence) ?? .inferred
        self.score = data.score
    }
}

enum EdgeConfidence: String {
    case extracted = "extracted"  // Deterministic, confidence 1.0
    case inferred = "inferred"    // Semantic similarity
    case ambiguous = "ambiguous"  // Uncertain
}

struct GraphCommunity: Identifiable {
    let id: Int
    let size: Int
    let topNodes: [String]
    
    init(from data: GraphCommunityData) {
        self.id = data.id
        self.size = data.size
        self.topNodes = data.topNodes
    }
}

enum GraphError: Error {
    case invalidResponse
    case generationFailed(String)
}

// MARK: - Logger Extension

extension Logger {
    fileprivate static let graph = Logger(subsystem: "com.epistemos", category: "KnowledgeGraph")
}
