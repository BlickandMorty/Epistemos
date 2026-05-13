import CryptoKit
import Foundation
import SwiftData

// MARK: - EntityExtractor
// AI-powered entity extraction that scans notes and chats to find
// cross-note semantic relationships and chat-derived ideas. Uses the
// user's configured LLM to extract entities and builds graph nodes +
// edges from the results.
//
// Active extractors today (RCA-P2-012 closure 2026-05-13):
//   - Notes batch → `crossNoteLinks` (supports / contradicts / expands
//     / questions edges between notes in the same batch).
//   - Chats with > 2 messages → `ExtractedIdea` (.idea graph nodes
//     anchored to the originating chat).
//
// Roadmap (NOT currently persisted — kept in the schema as optional
// back-compat fields):
//   - Source mentions (`ExtractionResult.sources` / `.sourcesShared`)
//   - Tag classification (`ExtractionResult.tags`)
// Promoting either back to a live graph projection is tracked under
// `RCA-P2-012` in the audit register; the prompt no longer requests
// them so the LLM doesn't burn tokens on unused output.
//
// Supports incremental scanning: skips notes whose content hash hasn't
// changed.

@MainActor
final class EntityExtractor {

    private let graphState: GraphState
    private let ontologyClassifier: (any OntologyClassifying)?
    private let sidecarGenerator: (any AFMSidecarGenerating)?

    /// Stores SHA-256 hash of note content at last successful extraction.
    /// Persisted to UserDefaults to survive app restarts.
    /// Key = page ID, Value = hex SHA-256 hash string.
    private static let hashCacheKey = "EntityExtractor.processedHashes"

