import Foundation
#if !EPISTEMOS_FREE_V1
import NaturalLanguage
#endif
import SwiftData

// MARK: - NodeInspectorState
// Observable state for the hologram node inspector panel.
// Manages selected node info, summaries, and neutral node profiles.
// Summaries use deterministic previews of the selected node's content.

@MainActor @Observable
final class NodeInspectorState {

    private struct ProfileCacheKey: Hashable {
        let nodeId: String
        let nodeUpdatedAt: Date
        let topologyVersion: Int
    }

    private struct BodyReadStage: Sendable {
        let pageId: String
        let filePath: String?
        let inlineBody: String
        let fallbackSummary: String
    }

    enum InspectorMode: Hashable { case profile, editor }

    // MARK: - Selection

    var selectedNodeId: String?
    var selectedNode: GraphNodeRecord?
    var inspectorMode: InspectorMode = .profile

    // MARK: - Summary

    var summaryText: String = ""
    var displayedSummary: String = ""
    var isSummarizing: Bool = false

    // MARK: - Profile (neutral node context)

    var profile: DialogueNodeProfile?

    // MARK: - Internal

    private var summaryTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var summaryCache: [String: String] = [:]
    private var profileCache: [ProfileCacheKey: DialogueNodeProfile] = [:]
    private var revealTask: Task<Void, Never>?

    // MARK: - Node Selection

