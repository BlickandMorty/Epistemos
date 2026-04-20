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

/// Graph builder — builds the structural knowledge graph from SwiftData entities.
/// Safe to use from any actor that owns the passed ModelContext
/// (@MainActor with mainContext, or @ModelActor with its own context).
// GraphBuilder has no instance state. The testing diagnostics live in static storage
// behind a lock, and call sites provide an actor-owned ModelContext.
final class GraphBuilder: Sendable {
    private nonisolated static let blockRefFetchBatchSize = 128
    private nonisolated static let blockRefFetchDiagnosticsLock = NSLock()
    private nonisolated(unsafe) static var blockRefFetchBatchCount = 0

    nonisolated static func resetBlockRefFetchDiagnosticsForTesting() {
        blockRefFetchDiagnosticsLock.lock()
        blockRefFetchBatchCount = 0
        blockRefFetchDiagnosticsLock.unlock()
    }

    nonisolated static func blockRefFetchBatchCountForTesting() -> Int {
        blockRefFetchDiagnosticsLock.lock()
        let count = blockRefFetchBatchCount
        blockRefFetchDiagnosticsLock.unlock()
        return count
    }

    private nonisolated static func recordBlockRefFetchBatchForTesting() {
        blockRefFetchDiagnosticsLock.lock()
        blockRefFetchBatchCount += 1
        blockRefFetchDiagnosticsLock.unlock()
    }

    private nonisolated func recordGraphBuilderFailure(
        _ action: String,
        error: Error
    ) {
        Log.graphBuilder.error(
            "\(action, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
        RuntimeDiagnostics.record(
            .error,
            category: "GraphBuilder",
            message: "\(action) failed",
            metadata: ["error": error.localizedDescription]
        )
    }

    private nonisolated func fetchReferencedBlocks(
        blockIds: Set<String>,
        context: ModelContext
    ) -> [SDBlock] {
        guard !blockIds.isEmpty else { return [] }

        let orderedIds = Array(blockIds)
        var blocks: [SDBlock] = []
        blocks.reserveCapacity(orderedIds.count)

        for start in stride(from: 0, to: orderedIds.count, by: Self.blockRefFetchBatchSize) {
            let end = min(start + Self.blockRefFetchBatchSize, orderedIds.count)
            let batch = Array(orderedIds[start..<end])
            let descriptor = FetchDescriptor<SDBlock>(
                predicate: #Predicate<SDBlock> { batch.contains($0.id) }
            )
            do {
                let fetched = try context.fetch(descriptor)
                blocks.append(contentsOf: fetched)
            } catch {
                recordGraphBuilderFailure("Fetch referenced blocks batch", error: error)
            }
            Self.recordBlockRefFetchBatchForTesting()
        }

        return blocks
    }

    nonisolated static func folderDescriptor() -> FetchDescriptor<SDFolder> {
        var descriptor = FetchDescriptor<SDFolder>()
        descriptor.relationshipKeyPathsForPrefetching = [\.pages, \.children]
        return descriptor
    }

    // MARK: - Build

    /// Scan all structured data and return graph nodes + edges (not yet persisted).
    /// Safe to call from any actor that owns the provided ModelContext.
    // SAFETY: @Model access is safe when caller owns the ModelContext
    // (guaranteed by @ModelActor or @MainActor). The class is Sendable because it
    // carries no instance state across actor boundaries.
    nonisolated func build(context: ModelContext) -> (nodes: [SDGraphNode], edges: [SDGraphEdge]) {
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
            recordGraphBuilderFailure("Fetch active pages", error: error)
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

            // Tags — stored in SDPage but NOT emitted as graph nodes.
            // Tags remain a first-class concept for filtering/search, just not visualized.

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

        // Pass 1: collect block refs from pages.
        // SDPage extracts these during saveBody() to avoid O(N) disk I/O here.
        struct BlockRef { let noteNodeId: String; let refId: String }
        var blockRefs: [BlockRef] = []
        var referencedBlockIds = Set<String>()

        for page in pages {
            guard let noteNodeId = sourceIdToNodeId[page.id] else { continue }
            let refs = page.blockReferences
            guard !refs.isEmpty else { continue }

            for refId in refs {
                referencedBlockIds.insert(refId)
                blockRefs.append(BlockRef(noteNodeId: noteNodeId, refId: refId))
            }
        }

        // Pass 2: fetch only referenced blocks and resolve edges.
        if !blockRefs.isEmpty {
            var blockIdToPageId: [String: String] = [:]
            for block in fetchReferencedBlocks(blockIds: referencedBlockIds, context: context) {
                blockIdToPageId[block.id] = block.pageId
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
            folders = try context.fetch(Self.folderDescriptor())
        } catch {
            recordGraphBuilderFailure("Fetch folders", error: error)
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
            recordGraphBuilderFailure("Fetch chats", error: error)
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

        Log.graphBuilder.info(
            "Built graph from \(pages.count) pages and \(chats.count) chats -> \(nodes.count) nodes, \(edges.count) edges"
        )
        return (nodes: nodes, edges: edges)
    }

    // MARK: - Persist (Diff-Based)

    /// Diff-based persist: compare expected nodes/edges against current SwiftData state
    /// and apply only inserts, updates, and deletes. Manual nodes/edges are never touched.
    // SAFETY: Same as build() — caller must own the ModelContext.
    nonisolated func persist(nodes expectedNodes: [SDGraphNode], edges expectedEdges: [SDGraphEdge], context: ModelContext) {
        struct NodeMutationSnapshot {
            let node: SDGraphNode
            let label: String
            let type: String
            let weight: Double
            let metadata: Data?
            let updatedAt: Date
        }

        struct EdgeMutationSnapshot {
            let edge: SDGraphEdge
            let sourceNodeId: String
            let targetNodeId: String
            let weight: Double
        }

        var inserted = 0
        var updated = 0
        var deleted = 0
        var insertedNodes: [SDGraphNode] = []
        var updatedNodeSnapshots: [NodeMutationSnapshot] = []
        var deletedNodes: [SDGraphNode] = []
        var insertedEdges: [SDGraphEdge] = []
        var updatedEdgeSnapshots: [EdgeMutationSnapshot] = []
        var deletedEdges: [SDGraphEdge] = []

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
            recordGraphBuilderFailure("Fetch persisted graph nodes", error: error)
            currentNodes = []
        }
        let currentEdges: [SDGraphEdge]
        do { currentEdges = try context.fetch(currentEdgeDesc) }
        catch {
            recordGraphBuilderFailure("Fetch persisted graph edges", error: error)
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
                let snapshot = NodeMutationSnapshot(
                    node: existing,
                    label: existing.label,
                    type: existing.type,
                    weight: existing.weight,
                    metadata: existing.metadata,
                    updatedAt: existing.updatedAt
                )
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
                    updatedNodeSnapshots.append(snapshot)
                    existing.updatedAt = Date()
                    updated += 1
                }
            } else {
                // New node — insert.
                context.insert(expected)
                insertedNodes.append(expected)
                buildIdToPersistedId[expected.id] = expected.id
                inserted += 1
            }
        }

        // Delete removed nodes — built-in structural nodes plus all persisted
        // source/quote residue so rebuilds keep the graph note/chat/idea/folder only.
        let builderOwnedTypes: Set<String> = [
            GraphNodeType.note.rawValue, GraphNodeType.folder.rawValue,
            GraphNodeType.tag.rawValue, GraphNodeType.idea.rawValue,
            GraphNodeType.chat.rawValue, GraphNodeType.source.rawValue,
            GraphNodeType.quote.rawValue,
        ]
        for (key, existing) in currentNodeMap where expectedNodeMap[key] == nil {
            guard builderOwnedTypes.contains(existing.type) else { continue }
            context.delete(existing)
            deletedNodes.append(existing)
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
                let snapshot = EdgeMutationSnapshot(
                    edge: existing,
                    sourceNodeId: existing.sourceNodeId,
                    targetNodeId: existing.targetNodeId,
                    weight: existing.weight
                )
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
                if changed {
                    updatedEdgeSnapshots.append(snapshot)
                    edgeUpdated += 1
                }
            } else {
                // New edge — remap to persisted node IDs and insert.
                let newEdge = SDGraphEdge(
                    source: info.persistedSourceId,
                    target: info.persistedTargetId,
                    type: GraphEdgeType(legacy: info.edge.type),
                    weight: info.edge.weight
                )
                context.insert(newEdge)
                insertedEdges.append(newEdge)
                edgeInserted += 1
            }
        }

