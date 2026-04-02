import AppIntents
import AppKit
import Foundation
import Metal
import os
import QuartzCore
import SwiftData

// MARK: - App Bootstrap
// Pure state/service factory. Creates state objects, services, and the dependency graph.
// All behavioral orchestration is delegated to AppCoordinator and ChatCoordinator.

@MainActor
private final class LocalModelRefreshThrottle {
    private let manager: LocalModelManager
    private let interval: TimeInterval
    private var lastRefreshAt: Date = .distantPast

    init(manager: LocalModelManager, interval: TimeInterval) {
        self.manager = manager
        self.interval = interval
    }

    func refreshIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRefreshAt) >= interval else {
            return
        }
        manager.refreshFromDisk()
        lastRefreshAt = now
    }
}

struct StartupIntegrityReport: Sendable {
    let sampledPageIds: [String]
    let corruptedPageIds: [String]
    let unrecoverablePageIds: [String]
    let eventStoreAvailable: Bool
    let vaultBookmarkExists: Bool
    let vaultBookmarkReadyForAutomaticRestore: Bool
    let vaultBookmarkFailureReason: String?

    var shouldBlockAutomaticVaultRestore: Bool {
        !corruptedPageIds.isEmpty || (vaultBookmarkExists && !vaultBookmarkReadyForAutomaticRestore)
    }
}

struct StartupIntegrityPageSnapshot: Sendable, Equatable {
    let id: String
    let filePath: String?
    let hasInlineBody: Bool
    let hasMeaningfulMetadata: Bool
}

struct StartupIntegrityToast: Sendable, Equatable {
    let message: String
    let type: ToastType
}

@MainActor
final class AppBootstrap {
    /// Shared instance for App Intent access. Set during init.
    static var shared: AppBootstrap?
    private nonisolated static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private static func requireInitialized<Value>(_ value: Value?, name: StaticString) -> Value {
        guard let value else {
            preconditionFailure("AppBootstrap.\(name.description) accessed before initialization")
        }
        return value
    }

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
    let inferenceState: InferenceState
    let localModelManager: LocalModelManager
    let dailyBriefState = DailyBriefState()
    let threadState = ThreadState()
    let graphState = GraphState()
    let queryEngine = QueryEngine()
    let physicsCoordinator = PhysicsCoordinator()
    let dialogueChatState = DialogueChatState()
    let orchestratorState = OrchestratorState()
    let mcpBridge = MCPBridge()
    let hermesManager = HermesSubprocessManager()
    let agentViewModel: AgentViewModel
    let hermesAdminViewModel: HermesAdminViewModel
    let constrainedDecoding = ConstrainedDecodingService()
    let hardwareTierManager = HardwareTierManager()
    private var _deviceAgent: DeviceAgentService?
    var deviceAgent: DeviceAgentService { Self.requireInitialized(_deviceAgent, name: "deviceAgent") }
    private var _dualBrainRouter: DualBrainRouter?
    var dualBrainRouter: DualBrainRouter { Self.requireInitialized(_dualBrainRouter, name: "dualBrainRouter") }
    private var _screen2AXFusion: Screen2AXFusion?
    var screen2AXFusion: Screen2AXFusion { Self.requireInitialized(_screen2AXFusion, name: "screen2AXFusion") }
    private var _visualVerifyLoop: VisualVerifyLoop?
    var visualVerifyLoop: VisualVerifyLoop { Self.requireInitialized(_visualVerifyLoop, name: "visualVerifyLoop") }
    private var _agentGraphMemory: AgentGraphMemory?
    var agentGraphMemory: AgentGraphMemory { Self.requireInitialized(_agentGraphMemory, name: "agentGraphMemory") }
    private var _recipeGraphSkills: RecipeGraphSkills?
    var recipeGraphSkills: RecipeGraphSkills { Self.requireInitialized(_recipeGraphSkills, name: "recipeGraphSkills") }
    private var _ghostBrainCoauthor: GhostBrainCoauthor?
    var ghostBrainCoauthor: GhostBrainCoauthor { Self.requireInitialized(_ghostBrainCoauthor, name: "ghostBrainCoauthor") }
    private var _reasoningLoopService: ReasoningLoopService?
    var reasoningLoopService: ReasoningLoopService { Self.requireInitialized(_reasoningLoopService, name: "reasoningLoopService") }
    let instantRecallService = InstantRecallService()
    private var _workspaceService: WorkspaceService?
    var workspaceService: WorkspaceService { Self.requireInitialized(_workspaceService, name: "workspaceService") }
    let activityTracker = ActivityTracker()
    private var _workspaceSummaryService: WorkspaceSummaryService?
    var workspaceSummaryService: WorkspaceSummaryService { Self.requireInitialized(_workspaceSummaryService, name: "workspaceSummaryService") }
    private var _timeMachineService: TimeMachineService?
    var timeMachineService: TimeMachineService { Self.requireInitialized(_timeMachineService, name: "timeMachineService") }

    // MARK: - Infrastructure
    let supervisor = AppSupervisor()
    let orphanCleanup = OrphanSubprocessCleanup()
    private var _paperclipStore: PaperclipStateStore?
    var paperclipStore: PaperclipStateStore { Self.requireInitialized(_paperclipStore, name: "paperclipStore") }

