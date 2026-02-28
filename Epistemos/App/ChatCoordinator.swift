import Foundation
import SwiftData
import os

// MARK: - Chat Coordinator
// Handles the full chat query lifecycle: user query → pipeline → streaming → persistence.
// Extracted from AppBootstrap+ChatOrchestration, +NotesContext, +Persistence.

@MainActor
final class ChatCoordinator {
    private unowned let bootstrap: AppBootstrap
    private let chatState: ChatState
    private let pipelineService: PipelineService
    private let inferenceState: InferenceState
    private let soarState: SOARState
    private let vaultSync: VaultSyncService
    private let modelContainer: ModelContainer
    private let eventBus: EventBus
    private let llmService: LLMService
    private let researchState: ResearchState
    private let notesUI: NotesUIState

    init(
        bootstrap: AppBootstrap,
        chatState: ChatState,
        pipelineService: PipelineService,
        inferenceState: InferenceState,
        soarState: SOARState,
        vaultSync: VaultSyncService,
        modelContainer: ModelContainer,
        eventBus: EventBus,
        llmService: LLMService,
        researchState: ResearchState,
        notesUI: NotesUIState
    ) {
        self.bootstrap = bootstrap
        self.chatState = chatState
        self.pipelineService = pipelineService
        self.inferenceState = inferenceState
        self.soarState = soarState
        self.vaultSync = vaultSync
        self.modelContainer = modelContainer
        self.eventBus = eventBus
        self.llmService = llmService
        self.researchState = researchState
        self.notesUI = notesUI
    }

    // MARK: - Query Lifecycle

