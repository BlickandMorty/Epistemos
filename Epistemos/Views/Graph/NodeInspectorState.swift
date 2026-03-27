import Foundation
import NaturalLanguage
import SwiftData

// MARK: - NodeInspectorState
// Observable state for the hologram node inspector panel.
// Manages: selected node info, AI summary, chat messages, streaming state.
// Summaries use Apple Intelligence directly for quick on-device work.
// Chat uses TriageService for deeper local reasoning.

@MainActor @Observable
final class NodeInspectorState {

    private struct ProfileCacheKey: Hashable {
        let nodeId: String
        let nodeUpdatedAt: Date
        let topologyVersion: Int
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

    // MARK: - Chat

    var chatMessages: [InspectorChatMessage] = []
    var chatInput: String = ""
    var isChatStreaming: Bool = false
    var chatScope: ChatScope = .node

    enum ChatScope: String, CaseIterable {
        case node = "Node"
    }

    // MARK: - Internal

    private var summaryTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var summaryCache: [String: String] = [:]
    private var profileCache: [ProfileCacheKey: DialogueNodeProfile] = [:]
    private var revealTask: Task<Void, Never>?

    // MARK: - Node Selection

    func selectNode(_ node: GraphNodeRecord?, store: GraphStore, modelContext: ModelContext) {
        guard let node, node.id != selectedNodeId else {
            if node == nil { clearSelection() }
            return
        }

        // Set loading state and selection IMMEDIATELY — no blocking work here.
        // This ensures the panel animates in instantly; heavy work runs in background.
        chatMessages = []
        chatInput = ""
        isChatStreaming = false
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
                        noteBody = await Task.detached {
                            NoteFileStorage.readBody(pageId: sourceId)
                        }.value
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
                    case .idea, .source, .quote: 3
                    case .tag, .block: 4
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
        chatTask?.cancel()
        revealTask?.cancel()
        profileTask?.cancel()
        profileTask = nil
        selectedNodeId = nil
        selectedNode = nil
        profile = nil
        summaryText = ""
        displayedSummary = ""
        isSummarizing = false
        chatMessages = []
        chatInput = ""
        isChatStreaming = false
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

            let prompt = buildSummaryPrompt(node: node, content: content)

            // Try Apple Intelligence first for a fast on-device summary, then local Qwen.
            do {
                let result = try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: nil
                )
                guard !Task.isCancelled, selectedNodeId == node.id else { return }

                if TriageService.shouldRetryWithLocalModel(result) {
                    throw AppleIntelligenceError.unavailable("Response inadequate")
                }
                summaryText = result
                summaryCache[node.id] = result
                startSummaryReveal()
            } catch {
                guard !Task.isCancelled, selectedNodeId == node.id else { return }
                Log.engine.info("Apple Intelligence unavailable for summary, trying local Qwen: \(error.localizedDescription, privacy: .public)")
                if let triage = AppBootstrap.shared?.triageService {
                    do {
                        let result = try await triage.generateGeneral(
                            prompt: prompt,
                            systemPrompt: nil,
                            operation: .brainstorm,
                            contentLength: prompt.count,
                            localSurface: .graph
                        )
                        guard !Task.isCancelled, selectedNodeId == node.id else { return }
                        if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            summaryText = result
                            summaryCache[node.id] = result
                        } else {
                            summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                        }
                        startSummaryReveal()
                    } catch let error as LocalInferenceRoutingError {
                        guard !Task.isCancelled, selectedNodeId == node.id else { return }
                        summaryText = error.localizedDescription
                        startSummaryReveal()
                    } catch {
                        guard !Task.isCancelled, selectedNodeId == node.id else { return }
                        Log.engine.info("Local Qwen also unavailable for summary: \(error.localizedDescription, privacy: .public)")
                        summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                        startSummaryReveal()
                    }
                } else {
                    guard selectedNodeId == node.id else { return }
                    summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                    startSummaryReveal()
                }
            }
        }
    }

    private func startSummaryReveal() {
        revealTask?.cancel()
        let full = summaryText
        displayedSummary = full
    }

    private func buildSummaryPrompt(node: GraphNodeRecord, content: String) -> String {
        // Trim content for on-device model — keep it focused.
        let trimmed = String(content.prefix(2000))

        switch node.type {
        case .folder:
            return "Summarize this folder's contents in 3-5 sentences. Focus on the main themes that connect these items.\n\n\(trimmed)"
        case .quote:
            if let quoteText = node.metadata.quoteText {
                return "Explain what this quote is saying and why it matters in 3-5 sentences.\n\n\"\(quoteText)\"\n\nContext:\n\(trimmed)"
            }
            return "Summarize the key arguments and themes in 3-5 sentences.\n\n\(trimmed)"
        case .tag:
            return "Summarize the main patterns that emerge across the notes connected by this tag.\n\n\(trimmed)"
        default:
            return "Summarize this note in 3-5 sentences. Cover the main arguments, key insights, and implications.\n\n\(trimmed)"
        }
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

    private func fetchPageContent(_ node: GraphNodeRecord, modelContext: ModelContext) async -> String {
        guard let sourceId = node.sourceId else { return node.label }
        let label = node.label

        if let liveBody = currentEditorBody(for: sourceId) {
            return liveBody
        }

        // File I/O off main actor (NoteFileStorage.readBody is nonisolated static).
        let body = await Task.detached {
            NoteFileStorage.readBody(pageId: sourceId)
        }.value
        if !body.isEmpty { return body }

        // Fallback: SwiftData page summary if body file doesn't exist (rare, stays on main).
        let predicate = #Predicate<SDPage> { $0.id == sourceId }
        var descriptor = FetchDescriptor<SDPage>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let page = try? modelContext.fetch(descriptor).first, !page.summary.isEmpty {
            return page.summary
        }
        return label
    }

    private func fetchFolderContent(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) async -> String {
        guard let folderID = node.sourceId else {
            return await fetchConnectedContext(for: node, store: store)
        }

        let predicate = #Predicate<SDFolder> { $0.id == folderID }
        var descriptor = FetchDescriptor<SDFolder>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let folder = try? modelContext.fetch(descriptor).first else {
            return await fetchConnectedContext(for: node, store: store)
        }

        let relativePath = folder.relativePath
        let nestedPrefix = relativePath.isEmpty ? "" : relativePath + "/"
        let childFolderNames = (folder.children ?? [])
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let pageDescriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        let allPages = (try? modelContext.fetch(pageDescriptor)) ?? []
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
        let pageBodies = await Task.detached {
            descendantPageIDs.map { pageID in
                if let liveBody = liveBodies[pageID] {
                    return liveBody
                }
                return NoteFileStorage.readBody(pageId: pageID)
            }
        }.value

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

        let connectedContext = await fetchConnectedContext(for: node, store: store, excluding: Set(descendantPages.map(\.id)))
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
        // Batch file reads off main actor.
        let bodies = await Task.detached {
            related.map { rel in
                guard let sid = rel.sourceId else { return "" }
                if let liveBody = liveBodies[sid] {
                    return liveBody
                }
                return NoteFileStorage.readBody(pageId: sid)
            }
        }.value

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
        let previews = await Task.detached {
            relatedArray.map { related -> String in
                guard let sourceId = related.sourceId else {
                    return related.metadata.abstract ?? related.metadata.quoteText ?? related.label
                }
                if let liveBody = liveBodies[sourceId] {
                    return liveBody
                }
                let body = NoteFileStorage.readBody(pageId: sourceId).trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    return body
                }
                return related.metadata.abstract ?? related.metadata.quoteText ?? related.label
            }
        }.value

        var lines = ["Connected graph context:"]
        for (index, related) in relatedArray.enumerated() {
            let preview = String(previews[index].prefix(420))
            lines.append("- \(related.label) (\(related.type.displayName)): \(preview)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Chat

    func sendMessage(store: GraphStore, modelContext: ModelContext) {
        let query = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isChatStreaming else { return }

        chatInput = ""
        chatMessages.append(InspectorChatMessage(role: .user, text: query))
        chatMessages.append(InspectorChatMessage(role: .assistant, text: ""))
        isChatStreaming = true

        chatTask?.cancel()
        chatTask = Task {
            defer { isChatStreaming = false }

            let context = await buildChatContext(query: query, store: store, modelContext: modelContext)

            guard let triage = AppBootstrap.shared?.triageService else {
                appendToLastAssistant("AI service unavailable.")
                return
            }

            let stream = triage.streamGeneral(
                prompt: context,
                systemPrompt: nil,
                operation: .chatResponse(query: query),
                contentLength: context.count
            )

            do {
                for try await chunk in stream {
                    guard !Task.isCancelled else { return }
                    appendToLastAssistant(chunk)
                }
            } catch {
                guard !Task.isCancelled else { return }
                if chatMessages.last?.text.isEmpty == true {
                    appendToLastAssistant("Failed to get response: \(error.localizedDescription)")
                }
            }
        }
    }

    private func appendToLastAssistant(_ text: String) {
        guard let lastIndex = chatMessages.indices.last,
              chatMessages[lastIndex].role == .assistant else { return }
        chatMessages[lastIndex].text += text
    }

    private func buildChatContext(query: String, store: GraphStore, modelContext: ModelContext) async -> String {
        guard let node = selectedNode else { return query }

        let nodeContent = await fetchContent(for: node, store: store, modelContext: modelContext)
        var context = "Selected node: \(node.label) (\(node.type.displayName))\n\n"
        context += "Node context:\n\(String(nodeContent.prefix(4200)))\n\n"
        context += "Answer from the selected node and its linked context. Treat folder context as a bundle of descendant notes and relationships, not just the folder label. If something is genuinely missing, say what is missing briefly.\n\n"
        context += "User question: \(query)"
        return context
    }
}

// MARK: - Chat Message

struct InspectorChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String

    enum Role { case user, assistant }
}
