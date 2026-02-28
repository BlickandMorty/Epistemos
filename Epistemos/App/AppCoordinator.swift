import AppKit
import Foundation
import SwiftData
import os

// MARK: - App Coordinator
// Handles event wiring, daily brief lifecycle, vault events, and chat navigation.
// Extracted from AppBootstrap — keeps AppBootstrap as pure state/service factory.

@MainActor
final class AppCoordinator {
    private unowned let bootstrap: AppBootstrap
    let chatCoordinator: ChatCoordinator

    private let eventBus: EventBus
    private let uiState: UIState
    private let chatState: ChatState
    private let dailyBriefState: DailyBriefState
    private let triageService: TriageService
    private let vaultSync: VaultSyncService
    private let pipelineService: PipelineService
    private let modelContainer: ModelContainer
    private let notesUI: NotesUIState

    init(
        bootstrap: AppBootstrap,
        chatCoordinator: ChatCoordinator,
        eventBus: EventBus,
        uiState: UIState,
        chatState: ChatState,
        dailyBriefState: DailyBriefState,
        triageService: TriageService,
        vaultSync: VaultSyncService,
        pipelineService: PipelineService,
        modelContainer: ModelContainer,
        notesUI: NotesUIState
    ) {
        self.bootstrap = bootstrap
        self.chatCoordinator = chatCoordinator
        self.eventBus = eventBus
        self.uiState = uiState
        self.chatState = chatState
        self.dailyBriefState = dailyBriefState
        self.triageService = triageService
        self.vaultSync = vaultSync
        self.pipelineService = pipelineService
        self.modelContainer = modelContainer
        self.notesUI = notesUI
    }

    // MARK: - Wire All Events

    func wireAll() {
        wirePipelineEvents()
        wireToastEvents()
        wireVaultEvents()
        wireDailyBrief()
    }

    // MARK: - EventBus Subscriptions

    private func wirePipelineEvents() {
        let pipeline = pipelineService
        let chat = chatState
        eventBus.subscribe(id: "pipeline") { [weak self] event in
            guard let self else { return }
            switch event {
            case .querySubmitted(_, let query):
                self.chatCoordinator.handleQuery(query, pipeline: pipeline, chatState: chat)
            default:
                break
            }
        }
    }

    private func wireToastEvents() {
        eventBus.subscribe(id: "toast") { [weak self] event in
            guard let self else { return }
            switch event {
            case .toast(let message, let type):
                self.uiState.showToast(message, type: type)
            case .error(let message):
                self.uiState.showToast(message, type: .error)
            default:
                break
            }
        }
    }

    private func wireVaultEvents() {
        eventBus.subscribe(id: "vaultManifest") { [weak self] event in
            guard let self else { return }
            switch event {
            case .vaultChanged:
                self.refreshAmbientManifest()
            default:
                break
            }
        }
    }

    // MARK: - Daily Brief

    private func wireDailyBrief() {
        dailyBriefState.onDailyBriefGenerate = { [weak self] prompt in
            guard let self else { return nil }
            let briefSystemPrompt = """
            You are a concise research analyst preparing a daily intelligence brief. \
            Reference actual note titles and specific content. Identify patterns the user hasn't connected. \
            Flag stalled work. Recommend concrete actions referencing specific materials. \
            Use markdown headers (###) and **bold**. Aim for 300-500 words.
            """
            do {
                return try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: briefSystemPrompt
                )
            } catch {
                return try? await self.triageService.generateGeneral(
                    prompt: prompt,
                    systemPrompt: briefSystemPrompt,
                    operation: .chatResponse(query: prompt),
                    contentLength: prompt.count
                )
            }
        }

        dailyBriefState.onGoDeepGenerate = { [weak self] prompt in
            guard let self else { return nil }
            let deepSystemPrompt = """
            You are a deep knowledge analyst performing multi-perspective synthesis. \
            Analyze from: statistical patterns, thematic clusters, temporal evolution, \
            knowledge gaps, unexpected connections. Cite actual note titles, dates, and details. \
            Use ### headers per perspective. Be substantive and intellectually challenging. \
            End with 3-5 provocative questions.
            """
            do {
                return try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: deepSystemPrompt
                )
            } catch {
                return try? await self.triageService.generateGeneral(
                    prompt: prompt,
                    systemPrompt: deepSystemPrompt,
                    operation: .chatResponse(query: prompt),
                    contentLength: prompt.count
                )
            }
        }

        dailyBriefState.onDailyBriefSave = { [weak self] content, isDeep in
            guard let self else { return }
            self.saveDailyBrief(content: content, isDeep: isDeep)
        }
    }

    private func saveDailyBrief(content: String, isDeep: Bool) {
        let context = modelContainer.mainContext

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
                page.saveBody(content)
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

    // MARK: - Vault Manifest

    func refreshAmbientManifest() {
        Task {
            bootstrap.ambientManifest = await vaultSync.buildAmbientManifest()
            Log.app.info("Ambient manifest refreshed: \(self.bootstrap.ambientManifest?.entries.count ?? 0) entries")
        }
    }

    // MARK: - Query Lifecycle

    func cancelActiveQuery() {
        bootstrap.queryTask?.cancel()
        bootstrap.queryTask = nil
        pipelineService.cancelAllEnrichment()
    }

    func requestVaultBriefing(chatState: ChatState) {
        Task {
            guard let fullManifest = await vaultSync.buildVaultManifest() else {
                chatState.addErrorMessage("No notes found in vault.")
                return
            }
            chatState.vaultBriefingManifest = fullManifest
            chatState.submitQuery("[VAULT_BRIEFING]")
        }
    }

    // MARK: - Chat Navigation

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
        if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
            main.makeKeyAndOrderFront(nil)
        }
    }
}
