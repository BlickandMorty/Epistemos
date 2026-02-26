import Foundation
import SwiftData

// MARK: - EntityExtractor
// AI-powered entity extraction that scans notes and chats to find thinkers,
// concepts, quotes, sources, and insights. Uses the user's configured LLM
// to extract entities and builds graph nodes + edges from the results.

@MainActor
final class EntityExtractor {

    private let graphState: GraphState

    init(graphState: GraphState) {
        self.graphState = graphState
    }

    // MARK: - Scan Vault

    func scanVault(context: ModelContext, llmService: LLMService) async {
        graphState.isScanning = true
        graphState.scanProgress = 0
        graphState.scanStatus = "Rebuilding structural graph..."

        // 1. Run StructuralGraphBuilder first (build + persist + reload)
        let builder = StructuralGraphBuilder()
        let result = builder.build(context: context)
        builder.persist(nodes: result.nodes, edges: result.edges, context: context)
        graphState.loadGraph(context: context)

        // 2. Fetch all active pages and process in batches of 5
        let pages = (try? context.fetch(SDPage.activePagesDescriptor)) ?? []
        let totalWork = Double(pages.count + 1)  // +1 for chat phase
        var completed = 0.0

        graphState.scanStatus = "Extracting entities from notes..."

        let batchSize = 5
        for batchStart in stride(from: 0, to: pages.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, pages.count)
            let batch = Array(pages[batchStart..<batchEnd])

            // Concatenate batch: title + first 2000 chars of body
            var batchContent = ""
            for page in batch {
                let bodySnippet = String(page.body.prefix(2000))
                batchContent += "--- Note: \(page.title) ---\n\(bodySnippet)\n\n"
            }

            // Build extraction prompt
            let prompt = """
                Extract entities from the following notes. Return ONLY valid JSON matching this exact schema:
                {"thinkers": [{"name": "string", "role": "string or null", "confidence": 0.0-1.0}],
                 "concepts": [{"name": "string", "description": "string or null"}],
                 "quotes": [{"text": "string", "attribution": "string or null", "context": "string or null"}],
                 "sources": [{"url": "string or null", "title": "string or null", "type": "string or null"}]}

                Rules:
                - Thinkers: Named real people (philosophers, scientists, authors). NOT the note author.
                - Concepts: Abstract themes that appear substantively.
                - Quotes: Direct quotations with clear attribution.
                - Sources: URLs, paper titles, or book titles.
                - Empty array [] if none found.
                - Deduplicate within batch.

                Content:
                \(batchContent)
                """

            // Call LLM and parse response
            do {
                let response = try await llmService.generate(prompt: prompt, maxTokens: 2000)
                if let extraction = parseJSON(response, as: ExtractionResult.self) {
                    processExtractionResult(extraction, sourcePages: batch, context: context)
                } else {
                    Log.app.info("EntityExtractor: failed to parse JSON for note batch \(batchStart/batchSize + 1)")
                }
            } catch {
                Log.app.error("EntityExtractor: LLM error for note batch — \(error.localizedDescription, privacy: .public)")
            }

            completed += Double(batch.count)
            graphState.scanProgress = completed / totalWork
        }

        // 3. Fetch all SDChat with >2 messages for insight extraction
        graphState.scanStatus = "Extracting insights from chats..."
        let allChats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []
        let substantiveChats = allChats.filter { ($0.messages ?? []).count > 2 }

        for chat in substantiveChats {
            let sorted = chat.sortedMessages
            var messagesText = ""
            for msg in sorted {
                let roleLabel = msg.role == "user" ? "User" : "Assistant"
                messagesText += "\(roleLabel): \(String(msg.content.prefix(1000)))\n\n"
            }

            let prompt = """
                Extract key insights from this conversation titled "\(chat.title)". Return ONLY valid JSON:
                {"insights": [{"summary": "string", "evidenceGrade": "A/B/C/D/F or null", "relatedEntities": ["string"]}],
                 "sourcesShared": [{"url": "string or null", "title": "string or null"}],
                 "thinkersDiscussed": [{"name": "string", "context": "string or null"}]}

                Rules:
                - Insights: 2-4 most significant conclusions. Not small talk.
                - Evidence grade: A = strong evidence, F = speculation.

                Conversation:
                \(messagesText)
                """

            do {
                let response = try await llmService.generate(prompt: prompt, maxTokens: 2000)
                if let insightResult = parseJSON(response, as: InsightExtractionResult.self) {
                    processInsightResult(insightResult, sourceChat: chat, context: context)
                } else {
                    Log.app.info("EntityExtractor: failed to parse JSON for chat '\(chat.title, privacy: .public)'")
                }
            } catch {
                Log.app.error("EntityExtractor: LLM error for chat — \(error.localizedDescription, privacy: .public)")
            }
        }