    private var processedHashes: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Self.hashCacheKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.hashCacheKey) }
    }

    init(
        graphState: GraphState,
        ontologyClassifier: (any OntologyClassifying)? = OntologyClassifier.shared,
        sidecarGenerator: (any AFMSidecarGenerating)? = AFMSidecarGenerator.shared
    ) {
        self.graphState = graphState
        self.ontologyClassifier = ontologyClassifier
        self.sidecarGenerator = sidecarGenerator
    }

    /// Compute SHA-256 hex string of note content for change detection.
    private func contentHash(of text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func recordFetchFailure(_ action: String, error: Error) {
        Log.app.error("\(action, privacy: .public) — \(error.localizedDescription, privacy: .public)")
    }

    private func rollbackInsertedGraphArtifacts(
        nodes: [SDGraphNode] = [],
        edges: [SDGraphEdge] = [],
        context: ModelContext
    ) {
        for edge in edges {
            context.delete(edge)
        }
        for node in nodes {
            context.delete(node)
        }
    }

    private func sourceURL(from filePath: String?) -> URL? {
        guard let raw = filePath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: raw).standardizedFileURL
    }

    private func classifyOntologyIfAvailable(
        _ text: String,
        sourceURL: URL
    ) async {
        guard let ontologyClassifier else { return }
        guard EpistemosSidecarPolicy.isEligible(sourceURL) else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard ontologyClassifier.readiness() == .available else { return }

        do {
            _ = try await ontologyClassifier.classifyAndPersist(text, for: sourceURL)
        } catch {
            Log.app.warning(
                "EntityExtractor: ontology classification skipped for \(sourceURL.lastPathComponent, privacy: .public) — \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func generateAFMSidecarIfAvailable(
        _ text: String,
        sourceURL: URL,
        candidateLinks: [AFMSidecarCandidateLink]
    ) async {
        guard let sidecarGenerator else { return }
        guard EpistemosSidecarPolicy.isEligible(sourceURL) else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard sidecarGenerator.readiness() == .available else { return }

        do {
            _ = try await sidecarGenerator.generateAndPersist(
                text,
                for: sourceURL,
                candidateLinks: candidateLinks
            )
        } catch {
            Log.app.warning(
                "EntityExtractor: AFM sidecar generation skipped for \(sourceURL.lastPathComponent, privacy: .public) — \(error.localizedDescription, privacy: .public)"
            )
        }
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

        // 2. Fetch all active pages, filter to only changed notes, process in batches of 10
        let allPages: [SDPage]
        do {
            allPages = try context.fetch(SDPage.activePagesDescriptor)
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch active pages for scan", error: error)
            allPages = []
        }
        var currentHashes = processedHashes

        // Incremental change detection: skip notes whose content hash
        // matches last extraction.
        //
        // Phase R.3 async cascade: `loadBodyAsync` preserves the
        // managed sidecar before using the R.3 gateway fallback.
        // Can't use `filter` directly because the body read is async —
        // fall back to a sequential loop
        // over `allPages`. scanVault is already async and the
        // per-note LLM call in the next phase dominates runtime, so
        // losing a tiny bit of filter parallelism is irrelevant.
        var pages: [SDPage] = []
        pages.reserveCapacity(allPages.count)
        for page in allPages {
            // Staging primitives keeps the SwiftData @Model reference
            // off the async call's send-region.
            let pageId = page.id
            let filePath = page.filePath
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: pageId,
                filePath: filePath,
                mapped: true
            )
            let hash = contentHash(of: body)
            if currentHashes[pageId] != hash {
                pages.append(page)
            }
        }

        let skipped = allPages.count - pages.count
        if skipped > 0 {
            Log.app.info("EntityExtractor: skipping \(skipped) unchanged notes, processing \(pages.count) changed")
        }

        let totalWork = Double(pages.count + 1)  // +1 for chat phase
        var completed = 0.0

        graphState.scanStatus = "Extracting entities from \(pages.count) changed notes..."

        let batchSize = 10
        for batchStart in stride(from: 0, to: pages.count, by: batchSize) {
            guard !Task.isCancelled else {
                Log.app.info("EntityExtractor: scan cancelled during note extraction")
                break
            }
            let batchEnd = min(batchStart + batchSize, pages.count)
            let batch = Array(pages[batchStart..<batchEnd])
            let sidecarCandidates = batch.map {
                AFMSidecarCandidateLink(noteId: $0.id, title: $0.title)
            }

            // Concatenate batch: title + body with block IDs annotated.
            // Block IDs let the LLM attribute entities to specific blocks.
            // Pre-fetch all blocks for this batch to avoid N+1 queries.
            let batchPageIds = batch.map(\.id)
            let allBatchBlocks = prefetchBlocks(forPageIds: batchPageIds, context: context)

            var batchContent = ""
            for page in batch {
                // Phase R.3: managed-sidecar-first body read via the
                // Sendable-primitive strangler-fig helper. Parity
                // with legacy `loadBody` is byte-equal per
                // `PhaseR3BodyReadParityTests`.
                let pageId = page.id
                let filePath = page.filePath
                let body = await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: pageId,
                    filePath: filePath,
                    mapped: true
                )
                let blocks = allBatchBlocks[pageId] ?? []
                let annotated = annotateBodyWithBlocks(body: body, blocks: blocks)
                batchContent += "--- Note: \(page.title) ---\n\(annotated)\n\n"
                if let sourceURL = sourceURL(from: filePath) {
                    await classifyOntologyIfAvailable(annotated, sourceURL: sourceURL)
                    let candidateLinks = sidecarCandidates.filter { $0.noteId != page.id }
                    await generateAFMSidecarIfAvailable(
                        annotated,
                        sourceURL: sourceURL,
                        candidateLinks: candidateLinks
                    )
                }
            }

            // Build extraction prompt with semantic relationship classification.
            // RCA-P2-012 closure 2026-05-13: tags + sources were asked for
            // by older drops of this prompt but `processExtractionResult`
            // only ever persisted `crossNoteLinks`. To stop the LLM from
            // doing free work that lands in /dev/null we now ask only for
            // the field we actually use. `ExtractionResult.tags` and
            // `.sources` stay in the schema as optional fields for
            // forward-compat (so older serialized payloads still parse)
            // but they are no longer requested at extraction time.
            let prompt = """
                Extract semantic relationships between the following notes. Return ONLY valid JSON:
                {"crossNoteLinks": [{"from": "Note Title", "to": "Note Title", "relationship": "supports|contradicts|expands|questions", "reason": "brief explanation"}]}

                Rules:
                - crossNoteLinks: Semantic relationships BETWEEN notes in this batch.
                  Only include when one note clearly supports, contradicts, expands, or questions another.
                - Empty array [] if none found.

                Content:
                \(batchContent)
                """

            // Call LLM and parse response
            do {
                let response = try await llmService.generate(prompt: prompt, maxTokens: 2000)
                if let extraction = parseJSON(response, as: ExtractionResult.self) {
                    processExtractionResult(extraction, sourcePages: batch, context: context)

                    // Update hash cache for successfully processed notes.
                    // Phase R.3: same managed-sidecar-first read path as above.
                    for page in batch {
                        let pageId = page.id
                        let filePath = page.filePath
                        let body = await SDPage.loadBodyAsyncFromPrimitives(
                            pageId: pageId,
                            filePath: filePath,
                            mapped: true
                        )
                        currentHashes[pageId] = contentHash(of: body)
                    }
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
        let allChats: [SDChat]
        do {
            allChats = try context.fetch(FetchDescriptor<SDChat>())
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch chats for scan", error: error)
            allChats = []
        }
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
                {"ideas": [{"summary": "string", "evidenceGrade": "A/B/C/D/F or null", "relatedEntities": ["string"]}]}

                Rules:
                - Ideas: 2-4 most significant conclusions or insights. Not small talk.
                - Evidence grade: A = strong evidence, F = speculation.

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

        // 4. Persist updated hash cache
        processedHashes = currentHashes

        // 5. Reload graph with new entities
        graphState.scanStatus = "Reloading graph..."
        graphState.loadGraph(context: context)

        graphState.isScanning = false
        graphState.scanStatus = ""
        Log.app.info("EntityExtractor: scan complete — \(pages.count) notes processed, \(skipped) skipped (unchanged)")
    }

    // MARK: - Process Extraction Result (Notes)

    private func processExtractionResult(
        _ extraction: ExtractionResult,
        sourcePages: [SDPage],
        context: ModelContext
    ) {
        var insertedEdges: [SDGraphEdge] = []

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
                if let edge = createEdgeIfNeeded(source: fromNode.id, target: toNode.id, type: edgeType, context: context) {
                    insertedEdges.append(edge)
                }
            }
        }

        do {
            try context.save()
        } catch {
            rollbackInsertedGraphArtifacts(edges: insertedEdges, context: context)
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
        var insertedIdeaNodes: [SDGraphNode] = []
        var insertedEdges: [SDGraphEdge] = []

        // RCA-P1-008 dedup (2026-05-13): build an in-memory
        // `(chatId, label) -> SDGraphNode` lookup so a second scan
        // of an unchanged chat REUSES the existing idea-node instead
        // of inserting a fresh duplicate.
        //
        // We can't predicate-filter on `meta.originChatId` because the
        // metadata is stored as a `Data?` blob (JSON-encoded
        // `GraphNodeMetadata`). The cheaper-than-it-looks alternative
        // is to fetch all `.idea` nodes once per scan, decode their
        // metadata in-memory, and bucket by the chat that owns them.
        // For a vault with tens of thousands of ideas this is still a
        // single fetch; the per-idea filter is O(n) hash-set work.
        //
        // Edges remain dedup-safe because `createEdgeIfNeeded` already
        // checks (source, target, type) before inserting.
        let typeRawIdea = GraphNodeType.idea.rawValue
        let existingIdeaNodes: [SDGraphNode]
        do {
            existingIdeaNodes = try context.fetch(
                FetchDescriptor<SDGraphNode>(
                    predicate: #Predicate<SDGraphNode> { $0.type == typeRawIdea }
                )
            )
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch existing idea nodes for dedup", error: error)
            existingIdeaNodes = []
        }
        let chatId = sourceChat.id
        let chatIdeaLookup: [String: SDGraphNode] = Dictionary(
            existingIdeaNodes.compactMap { node -> (String, SDGraphNode)? in
                guard node.meta.originChatId == chatId else { return nil }
                return ("\(chatId)::\(node.label)", node)
            },
            uniquingKeysWith: { first, _ in first }
        )

        // Ideas (absorbs insights)
        for idea in ideaResult.ideas {
            let label = String(idea.summary.prefix(80))
            let dedupKey = "\(chatId)::\(label)"

            let ideaNode: SDGraphNode
            if let existing = chatIdeaLookup[dedupKey] {
                // Existing idea found — reuse the node so edges stay
                // attached to a stable id. Refresh evidence_grade if
                // the new extraction differs.
                ideaNode = existing
                if existing.meta.evidenceGrade != idea.evidenceGrade {
                    var meta = existing.meta
                    meta.evidenceGrade = idea.evidenceGrade
                    existing.meta = meta
                    existing.updatedAt = .now
                }
            } else {
                ideaNode = SDGraphNode(type: .idea, label: label)
                var meta = GraphNodeMetadata()
                meta.evidenceGrade = idea.evidenceGrade
                meta.originChatId = chatId
                ideaNode.meta = meta
                context.insert(ideaNode)
                insertedIdeaNodes.append(ideaNode)
            }

            // Link idea back to source chat. createEdgeIfNeeded dedupes
            // on (source, target, type) so a re-scan against the same
            // (idea, chat, reference) tuple inserts nothing.
            if let chatGraphNodeId = chatNodeId {
                if let edge = createEdgeIfNeeded(source: ideaNode.id, target: chatGraphNodeId, type: .reference, context: context) {
                    insertedEdges.append(edge)
                }
            }

            // Link to related entities mentioned in the idea
            if let related = idea.relatedEntities {
                for entityName in related {
                    if let existingNode = findExistingNodeByLabel(entityName, context: context) {
                        if let edge = createEdgeIfNeeded(
                            source: ideaNode.id,
                            target: existingNode.id,
                            type: .related,
                            context: context
                        ) {
                            insertedEdges.append(edge)
                        }
                    }
                }
            }
        }

        do {
            try context.save()
        } catch {
            rollbackInsertedGraphArtifacts(nodes: insertedIdeaNodes, edges: insertedEdges, context: context)
            Log.app.error("EntityExtractor: failed to save idea results — \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Block-Level Annotation

    /// Pre-fetch all SDBlocks for a set of page IDs.
    ///
    /// RCA-P1-011 (2026-05-13): the previous implementation fired one
    /// `FetchDescriptor` per page ID, which is the "N+1" pattern the
    /// audit register flagged — for a 200-page scan that meant 200
    /// round-trips to SwiftData on the MainActor. The new implementation
    /// uses a single batched fetch with `pageIdSet.contains($0.pageId)`,
    /// then groups the result in-memory. Same correctness, one round-
    /// trip instead of N.
    private func prefetchBlocks(forPageIds pageIds: [String], context: ModelContext) -> [String: [SDBlock]] {
        guard !pageIds.isEmpty else { return [:] }
        let pageIdSet = Set(pageIds)
        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { pageIdSet.contains($0.pageId) },
            sortBy: [SortDescriptor(\SDBlock.order)]
        )
        let blocks: [SDBlock]
        do {
            blocks = try context.fetch(descriptor)
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch page blocks for annotation", error: error)
            return [:]
        }
        // Group by pageId in-memory. For typical scans (10-200 pages,
        // ~5-50 blocks each) this is a few thousand assignments — far
        // cheaper than the previous N round-trips to SwiftData.
        return Dictionary(grouping: blocks, by: \.pageId)
    }

    /// Annotate body text with block IDs so the LLM can attribute entities to specific blocks.
    private func annotateBodyWithBlocks(body: String, blocks: [SDBlock]) -> String {
        guard !blocks.isEmpty else { return String(body.prefix(2000)) }

        // Build a content → blockId map for matching.
        var contentToBlockId: [String: String] = [:]
        for block in blocks where block.content.count > 15 {
            let key = String(block.content.prefix(50))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            contentToBlockId[key] = block.id
        }

        // Annotate lines with block IDs where they match.
        var annotated = ""
        annotated.reserveCapacity(min(body.count, 2200))
        var charCount = 0
        for line in body.components(separatedBy: "\n") {
            guard charCount < 2000 else { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let key = String(trimmed.prefix(50))
            if let blockId = contentToBlockId[key] {
                annotated += "[block:\(blockId)] \(line)\n"
            } else {
                annotated += "\(line)\n"
            }
            charCount += line.count + 1
        }
        return annotated
    }

    // MARK: - Find or Create Node

    private func findOrCreateNode(type: GraphNodeType, label: String, context: ModelContext) -> SDGraphNode {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeRaw = type.rawValue

        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.type == typeRaw && $0.label == normalizedLabel }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.weight += 1
                existing.updatedAt = .now
                return existing
            }
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch existing graph node", error: error)
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
        do {
            return try context.fetch(descriptor).first
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch graph node", error: error)
            return nil
        }
    }

    private func findExistingNodeByLabel(_ label: String, context: ModelContext) -> SDGraphNode? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.label == normalized }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch graph node by label", error: error)
            return nil
        }
    }

    // MARK: - Create Edge If Needed

    private func createEdgeIfNeeded(
        source: String,
        target: String,
        type: GraphEdgeType,
        context: ModelContext
    ) -> SDGraphEdge? {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate {
                $0.sourceNodeId == source && $0.targetNodeId == target && $0.type == typeRaw
            }
        )
        do {
            let existing = try context.fetch(descriptor)
            if !existing.isEmpty {
                return nil
            }
        } catch {
            recordFetchFailure("EntityExtractor: failed to fetch existing graph edge", error: error)
            return nil
        }

        let edge = SDGraphEdge(source: source, target: target, type: type)
        context.insert(edge)
        return edge
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
        var cleaned = text.strippingThinkingBlocks()
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
