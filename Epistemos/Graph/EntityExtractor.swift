import Foundation
import SwiftData

// MARK: - EntityExtractor
// AI-powered entity extraction that scans notes and chats to find sources,
// quotes, tags, and ideas. Uses the user's configured LLM to extract entities
// and builds graph nodes + edges from the results.
//
// Updated for 7-type model: sources (absorbs thinkers/papers/books),
// tags (absorbs concepts), ideas (absorbs insights/brainDumps).

@MainActor
final class EntityExtractor {

    private let graphState: GraphState

    init(graphState: GraphState) {
        self.graphState = graphState
    }

    // MARK: - Scan Vault

    func scanVault(context: ModelContext, llmService: any LLMClientProtocol) async {
        graphState.isScanning = true
        graphState.scanProgress = 0
        graphState.scanStatus = "Rebuilding structural graph..."

        // 1. Run GraphBuilder first (build + persist + reload)
        let builder = GraphBuilder()
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
            guard !Task.isCancelled else {
                Log.app.info("EntityExtractor: scan cancelled during note extraction")
                break
            }
            let batchEnd = min(batchStart + batchSize, pages.count)
            let batch = Array(pages[batchStart..<batchEnd])

            // Concatenate batch: title + first 2000 chars of body
            var batchContent = ""
            for page in batch {
                let bodySnippet = String(page.loadBody(mapped: true).prefix(2000))
                batchContent += "--- Note: \(page.title) ---\n\(bodySnippet)\n\n"
            }

            // Build extraction prompt with semantic relationship classification
            let prompt = """
                Extract entities and relationships from the following notes. Return ONLY valid JSON:
                {"sources": [{"name": "string", "url": "string or null", "title": "string or null", "type": "string or null", "relationship": "cites|supports|contradicts|expands|questions"}],
                 "quotes": [{"text": "string", "attribution": "string or null", "context": "string or null"}],
                 "tags": [{"name": "string", "description": "string or null"}],
                 "crossNoteLinks": [{"from": "Note Title", "to": "Note Title", "relationship": "supports|contradicts|expands|questions", "reason": "brief explanation"}]}

                Rules:
                - Sources: Named people, URLs, papers, books. Classify the relationship:
                  - cites: neutral reference
                  - supports: note agrees with or provides evidence for the source
                  - contradicts: note disagrees with or challenges the source
                  - expands: note builds on ideas from the source
                  - questions: note raises doubts about the source
                - Quotes: Direct quotations with clear attribution.
                - Tags: Abstract themes or concepts that appear substantively.
                - crossNoteLinks: Semantic relationships BETWEEN notes in this batch.
                  Only include when one note clearly supports, contradicts, expands, or questions another.
                - Default relationship to "cites" if unclear. Empty array [] if none found.

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

        // 3. Fetch all SDChat with >2 messages for idea extraction
        graphState.scanStatus = "Extracting ideas from chats..."
        let allChats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []
        let substantiveChats = allChats.filter { ($0.messages ?? []).count > 2 }

        for chat in substantiveChats {
            guard !Task.isCancelled else {
                Log.app.info("EntityExtractor: scan cancelled during chat extraction")
                break
            }
            let sorted = chat.sortedMessages
            var messagesText = ""
            for msg in sorted {
                let roleLabel = msg.role == "user" ? "User" : "Assistant"
                messagesText += "\(roleLabel): \(String(msg.content.prefix(1000)))\n\n"
            }

            let prompt = """
                Extract key ideas from this conversation titled "\(chat.title)". Return ONLY valid JSON:
                {"ideas": [{"summary": "string", "evidenceGrade": "A/B/C/D/F or null", "relatedEntities": ["string"]}],
                 "sourcesShared": [{"url": "string or null", "title": "string or null"}]}

                Rules:
                - Ideas: 2-4 most significant conclusions or insights. Not small talk.
                - Evidence grade: A = strong evidence, F = speculation.
                - Sources: Any URLs or references shared during the conversation.

                Conversation:
                \(messagesText)
                """

            do {
                let response = try await llmService.generate(prompt: prompt, maxTokens: 2000)
                if let ideaResult = parseJSON(response, as: InsightExtractionResult.self) {
                    processIdeaResult(ideaResult, sourceChat: chat, context: context)
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
        let sourceNodeIds: [String] = sourcePages.compactMap { page in
            findSDGraphNode(type: .note, sourceId: page.id, context: context)?.id
        }

        // Sources — with semantic relationship classification
        for source in extraction.sources {
            let node = findOrCreateSourceNode(
                url: source.url,
                title: source.title ?? source.name,
                context: context
            )
            if let sourceType = source.type {
                var meta = node.meta
                meta.clusterTheme = sourceType
                node.meta = meta
            }
            let edgeType = Self.edgeType(from: source.relationship, default: .cites)
            for sourceId in sourceNodeIds {
                createEdgeIfNeeded(source: node.id, target: sourceId, type: edgeType, context: context)
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
                createEdgeIfNeeded(source: quoteNode.id, target: sourceId, type: .reference, context: context)
            }

            // Link to attribution source if present
            if let attribution = quote.attribution, !attribution.isEmpty {
                let sourceNode = findOrCreateNode(type: .source, label: attribution, context: context)
                createEdgeIfNeeded(source: quoteNode.id, target: sourceNode.id, type: .quotes, context: context)
            }
        }

        // Tags (absorbs concepts)
        for tag in extraction.tags {
            let node = findOrCreateNode(type: .tag, label: tag.name, context: context)
            if let desc = tag.description {
                var meta = node.meta
                meta.abstract = desc
                node.meta = meta
            }
            for sourceId in sourceNodeIds {
                createEdgeIfNeeded(source: sourceId, target: node.id, type: .tagged, context: context)
            }
        }

        // Cross-note semantic links — connect notes within the batch that
        // support, contradict, expand, or question each other.
        if let links = extraction.crossNoteLinks {
            let pageTitles = Dictionary(sourcePages.map { ($0.title, $0.id) }, uniquingKeysWith: { first, _ in first })
            for link in links {
                guard let fromPageId = pageTitles[link.from],
                      let toPageId = pageTitles[link.to],
                      let fromNode = findSDGraphNode(type: .note, sourceId: fromPageId, context: context),
                      let toNode = findSDGraphNode(type: .note, sourceId: toPageId, context: context) else { continue }
                let edgeType = Self.edgeType(from: link.relationship, default: .related)
                createEdgeIfNeeded(source: fromNode.id, target: toNode.id, type: edgeType, context: context)
            }
        }

        do {
            try context.save()
        } catch {
            Log.app.error("EntityExtractor: failed to save extraction results — \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Process Idea Result (Chats)

    private func processIdeaResult(
        _ ideaResult: InsightExtractionResult,
        sourceChat: SDChat,
        context: ModelContext
    ) {
        let chatNode = findSDGraphNode(type: .chat, sourceId: sourceChat.id, context: context)
        let chatNodeId = chatNode?.id

        // Ideas (absorbs insights)
        for idea in ideaResult.ideas {
            let ideaNode = SDGraphNode(type: .idea, label: String(idea.summary.prefix(80)))
            var meta = GraphNodeMetadata()
            meta.evidenceGrade = idea.evidenceGrade
            meta.originChatId = sourceChat.id
            ideaNode.meta = meta
            context.insert(ideaNode)

            // Link idea back to source chat
            if let chatId = chatNodeId {
                createEdgeIfNeeded(source: ideaNode.id, target: chatId, type: .reference, context: context)
            }

            // Link to related entities mentioned in the idea
            if let related = idea.relatedEntities {
                for entityName in related {
                    if let existingNode = findExistingNodeByLabel(entityName, context: context) {
                        createEdgeIfNeeded(source: ideaNode.id, target: existingNode.id, type: .related, context: context)
                    }
                }
            }
        }

        // Sources shared in chat
        for source in ideaResult.sourcesShared {
            let node = findOrCreateSourceNode(url: source.url, title: source.title, context: context)
            if let chatId = chatNodeId {
                createEdgeIfNeeded(source: node.id, target: chatId, type: .reference, context: context)
            }
        }

        do {
            try context.save()
        } catch {
            Log.app.error("EntityExtractor: failed to save idea results — \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Find or Create Node

    private func findOrCreateNode(type: GraphNodeType, label: String, context: ModelContext) -> SDGraphNode {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeRaw = type.rawValue

        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.type == typeRaw && $0.label == normalizedLabel }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.weight += 1
            existing.updatedAt = .now
            return existing
        }

        let node = SDGraphNode(type: type, label: normalizedLabel)
        context.insert(node)
        return node
    }

    private func findSDGraphNode(type: GraphNodeType, sourceId: String, context: ModelContext) -> SDGraphNode? {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.type == typeRaw && $0.sourceId == sourceId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func findExistingNodeByLabel(_ label: String, context: ModelContext) -> SDGraphNode? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.label == normalized }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func findOrCreateSourceNode(url: String?, title: String?, context: ModelContext) -> SDGraphNode {
        let typeRaw = GraphNodeType.source.rawValue

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

    private func createEdgeIfNeeded(source: String, target: String, type: GraphEdgeType, context: ModelContext) {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate {
                $0.sourceNodeId == source && $0.targetNodeId == target && $0.type == typeRaw
            }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let edge = SDGraphEdge(source: source, target: target, type: type)
        context.insert(edge)
    }

    // MARK: - Relationship Mapping

    private static func edgeType(from relationship: String?, default fallback: GraphEdgeType) -> GraphEdgeType {
        guard let rel = relationship?.lowercased() else { return fallback }
        switch rel {
        case "supports": return .supports
        case "contradicts": return .contradicts
        case "expands": return .expands
        case "questions": return .questions
        case "cites": return .cites
        case "related": return .related
        default: return fallback
        }
    }

    // MARK: - JSON Parsing

    private func parseJSON<T: Decodable>(_ text: String, as type: T.Type) -> T? {
        var cleaned = text.replacingOccurrences(
            of: "<thinking>[\\s\\S]*?</thinking>",
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstBrace = cleaned.firstIndex(of: "{"),
              let lastBrace = cleaned.lastIndex(of: "}") else {
            return nil
        }
        var jsonStr = String(cleaned[firstBrace...lastBrace])

        jsonStr = jsonStr.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )

        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