    func selectNode(_ node: GraphNodeRecord?, store: GraphStore, modelContext: ModelContext) {
        guard let node else {
            clearSelection()
            return
        }
        guard node.id != selectedNodeId || selectedNode?.id != node.id else {
            return
        }

        // Set loading state and selection IMMEDIATELY — no blocking work here.
        // This ensures the panel animates in instantly; heavy work runs in background.
        inspectorMode = .profile
        summaryTask?.cancel()
        summaryTask = nil
        selectedNodeId = node.id
        selectedNode = node
        let cachedSummary = summaryCache[node.id]
        summaryText = cachedSummary ?? ""
        displayedSummary = cachedSummary ?? ""
        isSummarizing = false
        profile = nil
        revealTask?.cancel()
        profileTask?.cancel()
        profileTask = nil

        let nodeId = node.id
        let label = node.label
        let nodeType = node.type
        let sourceId = node.sourceId
        let nodeUpdatedAt = node.updatedAt
        let topologyVersion = store.topologyVersion
        let cacheKey = ProfileCacheKey(
            nodeId: nodeId,
            nodeUpdatedAt: nodeUpdatedAt,
            topologyVersion: topologyVersion
        )

        if let cachedProfile = profileCache[cacheKey] {
            profile = cachedProfile
        } else {
            // Derive profile asynchronously so selectNode() returns immediately.
            profileTask = Task {
                guard !Task.isCancelled, self.selectedNodeId == nodeId else { return }

                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, self.selectedNodeId == nodeId else { return }

                let linkedLabels = store.neighborLabels(of: nodeId)

                let noteBody: String
                if nodeType == .note, let sourceId {
                    if let liveBody = currentEditorBody(for: sourceId) {
                        noteBody = liveBody
                    } else {
                        let stage = stageBodyRead(
                            pageId: sourceId,
                            modelContext: modelContext,
                            logPrefix: "NodeInspectorState"
                        )
                        noteBody = await Self.bodyText(for: stage)
                    }
                } else {
                    noteBody = ""
                }
                guard !Task.isCancelled, self.selectedNodeId == nodeId else { return }

                let derived = await Task.detached(priority: .userInitiated) {
                    let linkedCount = linkedLabels.count
                    let stopWords: Set<String> = [
                        "about", "after", "again", "also", "because", "between", "could", "every", "first",
                        "from", "have", "into", "just", "like", "more", "most", "other", "over", "some",
                        "than", "that", "their", "them", "then", "there", "these", "they", "this", "those",
                        "under", "using", "very", "what", "when", "where", "which", "while", "with", "would",
                        "your", "note", "notes", "page", "pages"
                    ]

                    func normalizedTokens(in text: String) -> [String] {
                        text
                            .lowercased()
                            .split { !$0.isLetter && !$0.isNumber }
                            .map(String.init)
                    }

                    func focusKeywords(in body: String, linkedNodeLabels: [String]) -> [String] {
                        var counts: [String: Int] = [:]
                        for token in normalizedTokens(in: body) where token.count >= 4 && !stopWords.contains(token) {
                            counts[token, default: 0] += 1
                        }

                        let rankedBodyWords = counts
                            .sorted { lhs, rhs in
                                if lhs.value == rhs.value { return lhs.key < rhs.key }
                                return lhs.value > rhs.value
                            }
                            .map(\.key)

                        let linkedWords = linkedNodeLabels
                            .flatMap { normalizedTokens(in: $0) }
                            .filter { $0.count >= 4 && !stopWords.contains($0) }

                        var ordered: [String] = []
                        for candidate in rankedBodyWords + linkedWords {
                            if !ordered.contains(candidate) {
                                ordered.append(candidate)
                            }
                            if ordered.count == 4 { break }
                        }
                        return ordered
                    }

                    func contentRichness(
                        body: String,
                        linkedNodeLabels: [String],
                        keywords: [String]
                    ) -> Double {
                        let bodyScore = min(0.72, Double(body.count) / 2200.0)
                        let linkScore = min(0.18, Double(linkedNodeLabels.count) * 0.03)
                        let keywordScore = min(0.10, Double(keywords.count) * 0.03)
                        return min(1.0, bodyScore + linkScore + keywordScore)
                    }

                    func depthResilience(for insight: DialogueNodeInsight) -> Double {
                        switch insight.tier {
                        case .root: 0.18
                        case .branch: 0.14
                        case .focus: 0.10
                        case .detail: 0.07
                        case .trace: 0.04
                        }
                    }

                    func depthCuriosity(for insight: DialogueNodeInsight) -> Double {
                        switch insight.tier {
                        case .root: 0.02
                        case .branch: 0.05
                        case .focus: 0.08
                        case .detail: 0.10
                        case .trace: 0.12
                        }
                    }

                    let normalizedBody = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
                    let ml = ContentPersonalitySignals.analyze(normalizedBody)
                    let freqKeywords = focusKeywords(
                        in: normalizedBody,
                        linkedNodeLabels: linkedLabels
                    )
                    var keywords: [String] = []
                    for kw in ml.entityKeywords + ml.dominantTopics + freqKeywords {
                        let lower = kw.lowercased()
                        if !keywords.contains(where: { $0.lowercased() == lower }) {
                            keywords.append(kw)
                        }
                        if keywords.count >= 6 { break }
                    }

                    let contentWords = normalizedBody.split { !$0.isLetter && !$0.isNumber }.count
                    let structureDepth: Int = switch nodeType {
                    case .folder: 0
                    case .note, .chat: 2
                    case .idea, .source, .quote, .person, .project, .topic, .decision, .event, .resource: 3
                    case .tag, .block: 4
                    case .run, .rawThought, .toolTrace: 3
                    case .proseNote, .document: 2  // Wave 3.3 typed cognitive artifacts
                    case .code, .output: 3
                    }
                    let prominence = min(1.0, Double(contentWords) / 1800.0 + Double(linkedCount) * 0.04)
                    let tier: DialogueDepthTier = switch structureDepth {
                    case ..<1: .root
                    case 1: .branch
                    case 2...3: .focus
                    case 4...5: .detail
                    default: .trace
                    }
                    let resolvedInsight = DialogueNodeInsight(
                        structureDepth: structureDepth,
                        contentWords: contentWords,
                        childCount: linkedCount,
                        tier: tier,
                        prominence: prominence
                    )
                    let richness = contentRichness(
                        body: normalizedBody,
                        linkedNodeLabels: linkedLabels,
                        keywords: keywords
                    )
                    let mood = DialogueMood.steady
                    let summary: String = {
                        guard !normalizedBody.isEmpty else { return "" }
                        let collapsed = normalizedBody
                            .components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        guard !collapsed.isEmpty else { return "" }
                        return String(collapsed.prefix(180)) + (collapsed.count > 180 ? "…" : "")
                    }()
                    let portrait = DialoguePortraitAsset(symbol: "square.stack.3d.up.fill", crestLabel: "Node")
                    let careHealth = min(1.0, max(0.0, 0.20 + richness * 0.34 + resolvedInsight.prominence * 0.30 + depthResilience(for: resolvedInsight) * 0.14))
                    let careAttention = min(1.0, max(0.0, 0.34 + min(0.18, Double(linkedCount) * 0.025) + resolvedInsight.prominence * 0.18 + depthCuriosity(for: resolvedInsight)))
                    let care = DialogueCareState(
                        health: careHealth,
                        attention: careAttention,
                        mood: mood,
                        interactionCount: 0,
                        lastInteractionAt: nil
                    )

                    return DialogueNodeProfile(
                        nodeId: nodeId,
                        label: label,
                        nodeType: nodeType,
                        archetype: .sentinel,
                        summary: summary,
                        openingLine: "Ask about this node.",
                        focusKeywords: keywords,
                        portrait: portrait,
                        insight: resolvedInsight,
                        care: care
                    )
                }.value
                guard !Task.isCancelled, self.selectedNodeId == nodeId else { return }
                self.profileCache[cacheKey] = derived
                self.profile = derived
            }
        }

    }