    // MARK: - Cognitive Substrates
    let epistemosConfig = EpistemosConfig()
    private var _ambientCapture: AmbientCaptureService?
    var ambientCapture: AmbientCaptureService { Self.requireInitialized(_ambientCapture, name: "ambientCapture") }
    private var _frictionMonitor: FrictionMonitorService?
    var frictionMonitor: FrictionMonitorService { Self.requireInitialized(_frictionMonitor, name: "frictionMonitor") }
    private var _nightBrain: NightBrainService?
    var nightBrain: NightBrainService { Self.requireInitialized(_nightBrain, name: "nightBrain") }
    private var _agentHeartbeat: AgentHeartbeatService?
    var agentHeartbeat: AgentHeartbeatService { Self.requireInitialized(_agentHeartbeat, name: "agentHeartbeat") }

    // MARK: - Ambient Vault Manifest
    /// Always-available vault manifest — built eagerly on vault attach, refreshed on changes.
    /// Nil when no vault is attached. Shared across all AI surfaces (main chat, MiniChat, graph inspector).
    var ambientManifest: VaultManifest?

    // MARK: - Active Query Task
    var queryTask: Task<Void, Never>?
    private var healthyVaultBodyCleanupTask: Task<Void, Never>?
    private var localRuntimeObserverTokens: [NSObjectProtocol] = []
    private let localModelRefreshThrottle: LocalModelRefreshThrottle
    private var startupIntegrityReport: StartupIntegrityReport?
    private var didStartPrimaryLaunchInitialization = false
    private var didCompletePrimaryLaunchInitialization = false
    private var didStartDeferredRuntimeServices = false

    private nonisolated static let primaryLaunchInitializationWaitTimeout: Duration = .seconds(6)
    private nonisolated static let primaryLaunchInitializationPollInterval: Duration = .milliseconds(50)
    private nonisolated static let deferredRuntimeServicesDelay: Duration = .milliseconds(250)

    private struct InstantRecallSeed: Sendable {
        let id: String
        let inlineBody: String
        let liveBody: String?
    }

    private func recordPersistenceIssue(
        _ message: String,
        error: Error
    ) {
        Log.persistence.error(
            "\(message, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        RuntimeDiagnostics.record(
            .error,
            category: "Persistence",
            message: message,
            metadata: ["error": error.localizedDescription]
        )
    }

    // MARK: - Services
    let llmService: LLMService
    let localInferenceService: MLXInferenceService
    let localMLXClient: LocalMLXClient
    let preparedModelRegistryState: PreparedModelRegistryState
    let preparedModelRegistry: PreparedModelRegistry
    let localLLMClient: LocalMLXClient
    let cloudLLMClient: CloudLLMClient
    let triageService: TriageService
    let vaultSync: VaultSyncService
    let noteInsightService: NoteInsightService

    // MARK: - Coordinators
    private var _coordinator: AppCoordinator?
    var coordinator: AppCoordinator { Self.requireInitialized(_coordinator, name: "coordinator") }

