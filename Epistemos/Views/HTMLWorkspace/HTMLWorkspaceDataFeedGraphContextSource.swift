import Foundation
import SwiftData

extension HTMLWorkspaceDataFeedContextSources {
    static func graphRelatedNoteResults(
        searchResults: [SearchResult],
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer, !searchResults.isEmpty else { return [] }

        let context = ModelContext(modelContainer)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let anchors = graphAnchorNodes(
            for: searchResults.prefix(effectiveLimit).map(\.pageId),
            context: context
        )
        guard !anchors.isEmpty else { return [] }

        var seenPageIDs = Set<String>()
        var candidates: [GraphRelatedNoteCandidate] = []
        candidates.reserveCapacity(effectiveLimit)

        for anchor in anchors {
            for edge in graphEdges(touching: anchor.node.id, context: context) {
                guard let relatedNode = graphRelatedNoteNode(
                    from: edge,
                    anchorNodeID: anchor.node.id,
                    context: context
                ),
                    let relatedPageID = normalized(relatedNode.sourceId),
                    relatedPageID != anchor.pageID,
                    seenPageIDs.insert(relatedPageID).inserted,
                    let page = page(id: relatedPageID, context: context)
                else {
                    continue
                }

                candidates.append(
                    GraphRelatedNoteCandidate(
                        page: page,
                        node: relatedNode,
                        anchorTitle: anchor.title,
                        edgeType: edge.edgeType,
                        edgeWeight: edge.weight,
                        anchorRank: anchor.rank,
                        order: candidates.count
                    )
                )

                if candidates.count >= effectiveLimit {
                    return candidates.map(\.dataFeedResult)
                }
            }
        }

        return candidates.map(\.dataFeedResult)
    }

    static func shouldUseGraphRelatedNoteResults(for query: String?) -> Bool {
        let normalizedQuery = normalized(query).lowercased()
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("graph:") || normalizedQuery.hasPrefix("related:") {
            return true
        }
        if normalizedQuery.hasPrefix("graph ") || normalizedQuery.hasPrefix("related ")
            || normalizedQuery.hasPrefix("related note ") || normalizedQuery.hasPrefix("related notes ") {
            return true
        }
        return [
            "graph",
            "related",
            "related note",
            "related notes",
            "graph related",
            "graph related notes",
        ].contains(normalizedQuery)
    }

    private struct GraphAnchorNode {
        var pageID: String
        var title: String
        var rank: Double
        var node: SDGraphNode
    }

    private struct GraphRelatedNoteCandidate {
        var page: SDPage
        var node: SDGraphNode
        var anchorTitle: String
        var edgeType: GraphEdgeType
        var edgeWeight: Double
        var anchorRank: Double
        var order: Int

        var dataFeedResult: HTMLWorkspaceDataFeedResult {
            let title = normalized(page.title).isEmpty ? normalized(node.label) : page.title
            let summary = normalized(page.summary)
            let bodySnippet = page.normalizedBodySnippet(limit: 360)
            let snippet = summary.isEmpty ? bodySnippet : summary
            let boundedWeight = min(max(edgeWeight, 0), 4)
            let rank = max(0.01, min(1, anchorRank * 0.75 + boundedWeight * 0.0625 - Double(order) * 0.001))
            return HTMLWorkspaceDataFeedResult(
                pageID: page.id,
                title: title.isEmpty ? "Untitled related note" : title,
                snippet: normalized(snippet).isEmpty ? "No related-note excerpt available." : snippet,
                rank: rank,
                contextKind: "graph_related_note",
                sourceLabel: "Graph related note",
                provenance: "SDGraphNode/SDGraphEdge / \(edgeType.rawValue) / anchor: \(anchorTitle)"
            )
        }
    }

    private static func graphAnchorNodes(
        for pageIDs: [String],
        context: ModelContext
    ) -> [GraphAnchorNode] {
        var seenNodeIDs = Set<String>()
        return pageIDs.enumerated().flatMap { index, pageID -> [GraphAnchorNode] in
            let trimmedPageID = normalized(pageID)
            guard !trimmedPageID.isEmpty,
                  let anchorPage = page(id: trimmedPageID, context: context) else {
                return []
            }

            return graphNoteNodes(sourceID: trimmedPageID, context: context)
                .filter { seenNodeIDs.insert($0.id).inserted }
                .map { node in
                    GraphAnchorNode(
                        pageID: trimmedPageID,
                        title: normalized(anchorPage.title).isEmpty ? normalized(node.label) : anchorPage.title,
                        rank: max(0.01, 1.0 - Double(index) * 0.01),
                        node: node
                    )
                }
        }
    }

    private static func graphNoteNodes(sourceID: String, context: ModelContext) -> [SDGraphNode] {
        var descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.sourceId == sourceID }
        )
        descriptor.fetchLimit = 8
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.nodeType == .note || $0.nodeType == .proseNote }
    }

    private static func graphEdges(touching nodeID: String, context: ModelContext) -> [SDGraphEdge] {
        var descriptor = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate { $0.sourceNodeId == nodeID || $0.targetNodeId == nodeID },
            sortBy: [
                SortDescriptor(\.weight, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        descriptor.fetchLimit = HTMLWorkspaceDataFeed.maxLimit * 4
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.edgeType != .quotes }
    }

    private static func graphRelatedNoteNode(
        from edge: SDGraphEdge,
        anchorNodeID: String,
        context: ModelContext
    ) -> SDGraphNode? {
        let relatedNodeID = edge.sourceNodeId == anchorNodeID ? edge.targetNodeId : edge.sourceNodeId
        guard relatedNodeID != anchorNodeID else { return nil }
        var descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.id == relatedNodeID }
        )
        descriptor.fetchLimit = 1
        guard let node = try? context.fetch(descriptor).first else { return nil }
        guard node.nodeType == .note || node.nodeType == .proseNote else { return nil }
        guard normalized(node.sourceId) != nil else { return nil }
        return node
    }

    private static func page(id pageID: String, context: ModelContext) -> SDPage? {
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.id == pageID }
        )
        descriptor.fetchLimit = 1
        guard let page = try? context.fetch(descriptor).first else { return nil }
        guard !page.isArchived, page.templateId == nil else { return nil }
        return page
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
