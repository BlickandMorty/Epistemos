import Foundation
import SwiftData

// MARK: - StructuralGraphBuilder
// Builds the "structural" knowledge graph from existing SwiftData entities.
// No AI calls — purely deterministic edges from SDPage, SDFolder, NoteIdea,
// SDChat, and tags. Run on first load or manual refresh to give the graph
// an immediate skeleton before AI entity extraction fills in semantic links.

@MainActor
final class StructuralGraphBuilder {

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

            // Ideas & Brain Dumps
            for idea in page.ideas {
                let ideaKey = "idea-\(idea.id)"
                guard existingSourceIds.insert(ideaKey).inserted else { continue }

                let ideaType: GraphNodeType = idea.type == .brainDump ? .brainDump : .idea
                let ideaNode = SDGraphNode(type: ideaType, label: idea.title, sourceId: idea.id)
                ideaNode.createdAt = idea.createdAt
                nodes.append(ideaNode)
                sourceIdToNodeId[idea.id] = ideaNode.id

                // idea/brainDump → note (belongsTo)
                edges.append(SDGraphEdge(source: ideaNode.id, target: node.id, type: .belongsTo))
            }
        }

        // ────────────────────────────────────────────
        // 2. Folders
        // ────────────────────────────────────────────
        let folders = (try? context.fetch(FetchDescriptor<SDFolder>())) ?? []

        for folder in folders {
            let folderKey = "folder-\(folder.id)"
            guard existingSourceIds.insert(folderKey).inserted else { continue }

            let node = SDGraphNode(type: .folder, label: folder.name, sourceId: folder.id)
            node.createdAt = folder.createdAt
            nodes.append(node)
            sourceIdToNodeId[folder.id] = node.id
        }

        // ────────────────────────────────────────────
        // 3. Note → Folder edges (livesIn)
        // ────────────────────────────────────────────
        for page in pages {
            guard let folder = page.folder,
                  let noteNodeId = sourceIdToNodeId[page.id],
                  let folderNodeId = sourceIdToNodeId[folder.id]
            else { continue }
            edges.append(SDGraphEdge(source: noteNodeId, target: folderNodeId, type: .livesIn))
        }

        // ────────────────────────────────────────────
        // 4. Nested pages (wikilink to parent)
        // ────────────────────────────────────────────
        for page in pages {
            guard let parentId = page.parentPageId,
                  let childNodeId = sourceIdToNodeId[page.id],
                  let parentNodeId = sourceIdToNodeId[parentId]
            else { continue }
            edges.append(SDGraphEdge(source: childNodeId, target: parentNodeId, type: .wikilink))
        }

        // ────────────────────────────────────────────
        // 5. Chats
        // ────────────────────────────────────────────
        let chats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []

        // Build a title → note-node-id lookup for chat→note referenced edges.
        var titleToNoteNodeId: [String: String] = [:]
        for page in pages {
            let key = page.title.lowercased()
            if !key.isEmpty, let nodeId = sourceIdToNodeId[page.id] {
                titleToNoteNodeId[key] = nodeId
            }
        }

        for chat in chats {
            let chatKey = "chat-\(chat.id)"
            guard existingSourceIds.insert(chatKey).inserted else { continue }

            let node = SDGraphNode(type: .chat, label: chat.title, sourceId: chat.id)
            node.createdAt = chat.createdAt
            nodes.append(node)
            sourceIdToNodeId[chat.id] = node.id

            // Chat → Note referenced edges.
            // SDMessage doesn't persist loadedNoteTitles directly.
            // We do a lightweight heuristic: scan assistant message content for exact
            // note title matches. This is skipped for now — the referenced edges will
            // be populated by the AI extraction pipeline (Task 7) or when SDMessage
            // gains a noteTitlesData field.
        }

        Log.app.info("StructuralGraphBuilder: built \(nodes.count) nodes, \(edges.count) edges")
        return (nodes: nodes, edges: edges)
    }

    // MARK: - Persist

    /// Delete all existing graph data and insert the freshly built nodes and edges.
    func persist(nodes: [SDGraphNode], edges: [SDGraphEdge], context: ModelContext) {
        // Wipe existing graph (fresh rebuild)
        do {
            try context.delete(model: SDGraphEdge.self)
            try context.delete(model: SDGraphNode.self)
        } catch {
            Log.app.error("StructuralGraphBuilder: failed to delete existing graph: \(error.localizedDescription, privacy: .public)")
        }

        for node in nodes {
            context.insert(node)
        }
        for edge in edges {
            context.insert(edge)
        }

        do {
            try context.save()
            Log.app.info("StructuralGraphBuilder: persisted \(nodes.count) nodes, \(edges.count) edges")
        } catch {
            Log.app.error("StructuralGraphBuilder: failed to save graph: \(error.localizedDescription, privacy: .public)")
        }
    }
}