    init() {
        let interval = Log.appPerf.beginInterval("bootstrapInit")
        defer { Log.appPerf.endInterval("bootstrapInit", interval) }

        // Register custom fonts (RetroGaming, etc.)
        EpistemosFont.registerFonts()

        // Create model container with implicit lightweight migration.
        // SwiftData auto-handles adding defaulted properties without an explicit MigrationPlan.
        // Falls back to in-memory container on failure (corrupt DB, schema mismatch).
        let schema = Schema(EpistemosSchema.models)
        let container: ModelContainer
        let dbError: Error?
        let usesInMemoryModelStore = Self.isRunningTests
        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: usesInMemoryModelStore)
            )
            dbError = nil
        } catch {
            Log.persistence.error(
                "Database failed to load, falling back to in-memory: \(error.localizedDescription, privacy: .public)"
            )
            RuntimeDiagnostics.record(
                .fault,
                category: "Persistence",
                message: "Database failed to load, falling back to in-memory",
                metadata: ["error": error.localizedDescription]
            )
            container = Self.makeFallbackModelContainer(schema: schema)
            dbError = error
        }
        self.modelContainer = container
        self.databaseError = dbError

        // InferenceState reads Keychain + checks Apple Intelligence availability
        let inference = InferenceState()
        self.inferenceState = inference
        let localModelManager = LocalModelManager(
            inference: inference,
            installer: ModelDownloadManager()
        )
        self.localModelManager = localModelManager
        let localModelRefreshThrottle = LocalModelRefreshThrottle(
            manager: localModelManager,
            interval: 2
        )
        self.localModelRefreshThrottle = localModelRefreshThrottle

        let localInferenceService = MLXInferenceService(snapshot: inference.hardwareCapabilitySnapshot)
        self.localInferenceService = localInferenceService

        let preparedModelRegistryState = PreparedModelRegistryState()
        self.preparedModelRegistryState = preparedModelRegistryState

        let preparedModelRegistry = PreparedModelRegistry()
        self.preparedModelRegistry = preparedModelRegistry
        do {
            let snapshot = try preparedModelRegistry.load()
            preparedModelRegistryState.apply(snapshot)
            graphState.applyPreparedRetrievalRuntimeConfiguration(snapshot.retrievalRuntimeConfiguration)
        } catch {
            preparedModelRegistryState.apply(error: error)
            graphState.applyPreparedRetrievalRuntimeConfiguration(nil)
        }

        let localMLXClient = LocalMLXClient(
            runtime: localInferenceService,
            inference: inference,
            paths: localModelManager.paths,
            prepareForRequest: {
                localModelRefreshThrottle.refreshIfNeeded()
            }
        )
        self.localMLXClient = localMLXClient
        self.localLLMClient = localMLXClient
        let cloudLLMClient = CloudLLMClient(inference: inference)
        self.cloudLLMClient = cloudLLMClient

        // LLMService is now the shared local-only gateway used by older subsystems.
        let llm = LLMService(
            inference: inference,
            localLLMClient: localLLMClient,
            cloudLLMClient: cloudLLMClient
        )
        self.llmService = llm
        let adminVM = HermesAdminViewModel(hermesManager: hermesManager)
        self.hermesAdminViewModel = adminVM
        let agentVM = AgentViewModel(
            hermesManager: hermesManager,
            inferenceState: inference,
            localLLMClient: localLLMClient
        )
        agentVM.adminViewModel = adminVM
        self.agentViewModel = agentVM

        // Pre-warm the Hermes subprocess only if first-launch setup is complete.
        // If setup hasn't run yet, the Python venv likely doesn't exist and
        // pre-warm would fail silently. SetupAssistantView handles installation.
        let setupComplete = UserDefaults.standard.bool(forKey: "epistemos.setupComplete")
        if setupComplete && !PowerGuard.shared.shouldDisableBackground {
            Task.detached(priority: .utility) { [hermesManager] in
                await hermesManager.preWarm()
            }
        }

        // Start centralized power authority — must be before any subsystem that
        // checks PowerGuard.shared.currentMode during init.
        PowerGuard.shared.start()

        // Start main thread watchdog to detect UI hangs (skipped in eco/lowPower).
        if !PowerGuard.shared.shouldDisableBackground {
            MainThreadWatchdog.install()
        }

        // Start centralized thermal authority before any inference work.
        Task { await ThermalGuard.shared.start() }

        // Register supervised children and start OTP-style supervisor.
        // Order matters — rest_for_one cancels children after the failed index.
        supervisor.register(ChildSpec(
            id: "hermesSubprocess",
            policy: .permanent,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable [hermesManager] in
                // Long-running: block until Hermes exits or is cancelled.
                // runSupervised() is @MainActor-isolated, await handles the hop.
                try await hermesManager.runSupervised()
            }
        ))
        supervisor.start()

        // TriageService routes between Apple Intelligence and local Qwen.
        let triage = TriageService(
            inference: inference,
            localLLMService: localLLMClient,
            cloudLLMService: cloudLLMClient,
            prepareForRouting: {
                localModelRefreshThrottle.refreshIfNeeded()
            }
        )
        self.triageService = triage

        // VaultSyncService — hybrid persistence bridge
        self.vaultSync = VaultSyncService(modelContainer: container)

        // NoteInsightService — on-device ML analysis for all notes
        self.noteInsightService = NoteInsightService(modelContainer: container)

        // PipelineService — direct local answer streaming
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llm,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        // Wire event bus to chat state
        chatState.eventBus = eventBus

        // Create coordinators
        let chatCoordinator = ChatCoordinator(
            bootstrap: self,
            chatState: chatState,
            inferenceState: inference,
            vaultSync: vaultSync,
            modelContainer: container,
            eventBus: eventBus,
            llmService: llm,
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
        self._coordinator = appCoordinator

        // Wire stop button → cancel active pipeline query
        chatState.onStopRequested = { [weak self] in
            self?.coordinator.cancelActiveQuery()
        }

        // Set shared before wiring so that any callbacks can access it.
        AppBootstrap.shared = self

        self._workspaceService = WorkspaceService(modelContainer: container)
        self._workspaceSummaryService = WorkspaceSummaryService(
            triageService: triage, activityTracker: activityTracker, modelContainer: container
        )

        // Initialize reasoning loop (STaR + autoresearch flywheel)
        // Opt-in via Settings → Omega. Do NOT force-enable at startup.
        let reasoning = ReasoningLoopService(triageService: triage)
        reasoning.config.enabled = UserDefaults.standard.bool(forKey: "omega.enableReasoningLoop")
        reasoning.onTracesGenerated = { jsonlLines in
            KnowledgeFusionViewModel.shared.ingestReasoningTraces(jsonlLines)
        }
        self._reasoningLoopService = reasoning

        // Configure Knowledge Fusion at boot so the inference bridge is ready.
        // State loading is deferred until after the primary launch path settles.
        KnowledgeFusionViewModel.shared.configure(triageService: triage)

        // Initialize dual-brain infrastructure
        self._deviceAgent = DeviceAgentService(hardwareTier: hardwareTierManager)
        self._dualBrainRouter = DualBrainRouter(
            hardwareTier: hardwareTierManager,
            deviceAgent: deviceAgent
        )
        // Wire Brain 2 to shared GPU backend (until dedicated ANE model is available post-Ω15)
        deviceAgent.setBackend(
            SharedGPUBackend(
                triageService: triage,
                localModelClient: localMLXClient,
                constrainedDecoding: constrainedDecoding,
                activeModelID: { [weak inference] in
                    inference?.activeLocalTextModelID
                }
            )
        )

        // Initialize computer use stack (Ω13)
        let screenCapture = ScreenCaptureService()
        self._screen2AXFusion = Screen2AXFusion(screenCapture: screenCapture)
        self._visualVerifyLoop = VisualVerifyLoop(screenCapture: screenCapture, deviceAgent: deviceAgent)

        // Initialize the persistent event store (separate SQLite database with WAL mode).
        EventStore.shared = EventStore()
        self._timeMachineService = TimeMachineService(modelContainer: container)
        self.workspaceService.timeMachineService = timeMachineService

        // Initialize cognitive substrates (Phase 0)
        // Services hold a reference to config and read it LIVE at each decision point.
        self._ambientCapture = AmbientCaptureService(config: epistemosConfig, screen2AXFusion: screen2AXFusion)
        self._frictionMonitor = FrictionMonitorService(config: epistemosConfig)
        FrictionMonitorService.shared = frictionMonitor
        self._nightBrain = NightBrainService(
            config: epistemosConfig,
            searchIndexProvider: { @MainActor [weak vaultSync] in
                vaultSync?.searchService
            },
            graphMemoryProvider: { @MainActor [weak self] in
                self?._agentGraphMemory
            }
        )
        self._agentHeartbeat = AgentHeartbeatService(
            config: epistemosConfig,
            hermesManagerProvider: { @MainActor [weak self] in
                self?.hermesManager
            },
            costTrackerProvider: { @MainActor [weak self] in
                self?.agentViewModel.costTracker
            }
        )

        if !Self.isRunningTests {
            wireLocalRuntimeLifecycle()
        }

        // Wire all events (pipeline, toast, vault, daily brief)
        appCoordinator.wireAll()

        // Evict old disk style cache entries in background (filesystem I/O).
        Task(priority: .utility) { DiskStyleCache.shared.evictIfNeeded() }

        // Give VaultSyncService access to EventBus for change notifications
        vaultSync.setEventBus(eventBus)

        // Register Omega specialist agents and wire LLM planning
        orchestratorState.registerAgents(
            vaultURL: vaultSync.vaultURL,
            modelContainer: container,
            triageService: triage,
            vaultSync: vaultSync,
            mcpBridge: mcpBridge,
            constrainedDecoding: constrainedDecoding,
            screenCapture: screenCapture,
            perception: screen2AXFusion
        )

        // Wire constrained decoding generator (Ω11)
        // Note: Current JSONSchemaLogitProcessor only applies soft EOS penalties,
        // NOT real grammar masking. ConstrainedDecodingService.isAvailable will
        // remain false until a fully constraining generator is registered.
        constrainedDecoding.setGenerator(MLXConstrainedGenerator(inferenceService: localInferenceService))
        if !constrainedDecoding.isAvailable {
            Log.app.info("AppBootstrap: constrained decoding registered but not available (soft guidance only)")
        }

        // Initialize knowledge graph integration (Ω14)
        self._agentGraphMemory = AgentGraphMemory(graphStore: graphState.store, graphState: graphState)
        self._recipeGraphSkills = RecipeGraphSkills(graphStore: graphState.store, mcpBridge: mcpBridge)
        self._ghostBrainCoauthor = GhostBrainCoauthor(graphStore: graphState.store, agentMemory: agentGraphMemory)
        orchestratorState.agentGraphMemory = agentGraphMemory
        agentViewModel.agentGraphMemory = agentGraphMemory

        let startupBookmarkValidation = vaultSync.startupBookmarkValidation()

        // Initialize instant recall vector index (Ω18)
        instantRecallService.initialize()
        if Self.shouldScheduleInitialInstantRecallSeed(
            vaultBookmarkValidation: startupBookmarkValidation
        ) {
            scheduleInitialInstantRecallRebuild()
        }

        // Body-file migration runs off-main to avoid launch hitching.
        // Orphan cleanup now waits for a confirmed healthy vault attach/import.
        Task(priority: .utility) {
            await migrateBodiesToFileStorage()
        }

        // Graph loads asynchronously — no launch stall. QueryEngine holds a reference
        // to GraphStore (a class), so it sees data as soon as the background load populates it.
        // HologramController.ensureOverlay() has a sync fallback if the graph is opened
        // before this Task completes.
        graphState.modelContext = container.mainContext
        if Self.shouldScheduleInitialGraphLoad(
            vaultBookmarkValidation: startupBookmarkValidation
        ) {
            Task(priority: .utility) { await graphState.loadGraph(container: container) }
        }

        // Pre-warm Metal shader cache.
        // The Rust engine compiles Metal shaders from source during graph_engine_create(),
        // which blocks for 300-800ms on first invocation. Creating a throwaway engine at
        // launch warms the Metal shader cache so the real engine creation in
        // MetalGraphNSView.setupMetal() hits the cache and completes in <5ms.
        //
        // CAMetalLayer must be created on the main thread (Core Animation requirement),
        // so we create the layer here and hand it to a background task for engine creation.
        // The engine creation (shader compilation + pipeline state) runs off-main.
        let warmupLayer = CAMetalLayer()
        warmupLayer.pixelFormat = .bgra8Unorm
        Task.detached(priority: .userInitiated) { [warmupLayer] in
            guard let device = MTLCreateSystemDefaultDevice() else { return }

            // Serialize shader compilation through a file lock to prevent flock
            // contention (errno 35) on Metal's shared shader cache. This avoids
            // races between the warmup engine and any concurrent Metal clients,
            // including zombie processes from previous crashed instances.
            let lockURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("com.epistemos.shader-warmup.lock")
            let lockFd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
            if lockFd >= 0 {
                flock(lockFd, LOCK_EX)
            }
            defer {
                if lockFd >= 0 {
                    flock(lockFd, LOCK_UN)
                    close(lockFd)
                }
            }

            warmupLayer.device = device
            let devicePtr = Unmanaged.passUnretained(device).toOpaque()
            let layerPtr = Unmanaged.passUnretained(warmupLayer).toOpaque()
            let warmupEngine = graph_engine_create(devicePtr, layerPtr)
            if let warmupEngine {
                graph_engine_destroy(warmupEngine)
            }
        }

        // Configure query engine with live dependencies (used by graph sidebar search).
        // The search index resolves lazily on first query so launch does not pay
        // the FTS/database setup cost unless the user actually opens search.
        queryEngine.configure(
            graphStore: graphState.store,
            graphState: graphState,
            searchIndexProvider: { [vaultSync] in
                vaultSync.searchService ?? (try? SearchIndexService())
            },
            preparedRetrievalRuntimeConfiguration: preparedModelRegistryState.retrievalRuntimeConfiguration
        )

        // Initialize Paperclip high-frequency state store (SQLite WAL mode)
        do {
            self._paperclipStore = try PaperclipStateStore()
        } catch {
            Log.app.error("PaperclipStateStore init failed: \(error.localizedDescription)")
        }

        // Tell Siri to re-index App Intents on every launch
        EpistemosShortcutsProvider.updateAppShortcutParameters()
        Log.app.info("AppBootstrap: initialized — local AI stack ready")
    }

    nonisolated static func startupIntegritySamplePageIdsForTesting(_ pageIds: [String]) -> [String] {
        let normalized = Array(Set(pageIds.filter { NoteFileStorage.isValidPageId($0) })).sorted()
        guard !normalized.isEmpty else { return [] }

        let sampleSize = min(normalized.count, max(1, normalized.count / 10))
        guard sampleSize < normalized.count else { return normalized }

        let lastIndex = normalized.count - 1
        let strideDivisor = max(1, sampleSize - 1)
        let sampled = (0..<sampleSize).map { sampleIndex in
            let position = Int(round(Double(sampleIndex * lastIndex) / Double(strideDivisor)))
            return normalized[position]
        }
        return Array(NSOrderedSet(array: sampled)) as? [String] ?? sampled
    }

    nonisolated static func startupIntegrityReportForTesting(
        samplePageIds: [String],
        readBodyData: (String) -> Data?,
        eventStoreAvailable: Bool,
        vaultBookmarkValidation: VaultBookmarkStartupValidation = VaultBookmarkStartupValidation(
            bookmarkExists: false,
            isReadyForAutomaticRestore: true,
            failureReason: nil
        ),
        pageSnapshots: [StartupIntegrityPageSnapshot] = [],
        bodyFileExists: (String) -> Bool = { _ in false },
        filePathReadable: (String) -> Bool = { _ in false }
    ) -> StartupIntegrityReport {
        let corruptedPageIds = samplePageIds.filter { readBodyData($0) == nil }
        let unrecoverablePageIds = startupUnrecoverablePageIdsForTesting(
            pageSnapshots,
            bodyFileExists: bodyFileExists,
            filePathReadable: filePathReadable
        )
        return StartupIntegrityReport(
            sampledPageIds: samplePageIds,
            corruptedPageIds: corruptedPageIds,
            unrecoverablePageIds: unrecoverablePageIds,
            eventStoreAvailable: eventStoreAvailable,
            vaultBookmarkExists: vaultBookmarkValidation.bookmarkExists,
            vaultBookmarkReadyForAutomaticRestore: vaultBookmarkValidation.isReadyForAutomaticRestore,
            vaultBookmarkFailureReason: vaultBookmarkValidation.failureReason
        )
    }

    nonisolated static func startupUnrecoverablePageIdsForTesting(
        _ pageSnapshots: [StartupIntegrityPageSnapshot],
        bodyFileExists: (String) -> Bool,
        filePathReadable: (String) -> Bool
    ) -> [String] {
        pageSnapshots.compactMap { page in
            let hasManagedBody = bodyFileExists(page.id)
            let hasReadableVaultSource = page.filePath.map { filePath in
                let trimmedPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedPath.isEmpty else { return false }
                return filePathReadable(trimmedPath)
            } ?? false
            guard !hasManagedBody,
                  !hasReadableVaultSource,
                  !page.hasInlineBody,
                  page.hasMeaningfulMetadata else {
                return nil
            }
            return page.id
        }
        .sorted()
    }

    nonisolated static func startupIntegrityToastForTesting(
        report: StartupIntegrityReport
    ) -> StartupIntegrityToast? {
        var segments: [String] = []
        var type: ToastType = .warning

        if !report.eventStoreAvailable {
            segments.append("session store is unavailable.")
            type = .error
        }

        if let vaultBookmarkFailureReason = report.vaultBookmarkFailureReason {
            segments.append("\(vaultBookmarkFailureReason) Automatic vault restore was paused.")
            type = .error
        }

        let corruptedCount = report.corruptedPageIds.count
        if corruptedCount > 0 {
            let noun = corruptedCount == 1 ? "note body" : "note bodies"
            segments.append(
                "quarantined \(corruptedCount) corrupted \(noun). Automatic vault restore was paused."
            )
            type = .error
        }

        let unrecoverableCount = report.unrecoverablePageIds.count
        if unrecoverableCount > 0 {
            let noun = unrecoverableCount == 1 ? "note" : "notes"
            segments.append(
                "found \(unrecoverableCount) \(noun) with no body file or vault source. Review them before editing."
            )
        }

        guard !segments.isEmpty else { return nil }
        return StartupIntegrityToast(
            message: "Startup integrity warning: \(segments.joined(separator: " "))",
            type: type
        )
    }

    private func startupIntegrityPageSnapshots() -> [StartupIntegrityPageSnapshot] {
        let context = modelContainer.mainContext
        guard let pages = try? context.fetch(FetchDescriptor<SDPage>()) else {
            return []
        }

        return pages
            .filter { !$0.isTemplate }
            .map { page in
                let titleHasContent = !page.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let summaryHasContent = !page.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasFrontMatter = !(page.frontMatterData?.isEmpty ?? true)
                let hasMeaningfulMetadata =
                    titleHasContent
                    || summaryHasContent
                    || !page.tags.isEmpty
                    || hasFrontMatter
                    || !page.blockReferences.isEmpty
                    || page.needsVaultSync
                    || page.updatedAt.timeIntervalSince(page.createdAt) > 1

                return StartupIntegrityPageSnapshot(
                    id: page.id,
                    filePath: page.filePath,
                    hasInlineBody: !page.body.isEmpty,
                    hasMeaningfulMetadata: hasMeaningfulMetadata
                )
            }
    }

    private nonisolated static func shouldDeferLaunchVaultPreloads(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        vaultBookmarkValidation.bookmarkExists && vaultBookmarkValidation.isReadyForAutomaticRestore
    }

    private nonisolated static func shouldScheduleInitialInstantRecallSeed(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        !shouldDeferLaunchVaultPreloads(vaultBookmarkValidation: vaultBookmarkValidation)
    }

    private nonisolated static func shouldScheduleInitialGraphLoad(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        !shouldDeferLaunchVaultPreloads(vaultBookmarkValidation: vaultBookmarkValidation)
    }

    private nonisolated static func shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestore(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldDeferLaunchVaultPreloads(vaultBookmarkValidation: vaultBookmarkValidation)
    }

    nonisolated static func shouldScheduleInitialInstantRecallSeedForTesting(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldScheduleInitialInstantRecallSeed(vaultBookmarkValidation: vaultBookmarkValidation)
    }

    nonisolated static func shouldScheduleInitialGraphLoadForTesting(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldScheduleInitialGraphLoad(vaultBookmarkValidation: vaultBookmarkValidation)
    }

    nonisolated static func shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestoreForTesting(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestore(
            vaultBookmarkValidation: vaultBookmarkValidation
        )
    }

    func performStartupIntegrityCheck() async -> StartupIntegrityReport {
        if let startupIntegrityReport {
            return startupIntegrityReport
        }

        let eventStoreAvailable = EventStore.shared != nil
        let vaultBookmarkValidation = vaultSync.startupBookmarkValidation()
        let pageSnapshots = startupIntegrityPageSnapshots()
        let report = await Task.detached(priority: .utility) {
            Self.startupIntegrityReportForTesting(
                samplePageIds: Self.startupIntegritySamplePageIdsForTesting(
                    NoteFileStorage.managedBodyPageIds()
                ),
                readBodyData: { pageId in
                    NoteFileStorage.readBodyData(pageId: pageId, fast: false)
                },
                eventStoreAvailable: eventStoreAvailable,
                vaultBookmarkValidation: vaultBookmarkValidation,
                pageSnapshots: pageSnapshots,
                bodyFileExists: { pageId in
                    NoteFileStorage.bodyExists(pageId: pageId)
                },
                filePathReadable: { filePath in
                    FileManager.default.isReadableFile(atPath: filePath)
                }
            )
        }.value

        startupIntegrityReport = report

        if !report.unrecoverablePageIds.isEmpty {
            Log.persistence.warning(
                "Startup integrity warning: \(report.unrecoverablePageIds.count, privacy: .public) notes have no managed body or readable vault source"
            )
        }

        if let toast = Self.startupIntegrityToastForTesting(report: report) {
            uiState.showToast(toast.message, type: toast.type)
        }

        return report
    }

    func performPrimaryLaunchInitialization() async {
        guard !didStartPrimaryLaunchInitialization else { return }
        didStartPrimaryLaunchInitialization = true

        workspaceService.autoRestore()
        activityTracker.startTracking()
        workspaceSummaryService.startAutoSummaryLoop()
        workspaceService.startAutoSave()
        didCompletePrimaryLaunchInitialization = true

        if workspaceService.welcomeBack != nil {
            Task { @MainActor [weak self] in
                await self?.refreshWelcomeBackSummary()
            }
        }

        startDeferredRuntimeServicesIfNeeded()
    }

    func runAutomaticVaultRestoreAfterLaunchIfNeeded() async {
        let vaultBookmarkValidation = vaultSync.startupBookmarkValidation()
        let report = await performStartupIntegrityCheck()
        guard !report.shouldBlockAutomaticVaultRestore else {
            if vaultBookmarkValidation.bookmarkExists {
                vaultSync.clearPendingStartupRestore()
            }
            return
        }

        await waitForPrimaryLaunchInitializationIfNeeded(
            vaultBookmarkValidation: vaultBookmarkValidation
        )
        await vaultSync.restoreVaultFromBookmark()
    }

    private func refreshWelcomeBackSummary() async {
        await workspaceSummaryService.generateSummaryNow()
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        if let ws = try? modelContainer.mainContext.fetch(
            FetchDescriptor(predicate: predicate)
        ).first, !ws.summary.isEmpty {
            workspaceService.welcomeBack?.intentSummary = ws.summary
        }
    }

    private func waitForPrimaryLaunchInitializationIfNeeded(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) async {
        guard Self.shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestore(
            vaultBookmarkValidation: vaultBookmarkValidation
        ) else { return }

        let clock = ContinuousClock()
        let deadline = clock.now + Self.primaryLaunchInitializationWaitTimeout

        while !didCompletePrimaryLaunchInitialization && clock.now < deadline {
            try? await Task.sleep(for: Self.primaryLaunchInitializationPollInterval)
        }
    }

    private func startDeferredRuntimeServicesIfNeeded() {
        guard !Self.isRunningTests else { return }
        guard !didStartDeferredRuntimeServices else { return }
        didStartDeferredRuntimeServices = true

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.deferredRuntimeServicesDelay)
            guard let self else { return }

            await self.nightBrain.start()
            await self.agentHeartbeat.start()
            await KnowledgeFusionViewModel.shared.loadState()

            if self.epistemosConfig.captureEnabled {
                await self.ambientCapture.start()
            }
        }
    }

    // MARK: - Forwarding (for external callers that reference AppBootstrap directly)

    func refreshAmbientManifest() { coordinator.refreshAmbientManifest() }
    func loadChat(chatId: String) { coordinator.loadChat(chatId: chatId) }
    func requestVaultBriefing(chatState: ChatState) { coordinator.requestVaultBriefing(chatState: chatState) }
    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade { ChatCoordinator.gradeFromConfidence(confidence) }

    private static func makeFallbackModelContainer(schema: Schema) -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            preconditionFailure(
                "Failed to create in-memory model container fallback: \(error.localizedDescription)"
            )
        }
    }

    private func applyPreparedRetrievalRuntimeConfiguration(_ configuration: PreparedRetrievalRuntimeConfiguration?) {
        graphState.applyPreparedRetrievalRuntimeConfiguration(configuration)
        queryEngine.applyPreparedRetrievalRuntimeConfiguration(configuration)
    }

    private func refreshPreparedRetrievalRuntimeConfigurationIfNeeded() {
        do {
            let snapshot = try preparedModelRegistry.load()
            guard snapshot.manifestURL != preparedModelRegistryState.manifestURL
                || snapshot.entriesByKey != preparedModelRegistryState.entriesByKey else {
                return
            }
            preparedModelRegistryState.apply(snapshot)
            applyPreparedRetrievalRuntimeConfiguration(snapshot.retrievalRuntimeConfiguration)
        } catch {
            guard preparedModelRegistryState.lastErrorMessage != error.localizedDescription
                || !preparedModelRegistryState.entriesByKey.isEmpty else {
                return
            }
            preparedModelRegistryState.apply(error: error)
            applyPreparedRetrievalRuntimeConfiguration(nil)
        }
    }

    // MARK: - Database Recovery

    func resetDatabaseAndRelaunch() {
        guard !Self.isRunningTests else {
            Log.app.info("Skipping database reset relaunch under tests")
            return
        }

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
                recordPersistenceIssue("Failed to enumerate Epistemos directory during reset", error: error)
            }
        }
        Log.app.info("Database reset complete — relaunching")
        relaunchApp()
    }

    func applyDisplayModeAndRelaunch(_ mode: AppDisplayMode) {
        uiState.setDisplayMode(mode)
        clearVisualCaches()

        guard !Self.isRunningTests else {
            Log.app.info("Skipping display-mode relaunch under tests")
            return
        }

        Log.app.info("Display mode updated to \(mode.rawValue, privacy: .public) — relaunching")
        relaunchApp()
    }

    private func scheduleInitialInstantRecallRebuild() {
        guard !Self.isRunningTests else { return }

        let seeds = snapshotInstantRecallSeeds()
        Task.detached(priority: .utility) {
            let notes = seeds.map { seed -> (id: String, text: String) in
                let diskBody = NoteFileStorage.readBody(pageId: seed.id, mapped: true)
                let text = seed.liveBody ?? (diskBody.isEmpty ? seed.inlineBody : diskBody)
                return (id: seed.id, text: text)
            }

            await MainActor.run {
                AppBootstrap.shared?.instantRecallService.rebuildIndex(notes: notes)
            }
        }
    }

    private func snapshotInstantRecallSeeds() -> [InstantRecallSeed] {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
        )
        guard let pages = try? modelContainer.mainContext.fetch(descriptor) else { return [] }
        return pages.map {
            InstantRecallSeed(
                id: $0.id,
                inlineBody: $0.body,
                liveBody: NoteWindowManager.shared.editorBody(for: $0.id)
            )
        }
    }

    // MARK: - Full Reset

    func resetAllData() {
        queryTask?.cancel()
        queryTask = nil
        ambientManifest = nil
        vaultSync.ambientManifest = nil

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

        let defaults = UserDefaults.standard
        let keysToRemove = [
            ThemeMode.defaultsKey,
            "epistemos.theme.pair",
            "epistemos.localRoutingMode",
            "epistemos.preferredLocalTextModelID",
            "epistemos.preferredChatModelSelection",
        ]
        InferenceState.purgeLegacyRemoteConfiguration(defaults: defaults)
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        chatState.clearMessages()
        notesUI.resetForVaultSwitch()
        pipelineState.reset()

        inferenceState.setRoutingMode(.auto)
        inferenceState.setPreferredLocalTextModelID(
            inferenceState.hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue
        )
        inferenceState.setPreferredChatModelSelection(
            .localQwen(inferenceState.hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue)
        )

        vaultSync.stopWatching()

        uiState.setActivePanel(.home)
        uiState.needsSetup = true

        Log.pipeline.info("Reset: All data cleared. Setup screen shown.")
    }

    private func clearVisualCaches() {
        DiskStyleCache.shared.clearAll()
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: - Body File Storage Migration

    private func migrateBodiesToFileStorage() async {
        let migrationKey = "v2_body_migration_complete"
        let blockMigrationKey = "v2_block_ref_migration_complete"
        let interval = Log.appPerf.beginInterval("migrateBodiesToFileStorage")
        defer { Log.appPerf.endInterval("migrateBodiesToFileStorage", interval) }

        let actor = BodyMigrationActor(modelContainer: modelContainer)

        // 1. Body migration
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            do {
                let migrated = try await actor.migrateInlineBodiesToFiles()
                UserDefaults.standard.set(true, forKey: migrationKey)
                if migrated > 0 {
                    Log.persistence.info("Body file storage migration moved \(migrated) bodies to disk")
                }
            } catch {
                recordPersistenceIssue("Body migration failed", error: error)
            }
        }

        // 2. Block reference migration (for graph performance)
        if !UserDefaults.standard.bool(forKey: blockMigrationKey) {
            do {
                let migrated = try await actor.migrateBlockReferences()
                UserDefaults.standard.set(true, forKey: blockMigrationKey)
                if migrated > 0 {
                    Log.persistence.info("Block reference migration cached \(migrated) pages")
                }
            } catch {
                recordPersistenceIssue("Block reference migration failed", error: error)
            }
        }
    }

    private func cleanupOrphanBodyFiles() async {
        do {
            let removed = try await BodyMigrationActor(modelContainer: modelContainer).cleanupOrphanBodies()
            if removed > 0 {
                Log.persistence.info("Body file cleanup removed \(removed) orphan note bodies")
            }
        } catch {
            recordPersistenceIssue("Body file cleanup failed", error: error)
        }
    }

    func scheduleHealthyVaultBodyCleanup() {
        guard !Self.isRunningTests else { return }
        healthyVaultBodyCleanupTask?.cancel()
        healthyVaultBodyCleanupTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            guard await vaultSync.shouldRunBodyCleanup(candidateVaultURL: vaultSync.vaultURL) else {
                Log.app.info("Body file cleanup skipped until vault health is confirmed")
                return
            }
            await cleanupOrphanBodyFiles()
        }
    }

    private func wireLocalRuntimeLifecycle() {
        let center = NotificationCenter.default
        localRuntimeObserverTokens = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshPreparedRetrievalRuntimeConfigurationIfNeeded()
                    self?.syncLocalRuntimeConditions(appActive: true)
                }
            },
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.syncLocalRuntimeConditions(appActive: false)
                }
            },
            center.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.syncLocalRuntimeConditions(appActive: nil)
                }
            },
            center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.syncLocalRuntimeConditions(appActive: nil)
                }
            },
        ]
        syncLocalRuntimeConditions(appActive: NSApp?.isActive ?? true)
    }

    private func syncLocalRuntimeConditions(appActive: Bool?) {
        let conditions = LocalRuntimeConditions.current(
            appActive: appActive ?? (NSApp?.isActive ?? true)
        )
        inferenceState.setLocalRuntimeConditions(conditions)
        Task(priority: .utility) { [localInferenceService] in
            await localInferenceService.updateRuntimeConditions(conditions)
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

    func migrateBlockReferences() throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        var migrated = 0
        let pattern = /\(\(([^)]+)\)\)/

        for page in pages where page.blockReferences.isEmpty {
            let body = page.loadBody(mapped: true)
            guard !body.isEmpty else { continue }
            let matches = body.matches(of: pattern)
            let refs = matches.compactMap { match -> String? in
                let refId = String(match.1).trimmingCharacters(in: .whitespaces)
                return refId.isEmpty ? nil : refId
            }
            if !refs.isEmpty {
                page.blockReferences = refs
                migrated += 1
            }
        }
        if migrated > 0 {
            try modelContext.save()
        }
        return migrated
    }

    func cleanupOrphanBodies() throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        return NoteFileStorage.cleanupOrphanBodies(validPageIds: pages.map(\.id)).count
    }
}
