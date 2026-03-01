import Foundation
import SwiftData

// MARK: - NodeInspectorState
// Observable state for the hologram node inspector panel.
// Manages: selected node info, AI summary, chat messages, streaming state.
// Summaries use Apple Intelligence directly (fast, free, on-device).
// Chat uses TriageService for deeper reasoning with cloud fallback.

@MainActor @Observable
final class NodeInspectorState {

    // MARK: - Selection

    var selectedNodeId: String?
    var selectedNode: GraphNodeRecord?

    // MARK: - Summary

    var summaryText: String = ""
    var isSummarizing: Bool = false

    // MARK: - Chat

    var chatMessages: [InspectorChatMessage] = []
    var chatInput: String = ""
    var isChatStreaming: Bool = false
    var chatScope: ChatScope = .node

    enum ChatScope: String, CaseIterable {
        case node = "Node"
        case knowledgeBase = "Knowledge Base"
    }

    // MARK: - Internal

    private var summaryTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var summaryCache: [String: String] = [:]

    // MARK: - Node Selection

    func selectNode(_ node: GraphNodeRecord?, store: GraphStore, modelContext: ModelContext) {
        guard let node, node.id != selectedNodeId else {
            if node == nil { clearSelection() }
            return
        }

        // Set loading state BEFORE setting selectedNode —
        // this ensures the spinner is ready when the panel animates in.
        isSummarizing = true
        chatMessages = []
        chatInput = ""
        isChatStreaming = false

        // Now set selection (triggers panel animation).
        selectedNodeId = node.id
        selectedNode = node
        summaryText = ""

        summarizeNode(node, store: store, modelContext: modelContext)
    }

    func clearSelection() {
        summaryTask?.cancel()
        chatTask?.cancel()
        selectedNodeId = nil
        selectedNode = nil
        summaryText = ""
        isSummarizing = false
        chatMessages = []
        chatInput = ""
        isChatStreaming = false
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
            return
        }

        isSummarizing = true
        summaryText = ""