    func clearSelection() {
        summaryTask?.cancel()
        revealTask?.cancel()
        profileTask?.cancel()
        profileTask = nil
        selectedNodeId = nil
        selectedNode = nil
        profile = nil
        summaryText = ""
        displayedSummary = ""
        isSummarizing = false
        inspectorMode = .profile
    }

    func clearCache() {
        summaryCache.removeAll()
        profileCache.removeAll()
    }

    func ensureSummary(for node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) {
        guard selectedNodeId == node.id else { return }
        if let cached = summaryCache[node.id] {
            summaryText = cached
            displayedSummary = cached
            isSummarizing = false
            return
        }
        guard !isSummarizing, summaryTask == nil else { return }
        summarizeNode(node, store: store, modelContext: modelContext)
    }

    // MARK: - Summarization

    private func summarizeNode(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) {
        summaryTask?.cancel()

        // Return cached summary instantly if available.
        if let cached = summaryCache[node.id] {
            summaryText = cached
            isSummarizing = false
            startSummaryReveal()
            return
        }

        isSummarizing = true
        summaryText = ""

        summaryTask = Task {
            defer {
                isSummarizing = false
                summaryTask = nil
            }

            let content = await fetchContent(for: node, store: store, modelContext: modelContext)
            guard !Task.isCancelled, selectedNodeId == node.id else { return }

            guard !content.isEmpty else {
                summaryText = "No content available for this node."
                startSummaryReveal()
                return
            }

            let summary = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
            guard !Task.isCancelled, selectedNodeId == node.id else { return }
            summaryText = summary
            summaryCache[node.id] = summary
            startSummaryReveal()
        }
    }

    private func startSummaryReveal() {
        revealTask?.cancel()
        let full = summaryText
        displayedSummary = full
    }

    // MARK: - Content Fetching

    private func fetchContent(for node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) async -> String {
        switch node.type {
        case .folder:
            return await fetchFolderContent(node, store: store, modelContext: modelContext)
        case .quote:
            return node.metadata.quoteText ?? node.label
        case .tag:
            return await fetchTagContent(node, store: store, modelContext: modelContext)
        default:
            return await fetchPageContent(node, modelContext: modelContext)
        }
    }

    private func currentEditorBody(for pageId: String) -> String? {
        NoteWindowManager.shared.editorBody(for: pageId)
    }

    private func liveEditorBodies(for pageIds: [String]) -> [String: String] {
        var bodies: [String: String] = [:]
        bodies.reserveCapacity(pageIds.count)
        for pageId in pageIds {
            if let body = currentEditorBody(for: pageId) {
                bodies[pageId] = body
            }
        }
        return bodies
    }

    private func stageBodyRead(from page: SDPage) -> BodyReadStage {
        BodyReadStage(
            pageId: page.id,
            filePath: page.filePath,
            inlineBody: page.body,
            fallbackSummary: page.summary
        )
    }

