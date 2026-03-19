import Foundation
import SwiftData
import os

// MARK: - Chat Coordinator
// Handles the full chat query lifecycle: user query → pipeline → streaming → persistence.
// Extracted from AppBootstrap+ChatOrchestration, +NotesContext, +Persistence.

@MainActor
final class ChatCoordinator {
    struct ChatReferenceResult: Identifiable, Sendable, Hashable {
        let attachment: ContextAttachment
        let preview: String?

        var id: String { attachment.id }
    }

    struct ReferenceSearchResults: Sendable {
        let notes: [NoteMentionChoice]
        let chats: [ChatReferenceResult]
    }

    struct NotesContextResolution: Sendable {
        let context: String?
        let cleanedQuery: String
        let loadedNoteIds: Set<String>
        let loadedNoteTitles: [String]
    }

    struct AttachedContextResolution: Sendable {
        let context: String?
        let cleanedQuery: String
        let loadedNoteIds: Set<String>
        let loadedNoteTitles: [String]
    }

    static let allNotesMentionToken = "All Notes"

    private unowned let bootstrap: AppBootstrap
    private let chatState: ChatState
    private let pipelineService: PipelineService
    private let inferenceState: InferenceState
    private let vaultSync: VaultSyncService
    private let modelContainer: ModelContainer
    private let eventBus: EventBus
    private let llmService: LLMService
    private let notesUI: NotesUIState

    init(
        bootstrap: AppBootstrap,
        chatState: ChatState,
        pipelineService: PipelineService,
        inferenceState: InferenceState,
        vaultSync: VaultSyncService,
        modelContainer: ModelContainer,
        eventBus: EventBus,
        llmService: LLMService,
        notesUI: NotesUIState
    ) {
        self.bootstrap = bootstrap
        self.chatState = chatState
        self.pipelineService = pipelineService
        self.inferenceState = inferenceState
        self.vaultSync = vaultSync
        self.modelContainer = modelContainer
        self.eventBus = eventBus
        self.llmService = llmService
        self.notesUI = notesUI
    }

    // MARK: - Query Lifecycle

