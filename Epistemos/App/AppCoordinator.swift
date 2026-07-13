import AppKit
import Foundation
import SwiftData
import os

// MARK: - App Coordinator
// Handles event wiring, daily brief lifecycle, and vault events.
// Extracted from AppBootstrap — keeps AppBootstrap as pure state/service factory.

@MainActor
final class AppCoordinator {
    private unowned let bootstrap: AppBootstrap
    private let ambientManifestRefreshDriver = AmbientManifestRefreshDriver()
    private var pageChangeManifestRefreshTask: Task<Void, Never>?

    private let eventBus: EventBus
    private let uiState: UIState
    private let dailyBriefState: DailyBriefState
    private let triageService: TriageService
    private let vaultSync: VaultSyncService
    let pipelineService: PipelineService
    private let modelContainer: ModelContainer
    private let notesUI: NotesUIState

    init(
        bootstrap: AppBootstrap,
        eventBus: EventBus,
        uiState: UIState,
        dailyBriefState: DailyBriefState,
        triageService: TriageService,
        vaultSync: VaultSyncService,
        pipelineService: PipelineService,
        modelContainer: ModelContainer,
        notesUI: NotesUIState
    ) {
        self.bootstrap = bootstrap
        self.eventBus = eventBus
        self.uiState = uiState
        self.dailyBriefState = dailyBriefState
        self.triageService = triageService
        self.vaultSync = vaultSync
        self.pipelineService = pipelineService
        self.modelContainer = modelContainer
        self.notesUI = notesUI
    }

    // MARK: - Wire All Events

    func wireAll() {
        wireToastEvents()
        wireVaultEvents()
        wireDailyBrief()
    }

    // MARK: - EventBus Subscriptions

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
                self.pageChangeManifestRefreshTask?.cancel()
                self.pageChangeManifestRefreshTask = nil
                self.refreshAmbientManifest()
                self.bootstrap.noteInsightService.reindex()
                self.bootstrap.refreshLiveNoteScheduler()
            case .vaultPageChanged(let pageId):
                self.scheduleAmbientManifestRefreshAfterPageMutation()
                self.bootstrap.noteInsightService.reanalyze(pageId: pageId)
            default:
                break
            }
        }
    }

    // MARK: - Daily Brief

    private func wireDailyBrief() {
        guard ProductCapabilityPolicy.isAvailable(.generativeActions) else {
            dailyBriefState.onDailyBriefGenerate = nil
            return
        }
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
                discardNewDailyBriefFolderIfNeeded()
                Log.pipeline.error("AppCoordinator: failed to create vault-backed daily brief '\(title, privacy: .public)'")
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

    private func scheduleAmbientManifestRefreshAfterPageMutation() {
        pageChangeManifestRefreshTask?.cancel()
        pageChangeManifestRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.refreshAmbientManifest()
            self?.pageChangeManifestRefreshTask = nil
        }
    }

    // MARK: - Query Lifecycle

    func cancelActiveQuery() {
        pipelineService.cancelActiveRun()
        bootstrap.queryTask?.cancel()
        bootstrap.queryTask = nil
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
