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
    private let ambientManifestRefreshDriver = AmbientManifestRefreshDriver()

    private let eventBus: EventBus
    private let uiState: UIState
    private let chatState: ChatState
    private let dailyBriefState: DailyBriefState
    private let triageService: TriageService
    private let vaultSync: VaultSyncService
    let pipelineService: PipelineService
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
            case .querySubmitted(_, let query, let operatingMode):
                self.chatCoordinator.handleQuery(
                    query,
                    pipeline: pipeline,
                    chatState: chat,
                    operatingMode: operatingMode
                )
            default:
                break
            }
        }
    }

    func handleMiniChatQuery(
        _ query: String,
        chatState: ChatState,
        operatingMode: EpistemosOperatingMode
    ) {
        chatCoordinator.handleQuery(
            query,
            pipeline: pipelineService,
            chatState: chatState,
            operatingMode: operatingMode
        )
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
                self.bootstrap.noteInsightService.reindex()
                self.bootstrap.refreshLiveNoteScheduler()
            case .vaultPageChanged(let pageId):
                self.refreshAmbientManifest()
                self.bootstrap.noteInsightService.reanalyze(pageId: pageId)
            default:
                break
            }
        }
    }

    // MARK: - Daily Brief

    private func wireDailyBrief() {
        dailyBriefState.onDailyBriefGenerate = { [weak self] prompt in
            guard let self else { return nil }
            do {
                return try await self.triageService.generateGeneral(
                    prompt: prompt,
                    systemPrompt: nil,
                    operation: .brainstorm,
                    contentLength: prompt.count
                )
            } catch {
                Log.pipeline.error(
                    "Daily brief generation failed: \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }

        dailyBriefState.onDailyBriefSave = { [weak self] content in
            guard let self else { return }
            self.saveDailyBrief(content: content)
        }
    }

    private func saveDailyBrief(content: String) {
        let context = modelContainer.mainContext

        let folderPred = #Predicate<SDFolder> { $0.name == "Daily Briefs" }
        let folderDesc = FetchDescriptor<SDFolder>(predicate: folderPred)
        let folder: SDFolder
        let createdFolder: Bool
        do {
            if let existing = try context.fetch(folderDesc).first {
                folder = existing
                createdFolder = false
            } else {
                folder = SDFolder(name: "Daily Briefs", emoji: "🌅")
                folder.isCollection = true
                context.insert(folder)
                CollectionRegistry.shared.setCollection("Daily Briefs", true)
                createdFolder = true
            }
        } catch {
            Log.pipeline.error("AppCoordinator: failed to fetch Daily Briefs folder: \(error.localizedDescription, privacy: .public)")
            return
        }

        let dateStr = Date.now.formatted(date: .abbreviated, time: .omitted)
        let title = "Daily Brief — \(dateStr)"
        let emoji = "🌅"

        func discardNewDailyBriefFolderIfNeeded() {
            guard createdFolder else { return }
            context.delete(folder)
            CollectionRegistry.shared.setCollection("Daily Briefs", false)
        }

        func discardFailedFallbackPage(_ page: SDPage) {
            let failedPageId = page.id
            context.delete(page)

            let blockDescriptor = FetchDescriptor<SDBlock>(
                predicate: #Predicate<SDBlock> { $0.pageId == failedPageId }
            )
            do {
                for block in try context.fetch(blockDescriptor) {
                    context.delete(block)
                }
            } catch {
                Log.pipeline.error(
                    "AppCoordinator: failed to cleanup daily brief blocks for \(failedPageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }

            NoteFileStorage.deleteBody(pageId: failedPageId)
        }

        let dupPred = #Predicate<SDPage> { $0.title == title }
        let dupDesc = FetchDescriptor<SDPage>(predicate: dupPred)
        let alreadySaved: Bool
        do {
            alreadySaved = try context.fetch(dupDesc).isEmpty == false
        } catch {
            discardNewDailyBriefFolderIfNeeded()
            Log.pipeline.error("AppCoordinator: failed to check existing daily brief '\(title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return
        }

        guard !alreadySaved else {
            discardNewDailyBriefFolderIfNeeded()
            return
        }

        Task {
            if let pageId = await self.vaultSync.createPage(
                title: title,
                body: content,
                emoji: emoji,
                subfolder: "Daily Briefs",
                allowVaultSelectionPrompt: true
            ) {
                let pagePred = #Predicate<SDPage> { $0.id == pageId }
                let pageQuery = FetchDescriptor<SDPage>(predicate: pagePred)
                do {
                    if let page = try context.fetch(pageQuery).first {
                        let originalFolder = page.folder
                        let originalTags = page.tags
                        page.folder = folder
                        page.tags = ["daily-brief"]
                        do {
                            try context.save()
                            AppBootstrap.shared?.graphState.needsRefresh = true
                        } catch {
                            page.folder = originalFolder
                            page.tags = originalTags
                            discardNewDailyBriefFolderIfNeeded()
                            Log.pipeline.error("Failed to save daily brief page: \(error.localizedDescription, privacy: .public)")
                        }
                    } else {
                        discardNewDailyBriefFolderIfNeeded()
                        Log.pipeline.error("AppCoordinator: created daily brief missing from SwiftData: \(pageId, privacy: .public)")
                    }
                } catch {
                    discardNewDailyBriefFolderIfNeeded()
                    Log.pipeline.error("AppCoordinator: failed to fetch created daily brief \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            } else {
                let page = SDPage(title: title, emoji: emoji)
                page.saveBody(content)
                page.subfolder = "Daily Briefs"
                page.wordCount = content.split(separator: " ").count
                page.folder = folder
                page.tags = ["daily-brief"]
                page.needsVaultSync = true
                page.updatedAt = .now
                context.insert(page)
                BlockMirror.sync(pageId: page.id, body: content, modelContext: context)
                do {
                    try context.save()
                    AppBootstrap.shared?.graphState.needsRefresh = true
                } catch {
                    discardFailedFallbackPage(page)
                    discardNewDailyBriefFolderIfNeeded()
                    Log.pipeline.error("Failed to save daily brief fallback: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - Vault Manifest

    func refreshAmbientManifest() {
        Task { [ambientManifestRefreshDriver, vaultSync, bootstrap] in
            await ambientManifestRefreshDriver.request(
                build: {
                    await vaultSync.buildAmbientManifest()
                },
                apply: { manifest in
                    await MainActor.run {
                        vaultSync.ambientManifest = manifest
                        bootstrap.ambientManifest = manifest
                        Log.app.info("Ambient manifest refreshed: \(manifest?.entries.count ?? 0) entries")
                    }
                }
            )
        }
    }

    // MARK: - Query Lifecycle

    func cancelActiveQuery() {
        pipelineService.cancelActiveRun()
        bootstrap.queryTask?.cancel()
        bootstrap.queryTask = nil
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
        let sdChat: SDChat
        do {
            guard let fetched = try modelContainer.mainContext.fetch(descriptor).first else {
                Log.app.error("AppCoordinator: missing chat \(chatId, privacy: .public)")
                return
            }
            sdChat = fetched
        } catch {
            Log.app.error("AppCoordinator: failed to fetch chat \(chatId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        chatState.setCurrentChat(sdChat.id)
        chatState.chatTitle = sdChat.title
        chatState.loadMessages(sdChat.loadedMessages)
        uiState.setActivePanel(.home)
        uiState.homeTab = .home
        HomeWindowIdentity.surfaceHomeWindow()
    }
}

actor AmbientManifestRefreshDriver {
    private var isRefreshing = false
    private var pendingRefresh = false

    func request(
        build: @escaping @Sendable () async -> VaultManifest?,
        apply: @escaping @Sendable (VaultManifest?) async -> Void
    ) async {
        guard !isRefreshing else {
            pendingRefresh = true
            return
        }

        isRefreshing = true
        await run(build: build, apply: apply)
    }

    private func run(
        build: @escaping @Sendable () async -> VaultManifest?,
        apply: @escaping @Sendable (VaultManifest?) async -> Void
    ) async {
        while true {
            let manifest = await build()
            await apply(manifest)
            await Task.yield()

            if pendingRefresh {
                pendingRefresh = false
                continue
            }

            isRefreshing = false
            return
        }
    }
}
