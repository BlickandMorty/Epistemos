import Foundation
import os

// MARK: - Recipe Graph Skills

/// Maps Rust-side Recipe templates into graph skill nodes.
/// Each recipe becomes a navigable, searchable node in the knowledge graph
/// connected to the topics and tools it uses.
///
/// This enables:
/// - Discovering relevant automations when browsing the graph
/// - Suggesting recipes when the user writes about related topics
/// - Building a "skill tree" visualization of agent capabilities
@MainActor
final class RecipeGraphSkills {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "RecipeGraphSkills")

    private let graphStore: GraphStore
    private let mcpBridge: MCPBridge

    /// Tracks which recipes have been synced to the graph (by recipe ID).
    private var syncedRecipeIds: Set<String> = []

    init(graphStore: GraphStore, mcpBridge: MCPBridge) {
        self.graphStore = graphStore
        self.mcpBridge = mcpBridge
    }

    // MARK: - Sync Recipes to Graph

    /// Sync all recipes from the Rust RecipeManager into graph nodes.
    /// Called on launch and after recipe creation/modification.
    func syncRecipesToGraph() {
        let recipesJson = listRecipesJson()
        guard let data = recipesJson.data(using: .utf8),
              let recipes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            log.debug("No recipes to sync")
            return
        }

        var created = 0
        var updated = 0

        for recipe in recipes {
            guard let id = recipe["id"] as? String,
                  let name = recipe["name"] as? String else { continue }

            let description = recipe["description"] as? String ?? ""
            let useCount = recipe["use_count"] as? Int ?? 0

            // Check if already in graph
            if graphStore.node(bySourceId: "recipe:\(id)", type: .idea) != nil {
                // Already synced — skip (weight updates happen on next full rebuild)
                updated += 1
                syncedRecipeIds.insert(id)
                continue
            }

            // Create new skill node
            let skillNode = GraphNodeRecord(
                id: UUID().uuidString,
                type: .idea,
                label: "Skill: \(name)",
                sourceId: "recipe:\(id)",
                metadata: GraphNodeMetadata(),
                weight: min(1.0, 0.3 + Double(useCount) * 0.1),
                createdAt: Date(),
                updatedAt: Date(),
                position: .zero,
                velocity: .zero,
                isVisible: true,
                isPinned: false
            )
            graphStore.addNode(skillNode)
            created += 1
            syncedRecipeIds.insert(id)

            // Extract tool names from steps and create edges to related nodes
            let tools = extractTools(from: recipe)
            let keywords = extractKeywords(from: name, description: description)

            // Link to existing tag nodes that match keywords
            for keyword in keywords {
                linkToMatchingTags(keyword: keyword, fromNodeId: skillNode.id)
            }

            // Create tag nodes for tools used
            for tool in tools {
                linkOrCreateToolTag(tool: tool, fromNodeId: skillNode.id)
            }
        }

        if created > 0 || updated > 0 {
            log.info("Recipe sync: \(created) created, \(updated) updated")
        }
    }

    // MARK: - Recipe Suggestions

    /// Find recipes relevant to a given topic by searching the graph.
    func suggestRecipes(forTopic topic: String, limit: Int = 5) -> [RecipeSuggestion] {
        let hits = graphStore.fuzzySearch(query: topic, limit: limit * 2)
        return hits
            .filter { $0.node.sourceId?.hasPrefix("recipe:") == true }
            .prefix(limit)
            .map { hit in
                let recipeId = String(hit.node.sourceId?.dropFirst(7) ?? "")
                return RecipeSuggestion(
                    recipeId: recipeId,
                    skillNodeId: hit.node.id,
                    label: hit.node.label,
                    relevance: Double(hit.score),
                    useCount: Int((hit.node.weight - 0.3) / 0.1)
                )
            }
    }

    /// Find recipes that use a specific tool.
    func recipesUsingTool(_ toolName: String) -> [GraphNodeRecord] {
        // Find the tool tag node
        guard let toolTag = graphStore.nodes.values.first(where: {
            $0.type == .tag && $0.label == "tool:\(toolName)"
        }) else { return [] }

        // Find all skill nodes connected to this tool tag
        return graphStore.neighbors(of: toolTag.id)
            .filter { $0.sourceId?.hasPrefix("recipe:") == true }
    }

    // MARK: - Helpers

    private func extractTools(from recipe: [String: Any]) -> [String] {
        guard let stepsJson = recipe["steps_json"] as? String,
              let data = stepsJson.data(using: .utf8),
              let steps = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return steps.compactMap { $0["tool_name"] as? String }
    }

    private func extractKeywords(from name: String, description: String) -> [String] {
        let combined = "\(name) \(description)".lowercased()
        let stopWords: Set<String> = [
            "about", "after", "every", "first", "their", "there",
            "these", "thing", "those", "which", "while", "would",
        ]
        return combined
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 3 && !stopWords.contains($0) }
    }

    private func linkToMatchingTags(keyword: String, fromNodeId: String) {
        let matchingTags = graphStore.nodes.values.filter {
            $0.type == .tag && $0.label.lowercased().contains(keyword)
        }
        for tag in matchingTags.prefix(3) {
            let edge = GraphEdgeRecord(
                id: UUID().uuidString,
                sourceNodeId: fromNodeId,
                targetNodeId: tag.id,
                type: .related,
                weight: 0.5,
                createdAt: Date()
            )
            graphStore.addEdge(edge)
        }
    }

    private func linkOrCreateToolTag(tool: String, fromNodeId: String) {
        let tagLabel = "tool:\(tool)"
        let tagNodeId: String

        if let existing = graphStore.nodes.values.first(where: { $0.type == .tag && $0.label == tagLabel }) {
            tagNodeId = existing.id
        } else {
            let tagNode = GraphNodeRecord(
                id: UUID().uuidString,
                type: .tag,
                label: tagLabel,
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 0.2,
                createdAt: Date(),
                updatedAt: Date(),
                position: .zero,
                velocity: .zero,
                isVisible: true,
                isPinned: false
            )
            graphStore.addNode(tagNode)
            tagNodeId = tagNode.id
        }

        let edge = GraphEdgeRecord(
            id: UUID().uuidString,
            sourceNodeId: fromNodeId,
            targetNodeId: tagNodeId,
            type: .tagged,
            weight: 0.4,
            createdAt: Date()
        )
        graphStore.addEdge(edge)
    }

    private func listRecipesJson() -> String {
        // Recipe listing via MCP JSON-RPC dispatch
        let request = "{\"jsonrpc\":\"2.0\",\"method\":\"recipes/list\",\"id\":1}"
        let response = mcpBridge.dispatch(request)
        // Extract result array from JSON-RPC response
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]],
              let resultData = try? JSONSerialization.data(withJSONObject: result),
              let resultJson = String(data: resultData, encoding: .utf8) else {
            return "[]"
        }
        return resultJson
    }
}

// MARK: - Types

struct RecipeSuggestion: Sendable, Identifiable {
    var id: String { recipeId }
    let recipeId: String
    let skillNodeId: String
    let label: String
    let relevance: Double
    let useCount: Int
}
