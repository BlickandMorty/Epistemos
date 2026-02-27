import AppIntents
import AppKit
import Foundation
import os
import SwiftData

// MARK: - App Bootstrap
// One-time initialization on app launch.
// Creates state objects, services, and wires the dependency graph.
//
// Extensions:
//   AppBootstrap+ChatOrchestration.swift — query flow, pipeline events, title generation
//   AppBootstrap+NotesContext.swift      — vault context building, action markers
//   AppBootstrap+Persistence.swift       — SwiftData chat/enrichment persistence

@MainActor
final class AppBootstrap {
    /// Shared instance for App Intent access. Set during init.
    static var shared: AppBootstrap?

    // MARK: - Model Container
    let modelContainer: ModelContainer

    // MARK: - State
    let eventBus = EventBus()
    let chatState = ChatState()
    let pipelineState = PipelineState()
    let uiState = UIState()
    let notesUI = NotesUIState()
    let researchState = ResearchState()
    let soarState = SOARState()
    let inferenceState: InferenceState
    let dailyBriefState = DailyBriefState()
    let threadState = ThreadState()
    let graphState = GraphState()

    // MARK: - Ambient Vault Manifest
    /// Always-available vault manifest — built eagerly on vault attach, refreshed on changes.
    /// Nil when no vault is attached. Shared across all AI surfaces (main chat, MiniChat, graph inspector).
    var ambientManifest: VaultManifest?

    // MARK: - App Nap Prevention
    private var antiNapActivity: NSObjectProtocol?

    // MARK: - Active Query Task
    var queryTask: Task<Void, Never>?

    // MARK: - Services
    let llmService: LLMService
    let triageService: TriageService
    let researchService: ResearchService
    let vaultSync: VaultSyncService
    let pipelineService: PipelineService
    let soarService: SOARService

    init() {
        // Register custom fonts (RetroGaming, etc.)
        EpistemosFont.registerFonts()

        // Prevent App Nap for the entire session. Without this, macOS throttles
        // URLSession network calls when the app loses focus — breaking enrichment.
        antiNapActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Epistemos — keep AI pipelines alive when app loses focus"
        )

        // Create model container for all SwiftData types
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SDPage.self, SDFolder.self,
                     SDChat.self, SDMessage.self, SDPageVersion.self,
                     SDGraphNode.self, SDGraphEdge.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.modelContainer = container

        // InferenceState reads Keychain + checks Apple Intelligence availability
        let inference = InferenceState()
        self.inferenceState = inference

        // LLMService wraps the 5-provider interface
        let llm = LLMService(inference: inference)
        self.llmService = llm

        // TriageService routes between Apple Intelligence and API
        let triage = TriageService(inference: inference, llmService: llm)
        self.triageService = triage

        // ResearchService — Semantic Scholar + LLM-powered research
        self.researchService = ResearchService(research: researchState, llm: llm)

        // VaultSyncService — hybrid persistence bridge
        self.vaultSync = VaultSyncService(modelContainer: container)

        // SOARService — teacher-student-reward learning engine
        let soar = SOARService(soarState: soarState, llmService: llm, eventBus: eventBus)
        self.soarService = soar

