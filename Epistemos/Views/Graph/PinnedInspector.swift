// MARK: - PinnedInspector
// A persistent inspector panel attached to a specific node.
// Survives deselection and follows its node as it moves.

import SwiftUI
import SwiftData

@MainActor @Observable
final class PinnedInspector: Identifiable {
    let id: String
    let nodeId: String
    private var nodeReference: GraphNodeRecord?
    
    var inspectorMode: NodeInspectorState.InspectorMode = .profile
    var summaryText: String = ""
    var displayedSummary: String = ""
    var isSummarizing: Bool = false
    var profile: DialogueNodeProfile?
    var chatMessages: [InspectorChatMessage] = []
    var chatInput: String = ""
    var isChatStreaming: Bool = false
    
    private var summaryTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var summaryCache: [String: String] = [:]
    private var profileCache: [ProfileCacheKey: DialogueNodeProfile] = [:]
    
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
    
    init(node: GraphNodeRecord) {
        self.id = UUID().uuidString
        self.nodeId = node.id
        self.nodeReference = node
        self.summaryCache = [:]
    }
    
    var node: GraphNodeRecord? {
        nodeReference
    }
    
    func updateNodeReference(from store: GraphStore) {
        nodeReference = store.nodes[nodeId]
    }
    
    func close() {
        summaryTask?.cancel()
        chatTask?.cancel()
        profileTask?.cancel()
    }
    
    // MARK: - Summarization
    
    func ensureSummary(store: GraphStore, modelContext: ModelContext) {
        guard let node = nodeReference else { return }
        if let cached = summaryCache[node.id] {
            summaryText = cached
            displayedSummary = cached
            isSummarizing = false
            return
        }
        guard !isSummarizing, summaryTask == nil else { return }
        summarizeNode(node, store: store, modelContext: modelContext)
    }
    
