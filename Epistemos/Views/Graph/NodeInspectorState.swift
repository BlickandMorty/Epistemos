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
    private var revealTask: Task<Void, Never>?

    // MARK: - Node Selection

    func selectNode(_ node: GraphNodeRecord?, store: GraphStore, modelContext: ModelContext) {
        guard let node, node.id != selectedNodeId else {
            if node == nil { clearSelection() }
            return
        }

        // Set loading state and selection IMMEDIATELY — no blocking work here.
        // This ensures the panel animates in instantly; heavy work runs in background.
        isSummarizing = true
        chatMessages = []
        chatInput = ""
        isChatStreaming = false
        inspectorMode = .profile
        selectedNodeId = node.id
        selectedNode = node
        summaryText = ""
        displayedSummary = ""
        profile = nil
        revealTask?.cancel()
        profileTask?.cancel()

        // Derive profile asynchronously: disk read + NLP derivation are deferred
        // so that selectNode() returns instantly and the panel animates in immediately.
        // The profile appears a moment later when the Task completes.
        let linkedLabels = store.neighbors(of: node.id).map(\.label)
        let nodeId = node.id
        let label = node.label
        let nodeType = node.type
        let sourceId = node.sourceId

        profileTask = Task {
            guard !Task.isCancelled, self.selectedNodeId == nodeId else { return }

            // File I/O off main actor (NoteFileStorage.readBody is nonisolated static).
            let noteBody: String
            if nodeType == .note, let sourceId {
                noteBody = await Task.detached {
                    NoteFileStorage.readBody(pageId: sourceId)
                }.value
            } else {
                noteBody = ""
            }
            guard !Task.isCancelled, self.selectedNodeId == nodeId else { return }

            // derive() is main-actor isolated (NLP analysis), but file I/O is already done.
            let derived = DialogueNodeProfile.derive(
                nodeId: nodeId, label: label, nodeType: nodeType,
                noteBody: noteBody, linkedNodeLabels: linkedLabels
            )
            guard !Task.isCancelled, self.selectedNodeId == nodeId else { return }
            self.profile = derived
        }

        summarizeNode(node, store: store, modelContext: modelContext)
    }

    func clearSelection() {
        summaryTask?.cancel()
        chatTask?.cancel()
        revealTask?.cancel()
        profileTask?.cancel()
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
            defer { isSummarizing = false }

            let content = await fetchContent(for: node, store: store, modelContext: modelContext)

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
                guard !Task.isCancelled else { return }

                if TriageService.shouldRetryWithLocalModel(result) {
                    throw AppleIntelligenceError.unavailable("Response inadequate")
                }
                summaryText = result
                summaryCache[node.id] = result
                startSummaryReveal()
            } catch {
                guard !Task.isCancelled else { return }
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
                        guard !Task.isCancelled else { return }
                        if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            summaryText = result
                            summaryCache[node.id] = result
                        } else {
                            summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                        }
                        startSummaryReveal()
                    } catch let error as LocalInferenceRoutingError {
                        guard !Task.isCancelled else { return }
                        summaryText = error.localizedDescription
                        startSummaryReveal()
                    } catch {
                        guard !Task.isCancelled else { return }
                        Log.engine.info("Local Qwen also unavailable for summary: \(error.localizedDescription, privacy: .public)")
                        summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                        startSummaryReveal()
                    }
                } else {
                    summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                    startSummaryReveal()
                }
            }
        }
    }

    private func startSummaryReveal() {
        revealTask?.cancel()
        let full = summaryText
        guard !full.isEmpty else {
            displayedSummary = ""
            return
        }
        displayedSummary = ""
        revealTask = Task {
            var pos = full.startIndex
            while pos < full.endIndex, !Task.isCancelled {
                let next = full.index(pos, offsetBy: 2, limitedBy: full.endIndex) ?? full.endIndex
                pos = next
                displayedSummary = String(full[..<pos])
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
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

    private func fetchPageContent(_ node: GraphNodeRecord, modelContext: ModelContext) async -> String {
        guard let sourceId = node.sourceId else { return node.label }
        let label = node.label

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
        let neighborIds = store.adjacency[node.id] ?? []
        let children: [(sourceId: String?, label: String)] = neighborIds.compactMap { store.nodes[$0] }
            .filter { $0.type != .folder }
            .prefix(15)
            .map { (sourceId: $0.sourceId, label: $0.label) }

        // Batch file reads off main actor.
        let bodies = await Task.detached {
            children.map { child in
                guard let sid = child.sourceId else { return "" }
                return NoteFileStorage.readBody(pageId: sid)
            }
        }.value

        var parts: [String] = ["Folder: \(node.label)\n"]
        for (i, child) in children.enumerated() {
            let content = bodies[i].isEmpty ? child.label : bodies[i]
            let preview = String(content.prefix(800))
            parts.append("- \(child.label): \(preview)")
        }
        return parts.joined(separator: "\n")
    }

    private func fetchTagContent(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) async -> String {
        let neighborIds = store.adjacency[node.id] ?? []
        let related: [(sourceId: String?, label: String)] = neighborIds.compactMap { store.nodes[$0] }
            .prefix(12)
            .map { (sourceId: $0.sourceId, label: $0.label) }

        // Batch file reads off main actor.
        let bodies = await Task.detached {
            related.map { rel in
                guard let sid = rel.sourceId else { return "" }
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
        context += "Content:\n\(String(nodeContent.prefix(3000)))\n\n"
        context += "Answer the user's question directly from this content. If the content does not answer it, say so plainly.\n\n"
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
