import Foundation
import os
import SwiftData

// MARK: - GraphBuilder
// Builds the structural knowledge graph from existing SwiftData entities.
// No AI calls — purely deterministic edges from SDPage, SDFolder, NoteIdea,
// SDChat, and tags. Run on first load or manual refresh to give the graph
// an immediate skeleton before AI entity extraction fills in semantic links.
//
// Uses the 7-type node model and 8-type edge model.

/// Graph builder — runs on @MainActor since @Model types require it in Swift 6.
/// For background graph loading, use BackgroundGraphActor instead.
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
        let pages: [SDPage]
        do {
            pages = try context.fetch(SDPage.activePagesDescriptor)
        } catch {
            Log.app.error("GraphBuilder: failed to fetch pages: \(error.localizedDescription, privacy: .public)")
            pages = []
        }

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
        // 1b. Block references — ((blockId)) in page bodies
        //     Resolves to the block's parent page, creating a note→note
        //     .reference edge. Blocks are NOT individual graph nodes.
        //     Two-pass: collect referenced IDs first, then fetch only those blocks.
        // ────────────────────────────────────────────

        let blockRefPattern = /\(\(([^)]+)\)\)/

        // Pass 1: scan bodies to collect referenced block IDs + source page mapping.
        struct BlockRef { let noteNodeId: String; let refId: String }
        var blockRefs: [BlockRef] = []
        var referencedBlockIds = Set<String>()

        for page in pages {
            guard let noteNodeId = sourceIdToNodeId[page.id] else { continue }
            let body = page.loadBody()
            guard !body.isEmpty else { continue }

            for match in body.matches(of: blockRefPattern) {
                let refId = String(match.1).trimmingCharacters(in: .whitespaces)
                guard !refId.isEmpty else { continue }
                referencedBlockIds.insert(refId)
                blockRefs.append(BlockRef(noteNodeId: noteNodeId, refId: refId))
            }
        }

        // Pass 2: fetch only referenced blocks and resolve edges.
        if !blockRefs.isEmpty {
            var blockIdToPageId: [String: String] = [:]
            for refId in referencedBlockIds {
                let desc = FetchDescriptor<SDBlock>(
                    predicate: #Predicate<SDBlock> { $0.id == refId }
                )
                if let block = try? context.fetch(desc).first {
                    blockIdToPageId[block.id] = block.pageId
                }
            }

            for ref in blockRefs {
                guard let ownerPageId = blockIdToPageId[ref.refId],
                      let targetNoteNodeId = sourceIdToNodeId[ownerPageId],
                      targetNoteNodeId != ref.noteNodeId  // skip self-references
                else { continue }

                edges.append(SDGraphEdge(source: ref.noteNodeId, target: targetNoteNodeId, type: .reference))
            }
        }

        // ────────────────────────────────────────────
        // 2. Folders (recursive — parent→child nesting)
        // ────────────────────────────────────────────
        let folders: [SDFolder]
        do {
            var folderDescriptor = FetchDescriptor<SDFolder>()
            folderDescriptor.relationshipKeyPathsForPrefetching = [\.pages, \.children]
            folders = try context.fetch(folderDescriptor)
        } catch {
            Log.app.error("GraphBuilder: failed to fetch folders: \(error.localizedDescription, privacy: .public)")
            folders = []
        }

        // Pre-compute recursive page count for each folder so parent folders
        // are visually larger (more content = bigger node radius).
        // Uses a visited set to guard against circular parent-child references
        // which would otherwise cause infinite recursion → stack overflow.
        var folderContentCount: [String: Int] = [:]
        var visitedFolders = Set<String>()
        func recursivePageCount(_ folder: SDFolder) -> Int {
            if let cached = folderContentCount[folder.id] { return cached }
            guard visitedFolders.insert(folder.id).inserted else { return 0 }
            let directPages = (folder.pages ?? []).filter { !$0.isArchived }.count
            let childCount = (folder.children ?? []).reduce(0) { $0 + recursivePageCount($1) }
            let total = directPages + childCount
            folderContentCount[folder.id] = total
            return total
        }
        for folder in folders {
            _ = recursivePageCount(folder)
        }

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
            // Weight 3.0 matches containment edges so nested pages stay close to parent.
            edges.append(SDGraphEdge(source: childNodeId, target: parentNodeId, type: .reference, weight: 3.0))
        }

        // ────────────────────────────────────────────
        // 6. Chats — standalone nodes (no page link yet)
        // ────────────────────────────────────────────
        let chats: [SDChat]
        do {
            chats = try context.fetch(FetchDescriptor<SDChat>())
        } catch {
            Log.app.error("GraphBuilder: failed to fetch chats: \(error.localizedDescription, privacy: .public)")
            chats = []
        }

        for chat in chats {
            let chatKey = "chat-\(chat.id)"
            guard existingSourceIds.insert(chatKey).inserted else { continue }

            let label = chat.title.isEmpty ? "Untitled Chat" : chat.title
            let node = SDGraphNode(type: .chat, label: label, sourceId: chat.id)
            node.createdAt = chat.createdAt
            nodes.append(node)
            sourceIdToNodeId[chat.id] = node.id
        }

        Log.app.info("GraphBuilder: \(pages.count) pages, \(chats.count) chats → \(nodes.count) nodes, \(edges.count) edges")
        return (nodes: nodes, edges: edges)
    }

    // MARK: - Persist (Diff-Based)

    /// Diff-based persist: compare expected nodes/edges against current SwiftData state
    /// and apply only inserts, updates, and deletes. Manual nodes/edges are never touched.
    func persist(nodes expectedNodes: [SDGraphNode], edges expectedEdges: [SDGraphEdge], context: ModelContext) {
        var inserted = 0
        var updated = 0
        var deleted = 0

        // ── 1. Fetch current non-manual entities ──

        let currentNodeDesc = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { !$0.isManual }
        )
        let currentEdgeDesc = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate<SDGraphEdge> { !$0.isManual }
        )

        let currentNodes: [SDGraphNode]
        do { currentNodes = try context.fetch(currentNodeDesc) }
        catch {
            Log.app.error("GraphBuilder.persist: failed to fetch current nodes: \(error.localizedDescription, privacy: .public)")
            currentNodes = []
        }
        let currentEdges: [SDGraphEdge]
        do { currentEdges = try context.fetch(currentEdgeDesc) }
        catch {
            Log.app.error("GraphBuilder.persist: failed to fetch current edges: \(error.localizedDescription, privacy: .public)")
            currentEdges = []
        }

        // ── 2. Build lookup maps for nodes ──
        // Key: "type-sourceId" for uniqueness across types.

        func nodeKey(_ type: String, _ sourceId: String?) -> String {
            "\(type)-\(sourceId ?? "")"
        }

        let currentNodeMap = Dictionary(
            currentNodes.compactMap { node -> (String, SDGraphNode)? in
                guard let sid = node.sourceId else { return nil }
                return (nodeKey(node.type, sid), node)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let expectedNodeMap = Dictionary(
            expectedNodes.compactMap { node -> (String, SDGraphNode)? in
                guard let sid = node.sourceId else { return nil }
                return (nodeKey(node.type, sid), node)
            },
            uniquingKeysWith: { first, _ in first }
        )

        // Maps expected (ephemeral build) node ID -> persisted node ID.
        // Needed to remap edge source/target before diffing edges.
        var buildIdToPersistedId: [String: String] = [:]

        // ── 3. Diff nodes ──

        for (key, expected) in expectedNodeMap {
            if let existing = currentNodeMap[key] {
                // Node exists — update if changed.
                buildIdToPersistedId[expected.id] = existing.id
                var changed = false
                if existing.label != expected.label {
                    existing.label = expected.label
                    changed = true
                }
                if existing.type != expected.type {
                    existing.type = expected.type
                    changed = true
                }
                if existing.weight != expected.weight {
                    existing.weight = expected.weight
                    changed = true
                }
                if existing.metadata != expected.metadata {
                    existing.metadata = expected.metadata
                    changed = true
                }
                if changed {
                    existing.updatedAt = Date()
                    updated += 1
                }
            } else {
                // New node — insert.
                context.insert(expected)
                buildIdToPersistedId[expected.id] = expected.id
                inserted += 1
            }
        }

        // Delete removed nodes — but only types that this builder manages.
        // Extraction-created nodes (source, quote, block) are preserved.
        let builderOwnedTypes: Set<String> = [
            GraphNodeType.note.rawValue, GraphNodeType.folder.rawValue,
            GraphNodeType.tag.rawValue, GraphNodeType.idea.rawValue,
            GraphNodeType.chat.rawValue,
        ]
        for (key, existing) in currentNodeMap where expectedNodeMap[key] == nil {
            guard builderOwnedTypes.contains(existing.type) else { continue }
            context.delete(existing)
            deleted += 1
        }

        // ── 4. Diff edges ──
        // Edge unique key: (sourceNodeSourceId, targetNodeSourceId, type).
        // We resolve node IDs to sourceIds for stable comparison.

        // Build a lookup from persisted node ID -> (type, sourceId) for current edges.
        let currentNodeIdToKey: [String: String] = Dictionary(
            currentNodes.compactMap { node -> (String, String)? in
                guard let sid = node.sourceId else { return nil }
                return (node.id, nodeKey(node.type, sid))
            },
            uniquingKeysWith: { first, _ in first }
        )

        // Also include newly inserted nodes (their build ID == persisted ID).
        let expectedNodeIdToKey: [String: String] = Dictionary(
            expectedNodes.compactMap { node -> (String, String)? in
                guard let sid = node.sourceId else { return nil }
                return (node.id, nodeKey(node.type, sid))
            },
            uniquingKeysWith: { first, _ in first }
        )

        typealias EdgeKey = String  // "sourceNodeKey|targetNodeKey|type"

        func edgeKey(sourceNodeKey: String, targetNodeKey: String, type: String) -> EdgeKey {
            "\(sourceNodeKey)|\(targetNodeKey)|\(type)"
        }

        // Map current edges by their resolved key.
        var currentEdgeMap: [EdgeKey: SDGraphEdge] = [:]
        for edge in currentEdges {
            guard let srcKey = currentNodeIdToKey[edge.sourceNodeId],
                  let tgtKey = currentNodeIdToKey[edge.targetNodeId]
            else { continue }
            let key = edgeKey(sourceNodeKey: srcKey, targetNodeKey: tgtKey, type: edge.type)
            currentEdgeMap[key] = edge
        }

        // Map expected edges by their resolved key, remapping node IDs to persisted IDs.
        struct ExpectedEdgeInfo {
            let edge: SDGraphEdge
            let persistedSourceId: String
            let persistedTargetId: String
        }

        var expectedEdgeMap: [EdgeKey: ExpectedEdgeInfo] = [:]
        for edge in expectedEdges {
            guard let srcKey = expectedNodeIdToKey[edge.sourceNodeId],
                  let tgtKey = expectedNodeIdToKey[edge.targetNodeId]
            else { continue }
            let key = edgeKey(sourceNodeKey: srcKey, targetNodeKey: tgtKey, type: edge.type)
            let persistedSrc = buildIdToPersistedId[edge.sourceNodeId] ?? edge.sourceNodeId
            let persistedTgt = buildIdToPersistedId[edge.targetNodeId] ?? edge.targetNodeId
            expectedEdgeMap[key] = ExpectedEdgeInfo(
                edge: edge, persistedSourceId: persistedSrc, persistedTargetId: persistedTgt
            )
        }

        var edgeInserted = 0
        var edgeUpdated = 0
        var edgeDeleted = 0

        // Insert new edges, update changed ones.
        for (key, info) in expectedEdgeMap {
            if let existing = currentEdgeMap[key] {
                // Edge exists — update weight if changed, remap node IDs if needed.
                var changed = false
                if existing.sourceNodeId != info.persistedSourceId {
                    existing.sourceNodeId = info.persistedSourceId
                    changed = true
                }
                if existing.targetNodeId != info.persistedTargetId {
                    existing.targetNodeId = info.persistedTargetId
                    changed = true
                }
                if existing.weight != info.edge.weight {
                    existing.weight = info.edge.weight
                    changed = true
                }
                if changed { edgeUpdated += 1 }
            } else {
                // New edge — remap to persisted node IDs and insert.
                let newEdge = SDGraphEdge(
                    source: info.persistedSourceId,
                    target: info.persistedTargetId,
                    type: GraphEdgeType(legacy: info.edge.type),
                    weight: info.edge.weight
                )
                context.insert(newEdge)
                edgeInserted += 1
            }
        }

        // Delete removed edges — but only types that this builder manages.
        // Extraction-created edges (mentions, cites, authored, etc.) are preserved.
        let builderOwnedEdgeTypes: Set<String> = [
            GraphEdgeType.reference.rawValue, GraphEdgeType.contains.rawValue,
            GraphEdgeType.tagged.rawValue,
        ]
        for (key, existing) in currentEdgeMap where expectedEdgeMap[key] == nil {
            guard builderOwnedEdgeTypes.contains(existing.type) else { continue }
            context.delete(existing)
            edgeDeleted += 1
        }

        // ── 5. Save ──

        do {
            try context.save()
            Log.app.info("""
                GraphBuilder: diff persist — \
                nodes: +\(inserted) ~\(updated) -\(deleted), \
                edges: +\(edgeInserted) ~\(edgeUpdated) -\(edgeDeleted)
                """)
        } catch {
            Log.app.error("GraphBuilder: failed to save graph: \(error.localizedDescription, privacy: .public)")
        }
    }
}