        summaryTask = Task {
            defer { isSummarizing = false }

            let content = fetchContent(for: node, store: store, modelContext: modelContext)

            guard !content.isEmpty else {
                summaryText = "No content available for this node."
                return
            }

            let prompt = buildSummaryPrompt(node: node, content: content)
            let systemPrompt = """
            Summarize this note concisely. Cover the main ideas, key arguments, and any notable connections. \
            Write 3-5 sentences. Be analytical, not surface-level.
            """

            // Try Apple Intelligence first (fast, free, on-device), then cloud API fallback.
            do {
                let result = try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt
                )
                guard !Task.isCancelled else { return }

                if TriageService.shouldFallbackToAPI(result) {
                    throw AppleIntelligenceError.unavailable("Response inadequate")
                }
                summaryText = result
                summaryCache[node.id] = result
            } catch {
                guard !Task.isCancelled else { return }
                Log.engine.info("Apple Intelligence unavailable for summary, trying cloud API: \(error.localizedDescription, privacy: .public)")
                // Fallback: use the user's configured cloud API via triage service.
                if let triage = AppBootstrap.shared?.triageService {
                    do {
                        let result = try await triage.generateGeneral(
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            operation: .brainstorm,
                            contentLength: prompt.count
                        )
                        guard !Task.isCancelled else { return }
                        if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            summaryText = result
                            summaryCache[node.id] = result
                        } else {
                            summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        Log.engine.info("Cloud API also unavailable for summary: \(error.localizedDescription, privacy: .public)")
                        summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                    }
                } else {
                    summaryText = String(content.prefix(300)) + (content.count > 300 ? "…" : "")
                }
            }
        }
    }

    private func buildSummaryPrompt(node: GraphNodeRecord, content: String) -> String {
        // Trim content for on-device model — keep it focused.
        let trimmed = String(content.prefix(2000))

        switch node.type {
        case .folder:
            return "Summarize this folder's contents. What themes connect these items?\n\n\(trimmed)"
        case .quote:
            if let quoteText = node.metadata.quoteText {
                return "What is the author saying in this quote, and why does it matter?\n\n\"\(quoteText)\"\n\nContext:\n\(trimmed)"
            }
            return "Summarize the key arguments and themes:\n\n\(trimmed)"
        case .tag:
            return "This tag connects multiple notes. What patterns emerge across the related content?\n\n\(trimmed)"
        default:
            return "Summarize this note — cover the main arguments, key insights, and implications:\n\n\(trimmed)"
        }
    }

    // MARK: - Content Fetching

    private func fetchContent(for node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) -> String {
        switch node.type {
        case .folder:
            return fetchFolderContent(node, store: store, modelContext: modelContext)
        case .quote:
            return node.metadata.quoteText ?? node.label
        case .tag:
            return fetchTagContext(node, store: store, modelContext: modelContext)
        default:
            return fetchPageContent(node, modelContext: modelContext)
        }
    }

    private func fetchPageContent(_ node: GraphNodeRecord, modelContext: ModelContext) -> String {
        guard let sourceId = node.sourceId else { return node.label }

        let predicate = #Predicate<SDPage> { $0.id == sourceId }
        var descriptor = FetchDescriptor<SDPage>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let pages = try? modelContext.fetch(descriptor),
              let page = pages.first else {
            return node.label
        }

        let pageBody = page.loadBody()
        return pageBody.isEmpty ? (page.summary.isEmpty ? node.label : page.summary) : pageBody
    }

    private func fetchFolderContent(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) -> String {
        let neighborIds = store.adjacency[node.id] ?? []
        let children = neighborIds.compactMap { store.nodes[$0] }
            .filter { $0.type != .folder }
            .prefix(15)

        var parts: [String] = ["Folder: \(node.label)\n"]
        for child in children {
            let content = fetchPageContent(child, modelContext: modelContext)
            let preview = String(content.prefix(800))
            parts.append("- \(child.label): \(preview)")
        }
        return parts.joined(separator: "\n")
    }

    private func fetchTagContext(_ node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext) -> String {
        let neighborIds = store.adjacency[node.id] ?? []
        let related = neighborIds.compactMap { store.nodes[$0] }.prefix(12)

        var parts: [String] = ["Tag: \(node.label)\nRelated nodes:"]
        for rel in related {
            let content = fetchPageContent(rel, modelContext: modelContext)
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

            let context = buildChatContext(query: query, store: store, modelContext: modelContext)

            guard let triage = AppBootstrap.shared?.triageService else {
                appendToLastAssistant("AI service unavailable.")
                return
            }

            let systemPrompt: String
            if chatScope == .knowledgeBase {
                systemPrompt = """
                You are a knowledge base analyst for Epistemos with access to the user's full vault index. \
                Answer questions by synthesizing information across the selected node, its graph neighbors, and the broader vault. \
                Reference specific notes by title. Identify connections the user might not see. \
                If the vault doesn't cover something, say so and offer what you know from general knowledge.
                """
            } else {
                systemPrompt = """
                You are a note analyst for Epistemos. Answer the user's question about this specific node. \
                Be concise, analytical, and helpful. If the content doesn't address their question, say so.
                """
            }

            let stream = triage.streamGeneral(
                prompt: context,
                systemPrompt: systemPrompt,
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

    private func buildChatContext(query: String, store: GraphStore, modelContext: ModelContext) -> String {
        guard let node = selectedNode else { return query }

        let nodeContent = fetchContent(for: node, store: store, modelContext: modelContext)
        var context = "Selected node: \(node.label) (\(node.type.displayName))\n\n"
        context += "Content:\n\(String(nodeContent.prefix(3000)))\n\n"

        if chatScope == .knowledgeBase {
            let neighborIds = store.adjacency[node.id] ?? []
            let neighbors = neighborIds.compactMap { store.nodes[$0] }.prefix(5)
            if !neighbors.isEmpty {
                context += "Connected nodes:\n"
                for n in neighbors {
                    let content = fetchPageContent(n, modelContext: modelContext)
                    context += "- \(n.label): \(String(content.prefix(500)))\n"
                }
                context += "\n"
            }

            // Inject ambient vault manifest for full vault awareness
            if let manifest = AppBootstrap.shared?.ambientManifest {
                context += manifest.asManifestOnly() + "\n\n"
            }
        }

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