    /// Process a user query through the 6-pass pipeline, streaming tokens back to ChatState.
    func handleQuery(_ query: String, pipeline: PipelineService, chatState: ChatState) {
        bootstrap.queryTask?.cancel()

        let aiFresh = AppleIntelligenceService.shared.checkAvailability()
        inferenceState.appleIntelligenceAvailable = aiFresh.available
        inferenceState.appleIntelligenceUnavailableReason = aiFresh.reason

        let isVaultBriefing = query == "[VAULT_BRIEFING]"
        chatState.isCurrentVaultBriefing = isVaultBriefing
        chatState.startStreaming()

        bootstrap.queryTask = Task {
            do {
                let mode = inferenceState.inferenceMode
                let hasVault = bootstrap.ambientManifest != nil
                Log.pipeline.info("handleQuery — hasVault=\(hasVault) skipEnrichment=true")

                let notesContext: String?
                let resolvedQuery: String
                if hasVault, Self.queryContainsExplicitContext(query, attachments: chatState.pendingContextAttachments) {
                    let (ctx, cleaned) = await self.buildContextAttachments(
                        query: query,
                        attachments: chatState.pendingContextAttachments,
                        chatState: chatState
                    )
                    notesContext = ctx
                    resolvedQuery = cleaned
                } else {
                    notesContext = nil
                    resolvedQuery = query
                    chatState.loadedNoteIds = []
                    chatState.loadedNoteTitles = []
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
                let stream = pipeline.run(
                    query: effectiveQuery,
                    mode: mode,
                    controls: .defaults,
                    notesContext: effectiveNotesContext,
                    skipEnrichment: true,
                    conversationHistory: conversationHistory,
                    onEnriched: nil
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
                        let dualMessage = Self.persistableDualMessage(from: dual, truth: truth)
                        let confidence = truth?.overallTruthLikelihood
                        let grade = confidence.map(Self.gradeFromConfidence)
                        chatState.completeProcessing(
                            messageId: pendingAssistantId,
                            dualMessage: dualMessage,
                            confidence: confidence,
                            grade: grade,
                            mode: mode,
                            truthAssessment: truth
                        )

                        if let lastMsg = chatState.messages.last {
                            let processed = self.executeVaultActions(in: lastMsg.content)
                            if processed != lastMsg.content {
                                chatState.updateLastMessageContent(processed)
                            }
                        }

                        eventBus.emit(.pipelineComplete)

                        if !chatState.isIncognito {
                            self.persistChatCompletion(
                                chatId: capturedChatId,
                                query: query,
                                answer: chatState.messages.last?.content ?? "",
                                dual: dualMessage,
                                truth: truth,
                                confidence: confidence,
                                grade: grade,
                                mode: mode,
                                assistantMessage: chatState.messages.last,
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

    // MARK: - Vault Context

    static func resolveNotesContext(
        query: String,
        manifest: VaultManifest?,
        loadedNoteIds: Set<String>,
        loadedNoteTitles: [String] = [],
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody]
    ) async -> NotesContextResolution {
        guard let manifest else {
            return NotesContextResolution(
                context: nil,
                cleanedQuery: query,
                loadedNoteIds: [],
                loadedNoteTitles: []
            )
        }

        var cleanedQuery = query
        var referencedNotes: [VaultManifest.NoteBody] = []
        var nextLoadedNoteIds: Set<String> = []
        var nextLoadedTitles: [String] = []
        var includeManifest = false

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
                    let replacement = title.caseInsensitiveCompare(Self.allNotesMentionToken) == .orderedSame ? "" : title
                    cleanedQuery.replaceSubrange(fullRange, with: replacement)
                }
            }

            if !titlesToResolve.isEmpty {
                for title in titlesToResolve {
                    if title.caseInsensitiveCompare(Self.allNotesMentionToken) == .orderedSame {
                        includeManifest = true
                        continue
                    }
                    let found = await findNotesByTitle(title)
                    let ids = found.map(\.pageId).filter { !nextLoadedNoteIds.contains($0) }
                    if !ids.isEmpty {
                        let bodies = await fetchNoteBodies(ids)
                        for body in bodies {
                            referencedNotes.append(body)
                            nextLoadedNoteIds.insert(body.pageId)
                            if !nextLoadedTitles.contains(body.title) {
                                nextLoadedTitles.append(body.title)
                            }
                        }
                    }
                }
            }
        }

        let pack = VaultContextPack(
            manifest: manifest,
            includeManifest: includeManifest,
            referencedNotes: referencedNotes,
            cleanedQuery: cleanedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return NotesContextResolution(
            context: pack.renderedContext(),
            cleanedQuery: pack.cleanedQuery,
            loadedNoteIds: nextLoadedNoteIds,
            loadedNoteTitles: nextLoadedTitles
        )
    }

    static func searchReferenceResults(
        filter: String,
        manifest: VaultManifest?,
        chats: [SDChat],
        threads: [ChatThread],
        limitPerSection: Int = 6
    ) -> ReferenceSearchResults {
        let normalizedFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let noteChoices: [NoteMentionChoice] = {
            guard let manifest else { return [] }
            var results: [NoteMentionChoice] = []
            if normalizedFilter.isEmpty || "all notes".contains(normalizedFilter) || "all".contains(normalizedFilter) {
                results.append(.allNotes)
            }
            let entries = manifest.entries
            if normalizedFilter.isEmpty {
                results.append(contentsOf: entries.prefix(limitPerSection).map(NoteMentionChoice.entry))
                return results
            }
            let matched = entries.filter {
                let title = $0.title.lowercased()
                return title.hasPrefix(normalizedFilter) || title.contains(normalizedFilter)
            }
            results.append(contentsOf: matched.prefix(limitPerSection).map(NoteMentionChoice.entry))
            return results
        }()

        let recentChats = chats.map { chat in
            let preview = chat.sortedMessages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return ChatReferenceResult(
                attachment: ContextAttachment(
                    kind: .chat,
                    targetId: chat.id,
                    title: chat.title,
                    subtitle: "Main chat"
                ),
                preview: preview
            )
        }

        let transientThreads = threads
            .filter { !$0.messages.isEmpty }
            .map { thread in
                ChatReferenceResult(
                    attachment: ContextAttachment(
                        kind: .chat,
                        targetId: thread.id,
                        title: thread.label,
                        subtitle: thread.type == "palette" ? "Palette chat" : "Mini chat"
                    ),
                    preview: thread.messages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

        var seenChatIDs = Set<String>()
        let filteredChats = (recentChats + transientThreads).filter { result in
            seenChatIDs.insert(result.id).inserted
        }.filter { result in
            if normalizedFilter.isEmpty { return true }
            let haystack = [result.attachment.title, result.attachment.subtitle, result.preview]
                .compactMap { $0?.lowercased() }
                .joined(separator: "\n")
            return haystack.contains(normalizedFilter)
        }

        return ReferenceSearchResults(
            notes: noteChoices,
            chats: Array(filteredChats.prefix(limitPerSection))
        )
    }

    func buildNotesContext(query: String, chatState: ChatState) async -> (String?, String) {
        let resolution = await Self.resolveNotesContext(
            query: query,
            manifest: bootstrap.ambientManifest,
            loadedNoteIds: chatState.loadedNoteIds,
            loadedNoteTitles: chatState.loadedNoteTitles,
            findNotesByTitle: { [vaultSync] title in
                await vaultSync.findNotesByTitle(title)
            },
            fetchNoteBodies: { [vaultSync] ids in
                await vaultSync.fetchNoteBodies(ids: ids)
            }
        )
        chatState.loadedNoteIds = resolution.loadedNoteIds
        chatState.loadedNoteTitles = resolution.loadedNoteTitles
        return (resolution.context, resolution.cleanedQuery)
    }

    func buildContextAttachments(
        query: String,
        attachments: [ContextAttachment],
        chatState: ChatState
    ) async -> (String?, String) {
        let syntheticNoteMentions = attachments.compactMap { attachment -> String? in
            switch attachment.kind {
            case .note:
                return "@[\(attachment.title)]"
            case .allNotes:
                return "@[\(Self.allNotesMentionToken)]"
            case .chat:
                return nil
            }
        }
        let noteSeedQuery = syntheticNoteMentions.isEmpty
            ? query
            : syntheticNoteMentions.joined(separator: " ") + " " + query

        let resolution = await Self.resolveAttachedContext(
            query: noteSeedQuery,
            attachments: attachments,
            manifest: bootstrap.ambientManifest,
            loadedNoteIds: chatState.loadedNoteIds,
            loadedNoteTitles: chatState.loadedNoteTitles,
            findNotesByTitle: { [vaultSync] title in
                await vaultSync.findNotesByTitle(title)
            },
            fetchNoteBodies: { [vaultSync] ids in
                await vaultSync.fetchNoteBodies(ids: ids)
            },
            fetchChatMessages: { [bootstrap, modelContainer] chatID in
                await MainActor.run {
                    if let thread = bootstrap.threadState.chatThreads.first(where: { $0.id == chatID }) {
                        return thread.messages
                    }
                    let context = modelContainer.mainContext
                    let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatID })
                    guard let chat = try? context.fetch(descriptor).first else { return [] }
                    return chat.sortedMessages.map { message in
                        AssistantMessage(
                            role: message.role == "user" ? .user : .assistant,
                            content: message.content,
                            createdAt: message.createdAt
                        )
                    }
                }
            }
        )
        chatState.loadedNoteIds = resolution.loadedNoteIds
        chatState.loadedNoteTitles = resolution.loadedNoteTitles
        return (resolution.context, resolution.cleanedQuery)
    }

    static func resolveAttachedContext(
        query: String,
        attachments: [ContextAttachment],
        manifest: VaultManifest?,
        loadedNoteIds: Set<String>,
        loadedNoteTitles: [String],
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody],
        fetchChatMessages: @escaping @Sendable (String) async -> [AssistantMessage]
    ) async -> AttachedContextResolution {
        let syntheticNoteMentions = attachments.compactMap { attachment -> String? in
            switch attachment.kind {
            case .note:
                return "@[\(attachment.title)]"
            case .allNotes:
                return "@[\(Self.allNotesMentionToken)]"
            case .chat:
                return nil
            }
        }
        let noteSeedQuery = syntheticNoteMentions.isEmpty
            ? query
            : syntheticNoteMentions.joined(separator: " ") + " " + query

        let noteResolution = await resolveNotesContext(
            query: noteSeedQuery,
            manifest: manifest,
            loadedNoteIds: loadedNoteIds,
            loadedNoteTitles: loadedNoteTitles,
            findNotesByTitle: findNotesByTitle,
            fetchNoteBodies: fetchNoteBodies
        )

        let chatContext = await buildChatContextPack(
            for: attachments.filter { $0.kind == .chat },
            fetchChatMessages: fetchChatMessages
        )
        var parts: [String] = []
        if let context = noteResolution.context, !context.isEmpty {
            parts.append(context)
        }
        if let chatContext, !chatContext.isEmpty {
            parts.append(chatContext)
        }
        return AttachedContextResolution(
            context: parts.isEmpty ? nil : parts.joined(separator: "\n\n"),
            cleanedQuery: noteResolution.cleanedQuery,
            loadedNoteIds: noteResolution.loadedNoteIds,
            loadedNoteTitles: noteResolution.loadedNoteTitles
        )
    }

    static func buildChatContextPack(
        for attachments: [ContextAttachment],
        fetchChatMessages: @escaping @Sendable (String) async -> [AssistantMessage]
    ) async -> String? {
        guard !attachments.isEmpty else { return nil }

        var sections: [String] = []
        sections.reserveCapacity(attachments.count)

        for attachment in attachments {
            let messages = await fetchChatMessages(attachment.targetId)
            let transcript = messages.suffix(8).map { message in
                let role = message.role == .user ? "User" : "Assistant"
                let content = message.content.count > 800
                    ? String(message.content.prefix(800)) + "…"
                    : message.content
                return "\(role): \(content)"
            }
            guard !transcript.isEmpty else { continue }
            sections.append(
                """
                Attached chat context: \(attachment.title)
                \(transcript.joined(separator: "\n\n"))
                """
            )
        }

        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    static func queryContainsExplicitNoteContext(_ query: String) -> Bool {
        query.contains("@[")
    }

    static func queryContainsExplicitContext(_ query: String, attachments: [ContextAttachment]) -> Bool {
        queryContainsExplicitNoteContext(query) || !attachments.isEmpty
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
        confidence: Double?,
        grade: EvidenceGrade?,
        mode: InferenceMode,
        assistantMessage: ChatMessage?,
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
        if isNotes { chat.chatType = "notes" }

        let sourceUserMessage = persistedUserMessage(
            chatId: chatId,
            query: query,
            assistantMessage: assistantMessage
        )
        let userMsg = SDMessage(role: "user", content: query)
        if let sourceUserMessage {
            userMsg.id = sourceUserMessage.id
            userMsg.createdAt = sourceUserMessage.createdAt
        }
        userMsg.chat = chat
        context.insert(userMsg)

        let assistantMsg = SDMessage(role: "assistant", content: answer)
        if let assistantMessage {
            assistantMsg.id = assistantMessage.id
            assistantMsg.createdAt = assistantMessage.createdAt
        }
        assistantMsg.updateAnalysis(
            dualMessage: dual,
            truthAssessment: truth,
            confidence: confidence,
            evidenceGrade: grade,
            mode: mode,
            reasoningText: assistantMessage?.reasoningText,
            reasoningDuration: assistantMessage?.reasoningDuration
        )
        assistantMsg.chat = chat
        context.insert(assistantMsg)

        // Cross-system note association: scan for [[wikilinks]] in the query
        if chat.linkedPageId == nil {
            if let linkedId = detectLinkedPageId(in: query, context: context) {
                chat.linkedPageId = linkedId
            }
        }

        do {
            try context.save()
            Log.db.info("Persisted chat \(chatId, privacy: .public): user + assistant messages")
        } catch {
            Log.db.error("Failed to persist chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistedUserMessage(
        chatId: String,
        query: String,
        assistantMessage: ChatMessage?
    ) -> ChatMessage? {
        let currentMessages = chatState.messages
        guard !currentMessages.isEmpty else { return nil }

        if let assistantMessage,
           let assistantIndex = currentMessages.lastIndex(where: { $0.id == assistantMessage.id }) {
            return currentMessages[..<assistantIndex].last {
                $0.chatId == chatId && $0.role == .user
            }
        }

        return currentMessages.last {
            $0.chatId == chatId && $0.role == .user && $0.content == query
        } ?? currentMessages.last {
            $0.chatId == chatId && $0.role == .user
        }
    }

    func persistEnrichment(
        chatId: String?,
        messageId: String,
        dualMessage: DualMessage,
        truthAssessment: TruthAssessment,
        message: ChatMessage?
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

        let grade = Self.gradeFromConfidence(truthAssessment.overallTruthLikelihood)
        lastAssistant.updateAnalysis(
            dualMessage: dualMessage,
            truthAssessment: truthAssessment,
            confidence: truthAssessment.overallTruthLikelihood,
            evidenceGrade: grade,
            mode: message?.mode ?? lastAssistant.inferenceMode.flatMap(InferenceMode.init(rawValue:)),
            reasoningText: message?.reasoningText ?? lastAssistant.reasoningText,
            reasoningDuration: message?.reasoningDuration ?? lastAssistant.reasoningDuration
        )

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

    private static func persistableDualMessage(
        from dual: DualMessage,
        truth: TruthAssessment?
    ) -> DualMessage? {
        guard truth != nil ||
            !dual.rawAnalysis.isEmpty ||
            !dual.uncertaintyTags.isEmpty ||
            !dual.modelVsDataFlags.isEmpty ||
            dual.laymanSummary != nil ||
            dual.reflection != nil ||
            dual.arbitration != nil
        else {
            return nil
        }
        return dual
    }

    // MARK: - Cross-System Note Association

    /// Scan text for [[wikilinks]] or "Note: <title>" references and match against existing pages.
    /// Returns the pageId of the first matched note, or nil.
    private func detectLinkedPageId(in text: String, context: ModelContext) -> String? {
        var candidates: [String] = []

        // Extract [[wikilink]] targets
        let wikiPattern = /\[\[([^\]]+)\]\]/
        for match in text.matches(of: wikiPattern) {
            candidates.append(String(match.1).trimmingCharacters(in: .whitespaces))
        }

        // Extract "Note: <title>" prefix (from command palette context injection)
        let notePattern = /Note: (.+?)(?:\n|$)/
        if let match = text.firstMatch(of: notePattern) {
            candidates.append(String(match.1).trimmingCharacters(in: .whitespaces))
        }

        guard !candidates.isEmpty else { return nil }

        for candidate in candidates {
            let lower = candidate.lowercased()
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate { $0.title.localizedStandardContains(lower) }
            )
            // localizedStandardContains is case/diacritic-insensitive but may over-match;
            // filter to exact case-insensitive equality.
            if let page = try? context.fetch(descriptor).first(where: {
                $0.title.lowercased() == lower
            }) {
                return page.id
            }
        }
        return nil
    }
}
