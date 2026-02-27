import Foundation
import SwiftData

// MARK: - GraphBuilder
// Builds the structural knowledge graph from existing SwiftData entities.
// No AI calls — purely deterministic edges from SDPage, SDFolder, NoteIdea,
// SDChat, and tags. Run on first load or manual refresh to give the graph
// an immediate skeleton before AI entity extraction fills in semantic links.
//
// Uses the 7-type node model and 8-type edge model.

@MainActor
final class GraphBuilder {

    // MARK: - Build

    /// Scan all structured data and return graph nodes + edges (not yet persisted).
    func build(context: ModelContext) -> (nodes: [SDGraphNode], edges: [SDGraphEdge]) {
        var nodes: [SDGraphNode] = []
        var edges: [SDGraphEdge] = []

        // Tracks sourceId keys already emitted to prevent duplicate nodes.
        var existingSourceIds = Set<String>()

        // Quick lookup: sourceId -> SDGraphNode.id (UUID) for edge wiring.
        var sourceIdToNodeId: [String: String] = [:]

        // ────────────────────────────────────────────
        // 1. Notes (non-archived SDPage)
        // ────────────────────────────────────────────
        let pages = (try? context.fetch(SDPage.activePagesDescriptor)) ?? []

        for page in pages {
            let pageKey = "note-\(page.id)"
            guard existingSourceIds.insert(pageKey).inserted else { continue }

            let label = page.title.isEmpty ? "Untitled" : page.title
            let weight = Double(max(1, page.wordCount / 100))

            let node = SDGraphNode(type: .note, label: label, sourceId: page.id, weight: weight)
            var meta = GraphNodeMetadata()
            meta.researchStage = page.researchStage
            node.meta = meta
            node.createdAt = page.createdAt

            nodes.append(node)
            sourceIdToNodeId[page.id] = node.id

            // Tags
            for tag in page.tags {
                let tagKey = "tag-\(tag.lowercased())"
                if existingSourceIds.insert(tagKey).inserted {
                    let tagNode = SDGraphNode(type: .tag, label: tag, sourceId: tagKey)
                    tagNode.createdAt = page.createdAt
                    nodes.append(tagNode)
                    sourceIdToNodeId[tagKey] = tagNode.id
                }
                if let tagNodeId = sourceIdToNodeId[tagKey] {
                    edges.append(SDGraphEdge(source: node.id, target: tagNodeId, type: .tagged))
                }
            }

            // Ideas (brainDump and idea both map to .idea in the 7-type model)
            for idea in page.ideas {
                let ideaKey = "idea-\(idea.id)"
                guard existingSourceIds.insert(ideaKey).inserted else { continue }

                let ideaNode = SDGraphNode(type: .idea, label: idea.title, sourceId: idea.id)
                ideaNode.createdAt = idea.createdAt
                nodes.append(ideaNode)
                sourceIdToNodeId[idea.id] = ideaNode.id

                // idea → note (contains) — weight 3 for tighter visual grouping
                edges.append(SDGraphEdge(source: ideaNode.id, target: node.id, type: .contains, weight: 3.0))
            }
        }

        // ────────────────────────────────────────────
        // 2. Folders (recursive — parent→child nesting)
        // ────────────────────────────────────────────
        let folders = (try? context.fetch(FetchDescriptor<SDFolder>())) ?? []

        // Pre-compute recursive page count for each folder so parent folders
        // are visually larger (more content = bigger node radius).
        var folderContentCount: [String: Int] = [:]
        func recursivePageCount(_ folder: SDFolder) -> Int {
            if let cached = folderContentCount[folder.id] { return cached }
            let directPages = (folder.pages ?? []).filter { !$0.isArchived }.count
            let childCount = (folder.children ?? []).reduce(0) { $0 + recursivePageCount($1) }
            let total = directPages + childCount
            folderContentCount[folder.id] = total
            return total
        }
        for folder in folders { _ = recursivePageCount(folder) }

        for folder in folders {
            let folderKey = "folder-\(folder.id)"
            guard existingSourceIds.insert(folderKey).inserted else { continue }

            // Weight by recursive content count so parent folders are bigger.
            let contentCount = folderContentCount[folder.id] ?? 1
            let node = SDGraphNode(type: .folder, label: folder.name, sourceId: folder.id, weight: Double(max(1, contentCount)))
            node.createdAt = folder.createdAt
            nodes.append(node)
            sourceIdToNodeId[folder.id] = node.id
        }

        // ────────────────────────────────────────────
        // 3. Folder → Subfolder edges (contains)
        // ────────────────────────────────────────────
        for folder in folders {
            guard let children = folder.children else { continue }
            guard let parentNodeId = sourceIdToNodeId[folder.id] else { continue }
            for child in children {
                guard let childNodeId = sourceIdToNodeId[child.id] else { continue }
                edges.append(SDGraphEdge(source: parentNodeId, target: childNodeId, type: .contains, weight: 3.0))
            }
        }

        // ────────────────────────────────────────────
        // 4. Note → Folder edges (contains)
        // ────────────────────────────────────────────
        for page in pages {
            guard let folder = page.folder,
                  let noteNodeId = sourceIdToNodeId[page.id],
                  let folderNodeId = sourceIdToNodeId[folder.id]
            else { continue }
            edges.append(SDGraphEdge(source: folderNodeId, target: noteNodeId, type: .contains, weight: 3.0))
        }

        // ────────────────────────────────────────────
        // 5. Nested pages (reference to parent)
        // ────────────────────────────────────────────
        for page in pages {
            guard let parentId = page.parentPageId,
                  let childNodeId = sourceIdToNodeId[page.id],
                  let parentNodeId = sourceIdToNodeId[parentId]
            else { continue }
            edges.append(SDGraphEdge(source: childNodeId, target: parentNodeId, type: .reference))
        }

        // ────────────────────────────────────────────
        // 6. Chats
        // ────────────────────────────────────────────
        let chats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []

        for chat in chats {
            let chatKey = "chat-\(chat.id)"
            guard existingSourceIds.insert(chatKey).inserted else { continue }

            let node = SDGraphNode(type: .chat, label: chat.title, sourceId: chat.id)
            node.createdAt = chat.createdAt
            nodes.append(node)
            sourceIdToNodeId[chat.id] = node.id
        }

        Log.app.info("GraphBuilder: built \(nodes.count) nodes, \(edges.count) edges")
        return (nodes: nodes, edges: edges)
    }

    // MARK: - Persist

    /// Delete all existing graph data and insert the freshly built nodes and edges.
    func persist(nodes: [SDGraphNode], edges: [SDGraphEdge], context: ModelContext) {
        // Wipe existing graph (fresh rebuild)
        do {
            try context.delete(model: SDGraphEdge.self, where: #Predicate<SDGraphEdge> { !$0.isManual })
            try context.delete(model: SDGraphNode.self, where: #Predicate<SDGraphNode> { !$0.isManual })
        } catch {
            Log.app.error("GraphBuilder: failed to delete existing graph: \(error.localizedDescription, privacy: .public)")
        }

        for node in nodes {
            context.insert(node)
        }
        for edge in edges {
            context.insert(edge)
        }

        do {
            try context.save()
            Log.app.info("GraphBuilder: persisted \(nodes.count) nodes, \(edges.count) edges")
        } catch {
            Log.app.error("GraphBuilder: failed to save graph: \(error.localizedDescription, privacy: .public)")
        }
    }
}