        completed += 1
        graphState.scanProgress = 1.0

        // 4. Reload graph with new entities
        graphState.scanStatus = "Reloading graph..."
        graphState.loadGraph(context: context)

        graphState.isScanning = false
        graphState.scanStatus = ""
        Log.app.info("EntityExtractor: scan complete")
    }

    // MARK: - Process Extraction Result (Notes)

    private func processExtractionResult(
        _ extraction: ExtractionResult,
        sourcePages: [SDPage],
        context: ModelContext
    ) {
        // For each source page, find or create a reference node
        let sourceNodeIds: [String] = sourcePages.compactMap { page in
            findSDGraphNode(type: .note, sourceId: page.id, context: context)?.id
        }

        // Thinkers
        for thinker in extraction.thinkers {
            let node = findOrCreateNode(type: .thinker, label: thinker.name, context: context)
            if let role = thinker.role {
                var meta = node.meta
                meta.clusterTheme = role
                node.meta = meta
            }
            for sourceId in sourceNodeIds {
                createEdgeIfNeeded(source: node.id, target: sourceId, type: .mentionedIn, context: context)
            }
        }

        // Concepts
        for concept in extraction.concepts {
            let node = findOrCreateNode(type: .concept, label: concept.name, context: context)
            if let desc = concept.description {
                var meta = node.meta
                meta.abstract = desc
                node.meta = meta
            }
            for sourceId in sourceNodeIds {
                createEdgeIfNeeded(source: node.id, target: sourceId, type: .appearsIn, context: context)
            }
        }

        // Quotes — always create new node
        for quote in extraction.quotes {
            let quoteNode = SDGraphNode(type: .quote, label: String(quote.text.prefix(80)))
            var meta = GraphNodeMetadata()
            meta.quoteText = quote.text
            quoteNode.meta = meta
            context.insert(quoteNode)

            // Link to source notes
            for sourceId in sourceNodeIds {
                createEdgeIfNeeded(source: quoteNode.id, target: sourceId, type: .extractedFrom, context: context)
            }

            // Link to attribution thinker if present
            if let attribution = quote.attribution, !attribution.isEmpty {
                let thinkerNode = findOrCreateNode(type: .thinker, label: attribution, context: context)
                createEdgeIfNeeded(source: quoteNode.id, target: thinkerNode.id, type: .attributedTo, context: context)
            }
        }

        // Sources
        for source in extraction.sources {
            let node = findOrCreateSourceNode(url: source.url, title: source.title, context: context)
            if let sourceType = source.type {
                var meta = node.meta
                meta.clusterTheme = sourceType
                node.meta = meta
            }
            for sourceId in sourceNodeIds {
                createEdgeIfNeeded(source: node.id, target: sourceId, type: .citedIn, context: context)
            }
        }

        do {
            try context.save()
        } catch {
            Log.app.error("EntityExtractor: failed to save extraction results — \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Process Insight Result (Chats)

    private func processInsightResult(
        _ insightResult: InsightExtractionResult,
        sourceChat: SDChat,
        context: ModelContext
    ) {
        // Find or locate the chat node in the graph
        let chatNode = findSDGraphNode(type: .chat, sourceId: sourceChat.id, context: context)
        let chatNodeId = chatNode?.id

        // Insights — always create new node
        for insight in insightResult.insights {
            let insightNode = SDGraphNode(type: .insight, label: String(insight.summary.prefix(80)))
            var meta = GraphNodeMetadata()
            meta.evidenceGrade = insight.evidenceGrade
            meta.originChatId = sourceChat.id
            insightNode.meta = meta
            context.insert(insightNode)

            // Link insight back to source chat
            if let chatId = chatNodeId {
                createEdgeIfNeeded(source: insightNode.id, target: chatId, type: .extractedFrom, context: context)
            }

            // Link to related entities mentioned in the insight
            if let related = insight.relatedEntities {
                for entityName in related {
                    // Try to find an existing concept or thinker node
                    if let existingNode = findExistingNodeByLabel(entityName, context: context) {
                        createEdgeIfNeeded(source: insightNode.id, target: existingNode.id, type: .relatesTo, context: context)
                    }
                }
            }
        }

        // Sources shared in chat
        for source in insightResult.sourcesShared {
            let node = findOrCreateSourceNode(url: source.url, title: source.title, context: context)
            if let chatId = chatNodeId {
                createEdgeIfNeeded(source: node.id, target: chatId, type: .sharedIn, context: context)
            }
        }

        // Thinkers discussed
        for thinker in insightResult.thinkersDiscussed {
            let node = findOrCreateNode(type: .thinker, label: thinker.name, context: context)
            if let ctx = thinker.context {
                var meta = node.meta
                meta.clusterTheme = ctx
                node.meta = meta
            }
            if let chatId = chatNodeId {
                createEdgeIfNeeded(source: node.id, target: chatId, type: .discussedIn, context: context)
            }
        }

        do {
            try context.save()
        } catch {
            Log.app.error("EntityExtractor: failed to save insight results — \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Find or Create Node

    /// Find an existing node by type + label (case-insensitive), incrementing weight if found.
    /// Creates a new node if none exists.
    private func findOrCreateNode(type: GraphNodeType, label: String, context: ModelContext) -> SDGraphNode {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeRaw = type.rawValue

        // Query for existing node with matching type and label
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.type == typeRaw && $0.label == normalizedLabel }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.weight += 1
            existing.updatedAt = .now
            return existing
        }

        // Create new node
        let node = SDGraphNode(type: type, label: normalizedLabel)
        context.insert(node)
        return node
    }

    /// Find an existing SDGraphNode by type and sourceId.
    private func findSDGraphNode(type: GraphNodeType, sourceId: String, context: ModelContext) -> SDGraphNode? {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.type == typeRaw && $0.sourceId == sourceId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// Find any existing node by label (case-insensitive search across types).
    private func findExistingNodeByLabel(_ label: String, context: ModelContext) -> SDGraphNode? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.label == normalized }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// Find or create a source node by URL or title.
    private func findOrCreateSourceNode(url: String?, title: String?, context: ModelContext) -> SDGraphNode {
        let typeRaw = GraphNodeType.source.rawValue

        // Try to find by URL first
        if let url, !url.isEmpty {
            let descriptor = FetchDescriptor<SDGraphNode>(
                predicate: #Predicate { $0.type == typeRaw && $0.sourceId == url }
            )
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.weight += 1
                existing.updatedAt = .now
                return existing
            }
        }

        // Try to find by title
        if let title, !title.isEmpty {
            let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptor = FetchDescriptor<SDGraphNode>(
                predicate: #Predicate { $0.type == typeRaw && $0.label == normalizedTitle }
            )
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.weight += 1
                existing.updatedAt = .now
                return existing
            }
        }

        // Create new source node
        let label = title ?? url ?? "Unknown Source"
        let node = SDGraphNode(type: .source, label: label.trimmingCharacters(in: .whitespacesAndNewlines), sourceId: url)
        if let url {
            var meta = GraphNodeMetadata()
            meta.url = url
            node.meta = meta
        }
        context.insert(node)
        return node
    }

    // MARK: - Create Edge If Needed

    /// Create an edge between two nodes if one does not already exist.
    private func createEdgeIfNeeded(source: String, target: String, type: GraphEdgeType, context: ModelContext) {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate {
                $0.sourceNodeId == source && $0.targetNodeId == target && $0.type == typeRaw
            }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return  // Edge already exists
        }

        let edge = SDGraphEdge(source: source, target: target, type: type)
        context.insert(edge)
    }

    // MARK: - JSON Parsing

    /// Parse JSON from LLM response, handling markdown code fences and whitespace.
    private func parseJSON<T: Decodable>(_ text: String, as type: T.Type) -> T? {
        // Strip <thinking> blocks (extended thinking models)
        var cleaned = text.replacingOccurrences(
            of: "<thinking>[\\s\\S]*?</thinking>",
            with: "",
            options: .regularExpression
        )
        // Strip markdown code fences
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the outermost { ... }
        guard let firstBrace = cleaned.firstIndex(of: "{"),
              let lastBrace = cleaned.lastIndex(of: "}") else {
            return nil
        }
        var jsonStr = String(cleaned[firstBrace...lastBrace])

        // Strip trailing commas before } or ] — common with GPT/Gemini/Kimi
        jsonStr = jsonStr.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )

        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