        // Delete removed edges — built-in structural edges plus any edge attached
        // to persisted source/quote nodes so rebuilds remove the old library graph residue.
        let builderOwnedEdgeTypes: Set<String> = [
            GraphEdgeType.reference.rawValue, GraphEdgeType.contains.rawValue,
            GraphEdgeType.tagged.rawValue, GraphEdgeType.mentions.rawValue,
            GraphEdgeType.cites.rawValue, GraphEdgeType.authored.rawValue,
        ]
        for (key, existing) in currentEdgeMap where expectedEdgeMap[key] == nil {
            let sourceNode = currentNodes.first { $0.id == existing.sourceNodeId }
            let targetNode = currentNodes.first { $0.id == existing.targetNodeId }
            let touchesSourceOrQuoteNode =
                sourceNode?.nodeType == .source
                || sourceNode?.nodeType == .quote
                || targetNode?.nodeType == .source
                || targetNode?.nodeType == .quote
            guard builderOwnedEdgeTypes.contains(existing.type)
                    || existing.type == GraphEdgeType.quotes.rawValue
                    || touchesSourceOrQuoteNode
            else { continue }
            context.delete(existing)
            deletedEdges.append(existing)
            edgeDeleted += 1
        }

        // ── 5. Save ──

        do {
            try context.save()
            Log.graphBuilder.info("""
                Diff persist complete — \
                nodes: +\(inserted) ~\(updated) -\(deleted), \
                edges: +\(edgeInserted) ~\(edgeUpdated) -\(edgeDeleted)
                """)
        } catch {
            for snapshot in updatedNodeSnapshots {
                snapshot.node.label = snapshot.label
                snapshot.node.type = snapshot.type
                snapshot.node.weight = snapshot.weight
                snapshot.node.metadata = snapshot.metadata
                snapshot.node.updatedAt = snapshot.updatedAt
            }
            for snapshot in updatedEdgeSnapshots {
                snapshot.edge.sourceNodeId = snapshot.sourceNodeId
                snapshot.edge.targetNodeId = snapshot.targetNodeId
                snapshot.edge.weight = snapshot.weight
            }
            for node in deletedNodes {
                context.insert(node)
            }
            for edge in deletedEdges {
                context.insert(edge)
            }
            for edge in insertedEdges {
                context.delete(edge)
            }
            for node in insertedNodes {
                context.delete(node)
            }
            recordGraphBuilderFailure("Save graph diff", error: error)
        }
    }
}