    private func summarizeNode(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) {
        summaryTask?.cancel()
        
        if let cached = summaryCache[node.id] {
            summaryText = cached
            isSummarizing = false
            displayedSummary = cached
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
            guard !Task.isCancelled else { return }
            
            guard !content.isEmpty else {
                summaryText = "No content available for this node."
                displayedSummary = summaryText
                return
            }
            
            let prompt = buildSummaryPrompt(node: node, content: content)
            
            do {
                let result = try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: nil
                )
                guard !Task.isCancelled else { return }
                
                if TriageService.shouldRetryWithLocalModel(result) {
                    throw AppleIntelligenceError.unavailable("Response inadequate")
                }
                summaryText = result
                summaryCache[node.id] = result
                displayedSummary = result
            } catch {
                guard !Task.isCancelled else { return }
                if let triage = AppBootstrap.shared?.triageService {
                    do {
                        let result = try await triage.generateGeneral(
                            prompt: prompt,
                            systemPrompt: nil,
                            operation: .brainstorm,
                            contentLength: prompt.count,
                            localSurface: .graph
                        )
                        guard !Task.isCancelled else { return }
                        if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            summaryText = result
                            summaryCache[node.id] = result
                        } else {
                            summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                        }
                        displayedSummary = summaryText
                    } catch {
                        guard !Task.isCancelled else { return }
                        summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                        displayedSummary = summaryText
                    }
                } else {
                    summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                    displayedSummary = summaryText
                }
            }
        }
    }
    
    private func buildSummaryPrompt(node: GraphNodeRecord, content: String) -> String {
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
    
    private func fetchPageContent(_ node: GraphNodeRecord, modelContext: ModelContext) async -> String {
        guard let sourceId = node.sourceId else { return node.label }
        
        // Check live editor first
        if let liveBody = NoteWindowManager.shared.editorBody(for: sourceId) {
            return liveBody
        }

        let stage = stageBodyRead(
            pageId: sourceId,
            modelContext: modelContext,
            logPrefix: "PinnedInspector"
        )
        let body = await bodyText(for: stage)
        if !body.isEmpty { return body }
        if !stage.fallbackSummary.isEmpty { return stage.fallbackSummary }
        return node.label
    }

    private func stageBodyRead(pageId: String, modelContext: ModelContext, logPrefix: String) -> BodyReadStage {
        let targetId = pageId
        let predicate = #Predicate<SDPage> { $0.id == targetId }
        var descriptor = FetchDescriptor<SDPage>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            if let page = try modelContext.fetch(descriptor).first {
                return BodyReadStage(
                    pageId: page.id,
                    filePath: page.filePath,
                    inlineBody: page.body,
                    fallbackSummary: page.summary
                )
            }
        } catch {
            Log.graph.error(
                "\(logPrefix): failed to fetch page summary for \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        return BodyReadStage(pageId: pageId, filePath: nil, inlineBody: "", fallbackSummary: "")
    }

    private nonisolated func bodyText(for stage: BodyReadStage) async -> String {
        await SDPage.loadBodyAsyncFromPrimitives(
            pageId: stage.pageId,
            filePath: stage.filePath,
            inlineBody: stage.inlineBody,
            mapped: true,
            fast: true
        )
    }
    
    private func fetchFolderContent(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) async -> String {
        guard let folderID = node.sourceId else { return "" }
        
        let predicate = #Predicate<SDFolder> { $0.id == folderID }
        var descriptor = FetchDescriptor<SDFolder>(predicate: predicate)
        descriptor.fetchLimit = 1

        let folder: SDFolder
        do {
            guard let fetchedFolder = try modelContext.fetch(descriptor).first else { return "" }
            folder = fetchedFolder
        } catch {
            Log.graph.error(
                "PinnedInspector: failed to fetch folder \(String(folderID.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return ""
        }
        
        let relativePath = folder.relativePath
        let nestedPrefix = relativePath.isEmpty ? "" : relativePath + "/"
        
        let pageDescriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        let allPages: [SDPage]
        do {
            allPages = try modelContext.fetch(pageDescriptor)
        } catch {
            Log.graph.error(
                "PinnedInspector: failed to fetch folder pages for \(String(folderID.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return "Folder: \(node.label)\nItems: 0"
        }
        let descendantPages = Array(
            allPages.filter { page in
                if page.folder?.id == folderID { return true }
                guard let subfolder = page.subfolder else { return false }
                return subfolder == relativePath || (!nestedPrefix.isEmpty && subfolder.hasPrefix(nestedPrefix))
            }.prefix(10)
        )
        
        var parts: [String] = [
            "Folder: \(node.label)",
            "Items: \(descendantPages.count)"
        ]
        
        for page in descendantPages.prefix(5) {
            parts.append("- \(page.title)")
        }
        
        return parts.joined(separator: "\n")
    }
    
    private func fetchTagContent(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) async -> String {
        let neighborIds = store.adjacency[node.id] ?? []
        let related = neighborIds.compactMap { store.nodes[$0] }.prefix(12)
        
        var parts: [String] = ["Tag: \(node.label)", "Related:"]
        for rel in related {
            parts.append("- \(rel.label)")
        }
        return parts.joined(separator: "\n")
    }
    
    // MARK: - Chat
    
    func sendMessage(
        store: GraphStore,
        modelContext: ModelContext,
        operatingMode: EpistemosOperatingMode = .fast
    ) {
        let query = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isChatStreaming else { return }
        guard let node = nodeReference else { return }
        
        chatInput = ""
        chatMessages.append(InspectorChatMessage(role: .user, text: query))
        chatMessages.append(InspectorChatMessage(role: .assistant, text: ""))
        isChatStreaming = true
        
        chatTask?.cancel()
        chatTask = Task {
            defer { isChatStreaming = false }
            
            let content = await fetchContent(for: node, store: store, modelContext: modelContext)
            var context = "Selected node: \(node.label) (\(node.type.displayName))\n\n"
            context += "Node context:\n\(String(content.prefix(4200)))\n\n"
            context += "User question: \(query)"
            
            guard let triage = AppBootstrap.shared?.triageService else {
                appendToLastAssistant("AI service unavailable.")
                return
            }
            
            let stream = triage.streamGeneral(
                prompt: context,
                systemPrompt: nil,
                operation: .chatResponse(query: query),
                contentLength: context.count,
                operatingMode: operatingMode,
                localSurface: .graph
            )
            
            do {
                for try await chunk in stream {
                    guard !Task.isCancelled else { return }
                    appendToLastAssistant(chunk)
                }
                finalizeLastAssistantText()
            } catch {
                guard !Task.isCancelled else { return }
                if chatMessages.last?.text.isEmpty == true {
                    appendToLastAssistant(UserFacingChatError.message(from: error))
                }
            }
        }
    }
    
    func stopChat() {
        chatTask?.cancel()
        chatTask = nil
        isChatStreaming = false
    }
    
    private func appendToLastAssistant(_ text: String) {
        guard let lastIndex = chatMessages.indices.last,
              chatMessages[lastIndex].role == .assistant else { return }
        chatMessages[lastIndex].text += text
    }

    private func finalizeLastAssistantText() {
        guard let lastIndex = chatMessages.indices.last,
              chatMessages[lastIndex].role == .assistant else { return }

        let visibleText = UserFacingModelOutput.finalVisibleText(from: chatMessages[lastIndex].text)
        chatMessages[lastIndex].text =
            visibleText.isEmpty
            ? "The model finished without a usable answer. Try Fast mode or another model."
            : visibleText
    }
}

// MARK: - PinnedInspectorManager

@MainActor @Observable
final class PinnedInspectorManager {
    static let shared = PinnedInspectorManager()
    
    var pinnedInspectors: [PinnedInspector] = []
    
    func pin(node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) -> PinnedInspector {
        // Check if already pinned
        if let existing = pinnedInspectors.first(where: { $0.nodeId == node.id }) {
            return existing
        }
        
        let inspector = PinnedInspector(node: node)
        pinnedInspectors.append(inspector)
        
        // Load summary
        inspector.ensureSummary(store: store, modelContext: modelContext)
        
        return inspector
    }
    
    func unpin(inspectorId: String) {
        if let index = pinnedInspectors.firstIndex(where: { $0.id == inspectorId }) {
            pinnedInspectors[index].close()
            pinnedInspectors.remove(at: index)
        }
    }
    
    func unpin(nodeId: String) {
        if let index = pinnedInspectors.firstIndex(where: { $0.nodeId == nodeId }) {
            pinnedInspectors[index].close()
            pinnedInspectors.remove(at: index)
        }
    }
    
    func updateNodeReferences(from store: GraphStore) {
        for inspector in pinnedInspectors {
            inspector.updateNodeReference(from: store)
        }
    }
    
    func closeAll() {
        for inspector in pinnedInspectors {
            inspector.close()
        }
        pinnedInspectors.removeAll()
    }
}

// MARK: - PinnedInspectorPanel (SwiftUI card)

/// Compact floating card that renders a pinned inspector. Positioned by
/// the overlay at the node's screen coordinates.
struct PinnedInspectorPanel: View {
    @Bindable var inspector: PinnedInspector
    let theme: EpistemosTheme
    let onClose: () -> Void

    init(
        inspector: PinnedInspector,
        theme: EpistemosTheme = .platinumViolet,
        onClose: @escaping () -> Void
    ) {
        self.inspector = inspector
        self.theme = theme
        self.onClose = onClose
    }

    var body: some View {
        // RCA finalization 2026-05-13: thread the theme through the
        // pinned-inspector card so Classic gets ChonkyPixels + ALL
        // CAPS on its title + summary lines (matching the Classic
        // hero treatment in LiquidGreeting). Other themes keep the
        // system font sizes unchanged.
        let titleFont = AppDisplayTypography.panelFont(size: 12, weight: .semibold, theme: theme)
        let bodyFont = AppDisplayTypography.panelFont(size: 11, weight: .regular, theme: theme)
        let nodeLabel = inspector.node?.label ?? "Node"
        // 2026-05-13 fifth pass: on Ember, panel labels route through
        // `boxedLabelText` (lowercase) so ColorBasic renders the
        // white-on-black boxed glyph form. Other themes pass through.
        let titleText = theme.boxedLabelText(nodeLabel)
        let summarizingText = theme.boxedLabelText("Summarizing...")
        let emptyText = theme.boxedLabelText("No summary yet")
        return VStack(alignment: .leading, spacing: 8) {
            // Header: node name + close button
            HStack {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(titleText)
                    .font(titleFont)
                    .lineLimit(1)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider().opacity(0.3)

            // Summary content
            if inspector.isSummarizing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(summarizingText)
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                }
            } else if !inspector.displayedSummary.isEmpty {
                let summary = inspector.displayedSummary
                let displayedSummary = theme.boxedLabelText(summary)
                Text(displayedSummary)
                    .font(bodyFont)
                    .foregroundStyle(.primary)
                    .lineLimit(8)
            } else {
                Text(emptyText)
                    .font(bodyFont)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(width: 260)
        // 2026-05-20 single-blur policy: pinned inspectors live inside
        // the main graph window which already carries one
        // NSVisualEffectView (HologramOverlay.swift). Themed tint reads
        // through that single blur — no per-panel Material kernel.
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(theme.isDark ? 0.25 : 0.10), radius: 8, x: 0, y: 2)
    }
}