        // PipelineService — 6-pass analytical engine
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llm,
            triageService: triage,
            eventBus: eventBus,
            soarService: soar
        )
        self.pipelineService = pipeline

        // Wire event bus to chat state
        chatState.eventBus = eventBus

        // Wire stop button → cancel active pipeline query
        chatState.onStopRequested = { [weak self] in
            self?.cancelActiveQuery()
        }

        // Wire EventBus: querySubmitted → PipelineService
        subscribeToPipelineEvents(pipeline: pipeline, chatState: chatState)

        // Evict old disk style cache entries in background (filesystem I/O).
        Task { DiskStyleCache.shared.evictIfNeeded() }

        // Wire Daily Brief overlay
        wireDailyBrief()

        // Wire toast/error display
        subscribeToToastEvents()

        // Wire vault change events → ambient manifest refresh
        subscribeToVaultEvents()

        // Give VaultSyncService access to EventBus for change notifications
        vaultSync.setEventBus(eventBus)

        // Check Ollama availability in background
        Task {
            await llm.checkOllama()
        }

        AppBootstrap.shared = self

        // Tell Siri to re-index App Intents on every launch
        EpistemosShortcutsProvider.updateAppShortcutParameters()

        Log.app.info("AppBootstrap: initialized — provider: \(inference.apiProvider.rawValue, privacy: .public)")
    }

    // MARK: - Daily Brief Wiring

    private func wireDailyBrief() {
        dailyBriefState.onDailyBriefGenerate = { [weak self] prompt in
            guard let self else { return nil }
            return try? await self.triageService.generateGeneral(
                prompt: prompt,
                systemPrompt: """
                You are a senior research analyst preparing a daily intelligence brief for a knowledge worker. \
                This person relies on your brief to orient their day — it must be comprehensive, specific, and actionable.

                Rules:
                - Reference actual note titles, conversation topics, and specific content — never be vague
                - Identify patterns the user hasn't explicitly connected
                - Flag stalled work and knowledge debts with urgency
                - Recommended actions must be concrete and reference specific materials
                - Write in flowing analytical prose, not shallow bullet lists
                - Use markdown headers (###) to structure sections, **bold** for emphasis
                - Aim for 600-1000 words — this is a deep brief, not a quick summary
                - If the vault contains many notes, focus on recency and interconnection, not exhaustive coverage
                """,
                operation: .chatResponse(query: prompt),
                contentLength: prompt.count
            )
        }

        dailyBriefState.onGoDeepGenerate = { [weak self] prompt in
            guard let self else { return nil }
            return try? await self.triageService.generateGeneral(
                prompt: prompt,
                systemPrompt: """
                You are a deep knowledge analyst performing a multi-perspective synthesis of the user's \
                personal knowledge base. This is NOT a casual summary — it's a rigorous analytical deep-dive.

                Analyze from these perspectives:
                1. **Statistical Patterns** — What do the numbers reveal? Note lengths, edit frequency, \
                tag distributions, chat confidence scores. What's the user spending the most time on?
                2. **Thematic Clusters** — Group the notes and chats into emergent themes. What clusters form? \
                Which themes are growing, which are dormant?
                3. **Temporal Evolution** — How has the user's focus shifted over time? What topics appeared \
                recently vs. weeks ago? What was abandoned mid-stream?
                4. **Knowledge Gaps** — Based on what the user is researching, what adjacent topics are missing? \
                What questions should they be asking but aren't?
                5. **Unexpected Connections** — Find non-obvious links between seemingly unrelated notes and chats. \
                Surprise the user with a connection they haven't noticed.

                Be specific — cite actual note titles, chat topics, dates, word counts, and confidence scores. \
                Include your own reflective thoughts: what does the pattern of activity *reveal* about the user's \
                intellectual trajectory? End with 3-5 provocative questions the user should consider.

                Format: Use markdown with **bold** for emphasis. Use ### headers for each analytical perspective. \
                Keep it substantive and intellectually challenging — this is meant to push thinking forward.
                """,
                operation: .chatResponse(query: prompt),
                contentLength: prompt.count
            )
        }

        dailyBriefState.onDailyBriefSave = { [weak self] content, isDeep in
            guard let self else { return }
            self.saveDailyBrief(content: content, isDeep: isDeep)
        }
    }

    /// Persist daily brief as a note in the "Daily Briefs" folder.
    private func saveDailyBrief(content: String, isDeep: Bool) {
        let context = modelContainer.mainContext

        // Find or create "Daily Briefs" folder
        let folderPred = #Predicate<SDFolder> { $0.name == "Daily Briefs" }
        let folderDesc = FetchDescriptor<SDFolder>(predicate: folderPred)
        let folder: SDFolder
        if let existing = try? context.fetch(folderDesc).first {
            folder = existing
        } else {
            folder = SDFolder(name: "Daily Briefs", emoji: "🌅")
            folder.isCollection = true
            context.insert(folder)
            CollectionRegistry.shared.setCollection("Daily Briefs", true)
        }

        let dateStr = Date.now.formatted(date: .abbreviated, time: .omitted)
        let title = isDeep ? "Deep Brief — \(dateStr)" : "Daily Brief — \(dateStr)"
        let emoji = isDeep ? "🔬" : "🌅"

        // Check for duplicate (same title = already saved today)
        let dupPred = #Predicate<SDPage> { $0.title == title }
        let dupDesc = FetchDescriptor<SDPage>(predicate: dupPred)
        let alreadySaved = (try? context.fetch(dupDesc))?.isEmpty == false
        guard !alreadySaved else { return }

        Task {
            if let pageId = await self.vaultSync.createPage(
                title: title,
                body: content,
                emoji: emoji,
                subfolder: "Daily Briefs"
            ) {
                let pagePred = #Predicate<SDPage> { $0.id == pageId }
                let pageQuery = FetchDescriptor<SDPage>(predicate: pagePred)
                if let page = try? context.fetch(pageQuery).first {
                    page.folder = folder
                    page.tags = ["daily-brief"]
                    do {
                        try context.save()
                    } catch {
                        Log.pipeline.error("Failed to save daily brief page: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } else {
                let page = SDPage(title: title, emoji: emoji)
                page.body = content
                page.subfolder = "Daily Briefs"
                page.wordCount = content.split(separator: " ").count
                page.folder = folder
                page.tags = ["daily-brief"]
                context.insert(page)
                do {
                    try context.save()
                } catch {
                    Log.pipeline.error("Failed to save daily brief fallback: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - Full Reset

    /// Wipe all persisted data except on-disk vault files, then show setup screen.
    /// Rebuild the ambient vault manifest from current SwiftData state.
    /// Called on vault attach, vault changes, and periodic refresh.
    func refreshAmbientManifest() {
        Task {
            ambientManifest = await vaultSync.buildAmbientManifest()
            Log.app.info("Ambient manifest refreshed: \(self.ambientManifest?.entries.count ?? 0) entries")
        }
    }

    func resetAllData() {
        queryTask?.cancel()
        queryTask = nil
        pipelineService.cancelAllEnrichment()
        ambientManifest = nil

        let context = modelContainer.mainContext
        do {
            try context.delete(model: SDMessage.self)
            try context.delete(model: SDChat.self)
            try context.delete(model: SDPageVersion.self)
            try context.delete(model: SDPage.self)
            try context.delete(model: SDFolder.self)
            try context.save()
        } catch {
            Log.pipeline.error("Reset: SwiftData wipe failed: \(error.localizedDescription, privacy: .public)")
        }

        Keychain.delete(for: "epistemos.apiKey.anthropic")
        Keychain.delete(for: "epistemos.apiKey.openai")
        Keychain.delete(for: "epistemos.apiKey.google")
        Keychain.delete(for: "epistemos.apiKey.kimi")

        let defaults = UserDefaults.standard
        let keysToRemove = [
            "epistemos.theme.pair",
            "epistemos.breathe.reminder",
            "epistemos.breathe.cycles",
            "epistemos.researchMode",
            "epistemos.apiProvider",
            "epistemos.anthropicModel",
            "epistemos.openaiModel",
            "epistemos.googleModel",
            "epistemos.kimiModel",
            "epistemos.ollamaBaseUrl",
            "epistemos.ollamaModel",
            "epistemos.research.savedPapers",
            "epistemos.soar.config",
        ]
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        chatState.clearMessages()
        researchState.reset()
        soarState.reset()
        notesUI.resetForVaultSwitch()
        pipelineState.clearConcepts()

        inferenceState.anthropicKey = ""
        inferenceState.openaiKey = ""
        inferenceState.googleKey = ""
        inferenceState.kimiKey = ""

        vaultSync.stopWatching()

        uiState.setActivePanel(.home)
        uiState.needsSetup = true

        Log.pipeline.info("Reset: All data cleared. Setup screen shown.")
    }

    // MARK: - Chat Navigation

    /// Load a chat by ID and navigate to it. Used by library provenance links.
    func loadChat(chatId: String) {
        let descriptor = FetchDescriptor<SDChat>(
            predicate: #Predicate<SDChat> { $0.id == chatId }
        )
        guard let sdChat = try? modelContainer.mainContext.fetch(descriptor).first else { return }
        let sorted = sdChat.sortedMessages
        let messages = sorted.map { msg in
            let dual = msg.dualMessageData.flatMap { try? JSONDecoder().decode(DualMessage.self, from: $0) }
            let isResearch = dual?.laymanSummary != nil
            return ChatMessage(
                id: msg.id,
                chatId: sdChat.id,
                role: msg.role == "user" ? .user : .assistant,
                content: msg.content,
                dualMessage: dual,
                truthAssessment: msg.truthAssessmentData.flatMap { try? JSONDecoder().decode(TruthAssessment.self, from: $0) },
                confidence: msg.confidenceScore,
                evidenceGrade: msg.evidenceGrade.flatMap { EvidenceGrade(rawValue: $0) },
                mode: msg.inferenceMode.flatMap { InferenceMode(rawValue: $0) },
                createdAt: msg.createdAt,
                isResearchResult: isResearch
            )
        }
        chatState.setCurrentChat(sdChat.id)
        chatState.chatTitle = sdChat.title
        chatState.loadMessages(messages)
        uiState.setActivePanel(.home)
        // Bring the main window to front — Library is a separate window,
        // so the user needs to see the main window where the chat lives.
        if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
            main.makeKeyAndOrderFront(nil)
        }
    }
}