    /// Process a user query through the 6-pass pipeline, streaming tokens back to ChatState.
    func handleQuery(_ query: String, pipeline: PipelineService, chatState: ChatState) {
        bootstrap.queryTask?.cancel()

        // Early guard: if the selected provider needs an API key and we have none,
        // AND Apple Intelligence isn't available as a fallback, show an error immediately.
        let aiFresh = AppleIntelligenceService.shared.checkAvailability()
        inferenceState.appleIntelligenceAvailable = aiFresh.available
        inferenceState.appleIntelligenceUnavailableReason = aiFresh.reason
        if inferenceState.needsApiKey && inferenceState.apiKey.isEmpty && !aiFresh.available {
            chatState.addErrorMessage("No API key configured for \(inferenceState.apiProvider.rawValue.capitalized). Add one in Settings, or use a Mac with Apple Intelligence.")
            return
        }

        let isVaultBriefing = query == "[VAULT_BRIEFING]"
        chatState.isCurrentVaultBriefing = isVaultBriefing
        chatState.startStreaming()

        if chatState.isResearchMode {
            chatState.researchStartTime = Date()
        }

        bootstrap.queryTask = Task {
            do {
                let mode = inferenceState.inferenceMode
                let isResearch = chatState.isResearchMode
                let hasVault = bootstrap.ambientManifest != nil
                Log.pipeline.warning("🔬 handleQuery — isResearch=\(isResearch) hasVault=\(hasVault) skipEnrichment=\(!isResearch)")

                let notesContext: String?
                let resolvedQuery: String
                if hasVault {
                    let (ctx, cleaned) = await self.buildNotesContext(query: query, chatState: chatState)
                    notesContext = ctx
                    resolvedQuery = cleaned
                } else {
                    notesContext = nil
                    resolvedQuery = query
                }

                // For vault briefing, override notesContext with full manifest (includes bodies)
                let effectiveNotesContext: String?
                let effectiveQuery: String
                if isVaultBriefing {
                    effectiveNotesContext = chatState.vaultBriefingManifest?.asContext() ?? notesContext
                    chatState.vaultBriefingManifest = nil  // Consumed — free memory
                    effectiveQuery = "Analyze my vault and provide a briefing: find cross-note connections, recurring themes, contradictions, topic gaps, stale notes worth revisiting, and notes that could be merged or split. Be specific — reference notes by title."
                } else {
                    effectiveNotesContext = notesContext
                    effectiveQuery = resolvedQuery
                }

                // Build conversation history for multi-turn context.
                let conversationHistory: String?
                let priorMessages = chatState.messages.dropLast()
                if !priorMessages.isEmpty && !isVaultBriefing {
                    let recent = priorMessages.suffix(10)
                    var lines: [String] = []
                    for msg in recent {
                        let role: String = msg.role == .user ? "User" : "Assistant"
                        let content: String = msg.content.count > 2000
                            ? String(msg.content.prefix(2000)) + "…"
                            : msg.content
                        lines.append(role + ": " + content)
                    }
                    conversationHistory = lines.joined(separator: "\n\n")
                } else {
                    conversationHistory = nil
                }

                let pendingAssistantId = UUID().uuidString
                let capturedChatId = chatState.activeChatId
                let capturedIsIncognito = chatState.isIncognito

                // Enrichment callback — survives queryTask cancellation.
                let onEnriched: @MainActor @Sendable (DualMessage, TruthAssessment) -> Void = { [weak self] dual, truth in
                    guard let self else { return }
                    Log.pipeline.info("[enriched] Callback — layman=\(dual.laymanSummary != nil) rawLen=\(dual.rawAnalysis.count) truth=\(Int(truth.overallTruthLikelihood * 100))% targetMsg=\(pendingAssistantId.prefix(8))")
                    chatState.enrichMessage(id: pendingAssistantId, dualMessage: dual, truthAssessment: truth)
                    if !capturedIsIncognito {
                        self.persistEnrichment(
                            chatId: capturedChatId,
                            messageId: pendingAssistantId,
                            dualMessage: dual,
                            truthAssessment: truth
                        )
                    }
                    if !dual.rawAnalysis.isEmpty {
                        self.extractAndSaveCitations(from: dual.rawAnalysis, source: "research",
                                                      originChatId: capturedChatId)
                    }
                }

                let stream = pipeline.run(
                    query: effectiveQuery,
                    mode: mode,
                    controls: .defaults,
                    soarConfig: self.soarState.soarConfig,
                    notesContext: effectiveNotesContext,
                    skipEnrichment: !isResearch,
                    conversationHistory: conversationHistory,
                    onEnriched: isResearch ? onEnriched : nil
                )

                for try await event in stream {
                    switch event {
                    case .textDelta(let token):
                        chatState.appendStreamingText(token)

                    case .reasoningDelta(let token):
                        chatState.startReasoning()
                        chatState.appendReasoningText(token)

                    case .enriched:
                        break

                    case .stageAdvanced, .signalUpdate, .soarEvent, .deliberationDelta:
                        break

                    case .completed(let dual, let truth):
                        let confidence = truth?.overallTruthLikelihood ?? 0.5
                        let grade = Self.gradeFromConfidence(confidence)
                        chatState.completeProcessing(
                            messageId: pendingAssistantId,
                            dualMessage: dual,
                            confidence: confidence,
                            grade: grade,
                            mode: mode,
                            truthAssessment: truth,
                            isResearchResult: isResearch
                        )

                        if let lastMsg = chatState.messages.last {
                            let processed = self.executeVaultActions(in: lastMsg.content)
                            if processed != lastMsg.content {
                                chatState.updateLastMessageContent(processed)
                            }
                        }

                        eventBus.emit(.pipelineComplete)

                        if let responseText = chatState.messages.last?.content {
                            self.extractAndSaveCitations(from: responseText, source: "chat",
                                                          originChatId: capturedChatId)
                        }

                        if !chatState.isIncognito {
                            self.persistChatCompletion(
                                chatId: capturedChatId,
                                query: query,
                                answer: chatState.messages.last?.content ?? "",
                                dual: dual,
                                truth: truth,
                                confidence: confidence,
                                grade: grade,
                                mode: mode,
                                isResearch: isResearch,
                                isNotes: hasVault
                            )
                        }

                        if chatState.chatTitle == nil {
                            self.generateChatTitle(query: query, chatId: capturedChatId, chatState: chatState)
                        }

                    case .error(let msg):
                        chatState.addErrorMessage(msg)
                    }
                }
            } catch is CancellationError {
                // User pressed stop — clean exit
            } catch {
                chatState.addErrorMessage("Analysis failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Chat Title Generation

    func generateChatTitle(query: String, chatId: String?, chatState: ChatState) {
        Task {
            let prompt = """
            Generate a very short title (2-6 words) for a chat conversation that starts with this query. \
            Return ONLY the title, no quotes, no punctuation at the end, no explanation. \
            Examples: "Quantum entanglement basics", "Fix SwiftUI layout bug", "Essay on stoicism", \
            "React vs Vue comparison", "Morning routine ideas"

            Query: \(query)
            """

            do {
                let title = try await llmService.generate(
                    prompt: prompt,
                    systemPrompt: "You generate concise chat titles. Return only the title text, nothing else.",
                    maxTokens: 30
                )
                let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
                guard !cleaned.isEmpty else { return }

                chatState.chatTitle = cleaned

                if let chatId {
                    let context = modelContainer.mainContext
                    let predicate = #Predicate<SDChat> { $0.id == chatId }
                    let descriptor = FetchDescriptor<SDChat>(predicate: predicate)
                    if let sdChat = try? context.fetch(descriptor).first {
                        sdChat.title = cleaned
                        do {
                            try context.save()
                        } catch {
                            Log.pipeline.error("Failed to save chat title: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            } catch {
                Log.pipeline.debug("Chat title generation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Auto-Citation Extraction

    func extractAndSaveCitations(from text: String, source: String,
                                  originChatId: String? = nil, originNoteTitle: String? = nil) {
        let papers = CitationExtractor.extract(from: text, source: source,
                                                originChatId: originChatId,
                                                originNoteTitle: originNoteTitle)
        guard !papers.isEmpty else { return }
        for paper in papers {
            researchState.addSavedPaper(paper)
        }
        if papers.count > 0 {
            eventBus.emitToast("Added \(papers.count) source\(papers.count == 1 ? "" : "s") to library", type: .info)
        }
    }

    // MARK: - Vault Context

    func buildNotesContext(query: String, chatState: ChatState) async -> (String?, String) {
        guard bootstrap.ambientManifest != nil else { return (nil, query) }

        var contextParts: [String] = []
        var cleanedQuery = query

        if let manifest = bootstrap.ambientManifest {
            contextParts.append(manifest.asManifestOnly())
        }

        let mentionPattern = #"@\[([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let nsQuery = query as NSString
            let matches = regex.matches(in: query, range: NSRange(location: 0, length: nsQuery.length))

            var titlesToResolve: [String] = []
            for match in matches.reversed() {
                guard let titleRange = Range(match.range(at: 1), in: query) else { continue }
                let title = String(query[titleRange])
                titlesToResolve.append(title)
                if let fullRange = Range(match.range, in: cleanedQuery) {
                    cleanedQuery.replaceSubrange(fullRange, with: title)
                }
            }

            if !titlesToResolve.isEmpty {
                for title in titlesToResolve {
                    let found = await vaultSync.findNotesByTitle(title)
                    let ids = found.map(\.pageId).filter { !chatState.loadedNoteIds.contains($0) }
                    if !ids.isEmpty {
                        let bodies = await vaultSync.fetchNoteBodies(ids: ids)
                        for body in bodies {
                            contextParts.append("### Referenced Note: \(body.title)\n\(body.body)")
                            chatState.loadedNoteIds.insert(body.pageId)
                            chatState.loadedNoteTitles.append(body.title)
                        }
                    }
                }
            }
        }

        if !chatState.loadedNoteIds.isEmpty {
            let alreadyLoaded = await vaultSync.fetchNoteBodies(ids: Array(chatState.loadedNoteIds))
            for body in alreadyLoaded {
                if !contextParts.contains(where: { $0.contains("### Referenced Note: \(body.title)") }) {
                    contextParts.append("### Previously Referenced: \(body.title)\n\(body.body)")
                }
            }
        }

        let context = contextParts.isEmpty ? nil : contextParts.joined(separator: "\n\n")
        return (context, cleanedQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Vault Action Execution

    func executeVaultActions(in response: String) -> String {
        var cleaned = response
        var executed: [String] = []
        let context = modelContainer.mainContext

        // TAG action
        if let range = response.range(of: #"\[ACTION:TAG\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let raw = marker
                .replacingOccurrences(of: "[ACTION:TAG ", with: "")
                .replacingOccurrences(of: "]", with: "")
            let tags = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count < 30 }

            if !tags.isEmpty {
                let targetId = notesUI.activePageId
                let page: SDPage?
                if let targetId {
                    let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == targetId })
                    page = try? context.fetch(desc).first
                } else {
                    var desc = FetchDescriptor<SDPage>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
                    desc.fetchLimit = 1
                    page = try? context.fetch(desc).first
                }
                if let page {
                    let newTags = tags.filter { !page.tags.contains($0) }
                    if !newTags.isEmpty {
                        page.tags.append(contentsOf: newTags)
                        page.updatedAt = .now
                        executed.append("✅ Added tags [\(newTags.joined(separator: ", "))] to \(page.title)")
                    }
                }
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // MOVE action
        if let range = response.range(of: #"\[ACTION:MOVE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let folderName = marker
                .replacingOccurrences(of: "[ACTION:MOVE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            let folderDesc = FetchDescriptor<SDFolder>()
            if let folders = try? context.fetch(folderDesc),
               let folder = folders.first(where: { $0.name.lowercased() == folderName.lowercased() }) {
                var pageDesc = FetchDescriptor<SDPage>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
                pageDesc.fetchLimit = 1
                if let page = try? context.fetch(pageDesc).first {
                    page.folder = folder
                    page.updatedAt = .now
                    executed.append("✅ Moved \(page.title) to \(folder.name)")
                }
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // CREATE action
        if let range = response.range(of: #"\[ACTION:CREATE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let title = marker
                .replacingOccurrences(of: "[ACTION:CREATE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                Task {
                    if await vaultSync.createPage(title: title) != nil {
                        // Note created — user can navigate to it from sidebar
                    }
                }
                executed.append("✅ Created note: \(title)")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        if !executed.isEmpty {
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned += "\n\n---\n" + executed.joined(separator: "\n")
        }

        return cleaned
    }

    // MARK: - Chat Persistence

    func persistChatCompletion(
        chatId: String?,
        query: String,
        answer: String,
        dual: DualMessage?,
        truth: TruthAssessment?,
        confidence: Double,
        grade: EvidenceGrade,
        mode: InferenceMode,
        isResearch: Bool = false,
        isNotes: Bool = false
    ) {
        guard let chatId else { return }
        let context = modelContainer.mainContext

        let chat: SDChat
        let predicate = #Predicate<SDChat> { $0.id == chatId }
        let descriptor = FetchDescriptor<SDChat>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            chat = existing
            chat.updatedAt = .now
        } else {
            let firstWords = String(query.prefix(50))
            chat = SDChat(title: firstWords, chatType: "chat")
            chat.id = chatId
            context.insert(chat)
        }
        if isResearch { chat.hasDeepResearch = true }
        if isNotes { chat.chatType = "notes" }

        let userMsg = SDMessage(role: "user", content: query)
        userMsg.chat = chat
        context.insert(userMsg)

        let assistantMsg = SDMessage(role: "assistant", content: answer)
        assistantMsg.confidenceScore = confidence
        assistantMsg.evidenceGrade = grade.rawValue
        assistantMsg.inferenceMode = mode.rawValue
        do { assistantMsg.dualMessageData = try JSONEncoder().encode(dual) }
        catch { Log.db.error("Failed to encode DualMessage: \(error.localizedDescription)") }
        do { assistantMsg.truthAssessmentData = try JSONEncoder().encode(truth) }
        catch { Log.db.error("Failed to encode TruthAssessment: \(error.localizedDescription)") }
        assistantMsg.chat = chat
        context.insert(assistantMsg)

        do {
            try context.save()
            Log.db.info("Persisted chat \(chatId, privacy: .public): user + assistant messages")
        } catch {
            Log.db.error("Failed to persist chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    func persistEnrichment(
        chatId: String?,
        messageId: String,
        dualMessage: DualMessage,
        truthAssessment: TruthAssessment
    ) {
        guard let chatId else { return }
        let context = modelContainer.mainContext

        // Look up the specific message by ID, not the "latest assistant message",
        // to avoid enrichment being saved to the wrong message during rapid queries.
        let msgPredicate = #Predicate<SDMessage> { $0.id == messageId }
        let msgDescriptor = FetchDescriptor<SDMessage>(predicate: msgPredicate)
        guard let lastAssistant = try? context.fetch(msgDescriptor).first else {
            Log.db.warning("persistEnrichment: no message found with id \(messageId.prefix(8), privacy: .public) for chat \(chatId, privacy: .public)")
            return
        }

        do { lastAssistant.dualMessageData = try JSONEncoder().encode(dualMessage) }
        catch { Log.db.error("Failed to encode DualMessage for enrichment: \(error.localizedDescription)") }
        do { lastAssistant.truthAssessmentData = try JSONEncoder().encode(truthAssessment) }
        catch { Log.db.error("Failed to encode TruthAssessment for enrichment: \(error.localizedDescription)") }
        lastAssistant.confidenceScore = truthAssessment.overallTruthLikelihood
        let grade = Self.gradeFromConfidence(truthAssessment.overallTruthLikelihood)
        lastAssistant.evidenceGrade = grade.rawValue

        do {
            try context.save()
            Log.db.info("Persisted enrichment for chat \(chatId, privacy: .public)")
        } catch {
            Log.db.error("Failed to persist enrichment: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade {
        switch confidence {
        case 0.85...: .a
        case 0.70..<0.85: .b
        case 0.50..<0.70: .c
        case 0.30..<0.50: .d
        default: .f
        }
    }
}