    private func stageBodyRead(pageId: String, modelContext: ModelContext, logPrefix: String) -> BodyReadStage {
        let targetId = pageId
        let predicate = #Predicate<SDPage> { $0.id == targetId }
        var descriptor = FetchDescriptor<SDPage>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            if let page = try modelContext.fetch(descriptor).first {
                return stageBodyRead(from: page)
            }
        } catch {
            Log.graph.error(
                "\(logPrefix): failed to fetch page summary for \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        return BodyReadStage(pageId: pageId, filePath: nil, inlineBody: "", fallbackSummary: "")
    }

    private func stagedBodyReads(
        for pageIds: [String],
        modelContext: ModelContext,
        logPrefix: String
    ) -> [String: BodyReadStage] {
        var stages: [String: BodyReadStage] = [:]
        stages.reserveCapacity(pageIds.count)
        for pageId in pageIds {
            stages[pageId] = stageBodyRead(
                pageId: pageId,
                modelContext: modelContext,
                logPrefix: logPrefix
            )
        }
        return stages
    }

    private nonisolated static func bodyText(for stage: BodyReadStage) async -> String {
        await SDPage.loadBodyAsyncFromPrimitives(
            pageId: stage.pageId,
            filePath: stage.filePath,
            inlineBody: stage.inlineBody,
            mapped: true,
            fast: true
        )
    }

    private nonisolated static func bodyTexts(
        for stages: [BodyReadStage?],
        liveBodies: [String: String]
    ) async -> [String] {
        await Task.detached(priority: .utility) { () async -> [String] in
            var bodies: [String] = []
            bodies.reserveCapacity(stages.count)
            for stage in stages {
                guard let stage else {
                    bodies.append("")
                    continue
                }
                if let liveBody = liveBodies[stage.pageId] {
                    bodies.append(liveBody)
                    continue
                }
                let body = await bodyText(for: stage)
                bodies.append(body.isEmpty ? stage.fallbackSummary : body)
            }
            return bodies
        }.value
    }

    private func fetchPageContent(_ node: GraphNodeRecord, modelContext: ModelContext) async -> String {
        guard let sourceId = node.sourceId else { return node.label }
        let label = node.label

        if let liveBody = currentEditorBody(for: sourceId) {
            return liveBody
        }

        let stage = stageBodyRead(
            pageId: sourceId,
            modelContext: modelContext,
            logPrefix: "NodeInspectorState"
        )
        let body = await Self.bodyText(for: stage)
        if !body.isEmpty { return body }
        if !stage.fallbackSummary.isEmpty { return stage.fallbackSummary }
        return label
    }

    private func fetchFolderContent(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) async -> String {
        guard let folderID = node.sourceId else {
            return await fetchConnectedContext(for: node, store: store, modelContext: modelContext)
        }

        let predicate = #Predicate<SDFolder> { $0.id == folderID }
        var descriptor = FetchDescriptor<SDFolder>(predicate: predicate)
        descriptor.fetchLimit = 1

        let folder: SDFolder
        do {
            guard let fetchedFolder = try modelContext.fetch(descriptor).first else {
                return await fetchConnectedContext(for: node, store: store, modelContext: modelContext)
            }
            folder = fetchedFolder
        } catch {
            Log.graph.error(
                "NodeInspectorState: failed to fetch folder \(String(folderID.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return await fetchConnectedContext(for: node, store: store, modelContext: modelContext)
        }

        let relativePath = folder.relativePath
        let nestedPrefix = relativePath.isEmpty ? "" : relativePath + "/"
        let childFolderNames = (folder.children ?? [])
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let pageDescriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        let allPages: [SDPage]
        do {
            allPages = try modelContext.fetch(pageDescriptor)
        } catch {
            Log.graph.error(
                "NodeInspectorState: failed to fetch folder pages for \(String(folderID.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return await fetchConnectedContext(for: node, store: store, modelContext: modelContext)
        }
        let descendantPages = Array(
            allPages.filter { page in
                if page.folder?.id == folderID {
                    return true
                }
                guard let subfolder = page.subfolder else { return false }
                return subfolder == relativePath || (!nestedPrefix.isEmpty && subfolder.hasPrefix(nestedPrefix))
            }
            .prefix(10)
        )

        let descendantPageIDs = descendantPages.map(\.id)
        let liveBodies = liveEditorBodies(for: descendantPageIDs)
        let pageBodies = await Self.bodyTexts(
            for: descendantPages.map { Optional(stageBodyRead(from: $0)) },
            liveBodies: liveBodies
        )

        var parts: [String] = [
            "Folder: \(node.label)",
            "Path: \(relativePath.isEmpty ? node.label : relativePath)",
            "Items loaded for context: \(descendantPages.count)"
        ]

        if !childFolderNames.isEmpty {
            parts.append("Subfolders: \(childFolderNames.prefix(8).joined(separator: ", "))")
        }

        for (index, page) in descendantPages.enumerated() {
            let body = pageBodies[index].trimmingCharacters(in: .whitespacesAndNewlines)
            let previewSource = body.isEmpty ? page.title : body
            let preview = String(previewSource.prefix(900))
            parts.append("Note: \(page.title)\n\(preview)")
        }

        let connectedContext = await fetchConnectedContext(
            for: node,
            store: store,
            modelContext: modelContext,
            excluding: Set(descendantPages.map(\.id))
        )
        if !connectedContext.isEmpty {
            parts.append(connectedContext)
        }

        return parts.joined(separator: "\n\n")
    }

    private func fetchTagContent(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) async -> String {
        let neighborIds = store.adjacency[node.id] ?? []
        let related: [(sourceId: String?, label: String)] = neighborIds.compactMap { store.nodes[$0] }
            .prefix(12)
            .map { (sourceId: $0.sourceId, label: $0.label) }

        let liveBodies = liveEditorBodies(for: related.compactMap(\.sourceId))
        let stagesById = stagedBodyReads(
            for: related.compactMap(\.sourceId),
            modelContext: modelContext,
            logPrefix: "NodeInspectorState"
        )
        let bodies = await Self.bodyTexts(
            for: related.map { rel in rel.sourceId.flatMap { stagesById[$0] } },
            liveBodies: liveBodies
        )

        var parts: [String] = ["Tag: \(node.label)\nRelated nodes:"]
        for (i, rel) in related.enumerated() {
            let content = bodies[i].isEmpty ? rel.label : bodies[i]
            let preview = String(content.prefix(400))
            parts.append("- \(rel.label): \(preview)")
        }
        return parts.joined(separator: "\n")
    }

    private func fetchConnectedContext(
        for node: GraphNodeRecord,
        store: GraphStore,
        modelContext: ModelContext,
        excluding excludedSourceIDs: Set<String> = []
    ) async -> String {
        let relatedNodes = (store.adjacency[node.id] ?? [])
            .compactMap { store.nodes[$0] }
            .filter { neighbor in
                guard neighbor.id != node.id else { return false }
                guard let sourceId = neighbor.sourceId else { return true }
                return !excludedSourceIDs.contains(sourceId)
            }
            .prefix(8)

        let relatedArray = Array(relatedNodes)
        guard !relatedArray.isEmpty else { return "" }

        let liveBodies = liveEditorBodies(for: relatedArray.compactMap(\.sourceId))
        let stagesById = stagedBodyReads(
            for: relatedArray.compactMap(\.sourceId),
            modelContext: modelContext,
            logPrefix: "NodeInspectorState"
        )
        let previews = await Self.bodyTexts(
            for: relatedArray.map { related in related.sourceId.flatMap { stagesById[$0] } },
            liveBodies: liveBodies
        )

        var lines = ["Connected graph context:"]
        for (index, related) in relatedArray.enumerated() {
            let fallback = related.metadata.abstract ?? related.metadata.quoteText ?? related.label
            let previewSource = previews[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? fallback
                : previews[index]
            let preview = String(previewSource.prefix(420))
            lines.append("- \(related.label) (\(related.type.displayName)): \(preview)")
        }
        return lines.joined(separator: "\n")
    }

}
