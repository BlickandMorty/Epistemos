import AppIntents
import AppKit
import Foundation
import os
import SwiftData

// MARK: - App Bootstrap
// Pure state/service factory. Creates state objects, services, and the dependency graph.
// All behavioral orchestration is delegated to AppCoordinator and ChatCoordinator.

@MainActor
final class AppBootstrap {
    /// Shared instance for App Intent access. Set during init.
    static var shared: AppBootstrap?
    private nonisolated static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    // MARK: - Model Container
    let modelContainer: ModelContainer
    /// Non-nil when the on-disk database failed to load and we fell back to in-memory.
    /// RootView shows a recovery alert when this is set.
    var databaseError: Error?

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
    let queryEngine = QueryEngine()
    let physicsCoordinator = PhysicsCoordinator()
    let dialogueChatState = DialogueChatState()

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
    let noteInsightService: NoteInsightService
    let pipelineService: PipelineService
    let soarService: SOARService

    // MARK: - Coordinators
    private(set) var coordinator: AppCoordinator!

    init() {
        // Register custom fonts (RetroGaming, etc.)
        EpistemosFont.registerFonts()

        // Prevent App Nap for the entire session. Without this, macOS throttles
        // URLSession network calls when the app loses focus — breaking enrichment.
        antiNapActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Epistemos — keep AI pipelines alive when app loses focus"
        )

        // Create model container with implicit lightweight migration.
        // SwiftData auto-handles adding defaulted properties without an explicit MigrationPlan.
        // Falls back to in-memory container on failure (corrupt DB, schema mismatch).
        let schema = Schema(EpistemosSchema.models)
        let container: ModelContainer
        let dbError: Error?
        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            dbError = nil
        } catch {
            Log.app.error("Database failed to load, falling back to in-memory: \(error.localizedDescription, privacy: .public)")
            // swiftlint:disable:next force_try — in-memory container cannot fail
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            dbError = error
        }
        self.modelContainer = container
        self.databaseError = dbError

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

        // NoteInsightService — on-device ML analysis for all notes
        self.noteInsightService = NoteInsightService(modelContainer: container)

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

        // Create coordinators
        let chatCoordinator = ChatCoordinator(
            bootstrap: self,
            chatState: chatState,
            pipelineService: pipeline,
            inferenceState: inference,
            soarState: soarState,
            vaultSync: vaultSync,
            modelContainer: container,
            eventBus: eventBus,
            llmService: llm,
            researchState: researchState,
            notesUI: notesUI
        )

        let appCoordinator = AppCoordinator(
            bootstrap: self,
            chatCoordinator: chatCoordinator,
            eventBus: eventBus,
            uiState: uiState,
            chatState: chatState,
            dailyBriefState: dailyBriefState,
            triageService: triage,
            vaultSync: vaultSync,
            pipelineService: pipeline,
            modelContainer: container,
            notesUI: notesUI
        )
        self.coordinator = appCoordinator

        // Wire stop button → cancel active pipeline query
        chatState.onStopRequested = { [weak self] in
            self?.coordinator.cancelActiveQuery()
        }

        // Set shared before wiring so that any callbacks can access it.
        AppBootstrap.shared = self

        // Wire all events (pipeline, toast, vault, daily brief)
        appCoordinator.wireAll()

        // Evict old disk style cache entries in background (filesystem I/O).
        Task { DiskStyleCache.shared.evictIfNeeded() }

        // Give VaultSyncService access to EventBus for change notifications
        vaultSync.setEventBus(eventBus)

        // Check Ollama availability in background.
        // Skip under tests to avoid pointless localhost network churn in the test host.
        if !Self.isRunningTests {
            Task(priority: .utility) { await llm.checkOllama() }
        }

        // One-time migration: move note bodies from inline SQLite to file storage.
        // Do the fetch/write/save cycle off the main actor to avoid launch hitching.
        Task(priority: .utility) { await migrateBodiesToFileStorage() }

        // Eagerly load graph store so command palette search works before the graph window opens.
        // Runs synchronously on MainActor — no Task wrapper — so queryEngine is configured
        // before any user interaction can trigger a query.
        graphState.loadGraph(context: container.mainContext)
        graphState.modelContext = container.mainContext
        // Configure query engine with live dependencies.
        // SearchIndexService may not exist yet if no vault is attached —
        // create a default one so queries work even without vault.
        let searchIdx = vaultSync.searchService ?? (try? SearchIndexService())
        if let searchIdx {
            queryEngine.configure(
                graphStore: graphState.store,
                graphState: graphState,
                searchIndex: searchIdx
            )
        }

        // Tell Siri to re-index App Intents on every launch
        EpistemosShortcutsProvider.updateAppShortcutParameters()

        Log.app.info("AppBootstrap: initialized — provider: \(inference.apiProvider.rawValue, privacy: .public)")
    }

    // MARK: - Forwarding (for external callers that reference AppBootstrap directly)

    func cancelActiveQuery() { coordinator.cancelActiveQuery() }
    func refreshAmbientManifest() { coordinator.refreshAmbientManifest() }
    func loadChat(chatId: String) { coordinator.loadChat(chatId: chatId) }
    func requestVaultBriefing(chatState: ChatState) { coordinator.requestVaultBriefing(chatState: chatState) }
    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade { ChatCoordinator.gradeFromConfidence(confidence) }

    // MARK: - Database Recovery

    func resetDatabaseAndRelaunch() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        // SwiftData default.store lives at the Application Support root (no subdirectory)
        if let dir = appSupport {
            for name in ["default.store", "default.store-shm", "default.store-wal"] {
                try? fm.removeItem(at: dir.appendingPathComponent(name))
            }
        }

        // Also clean Epistemos subdirectory (search index, etc.)
        if let dir = appSupport?.appendingPathComponent("Epistemos") {
            do {
                let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                for file in contents where file.pathExtension == "sqlite"
                    || file.lastPathComponent.contains("default.store") {
                    try? fm.removeItem(at: file)
                }
            } catch {
                Log.app.error("Failed to enumerate Epistemos directory during reset: \(error.localizedDescription, privacy: .public)")
            }
        }
        Log.app.info("Database reset complete — relaunching")
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: - Full Reset

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
            try context.delete(model: SDNoteInsight.self)
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

    // MARK: - Body File Storage Migration

    private func migrateBodiesToFileStorage() async {
        let migrationKey = "v2_body_migration_complete"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        do {
            let migrated = try await BodyMigrationActor(modelContainer: modelContainer).migrateInlineBodiesToFiles()
            UserDefaults.standard.set(true, forKey: migrationKey)
            if migrated > 0 {
                Log.app.info("Body file storage migration: moved \(migrated) bodies to disk")
            }
        } catch {
            Log.app.error("Body migration: failed — will retry on next launch: \(error.localizedDescription, privacy: .public)")
        }
    }
}

@ModelActor
private actor BodyMigrationActor {
    func migrateInlineBodiesToFiles() throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        var migrated = 0
        for page in pages where !page.body.isEmpty {
            NoteFileStorage.writeBody(pageId: page.id, content: page.body)
            page.body = ""
            migrated += 1
        }
        if migrated > 0 {
            try modelContext.save()
        }
        return migrated
    }
}
