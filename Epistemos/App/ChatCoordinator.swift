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
        let vaultTitle: String?
        let vaultNoteCount: Int
        let isInventoryComplete: Bool
        let query: String
        let indexedMatchedNoteIDs: Set<String>
        let indexedNoteSnippetsByPageID: [String: String]
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

    /// Process a user query through the direct local answer path, streaming tokens back to ChatState.
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
                Log.pipeline.info("handleQuery — hasVault=\(hasVault)")

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
                    notesContext: effectiveNotesContext,
                    conversationHistory: conversationHistory
                )

                for try await event in stream {
                    switch event {
                    case .textDelta(let token):
                        chatState.appendStreamingText(token)

                    case .completed:
                        chatState.completeProcessing(
                            messageId: pendingAssistantId,
                            mode: mode
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
                    systemPrompt: nil,
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
        includeAllNotesContext: Bool = false,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody],
        searchNoteIDs: @escaping @Sendable (String) async -> [String]
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
        var matchedVaultNotes: [VaultManifest.NoteBody] = []
        var nextLoadedNoteIds: Set<String> = []
        var nextLoadedTitles: [String] = []
        var includeManifest = includeAllNotesContext

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
                    let ids = uniquePreservingOrder(found.map(\.pageId))
                    if !ids.isEmpty {
                        let bodies = await fetchNoteBodies(ids)
                        appendLoadedNotes(
                            bodies,
                            to: &referencedNotes,
                            loadedIDs: &nextLoadedNoteIds,
                            loadedTitles: &nextLoadedTitles
                        )
                    }
                }
            }
        }

        if referencedNotes.isEmpty,
           let referencedTitle = explicitNoteReferenceTitle(in: cleanedQuery) {
            let ids = uniquePreservingOrder((await findNotesByTitle(referencedTitle)).map(\.pageId))
            if !ids.isEmpty {
                let bodies = await fetchNoteBodies(ids)
                appendLoadedNotes(
                    bodies,
                    to: &referencedNotes,
                    loadedIDs: &nextLoadedNoteIds,
                    loadedTitles: &nextLoadedTitles
                )
            }
        }

        if referencedNotes.isEmpty,
           queryLikelyTargetsExistingNote(cleanedQuery) {
            let ids = await autoMatchedReferencedNoteIDs(
                for: cleanedQuery,
                manifest: manifest,
                findNotesByTitle: findNotesByTitle,
                searchNoteIDs: searchNoteIDs
            )
            if !ids.isEmpty {
                let bodies = await fetchNoteBodies(ids)
                appendLoadedNotes(
                    bodies,
                    to: &referencedNotes,
                    loadedIDs: &nextLoadedNoteIds,
                    loadedTitles: &nextLoadedTitles
                )
            }
        }

        if includeManifest {
            let matchedIDs = await matchedVaultNoteIDs(
                for: cleanedQuery,
                manifest: manifest,
                searchNoteIDs: searchNoteIDs
            )
            if !matchedIDs.isEmpty {
                let bodies = await fetchNoteBodies(matchedIDs)
                appendLoadedNotes(
                    bodies,
                    to: &matchedVaultNotes,
                    loadedIDs: &nextLoadedNoteIds,
                    loadedTitles: &nextLoadedTitles
                )
            }
        }

        let pack = VaultContextPack(
            manifest: manifest,
            includeManifest: includeManifest,
            referencedNotes: referencedNotes,
            matchedVaultNotes: matchedVaultNotes,
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
        limitPerSection: Int = 6,
        indexedNoteIDs: [String] = [],
        indexedNoteSnippets: [String: String] = [:]
    ) -> ReferenceSearchResults {
        let normalizedFilter = normalizedSearchField(
            filter.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let uniqueIndexedNoteIDs = uniquePreservingOrder(indexedNoteIDs)
        let noteResultLimit = normalizedFilter.isEmpty ? max(limitPerSection, 10) : limitPerSection

        let noteChoices: [NoteMentionChoice] = {
            guard let manifest else { return [] }
            var results: [NoteMentionChoice] = []
            if shouldOfferAllNotesChoice(for: normalizedFilter) {
                results.append(.allNotes)
            }
            if normalizedFilter.isEmpty {
                let recentEntries = manifest.entries
                    .sorted {
                        if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    .prefix(noteResultLimit)
                results.append(contentsOf: recentEntries.map(NoteMentionChoice.entry))
                return results
            }

            let terms = searchTerms(from: normalizedFilter)
            let indexedBoosts = indexedNoteBoosts(
                pageIDs: uniqueIndexedNoteIDs,
                limit: limitPerSection * 2
            )
            let matched = manifest.entries
                .compactMap { entry -> (entry: VaultManifest.ManifestEntry, score: Int)? in
                    let score = noteSearchScore(
                        for: entry,
                        normalizedFilter: normalizedFilter,
                        terms: terms
                    ) + (indexedBoosts[entry.pageId] ?? 0)
                    return score > 0 ? (entry, score) : nil
                }
                .sorted {
                    if $0.score != $1.score { return $0.score > $1.score }
                    if $0.entry.updatedAt != $1.entry.updatedAt {
                        return $0.entry.updatedAt > $1.entry.updatedAt
                    }
                    return $0.entry.title.localizedCaseInsensitiveCompare($1.entry.title) == .orderedAscending
                }
            results.append(contentsOf: matched.prefix(noteResultLimit).map { .entry($0.entry) })
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
            if normalizedFilter.isEmpty { return false }
            let haystack = [result.attachment.title, result.attachment.subtitle, result.preview]
                .compactMap { $0?.lowercased() }
                .joined(separator: "\n")
            return haystack.contains(normalizedFilter)
        }

        return ReferenceSearchResults(
            notes: noteChoices,
            chats: Array(filteredChats.prefix(limitPerSection)),
            vaultTitle: manifest?.vaultTitle,
            vaultNoteCount: manifest?.totalNoteCount ?? 0,
            isInventoryComplete: manifest?.isInventoryComplete ?? false,
            query: normalizedFilter,
            indexedMatchedNoteIDs: Set(uniqueIndexedNoteIDs),
            indexedNoteSnippetsByPageID: indexedNoteSnippets
        )
    }

    private static func shouldOfferAllNotesChoice(for normalizedFilter: String) -> Bool {
        normalizedFilter.isEmpty
            || "all notes".contains(normalizedFilter)
            || "all".contains(normalizedFilter)
            || "vault".contains(normalizedFilter)
            || "everything".contains(normalizedFilter)
    }

    private static func searchTerms(from normalizedFilter: String) -> [String] {
        normalizedFilter
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func indexedNoteBoosts(pageIDs: [String], limit: Int) -> [String: Int] {
        var boosts: [String: Int] = [:]
        for (offset, pageID) in uniquePreservingOrder(pageIDs).prefix(limit).enumerated() {
            boosts[pageID] = max(18, 74 - (offset * 8))
        }
        return boosts
    }

    private static func noteSearchScore(
        for entry: VaultManifest.ManifestEntry,
        normalizedFilter: String,
        terms: [String]
    ) -> Int {
        let normalizedTitle = normalizedSearchField(entry.title)
        let normalizedFolder = entry.folderName.map { normalizedSearchField($0) } ?? ""
        let normalizedSnippet = normalizedSearchField(entry.snippet)
        let normalizedTags = entry.tags.map(normalizedSearchField)

        guard !terms.isEmpty else { return 0 }

        var score = 0
        for term in terms {
            var matchedCurrentTerm = false

            if normalizedTitle == term {
                score += 160
                matchedCurrentTerm = true
            } else if normalizedTitle.hasPrefix(term) {
                score += 120
                matchedCurrentTerm = true
            } else if normalizedTitle.contains(term) {
                score += 80
                matchedCurrentTerm = true
            }

            if normalizedFolder.hasPrefix(term) {
                score += 32
                matchedCurrentTerm = true
            } else if normalizedFolder.contains(term) {
                score += 24
                matchedCurrentTerm = true
            }

            var matchedTag = false
            for tag in normalizedTags {
                if tag == term {
                    score += 48
                    matchedCurrentTerm = true
                    matchedTag = true
                    break
                }
                if tag.hasPrefix(term) {
                    score += 38
                    matchedCurrentTerm = true
                    matchedTag = true
                    break
                }
                if tag.contains(term) {
                    score += 26
                    matchedCurrentTerm = true
                    matchedTag = true
                    break
                }
            }

            if !matchedTag {
                if normalizedSnippet.hasPrefix(term) {
                    score += 22
                    matchedCurrentTerm = true
                } else if normalizedSnippet.contains(term) {
                    score += 16
                    matchedCurrentTerm = true
                }
            }

            if !matchedCurrentTerm {
                return 0
            }
        }

        let ageInDays = max(0, Date().timeIntervalSince(entry.updatedAt) / 86_400)
        score += max(0, 14 - Int(min(ageInDays, 14)))
        return score
    }

    private static func normalizedSearchField(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    func buildNotesContext(query: String, chatState: ChatState) async -> (String?, String) {
        let resolution = await Self.resolveNotesContext(
            query: query,
            manifest: bootstrap.ambientManifest,
            loadedNoteIds: chatState.loadedNoteIds,
            loadedNoteTitles: chatState.loadedNoteTitles,
            includeAllNotesContext: false,
            findNotesByTitle: { [vaultSync] title in
                await vaultSync.findNotesByTitle(title)
            },
            fetchNoteBodies: { [vaultSync] ids in
                await vaultSync.fetchNoteBodies(ids: ids)
            },
            searchNoteIDs: { [vaultSync] query in
                await vaultSync.searchIndex(query: query)
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
        let resolution = await Self.resolveAttachedContext(
            query: query,
            attachments: attachments,
            manifest: bootstrap.ambientManifest,
            loadedNoteIds: chatState.loadedNoteIds,
            loadedNoteTitles: chatState.loadedNoteTitles,
            includeAllNotesContext: false,
            findNotesByTitle: { [vaultSync] title in
                await vaultSync.findNotesByTitle(title)
            },
            fetchNoteBodies: { [vaultSync] ids in
                await vaultSync.fetchNoteBodies(ids: ids)
            },
            searchNoteIDs: { [vaultSync] query in
                await vaultSync.searchIndex(query: query)
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
        includeAllNotesContext: Bool = false,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody],
        searchNoteIDs: @escaping @Sendable (String) async -> [String],
        fetchChatMessages: @escaping @Sendable (String) async -> [AssistantMessage]
    ) async -> AttachedContextResolution {
        let noteResolution = await resolveNotesContext(
            query: query,
            manifest: manifest,
            loadedNoteIds: loadedNoteIds,
            loadedNoteTitles: loadedNoteTitles,
            includeAllNotesContext: includeAllNotesContext
                || attachments.contains(where: { $0.kind == .allNotes }),
            findNotesByTitle: findNotesByTitle,
            fetchNoteBodies: fetchNoteBodies,
            searchNoteIDs: searchNoteIDs
        )

        let attachedNoteContext = await buildAttachedNoteContext(
            for: attachments.filter { $0.kind == .note },
            excluding: noteResolution.loadedNoteIds,
            findNotesByTitle: findNotesByTitle,
            fetchNoteBodies: fetchNoteBodies
        )
        let chatContext = await buildChatContextPack(
            for: attachments.filter { $0.kind == .chat },
            fetchChatMessages: fetchChatMessages
        )
        var parts: [String] = []
        if let attachedNoteContext = attachedNoteContext.context, !attachedNoteContext.isEmpty {
            parts.append(attachedNoteContext)
        }
        if let context = noteResolution.context, !context.isEmpty {
            parts.append(context)
        }
        if let chatContext, !chatContext.isEmpty {
            parts.append(chatContext)
        }
        let combinedLoadedNoteIDs = noteResolution.loadedNoteIds.union(attachedNoteContext.loadedNoteIds)
        var combinedLoadedTitles = noteResolution.loadedNoteTitles
        for title in attachedNoteContext.loadedNoteTitles where !combinedLoadedTitles.contains(title) {
            combinedLoadedTitles.append(title)
        }
        return AttachedContextResolution(
            context: parts.isEmpty ? nil : parts.joined(separator: "\n\n"),
            cleanedQuery: noteResolution.cleanedQuery,
            loadedNoteIds: combinedLoadedNoteIDs,
            loadedNoteTitles: combinedLoadedTitles
        )
    }

    private static func uniquePreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        results.reserveCapacity(ids.count)
        for id in ids where seen.insert(id).inserted {
            results.append(id)
        }
        return results
    }

    private static func explicitNoteReferenceTitle(in query: String) -> String? {
        let patterns = [
            #/(?i)\b(?:go\s+to|open|find|use|read|show|look\s+for|check)\s+(?:my\s+)?note\s+(.+?)(?=\s+(?:and|then|please|summarize|rewrite|analyze|compare|review|explain|tell|show|use)\b|[?.!,]|$)/#,
            #/(?i)\b(?:my\s+)?note\s+(.+?)(?=\s+(?:and|then|please|summarize|rewrite|analyze|compare|review|explain|tell|show|use)\b|[?.!,]|$)/#,
        ]

        for pattern in patterns {
            if let match = query.firstMatch(of: pattern) {
                let title = String(match.output.1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
                    .lowercased()
                if !title.isEmpty {
                    return title
                }
            }
        }
        return nil
    }

    private static func queryLikelyTargetsExistingNote(_ query: String) -> Bool {
        let normalized = normalizedSearchField(query)
        guard !normalized.isEmpty else { return false }
        let cues = [
            "note", "essay", "draft", "wrote", "written", "mentioned", "mentioning",
            "summarize it", "summarize that", "find", "look for", "show me", "open",
            "a few weeks ago", "few weeks ago", "last week", "yesterday", "earlier",
        ]
        return cues.contains { normalized.contains($0) }
    }

    private static func noteLookupSearchPhrases(from query: String) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var phrases = [trimmedQuery]
        let patterns = [
            #/(?i)\b(?:essay|note|draft)\s+(?:on|about)\s+(.+?)(?=\s+(?:a\s+few|few|last|yesterday|today|this|please|summarize|rewrite|analyze|compare|review|explain|show|find|open|where)\b|[?.!,]|$)/#,
            #/(?i)\b(?:mentioned|mentioning)\s+(.+?)(?=\s+(?:a\s+few|few|last|yesterday|today|this|please|summarize|rewrite|analyze|compare|review|explain|show|find|open)\b|[?.!,]|$)/#,
            #/(?i)\b(?:called|titled)\s+(.+?)(?=\s+(?:a\s+few|few|last|yesterday|today|this|please|summarize|rewrite|analyze|compare|review|explain|show|find|open)\b|[?.!,]|$)/#,
        ]

        for pattern in patterns {
            if let match = trimmedQuery.firstMatch(of: pattern) {
                let phrase = String(match.output.1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
                if !phrase.isEmpty {
                    phrases.append(phrase)
                }
            }
        }

        if let explicitTitle = explicitNoteReferenceTitle(in: trimmedQuery) {
            phrases.append(explicitTitle)
        }

        return uniquePreservingOrder(phrases)
    }

    private static func autoMatchedReferencedNoteIDs(
        for query: String,
        manifest: VaultManifest,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        searchNoteIDs: @escaping @Sendable (String) async -> [String]
    ) async -> [String] {
        let phrases = noteLookupSearchPhrases(from: query)
        guard !phrases.isEmpty else { return [] }

        var scoresByPageID: [String: Int] = [:]
        let normalizedQuery = normalizedSearchField(query)

        for (phraseIndex, phrase) in phrases.enumerated() {
            let normalizedPhrase = normalizedSearchField(phrase)
            let terms = searchTerms(from: normalizedPhrase)
            guard !terms.isEmpty else { continue }

            let titleMatches = await findNotesByTitle(phrase)
            for (offset, entry) in titleMatches.prefix(8).enumerated() {
                let boost = max(48, 120 - (offset * 12) - (phraseIndex * 8))
                scoresByPageID[entry.pageId] = max(scoresByPageID[entry.pageId] ?? 0, boost)
            }

            let indexedIDs = uniquePreservingOrder(await searchNoteIDs(phrase))
            let indexedBoosts = indexedNoteBoosts(pageIDs: indexedIDs, limit: 12)
            for entry in manifest.entries {
                let score = noteSearchScore(
                    for: entry,
                    normalizedFilter: normalizedPhrase,
                    terms: terms
                ) + (indexedBoosts[entry.pageId] ?? 0) + temporalHintBoost(
                    for: entry,
                    normalizedQuery: normalizedQuery
                )
                guard score > 0 else { continue }
                scoresByPageID[entry.pageId] = max(scoresByPageID[entry.pageId] ?? 0, score)
            }
        }

        let ranked = scoresByPageID.sorted { lhsPair, rhsPair in
            if lhsPair.value != rhsPair.value { return lhsPair.value > rhsPair.value }
            let lhsEntry = manifest.entries.first { $0.pageId == lhsPair.key }
            let rhsEntry = manifest.entries.first { $0.pageId == rhsPair.key }
            return (lhsEntry?.updatedAt ?? .distantPast) > (rhsEntry?.updatedAt ?? .distantPast)
        }
        guard let top = ranked.first, top.value >= 90 else { return [] }
        if let second = ranked.dropFirst().first, top.value < second.value + 18 {
            return []
        }
        return [top.key]
    }

    private static func temporalHintBoost(
        for entry: VaultManifest.ManifestEntry,
        normalizedQuery: String
    ) -> Int {
        if normalizedQuery.contains("few weeks ago") || normalizedQuery.contains("a few weeks ago") {
            let ageInDays = Int(Date().timeIntervalSince(entry.updatedAt) / 86_400)
            return (10...45).contains(ageInDays) ? 18 : 0
        }
        if normalizedQuery.contains("last week") {
            let ageInDays = Int(Date().timeIntervalSince(entry.updatedAt) / 86_400)
            return (5...14).contains(ageInDays) ? 16 : 0
        }
        if normalizedQuery.contains("yesterday") {
            let ageInDays = Int(Date().timeIntervalSince(entry.updatedAt) / 86_400)
            return ageInDays == 1 ? 16 : 0
        }
        if normalizedQuery.contains("today") {
            let ageInDays = Int(Date().timeIntervalSince(entry.updatedAt) / 86_400)
            return ageInDays == 0 ? 16 : 0
        }
        return 0
    }

    private static func appendLoadedNotes(
        _ bodies: [VaultManifest.NoteBody],
        to destination: inout [VaultManifest.NoteBody],
        loadedIDs: inout Set<String>,
        loadedTitles: inout [String]
    ) {
        for body in bodies {
            guard loadedIDs.insert(body.pageId).inserted else { continue }
            destination.append(body)
            if !loadedTitles.contains(body.title) {
                loadedTitles.append(body.title)
            }
        }
    }

    private static func matchedVaultNoteIDs(
        for query: String,
        manifest: VaultManifest,
        searchNoteIDs: @escaping @Sendable (String) async -> [String],
        limit: Int = 4
    ) async -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            let ranked = uniquePreservingOrder(await searchNoteIDs(trimmedQuery))
            if !ranked.isEmpty {
                return Array(ranked.prefix(limit))
            }
        }

        return manifest.entries
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(limit)
            .map(\.pageId)
    }

    private static func buildAttachedNoteContext(
        for attachments: [ContextAttachment],
        excluding excludedIDs: Set<String>,
        findNotesByTitle: @escaping @Sendable (String) async -> [VaultManifest.ManifestEntry],
        fetchNoteBodies: @escaping @Sendable ([String]) async -> [VaultManifest.NoteBody]
    ) async -> NotesContextResolution {
        guard !attachments.isEmpty else {
            return NotesContextResolution(
                context: nil,
                cleanedQuery: "",
                loadedNoteIds: [],
                loadedNoteTitles: []
            )
        }

        let directIDs = uniquePreservingOrder(attachments.map(\.targetId))
        let directBodies = await fetchNoteBodies(directIDs)
        var bodiesByID = Dictionary(uniqueKeysWithValues: directBodies.map { ($0.pageId, $0) })

        for attachment in attachments where bodiesByID[attachment.targetId] == nil {
            let fallbackIDs = uniquePreservingOrder(
                (await findNotesByTitle(attachment.title)).map(\.pageId)
            )
            guard !fallbackIDs.isEmpty else { continue }
            let fallbackBodies = await fetchNoteBodies(fallbackIDs)
            for body in fallbackBodies where bodiesByID[body.pageId] == nil {
                bodiesByID[body.pageId] = body
            }
        }

        var seenIDs = excludedIDs
        var sections: [String] = []
        var loadedIDs = Set<String>()
        var loadedTitles: [String] = []

        for attachment in attachments {
            guard let body = bodiesByID[attachment.targetId] else { continue }
            guard seenIDs.insert(body.pageId).inserted else { continue }
            sections.append("### Attached Note: \(body.title)\n\(body.body)")
            loadedIDs.insert(body.pageId)
            if !loadedTitles.contains(body.title) {
                loadedTitles.append(body.title)
            }
        }

        return NotesContextResolution(
            context: sections.isEmpty ? nil : sections.joined(separator: "\n\n"),
            cleanedQuery: "",
            loadedNoteIds: loadedIDs,
            loadedNoteTitles: loadedTitles
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
            || explicitNoteReferenceTitle(in: query) != nil
            || queryLikelyTargetsExistingNote(query)
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
        userMsg.updatePresentationSnapshot(
            attachments: sourceUserMessage?.attachments ?? [],
            loadedNoteTitles: sourceUserMessage?.loadedNoteTitles,
            contextAttachments: sourceUserMessage?.contextAttachments
        )
        userMsg.chat = chat
        context.insert(userMsg)

        let assistantMsg = SDMessage(role: "assistant", content: answer)
        if let assistantMessage {
            assistantMsg.id = assistantMessage.id
            assistantMsg.createdAt = assistantMessage.createdAt
        }
        assistantMsg.updatePresentationSnapshot(
            attachments: assistantMessage?.attachments ?? [],
            loadedNoteTitles: assistantMessage?.loadedNoteTitles,
            contextAttachments: assistantMessage?.contextAttachments
        )
        assistantMsg.inferenceMode = mode.rawValue
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

    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade {
        switch confidence {
        case 0.85...: .a
        case 0.70..<0.85: .b
        case 0.50..<0.70: .c
        case 0.30..<0.50: .d
        default: .f
        }
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
