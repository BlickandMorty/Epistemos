import Foundation
import SwiftData

// MARK: - KnowledgeIndexBuilder
// Builds a compact entity table from the knowledge graph and injects it into
// every agent system prompt. Enables entity resolution by lookup, not search.
//
// Reference: Rowboat `knowledge_index.ts` pattern — structured table of all entities
// passed to agent prompts for entity resolution.
//
// Output format (markdown table, capped at ~2000 tokens / 150 entries):
// ## Your Knowledge Graph
// | Note | Type | Path |
// |------|------|------|
// | Sprint Omega-5 | folder | docs/sprint-sessions/ |
// | MOHAWK Pipeline | note  | KnowledgeFusion/MOHAWK/ |

@MainActor
final class KnowledgeIndexBuilder {

    // MARK: - Cache

    private var cachedIndex: String?
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 30 // seconds

    private func fetchGraphNodes(context: ModelContext) -> [SDGraphNode]? {
        let noteRaw = GraphNodeType.note.rawValue
        let folderRaw = GraphNodeType.folder.rawValue
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.type == noteRaw || $0.type == folderRaw },
            sortBy: [SortDescriptor(\SDGraphNode.updatedAt, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            Log.engine.error(
                "KnowledgeIndexBuilder: failed to fetch graph nodes: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    // MARK: - Build Index

    /// Build a compact markdown table of all note/folder nodes in the graph.
    /// Capped at 150 entries, sorted by most recently updated first.
    /// Cached for 30 seconds to avoid redundant SwiftData fetches.
    func buildIndex(context: ModelContext) -> String {
        if let cached = cachedIndex,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheTTL {
            return cached
        }

        // Fetch note and folder nodes, sorted by updatedAt descending
        guard let nodes = fetchGraphNodes(context: context) else {
            return ""
        }
        let capped = nodes.prefix(150)

        guard !capped.isEmpty else {
            cachedIndex = ""
            cacheTimestamp = Date()
            return ""
        }

        var table = "## Your Knowledge Graph\n"
        table += "| Note | Type | Path |\n|------|------|------|\n"
        for node in capped {
            let typeName = GraphNodeType(legacy: node.type).displayName.lowercased()
            let path = node.sourceId ?? ""
            // Escape pipe characters in label to avoid breaking the table
            let safeLabel = node.label.replacingOccurrences(of: "|", with: "\\|")
            table += "| \(safeLabel) | \(typeName) | \(path) |\n"
        }

        cachedIndex = table
        cacheTimestamp = Date()
        return table
    }

    /// Returns the index wrapped as a system prompt block, or empty string if no entities.
    func systemPromptBlock(context: ModelContext) -> String {
        let index = buildIndex(context: context)
        guard !index.isEmpty else { return "" }
        return index + "\n"
    }

    /// Invalidate cache — call after graph rebuild or vault sync.
    func invalidateCache() {
        cachedIndex = nil
        cacheTimestamp = nil
    }

    /// Write the index to a file in the vault for Rust agent_core to read.
    /// Called after graph rebuilds so the Rust loop can inject it into prompts.
    func writeToVault(context: ModelContext, vaultRoot: URL) {
        let index = buildIndex(context: context)
        guard !index.isEmpty else { return }

        let epistemosDir = vaultRoot.appendingPathComponent(".epistemos")
        do {
            try FileManager.default.createDirectory(at: epistemosDir, withIntermediateDirectories: true)
        } catch {
            Log.engine.error(
                "KnowledgeIndexBuilder: failed to create index directory: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        let indexFile = epistemosDir.appendingPathComponent("knowledge_index.md")
        do {
            try index.write(to: indexFile, atomically: true, encoding: .utf8)
        } catch {
            Log.engine.error(
                "KnowledgeIndexBuilder: failed to write knowledge index: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
