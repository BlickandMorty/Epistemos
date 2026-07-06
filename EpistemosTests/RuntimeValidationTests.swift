import AppKit
import Foundation
import SQLite3
import Testing
@testable import Epistemos

private func loadRepoTextFileWithRetry(
    relativePath: String,
    testsFilePath: String,
    attempts: Int = 5
) throws -> String {
    _ = testsFilePath
    _ = attempts
    return try loadMirroredSourceTextFile(relativePath)
}

private func createSQLiteDatabase(
    at url: URL,
    statements: [String]
) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    var db: OpaquePointer?
    guard sqlite3_open_v2(
        url.path,
        &db,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
        nil
    ) == SQLITE_OK, let db else {
        throw NSError(
            domain: "RuntimeValidationTests.SQLiteCreate",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to open SQLite database at \(url.path)"]
        )
    }
    defer { sqlite3_close(db) }

    for statement in statements {
        guard sqlite3_exec(db, statement, nil, nil, nil) == SQLITE_OK else {
            throw NSError(
                domain: "RuntimeValidationTests.SQLiteExec",
                code: Int(sqlite3_errcode(db)),
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))]
            )
        }
    }
}

private func sqliteColumnNames(
    in tableName: String,
    databaseURL: URL
) throws -> Set<String> {
    var db: OpaquePointer?
    guard sqlite3_open_v2(
        databaseURL.path,
        &db,
        SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
        nil
    ) == SQLITE_OK, let db else {
        throw NSError(
            domain: "RuntimeValidationTests.SQLiteOpen",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to open SQLite database at \(databaseURL.path)"]
        )
    }
    defer { sqlite3_close(db) }

    var statement: OpaquePointer?
    let query = "PRAGMA table_info(\(tableName));"
    guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
        throw NSError(
            domain: "RuntimeValidationTests.SQLitePrepare",
            code: Int(sqlite3_errcode(db)),
            userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))]
        )
    }
    defer { sqlite3_finalize(statement) }

    var columns = Set<String>()
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let name = sqlite3_column_text(statement, 1) else { continue }
        columns.insert(String(cString: name))
    }
    return columns
}

@Suite("Runtime Validation")
struct RuntimeValidationTests {
    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func repoFileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: repoRootURL.appendingPathComponent(relativePath).path
        )
    }

    private let inferenceDefaultsKeys = [
        "epistemos.localRoutingMode",
        "epistemos.chatAutoRouteToCloud",
        "epistemos.preferredLocalTextModelID",
        "epistemos.preferredChatModelSelection",
        "epistemos.activeAIProvider",
        "epistemos.lastNonLocalAIProvider",
        "epistemos.openAIWebSearchEnabled",
        "epistemos.openAICodeInterpreterEnabled",
        "epistemos.anthropicExtendedThinkingEnabled",
        "epistemos.anthropicWebSearchEnabled",
        "epistemos.anthropicWebFetchEnabled",
        "epistemos.anthropicCodeExecutionEnabled",
        "epistemos.googleGroundingEnabled",
        "epistemos.cloudSetupHintShown",
        "epistemos.preferredCloudModel.openAI",
        "epistemos.preferredCloudModel.anthropic",
        "epistemos.preferredCloudModel.google",
        "epistemos.preferredCloudModel.zai",
        "epistemos.preferredCloudModel.kimi",
        "epistemos.preferredCloudModel.minimax",
        "epistemos.preferredCloudModel.deepseek",
    ]

    @MainActor
    private func withResetInferenceDefaults(
        _ body: () async throws -> Void
    ) async rethrows {
        let defaults = UserDefaults.standard
        let savedValues = inferenceDefaultsKeys.reduce(into: [String: Any?]()) { partialResult, key in
            partialResult[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in inferenceDefaultsKeys {
                if let value = savedValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try await body()
    }

    @Test("bootstrap adopts legacy root stores into the app-scoped path and repairs message columns")
    func bootstrapAdoptsLegacyRootStoresIntoAppScopedPathAndRepairsMessageColumns() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppBootstrapStoreRepair-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let legacyStoreURL = AppBootstrap.legacyRootModelStoreURL(applicationSupportDirectory: root)
        try createSQLiteDatabase(
            at: legacyStoreURL,
            statements: [
                """
                CREATE TABLE ZSDMESSAGE (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZID VARCHAR
                );
                """,
                "INSERT INTO ZSDMESSAGE (Z_PK, Z_ENT, Z_OPT, ZID) VALUES (1, 1, 1, 'legacy-message');",
                """
                CREATE TABLE ZSDPAGE (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZID VARCHAR,
                    ZTITLE VARCHAR,
                    ZTAGS BLOB
                );
                """,
                "INSERT INTO ZSDPAGE (Z_PK, Z_ENT, Z_OPT, ZID, ZTITLE, ZTAGS) VALUES (1, 1, 1, 'legacy-page', 'Legacy Page', X'00');",
            ]
        )

        let destinationStoreURL = try AppBootstrap.preparePersistentModelStoreIfNeeded(
            applicationSupportDirectory: root,
            fileManager: .default
        )
        let backupStoreURL = destinationStoreURL
            .deletingLastPathComponent()
            .appendingPathComponent("default.store.pre-column-repair.backup")

        #expect(destinationStoreURL == AppBootstrap.persistentModelStoreURL(applicationSupportDirectory: root))
        #expect(destinationStoreURL.path == root.appendingPathComponent("Epistemos/default.store").path)
        #expect(FileManager.default.fileExists(atPath: destinationStoreURL.path))
        #expect(FileManager.default.fileExists(atPath: backupStoreURL.path))

        let columns = try sqliteColumnNames(in: "ZSDMESSAGE", databaseURL: destinationStoreURL)
        #expect(columns.contains("ZTHINKINGTRACE"))
        #expect(columns.contains("ZTHINKINGDURATIONSECONDS"))

        let pageColumns = try sqliteColumnNames(in: "ZSDPAGE", databaseURL: destinationStoreURL)
        #expect(pageColumns.contains("ZWIKILINKREFERENCES"))
        #expect(pageColumns.contains("ZWIKILINKREFERENCESCANSIGNATURE"))

        let backupPageColumns = try sqliteColumnNames(in: "ZSDPAGE", databaseURL: backupStoreURL)
        #expect(!backupPageColumns.contains("ZWIKILINKREFERENCES"))
        #expect(!backupPageColumns.contains("ZWIKILINKREFERENCESCANSIGNATURE"))
    }

    @Test("bootstrap replaces invalid pre-column backups before repairing page columns")
    func bootstrapReplacesInvalidPreColumnBackupsBeforeRepairingPageColumns() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppBootstrapInvalidBackupRepair-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storeURL = AppBootstrap.persistentModelStoreURL(applicationSupportDirectory: root)
        try createSQLiteDatabase(
            at: storeURL,
            statements: [
                """
                CREATE TABLE ZSDPAGE (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZID VARCHAR,
                    ZTITLE VARCHAR,
                    ZTAGS BLOB
                );
                """,
                "INSERT INTO ZSDPAGE (Z_PK, Z_ENT, Z_OPT, ZID, ZTITLE, ZTAGS) VALUES (1, 1, 1, 'legacy-page', 'Legacy Page', X'00');",
            ]
        )

        let backupStoreURL = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("default.store.pre-column-repair.backup")
        FileManager.default.createFile(atPath: backupStoreURL.path, contents: Data())

        let destinationStoreURL = try AppBootstrap.preparePersistentModelStoreIfNeeded(
            applicationSupportDirectory: root,
            fileManager: .default
        )

        #expect(destinationStoreURL == storeURL)
        #expect((try FileManager.default.attributesOfItem(atPath: backupStoreURL.path)[.size] as? NSNumber)?.intValue ?? 0 > 0)

        let pageColumns = try sqliteColumnNames(in: "ZSDPAGE", databaseURL: destinationStoreURL)
        #expect(pageColumns.contains("ZWIKILINKREFERENCES"))
        #expect(pageColumns.contains("ZWIKILINKREFERENCESCANSIGNATURE"))

        let backupPageColumns = try sqliteColumnNames(in: "ZSDPAGE", databaseURL: backupStoreURL)
        #expect(backupPageColumns.contains("ZTAGS"))
        #expect(!backupPageColumns.contains("ZWIKILINKREFERENCES"))
        #expect(!backupPageColumns.contains("ZWIKILINKREFERENCESCANSIGNATURE"))
    }

    @Test("bootstrap leaves a healthy app-scoped store alone when no legacy exists")
    func bootstrapLeavesHealthyAppScopedStoreAloneWithNoLegacy() throws {
        // The production-steady-state path: every launch AFTER the
        // legacy-root adoption is done. Destination exists and is
        // already in current-schema shape (all ZWIKILINK* + ZTHINKING*
        // columns present); there's no legacy root to adopt. The
        // function should be a no-op repair pass and return the
        // destination URL unchanged.
        //
        // No backup file should appear at the destination parent
        // because the schema is current — column-repair only creates
        // a backup when it has missing columns to ALTER in.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "AppBootstrapHealthyDestinationOnly-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let destinationURL = AppBootstrap.persistentModelStoreURL(
            applicationSupportDirectory: root
        )
        try createSQLiteDatabase(
            at: destinationURL,
            statements: [
                // All four legacy ZSDMESSAGE columns the repair pass
                // looks for (see AppBootstrap.legacyMessageColumns).
                // Missing any one would trigger a backup-and-ALTER pass
                // and make this test's no-backup assertion false.
                """
                CREATE TABLE ZSDMESSAGE (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZID VARCHAR,
                    ZTHINKINGTRACE TEXT,
                    ZTHINKINGDURATIONSECONDS DOUBLE,
                    ZAUTHOREDBYPROVIDERID TEXT,
                    ZAUTHOREDBYMODELID TEXT
                );
                """,
                """
                CREATE TABLE ZSDPAGE (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZID VARCHAR,
                    ZTITLE VARCHAR,
                    ZTAGS BLOB,
                    ZWIKILINKREFERENCES BLOB,
                    ZWIKILINKREFERENCESCANSIGNATURE VARCHAR
                );
                """,
            ]
        )

        let returned = try AppBootstrap.preparePersistentModelStoreIfNeeded(
            applicationSupportDirectory: root,
            fileManager: .default
        )

        #expect(returned == destinationURL)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))

        // No backup needed when there's nothing to repair — the
        // existence check protects against an over-eager backup that
        // would accumulate stale .pre-column-repair.backup files at
        // every healthy launch.
        let backupURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent("default.store.pre-column-repair.backup")
        #expect(!FileManager.default.fileExists(atPath: backupURL.path),
                "healthy store should not produce a pre-column-repair backup")
    }

    @Test("bootstrap repairs legacy root and app-scoped stores when both exist")
    func bootstrapRepairsLegacyRootAndAppScopedStoresWhenBothExist() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppBootstrapDualStoreRepair-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let legacyStoreURL = AppBootstrap.legacyRootModelStoreURL(applicationSupportDirectory: root)
        let appScopedStoreURL = AppBootstrap.persistentModelStoreURL(applicationSupportDirectory: root)

        for storeURL in [legacyStoreURL, appScopedStoreURL] {
            try createSQLiteDatabase(
                at: storeURL,
                statements: [
                    """
                    CREATE TABLE ZSDPAGE (
                        Z_PK INTEGER PRIMARY KEY,
                        Z_ENT INTEGER,
                        Z_OPT INTEGER,
                        ZID VARCHAR,
                        ZTITLE VARCHAR,
                        ZTAGS BLOB
                    );
                    """,
                    "INSERT INTO ZSDPAGE (Z_PK, Z_ENT, Z_OPT, ZID, ZTITLE, ZTAGS) VALUES (1, 1, 1, 'legacy-page', 'Legacy Page', X'00');",
                ]
            )
        }

        let destinationStoreURL = try AppBootstrap.preparePersistentModelStoreIfNeeded(
            applicationSupportDirectory: root,
            fileManager: .default
        )

        #expect(destinationStoreURL == appScopedStoreURL)
        for storeURL in [legacyStoreURL, appScopedStoreURL] {
            let pageColumns = try sqliteColumnNames(in: "ZSDPAGE", databaseURL: storeURL)
            #expect(pageColumns.contains("ZWIKILINKREFERENCES"))
            #expect(pageColumns.contains("ZWIKILINKREFERENCESCANSIGNATURE"))
        }
    }

    // Cloud-only migration: removed "inference keeps only local routing defaults"
    // (routingMode / preferredLocalTextModelID / recommendedLocalTextModelID deleted)
    // and "tool-capable local selections expose agent mode …" (LocalTextModelID +
    // setInstalled/PreparedLocalTextModelIDs deleted).

    @Test("inference migrates legacy secure cloud keys and selections forward")
    func inferenceMigratesLegacyCloudConfigurationForward() throws {
        let source = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let normalized = source.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        #expect(source.contains("migrateLegacyCloudAPIKeysIfNeeded()"))
        #expect(source.contains("func availableOperatingModes("))
        #expect(source.contains("for selection: ChatModelSelection"))
        #expect(source.contains("epistemos.apiKey.openai"))
        #expect(source.contains("epistemos.apiKey.anthropic"))
        #expect(source.contains("epistemos.apiKey.google"))
        #expect(source.contains("migrateLegacyCloudSelection(defaults: defaults)"))
        #expect(source.contains("\"gpt-5.3\": .openAIGPT54"))
        #expect(
            normalized.range(
                of: #""claude-sonnet-4-6": \.anthropicClaudeSonnet46"#,
                options: .regularExpression
            ) != nil
        )
        #expect(!source.contains("// \"claude-sonnet-4-6\": .anthropicClaudeSonnet4"))
        #expect(source.contains("\"gemini-1.5-pro\": .googleGemini31ProPreview"))
        #expect(source.contains("case zai"))
        #expect(source.contains("case kimi"))
        #expect(source.contains("case minimax"))
        #expect(source.contains("case deepseek"))
        #expect(source.contains("\"epistemos.preferredCloudModel.\\(provider.rawValue)\""))
    }

    @Test("chat model selector splits mode, model, and routing controls across toolbar buttons")
    func chatModelSelectorUsesSplitToolbarControls() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(rootView.contains("splitToolbarControls"))
        #expect(rootView.contains("modePopover"))
        #expect(rootView.contains("modelPopover"))
        #expect(rootView.contains("routingPopover"))
        #expect(rootView.contains("routeButtonTitle"))
        #expect(rootView.contains("temporaryChatButton"))
        #expect(rootView.contains("pickerCloudSection"))
        #expect(rootView.contains("routingSection"))
        #expect(rootView.contains("DisclosureGroup("))
        #expect(rootView.contains("inference.preferredCloudModel(for: provider)"))
    }

    // "local model toolbar subtitles do not query runtime modes per row" removed with
    // cloud-only/Omega removal 2026-07-03 — the local-model subtitle machinery
    // (localModelSubtitle(for: LocalModelDescriptor) / localModelSubtitleCache / etc.) was deleted
    // from RootView with the local-model UI.

    @Test("managed tool runtime falls back to a writable scratch vault when no vault is attached")
    func managedToolRuntimeFallsBackToWritableScratchVaultWhenNoVaultIsAttached() throws {
        let url = FoundationSafety.managedToolRuntimeVaultDirectory(preferredVaultPath: nil)

        #expect(url.lastPathComponent == "ScratchVault")
        #expect(url.path.contains("ManagedToolRuntime"))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("managed tool runtime keeps the attached vault path when one is available")
    func managedToolRuntimeKeepsAttachedVaultPathWhenAvailable() {
        let preferred = URL(fileURLWithPath: "/tmp/epistemos-runtime-vault", isDirectory: true)

        let url = FoundationSafety.managedToolRuntimeVaultDirectory(
            preferredVaultPath: preferred.path
        )

        #expect(url.path == preferred.standardizedFileURL.path)
    }

    @Test("inference settings expose the shared cloud fallback toggle")
    func inferenceSettingsExposeCloudFallbackToggle() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("Text(\"Auto-route on failure\")"))
        #expect(settings.contains("inference.setCloudAutoFallback($0)"))
    }

    @Test("inference settings expose model-aware provider-native runtime controls")
    func inferenceSettingsExposeModelAwareProviderNativeRuntimeControls() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("Reasoning Effort"))
        #expect(settings.contains("providerNativeReasoningModes(for:"))
        #expect(settings.contains("providerNativeControls(for: provider)"))
        #expect(settings.contains("if hasConfiguredAccess {"))
        #expect(settings.contains("Enable Adaptive Thinking"))
        #expect(settings.contains("Enable Grounding with Google Search"))
        #expect(settings.contains("Enable Web Search"))
    }

    @Test("direct-stream manifest suppresses app tools it cannot execute")
    func pipelineDirectStreamManifestSuppressesUnexecutableTools() throws {
        // The direct-stream path (Fast / Thinking for cloud, local non-agent)
        // cannot execute app tools like vault.read or file.read — only the
        // Rust agent loop or LocalAgentLoop can. Advertising those tools
        // in the system manifest for direct-stream turns caused models to
        // emit tool-call JSON that the runtime silently ignored, leaving
        // the answer looking hallucinated. The fix passes
        // `toolExecutionAvailable: false` to the manifest builder so the
        // builder only surfaces provider-native tools (web_search, etc.)
        // that the cloud provider actually executes natively.
        let pipeline = try loadRepoTextFile("Epistemos/Engine/PipelineService.swift")

        #expect(pipeline.contains("toolExecutionAvailable: false"))
        #expect(pipeline.contains("toolExecutionAvailable: Bool"))
        #expect(pipeline.contains("providerNativeCapabilityToolNameList"))
    }

    @MainActor
    @Test("provider-native capability list only exposes tools the cloud request actually attaches")
    func providerNativeCapabilityListIsBoundedByEnabledToggles() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()
            inference.setPreferredChatModelSelection(.cloud(.openAIGPT54Mini))
            inference.setOpenAIWebSearchEnabled(false)

            let disabled = inference.providerNativeCapabilityToolNameList(for: .fast)
            #expect(disabled.isEmpty)

            inference.setOpenAIWebSearchEnabled(true)
            let enabled = inference.providerNativeCapabilityToolNameList(for: .fast)
            #expect(enabled == ["web_search"])
        }
    }

    @Test("reasoning loop and graph inspectors preserve selected operating-mode error handling")
    func reasoningLoopAndGraphInspectorsPreserveOperatingModeErrorHandling() throws {
        let reasoningLoop = try loadRepoTextFile("Epistemos/Omega/Inference/ReasoningLoopService.swift")
        let graphInspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let pinnedInspector = try loadRepoTextFile("Epistemos/Views/Graph/PinnedInspector.swift")
        let streamingDelegate = try loadRepoTextFile("Epistemos/Bridge/StreamingDelegate.swift")

        #expect(reasoningLoop.contains("operatingMode: EpistemosOperatingMode = .fast"))
        #expect(reasoningLoop.contains("guard operatingMode != .fast else { return false }"))
        #expect(reasoningLoop.contains("query: query,\n                operatingMode: operatingMode"))
        #expect(graphInspector.contains("appendToLastAssistant(UserFacingChatError.message(from: error))"))
        #expect(pinnedInspector.contains("appendToLastAssistant(UserFacingChatError.message(from: error))"))
        #expect(streamingDelegate.contains("struct AgentRuntimeError: Error, LocalizedError, Sendable"))
    }

    @Test("root toolbar only mounts a principal item when there is visible content")
    func rootToolbarOnlyMountsPrincipalItemWhenVisible() throws {
        let rootView = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )

        #expect(rootView.contains("private var embeddedHomeGraphContentVisible: Bool"))
        #expect(rootView.contains("private var embeddedHomeGraphCanvasVisible: Bool"))
        #expect(rootView.contains("private var embeddedHomeGraphNoteVisible: Bool"))
        #expect(rootView.contains("if embeddedHomeGraphContentVisible {\n            return embeddedHomeGraphNoteVisible\n        }"))
        #expect(rootView.contains("if !embeddedHomeGraphContentVisible && ui.homeTab == .home && activeHomeChat"))
        #expect(rootView.contains("|| showEmbeddedGraphToolbarControls"))
        #expect(!rootView.contains("floatingGraphToolbarControls"))
        #expect(!rootView.contains("GraphSurfaceUtilityToolbar"))
        #expect(rootView.contains("ToolbarItem(placement: .principal)"))
        #expect(!rootView.contains("private var activeAgentWorkspace: Bool"))
        #expect(rootView.contains("private var showLandingToolbarControls: Bool"))
        #expect(rootView.contains("private var showEmbeddedGraphToolbarControls: Bool"))
        #expect(rootView.contains("ToolbarItem(placement: .navigation)"))
    }

    @Test("bootstrap local model log does not imply eager weight load")
    func bootstrapLocalModelLogDoesNotImplyEagerWeightLoad() throws {
        let bootstrap = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/AppBootstrap.swift",
            testsFilePath: #filePath
        )

        #expect(!bootstrap.contains("Local agent model loaded:"))
        // `bootstrap.contains("Local agent model selected:")` removed with cloud-only/Omega
        // removal 2026-07-03 — the local-agent model-selection log was deleted with the local stack.
    }

    @Test("startup warmups only schedule Metal shader warmup outside tests and debug builds")
    func startupWarmupsStayLazyInTestsAndDebugBuilds() throws {
        #expect(
            !AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: true,
                isDebugBuild: false
            )
        )
        #expect(
            !AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: false,
                isDebugBuild: true
            )
        )
        #expect(
            AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: false,
                isDebugBuild: false
            )
        )

        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/AppBootstrap.swift",
            testsFilePath: #filePath
        )
        #expect(!source.contains("shouldPrewarmHermesAtLaunch"))
        #expect(!source.contains("shouldSuperviseHermesAtLaunch"))
    }

    // "local runtime health is wired from mlx and gguf inference into settings surfaces" removed
    // with cloud-only/Omega removal 2026-07-03 — the local-runtime health wiring (localGGUFClient /
    // LocalRuntimeHealthSnapshot / setLatestLocalRuntimeProfile / localRuntimeStatus*) was deleted
    // with the MLX/GGUF stack; the app is cloud-only.

    @Test("live notes route through the global staged vault approval flow")
    func liveNotesRouteThroughGlobalStagedVaultApprovalFlow() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let appEnvironment = try loadRepoTextFile("Epistemos/App/AppEnvironment.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let liveNoteExecutor = try loadRepoTextFile("Epistemos/Vault/LiveNoteExecutor.swift")

        #expect(appBootstrap.contains("let vaultChatMutator"))
        #expect(appBootstrap.contains("let liveNoteScheduler = LiveNoteSchedulerService()"))
        #expect(appBootstrap.contains("refreshLiveNoteScheduler()"))
        #expect(appBootstrap.contains("approvalMutator: vaultChatMutator"))
        #expect(appEnvironment.contains(".environment(bootstrap.vaultChatMutator)"))
        #expect(app.contains("DiffApprovalSheet("))
        #expect(liveNoteExecutor.contains("stageFileMutation("))
        #expect(!liveNoteExecutor.contains("try? body.write(to: fileURL"))
    }

    @Test("live note approval restores managed note state if persistence fails before commit")
    func liveNoteApprovalRestoresManagedNoteStateIfPersistenceFails() throws {
        let source = try loadRepoTextFile("Epistemos/Vault/LiveNoteExecutor.swift")

        #expect(source.contains("let originalFilePath = page.filePath"))
        #expect(source.contains("let originalWordCount = page.wordCount"))
        #expect(source.contains("let originalLastSyncedBodyHash = page.lastSyncedBodyHash"))
        #expect(source.contains("page.saveBody(originalBody)"))
        #expect(source.contains("BlockMirror.sync(pageId: page.id, body: originalBody, modelContext: context)"))
        #expect(source.contains("page.filePath = originalFilePath"))
        #expect(source.contains("page.lastSyncedBodyHash = originalLastSyncedBodyHash"))
        #expect(source.contains("page.needsVaultSync = originalNeedsVaultSync"))
    }

    @Test("live note scheduler timer stays on the main queue to avoid actor isolation crashes")
    func liveNoteSchedulerTimerStaysOnMainQueue() throws {
        let source = try loadRepoTextFile("Epistemos/Vault/LiveNoteExecutor.swift")

        #expect(source.contains("DispatchSource.makeTimerSource(queue: .main)"))
        #expect(!source.contains("DispatchSource.makeTimerSource(queue: .global(qos: .utility))"))
    }

    @Test("live note scans use the fast body-read path to avoid repeated launch hangs")
    func liveNoteScansUseFastBodyReadPath() throws {
        let scanner = try loadRepoTextFile("Epistemos/Vault/LiveNoteScanner.swift")
        let pageModel = try loadRepoTextFile("Epistemos/Models/SDPage.swift")
        let executor = try loadRepoTextFile("Epistemos/Vault/LiveNoteExecutor.swift")

        #expect(scanner.contains("func scanForLiveNotes(modelContainer: ModelContainer) async -> [LiveNoteTask]"))
        #expect(scanner.contains("let context = ModelContext(modelContainer)"))
        #expect(scanner.contains("Task.detached(priority: .utility)"))
        #expect(pageModel.contains("func loadBody(mapped: Bool = false, fast: Bool = false)"))
        #expect(scanner.contains("return await Self.scanTasksAsync(from: candidates)"))
        #expect(scanner.contains("await SDPage.loadBodyAsyncFromPrimitives("))
        #expect(executor.contains("let tasks = await scanner.scanForLiveNotes(modelContainer: container)"))
        #expect(!scanner.contains("func scanForLiveNotes(context: ModelContext) async -> [LiveNoteTask]"))
    }

    @Test("main scene disables macOS window restoration so bad saved state cannot trap launch")
    func mainSceneDisablesMacOSWindowRestoration() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(app.contains("func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool"))
        #expect(app.contains("func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool"))
        #expect(app.contains("func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool"))
        #expect(app.contains(".restorationBehavior(.disabled)"))
        #expect(app.contains("SavedApplicationStatePurger.shouldPurgeAtLaunch()"))
        #expect(app.contains("SavedApplicationStatePurger.purgeIfNeeded()"))
        #expect(app.contains("func applicationWillFinishLaunching(_ notification: Notification)"))
        #expect(app.contains("_ = EpistemosDocumentController(databaseWriter: nil)"))
        #expect(!app.contains("window.isRestorable = false"))
        #expect(appBootstrap.contains("SavedApplicationStatePurger.purgeIfNeeded()"))
    }

    @Test("main scene avoids imperative home window mutation during SwiftUI startup")
    func mainSceneAvoidsImperativeHomeWindowMutationDuringStartup() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(app.contains("WindowGroup(\"Epistemos\")"))
        #expect(app.contains("#if EPISTEMOS_APP_STORE"))
        #expect(app.contains("_bootstrap = State(initialValue: bootstrap)"))
        #expect(app.contains("private static func viableHomeWindow() -> NSWindow?"))
        #expect(app.contains("window.frame.height >= WindowPresentationPolicy.mainWindowMinimumSize.height"))
        #expect(app.contains("AppStoreFirstWindowPresenter.shared.schedule(bootstrap: bootstrap)"))
        #expect(app.contains("window.isReleasedWhenClosed = false"))
        #expect(app.contains("guard !Self.isRunningTests else { return }"))
        #expect(!app.contains("ModularZoomWindowObserver"))
        #expect(!app.contains("applyMainWindowPolicyIfNeeded"))
        #expect(!app.contains("NSWindow.didBecomeMainNotification"))
        #expect(!app.contains("NSWindow.didBecomeKeyNotification"))
        #expect(!app.contains("NSWindow.didDeminiaturizeNotification"))
    }

    @Test("home window diagnostics instrument sendEvent hit testing and alpha writes behind an opt-in flag")
    func homeWindowDiagnosticsInstrumentSendEventHitTestingAndAlphaWrites() throws {
        let diagnostics = try loadRepoTextFile("Epistemos/App/HomeWindowInputDiagnostics.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(diagnostics.contains("EPI_HOME_WINDOW_INPUT_DIAGNOSTICS"))
        #expect(diagnostics.contains("#selector(NSWindow.sendEvent(_:))"))
        #expect(diagnostics.contains("#selector(setter: NSView.alphaValue)"))
        #expect(diagnostics.contains("contentView.hitTest("))
        #expect(diagnostics.contains("contentView.alphaValue"))
        #expect(diagnostics.contains("contentView.layer?.opacity"))
        #expect(app.contains("HomeWindowInputDiagnostics.shared.startIfNeeded()"))
        #expect(app.contains("HomeWindowInputDiagnostics.shared.stop()"))
    }

    @Test("runtime audit can swap the home scene to a bare button without launch gate or root sheets")
    func runtimeAuditCanSwapHomeSceneToBareButton() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(app.contains("EPI_HOME_WINDOW_MINIMAL_CONTENT"))
        #expect(app.contains("AuditMinimalHomeSceneView()"))
        #expect(app.contains("Button(\"test\")"))
        #expect(app.contains("if RuntimeAuditFlags.minimalHomeSceneEnabled"))
        #expect(app.contains("LaunchIntegrityGateView(bootstrap: bootstrap)"))
    }

    @Test("runtime audit can keep the root shell while swapping home content to a bare button")
    func runtimeAuditCanKeepRootShellWhileSwappingHomeContent() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(rootView.contains("EPI_HOME_WINDOW_ROOT_SHELL_MINIMAL_CONTENT"))
        #expect(rootView.contains("AuditRootShellMinimalContentView()"))
        #expect(rootView.contains("root_shell_button_pressed"))
        #expect(rootView.contains("if RuntimeAuditRootFlags.rootShellMinimalContentEnabled"))
    }

    @Test("audit launcher isolates the latest build behind a dedicated audit app identity")
    func auditLauncherIsolatesLatestBuildBehindDedicatedIdentity() throws {
        let script = try loadRepoTextFile("scripts/launch_audit_app.sh")

        #expect(script.contains("build/audit-derived-data"))
        #expect(script.contains("com.epistemos.audit"))
        #expect(script.contains("Epistemos Audit"))
        #expect(script.contains("epistemos.restoreLastSession"))
        #expect(script.contains("epistemos.vaultBookmark"))
        #expect(script.contains("epistemos.lastVaultPath"))
        #expect(script.contains("EPISTEMOS_SKIP_VAULT_RESTORE"))
        #expect(script.contains("EPISTEMOS_APPLICATION_SUPPORT_ROOT"))
        #expect(script.contains("EPISTEMOS_AUDIT_ALLOW_SOVEREIGN_GATE"))
        #expect(script.contains("AUDIT_APP_SUPPORT_ROOT"))
        #expect(script.contains("build/audit-app-support"))
        #expect(script.contains("clear_audit_runtime_state"))
        #expect(script.contains("clear_audit_saved_state"))
        #expect(script.contains("Library/Saved Application State"))
        #expect(script.contains("EPI_HOME_WINDOW_MINIMAL_CONTENT"))
        #expect(script.contains("scripts/xcodebuild_epistemos.sh"))
    }

    @Test("workspace restore offers a one-shot skip restore relaunch escape hatch")
    func workspaceRestoreOffersSkipRestoreEscapeHatch() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let statusBar = try loadRepoTextFile("Epistemos/App/StatusBar.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        #expect(app.contains("Skip Restore and Relaunch Home"))
        #expect(app.contains("@objc private func dockSkipRestoreAndRelaunch()"))
        #expect(statusBar.contains("Skip Restore and Relaunch Home"))
        #expect(statusBar.contains("@objc private func skipRestoreAndRelaunch()"))
        #expect(appBootstrap.contains("func relaunchSkippingRestoreAndDiscardSession()"))
        #expect(appBootstrap.contains("workspaceService.prepareSkipRestoreRelaunch()"))
        #expect(workspaceService.contains("epistemos.skipWorkspaceRestoreOnce"))
        #expect(workspaceService.contains("epistemos.skipWorkspaceAutoSaveOnce"))
        #expect(workspaceService.contains("func prepareSkipRestoreRelaunch()"))
        #expect(workspaceService.contains("func consumeSkipRestoreRequest() -> Bool"))
        #expect(workspaceService.contains("func consumeSkipAutoSaveRequest() -> Bool"))
        #expect(workspaceService.contains("func clearAutoSavedWorkspace()"))
    }

    @Test("bootstrap archives the retired dual brain router instead of booting it into the live app")
    func bootstrapArchivesTheRetiredDualBrainRouterInsteadOfBootingItIntoTheLiveApp() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let appEnvironment = try loadRepoTextFile("Epistemos/App/AppEnvironment.swift")

        #expect(!appBootstrap.contains("private var _dualBrainRouter"))
        #expect(!appBootstrap.contains("var dualBrainRouter: DualBrainRouter"))
        #expect(!appBootstrap.contains("self._dualBrainRouter = DualBrainRouter("))
        #expect(!appEnvironment.contains(".environment(bootstrap.dualBrainRouter)"))
        // "Initialize device-action infrastructure" / deviceAgent.setBackend asserts removed
        // with cloud-only/Omega removal 2026-07-03 (the device-action infra was deleted).
    }

    @Test("archived runtime shims are compile-time unavailable so they cannot drift back into the live app")
    func archivedRuntimeShimsAreCompileTimeUnavailableSoTheyCannotDriftBackIntoTheLiveApp() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let agentRuntime = try loadRepoTextFile("Epistemos/Engine/AgentRuntime.swift")
        let claudeRuntime = try loadRepoTextFile("Epistemos/Engine/ClaudeManagedRuntime.swift")

        #expect(agentRuntime.contains("Archived Agent Runtime Surface"))
        #expect(agentRuntime.contains("@available(*, unavailable"))
        #expect(!repoFileExists("Epistemos/Engine/LocalRustRuntime.swift"))
        #expect(!repoFileExists("Epistemos/Engine/UnavailableLocalLLMClient.swift"))
        #expect(!appBootstrap.contains("UnavailableLocalLLMClient("))
        #expect(claudeRuntime.contains("Archived ClaudeManagedRuntime"))
        #expect(claudeRuntime.contains("@available(*, unavailable"))
        #expect(!claudeRuntime.contains("not yet wired to live API"))
    }

    @Test("test hosts route application support paths into a temporary runtime root")
    func testHostsRouteApplicationSupportPathsIntoTemporaryRuntimeRoot() {
        let appSupport = FoundationSafety.userApplicationSupportDirectory().standardizedFileURL
        let tempRoot = FileManager.default.temporaryDirectory.standardizedFileURL
        let noteBodies = NoteFileStorage.storageDirectory().standardizedFileURL

        #expect(appSupport.path.hasPrefix(tempRoot.path))
        #expect(appSupport.lastPathComponent == "Application Support")
        #expect(noteBodies.path.hasPrefix(appSupport.path))
        #expect(noteBodies.path.contains("/Epistemos/note-bodies"))
    }

    @Test("application support override routes audit runtimes away from production stores")
    func applicationSupportOverrideRoutesAuditRuntimesAwayFromProductionStores() {
        let fileManager = FileManager.default
        let overrideRoot = fileManager.temporaryDirectory
            .appendingPathComponent("Epistemos-AppSupportOverride-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL

        let resolved = FoundationSafety.runtimeApplicationSupportDirectory(
            fileManager: fileManager,
            processInfoEnvironment: [
                FoundationSafety.applicationSupportOverrideEnvironmentKey: overrideRoot.path,
                "XCTestConfigurationFilePath": "/tmp/test.xctest",
            ],
            processIdentifier: 4242
        )

        #expect(resolved == overrideRoot)
        #expect(fileManager.fileExists(atPath: resolved.path))

        let relativeOverride = FoundationSafety.runtimeApplicationSupportDirectory(
            fileManager: fileManager,
            processInfoEnvironment: [
                FoundationSafety.applicationSupportOverrideEnvironmentKey: "relative/audit-root",
                "XCTestConfigurationFilePath": "/tmp/test.xctest",
            ],
            processIdentifier: 4243
        )

        #expect(relativeOverride.path.contains("Epistemos-TestRuntime/4243/Application Support"))
        try? fileManager.removeItem(at: overrideRoot)
    }

    @Test("test-safe application support routing stays centralized")
    func testSafeApplicationSupportRoutingStaysCentralized() throws {
        let extensions = try loadRepoTextFile("Epistemos/Engine/Extensions.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let noteFileStorage = try loadRepoTextFile("Epistemos/Sync/NoteFileStorage.swift")
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let paperclipStore = try loadRepoTextFile("Epistemos/State/PaperclipStateStore.swift")
        // localModels (LocalModelInfrastructure.swift) dropped from the FoundationSafety-routing
        // list with cloud-only/Omega removal 2026-07-03 — its local-model persistence (which used
        // FoundationSafety.userApplicationSupportDirectory) was gutted; it is no longer a persistence surface.
        let traceCollector = try loadRepoTextFile("Epistemos/Harness/TraceCollector.swift")
        let harnessRegistry = try loadRepoTextFile("Epistemos/Harness/HarnessRegistry.swift")
        let progressStore = try loadRepoTextFile("Epistemos/Harness/ProgressStore.swift")
        let watchdog = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")
        let pageEditorCache = try loadRepoTextFile("Epistemos/Views/Notes/PageEditorCache.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let conversationPersistence = try loadRepoTextFile("Epistemos/Vault/ConversationPersistence.swift")
        let appGroupContainer = try loadRepoTextFile("Epistemos/App/AppGroupContainer.swift")
        let quarantineArchive = try loadRepoTextFile("Epistemos/Engine/QuarantineArchive.swift")
        let capabilityManifest = try loadRepoTextFile("Epistemos/Engine/CapabilityManifestBuilder.swift")
        // deviceAgent (DeviceAgentService.swift) removed with cloud-only/Omega removal 2026-07-03
        let traceInspector = try loadRepoTextFile("Epistemos/Views/Capture/TraceInspectorView.swift")

        #expect(extensions.contains("Epistemos-TestRuntime"))
        #expect(extensions.contains("EPISTEMOS_APPLICATION_SUPPORT_ROOT"))
        #expect(extensions.contains("XCTestConfigurationFilePath"))
        #expect(appBootstrap.contains("let usesInMemoryModelStore = Self.isRunningTests"))
        #expect(appBootstrap.contains("preparePersistentModelStoreIfNeeded"))
        #expect(appBootstrap.contains("let modelStoreURL = Self.persistentModelStoreURL("))
        #expect(appBootstrap.contains("applicationSupportDirectory: applicationSupportDirectory"))
        #expect(appBootstrap.contains("ModelConfiguration(url: modelStoreURL)"))
        #expect(appBootstrap.contains("FoundationSafety.userApplicationSupportDirectory(fileManager: .default)"))

        for source in [
            noteFileStorage,
            searchIndex,
            vaultSync,
            paperclipStore,
            traceCollector,
            harnessRegistry,
            progressStore,
            watchdog,
            pageEditorCache,
            app,
            conversationPersistence,
            appGroupContainer,
            quarantineArchive,
            capabilityManifest,
            traceInspector,
        ] {
            #expect(source.contains("FoundationSafety.userApplicationSupportDirectory"))
        }
    }

    @Test("paperclip store uses bound SQLite statements and explicit rollback")
    func paperclipStoreUsesBoundStatementsAndRollback() throws {
        let paperclipStore = try loadRepoTextFile("Epistemos/State/PaperclipStateStore.swift")

        #expect(!paperclipStore.contains("_ = try? exec(\"COMMIT;\")"))
        #expect(!paperclipStore.contains("VALUES ('\\(tick.sessionId)'"))
        #expect(!paperclipStore.contains("VALUES ('\\(heartbeat.agentId)'"))
        #expect(paperclipStore.contains("try exec(\"ROLLBACK;\")"))
        #expect(paperclipStore.contains("sqlite3_bind_text"))
        #expect(paperclipStore.contains("sqlite3_bind_double"))
        #expect(paperclipStore.contains("sqlite3_bind_int64"))
    }

    @Test("paperclip heartbeat clock is a lightweight two-minute bootstrap loop")
    func paperclipHeartbeatClockIsLightweightTwoMinuteBootstrapLoop() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let heartbeatClock = try loadRepoTextFile("Epistemos/State/PaperclipHeartbeatClock.swift")

        #expect(heartbeatClock.contains("static let defaultInterval: Duration = .seconds(120)"))
        #expect(heartbeatClock.contains("Task.sleep(for: interval)"))
        #expect(heartbeatClock.contains("while !Task.isCancelled"))
        #expect(heartbeatClock.contains("try await store.recordHeartbeat(heartbeat)"))
        #expect(heartbeatClock.contains("durationMs: durationMs"))
        #expect(!heartbeatClock.contains("MLX"))
        #expect(!heartbeatClock.contains("import Metal"))

        #expect(bootstrap.contains("private var _paperclipHeartbeatClock: PaperclipHeartbeatClock?"))
        #expect(bootstrap.contains("PaperclipHeartbeatClock(store: store)"))
        #expect(bootstrap.contains("if !Self.isRunningTests {"))
        #expect(bootstrap.contains("paperclipHeartbeatClock.start()"))
    }

    @Test("capture config avoids silent JSON fallback for allowlist and blocklist")
    func captureConfigAvoidsSilentJSONFallback() throws {
        let config = try loadRepoTextFile("Epistemos/State/EpistemosConfig.swift")

        #expect(!config.contains("(try? JSONDecoder().decode([String].self, from: Data(allowlistJSON.utf8))) ?? []"))
        #expect(!config.contains("(try? JSONDecoder().decode([String].self, from: Data(blocklistJSON.utf8))) ?? []"))
        #expect(!config.contains("(try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? \"[]\""))
        #expect(config.contains("EpistemosConfig: failed to decode capture allowlist JSON"))
        #expect(config.contains("EpistemosConfig: failed to decode capture blocklist JSON"))
        #expect(config.contains("EpistemosConfig: failed to encode capture filter JSON"))
        #expect(config.contains("private func decodeBundleList"))
    }

    @Test("capture config also recovers legacy delimited bundle lists")
    func captureConfigRecoversLegacyDelimitedLists() throws {
        let config = try loadRepoTextFile("Epistemos/State/EpistemosConfig.swift")

        #expect(config.contains("private func decodeLegacyBundleList"))
        #expect(config.contains("CharacterSet(charactersIn: \",;\\n\")"))
        #expect(config.contains("private func deduplicatedBundleList"))
        #expect(config.contains("persistDecodedBundleList"))
        #expect(config.contains("return nil"))
        #expect(!config.contains("resetMalformedBundleList"))
    }

    // Cloud-only migration: removed the local-model thinking-mode gating tests
    // ("… sanitizes unsupported chat model selections", "… stays off for local
    // models without verified responsive thinking support", "… stays off for
    // installed local models without verified think support") and the local
    // hardware-tier support test — all drove deleted LocalTextModelID /
    // setInstalled/PreferredLocalTextModelIDs machinery.

    @MainActor
    @Test("available operating modes match the active chat selection")
    func availableOperatingModesMatchTheActiveSelection() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()

            inference.setPreferredChatModelSelection(.appleIntelligence)
            #expect(inference.availableOperatingModes == [.fast])

            inference.setPreferredChatModelSelection(.cloud(.openAIGPT54Mini))
            // GPT-5.4-Mini legitimately supports Fast and Agent per its
            // cloud capability manifest.
            #expect(inference.availableOperatingModes == [.fast, .agent])
        }
    }

    @Test("landing no longer mounts runtime model selection")
    func landingNoLongerMountsRuntimeModelSelection() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landing.contains("ChatBrainPickerMenu("))
        #expect(!landing.contains("InlineRuntimePickerPanel("))
        #expect(!landing.contains("operatingMode: operatingModeBinding"))
        #expect(!landing.contains("availableOperatingModes: supportedOperatingModes"))
        #expect(!landing.contains("OperatingModeSelectorView("))
    }

    @Test("inference exposes observable cloud credential cache and validation state")
    func inferenceExposesObservableCloudCredentialCacheAndValidationState() throws {
        let source = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(source.contains("private(set) var cachedCloudAPIKeys"))
        #expect(source.contains("private(set) var cachedCloudOAuthCredentials"))
        #expect(source.contains("private(set) var cloudProviderValidationStates"))
        #expect(source.contains("func validateCloudAccess(for provider: CloudModelProvider) async -> ConnectionTestResult"))
        #expect(source.contains("func validateAPIKey(for provider: CloudModelProvider) async -> ConnectionTestResult"))
        #expect(source.contains("cloudProviderValidationStates[provider] = .checking"))
        #expect(source.contains("cloudProviderValidationStates[provider] = .unchecked"))
        #expect(source.contains("cloudProviderValidationStates[provider] = .missing"))
        #expect(source.contains("cachedCloudAPIKeys[provider] = trimmed"))
    }

    @Test("inference defers launch-time cloud credential hydration off the boot path")
    func inferenceDefersLaunchTimeCloudCredentialHydrationOffTheBootPath() throws {
        let source = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(source.contains("deferCloudCredentialBootstrapOnLaunch"))
        #expect(source.contains("initializeDeferredCloudCredentialState()"))
        #expect(source.contains("startDeferredCloudCredentialBootstrap()"))
        #expect(source.contains("DispatchQueue.global(qos: .utility).async"))
    }

    @Test("cloud key validation checks provider auth before probing a model")
    func cloudKeyValidationChecksProviderAuthBeforeProbingAModel() throws {
        let llmService = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(llmService.contains("if let model"))
        #expect(llmService.contains("providerAuthorizationRequest"))
        #expect(llmService.contains("openAIRequestURL(path: \"/models\", credential: credential)"))
        #expect(llmService.contains("https://api.anthropic.com/v1/models"))
        #expect(llmService.contains("generativelanguage.googleapis.com/v1beta/models"))
        #expect(inference.contains("case .anthropic:\n            .anthropicClaudeSonnet46"))
    }

    @Test("inference settings surface exposes key validation and provider guidance")
    func inferenceSettingsSurfaceExposesValidationAndGuidance() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let providerSupport = try loadRepoTextFile("Epistemos/Views/Shared/CloudProviderSetupCard.swift")

        #expect(source.contains("Check Access"))
        #expect(source.contains("statusBadge"))
        #expect(source.contains("setupHelpText"))
        #expect(source.contains("securely in the Apple Keychain"))
        #expect(!providerSupport.contains("struct CloudProviderSetupCard"))
    }

    #if false
    @Test("agent runtime panel uses a glass-native shell instead of the old flat split pane")
    func agentRuntimePanelUsesGlassNativeShell() throws {}

    @Test("agent runtime panel surfaces Hermes command actions in the native UI")
    func agentRuntimePanelSurfacesHermesCommandActions() throws {}

    @Test("agent runtime status pulse avoids repeat forever animation drift")
    func agentRuntimeStatusPulseAvoidsRepeatForeverAnimationDrift() throws {}

    @Test("agent runtime prepares harness state before recording intent and runs completion hooks")
    func agentRuntimeRunsHarnessLifecycleHooksInOrder() throws {}
    #endif

    @Test("xcode build graph regenerates and links epistemos core integrity bindings")
    func xcodeBuildGraphRegeneratesEpistemosCoreBindings() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let spec = try loadRepoTextFile("project.yml")
        let patcher = try loadRepoTextFile("patch-uniffi-bindings.py")
        let buildScript = try loadRepoTextFile("build-epistemos-core.sh")
        let embedAndSignHelper = try loadRepoTextFile("embed-and-sign-rust-dylib.sh")
        let bundleAssetsScript = try loadRepoTextFile("bundle-app-runtime-assets.sh")

        // build-omega-ax.sh segment removed from the chain with cloud-only/Omega removal 2026-07-03
        #expect(
            project.contains(
                "bash \\\"${SRCROOT}/build-rust.sh\\\" && bash \\\"${SRCROOT}/build-syntax-core.sh\\\" && bash \\\"${SRCROOT}/build-omega-mcp.sh\\\" && bash \\\"${SRCROOT}/build-epistemos-core.sh\\\""
            )
        )
        #expect(project.contains("Bundle Runtime Assets"))
        #expect(project.contains("bash \\\"${SRCROOT}/bundle-app-runtime-assets.sh\\\""))
        #expect(project.contains("-lepistemos_core"))
        #expect(project.contains("-lsyntax_core"))
        #expect(project.contains("-lomega_mcp"))
        #expect(!project.contains("-lomega_ax"))  // omega-ax removed with cloud-only/Omega removal 2026-07-03
        #expect(project.contains("epistemos_coreFFI"))
        #expect(project.contains("\"@executable_path\","))
        #expect(project.contains("\"@loader_path/../Frameworks\","))
        #expect(spec.contains("bash \\\"${SRCROOT}/build-agent-core.sh\\\""))
        #expect(spec.contains("bash \\\"${SRCROOT}/build-epistemos-shadow.sh\\\""))
        #expect(spec.contains("bash \\\"${SRCROOT}/build-epistemos-code-index.sh\\\""))
        #expect(spec.contains("bash \\\"${SRCROOT}/build-substrate-rt.sh\\\""))
        #expect(spec.contains("bash \\\"${SRCROOT}/build-tiptap-bundle.sh\\\""))
        #expect(spec.contains("name: Bundle Runtime Assets"))
        #expect(spec.contains("bash \"${SRCROOT}/bundle-app-runtime-assets.sh\""))
        #expect(spec.contains("-lepistemos_core"))
        #expect(spec.contains("-lsyntax_core"))
        #expect(spec.contains("epistemos_coreFFI"))
        #expect(spec.contains("@executable_path"))
        #expect(spec.contains("@loader_path/../Frameworks"))
        #expect(!project.contains("SHIP_MODE=release"))
        #expect(!spec.contains("SHIP_MODE=release"))
        #expect(patcher.contains("nonisolated public var errorDescription"))
        #expect(patcher.contains("nonisolated(unsafe)"))
        #expect(patcher.contains("nonisolated(unsafe) let pointer = self.pointer"))
        #expect(patcher.contains("((?:(?:open|public|private|fileprivate|internal|final|indirect)\\s+)*)((?:class|struct|enum|protocol|extension)\\b)"))
        #expect(patcher.contains("((?:(?:open|public|private|fileprivate|internal|override|final)\\s+)*)((?:static|class)\\s+)?func\\s"))
        #expect(buildScript.contains("rm -f \"$TARGET_BUILD_DIR/PackageFrameworks/libepistemos_core.dylib\""))
        #expect(buildScript.contains("embed-and-sign-rust-dylib.sh"))
        #expect(embedAndSignHelper.contains("codesign --force --sign"))
        #expect(embedAndSignHelper.contains("EXPANDED_CODE_SIGN_IDENTITY"))
        #expect(!buildScript.contains("cp ../build-rust/libepistemos_core.dylib \"$TARGET_BUILD_DIR/PackageFrameworks/libepistemos_core.dylib\""))
    }

    @Test("test source mirror stays incremental and skips heavyweight build artifacts")
    func testSourceMirrorStaysIncrementalAndSkipsHeavyweightBuildArtifacts() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let spec = try loadRepoTextFile("project.yml")

        for source in [project, spec] {
            #expect(source.contains("Bundle Test Source Mirror"))
            #expect(
                source.contains("copy_tree \"epistemos-code-index\"")
                    || source.contains("copy_tree \\\"epistemos-code-index\\\"")
            )
            #expect(
                source.contains("copy_tree \"XPCServices\"")
                    || source.contains("copy_tree \\\"XPCServices\\\""),
                "XPC source guards must read bundled XPCServices files from SourceMirror instead of falling back to live checkout."
            )
            #expect(!source.contains("rm -rf \"${output_dir}\""))
            #expect(source.contains("prune_artifact_directories"))
            #expect(
                source.contains("prune_artifact_directories \"${destination_root}\"")
                    || source.contains("prune_artifact_directories \\\"${destination_root}\\\"")
            )
            #expect(source.contains("--exclude='target/'"))
            #expect(source.contains("--exclude='.build/'"))
            #expect(source.contains("--exclude='build/'"))
            #expect(source.contains("--exclude='DerivedData/'"))
            #expect(source.contains("--exclude='.git/'"))
            #expect(
                source.contains("rsync -a \"${source_path}\" \"${destination_path}\"")
                    || source.contains("rsync -a \\\"${source_path}\\\" \\\"${destination_path}\\\"")
            )
        }
    }

    @Test("structured diagnostic logger keeps fire-and-forget writes alive")
    func structuredDiagnosticLoggerRetainsFireAndForgetWrites() throws {
        let source = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")

        #expect(source.contains("queue.async {"))
        #expect(!source.contains("queue.async { [weak self] in"))
        #expect(source.contains("self.appendLine(entry)"))
    }

    @Test("structured diagnostic logger avoids silent file persistence fallbacks")
    func structuredDiagnosticLoggerAvoidsSilentFilePersistenceFallbacks() throws {
        let source = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")

        #expect(!source.contains("try? FileManager.default.createDirectory("))
        #expect(!source.contains("guard let data = try? Data(contentsOf: logFileURL),"))
        #expect(!source.contains("guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),"))
        #expect(!source.contains("if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),"))
        #expect(!source.contains("try? FileManager.default.removeItem(at: rotatedURL)"))
        #expect(!source.contains("try? FileManager.default.moveItem(at: logFileURL, to: rotatedURL)"))
        #expect(!source.contains("if let handle = try? FileHandle(forWritingTo: logFileURL)"))
        #expect(!source.contains("try? entry.write(to: logFileURL)"))
        #expect(source.contains("Structured diagnostics: failed to create log directory"))
        #expect(source.contains("Structured diagnostics: failed to load recent events"))
        #expect(source.contains("Structured diagnostics: failed to encode event"))
        #expect(source.contains("Structured diagnostics: failed to append log entry"))
        #expect(source.contains("private nonisolated func ensureLogDirectoryExists()"))
        #expect(source.contains("private nonisolated func shouldRotateLogFile() throws -> Bool"))
        #expect(source.contains("private nonisolated func rotateLogFile() throws"))
    }

    @Test("main thread watchdog coalesces queued delayed callbacks before logging")
    func mainThreadWatchdogCoalescesQueuedDelayedCallbacksBeforeLogging() throws {
        let source = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")

        #expect(source.contains("struct HangBurstTracker"))
        #expect(source.contains("hangCoalescingDelay"))
        #expect(source.contains("scheduleHangBurstEmission"))
        #expect(source.contains("coalesced samples"))
        #expect(!source.contains("consecutive:"))
    }

    @Test("app bootstrap skips main thread watchdog install under tests")
    func appBootstrapSkipsWatchdogInstallUnderTests() throws {
        let source = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        #expect(source.contains("if !Self.isRunningTests && !PowerGuard.shared.shouldDisableBackground {"))
        #expect(source.contains("MainThreadWatchdog.install()"))
    }

    @Test("Rust build scripts force panic abort under thread sanitizer builds")
    func rustBuildScriptsForcePanicAbortUnderThreadSanitizerBuilds() throws {
        let graphEngine = try loadRepoTextFile("build-rust.sh")
        let syntaxCore = try loadRepoTextFile("build-syntax-core.sh")
        let omegaMcp = try loadRepoTextFile("build-omega-mcp.sh")
        // build-omega-ax.sh removed with cloud-only/Omega removal 2026-07-03
        let epistemosCore = try loadRepoTextFile("build-epistemos-core.sh")

        for script in [graphEngine, syntaxCore, omegaMcp, epistemosCore] {
            #expect(script.contains("ENABLE_THREAD_SANITIZER"))
            #expect(script.contains("CARGO_PROFILE_DEV_PANIC=abort"))
            #expect(script.contains("RUSTFLAGS"))
            #expect(script.contains("-C panic=abort"))
        }
    }

    @Test("omega ffi crates build and embed dylibs instead of static archives")
    func omegaFFICratesBuildAndEmbedDylibsInsteadOfStaticArchives() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let omegaMcp = try loadRepoTextFile("build-omega-mcp.sh")
        // build-omega-ax.sh + omega_ax link/FFI removed with cloud-only/Omega removal 2026-07-03
        #expect(project.contains("-lomega_mcp"))
        #expect(!project.contains("-lomega_ax"))
        #expect(project.contains("omega_mcpFFI"))
        #expect(!project.contains("omega_axFFI"))
        #expect(!project.contains("$(SRCROOT)/build-rust/libomega_mcp.a"))
        #expect(!project.contains("$(SRCROOT)/build-rust/libomega_ax.a"))

        for script in [omegaMcp] {
            #expect(script.contains("cargo build --target aarch64-apple-darwin"))
            #expect(script.contains("cargo build --target x86_64-apple-darwin"))
            #expect(script.contains("lipo -create"))
            #expect(script.contains(".dylib\""))
            #expect(script.contains("install_name_tool -id"))
            #expect(script.contains("FRAMEWORKS_FOLDER_PATH"))
            #expect(script.contains("embed-and-sign-rust-dylib.sh"))
            #expect(script.contains("rm -f ../build-rust/lib"))
            #expect(!script.contains("cp \"$LIB_PATH\" ../build-rust/libomega_mcp.a"))
            #expect(!script.contains("cp \"$LIB_PATH\" ../build-rust/libomega_ax.a"))
        }
    }

    @Test("graph engine and epistemos core build universal darwin artifacts")
    func graphEngineAndEpistemosCoreBuildUniversalDarwinArtifacts() throws {
        let graphEngine = try loadRepoTextFile("build-rust.sh")
        let syntaxCore = try loadRepoTextFile("build-syntax-core.sh")
        let epistemosCore = try loadRepoTextFile("build-epistemos-core.sh")

        for script in [graphEngine, syntaxCore, epistemosCore] {
            #expect(script.contains("cargo build"))
            #expect(script.contains("--target aarch64-apple-darwin"))
            #expect(script.contains("--target x86_64-apple-darwin"))
            #expect(script.contains("lipo -create"))
        }
        #expect(graphEngine.contains("--features bolt-graph,shared-position-buffers"))
    }

    @Test("shadow git checkpoint dead code remains deleted")
    func shadowGitCheckpointDeadCodeRemainsDeleted() throws {
        let shadowGitURL = try sourceMirrorURL(for: "Epistemos/Omega/Safety/ShadowGitCheckpoint.swift")

        #expect(!FileManager.default.fileExists(atPath: shadowGitURL.path))
    }

    @Test("epistemos core durability and instant recall exports stay fail-closed")
    func epistemosCoreDurabilityAndInstantRecallExportsStayFailClosed() throws {
        let source = try loadRepoTextFile("epistemos-core/src/uniffi_exports.rs")
        let udl = try loadRepoTextFile("epistemos-core/uniffi/epistemos_core.udl")
        let noteStorage = try loadRepoTextFile("Epistemos/Sync/NoteFileStorage.swift")

        #expect(source.contains("libc::F_FULLFSYNC"))
        #expect(!source.contains("libc::fsync("))
        #expect(source.contains("fn with_recall_indices_mut<R>("))
        #expect(source.contains("fn with_recall_indices<R>("))
        #expect(!source.contains("RECALL_INDICES.lock().unwrap()"))
        #expect(source.contains("with_recall_indices_mut(false"))
        #expect(source.contains("with_recall_indices(\"[]\".to_string()"))
        #expect(source.contains("with_recall_indices(0"))
        #expect(source.contains("pub enum TextNormalizationError"))
        #expect(source.contains("pub fn sanitize_and_normalize(input: String) -> Result<String, TextNormalizationError>"))
        #expect(!source.contains("Returns empty string on rejection"))
        #expect(udl.contains("[Throws=TextNormalizationError]"))
        #expect(noteStorage.contains("try sanitizeAndNormalize(input: value)"))
        #expect(!noteStorage.contains("uniffi_epistemos_core_checksum_func_sanitize_and_normalize()"))
    }

    @Test("activity tracker lane avoids unchecked sendable on simple local state containers")
    func activityTrackerLaneAvoidsUncheckedSendableOnSimpleLocalStateContainers() throws {
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let substrateTypes = try loadRepoTextFile("Epistemos/State/CognitiveSubstrateTypes.swift")

        #expect(!activityTracker.contains("@unchecked Sendable"))
        #expect(activityTracker.contains("actor ActivityFlagState"))
        #expect(!substrateTypes.contains("@unchecked Sendable"))
        #expect(substrateTypes.contains("struct RingBuffer<T: Sendable>: Sendable"))
    }

    @Test("passive launch paths avoid system-wide input and Messages automation TCC probes")
    func passiveLaunchPathsAvoidSystemWideInputAndAutomationTCCProbes() throws {
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let appEnvironment = try loadRepoTextFile("Epistemos/App/AppEnvironment.swift")
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")
        let inferenceState = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let afmSessionPool = try loadRepoTextFile("Epistemos/Engine/AFMSessionPool.swift")
        let settingsView = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let shadowPanel = try loadRepoTextFile("Epistemos/Views/Halo/ShadowPanel.swift")
        let graphOverlayPanel = try loadRepoTextFile("Epistemos/Views/Graph/GraphOverlayPanel.swift")
        let hologramOverlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let proseTextView = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(!activityTracker.contains("CGEventSource.secondsSinceLastEventType"))
        #expect(!activityTracker.contains("NSEvent.addLocalMonitorForEvents"))
        #expect(!activityTracker.contains("NSEvent.addGlobalMonitorForEvents"))
        #expect(activityTracker.contains("func appIdleSeconds() -> Double"))
        #expect(activityTracker.contains("func recordInAppActivity()"))
        #expect(activityTracker.contains("Activity tracking started (explicit in-app activity signals)"))
        #expect(proseTextView.contains("AppBootstrap.shared?.activityTracker.recordInAppActivity()"))
        #expect(codeEditor.contains("AppBootstrap.shared?.activityTracker.recordInAppActivity()"))
        #expect(!appBootstrap.contains("IMessageNativeSetupDoctor.currentStatus"))
        #expect(!appBootstrap.contains("EpistemosShortcutsProvider.updateAppShortcutParameters()"))
        #expect(!appBootstrap.contains("AppleIntelligenceService.shared.checkAvailability().available"))
        #expect(appBootstrap.contains("SharedGPUAppleFallbackBackend(sharedGPUBackend: sharedGPUBackend)"))
        #expect(!appBootstrap.contains("AFMSessionPool.shared.prewarmAtLaunch"))
        #expect(!appBootstrap.contains("contentTagging-launch"))
        #expect(!afmSessionPool.contains("prewarmAtLaunch"))
        #expect(!afmSessionPool.contains("prewarmed at launch"))
        #expect(afmSessionPool.contains("prewarmForExplicitClassifierWork"))
        #expect(!appSupervisor.contains("AppleIntelligenceService.shared.checkAvailability()"))
        #expect(inferenceState.contains("func refreshAppleIntelligenceAvailability()"))
        let inferenceInitializer = try #require(
            inferenceState.range(of: "init(\n        hardwareCapabilitySnapshot:")
        )
        let inferenceBodyEnd = try #require(
            inferenceState.range(of: "\n    func refreshAppleIntelligenceAvailability()")
        )
        #expect(!inferenceState[inferenceInitializer.lowerBound..<inferenceBodyEnd.lowerBound].contains("checkAvailability()"))
        #expect(settingsView.contains("inference.refreshAppleIntelligenceAvailability()"))
        #expect(!appEnvironment.contains(".environment(bootstrap.screen2AXFusion)"))
        #expect(!shadowPanel.contains("NSEvent.addGlobalMonitorForEvents"))
        #expect(!shadowPanel.contains("NSEvent.addLocalMonitorForEvents"))
        #expect(shadowPanel.contains("NSWindow.didResignKeyNotification"))
        #expect(!hologramOverlay.contains("NSEvent.addLocalMonitorForEvents"))
        #expect(!hologramOverlay.contains("NSEvent.addGlobalMonitorForEvents"))
        #expect(graphOverlayPanel.contains("var keyEventHandler: ((NSEvent) -> Bool)?"))
    }

    @Test("event store graph builder and branded ids avoid unchecked sendable wrappers")
    func eventStoreGraphBuilderAndBrandedIdsAvoidUncheckedSendableWrappers() throws {
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")
        let graphBuilder = try loadRepoTextFile("Epistemos/Graph/GraphBuilder.swift")
        let brandedTypes = try loadRepoTextFile("Epistemos/Models/BrandedTypes.swift")

        #expect(!eventStore.contains("@unchecked Sendable"))
        #expect(eventStore.contains("final class EventStore: Sendable"))
        #expect(eventStore.contains("executeRequired(\"PRAGMA journal_mode=WAL;\")"))
        #expect(eventStore.contains("pragmaTextValue(\"PRAGMA journal_mode;\")?.lowercased() == \"wal\""))
        #expect(!graphBuilder.contains("@unchecked Sendable"))
        #expect(graphBuilder.contains("final class GraphBuilder: Sendable"))
        #expect(!brandedTypes.contains("@unchecked Sendable"))
        #expect(brandedTypes.contains("struct ChatId: BrandedId, Sendable"))
        #expect(brandedTypes.contains("struct MessageId: BrandedId, Sendable"))
    }

    @Test("note image display payload avoids unchecked sendable wrappers")
    func noteImageDisplayPayloadAvoidsUncheckedSendableWrappers() throws {
        let noteImageProcessor = try loadRepoTextFile("Epistemos/Views/Notes/NoteImageProcessor.swift")

        #expect(!noteImageProcessor.contains("@unchecked Sendable"))
        #expect(noteImageProcessor.contains("struct DisplayImage: Sendable"))
    }

    @Test("remaining production concurrency wrappers narrow unsafe state instead of unchecked sendable")
    func remainingProductionConcurrencyWrappersNarrowUnsafeStateInsteadOfUncheckedSendable() throws {
        let llmService = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        // MoLoRAInferenceService removed 2026-06-18 (orphaned molora_inference.py
        // subprocess; native NativeAdapterApply replaces it).
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(!llmService.contains("@unchecked Sendable"))
        #expect(llmService.contains("struct ProcessActivityToken: Sendable"))
        #expect(!graphState.contains("@unchecked Sendable"))
        #expect(graphState.contains("final class EngineHandleState: Sendable"))
        #expect(!searchIndex.contains("@unchecked Sendable"))
        #expect(searchIndex.contains("private final class OffloadedSearchState<T: Sendable>: Sendable"))
        #expect(searchIndex.contains("private final class OffloadedSearchStateBox<T: Sendable>: Sendable"))
        #expect(searchIndex.contains("private final class SQLiteCancellationContext: Sendable"))
        #expect(searchIndex.contains("func passiveCheckpoint() throws"))
        #expect(searchIndex.contains("db.checkpoint(.passive)"))
        #expect(searchIndex.contains("case journalModeRejected(String)"))
    }

    @Test("test helper probes avoid unchecked sendable wrappers")
    func testHelperProbesAvoidUncheckedSendableWrappers() throws {
        let omegaAgentTests = try loadRepoTextFile("EpistemosTests/OmegaAgentTests.swift")
        let noteEditorLayoutTests = try loadRepoTextFile("EpistemosTests/NoteEditorLayoutTests.swift")
        let noteFileStorageTests = try loadRepoTextFile("EpistemosTests/NoteFileStorageTests.swift")
        let pipelineServiceTests = try loadRepoTextFile("EpistemosTests/PipelineServiceTests.swift")
        let vaultSyncAuditTests = try loadRepoTextFile("EpistemosTests/VaultSyncServiceAuditTests.swift")
        let textKit2FoundationTests = try loadRepoTextFile("EpistemosTests/TextKit2FoundationTests.swift")

        #expect(!omegaAgentTests.contains("@unchecked Sendable"))
        #expect(!noteEditorLayoutTests.contains("@unchecked Sendable"))
        #expect(noteEditorLayoutTests.contains("private final class LayoutNotificationCounts: Sendable"))
        #expect(!noteFileStorageTests.contains("@unchecked Sendable"))
        #expect(noteFileStorageTests.contains("private final class EventSink: Sendable"))
        #expect(!pipelineServiceTests.contains("@unchecked Sendable"))
        #expect(pipelineServiceTests.contains("private final class ActivityProbe: Sendable"))
        #expect(!vaultSyncAuditTests.contains("@unchecked Sendable"))
        #expect(vaultSyncAuditTests.contains("final class ManagedBodyCountProbe: Sendable"))
        #expect(!textKit2FoundationTests.contains("@unchecked Sendable"))
        #expect(textKit2FoundationTests.contains("private final class NotificationRecorder: Sendable"))
    }

    @Test("startup integrity check runs before automatic vault restore")
    func startupIntegrityCheckRunsBeforeAutomaticVaultRestore() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(bootstrap.contains("struct StartupIntegrityReport: Sendable"))
        #expect(bootstrap.contains("func performStartupIntegrityCheck() async -> StartupIntegrityReport"))
        #expect(bootstrap.contains("static func startupIntegritySamplePageIdsForTesting"))
        #expect(bootstrap.contains("static func startupIntegrityReportForTesting"))
        #expect(bootstrap.contains("vaultSync.startupBookmarkValidation()"))
        #expect(bootstrap.contains("func runAutomaticVaultRestoreAfterLaunchIfNeeded() async"))
        #expect(bootstrap.contains("let report = await performStartupIntegrityCheck()"))
        #expect(bootstrap.contains("guard !report.shouldBlockAutomaticVaultRestore else"))
        #expect(bootstrap.contains("vaultSync.restoreVaultFromBookmark()"))
        #expect(app.contains("await bootstrap.runAutomaticVaultRestoreAfterLaunchIfNeeded()"))
        #expect(vaultSync.contains("func startupBookmarkValidation() -> VaultBookmarkStartupValidation"))
    }

    @Test("body migration cleans up managed note files when persistence fails")
    func bodyMigrationCleansUpManagedBodiesWhenSaveFails() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(bootstrap.contains("func migrateInlineBodiesToFiles() throws -> Int"))
        #expect(bootstrap.contains("NoteFileStorage.writeBody(pageId: page.id, content: page.body)"))
        #expect(bootstrap.contains("modelContext.rollback()"))
        #expect(bootstrap.contains("NoteFileStorage.deleteBody(pageId: pageId)"))
    }

    @Test("vault export paths abort when pre-export persistence fails")
    func vaultExportPathsAbortWhenPreExportPersistenceFails() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let normalized = source.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        #expect(normalized.range(of: #"Failed to save before page export.*return nil"#, options: .regularExpression) != nil)
        #expect(normalized.range(of: #"Failed to save before dirty pages export.*return nil"#, options: .regularExpression) != nil)
    }

    @Test("launch integrity gate lives above RootView and owns automatic vault restore")
    func launchIntegrityGateLivesAboveRootViewAndOwnsAutomaticVaultRestore() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(app.contains("private struct LaunchIntegrityGateView<Content: View>: View"))
        #expect(app.contains("await bootstrap.runAutomaticVaultRestoreAfterLaunchIfNeeded()"))
        #expect(app.contains("await bootstrap.performPrimaryLaunchInitialization()"))
        #expect(app.contains("LaunchIntegrityGateView(bootstrap: bootstrap)"))
        #expect(!rootView.contains("performStartupIntegrityCheck"))
        #expect(!rootView.contains("restoreVaultFromBookmark"))
    }

    @Test("primary launch initialization defers agent env keychain hydration off the main thread")
    func primaryLaunchInitializationDefersAgentEnvKeychainHydrationOffTheMainThread() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(bootstrap.contains("Task.detached(priority: .utility)"))
        #expect(bootstrap.contains("Self.populateAgentCoreEnvironment()"))
        #expect(!bootstrap.contains("// in-process Rust agent_core providers can read them via std::env::var.\n        Self.populateAgentCoreEnvironment()"))
    }

    @Test("launch bootstrap leaves App Shortcuts refresh user initiated")
    func launchBootstrapLeavesAppShortcutsRefreshUserInitiated() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(!bootstrap.contains("EpistemosShortcutsProvider.updateAppShortcutParameters()"))
        #expect(settings.contains("Button(\"Refresh Siri Shortcuts\")"))
        #expect(settings.contains("EpistemosShortcutsProvider.updateAppShortcutParameters()"))
    }

    @Test("launch agent env hydration skips duplicate work while deferred cloud bootstrap is active")
    func launchAgentEnvHydrationSkipsDuplicateWorkWhileDeferredCloudBootstrapIsActive() {
        #expect(
            !AppBootstrap.shouldPopulateAgentCoreEnvironmentAtLaunch(
                deferredCloudCredentialBootstrapInFlight: true
            )
        )
        #expect(
            AppBootstrap.shouldPopulateAgentCoreEnvironmentAtLaunch(
                deferredCloudCredentialBootstrapInFlight: false,
                launchKeychainAccessAllowed: true
            )
        )
        #expect(
            !AppBootstrap.shouldPopulateAgentCoreEnvironmentAtLaunch(
                deferredCloudCredentialBootstrapInFlight: false,
                launchKeychainAccessAllowed: false
            )
        )
    }

    @Test("skip-restore audit launches purge saved state and avoid startup keychain reads")
    func skipRestoreAuditLaunchesPurgeSavedStateAndAvoidStartupKeychainReads() {
        let skipRestoreEnvironment = ["EPISTEMOS_SKIP_VAULT_RESTORE": "1"]

        #expect(
            SavedApplicationStatePurger.shouldPurgeAtLaunch(
                processInfoEnvironment: skipRestoreEnvironment
            )
        )
        #expect(
            !AppBootstrap.shouldReadKeychainAtLaunch(
                processInfoEnvironment: skipRestoreEnvironment
            )
        )
        #expect(
            !InferenceState.shouldDeferCloudCredentialBootstrapOnLaunch(
                isRunningTests: false,
                processInfoEnvironment: skipRestoreEnvironment
            )
        )
        #expect(
            !InferenceState.shouldSkipCloudCredentialBootstrapOnLaunch(
                processInfoEnvironment: skipRestoreEnvironment
            )
        )
        #expect(
            !SavedApplicationStatePurger.shouldPurgeAtLaunch(
                processInfoEnvironment: [:]
            )
        )
        #expect(
            AppBootstrap.shouldReadKeychainAtLaunch(
                processInfoEnvironment: [:]
            )
        )
        #expect(
            InferenceState.shouldDeferCloudCredentialBootstrapOnLaunch(
                isRunningTests: false,
                processInfoEnvironment: [:]
            )
        )
        #expect(
            !InferenceState.shouldSkipCloudCredentialBootstrapOnLaunch(
                processInfoEnvironment: [:]
            )
        )
    }

    @Test("test inference bootstrap skips legacy key migration but still refreshes cached credentials")
    func testInferenceBootstrapSkipsLegacyKeyMigrationButStillRefreshesCachedCredentials() throws {
        let source = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let normalized = source.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        #expect(
            normalized.range(
                of: #"if Self\.isRunningTests \{ refreshCachedCloudAPIKeys\(\) \} else \{ migrateLegacyCloudAPIKeysIfNeeded\(\) refreshCachedCloudAPIKeys\(\) \}"#,
                options: .regularExpression
            ) != nil
        )
    }

    @Test("initial vault import is offloaded through a nonisolated helper")
    func initialVaultImportIsOffloadedThroughNonisolatedHelper() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(vaultSync.contains("await Self.performInitialImport("))
        #expect(vaultSync.contains("private nonisolated static func performInitialImport("))
        #expect(vaultSync.contains("private nonisolated static func rebuildInstantRecallIndex("))
    }

    @Test("instant recall rebuild snapshots SwiftData page primitives before awaiting body reads")
    func instantRecallRebuildSnapshotsSwiftDataPagePrimitivesBeforeAwaitingBodyReads() throws {
        let actor = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(actor.contains("private struct PageIndexingSnapshot: Sendable"))
        #expect(actor.contains("let snapshot = PageIndexingSnapshot(page: page)"))
        #expect(actor.contains("out.append((snapshot.id, snapshot.title, body, snapshot.tagsJoined, snapshot.updatedAt))"))
        #expect(!actor.contains("let body = await bodyForIndexing(page)\n        return (page.title, body, page.tags.joined(separator: \" \"), page.updatedAt)"))
        #expect(!actor.contains("let body = await bodyForIndexing(page)\n            out.append((page.id, page.title, body, page.tags.joined(separator: \" \"), page.updatedAt))"))
    }

    @Test("shared scheme keeps test bundle out of normal app builds")
    func sharedSchemeKeepsTestBundleOutOfNormalAppBuilds() throws {
        let scheme = try loadRepoTextFile("Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme")
        let spec = try loadRepoTextFile("project.yml")
        let buildAction = scheme.components(separatedBy: "<TestAction").first ?? scheme

        #expect(spec.contains("targets:\n        Epistemos: all"))
        #expect(!spec.contains("EpistemosTests: test"))
        #expect(scheme.contains("BlueprintName = \"EpistemosTests\""))
        #expect(scheme.contains("buildForTesting = \"YES\""))
        #expect(scheme.contains("buildForRunning = \"YES\""))
        #expect(scheme.contains("buildForProfiling = \"YES\""))
        #expect(scheme.contains("buildForArchiving = \"YES\""))
        #expect(!buildAction.contains("BuildableName = \"EpistemosTests.xctest\""))
    }

    @Test("retired local model installer stays deleted")
    func retiredLocalModelInstallerStaysDeleted() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let infrastructure = try loadRepoTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")
        let environment = try loadRepoTextFile("Epistemos/App/AppEnvironment.swift")

        #expect(!repoFileExists("Epistemos/Engine/ModelDownloadManager.swift"))
        #expect(!repoFileExists("EpistemosTests/ModelStackInstallTests.swift"))
        #expect(!repoFileExists("EpistemosTests/ModelDownloadGgufVerifyTests.swift"))
        #expect(!bootstrap.contains("LocalModelManager("))
        #expect(!bootstrap.contains("ModelDownloadManager("))
        #expect(!environment.contains("localModelManager"))
        #expect(!infrastructure.contains("final class LocalModelManager"))
        #expect(!infrastructure.contains("LocalModelInstallManifest"))
    }

    @MainActor
    @Test("bootstrap propagates prepared retrieval assets into the live graph and query runtime")
    func bootstrapPropagatesPreparedRetrievalAssets() async throws {
        let bootstrap = AppBootstrap()
        await bootstrap.loadPreparedModelRegistryForTesting()

        #expect(bootstrap.preparedModelRegistryState.primaryRetriever?.servedModelID == "BAAI/bge-m3")

        let graphAssets = try #require(bootstrap.graphState.preparedRetrievalRuntimeConfiguration)
        let queryAssets = try #require(bootstrap.queryEngine.preparedRetrievalRuntimeConfiguration)
        let embeddingAssets = try #require(bootstrap.graphState.embeddingService.preparedRetrievalRuntimeConfiguration)

        #expect(graphAssets.retriever.servedModelID == "BAAI/bge-m3")
        #expect(graphAssets.retriever.resolvedDownloadPath?.hasSuffix("/PreparedModels/retrieval/bge-m3/source") == true)
        #expect(queryAssets == graphAssets)
        #expect(embeddingAssets == graphAssets)
    }

    @MainActor
    @Test("bootstrap surfaces the prepared retrieval runtime state from the live asset layout")
    func bootstrapSurfacesThePreparedRetrievalRuntimeStateFromTheLiveAssetLayout() async throws {
        let bootstrap = AppBootstrap()
        await bootstrap.loadPreparedModelRegistryForTesting()
        let configuration = try #require(bootstrap.preparedModelRegistryState.retrievalRuntimeConfiguration)
        let layout = try #require(configuration.assetLayout)

        #expect(layout.retrieverSourceRoot.hasSuffix("/PreparedModels/retrieval/bge-m3/source"))
        if let manifest = layout.indexManifest {
            #expect(FileManager.default.fileExists(atPath: layout.embeddingsPath))
            #expect(FileManager.default.fileExists(atPath: layout.documentsPath))
            #expect(manifest.documentCount > 8)
            #expect(manifest.sourceDatabasePath?.hasSuffix("/Epistemos/search.sqlite") == true)
            #expect(manifest.sourceDatabaseModifiedAt != nil)
        } else {
            #expect(!layout.isBuilt)
        }

        let allowedModes: [PreparedRetrievalExecutionMode] = [
            .preparedIndexReady(retrieverModelID: "BAAI/bge-m3"),
            .preparedAssetsPendingIndex(retrieverModelID: "BAAI/bge-m3"),
            .appleEmbeddingFallback,
        ]
        #expect(allowedModes.contains(where: { $0 == bootstrap.graphState.preparedRetrievalExecutionMode }))
        #expect(allowedModes.contains(where: { $0 == bootstrap.queryEngine.preparedRetrievalExecutionMode }))
        #expect(allowedModes.contains(where: { $0 == bootstrap.graphState.embeddingService.preparedRetrievalExecutionMode }))
    }

    @Test("settings inference surface does not refresh local models on open")
    func settingsInferenceSurfaceDoesNotRefreshOnOpen() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("Button(\"Refresh\")"))
        #expect(!settings.contains(".onAppear {\n            localModelManager.refreshFromDisk()"))
        #expect(!settings.contains(".task {\n            localModelManager.refreshFromDisk()"))
    }

    @Test("settings, graph, and note workspace surfaces defer on-appear state mutations off the active view update")
    func nonChatStatefulSurfacesDeferOnAppearMutations() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(settings.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(inspector.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(workspace.contains(".onAppear {\n                Task { @MainActor in"))
    }

    @Test("settings window keeps a native source-list layout with a persistent sidebar toggle")
    func settingsWindowUsesNativeSourceListChrome() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let utilityManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(settings.contains(".listStyle(.sidebar)"))
        #expect(settings.contains("Image(systemName: \"sidebar.left\")"))
        #expect(settings.contains("ToolbarItem(placement: .navigation)"))
        #expect(settings.contains("toggleSidebar()"))
        #expect(utilityManager.contains("toolbar.showsBaselineSeparator = false"))
        #expect(utilityManager.contains("panel.toolbarStyle = .unifiedCompact"))
    }

    @Test("utility panels activate and order front when shown")
    func utilityPanelsActivateAndOrderFrontWhenShown() throws {
        let utilityManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(utilityManager.contains("NSApp.activate(ignoringOtherApps: true)"))
        #expect(utilityManager.contains("window.orderFrontRegardless()"))
        #expect(utilityManager.contains("window.makeKeyAndOrderFront(nil)"))
    }

    // "legacy omega utility routing surfaces home without deleted chat state" removed with
    // cloud-only/Omega removal 2026-07-03 — the .omega UtilityPanel and its routing handler
    // (if panel == .omega / routeOmegaPanelToMainChat()) were deleted from UtilityWindowManager.

    @Test("bootstrap removes native agent chat state with deleted chat surface")
    func bootstrapRemovesNativeAgentChatStateWithDeletedChatSurface() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!bootstrap.contains("let agentChatState = AgentChatState()"))
        #expect(!bootstrap.contains("agentChatState.eventBus = eventBus"))
        #expect(!bootstrap.contains("chatState.primeComposerDraft(trimmed)"))
        #expect(!bootstrap.contains("chatState.showLanding = false"))
        #expect(!bootstrap.contains("func presentAgentCommandCenter("))
        #expect(!bootstrap.contains("func submitAgentWorkspacePrompt("))
        #expect(!bootstrap.contains("routeLegacyAgentSurfaceIntoMainChat("))
        #expect(!bootstrap.contains("agentCommandCenterState.present()"))
    }

    @Test("note editor still suppresses binding sync churn during AI token flushes")
    func noteEditorStillSuppressesStreamingBindingChurn() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(source.contains("var isFlushingTokens = false"))
        #expect(source.contains("guard !isFlushingTokens else { return }"))
        #expect(source.contains("Task.sleep(for: .milliseconds(300))"))
    }

    @Test("query runtime hot path avoids legacy full-match node sorting")
    func queryRuntimeHotPathAvoidsLegacyFullMatchNodeSorting() throws {
        let source = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(!source.contains("Array(graphStore.nodes.values)"))
        #expect(!source.contains("Array(graphStore.edges.values)"))
        #expect(!source.contains("Set(graphStore.nodes.keys)"))
        #expect(!source.contains("graphStore.nodes.values.compactMap"))
        #expect(!source.contains("graphStore.edgesByNode[scopedNodeID]"))
        #expect(!source.contains("graphStore.nodes.values.filter"))
        #expect(!source.contains("from: graphStore.nodes.values"))
        #expect(!source.contains("results.sort { $0.createdAt > $1.createdAt }"))
        #expect(source.contains("graphStore.nodes(matchingLabelContains: labelContains, types: filter.types)"))
        #expect(source.contains("graphStore.edges(for: scopedNodeID)"))
        #expect(source.contains("graphStore.nodes(matchingLabelContains: text)"))
        #expect(source.contains("graphStore.firstNode(ofType: type)?.id"))
        #expect(source.contains("graphStore.forEachNodeNewestFirst(ofTypes: filter.types)"))
        #expect(source.contains("graphStore.forEachNodeNewestFirst { node in"))
        #expect(!source.contains("graphStore.nodes.values.first { $0.type == type }"))
        #expect(!source.contains("graphStore.adjacency[$0.id]"))
        #expect(!source.contains("graphStore.adjacency[$1.id]"))
        #expect(!source.contains("graphStore.nodes[$0.id]?.createdAt"))
        #expect(!source.contains("graphStore.nodes[$1.id]?.createdAt"))
        #expect(!source.contains("graphStore.nodes[$0.id]?.updatedAt"))
        #expect(!source.contains("graphStore.nodes[$1.id]?.updatedAt"))
        #expect(source.contains("if $0.connectionCount == $1.connectionCount"))
        #expect(source.contains("return $0.connectionCount > $1.connectionCount"))
        #expect(source.contains("let a = $0.createdAt"))
        #expect(source.contains("let b = $1.createdAt"))
        #expect(source.contains("let a = $0.updatedAt"))
        #expect(source.contains("let b = $1.updatedAt"))
    }

    @Test("graph store source lookup uses the direct source index")
    func graphStoreSourceLookupUsesDirectSourceIndex() throws {
        let source = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")

        #expect(source.contains("private var _sourceLookup: [SourceLookupKey: String] = [:]"))
        #expect(source.contains("let key = SourceLookupKey(sourceId: sourceId, type: type)"))
        #expect(source.contains("_sourceLookup[key]"))
        #expect(!source.contains("nodes.values.first { $0.sourceId == sourceId && $0.type == type }"))
    }

    @Test("graph store type lookup uses the direct type index")
    func graphStoreTypeLookupUsesDirectTypeIndex() throws {
        let source = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")

        #expect(source.contains("private var _typeLookup: [GraphNodeType: Set<String>] = [:]"))
        #expect(source.contains("(_typeLookup[type] ?? []).compactMap { nodes[$0] }"))
        #expect(source.contains("func nodes(ofTypes types: [GraphNodeType]) -> [GraphNodeRecord]"))
        #expect(source.contains("guard let nodeID = _typeLookup[type]?.first else { return nil }"))
        #expect(!source.contains("nodes.values.filter { $0.type == type }"))
    }

    @Test("semantic clustering stays behind apple fallback and the shared embedding boundary")
    func semanticClusteringStaysBehindAppleFallbackAndSharedEmbeddingBoundary() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let clustering = try loadRepoTextFile("Epistemos/Graph/SemanticClusterService.swift")
        let embeddings = try loadRepoTextFile("Epistemos/Graph/EmbeddingService.swift")
        let infrastructure = try loadRepoTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")
        let controls = try loadRepoTextFile("Epistemos/Views/Graph/GraphFloatingControls.swift")

        #expect(graphState.contains("var semanticClusteringAvailable: Bool"))
        #expect(graphState.contains("guard semanticClusteringAvailable else"))
        #expect(graphState.contains("func canRunFallbackSemanticSearch() -> Bool"))
        #expect(graphState.contains("func semanticSearch(query: String, limit: Int = 20)"))
        #expect(graphState.contains("for hit in semanticSearch(query: query, limit: limit)"))
        #expect(graphState.contains("embeddingService.computeFallbackSemanticClusters(store: store)"))
        #expect(!clustering.contains("NLEmbedding.wordEmbedding"))
        #expect(infrastructure.contains("var usesSwiftEmbeddingFallback: Bool"))
        #expect(embeddings.contains("swiftEmbeddingFallbackActive = preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback"))
        #expect(embeddings.contains("preparedQueryEmbeddingActive = preparedRetrievalExecutionMode.hasPreparedIndexRuntime"))
        #expect(embeddings.contains("guard swiftEmbeddingFallbackActive || preparedQueryEmbeddingActive else { return nil }"))
        #expect(embeddings.contains("guard swiftEmbeddingFallbackActive else { return [:] }"))
        #expect(graphState.contains("private func preparedSemanticSearch(query: String, limit: Int) -> [GraphStore.SearchHit]?"))
        #expect(graphState.contains("manifestPath.withCString"))
        #expect(graphState.contains("graph_engine_load_prepared_retrieval_index(engine, $0)"))
        #expect(graphState.contains("graph_engine_prepared_retrieval_search("))
        #expect(!controls.contains("semanticClusterToggle"))
        #expect(!controls.contains(".disabled(!available)"))
    }

    @Test("graph bootstrap defers hybrid embedding lookup construction until semantic work begins")
    func graphBootstrapDefersHybridEmbeddingLookupConstruction() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let embeddings = try loadRepoTextFile("Epistemos/Graph/EmbeddingService.swift")

        #expect(graphState.contains("DeferredTextEmbeddingLookup"))
        #expect(graphState.contains("embeddingLookup: DeferredTextEmbeddingLookup {"))
        #expect(graphState.contains("AppleHybridEmbeddingLookup()"))
        #expect(!graphState.contains("EmbeddingService(embeddingLookup: AppleHybridEmbeddingLookup())"))
        #expect(embeddings.contains("nonisolated struct DeferredTextEmbeddingLookup"))
        #expect(embeddings.contains("DeferredTextEmbeddingLookup: TextEmbeddingLookup"))
        #expect(embeddings.contains("DeferredTextEmbeddingLookupStorage"))
    }

    @Test("fallback semantic query path requires a populated matching Rust embedding store")
    func fallbackSemanticQueryPathRequiresPopulatedMatchingRustStore() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(graphState.contains("func canRunFallbackSemanticSearch() -> Bool"))
        #expect(graphState.contains("func semanticSearch(query: String, limit: Int = 20)"))
        #expect(graphState.contains("graph_engine_embedding_count(engine) > 0"))
        #expect(graphState.contains("Int(graph_engine_embedding_dimension(engine)) == embeddingService.dimension"))
        #expect(queryRuntime.contains("graphState.semanticSearch(query: query, limit: limit)"))
    }

    @Test("native semantic runtime exposes an explicit dimension reset boundary")
    func nativeSemanticRuntimeExposesDimensionResetBoundary() throws {
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")
        let swiftWrapper = try loadRepoTextFile("Epistemos/Graph/GraphEngine.swift")

        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_embedding_dimension"))
        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_reset_embedding_dimension"))
        #expect(header.contains("uint32_t graph_engine_embedding_dimension(Engine* engine);"))
        #expect(header.contains("uint8_t graph_engine_reset_embedding_dimension(Engine* engine, uint32_t dim);"))
        #expect(swiftWrapper.contains("func semanticEmbeddingDimension() -> Int"))
        #expect(swiftWrapper.contains("func resetSemanticEmbeddingDimension(to dimension: Int) -> Bool"))
    }

    @Test("retired graph ffi controls stay out of the live bridge surface")
    func retiredGraphFFIControlsStayRemoved() throws {
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")

        let retiredExports = [
            "graph_engine_set_lite_mode",
            "graph_engine_set_time_filter",
            "graph_engine_add_version",
            "graph_engine_get_version_count",
            "graph_engine_dialogue_open",
            "graph_engine_dialogue_close",
            "graph_engine_dialogue_set_streaming",
            "graph_engine_dialogue_screen_rect",
            "graph_engine_dialogue_node_screen_pos",
            "graph_engine_dialogue_is_active",
        ]

        for symbol in retiredExports {
            #expect(!rustFFI.contains(symbol))
            #expect(!header.contains(symbol))
        }
    }

    @Test("live local ai surfaces stay free of sidecar residue")
    func liveLocalAISurfacesStayFreeOfSidecarResidue() throws {
        let llm = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        for banned in [
            "LocalSidecar",
            "mlx-openai-server",
            "http://127.0.0.1",
        ] {
            #expect(!llm.contains(banned))
            #expect(!triage.contains(banned))
            #expect(!inference.contains(banned))
        }
    }

    @Test("native cleanup fallback grep uses word boundaries for legacy runtime bans")
    func nativeCleanupFallbackGrepUsesWordBoundaries() throws {
        let scan = try loadRepoTextFile("scripts/audit/native_cleanup_scan.sh")

        #expect(scan.contains(#"\\breasoner\\b"#))
        #expect(scan.contains(#"\\bSSE\\b"#))
        #expect(!scan.contains("|SSE'"))
        #expect(scan.contains("ast-grep scan --rule"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Engine"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Graph"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Views/Graph"))
        #expect(scan.contains("periphery scan --project Epistemos.xcodeproj --schemes Epistemos --targets Epistemos --format xcode"))
        #expect(scan.contains("cd '${ROOT_DIR}/graph-engine' && cargo machete"))
    }

    @Test("prepared retrieval scorer uses a dedicated candidate list ffi")
    func preparedRetrievalScorerUsesDedicatedCandidateListFFI() throws {
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")

        #expect(queryRuntime.contains("graph_engine_prepared_retrieval_score_page_ids("))
        #expect(queryRuntime.contains("graph_engine_free_prepared_retrieval_candidates(list)"))
        #expect(queryRuntime.contains("result.page_id"))
        #expect(!queryRuntime.contains("graph_engine_free_search_results(results, count)"))
        #expect(header.contains("GraphEnginePreparedRetrievalCandidate"))
        #expect(header.contains("GraphEnginePreparedRetrievalCandidateList"))
        #expect(header.contains("graph_engine_free_prepared_retrieval_candidates"))
        #expect(rustFFI.contains("pub struct GraphEnginePreparedRetrievalCandidate"))
        #expect(rustFFI.contains("pub struct GraphEnginePreparedRetrievalCandidateList"))
        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_free_prepared_retrieval_candidates"))
    }

    @Test("strict verification suite keeps compiler and purge gates wired")
    func strictVerificationSuiteKeepsCompilerAndPurgeGatesWired() throws {
        let verify = try loadRepoTextFile("scripts/audit/verify.sh")
        let cleanupSuite = try loadRepoTextFile("scripts/audit/cleanup_suite.sh")

        #expect(verify.contains("cargo clippy --manifest-path graph-engine/Cargo.toml --all-targets --all-features -- -D warnings -D dead_code"))
        #expect(verify.contains("cargo test --manifest-path graph-engine/Cargo.toml"))
        #expect(verify.contains("native_cleanup_scan.sh"))
        #expect(verify.contains("OTHER_SWIFT_FLAGS='\\$(inherited) -Xfrontend -strict-concurrency=complete'"))
        #expect(verify.contains("MallocStackLogging=1"))
        #expect(verify.contains("leaks Epistemos"))
        #expect(verify.contains("powermetrics --samplers gpu_power"))
        #expect(cleanupSuite.contains("./scripts/audit/verify.sh"))
    }

    @Test("landing surface no longer mounts live cursor fx overlays or controls")
    func landingSurfaceNoLongerMountsLiveCursorFXOverlaysOrControls() throws {
        let landingView = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let pageShell = try loadRepoTextFile("Epistemos/Views/Shell/PageShell.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")
        let liquidGreeting = try loadRepoTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(!landingView.contains("currentCursorSurface"))
        #expect(!landingView.contains("landingWakeVocabulary"))
        #expect(!landingView.contains("ui.landingCursorVisibilityMode.shows(on: surface)"))
        #expect(!landingView.contains("pointerState.registerTap(at: value.location)"))
        #expect(!landingView.contains("LandingASCIIWakeField"))
        #expect(!landingView.contains("LandingPointerState"))
        #expect(!rootView.contains("Cursor FX"))
        #expect(!rootView.contains("LandingCursorControlsView"))
        #expect(!rootView.contains("cursorVisible"))
        #expect(!settings.contains("Cursor Visibility"))
        #expect(!settings.contains("Cursor Animation"))
        #expect(!liquidGreeting.contains("cursorBlinkLoop"))
        #expect(liquidGreeting.contains("search cursor blink"))
        #expect(!pageShell.contains("cursorVisible"))
        #expect(!uiState.contains("var landingCursorAnimationEnabled"))
        #expect(!uiState.contains("var landingCursorVisibilityMode"))
        #expect(uiState.contains("\"epistemos.landingCursorAnimationEnabled\""))
    }

    @Test("landing greeting rechecks window occlusion after appear so typewriter can start once the home window is key")
    func landingGreetingRechecksWindowOcclusionAfterAppear() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let landingView = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let liquidGreeting = try loadRepoTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(liquidGreeting.contains("!windowOccluded && typewriterEnabled"))
        #expect(landingView.contains("windowOccluded: ui.windowOccluded"))
        #expect(landingView.contains("typewriterEnabled: ui.landingGreetingTypewriterEnabled"))
        #expect(!liquidGreeting.contains("ui.activePanel == .home &&"))
        #expect(landingView.contains("LandingViewStateSync"))
        #expect(landingView.contains("LandingViewStateSync.reassertHomeSurface(ui)"))
        #expect(rootView.contains("HomeWindowIdentity.apply(to: window)"))
        #expect(rootView.contains(".background(HomeWindowIdentityObserver(themeIsDark: ui.theme.isDark))"))
        #expect(rootView.contains(".onAppear {"))
        #expect(rootView.contains("updateWindowOcclusion()"))
        #expect(rootView.contains("try await Task.sleep(for: .milliseconds(150))"))
        #expect(rootView.contains("updateWindowOcclusion()"))
    }

    @Test("command palette source files are removed from the app")
    func commandPaletteSourceFilesAreRemoved() throws {
        let repoRoot = try sourceMirrorRootURL()

        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/CommandPaletteOverlay.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/CommandPaletteWindowController.swift").path))
    }

    @Test("search index uses a user-initiated query queue for interactive full text search")
    func searchIndexUsesUserInitiatedQueryQueueForInteractiveSearch() throws {
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(searchIndex.contains("DatabasePool"))
        #expect(searchIndex.contains("label: \"com.epistemos.search-index.query\""))
        #expect(searchIndex.contains("attributes: .concurrent"))
        #expect(searchIndex.contains("try await offloadSearch { [self, terms, limit] cancellation in"))
        #expect(searchIndex.contains("try await offloadSearch { [self, sanitized, weights, now] cancellation in"))
        #expect(searchIndex.contains("private final class OffloadedSearchStateBox"))
        #expect(searchIndex.contains("private struct OffloadedSearchCancellationProbe"))
        #expect(searchIndex.contains("private final class SQLiteCancellationContext"))
        #expect(searchIndex.contains("func check() throws"))
        #expect(searchIndex.contains("try cancellation.check()"))
        #expect(searchIndex.contains("let cancellation = OffloadedSearchCancellationProbe {"))
        #expect(searchIndex.contains("currentState.isCancelled()"))
        #expect(searchIndex.contains("return try await withTaskCancellationHandler"))
        #expect(searchIndex.contains("stateBox.cancel()"))
        #expect(searchIndex.contains("private nonisolated static func withSQLiteCancellation"))
        #expect(searchIndex.contains("sqlite3_progress_handler("))
    }

    @Test("notes sidebar caches title matches outside the render path")
    func notesSidebarCachesTitleMatchesOutsideRenderPath() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(sidebar.contains("enum NotesSidebarSearchCachePolicy"))
        #expect(sidebar.contains("static let maxCachedQueries = 12"))
        #expect(sidebar.contains("@State private var titleSearchResults: [SidebarPageItem] = []"))
        #expect(sidebar.contains("@State private var cachedPageSearchCatalog: [SidebarPageSearchCatalogEntry] = []"))
        #expect(sidebar.contains("@State private var cachedPageSearchCatalogById: [String: SidebarPageSearchCatalogEntry] = [:]"))
        #expect(sidebar.contains("@State private var cachedPageSearchTrigramIndex = TrigramSearchIndex<String>()"))
        #expect(sidebar.contains("@State private var cachedTitleSearchResultIDsByQuery: [String: [String]] = [:]"))
        #expect(sidebar.contains("@State private var cachedBodySearchResultsByQuery: [String: [SidebarPageItem]] = [:]"))
        #expect(sidebar.contains("@State private var cachedTitleSearchQueryOrder: [String] = []"))
        #expect(sidebar.contains("@State private var cachedBodySearchQueryOrder: [String] = []"))
        #expect(sidebar.contains("refreshTitleSearchResults(query: notesUI.searchQuery)"))
        #expect(sidebar.contains("titleSearchResults + uniqueBodyMatches"))
        #expect(sidebar.contains("cachedPageSearchTrigramIndex.rebuild("))
        #expect(sidebar.contains("private func longestCachedTitleSearchPrefixIDs(for query: String) -> [String]?"))
        #expect(sidebar.contains("let matchedIDs = cachedTitleSearchResultIDsByQuery[normalizedQuery] ?? {"))
        #expect(sidebar.contains("let candidateIDs = longestCachedTitleSearchPrefixIDs(for: normalizedQuery)"))
        #expect(sidebar.contains("cachedPageSearchTrigramIndex.orderedCandidates(for: normalizedQuery)"))
        #expect(sidebar.contains("NotesSidebarSearchCachePolicy.store("))
        #expect(sidebar.contains("guard normalizedQuery.count >= 3 else"))
        #expect(sidebar.contains("if let cached = cachedBodySearchResultsByQuery[normalizedQuery]"))
        #expect(sidebar.contains("cache: &cachedBodySearchResultsByQuery"))
        #expect(sidebar.contains("private func refreshTitleSearchResults(query: String)"))
    }

    @Test("notes sidebar cache rebuild observes folder structure and offloads epdoc package scans")
    func notesSidebarCacheRebuildObservesFolderStructureAndOffloadsEpdocScans() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(sidebar.contains("struct NotesSidebarFolderCacheSignature"))
        #expect(sidebar.contains("@State private var cachedFolderCacheSignature: [NotesSidebarFolderCacheSignature] = []"))
        #expect(sidebar.contains("let newPageItemsByFolderId = Dictionary("))
        #expect(sidebar.contains("NotesSidebarFolderCacheSignature("))
        #expect(sidebar.contains("newFolderSignature == cachedFolderCacheSignature"))
        #expect(sidebar.contains("cachedFolderCacheSignature = newFolderSignature"))
        #expect(!sidebar.contains("allFolders.count == cachedFolderItems.count"))
        #expect(!sidebar.contains("childPageIds = (folder.pages ?? [])"))
        #expect(!sidebar.contains("let pages = (folder.pages ?? [])"))

        #expect(sidebar.contains("@State private var epdocDocumentScanTask: Task<Void, Never>?"))
        #expect(sidebar.contains("private func refreshEpdocDocuments"))
        #expect(sidebar.contains("Task.detached(priority: .utility)"))
        #expect(sidebar.contains("private nonisolated static func scanEpdocDocuments"))
        #expect(sidebar.contains("private nonisolated static func epdocTitle"))
        #expect(!sidebar.contains("cachedDocumentItems = Self.scanEpdocDocuments(in: vaultSync.vaultURL)"))
    }

    @Test("large vault imports refresh sidebar folders at batch checkpoints")
    func largeVaultImportsRefreshSidebarFoldersAtBatchCheckpoints() throws {
        let indexActor = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(indexActor.contains("let batchSize = 200"))

        guard let saveRange = indexActor.range(
            of: "try saveImportProgress(\"vault import batch progress\")"
        ) else {
            Issue.record("Missing batch progress save before folder synthesis")
            return
        }
        guard let synthesizeRange = indexActor.range(
            of: "try synthesizeFoldersFromSubfolders()",
            range: saveRange.upperBound..<indexActor.endIndex
        ) else {
            Issue.record("Missing folder synthesis after batch progress save")
            return
        }
        guard let progressLogRange = indexActor.range(
            of: "log.info(\"Vault import progress:",
            range: synthesizeRange.upperBound..<indexActor.endIndex
        ) else {
            Issue.record("Missing progress log after batch folder synthesis")
            return
        }

        #expect(saveRange.lowerBound < synthesizeRange.lowerBound)
        #expect(synthesizeRange.lowerBound < progressLogRange.lowerBound)
    }

    @Test("graph selection ignores redundant same-node picks")
    func graphSelectionIgnoresRedundantSameNodePicks() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let graphStore = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(graphState.contains("guard selectedNodeId != id else { return }"))
        #expect(graphStore.contains("func neighborLabels(of nodeId: String) -> [String]"))
        #expect(graphStore.contains("private var neighborLabelsCache: [String: [String]] = [:]"))
        #expect(graphStore.contains("if let cached = neighborLabelsCache[nodeId]"))
        #expect(inspectorState.contains("let linkedLabels = store.neighborLabels(of: nodeId)"))
        #expect(!inspectorState.contains("store.neighbors(of: node.id).map(\\.label)"))
    }

    @Test("manual graph mutations clean up transient state when persistence fails")
    func manualGraphMutationsCleanUpTransientStateOnSaveFailure() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")

        #expect(graphState.contains("private func persistManualGraphMutation("))
        #expect(graphState.contains("rollback()"))
        #expect(graphState.contains("guard persistManualGraphMutation("))
        #expect(graphState.contains("store.positionHints.removeValue(forKey: sdNode.id)"))
        #expect(graphState.contains("context.delete(sdNode)"))
        #expect(graphState.contains("context.delete(sdEdge)"))
        #expect(graphState.contains("interactionMode = .idle"))
    }

    @Test("graph selection tracking throttles inspector position churn")
    func graphSelectionTrackingThrottlesInspectorPositionChurn() throws {
        let metalView = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(metalView.contains("nonisolated enum GraphInteractionRenderPolicy"))
        #expect(metalView.contains("static func selectedNodePublishDistance(isInteracting: Bool) -> CGFloat"))
        #expect(metalView.contains("static func selectedNodeSampleIntervalFrames(isInteracting: Bool) -> Int"))
        #expect(metalView.contains("private var sampledSelectedNodeId: String?"))
        #expect(metalView.contains("private var lastPublishedSelectedNodeScreenPoint: CGPoint?"))
        #expect(metalView.contains("private var selectedNodeScreenPointSampleFrame = 0"))
        #expect(metalView.contains("private func resetSelectedNodeScreenPointTracking(for graphState: GraphState?)"))
        #expect(metalView.contains("let selectedNodeSampleIntervalFrames = GraphInteractionRenderPolicy.selectedNodeSampleIntervalFrames("))
        #expect(metalView.contains("selectedNodeScreenPointSampleFrame % selectedNodeSampleIntervalFrames == 0"))
        #expect(metalView.contains("let shouldSampleSelectedNodeScreenPoint ="))
        #expect(metalView.contains("graphState?.selectedNodeScreenPoint == nil"))
        #expect(metalView.contains("lastPublishedSelectedNodeScreenPoint == nil"))
        #expect(metalView.contains("let publishDistance = GraphInteractionRenderPolicy.selectedNodePublishDistance("))
        #expect(metalView.contains("if delta > publishDistance"))
        #expect(overlay.contains("private var inspectorRepositionTask: Task<Void, Never>?"))
        #expect(overlay.contains("private var lastQueuedInspectorAnchor: CGPoint?"))
        #expect(overlay.contains("private var lastQueuedInspectorMode: NodeInspectorState.InspectorMode?"))
        #expect(overlay.contains("Reposition immediately"))
        #expect(overlay.contains("private func shouldQueueInspectorReposition("))
        #expect(overlay.contains("private var lastInspectorFrame: CGRect?"))
        #expect(overlay.contains("private func shouldApplyInspectorFrame(_ targetFrame: CGRect) -> Bool"))
    }

    @Test("graph overlay toolbar defaults to a bottom anchor before drag repositioning")
    func graphOverlayToolbarDefaultsToBottomAnchorBeforeDragRepositioning() throws {
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(overlay.contains("controlsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor"))
        #expect(!overlay.contains("controlsView.topAnchor.constraint(equalTo: contentView.topAnchor"))
    }

    @Test("graph square show paths restore floating chrome after mini mode")
    func graphSquareShowPathsRestoreFloatingChromeAfterMiniMode() throws {
        let controller = try loadRepoTextFile("Epistemos/Views/Graph/HologramController.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(controller.contains("private func presentFullOverlay()"))
        #expect(controller.contains("if overlay?.isMinimized == true"))
        #expect(controller.contains("overlay?.restore()"))
        #expect(controller.contains("overlay?.show()"))
        #expect(controller.contains("func show()"))
        #expect(controller.contains("presentFullOverlay()"))
        #expect(controller.contains("func revealPage(_ pageId: String)"))
        #expect(overlay.contains("restore()"))
        #expect(overlay.contains("restoreFloatingPanelChromeIfNeeded(window, metalView: metalView)"))
        #expect(overlay.contains("metalView.isMiniMode = true"))
        #expect(overlay.contains("prepareImmersiveOverlayWindow(window, screen: NSScreen.main)"))
        #expect(!overlay.contains("guard false else { return }"))
        #expect(!overlay.contains("window.applyPresentation(.immersiveOverlay)"))
    }

    @Test("graph overlay bounds hidden Metal retention with a scheduled teardown")
    func graphOverlayBoundsHiddenMetalRetentionWithAScheduledTeardown() throws {
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(overlay.contains("private var hiddenTeardownTask: Task<Void, Never>?"))
        #expect(overlay.contains("cancelScheduledTeardown()"))
        #expect(overlay.contains("scheduleHiddenTeardown()"))
        #expect(overlay.contains("self?.metalView?.pauseEngine()"))
        #expect(overlay.contains("self?.scheduleHiddenTeardown()"))
        #expect(overlay.contains("GraphOverlayRetentionPolicy.hiddenTeardownDelay"))
        #expect(overlay.contains("guard !self.isMinimized, self.window?.isVisible != true else { return }"))
    }

    @Test("metal graph view wakes idle renderer on power mode changes")
    func metalGraphViewWakesIdleRendererOnPowerModeChanges() throws {
        let metalView = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(metalView.contains("private nonisolated(unsafe) var powerModeObserver: (any NSObjectProtocol)?"))
        #expect(metalView.contains("refreshPowerModeObserver()"))
        #expect(metalView.contains("PowerGuard.modeDidChangeNotification"))
        #expect(metalView.contains("private func applyPowerModeGraphOverrides()"))
        #expect(metalView.contains("graph_engine_set_quality_level(engine, graphState.qualityLevel)"))
        #expect(metalView.contains("pushForceParams()"))
        #expect(metalView.contains("pushExtendedForceParams()"))
        #expect(metalView.contains("self?.applyPowerModeGraphOverrides()"))
    }

    @Test("graph pause path releases drawables and resume restores them before rendering")
    func graphPausePathReleasesDrawablesAndResumeRestoresThem() throws {
        let metalView = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(metalView.contains("layer.maximumDrawableCount = 3"))
        #expect(metalView.contains("private var graphDrawableScale: CGFloat"))
        #expect(metalView.contains("private var currentGraphDrawableScale: CGFloat"))
        #expect(metalView.contains("metalLayer?.contentsScale = GraphDrawableResolutionPolicy.layerContentsScale"))
        #expect(metalView.contains("func pauseEngine()"))
        #expect(metalView.contains("pausedDrawableSize = CGSize(width: 1, height: 1)"))
        #expect(metalView.contains("metalLayer?.drawableSize = GraphDrawableResolutionPolicy.pausedDrawableSize"))
        #expect(metalView.contains("func resumeEngine()"))
        #expect(metalView.contains("updateMetalLayerBackingProperties()"))
    }

    @Test("landing liquid wave click and cursor sources are removed")
    func landingLiquidWaveClickAndCursorSourcesAreRemoved() throws {
        let repoRoot = try sourceMirrorRootURL()
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let pixelComponents = try loadRepoTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        for relativePath in [
            "Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveChoreography.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveOverlay.swift",
            "Epistemos/Shaders/LandingWave.metal",
        ] {
            #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(relativePath).path))
        }
        #expect(!landing.contains("LandingWaveHaptics.fireBeat"))
        #expect(!landing.contains("LandingWaveOverlay("))
        #expect(!landing.contains("landingSearchLiquidReveal("))
        #expect(pixelComponents.contains("landingSearchStepReveal(frame:"))
        #expect(!pixelComponents.contains("LandingSearchLiquidRevealModifier"))
        #expect(!pixelComponents.contains("rippleOpacity"))
    }

    @Test("graph renderer keeps the snappy configurable camera smoothing baseline")
    func graphRendererKeepsTheSnappyCameraBaseline() throws {
        let renderer = try loadRepoTextFile("graph-engine/src/renderer.rs")

        #expect(renderer.contains("camera_lambda: 11.0,"))
        #expect(renderer.contains("const DEFAULT_CAMERA_LAMBDA: f32 = 11.0;"))
    }

    @Test("graph sidebar caches notes tree snapshots across selection churn")
    func graphSidebarCachesNotesTreeSnapshotsAcrossSelectionChurn() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")

        #expect(sidebar.contains("@State private var cachedNotesTreeSnapshot"))
        #expect(sidebar.contains("@State private var cachedNotesTreeTopologyVersion = -1"))
        #expect(sidebar.contains("refreshGraphSidebarCachesIfNeeded()"))
        #expect(sidebar.contains("cachedNotesTreeTopologyVersion != topologyVersion"))
        #expect(sidebar.contains("let snapshot = cachedNotesTreeSnapshot"))
    }

    @Test("graph sidebar keeps notes and query but not graph chat")
    func graphSidebarKeepsNotesAndQueryButNotGraphChat() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let state = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(sidebar.contains("private enum SidebarTab"))
        #expect(sidebar.contains("case .notes"))
        #expect(sidebar.contains("case .query"))
        #expect(!sidebar.contains("case .chat"))
        #expect(sidebar.contains("@AppStorage(\"epistemos.graphSidebarWidth.v1\")"))
        #expect(sidebar.contains("@AppStorage(\"epistemos.graphSidebarHeight.v1\")"))
        #expect(sidebar.contains("@AppStorage(\"epistemos.graphSidebarCollapsed.notesQuery.v1\")"))
        #expect(!sidebar.contains("ChatComposerTextEditor("))
        #expect(!sidebar.contains(".assistantComposerChrome("))
        #expect(!sidebar.contains("graphComposerControlResetKey"))
        #expect(!sidebar.contains("AssistantSendButton("))
        #expect(!sidebar.contains("TextField(\"Ask this node\""))
        #expect(state.contains("enum InspectorMode: Hashable { case profile, editor }"))
        #expect(!inspector.contains("Text(\"Chat\").tag(NodeInspectorState.InspectorMode.chat)"))
        #expect(!inspector.contains("else if inspectorState.inspectorMode == .chat"))
        #expect(!inspector.contains("AssistantToolbarAskBar("))
        #expect(overlay.contains("let sidebarRoot = HologramSearchSidebar("))
    }

    @Test("graph search sidebar renders only on the canvas route")
    func graphSearchSidebarRendersOnlyOnCanvasRoute() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let embedded = try loadRepoTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")

        #expect(sidebar.contains("if graphState.currentRoute.isCanvas"))
        #expect(!sidebar.contains("expandForWorkspaceRoute"))
        #expect(overlay.contains("sidebarHostView?.isHidden = !isCanvas"))
        #expect(overlay.contains("hideGraphRouteInspectorChrome()"))
        #expect(embedded.contains("if graphState.currentRoute.isCanvas"))
    }

    @Test("compact graph inspector typewrites node title and hides keyword chips")
    func compactGraphInspectorTypewritesNodeTitleAndHidesKeywordChips() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let headerStart = try #require(inspector.range(of: "private func compactHeader"))
        let headerEnd = try #require(
            inspector.range(of: "private func compactVitals", range: headerStart.lowerBound..<inspector.endIndex)
        )
        let compactHeader = String(inspector[headerStart.lowerBound..<headerEnd.lowerBound])

        let vitalsStart = headerEnd
        let vitalsEnd = try #require(
            inspector.range(of: "private func compactRelationships", range: vitalsStart.lowerBound..<inspector.endIndex)
        )
        let compactVitals = String(inspector[vitalsStart.lowerBound..<vitalsEnd.lowerBound])

        #expect(compactHeader.contains("TypewriterHeading("))
        #expect(compactHeader.contains("theme.nodeTitleFontName"))
        #expect(compactHeader.contains("compactNodeTitleFontSize"))
        #expect(!compactVitals.contains("focusKeywords"))
        #expect(!compactVitals.contains("compactChip("))
    }

    @Test("compact graph inspector uses blur reveal instead of springy pop")
    func compactGraphInspectorUsesBlurRevealInsteadOfSpringyPop() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let embedded = try loadRepoTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")

        let bodyStart = try #require(inspector.range(of: "var body: some View"))
        let bodyEnd = try #require(
            inspector.range(of: "private func syncSelection", range: bodyStart.lowerBound..<inspector.endIndex)
        )
        let inspectorBody = String(inspector[bodyStart.lowerBound..<bodyEnd.lowerBound])
        let revealStart = try #require(inspector.range(of: "private func restartPanelReveal"))
        let revealEnd = try #require(
            inspector.range(of: "private struct CompactEdgeStats", range: revealStart.lowerBound..<inspector.endIndex)
        )
        let revealBody = String(inspector[revealStart.lowerBound..<revealEnd.lowerBound])
        let embeddedStart = try #require(embedded.range(of: "private var embeddedAttachedInspector"))
        let embeddedEnd = try #require(
            embedded.range(of: "private func embeddedInspectorFrame", range: embeddedStart.lowerBound..<embedded.endIndex)
        )
        let embeddedInspector = String(embedded[embeddedStart.lowerBound..<embeddedEnd.lowerBound])

        #expect(inspectorBody.contains(".blur(radius: panelIsRevealed ? 0 : 7)"))
        #expect(inspectorBody.contains(".scaleEffect(panelIsRevealed ? 1.0 : 0.985"))
        #expect(revealBody.contains(".smooth(duration: 0.18)"))
        #expect(!revealBody.contains("interpolatingSpring"))
        #expect(embeddedInspector.contains(".transition(.opacity)"))
        #expect(embeddedInspector.contains(".smooth(duration: 0.18)"))
        #expect(!embeddedInspector.contains("interpolatingSpring"))
    }

    @Test("embedded graph note route opens without animated curtain transaction")
    func embeddedGraphNoteRouteOpensWithoutAnimatedCurtainTransaction() throws {
        let embedded = try loadRepoTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")

        let routeStart = try #require(embedded.range(of: "private var embeddedWorkspaceRoute"))
        let routeEnd = try #require(
            embedded.range(of: "private var shouldRenderCanvas", range: routeStart.lowerBound..<embedded.endIndex)
        )
        let routeBody = String(embedded[routeStart.lowerBound..<routeEnd.lowerBound])

        #expect(routeBody.contains("GraphWorkspaceContainer()"))
        #expect(routeBody.contains("transaction.animation = nil"))
        #expect(routeBody.contains("transaction.disablesAnimations = true"))
        #expect(!embedded.contains("value: graphState.currentRoute"))
    }

    @Test("graph node inspector keeps summary generation off the immediate selection turn")
    func graphNodeInspectorKeepsSummaryGenerationOffImmediateSelectionTurn() throws {
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let inspectorView = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(!inspectorState.contains("summaryKickoffTask"))
        #expect(inspectorState.contains("func ensureSummary(for node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext)"))
        #expect(inspectorState.contains("summaryTask?.cancel()"))
        #expect(inspectorState.contains("guard !Task.isCancelled, selectedNodeId == node.id else { return }"))
        #expect(inspectorView.contains("guard newSection == .summary else { return }"))
        #expect(inspectorView.contains("inspectorState.ensureSummary(for: node, store: graphState.store, modelContext: modelContext)"))
    }

    @Test("graph summaries still prefer Apple Intelligence before local Qwen fallback")
    func graphSummariesStayAppleFirst() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        // "…then local Qwen." copy assertion removed with cloud-only/Omega removal 2026-07-03 —
        // the local-Qwen fallback clause is gone; graph summaries stay on Apple Intelligence (kept).
        #expect(inspector.contains("AppleIntelligenceService.shared.generate("))
    }

    @Test("node inspector derives profiles off the main actor and caches them by node version")
    func nodeInspectorDerivesProfilesOffTheMainActorAndCachesThemByNodeVersion() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("private var profileCache: [ProfileCacheKey: DialogueNodeProfile] = [:]"))
        #expect(inspector.contains("let derived = await Task.detached(priority: .userInitiated)"))
        #expect(inspector.contains("let normalizedBody = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)"))
        #expect(inspector.contains("let freqKeywords = focusKeywords("))
        #expect(inspector.contains("self.profileCache[cacheKey] = derived"))
        #expect(inspector.contains("if let cachedProfile = profileCache[cacheKey]"))
        #expect(inspector.contains("displayedSummary = full"))
        #expect(!inspector.contains("Task.sleep(for: .milliseconds(16))"))
    }

    @Test("node inspector chat expands folder descendants and linked graph context")
    func nodeInspectorChatExpandsFolderDescendantsAndLinkedGraphContext() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("let predicate = #Predicate<SDFolder> { $0.id == folderID }"))
        #expect(inspector.contains("return subfolder == relativePath || (!nestedPrefix.isEmpty && subfolder.hasPrefix(nestedPrefix))"))
        #expect(inspector.contains("Items loaded for context:"))
        #expect(inspector.contains("Connected graph context:"))
        #expect(inspector.contains("Treat folder context as a bundle of descendant notes and relationships"))
    }

    @Test("note editor keeps markdown tables as plain editor text")
    func noteEditorKeepsMarkdownTablesAsPlainEditorText() throws {
        let tk2 = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(tk2.contains("tv.usesRenderedTableOverlays = false"))
        #expect(tk2.contains("tv.markdownDelegate.usesRenderedTableOverlays = false"))
        #expect(!tk2.contains("coord.renderedTableOverlayManager = RenderedTableOverlayManager2("))
    }

    @Test("landing does not expose mode selection or a separate agent page")
    func landingDoesNotExposeModeSelectionOrSeparateAgentPage() throws {
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let pipeline = try loadRepoTextFile("Epistemos/Engine/PipelineService.swift")

        #expect(inference.contains("enum EpistemosOperatingMode"))
        #expect(!landing.contains("operatingMode: operatingModeBinding"))
        #expect(!root.contains("AgentChatView()"))
        #expect(!repoFileExists("Epistemos/Views/AgentChat/AgentChatView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
        #expect(pipeline.contains("operatingMode: EpistemosOperatingMode = .fast"))
        #expect(pipeline.contains("operatingMode: operatingMode"))
    }

    @Test("legacy agent workspace view files are removed after fusion")
    func legacyAgentWorkspaceViewFilesAreRemovedAfterFusion() {
        #expect(!repoFileExists("Epistemos/Views/AgentChat/AgentChatView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/AgentPlanEditorView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/ToolTogglePillsView.swift"))
    }

    @Test("landing composer keeps the lightweight surface free of removed agent chrome")
    func landingStaysFreeOfRemovedAgentChrome() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landing.contains("LocalModelToolbarMenu("))
        #expect(!landing.contains("ComposerContextShortcutBar("))
        #expect(landing.contains("ComposerAttachmentEntryHints.landingPlaceholder"))
        #expect(!landing.contains("Command Center"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
    }

    @Test("landing keeps plain Home route without fused chat launch")
    func landingKeepsPlainHomeRouteWithoutFusedChatLaunch() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!landing.contains("enum LandingPromptSurface"))
        #expect(!landing.contains("landingPromptSurface: LandingPromptSurface = .chat"))
        #expect(!landing.contains("landingPromptSurfacePicker"))
        #expect(!landing.contains("landingAgentSpecificControls"))
        #expect(!landing.contains("submitLandingAgentPrompt("))
        #expect(!landing.contains("landingAgentDraft("))
        #expect(!landing.contains("ChatBrainPickerMenu("))
        #expect(!landing.contains("AgentCloneBridge.submitPrompt"))
        #expect(!landing.contains("AgentPortalContextSnapshot"))
        #expect(!landing.contains("@Environment(AgentChatState.self)"))
        #expect(!landing.contains("title: \"search\""))
        #expect(!bootstrap.contains("agentChatState.startNewSession()"))
    }

    @Test("non-chat interactive surfaces use Task.sleep instead of DispatchQueue.main.asyncAfter")
    func nonChatInteractiveSurfacesUseTaskSleepInsteadOfDispatchAsyncAfter() throws {
        let focusedResponsePanel = try loadRepoTextFile("Epistemos/Views/Notes/FocusedResponsePanel.swift")
        let inspectMode = try loadRepoTextFile("Epistemos/Views/Graph/GraphInspectModeView.swift")

        #expect(!focusedResponsePanel.contains("DispatchQueue.main.asyncAfter"))
        #expect(!inspectMode.contains("DispatchQueue.main.asyncAfter"))
        #expect(focusedResponsePanel.contains("Task.sleep"))
        #expect(inspectMode.contains("EmptyView()"))
        #expect(!inspectMode.contains("Task.sleep"))
    }

    @Test("note insight JSON fallbacks avoid force-cast traps")
    func noteInsightJSONFallbackAvoidsForceCasts() throws {
        let source = try loadRepoTextFile("Epistemos/Models/SDNoteInsight.swift")

        #expect(!source.contains("as!"))
        #expect(source.contains("decodeJSONArray"))
    }

    @Test("landing keeps toolbar model picker out of the root chrome")
    func landingKeepsToolbarModelPickerOutOfRootChrome() throws {
        let landingView = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(!landingView.contains("MainChatOperatingModePreference"))
        #expect(!landingView.contains("operatingMode: selectedOperatingMode"))

        #expect(!rootView.contains("LocalModelToolbarMenu(\n            variant: .toolbar,\n            overrideTitle:"))
    }

    @Test("apple fallback preserves the available response when local qwen is unavailable")
    func appleFallbackKeepsVisibleResponseWhenLocalFallbackFails() throws {
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")

        // "Local model fallback also failed…" log + `localSelection: localSelection.selection`
        // removed with cloud-only/Omega removal 2026-07-03 — the local-model fallback path was
        // deleted; the Apple Intelligence response-preservation assertions below stay valid.
        #expect(triage.contains("continuation.yield(result)"))
        #expect(!triage.contains("if !Self.isRefusalResponse(result)"))
        #expect(triage.contains("selectedRoute: .appleIntelligence"))
    }

    @Test("chat model selection can explicitly force Apple Intelligence")
    func chatModelSelectionCanExplicitlyForceAppleIntelligence() throws {
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(inference.contains("enum ChatModelSelection"))
        #expect(inference.contains("case appleIntelligence"))
        #expect(inference.contains("var preferredChatModelSelection"))
        #expect(triage.contains("preferredChatModelSelection"))
        #expect(triage.contains("selectedRoute: .appleIntelligence"))
        #expect(root.contains("Apple Intelligence"))
        #expect(root.contains("setPreferredChatModelSelection("))
    }

    @Test("chat model selector scopes cloud guidance to the active provider and links settings")
    func chatModelSelectorAlwaysExposesCloudModelsAndShowsConfigurationGuidance() throws {
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(root.contains("inference.activeCloudProvider"))
        #expect(root.contains("pickerCloudSection"))
        #expect(root.contains("popoverSectionTitle(\"Cloud\")"))
        #expect(root.contains("inference.configuredCloudProviders.contains(provider)"))
        #expect(root.contains("inference.preferredCloudModel(for: provider)"))
        #expect(root.contains("return \"Finish setup to unlock\""))
        #expect(root.contains("\"Connect a cloud provider in Settings → Inference to give the chat stack a cloud escalation path.\""))
        #expect(root.contains("Button(\"Open Settings\")"))
        #expect(root.contains("systemImage: provider.systemImage"))
    }

    @Test("provider setup guidance stays out of first-run onboarding")
    func providerSetupGuidanceStaysOutOfFirstRunOnboarding() throws {
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let setupAssistant = try loadRepoTextFile("Epistemos/Views/Onboarding/SetupAssistantView.swift")
        let providerSupport = try loadRepoTextFile("Epistemos/Views/Shared/CloudProviderSetupCard.swift")

        #expect(root.contains("Button(\"Open Settings\")"))
        #expect(root.contains("\"Connect a cloud provider in Settings → Inference to give the chat stack a cloud escalation path.\""))
        #expect(!setupAssistant.contains("CloudProviderSetupCard("))
        #expect(!setupAssistant.contains("ForEach(CloudModelProvider.preferredOrder"))
        #expect(!setupAssistant.contains("Cloud AI"))
        #expect(!providerSupport.contains("struct CloudProviderSetupCard"))
    }

    @Test("instant recall rebuild leaves the heavy vault watcher work off the main actor")
    func instantRecallRebuildLeavesWatcherWorkOffTheMainActor() throws {
        let service = try loadRepoTextFile("Epistemos/Engine/InstantRecallService.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(service.contains("func rebuildIndexAsync(notes: [(id: String, text: String)]) async"))
        #expect(service.contains("Task.detached(priority: .utility)"))
        #expect(vaultSync.contains("await service.rebuildIndexAsync(notes: notes)"))
        #expect(!vaultSync.contains("instantRecallService.rebuildIndex(notes: notes)"))
    }

    @Test("landing note picker observes vault sync manifest updates instead of relying on bootstrap singleton state")
    func landingNotePickerObservesVaultSyncManifestUpdates() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let coordinator = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(landing.contains("vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest"))
        #expect(landing.contains("manifest: ambientManifest"))
        #expect(!landing.contains("manifest: AppBootstrap.shared?.ambientManifest"))

        #expect(vaultSync.contains("var ambientManifest: VaultManifest?"))
        #expect(coordinator.contains("vaultSync.ambientManifest = manifest"))
    }

    @Test("node inspector profile copy avoids synthetic knowledge cluster filler text")
    func nodeInspectorProfileCopyAvoidsSyntheticKnowledgeClusterFillerText() throws {
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let inspectorView = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(!inspectorState.contains("is part of a connected knowledge cluster"))
        #expect(inspectorView.contains("if !p.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty"))
    }

    @Test("regex-backed presentation helpers avoid force-try compilation")
    func regexBackedPresentationHelpersAvoidForceTryCompilation() throws {
        let files = [
            "Epistemos/Sync/BlockPropertyParser.swift",
            "Epistemos/Views/Chat/TaggedMarkdownTextView.swift",
            "Epistemos/Views/Notes/MarkdownContentStorage.swift",
            "Epistemos/Views/Notes/MarkdownEditorStyle.swift",
            "Epistemos/Views/Notes/OutlineNavigatorView.swift",
            "Epistemos/Theme/EpistemosTheme.swift",
            "Epistemos/Theme/GlassModifiers.swift",
        ]

        for file in files {
            let source = try loadRepoTextFile(file)
            #expect(!source.contains("try!"), "\(file) should not use try! for regex or detector setup")
        }
    }

    @Test("block mirror similarity avoids quadratic edit-distance buffers")
    func blockMirrorSimilarityAvoidsQuadraticEditDistanceBuffers() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/BlockMirror.swift")

        #expect(!source.contains("Array(lhs.utf16)"))
        #expect(!source.contains("Array(rhs.utf16)"))
        #expect(!source.contains("var previous = Array(0...right.count)"))
        #expect(!source.contains("var current = Array(repeating: 0, count: right.count + 1)"))
    }

    @Test("read only note windows use the shared app environment helper")
    func readOnlyNoteWindowsUseSharedAppEnvironmentHelper() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")

        #expect(source.contains("ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)\n            .withAppEnvironment(bootstrap)"))
        #expect(!source.contains("ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)\n            .environment(bootstrap.uiState)"))
    }

    @Test("note window manager logs fetch failures instead of silently no-oping")
    func noteWindowManagerLogsFetchFailures() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")

        #expect(!source.contains("guard let page = try? bootstrap.modelContainer.mainContext.fetch(descriptor).first else {\n            return\n        }"))
        #expect(!source.contains("if let page = try? AppBootstrap.shared?.modelContainer.mainContext.fetch(desc).first"))
        #expect(source.contains("NoteWindowManager: failed to fetch page"))
        #expect(source.contains("NoteWindowManager: failed to fetch page title"))
    }

    @Test("time machine duplicate page IDs log instead of asserting")
    func timeMachineDuplicatePageIDsLogInsteadOfAsserting() throws {
        let source = try loadRepoTextFile("Epistemos/State/TimeMachineService.swift")

        #expect(source.contains("Self.log.fault"))
        #expect(!source.contains("assertionFailure(message)"))
    }

    @Test("time machine persistence avoids silent fetch and count failures")
    func timeMachinePersistenceAvoidsSilentFailures() throws {
        let source = try loadRepoTextFile("Epistemos/State/TimeMachineService.swift")

        #expect(!source.contains("let version = try? context.fetch(versionDesc).first"))
        #expect(!source.contains("if let chats = try? context.fetch(chatDesc)"))
        #expect(!source.contains("let msgCount = (try? context.fetchCount(msgDesc)) ?? 0"))
        #expect(!source.contains("state.graphStats.nodeCount = (try? context.fetchCount(nodeDesc)) ?? 0"))
        #expect(!source.contains("state.graphStats.edgeCount = (try? context.fetchCount(edgeDesc)) ?? 0"))
        #expect(!source.contains("let currentPages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!source.contains("let currentChatCount = (try? context.fetchCount(FetchDescriptor<SDChat>())) ?? 0"))
        #expect(!source.contains("let currentNodeCount = (try? context.fetchCount(FetchDescriptor<SDGraphNode>())) ?? 0"))
        #expect(!source.contains("let currentEdgeCount = (try? context.fetchCount(FetchDescriptor<SDGraphEdge>())) ?? 0"))
        #expect(source.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(source.contains("private func fetchAll<T: PersistentModel>("))
        #expect(source.contains("private func fetchCount<T: PersistentModel>("))
        #expect(source.contains("Self.log.error(\"TimeMachine: failed to fetch \\(label"))
        #expect(source.contains("label: \"note version\""))
        #expect(source.contains("label: \"chats\""))
        #expect(source.contains("label: \"chat message count\""))
        #expect(source.contains("label: \"node count\""))
        #expect(source.contains("label: \"edge count\""))
        #expect(source.contains("label: \"current pages\""))
        #expect(source.contains("label: \"current chat count\""))
        #expect(source.contains("label: \"current graph node count\""))
        #expect(source.contains("label: \"current graph edge count\""))
    }

    @Test("time machine restored workspaces undo failed inserts before returning")
    func timeMachineRestoredWorkspaceSaveFailuresUndoInsertedWorkspace() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Landing/TimeMachineView.swift")

        #expect(source.contains("context.delete(ws)"))
        #expect(source.contains("TimeMachineView: failed to persist restored workspace"))
    }

    @Test("vault index actor avoids silent import and manifest fallback paths")
    func vaultIndexActorAvoidsSilentRuntimeFallbacks() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(!source.contains("guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),"))
        #expect(!source.contains("if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),"))
        #expect(!source.contains("let currentPages = (try? modelContext.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!source.contains("if let existingFolders = try? modelContext.fetch(existingFolderDescriptor)"))
        #expect(!source.contains("if let insight = try? modelContext.fetch(insightDesc).first"))
        #expect(!source.contains("let existingWithId = (try? modelContext.fetch(idDescriptor)) ?? []"))
        #expect(!source.contains("guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {"))
        #expect(!source.contains("guard let pages = try? modelContext.fetch(descriptor) else { return [] }"))
        #expect(!source.contains("let folderNames = (try? modelContext.fetch(folderDescriptor))?.map(\\.name) ?? []"))
        #expect(!source.contains("let changedPageCount = (try? modelContext.fetchCount(descriptor)) ?? 0"))
        #expect(!source.contains("try? modelContext.save()"))
        #expect(source.contains("private func fetchAll<T: PersistentModel>("))
        #expect(source.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(source.contains("private func fetchCount<T: PersistentModel>("))
        #expect(source.contains("private func saveContext("))
        #expect(source.contains("private nonisolated static func contentModificationDate("))
    }

    @Test("vault index actor keeps durable body writes out of SDPage model methods")
    func vaultIndexActorAvoidsSynchronousModelBodyWrites() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(!source.contains("page.saveBody("))
        #expect(!source.contains(".mappedIfSafe"))
        #expect(!source.contains("loadBody(mapped: true)"))
        #expect(!source.contains("NoteFileStorage.writeBody(pageId: snapshot.pageId"))
        #expect(source.contains("private nonisolated static func vaultFileData("))
        #expect(source.contains("await NoteFileStorage.writePreparedImportedVaultBodyAsync(pageId: page.id, content: importedStorageBody)"))
        #expect(source.contains("NoteFileStorage.scheduleWriteBody(pageId: snapshot.pageId, content: snapshot.body)"))
        #expect(source.contains("page.updateBodyDerivedState(from: body)"))
    }

    @Test("custom non-chat secondary windows opt out of AppKit state restoration")
    func customNonChatSecondaryWindowsOptOutOfAppKitStateRestoration() throws {
        let noteWindowManager = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")
        let utilityWindowManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")
        let graphOverlayPanel = try loadRepoTextFile("Epistemos/Views/Graph/GraphOverlayPanel.swift")
        let quitSavePanel = try loadRepoTextFile("Epistemos/Views/Landing/QuitSavePanelController.swift")

        #expect(noteWindowManager.contains("window.isRestorable = false"))
        #expect(utilityWindowManager.contains("panel.isRestorable = false"))
        #expect(graphOverlayPanel.contains("isRestorable = false"))
        #expect(quitSavePanel.contains("scrim.isRestorable = false"))
        #expect(quitSavePanel.contains("floatingPanel.isRestorable = false"))
    }

    @Test("quit save panel treats workspace persistence failures as real failures")
    func quitSavePanelTreatsWorkspacePersistenceFailuresAsRealFailures() throws {
        let quitSavePanel = try loadRepoTextFile("Epistemos/Views/Landing/QuitSavePanelController.swift")
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        #expect(!quitSavePanel.contains("try? AppBootstrap.shared?.modelContainer.mainContext.save()"))
        #expect(!quitSavePanel.contains("if let data = try? JSONEncoder().encode(ws.captureSnapshot())"))
        #expect(quitSavePanel.contains("guard let saved = ws.saveWorkspace(name: name) else {"))
        #expect(quitSavePanel.contains("QuitSavePanelController: failed to save workspace"))
        #expect(quitSavePanel.contains("QuitSavePanelController: failed to save updated workspace"))
        #expect(workspaceService.contains("@discardableResult"))
        #expect(workspaceService.contains("func saveWorkspace(name: String) -> SDWorkspace?"))
    }

    @Test("quit save panel restores failed follow-up workspace mutations before returning failure")
    func quitSavePanelRestoresFailedFollowUpWorkspaceMutationsBeforeReturningFailure() throws {
        let quitSavePanel = try loadRepoTextFile("Epistemos/Views/Landing/QuitSavePanelController.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(quitSavePanel.range(of: startMarker))
            let end = try #require(
                quitSavePanel.range(of: endMarker, range: start.lowerBound..<quitSavePanel.endIndex)
            )
            return String(quitSavePanel[start.lowerBound..<end.lowerBound])
        }

        let performSave = try section(from: "private func performSave()", to: "// MARK: - Thin wrappers")

        #expect(performSave.contains("let originalSavedUserNote = saved.userNote"))
        #expect(performSave.contains("saved.userNote = originalSavedUserNote"))
        #expect(performSave.contains("let originalSnapshotData = existing.snapshotData"))
        #expect(performSave.contains("let originalUpdatedAt = existing.updatedAt"))
        #expect(performSave.contains("let originalExistingUserNote = existing.userNote"))
        #expect(performSave.contains("existing.snapshotData = originalSnapshotData"))
        #expect(performSave.contains("existing.updatedAt = originalUpdatedAt"))
        #expect(performSave.contains("existing.userNote = originalExistingUserNote"))
    }

    @Test("graph overlay live presentation stays on floating panel mode")
    func graphOverlayLivePresentationStaysOnFloatingPanelMode() throws {
        let graphOverlayPanel = try loadRepoTextFile("Epistemos/Views/Graph/GraphOverlayPanel.swift")
        let hologramOverlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(graphOverlayPanel.contains("enum GraphOverlayPanelPresentation"))
        #expect(graphOverlayPanel.contains("case floatingPanel"))
        #expect(graphOverlayPanel.contains("level = .floating"))

        #expect(hologramOverlay.contains("window.applyPresentation(.floatingPanel)"))
        #expect(hologramOverlay.contains("GraphMiniPanelLayout.frame(in: screen.visibleFrame)"))
        #expect(!hologramOverlay.contains("window.applyPresentation(.immersiveOverlay)"))
        #expect(hologramOverlay.contains("orderFrontRegardless()"))
    }

    @Test("app delegate disables AppKit state restoration in favor of workspace restore")
    func appDelegateDisablesAppKitStateRestorationInFavorOfWorkspaceRestore() throws {
        let source = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(source.contains("func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {\n        false\n    }"))
        #expect(source.contains("func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {\n        false\n    }"))
        #expect(source.contains("func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {\n        false\n    }"))
    }

    @Test("bootstrap and persistence helpers avoid force-trap fallbacks")
    func bootstrapAndPersistenceHelpersAvoidForceTrapFallbacks() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let mcpBridge = try loadRepoTextFile("Epistemos/Omega/MCPBridge.swift")
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")
        let dataDetectionService = try loadRepoTextFile("Epistemos/Engine/DataDetectionService.swift")
        let queryParser = try loadRepoTextFile("Epistemos/Engine/QueryParser.swift")
        let structuredQueryParser = try loadRepoTextFile("Epistemos/Engine/StructuredQueryParser.swift")

        #expect(!appBootstrap.contains("try! ModelContainer("))
        #expect(!mcpBridge.contains(".first!"))
        #expect(!activityTracker.contains(".first!"))
        #expect(!eventStore.contains(".first!"))
        #expect(!dataDetectionService.contains("URL(string: \"webcal://\")!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
    }

    @Test("activity tracker crash recovery stays wired and fail-closed")
    func activityTrackerCrashRecoveryStaysWiredAndFailClosed() throws {
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(activityTracker.contains("NoteFileStorage.writeTextAtomically(text, to: url, itemLabel: Self.flushFileLabel)"))
        #expect(activityTracker.contains("events = Array((loaded + events).suffix(Self.maxEvents))"))
        #expect(!activityTracker.contains("try? await Task.sleep(for: .seconds(2))"))
        #expect(!activityTracker.contains("return try? context.fetch(descriptor).first?.title"))
        #expect(!activityTracker.contains("try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)"))
        #expect(appBootstrap.contains("activityTracker.loadFlushedEvents()"))
        #expect(app.contains("bootstrap.activityTracker.flushToDisk()"))
    }

    @Test("workspace summary persistence avoids silent fetch save and sleep failures")
    func workspaceSummaryPersistenceAvoidsSilentFailures() throws {
        let workspaceSummary = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")

        #expect(!workspaceSummary.contains("try? await Task.sleep(for: interval)"))
        #expect(!workspaceSummary.contains("try? context.save()"))
        #expect(!workspaceSummary.contains("return try? context.fetch(FetchDescriptor<SDWorkspace>())"))
        #expect(!workspaceSummary.contains("return try? modelContainer.mainContext.fetch(descriptor).first?.title"))
        #expect(workspaceSummary.contains("Summary storage save failed"))
        #expect(workspaceSummary.contains("Summary timestamp fetch failed"))
        #expect(workspaceSummary.contains("Summary page-title fetch failed"))
    }

    @Test("workspace summary output is sanitized before persistence and prompt reuse")
    func workspaceSummaryOutputIsSanitizedBeforePersistenceAndPromptReuse() throws {
        let workspaceSummary = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(workspaceSummary.contains("UserFacingModelOutput.finalVisibleText(from: raw)"))
        #expect(workspaceSummary.contains("Self.sanitizedSummaryText(from: summary)"))
        #expect(workspaceService.contains("var sanitizedIntentSummary: String"))
        #expect(workspaceService.contains("UserFacingModelOutput.finalVisibleText(from: intentSummary)"))
        #expect(landing.contains("info.displayText"))
        #expect(appBootstrap.contains("workspaceService.welcomeBack?.intentSummary = WelcomeBackInfo.cleanedSummaryText(from: ws.summary)"))
    }

    @Test("primary launch verifies restored welcome back summaries after restore")
    func primaryLaunchVerifiesRestoredWelcomeBackSummariesAfterRestore() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let environment = try loadRepoTextFile("Epistemos/App/AppEnvironment.swift")
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        #expect(appBootstrap.contains("if workspaceService.welcomeBack != nil {"))
        #expect(appBootstrap.contains("await self?.refreshWelcomeBackSummary()"))
        #expect(appBootstrap.contains("func refreshWelcomeBackSummary() async"))
        #expect(environment.contains(".environment(bootstrap.workspaceService)"))
        #expect(workspaceService.contains("private static func welcomeBackInfo("))
        #expect(workspaceService.contains("if welcomeBack != nil {"))
        #expect(landing.contains("@State private var presentedWelcomeBack: WelcomeBackInfo?"))
        #expect(landing.contains("@State private var welcomeBackSyncTask: Task<Void, Never>?"))
        #expect(landing.contains("@Environment(WorkspaceService.self) private var workspaceService"))
        #expect(landing.contains(".onChange(of: workspaceService.welcomeBack?.displayText ?? \"\")"))
        #expect(landing.contains("scheduleWelcomeBackSync()"))
        #expect(landing.contains("private func syncWelcomeBackPresentation()"))
        #expect(landing.contains("guard presentedWelcomeBack?.displayText != info.displayText || !showWelcomeBack else { return }"))
        #expect(landing.contains("presentedWelcomeBack = info"))
        #expect(landing.contains(".pixelPanel(theme: theme, surface: welcomeBackPanelSurface(for: theme))"))
    }

    @Test("welcome back info strips reasoning artifacts from restored summaries")
    func welcomeBackInfoStripsReasoningArtifactsFromRestoredSummaries() {
        let info = WelcomeBackInfo(
            intentSummary: "<think>debug trace</think>\nShip mode summary is ready.",
            userNote: "",
            noteCount: 1,
            chatCount: 0,
            graphWasOpen: false,
            sessionMinutes: 10,
            editedNoteTitles: []
        )

        #expect(info.sanitizedIntentSummary == "Ship mode summary is ready.")
        #expect(!info.displayText.contains("<think>"))
        #expect(info.displayText.contains("Resume Point"))
        #expect(info.displayText.contains("- Ship mode summary is ready."))
        #expect(info.displayText.contains("Ship mode summary is ready."))
    }

    @Test("app bootstrap startup recovery avoids silent fetch delete and timer failures")
    func appBootstrapStartupRecoveryAvoidsSilentFailures() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!appBootstrap.contains("guard let pages = try? context.fetch(FetchDescriptor<SDPage>()) else {"))
        #expect(!appBootstrap.contains("if let ws = try? modelContainer.mainContext.fetch("))
        #expect(!appBootstrap.contains("try? await Task.sleep(for: Self.primaryLaunchInitializationPollInterval)"))
        #expect(!appBootstrap.contains("try? await Task.sleep(for: Self.deferredRuntimeServicesDelay)"))
        #expect(!appBootstrap.contains("try? fm.removeItem(at: appSupport.appendingPathComponent(name))"))
        #expect(!appBootstrap.contains("try? fm.removeItem(at: file)"))
        #expect(!appBootstrap.contains("guard let pages = try? modelContainer.mainContext.fetch(descriptor) else { return [] }"))
        #expect(appBootstrap.contains("Startup integrity snapshot failed"))
        #expect(appBootstrap.contains("Welcome-back summary fetch failed"))
        #expect(appBootstrap.contains("Instant Recall seed snapshot failed"))
        #expect(appBootstrap.contains("Database reset cleanup failed"))
    }

    @Test("database open failure blocks normal editing behind explicit recovery UI")
    func databaseOpenFailureBlocksNormalEditingBehindExplicitRecoveryUI() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(appBootstrap.contains("enum PersistenceMode: Equatable, Sendable"))
        #expect(appBootstrap.contains("let persistenceMode: PersistenceMode"))
        #expect(appBootstrap.contains(".durable(url: modelStoreURL)"))
        #expect(appBootstrap.contains(".inMemoryRecovery(reason: error.localizedDescription)"))
        #expect(appBootstrap.contains("Database failed to load; entering recovery-only in-memory mode"))

        #expect(!rootView.contains("Button(\"Continue Empty\")"))
        #expect(!rootView.contains("continue with an empty session"))
        #expect(rootView.contains("DatabaseRecoveryOverlay("))
        #expect(rootView.contains("if let databaseError {"))
        #expect(rootView.contains("Notes, chat, capture, vault sync, and .epdoc writes are disabled"))
        #expect(rootView.contains(".alert(\"Database Recovery Required\""))
        #expect(rootView.contains("This recovery session is not durable."))
    }

    // RCA-P0-002 fault-injection unit coverage. The source-guard test
    // above pins the wiring; these tests exercise the actual
    // `PersistenceMode` enum so a refactor that subtly broadens
    // `isDurable` or collapses `.inMemoryRecovery` into a default-bool
    // fails CI without needing a corrupt-store smoke run.
    //
    // What's still NOT covered automatically (called out in the audit
    // entry's "Remaining risk"): a real corrupted-SwiftData-store
    // launch, the workspace hide visual under load, and any pre-
    // existing detached write surfaces. Those remain manual smoke.

    @Test("PersistenceMode.isDurable is true only for the .durable case")
    func persistenceModeIsDurableReflectsCase() throws {
        let durable = PersistenceMode.durable(url: URL(fileURLWithPath: "/tmp/test.store"))
        let testInMemory = PersistenceMode.testInMemory
        let recovery = PersistenceMode.inMemoryRecovery(reason: "store open failed")

        #expect(durable.isDurable == true)
        #expect(testInMemory.isDurable == false)
        #expect(recovery.isDurable == false,
                "recovery mode MUST report non-durable so any caller gating writes on isDurable blocks correctly")
    }

    @Test("PersistenceMode equality honors the recovery reason")
    func persistenceModeEquatabilityHonorsReason() throws {
        // Two recovery sessions with different reasons must NOT compare
        // equal — otherwise diagnostic surfaces that key off
        // PersistenceMode would collapse distinct failure modes into
        // one. Guards against an accidental `Equatable` synthesis
        // regression that ignores associated values.
        let a = PersistenceMode.inMemoryRecovery(reason: "missing store file")
        let b = PersistenceMode.inMemoryRecovery(reason: "schema mismatch")
        #expect(a != b)

        let aDup = PersistenceMode.inMemoryRecovery(reason: "missing store file")
        #expect(a == aDup)

        // Different cases with same superficial info still differ.
        let url = URL(fileURLWithPath: "/tmp/test.store")
        let durable = PersistenceMode.durable(url: url)
        #expect(durable != PersistenceMode.testInMemory)
    }

    @Test("full reset clears the whole schema and managed note bodies")
    func fullResetClearsTheWholeSchemaAndManagedNoteBodies() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let resetRange = try #require(appBootstrap.range(of: "func resetAllData() async {"))
        let resetBody = appBootstrap[resetRange.lowerBound...]

        #expect(resetBody.contains("let didClear = await vaultSync.stopWatchingAsync(preserveData: false)"))
        #expect(resetBody.contains("if !didClear {"))
        #expect(resetBody.contains("await vaultSync.forceClearDerivedLocalStateForFullReset()"))
        #expect(resetBody.contains("try context.delete(model: SDMessage.self)"))
        #expect(resetBody.contains("try context.delete(model: SDChat.self)"))
        #expect(resetBody.contains("try context.delete(model: SDPageVersion.self)"))
        #expect(resetBody.contains("try context.delete(model: SDNoteInsight.self)"))
        #expect(resetBody.contains("try context.delete(model: SDPage.self)"))
        #expect(resetBody.contains("try context.delete(model: SDFolder.self)"))
        #expect(resetBody.contains("try context.delete(model: SDGraphNode.self)"))
        #expect(resetBody.contains("try context.delete(model: SDGraphEdge.self)"))
        #expect(resetBody.contains("try context.delete(model: SDBlock.self)"))
        #expect(resetBody.contains("try context.delete(model: SDWorkspace.self)"))
        #expect(!resetBody.contains("SDModelProfile"))
        #expect(resetBody.contains("NoteFileStorage.removeAllManagedBodies()"))
        #expect(resetBody.contains("UserDefaults.standard.set(false, forKey: \"epistemos.setupComplete\")"))
        #expect(resetBody.contains("clearVaultLifecycleRuntimeState("))
        #expect(appBootstrap.contains("queryEngine.resetForVaultLifecycle()"))
        #expect(appBootstrap.contains("contextualShadowsState.resetForVaultLifecycle()"))
        #expect(appBootstrap.contains("graphState.resetForVaultLifecycle()"))
        #expect(!appBootstrap.contains("graphState.needsRefresh = true"))
    }

    @Test("retired model profile layer stays deleted")
    func retiredModelProfileLayerStaysDeleted() throws {
        let schema = try loadRepoTextFile("Epistemos/Models/EpistemosSchema.swift")

        #expect(!repoFileExists("Epistemos/Models/SDModelProfile.swift"))
        #expect(!repoFileExists("Epistemos/State/ModelProfileManager.swift"))
        #expect(!schema.contains("SDModelProfile"))
    }

    @Test("UIState landing greeting persistence avoids silent JSON and timer failures")
    func uiStateLandingGreetingPersistenceAvoidsSilentFailures() throws {
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")

        #expect(!uiState.contains("let decodedGreetings = try? JSONDecoder().decode("))
        #expect(!uiState.contains("guard let encodedGreetings = try? JSONEncoder().encode(landingCustomGreetings) else"))
        #expect(!uiState.contains("try? await Task.sleep(for: .seconds(type == .error ? 5 : 3))"))
        #expect(!uiState.contains("guard let pages = try? context.fetch(descriptor), !pages.isEmpty else { return [] }"))
        #expect(!uiState.contains("if let ws = try? context.fetch("))
        #expect(uiState.contains("UIState: failed to decode custom landing greetings"))
        #expect(uiState.contains("UIState: failed to encode custom landing greetings"))
        #expect(uiState.contains("UIState: toast dismissal sleep failed"))
        #expect(uiState.contains("LandingGreetingResolver: failed to fetch recent pages"))
        #expect(uiState.contains("LandingGreetingResolver: failed to fetch workspace summary"))
    }

    @Test("workspace service persistence avoids silent fetch decode and timer failures")
    func workspaceServicePersistenceAvoidsSilentFailures() throws {
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        #expect(!workspaceService.contains("try? await Task.sleep(for: .milliseconds(200))"))
        #expect(!workspaceService.contains("try? await Task.sleep(for: .seconds(self?.autoSaveInterval ?? 300))"))
        #expect(!workspaceService.contains("let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first"))
        #expect(!workspaceService.contains("guard let workspace = try? context.fetch(FetchDescriptor(predicate: predicate)).first"))
        #expect(!workspaceService.contains("let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: workspace.snapshotData)"))
        #expect(!workspaceService.contains("return (try? modelContainer.mainContext.fetch(descriptor)) ?? []"))
        #expect(workspaceService.contains("Workspace auto-save: failed to fetch auto-save workspace"))
        #expect(workspaceService.contains("Workspace auto-restore: failed to fetch auto-save workspace"))
        #expect(workspaceService.contains("Workspace diff: failed to decode saved snapshot"))
        #expect(workspaceService.contains("Workspace list: failed to fetch saved workspaces"))
    }

    @Test("workspace service restores failed workspace mutations without rolling back unrelated shared state")
    func workspaceServiceRestoresFailedMutationsWithoutGlobalRollback() throws {
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(workspaceService.range(of: startMarker))
            let end = try #require(
                workspaceService.range(of: endMarker, range: start.lowerBound..<workspaceService.endIndex)
            )
            return String(workspaceService[start.lowerBound..<end.lowerBound])
        }

        let autoSave = try section(from: "func autoSave()", to: "func autoRestore()")
        let clearAutoSavedWorkspace = try section(
            from: "func clearAutoSavedWorkspace()",
            to: "// MARK: - Auto-Save Timer"
        )
        let saveWorkspace = try section(
            from: "func saveWorkspace(name: String) -> SDWorkspace?",
            to: "func loadWorkspace"
        )
        let deleteWorkspace = try section(
            from: "func deleteWorkspace(_ workspace: SDWorkspace)",
            to: "func renameWorkspace"
        )
        let renameWorkspace = try section(
            from: "func renameWorkspace(_ workspace: SDWorkspace, to newName: String)",
            to: "func listWorkspaces"
        )

        #expect(workspaceService.contains("private func persistWorkspaceMutation("))
        #expect(workspaceService.contains("restoreState()"))
        #expect(!workspaceService.contains("context.rollback()"))
        #expect(autoSave.contains("savedWorkspace.snapshotData = originalSnapshotData"))
        #expect(autoSave.contains("savedWorkspace.updatedAt = originalUpdatedAt"))
        #expect(autoSave.contains("context.delete(savedWorkspace)"))
        #expect(clearAutoSavedWorkspace.contains("context.insert(workspace)"))
        #expect(saveWorkspace.contains("context.delete(ws)"))
        #expect(deleteWorkspace.contains("context.insert(workspace)"))
        #expect(renameWorkspace.contains("let originalName = workspace.name"))
        #expect(renameWorkspace.contains("workspace.name = originalName"))
        #expect(renameWorkspace.contains("workspace.updatedAt = originalUpdatedAt"))
    }

    @Test("notes sidebar delete flows persist model removal before destructive cleanup")
    func notesSidebarDeleteFlowsPersistBeforeDestructiveCleanup() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(source.contains("preparePageDeletion("))
        #expect(source.contains("restorePageDeletion("))
        #expect(source.contains("finalizePageDeletion("))
        #expect(source.contains("preparePageDeletions(in folder: SDFolder)"))
        #expect(source.contains("let pageDeletion = preparePageDeletion(page)"))
        #expect(source.contains("let pageDeletions = preparePageDeletions(in: folder)"))
        #expect(source.contains("saveSidebarChanges(rebuild: false, reason: \"page delete\")"))
        #expect(source.contains("saveSidebarChanges(rebuild: false, reason: \"folder delete\")"))
        #expect(source.contains("vaultSync.deletePageFromDisk(filePath: deletion.filePath)"))
        #expect(source.contains("vaultSync.deleteDirectory(relativePath: relativePath)"))
    }

    @Test("notes sidebar restores failed non-delete mutations before external side effects")
    func notesSidebarRestoresFailedNonDeleteMutationsBeforeExternalSideEffects() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let renamePage = try section(from: "case .renamePage", to: "case .requestDeletePage")
        let renameFolder = try section(from: "case .renameFolder", to: "case .requestDeleteFolder")
        let newSubfolder = try section(from: "case .newSubfolder", to: "case .toggleCollection")
        let toggleCollection = try section(from: "case .toggleCollection", to: "case .movePageToFolder")
        let movePageToFolder = try section(from: "case .movePageToFolder", to: "case .moveFolderInto")
        let moveFolderInto = try section(from: "case .moveFolderInto", to: "case .movePageToRoot")
        let movePageToRoot = try section(from: "case .movePageToRoot", to: "case .moveFolderToRoot")
        let moveFolderToRoot = try section(from: "case .moveFolderToRoot", to: "case .createNewPage")
        let createFolder = try section(from: "private func createFolder(title: String)", to: "private func createCollection")
        let getOrCreateTodayJournal = try section(
            from: "private func getOrCreateTodayJournal()",
            to: "// MARK: - Vault Header"
        )

        #expect(source.contains("private func persistSidebarMutation("))
        #expect(source.contains("restoreState()"))
        #expect(source.contains("private struct NotesSidebarFolderMutationSnapshot"))
        #expect(source.contains("private struct NotesSidebarPageLocationSnapshot"))
        #expect(source.contains("private func captureFolderMutationSnapshot("))
        #expect(source.contains("private func restoreFolderMutationSnapshot("))
        #expect(renamePage.contains("guard persistSidebarMutation("))
        #expect(renamePage.contains("page.title = originalTitle"))
        #expect(renameFolder.contains("let snapshot = captureFolderMutationSnapshot(folder)"))
        #expect(renameFolder.contains("restoreFolderMutationSnapshot(snapshot)"))
        #expect(newSubfolder.contains("modelContext.delete(child)"))
        #expect(toggleCollection.contains("CollectionRegistry.shared.setCollection(folder.name, folder.isCollection)"))
        #expect(toggleCollection.contains("folder.isCollection = originalIsCollection"))
        #expect(movePageToFolder.contains("let snapshot = NotesSidebarPageLocationSnapshot(page)"))
        #expect(movePageToFolder.contains("snapshot.restore(on: page)"))
        #expect(moveFolderInto.contains("let snapshot = captureFolderMutationSnapshot(child)"))
        #expect(moveFolderInto.contains("restoreFolderMutationSnapshot(snapshot)"))
        #expect(movePageToRoot.contains("let snapshot = NotesSidebarPageLocationSnapshot(page)"))
        #expect(movePageToRoot.contains("snapshot.restore(on: page)"))
        #expect(moveFolderToRoot.contains("let snapshot = captureFolderMutationSnapshot(folder)"))
        #expect(moveFolderToRoot.contains("restoreFolderMutationSnapshot(snapshot)"))
        #expect(createFolder.contains("modelContext.delete(folder)"))
        #expect(getOrCreateTodayJournal.contains("let locationSnapshot = NotesSidebarPageLocationSnapshot(existing)"))
        #expect(getOrCreateTodayJournal.contains("locationSnapshot.restore(on: existing)"))
    }

    @Test("collection folder renames keep the registry aligned with the new name")
    func collectionFolderRenamesKeepRegistryAlignedWithNewName() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let start = try #require(source.range(of: "case .renameFolder"))
        let end = try #require(
            source.range(of: "case .requestDeleteFolder", range: start.lowerBound..<source.endIndex)
        )
        let renameFolder = String(source[start.lowerBound..<end.lowerBound])

        #expect(renameFolder.contains("let wasCollection = folder.isCollection"))
        #expect(renameFolder.contains("CollectionRegistry.shared.setCollection(oldName, false)"))
        #expect(renameFolder.contains("CollectionRegistry.shared.setCollection(newName, true)"))
        #expect(renameFolder.contains("if wasCollection"))
    }

    @Test("vault organizer persists approved suggestions before file-system side effects")
    func vaultOrganizerPersistsApprovedSuggestionsBeforeFileSystemSideEffects() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/VaultOrganizerView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let applySuggestion = try section(
            from: "private func applySuggestion(_ suggestion: OrgSuggestion)",
            to: "private func dismissSuggestion"
        )

        #expect(source.contains("private func persistSuggestionMutation("))
        #expect(applySuggestion.contains("let originalTags = page.tags"))
        #expect(applySuggestion.contains("page.tags = originalTags"))
        #expect(applySuggestion.contains("let originalFolder = page.folder"))
        #expect(applySuggestion.contains("let originalSubfolder = page.subfolder"))
        #expect(applySuggestion.contains("page.subfolder = folder.relativePath"))
        #expect(applySuggestion.contains("page.subfolder = originalSubfolder"))
        #expect(applySuggestion.contains("vaultSync.movePage(pageId: pageId, toSubfolder: folder.relativePath)"))
        #expect(applySuggestion.contains("persistSuggestionMutation("))
        #expect(applySuggestion.contains("reason: \"organizer folder create\""))
        #expect(applySuggestion.contains("modelContext.delete(folder)"))
        #expect(applySuggestion.contains("guard applied else { return }"))
        #expect(applySuggestion.contains("appliedCount += 1"))
        #expect(applySuggestion.contains("suggestions.removeAll { $0.id == suggestion.id }"))
    }

    @Test("prose editor title sync restores failed title saves before renaming the vault file")
    func proseEditorTitleSyncRestoresFailedTitleSavesBeforeRenamingVaultFile() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let start = try #require(source.range(of: "static func syncNoteTitleIfNeeded("))
        let end = try #require(
            source.range(of: "private static func syncedNoteTitle(inLine rawLine: String) -> String?", range: start.lowerBound..<source.endIndex)
        )
        let syncTitle = String(source[start.lowerBound..<end.lowerBound])

        #expect(syncTitle.contains("let originalTitle = page.title"))
        #expect(syncTitle.contains("let originalUpdatedAt = page.updatedAt"))
        #expect(syncTitle.contains("let originalNeedsVaultSync = page.needsVaultSync"))
        #expect(syncTitle.contains("page.title = originalTitle"))
        #expect(syncTitle.contains("page.updatedAt = originalUpdatedAt"))
        #expect(syncTitle.contains("page.needsVaultSync = originalNeedsVaultSync"))
        #expect(syncTitle.contains("return false"))
        #expect(syncTitle.contains("renamePageFile(page.id, syncedTitle)"))

        let saveCall = try #require(syncTitle.range(of: "try modelContext.save()"))
        let renameCall = try #require(syncTitle.range(of: "renamePageFile(page.id, syncedTitle)"))
        #expect(saveCall.lowerBound < renameCall.lowerBound)
    }

    @Test("note detail quick mutations restore failed save state for pin favorite and ideas")
    func noteDetailQuickMutationsRestoreFailedSaveState() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("private func persistPageMutation("))
        #expect(source.contains("let originalShortcutPinned = page.isPinned"))
        #expect(source.contains("page.isPinned = originalShortcutPinned"))
        #expect(source.contains("let originalMenuPinned = page.isPinned"))
        #expect(source.contains("page.isPinned = originalMenuPinned"))
        #expect(source.contains("let originalIsFavorite = page.isFavorite"))
        #expect(source.contains("page.isFavorite = originalIsFavorite"))
        #expect(source.contains("let originalIdeas = page.ideas"))
        #expect(source.contains("let originalUpdatedAt = page.updatedAt"))
        #expect(source.contains("page.ideas = originalIdeas"))
        #expect(source.contains("page.updatedAt = originalUpdatedAt"))
    }

    @Test("diff sheet restores failed restore and delete mutations before surfacing UI success")
    func diffSheetRestoreMutationsRestoreFailedState() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/DiffSheetView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let restoreVersion = try section(from: "private func restoreVersion()", to: "private func undoRestore()")
        let undoRestore = try section(from: "private func undoRestore()", to: "// MARK: - Actions")
        let persistRestoredBody = try section(from: "static func persistRestoredBody(", to: "private func copyVersionText()")
        let deleteSelectedVersion = try section(from: "private func deleteSelectedVersion()", to: "// MARK: - Diff Colors")

        #expect(restoreVersion.contains("modelContext.delete(snapshot)"))
        #expect(restoreVersion.contains("return"))
        #expect(restoreVersion.contains("preRestoreBody = currentBody"))

        let restoreSaveCall = try #require(restoreVersion.range(of: "try Self.persistRestoredBody("))
        let restoreUndoState = try #require(restoreVersion.range(of: "preRestoreBody = currentBody"))
        let restoreLiveBody = try #require(restoreVersion.range(of: "liveBody = version.body"))
        #expect(restoreSaveCall.lowerBound < restoreUndoState.lowerBound)
        #expect(restoreUndoState.lowerBound < restoreLiveBody.lowerBound)

        #expect(undoRestore.contains("return"))
        let undoSaveCall = try #require(undoRestore.range(of: "try Self.persistRestoredBody("))
        let undoVaultWrite = try #require(undoRestore.range(of: "await writeRestoredBodyToVault("))
        let undoLiveBody = try #require(undoRestore.range(of: "liveBody = oldBody"))
        #expect(undoSaveCall.lowerBound < undoVaultWrite.lowerBound)
        #expect(undoVaultWrite.lowerBound < undoLiveBody.lowerBound)

        #expect(restoreVersion.contains("await writeRestoredBodyToVault(pageId: page.id, body: version.body)"))
        #expect(persistRestoredBody.contains("let originalBody = page.loadBody(mapped: false, fast: true)"))
        #expect(persistRestoredBody.contains("let originalWordCount = page.wordCount"))
        #expect(persistRestoredBody.contains("let originalUpdatedAt = page.updatedAt"))
        #expect(persistRestoredBody.contains("let originalNeedsVaultSync = page.needsVaultSync"))
        #expect(persistRestoredBody.contains("let originalInlineBody = page.body"))
        #expect(persistRestoredBody.contains("let originalBlockReferences = page.blockReferences"))
        #expect(persistRestoredBody.contains("page.body = originalInlineBody"))
        #expect(persistRestoredBody.contains("page.blockReferences = originalBlockReferences"))
        #expect(persistRestoredBody.contains("page.wordCount = originalWordCount"))
        #expect(persistRestoredBody.contains("page.updatedAt = originalUpdatedAt"))
        #expect(persistRestoredBody.contains("page.needsVaultSync = originalNeedsVaultSync"))
        #expect(persistRestoredBody.contains("_ = NoteFileStorage.stageBodyForImmediateRead(pageId: pageId, content: originalBody)"))

        let persistSaveCall = try #require(persistRestoredBody.range(of: "try modelContext.save()"))
        let persistSyncCall = try #require(persistRestoredBody.range(of: "await BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(persistSaveCall.lowerBound < persistSyncCall.lowerBound)
        #expect(!persistRestoredBody.contains("flushPendingBodyToDisk"))

        #expect(deleteSelectedVersion.contains("modelContext.insert(version)"))
    }

    @Test("workspace summary storage restores failed save state")
    func workspaceSummaryStorageRestoresFailedSaveState() throws {
        let source = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")
        let start = try #require(source.range(of: "private func storeSummary(_ text: String)"))
        let end = try #require(
            source.range(of: "private func fetchAutoSaveLastSummaryAt()", range: start.lowerBound..<source.endIndex)
        )
        let storeSummary = String(source[start.lowerBound..<end.lowerBound])

        #expect(storeSummary.contains("let originalSummary = workspace.summary"))
        #expect(storeSummary.contains("let originalLastSummaryAt = workspace.lastSummaryAt"))
        #expect(storeSummary.contains("workspace.summary = originalSummary"))
        #expect(storeSummary.contains("workspace.lastSummaryAt = originalLastSummaryAt"))
    }

    @Test("daily brief follow-up saves restore failed mutation state")
    func dailyBriefRestoresFailedMutationState() throws {
        let appCoordinator = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")

        let dailyStart = try #require(appCoordinator.range(of: "if let pageId = await self.vaultSync.createPage("))
        let dailyEnd = try #require(
            appCoordinator.range(of: "} else {", range: dailyStart.lowerBound..<appCoordinator.endIndex)
        )
        let dailyBriefPersist = String(appCoordinator[dailyStart.lowerBound..<dailyEnd.lowerBound])

        #expect(dailyBriefPersist.contains("let originalFolder = page.folder"))
        #expect(dailyBriefPersist.contains("let originalTags = page.tags"))
        #expect(dailyBriefPersist.contains("page.folder = originalFolder"))
        #expect(dailyBriefPersist.contains("page.tags = originalTags"))
    }

    @Test("daily brief cleanup removes failed temporary folder page and block mutations")
    func dailyBriefCleanupRemovesFailedTemporaryState() throws {
        let source = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")
        let start = try #require(source.range(of: "private func saveDailyBrief(content: String)"))
        let end = try #require(
            source.range(of: "// MARK: - Vault Manifest", range: start.lowerBound..<source.endIndex)
        )
        let saveDailyBrief = String(source[start.lowerBound..<end.lowerBound])

        #expect(saveDailyBrief.contains("let createdFolder: Bool"))
        #expect(saveDailyBrief.contains("func discardNewDailyBriefFolderIfNeeded()"))
        #expect(saveDailyBrief.contains("CollectionRegistry.shared.setCollection(\"Daily Briefs\", false)"))
        #expect(saveDailyBrief.contains("func discardFailedFallbackPage(_ page: SDPage)"))
        #expect(saveDailyBrief.contains("FetchDescriptor<SDBlock>("))
        #expect(saveDailyBrief.contains("context.delete(page)"))
        #expect(saveDailyBrief.contains("context.delete(folder)"))
        #expect(saveDailyBrief.contains("let failedPageId = page.id"))
        #expect(saveDailyBrief.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))
        #expect(saveDailyBrief.contains("guard !alreadySaved else {"))
        #expect(saveDailyBrief.contains("discardNewDailyBriefFolderIfNeeded()"))
        #expect(saveDailyBrief.contains("discardFailedFallbackPage(page)"))
    }

    @Test("shared-context page journal failures restore local mutations without global rollback")
    func sharedContextPageJournalPersistenceFailuresAvoidGlobalRollback() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let journal = try loadRepoTextFile("Epistemos/Intents/Schemas/JournalIntents.swift")

        #expect(!vaultSync.contains("context.rollback()"))
        #expect(vaultSync.contains("let failedPageId = page.id"))
        #expect(vaultSync.contains("predicate: #Predicate<SDBlock> { $0.pageId == failedPageId }"))
        #expect(vaultSync.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))

        #expect(!journal.contains("context.rollback()"))
        #expect(journal.contains("let originalBody = await SDPage.loadBodyAsyncFromPrimitives("))
        #expect(journal.contains("pageId: page.id"))
        #expect(journal.contains("filePath: page.filePath"))
        #expect(journal.contains("inlineBody: page.body"))
        #expect(journal.contains("let originalJournalDate = page.journalDate"))
        #expect(journal.contains("page.journalDate = journalDate"))
        #expect(journal.contains("page.journalDate = originalJournalDate"))
        #expect(journal.contains("page.saveBody(originalBody)"))
        #expect(journal.contains("BlockMirror.sync(pageId: pageId, body: originalBody, modelContext: context)"))
    }

    @Test("AI partner interaction logging avoids silent directory creation fallback")
    func aiPartnerInteractionLoggingAvoidsSilentDirectoryFallback() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/AIPartnerService.swift")
        let start = try #require(source.range(of: "private func saveInteractionLog()"))
        let end = try #require(
            source.range(of: "// MARK: - Weighted Context Helpers", range: start.lowerBound..<source.endIndex)
        )
        let saveInteractionLog = String(source[start.lowerBound..<end.lowerBound])

        #expect(saveInteractionLog.contains("FoundationSafety.userApplicationSupportDirectory()"))
        #expect(!saveInteractionLog.contains("try? FileManager.default.createDirectory("))
        #expect(saveInteractionLog.contains("Failed to create AI partner log directory"))
    }

    @Test("hologram inspector schedules block mirror sync only after dirty save succeeds")
    func hologramInspectorSchedulesBlockMirrorSyncAfterSave() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let start = try #require(source.range(of: "private func markPageDirty(pageId: String, body: String)"))
        let end = try #require(
            source.range(of: "@ViewBuilder", range: start.lowerBound..<source.endIndex)
        )
        let markPageDirty = String(source[start.lowerBound..<end.lowerBound])

        let saveCall = try #require(markPageDirty.range(of: "try modelContext.save()"))
        let syncCall = try #require(markPageDirty.range(of: "await BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(saveCall.lowerBound < syncCall.lowerBound)
    }

    @Test("home navigation paths order the main window front regardless for hidden launch sheets")
    func homeNavigationPathsOrderMainWindowFrontRegardlessForHiddenLaunchSheets() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let statusBar = try loadRepoTextFile("Epistemos/App/StatusBar.swift")
        let coordinator = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        #expect(rootView.contains("static let sceneIdentifier = \"main\""))
        #expect(rootView.contains("window.identifier?.rawValue == sceneIdentifier"))
        #expect(rootView.contains("static func surfaceHomeWindow()"))
        #expect(rootView.contains("mainWindow.orderFrontRegardless()"))
        #expect(app.contains("HomeWindowIdentity.surfaceHomeWindow()"))
        #expect(statusBar.contains("HomeWindowIdentity.surfaceHomeWindow()"))
        #expect(coordinator.contains("HomeWindowIdentity.surfaceHomeWindow()"))
        #expect(workspaceService.contains("HomeWindowIdentity.surfaceHomeWindow()"))
    }

    @Test("home window keeps manual resizing instead of locking to the content's exact size")
    func homeWindowKeepsManualResizing() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(app.contains(".windowResizability(.contentMinSize)"))
        #expect(!app.contains(".windowResizability(.contentSize)"))
    }

    @Test("EventStore persistence avoids silent directory and JSON fallback failures")
    func eventStorePersistenceAvoidsSilentDirectoryAndJSONFallbackFailures() throws {
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")

        #expect(!eventStore.contains("try? FileManager.default.createDirectory("))
        #expect(!eventStore.contains("(try? String(data: JSONEncoder().encode(completedJobs), encoding: .utf8)) ?? \"[]\""))
        #expect(!eventStore.contains("(try? JSONDecoder().decode([String].self, from: Data(jobsJSON.utf8))) ?? []"))
        #expect(!eventStore.contains("(try? String(data: payloadEncoder.encode(dict), encoding: .utf8)) ?? \"{}\""))
        #expect(!eventStore.contains("guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else { return \"{}\" }"))
        #expect(eventStore.contains("EventStore: failed to create database directory"))
        #expect(eventStore.contains("EventStore: failed to encode event payload"))
        #expect(eventStore.contains("let payloadObject: [String: Any] = ["))
        #expect(eventStore.contains("let data = try JSONSerialization.data(withJSONObject: payloadObject, options: [.sortedKeys])"))
        #expect(eventStore.contains("private nonisolated static func excludeParentDirectoryFromSpotlight"))
        #expect(eventStore.contains("throw CocoaError(.fileWriteUnknown)"))
    }

    @Test("theme capture and settings helpers avoid user-facing force unwrap traps")
    func themeCaptureAndSettingsHelpersAvoidUserFacingForceUnwrapTraps() throws {
        let themeSource = try loadRepoTextFile("Epistemos/Theme/EpistemosTheme.swift")

        #expect(!themeSource.contains("preconditionFailure(\"Missing resolved theme cache"))
        #expect(themeSource.contains("Self.resolvedCache[self] ?? buildResolved()"))
    }

    @Test("supervisor network health has no hardcoded remote endpoint")
    func supervisorNetworkHealthHasNoHardcodedRemoteEndpoint() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(!appSupervisor.contains("https://api.anthropic.com"))
    }

    @Test("supervisor network health avoids remote HTTP polling")
    func supervisorNetworkHealthAvoidsRemoteHTTPPolling() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("import Network"))
        #expect(appSupervisor.contains("NWPathMonitor"))
        #expect(!appSupervisor.contains("https://api.anthropic.com"))
        #expect(!appSupervisor.contains("URLRequest(url: url, timeoutInterval: 5.0)"))
        #expect(!appSupervisor.contains("request.httpMethod = \"HEAD\""))
        #expect(!appSupervisor.contains("URLSession.shared.data(for: request)"))
    }

    @Test("supervisor manual restart path stays generic and logs unknown subsystems")
    func supervisorManualRestartPathStaysGeneric() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("Self.log.notice(\"Manual restart of '\\(name)': \\(reason)\")"))
        #expect(appSupervisor.contains("pendingRestartTasks.removeValue(forKey: name)?.cancel()"))
        #expect(appSupervisor.contains("if let spec = childSpecs.first(where: { $0.id == name })"))
        #expect(appSupervisor.contains("Self.log.warning(\"Unknown subsystem for restart: \\(name)\")"))
    }

    @Test("supervisor escalation triggers orphan cleanup")
    func supervisorEscalationTriggersOrphanCleanup() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("AppBootstrap.shared?.orphanCleanup.cleanupAll()"))
    }

    @Test("supervisor latches start and ignores stale child exits")
    func supervisorLatchesStartAndIgnoresStaleChildExits() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("private var isRunning = false"))
        #expect(appSupervisor.contains("guard !isRunning else { return }"))
        #expect(appSupervisor.contains("guard childGenerations[childId] == generation else {"))
        #expect(!appSupervisor.contains("guard supervisorTask == nil else { return }"))
    }

    @Test("supervisor cancels pending restart tasks on stop and manual restart")
    func supervisorCancelsPendingRestartTasks() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("private var pendingRestartTasks: [String: Task<Void, Never>] = [:]"))
        #expect(appSupervisor.contains("for task in pendingRestartTasks.values {"))
        #expect(appSupervisor.contains("pendingRestartTasks.removeValue(forKey: name)?.cancel()"))
        #expect(appSupervisor.contains("pendingRestartTasks.removeValue(forKey: dependent.id)?.cancel()"))
    }

    // Hermes subprocess orphan-cleanup test removed 2026-05-05 with the
    // rest of the Hermes-agent removal — see
    // docs/_archive/hermes-removal-2026-05-05/README.md.
    #if false
    @Test("orphan cleanup skips signal handler registration under tests")
    func orphanCleanupSkipsSignalHandlerRegistrationUnderTests() throws {
        let orphanCleanup = try loadRepoTextFile("Epistemos/State/OrphanSubprocessCleanup.swift")

        #expect(orphanCleanup.contains("processInfoEnvironment[\"XCTestConfigurationFilePath\"] == nil"))
        #expect(orphanCleanup.contains("cleanupLog.info(\"Skipping subprocess signal handlers under tests\")"))
    }

    @Test("orphan cleanup snapshots descendant process trees before termination")
    func orphanCleanupSnapshotsDescendantProcessTrees() throws {
        let orphanCleanup = try loadRepoTextFile("Epistemos/State/OrphanSubprocessCleanup.swift")

        #expect(orphanCleanup.contains("snapshotTrackedProcessTreePIDs()"))
        #expect(orphanCleanup.contains("proc_listchildpids(parentPID, &buffer, Int32(bufferSize))"))
        #expect(orphanCleanup.contains("func cleanupProcessTree(rootPID: pid_t)"))
    }

    @Test("Hermes termination uses process-tree cleanup instead of a fake process-group API")
    func hermesTerminationUsesProcessTreeCleanup() throws {}
    #endif

    @Test("note editor cache persistence avoids silent try-question-mark fallbacks")
    func noteEditorCachePersistenceAvoidsSilentTryQuestionMarkFallbacks() throws {
        let pageEditorCache = try loadRepoTextFile("Epistemos/Views/Notes/PageEditorCache.swift")

        #expect(!pageEditorCache.contains("try? data.write(to: url, options: .atomic)"))
        #expect(!pageEditorCache.contains("guard let data = try? Data(contentsOf: url),"))
        #expect(pageEditorCache.contains("DiskStyleCache: failed to decode cache entry"))
        #expect(pageEditorCache.contains("DiskStyleCache: failed to write cache entry"))
    }

    @Test("note insight and shell surfaces avoid silent persistence and cancellation fallbacks")
    func noteInsightAndShellSurfacesAvoidSilentFallbacks() throws {
        let noteInsight = try loadRepoTextFile("Epistemos/Engine/NoteInsightService.swift")
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let timeMachine = try loadRepoTextFile("Epistemos/Views/Landing/TimeMachineView.swift")

        #expect(!noteInsight.contains("let existing = try? context.fetch("))
        #expect(!noteInsight.contains("try? context.save()"))
        #expect(!noteInsight.contains("return try? context.fetch("))

        #expect(!sidebar.contains("return try? modelContext.fetch(descriptor).first"))
        #expect(!sidebar.contains("try? modelContext.save()"))
        #expect(!sidebar.contains("if let insight = try? modelContext.fetch(insightDesc).first"))

        #expect(!inspector.contains("try? await Task.sleep(for: .seconds(1))"))
        #expect(!inspector.contains("if let page = try? modelContext.fetch(desc).first"))
        #expect(!inspector.contains("try? modelContext.save()"))

        #expect(!timeMachine.contains("guard let data = try? JSONEncoder().encode(snapshot) else { return }"))
        #expect(!timeMachine.contains("try? context?.save()"))
        #expect(!timeMachine.contains("try? await Task.sleep(for: .milliseconds(150))"))
    }

    @Test("landing and vault runtime surfaces avoid silent startup and fetch fallbacks")
    func landingAndVaultRuntimeSurfacesAvoidSilentFallbacks() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let vaultIndexActor = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(!landing.contains("try? await Task.sleep(for: .milliseconds(800))"))
        #expect(!landing.contains("try? await Task.sleep(for: .milliseconds(16))"))
        #expect(!landing.contains("try? bootstrap.modelContainer.mainContext.save()"))
        #expect(!landing.contains("try? await Task.sleep(for: .milliseconds(100))"))
        #expect(!landing.contains("return (try? modelContext.fetch(descriptor)) ?? []"))
        #expect(landing.contains("LandingView: failed to fetch recent chats"))
        #expect(landing.contains("LandingView: failed to save welcome-back summary note"))

        #expect(!vaultIndexActor.contains("try? url.resourceValues(forKeys: [.contentModificationDateKey])"))
        #expect(!vaultIndexActor.contains("try? modelContext.fetch(fetchDescriptor)"))
        #expect(!vaultIndexActor.contains("try? modelContext.fetchCount(countDescriptor)"))
        #expect(!vaultIndexActor.contains("try? modelContext.save()"))
        #expect(!vaultIndexActor.contains("try? Data(contentsOf: url, options: [.mappedIfSafe])"))
        #expect(vaultIndexActor.contains("private func fetchAll<T: PersistentModel>("))
        #expect(vaultIndexActor.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(vaultIndexActor.contains("private func fetchCount<T: PersistentModel>("))
        #expect(vaultIndexActor.contains("private func saveContext("))
        #expect(vaultIndexActor.contains("private nonisolated static func contentModificationDate("))
    }

    @Test("landing command stage has no native search composer or retired liquid wave overlay")
    func landingCommandStageHasNoNativeSearchComposerOrRetiredLiquidWaveOverlay() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landing.contains("LiquidGreeting("))
        #expect(!landing.contains("landingSearchInputLine"))
        #expect(!landing.contains("ChatComposerTextEditor("))
        #expect(!landing.contains("landingSearchInlineStage"))
        #expect(landing.contains("landingSearchStepReveal(frame: landingStageRevealFrame"))
        #expect(!landing.contains("LandingWaveOverlay("))
        #expect(!landing.contains("LandingWaveHaptics.fireBeat"))
        #expect(!landing.contains("TextField(\"\", text: $landingSearchText)"))
        #expect(!landing.contains(".frame(width: 2, height: 2)"))
        #expect(!landing.contains(".appKitPopover("))
        #expect(!landing.contains("SpatialTapGesture("))
        #expect(landing.contains("if showingLandingStageCommand {\n                        dismissLandingStageCommand()\n                    }"))
        #expect(!landing.contains("showLandingSlashMenu"))
        #expect(!landing.contains("SlashCommandPopover("))
        #expect(!landing.contains("handleLandingSearchTextChange(newValue)"))
        #expect(!landing.contains("supportedLandingSlashItems"))
        #expect(!landing.contains("agentCommandCenter.availableSkills"))
        #expect(!landing.contains("chat.queuePendingSlashToken(slashToken)"))
    }

    @Test("app menu fallback does not structurally mutate SwiftUI-owned menus")
    func appMenuFallbackDoesNotStructurallyMutateSwiftUIMenus() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let marker = "private func installKnowledgeGraphMenuFallback()"
        let start = try #require(app.range(of: marker)?.lowerBound)
        let tail = app[start...]
        let end = try #require(tail.range(of: "\n    @objc private func toggleKnowledgeGraphFromMenu")?.lowerBound)
        let body = String(tail[..<end])

        #expect(body.contains("viewMenu.items.first(where: { $0.title == \"Knowledge Graph\" })"))
        #expect(body.contains("viewMenu.items.first(where: { $0.title == \"Reveal Current Document in Graph\" })"))
        #expect(body.contains("item.action = #selector(toggleKnowledgeGraphFromMenu(_:))"))
        #expect(body.contains("revealItem.action = #selector(revealCurrentDocumentInKnowledgeGraph(_:))"))
        #expect(!body.contains("insertItem("))
        #expect(!body.contains("addItem("))
        #expect(!body.contains("NSMenuItem("))
    }

    @Test("vault and query runtime surfaces avoid silent fetch save and timer fallbacks")
    func vaultAndQueryRuntimeSurfacesAvoidSilentFallbacks() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")
        let vaultMutator = try loadRepoTextFile("Epistemos/Vault/VaultChatMutator.swift")
        let vaultRegistry = try loadRepoTextFile("Epistemos/Vault/VaultRegistry.swift")

        #expect(!vaultSync.contains("let pages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!vaultSync.contains("guard (try? context.fetch(descriptor).first) != nil else { return nil }"))
        #expect(!vaultSync.contains("if let page = try? context.fetch(desc).first, let result = exportResult"))
        #expect(!vaultSync.contains("guard let dirtyPages = try? context.fetch(dirtyDescriptor),"))
        #expect(!vaultSync.contains("try? await Task.sleep(for: .seconds(interval))"))
        #expect(!vaultSync.contains("try? await Task.sleep(for: .seconds(300))"))
        #expect(!vaultSync.contains("try? await Task.sleep(for: .seconds(2))"))
        #expect(!vaultSync.contains("if let latest = try? context.fetch(versionDesc).first, latest.body == currentBody { return }"))
        #expect(!vaultSync.contains("guard let totalCount = try? context.fetchCount(countDesc),"))
        #expect(vaultSync.contains("private func fetchAll<T: PersistentModel>("))
        #expect(vaultSync.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(vaultSync.contains("private nonisolated static func fetchBackgroundAll<T: PersistentModel>("))

        #expect(!queryRuntime.contains("let results = (try? searchIndex.search(query: query, limit: limit)) ?? []"))
        #expect(!queryRuntime.contains("let blockResults = (try? searchIndex.searchBlocks(query: query, limit: limit)) ?? []"))
        #expect(queryRuntime.contains("QueryRuntime: failed to search"))

        #expect(!vaultMutator.contains("let before = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? defaultMemoryBody(for: targetVault)"))
        #expect(!vaultMutator.contains("try? await Task.sleep(for: .seconds(timeoutSeconds))"))
        #expect(vaultMutator.contains("VaultChatMutator: failed to read staged memory file"))

        #expect(!vaultRegistry.contains("guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),"))
        #expect(vaultRegistry.contains("VaultRegistry: failed to inspect modification date"))
    }

    @Test("HookRegistry persists AgentEvent hook lifecycle without crossing forbidden boundaries")
    func hookRegistryPersistsAgentEventHookLifecycleWithoutCrossingForbiddenBoundaries() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/HookRegistry.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("persistAgentEvent"))
        #expect(source.contains("kind: .hookRegistered"))
        #expect(source.contains("kind: .hookFired"))
        #expect(source.contains("kind: .hookCompleted"))
        #expect(source.contains(#""source": "hook_registry""#))
        #expect(source.contains(#""hook_point": hookPoint"#))
        #expect(!source.contains("MutationOpLog"))
        #expect(!source.contains("RustOpLogFFIClient"))
        #expect(!source.contains("GraphEvent"))
        #expect(!source.contains("ReplayBundle"))
        #expect(!source.contains("ProseEditor"))
        #expect(!source.contains("MetalGraphView"))
        #expect(!source.contains("HologramController"))
        #expect(!source.contains("ChatCoordinator"))
        #expect(!source.contains("PipelineService"))
        #expect(!source.contains("Omega"))
    }

    @Test("graph-only chrome hides sidebar and keeps Metal paused on workspace routes")
    func graphOnlyChromeHidesSidebarAndPausesMetalOnWorkspaceRoutes() throws {
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let embedded = try loadRepoTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")
        let container = try loadRepoTextFile("Epistemos/Views/Graph/GraphWorkspaceContainer.swift")
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")

        #expect(overlay.contains("private func syncGraphWorkspaceChromeVisibility(isCanvas: Bool)"))
        #expect(overlay.contains("private var lastSyncedGraphWorkspaceIsCanvas: Bool?"))
        #expect(overlay.contains("private var fpsHUDHostView: NSView?"))
        #expect(overlay.contains("routeHostView?.isHidden = isCanvas"))
        #expect(overlay.contains("controlsHostView?.isHidden = !isCanvas"))
        #expect(overlay.contains("sidebarHostView?.isHidden = !isCanvas"))
        #expect(overlay.contains("fpsHUDHostView?.isHidden = !isCanvas"))
        #expect(overlay.contains("graphOpenStartTask?.cancel()"))
        #expect(overlay.contains("guard self.graphState.currentRoute.isCanvas else {"))
        #expect(overlay.contains("guard s.graphState.currentRoute.isCanvas else {"))
        #expect(overlay.contains("guard graphState.currentRoute.isCanvas else { return }"))
        #expect(overlay.contains("metalView.pauseEngine()"))
        #expect(overlay.contains("metalView.isHidden = true"))
        #expect(overlay.contains("metalView.alphaValue = 0.0"))
        #expect(overlay.contains("inspectorEjectButton?.isHidden = true"))
        #expect(overlay.contains("miniInspectorPanel?.orderOut(nil)"))
        #expect(overlay.contains("graphView.isHidden = !graphState.currentRoute.isCanvas"))
        #expect(overlay.contains("syncGraphWorkspaceChromeVisibility(isCanvas: graphState.currentRoute.isCanvas)"))
        #expect(embedded.contains("if graphState.currentRoute.isCanvas {\n                HStack(alignment: .top, spacing: 0)"))
        #expect(embedded.contains("if graphState.currentRoute.isCanvas {\n                embeddedFloatingControls"))
        #expect(!container.contains("routeSidebarInset"))
        #expect(!container.contains("GraphSidebarLayout.routedContentLeadingInset"))
        #expect(!container.contains("epistemos.graphSidebarWidth.v1"))
        #expect(!container.contains("GraphHTMLWorkspaceDock("))
        #expect(!container.contains("graphHTMLWorkspaceDockLayer"))
        #expect(overlay.contains("if isCanvas {"))
        #expect(overlay.contains("inspectorHostView?.isHidden = true"))
        #expect(overlay.contains("for view in pinnedInspectorViews.values {"))
        #expect(sidebar.contains("if graphState.currentRoute.isCanvas"))
        #expect(!sidebar.contains(".onChange(of: graphState.currentRoute)"))
        #expect(!sidebar.contains("expandForWorkspaceRoute"))
        #expect(!sidebar.contains("private func expandForWorkspaceRoute"))
        #expect(!sidebar.contains("guard !route.isCanvas else { return }"))
    }

    @Test("bundled note-operation skills stay available to the harness")
    func bundledNoteOperationSkillsStayAvailableToTheHarness() throws {
        let noteRead = try loadMirroredSourceTextFile(".agents/skills/note-read/SKILL.md")
        let noteWrite = try loadMirroredSourceTextFile(".agents/skills/note-write/SKILL.md")
        let noteCreate = try loadMirroredSourceTextFile(".agents/skills/note-create/SKILL.md")
        let noteDelete = try loadMirroredSourceTextFile(".agents/skills/note-delete/SKILL.md")

        #expect(noteRead.contains("name: \"Note Read\""))
        #expect(noteRead.contains("vault.read"))
        #expect(noteWrite.contains("name: \"Note Write\""))
        #expect(noteWrite.contains("vault.write"))
        #expect(noteCreate.contains("name: \"Note Create\""))
        #expect(noteCreate.contains("create a new note"))
        #expect(noteDelete.contains("name: \"Note Delete\""))
        #expect(noteDelete.contains("file.delete"))
    }

    @Test("bundled audit skills keep Codex-compatible frontmatter")
    func bundledAuditSkillsKeepCodexCompatibleFrontmatter() throws {
        let releaseAudit = try loadMirroredSourceTextFile(".agents/skills/epistemos_release_audit/SKILL.md")
        let recursiveAudit = try loadMirroredSourceTextFile(".agents/skills/recursive_app_audit/SKILL.md")

        #expect(releaseAudit.hasPrefix("---\nname: \"Epistemos Release Audit\""))
        #expect(releaseAudit.contains("\n---\n\n# Epistemos Release Audit"))
        #expect(recursiveAudit.hasPrefix("---\nname: \"Recursive App Audit\""))
        #expect(recursiveAudit.contains("\n---\n\n# Recursive App Audit Skill"))
    }

    @Test("code editor release path removes embedded ask-bar policy")
    func codeEditorReleasePathRemovesEmbeddedAskBarPolicy() throws {
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(!codeEditor.contains("availableAskBarResponseModes"))
        #expect(!codeEditor.contains("private func sanitizedAskBarResponseMode("))
        #expect(!codeEditor.contains("CodeAskBarService("))
    }

    @Test("code editor TextKit preview surfaces force horizontal scroller visibility for long-line files")
    func codeEditorTextKitPreviewSurfacesForceHorizontalScrollerVisibility() throws {
        // Per user direction 2026-05-15: long-line files (`.jsonl`,
        // minified `.json`, single-line `.csv` rows) overflow the
        // viewport. TextKit preview scrollers must stay visible so users
        // can discover horizontal overflow immediately.
        //
        // The fix wires `.legacy` scroller style + hasHorizontalScroller +
        // autohidesScrollers=false into the shared TextKit configurator.
        // Pin all three lines so a future
        // refactor that drops one trips this test before regressing
        // the user-facing behavior.
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(codeEditor.contains("scrollView.scrollerStyle = .legacy"))
        #expect(codeEditor.contains("scrollView.hasHorizontalScroller = true"))
        #expect(codeEditor.contains("scrollView.autohidesScrollers = false"))
        #expect(codeEditor.contains("CodeEditorScrollConfigurator.allowTwoAxisScrolling"))
        #expect(codeEditor.contains("textView.textContainer?.widthTracksTextView = false"))
        #expect(codeEditor.contains("textView.isHorizontallyResizable = true"))
        #expect(codeEditor.contains("textView.autoresizingMask = [.height]"))
        #expect(codeEditor.contains("horizontalScrollElasticity = .allowed"))
        #expect(!codeEditor.contains("CodeEditorScrollConfigurator.allowCodeEditTwoAxisScrolling"))
    }

    @Test("code editor theme normalizes transparent and system colors into RGB space")
    func codeEditorThemeNormalizesTransparentAndSystemColorsIntoRGBSpace() {
        let transparentBackground = NSColor.clear.rgbSafeForCodeEditorTheme()
        let systemSelection = NSColor.selectedTextBackgroundColor
            .withAlphaComponent(0.28)
            .rgbSafeForCodeEditorTheme()

        #expect(transparentBackground.colorSpace.colorSpaceModel == .rgb)
        #expect(systemSelection.colorSpace.colorSpaceModel == .rgb)
        #expect(abs(transparentBackground.alphaComponent - NSColor.clear.alphaComponent) < 0.0001)
        #expect(abs(systemSelection.alphaComponent - 0.28) < 0.0001)
    }

    @Test("harness perf hotspots reuse shared timestamp helpers")
    func harnessPerfHotspotsReuseSharedHelpers() throws {
        let progressStore = try loadRepoTextFile("Epistemos/Harness/ProgressStore.swift")
        let harnessRegistry = try loadRepoTextFile("Epistemos/Harness/HarnessRegistry.swift")
        let harnessLab = try loadRepoTextFile("Epistemos/Harness/HarnessLab.swift")

        #expect(progressStore.contains("private static func sortedSessionDirectories("))
        #expect(progressStore.contains("private static func sessionDirectoryEntries("))

        #expect(harnessRegistry.contains("private nonisolated static func timestampString("))
        #expect(!harnessRegistry.contains("ISO8601DateFormatter().string(from: Date())"))

        #expect(harnessLab.contains("private enum HarnessLabTime"))
        #expect(harnessLab.contains("static func timestampString("))
        #expect(!harnessLab.contains("ISO8601DateFormatter().string(from: Date())"))
    }

    @Test("graph label runtime surfaces log atlas failures and keep labels available in performance mode")
    func graphLabelRuntimeSurfacesLogFailuresAndKeepPerformanceLabels() throws {
        let metalGraph = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        let renderer = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")

        #expect(metalGraph.contains("failed to load label atlas"))
        #expect(metalGraph.contains("labelMaxNodes"))
        #expect(metalGraph.contains("labelZoomBias"))
        #expect(!renderer.contains("if !self.labels_enabled || self.quality_level >= 2 {"))
    }

    @Test("landing perf seams share explicit delay helpers")
    func landingAndAdminPerfSeamsShareExplicitDelayHelpers() throws {
        let workspaceSwitcher = try loadRepoTextFile("Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift")

        #expect(workspaceSwitcher.contains("private enum WorkspaceSwitcherOverlayTiming"))
        #expect(workspaceSwitcher.contains("private func performAfterDismiss("))
        #expect(workspaceSwitcher.contains("private func pause(_ duration: Duration) async -> Bool"))
        #expect(!workspaceSwitcher.contains("try? await Task.sleep(for: .milliseconds(150))"))
    }

    #if false
    @Test("omega note and checkpoint surfaces avoid silent persistence fallbacks")
    func omegaNoteAndCheckpointSurfacesAvoidSilentFallbacks() throws {}
    #endif

    #if false
    @Test("Hermes health check requires a live bridge ping before reporting healthy")
    func hermesHealthCheckRequiresLiveBridgePing() throws {}
    #endif

    @Test("long-lived subprocess continuations have timeout and cancellation escape hatches")
    func longLivedSubprocessContinuationsHaveTimeoutAndCancellationEscapeHatches() throws {
        let vaultMutator = try loadRepoTextFile("Epistemos/Vault/VaultChatMutator.swift")

        #expect(vaultMutator.contains("withTaskCancellationHandler"))
        #expect(vaultMutator.contains("ThrowingProcessContinuationState<String>()"))
        #expect(vaultMutator.contains("TimeoutError(seconds: timeoutSeconds)"))
        #expect(!vaultMutator.contains("process.waitUntilExit()"))
    }

    @Test("setup and harness subprocess helpers terminate on cancellation")
    func setupAndHarnessSubprocessHelpersTerminateOnCancellation() throws {
        let completionChecker = try loadRepoTextFile("Epistemos/Harness/CompletionChecker.swift")
        let harnessLab = try loadRepoTextFile("Epistemos/Harness/HarnessLab.swift")
        let evalSandbox = try loadRepoTextFile("Epistemos/Harness/EvalSandbox.swift")

        #expect(completionChecker.contains("withTaskCancellationHandler"))
        #expect(completionChecker.contains("ProcessContinuationState<ProcessResult>()"))
        #expect(completionChecker.contains("Cancelled \\(executable)"))

        #expect(harnessLab.contains("withTaskCancellationHandler"))
        #expect(harnessLab.contains("ProcessContinuationState<ProcessResult>()"))
        #expect(harnessLab.contains("Cancelled proposer agent"))

        #expect(evalSandbox.contains("withTaskCancellationHandler"))
        #expect(evalSandbox.contains("ProcessContinuationState<ProcessResult>()"))
        #expect(evalSandbox.contains("Cancelled sandboxed command"))
    }

    @Test("main actor capture and vault helpers offload blocking subprocess waits")
    func mainActorCaptureAndVaultHelpersOffloadBlockingSubprocessWaits() throws {
        let vaultMutator = try loadRepoTextFile("Epistemos/Vault/VaultChatMutator.swift")
        // screenCapture (ScreenCaptureService.swift) removed with cloud-only/Omega removal 2026-07-03

        #expect(vaultMutator.contains("private nonisolated func runGitOffMain("))
        #expect(vaultMutator.contains("try await runGitOffMain("))
        #expect(vaultMutator.contains("DispatchQueue.global(qos: .utility).async"))
    }

    #if false
    @Test("Agent heartbeat monitors Hermes after dispatch instead of blind sleeping to completion")
    func agentHeartbeatMonitorsHermesAfterDispatch() throws {}

    @Test("Agent heartbeat monitoring handles cancellation explicitly")
    func agentHeartbeatMonitoringHandlesCancellationExplicitly() throws {}
    #endif

    @Test("Supervisor background sleep paths no longer swallow cancellation")
    func supervisorBackgroundSleepPathsNoLongerSwallowCancellation() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(!appSupervisor.contains("try? await Task.sleep(for: .seconds(60))"))
        #expect(!appSupervisor.contains("try? await Task.sleep(for: .seconds(interval))"))
        #expect(!appSupervisor.contains("try? await Task.sleep(for: .seconds(delay))"))
        #expect(appSupervisor.contains("catch is CancellationError"))
    }

    // "Ambient capture runtime paths no longer swallow debounce or parse failures" removed
    // with cloud-only/Omega removal 2026-07-03 — AmbientCaptureService.swift (Omega ambient
    // capture chain: ScreenCapture -> Screen2AXFusion -> VisualVerifyLoop -> AmbientCapture) was deleted.

    @Test("duration formatters guard non-finite doubles before Int conversion")
    func durationFormattersGuardNonFiniteDoublesBeforeIntConversion() throws {
        #expect(!FileManager.default.fileExists(atPath: repoRootURL.appendingPathComponent("Epistemos/Views/Chat/ThinkingTrailView.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRootURL.appendingPathComponent("Epistemos/Views/Chat/ThinkingPopoverView.swift").path))
    }

    @Test("animated delay paths sanitize non-finite timing before milliseconds casts")
    func animatedDelayPathsSanitizeNonFiniteTimingBeforeMillisecondsCasts() throws {
        let typewriter = try loadRepoTextFile("Epistemos/Views/Shared/TypewriterASCIIRippleText.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let noteWorkspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(typewriter.contains("let safeInitialDelay = initialDelay.isFinite ? max(0, initialDelay) : 0"))
        #expect(typewriter.contains("let safeTypingSpeed = typingSpeed.isFinite ? max(0, typingSpeed) : 0"))
        #expect(rootView.contains("let safeDelay = delay.isFinite ? max(0, delay) : 0"))
        #expect(noteWorkspace.contains("let safeHoldTime = holdTime.isFinite ? max(0, holdTime) : 0"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadRepoTextFileWithRetry(relativePath: relativePath, testsFilePath: #filePath)
    }
}

@Suite("Inference Cloud Selection", .serialized)
struct InferenceCloudSelectionTests {
    private let inferenceDefaultsKeys = [
        "epistemos.localRoutingMode",
        "epistemos.preferredLocalTextModelID",
        "epistemos.preferredChatModelSelection",
        "epistemos.activeAIProvider",
        "epistemos.lastNonLocalAIProvider",
        "epistemos.openAIWebSearchEnabled",
        "epistemos.openAICodeInterpreterEnabled",
        "epistemos.anthropicExtendedThinkingEnabled",
        "epistemos.anthropicWebSearchEnabled",
        "epistemos.anthropicWebFetchEnabled",
        "epistemos.anthropicCodeExecutionEnabled",
        "epistemos.googleGroundingEnabled",
        "epistemos.cloudSetupHintShown",
        "epistemos.preferredCloudModel.openAI",
        "epistemos.preferredCloudModel.anthropic",
        "epistemos.preferredCloudModel.google",
        "epistemos.preferredCloudModel.zai",
        "epistemos.preferredCloudModel.kimi",
        "epistemos.preferredCloudModel.minimax",
        "epistemos.preferredCloudModel.deepseek",
    ]

    @MainActor
    private func withResetInferenceDefaults(
        _ body: () async throws -> Void
    ) async rethrows {
        let defaults = UserDefaults.standard
        let savedValues = inferenceDefaultsKeys.reduce(into: [String: Any?]()) { partialResult, key in
            partialResult[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in inferenceDefaultsKeys {
                if let value = savedValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try await body()
    }

    // Cloud-only migration: "unconfigured cloud selection keeps a visible cloud
    // intent while preserving the local fallback" removed — the local-fallback
    // (.localMLX(preferredLocalTextModelID)) behavior it asserted was deleted.

    @MainActor
    @Test("curated provider cloud preferences normalize hidden models back to visible picker models")
    func curatedProviderCloudPreferencesNormalizeHiddenModelsBackToVisiblePickerModels() async {
        await withResetInferenceDefaults {
            let defaults = UserDefaults.standard
            defaults.set(
                CloudTextModelID.openAIO3.rawValue,
                forKey: "epistemos.preferredCloudModel.openAI"
            )
            defaults.set(
                CloudTextModelID.anthropicClaudeSonnet4.rawValue,
                forKey: "epistemos.preferredCloudModel.anthropic"
            )
            defaults.set(
                CloudTextModelID.googleGemini25Flash.rawValue,
                forKey: "epistemos.preferredCloudModel.google"
            )

            let store = TestKeychainStore(values: [
                CloudModelProvider.openAI.apiKeyKeychainKey: "openai-test-key",
                CloudModelProvider.anthropic.apiKeyKeychainKey: "anthropic-test-key",
                CloudModelProvider.google.apiKeyKeychainKey: "google-test-key",
            ])
            let inference = InferenceState(
                keychainLoad: store.load(_:),
                keychainSave: store.save(_:_:),
                keychainDelete: store.delete(_:)
            )

            #expect(inference.preferredCloudModel(for: .openAI) == .openAIGPT54)
            #expect(inference.preferredCloudModel(for: .anthropic) == .anthropicClaudeSonnet46)
            #expect(inference.preferredCloudModel(for: .google) == .googleGemini3FlashPreview)
            #expect(inference.cloudModels(for: .openAI).contains(inference.preferredCloudModel(for: .openAI)))
            #expect(inference.cloudModels(for: .anthropic).contains(inference.preferredCloudModel(for: .anthropic)))
            #expect(inference.cloudModels(for: .google).contains(inference.preferredCloudModel(for: .google)))
        }
    }

    @MainActor
    @Test("active AI provider scopes cloud models and remembers the last model per provider")
    func activeAIProviderScopesCloudModelsAndRemembersProviderModels() async {
        await withResetInferenceDefaults {
            let store = TestKeychainStore(values: [
                CloudModelProvider.openAI.apiKeyKeychainKey: "openai-test-key",
                CloudModelProvider.anthropic.apiKeyKeychainKey: "anthropic-test-key",
                CloudModelProvider.zai.apiKeyKeychainKey: "zai-test-key",
                CloudModelProvider.kimi.apiKeyKeychainKey: "kimi-test-key",
                CloudModelProvider.minimax.apiKeyKeychainKey: "minimax-test-key",
                CloudModelProvider.deepseek.apiKeyKeychainKey: "deepseek-test-key",
            ])
            let inference = InferenceState(
                keychainLoad: store.load(_:),
                keychainSave: store.save(_:_:),
                keychainDelete: store.delete(_:)
            )

            #expect(inference.activeAIProvider == .openAI)
            #expect(inference.activeCloudProvider == .openAI)
            #expect(inference.activeCloudModels == CloudTextModelID.models(for: .openAI))

            inference.setPreferredChatModelSelection(.cloud(.openAIGPT54Mini))
            inference.setActiveAIProvider(.anthropic)

            #expect(inference.activeAIProvider == .anthropic)
            #expect(inference.activeCloudProvider == .anthropic)
            #expect(inference.activeCloudModels == CloudTextModelID.models(for: .anthropic))
            #expect(inference.preferredChatModelSelection == .cloud(.anthropicClaudeSonnet46))

            inference.setPreferredChatModelSelection(.cloud(.anthropicClaudeOpus47))
            inference.setActiveAIProvider(.openAI)
            inference.setActiveAIProvider(.anthropic)
            #expect(inference.preferredChatModelSelection == .cloud(.anthropicClaudeOpus47))

            inference.setActiveAIProvider(.deepseek)
            #expect(inference.activeCloudProvider == .deepseek)
            #expect(inference.activeCloudModels == CloudTextModelID.models(for: .deepseek))
        }
    }

    @MainActor
    @Test("cloud mode toggle keeps local-only routing explicit and restores the last cloud provider")
    func cloudModeToggleKeepsLocalOnlyRoutingExplicit() async {
        await withResetInferenceDefaults {
            let store = TestKeychainStore(values: [
                CloudModelProvider.openAI.apiKeyKeychainKey: "openai-test-key",
                CloudModelProvider.anthropic.apiKeyKeychainKey: "anthropic-test-key",
            ])
            let inference = InferenceState(
                keychainLoad: store.load(_:),
                keychainSave: store.save(_:_:),
                keychainDelete: store.delete(_:)
            )

            #expect(inference.activeAIProvider == .openAI)
            inference.setPreferredChatModelSelection(.cloud(.anthropicClaudeSonnet46))
            inference.setActiveAIProvider(.anthropic)
            #expect(inference.activeAIProvider == .anthropic)

            inference.setCloudModelsEnabled(false)
            #expect(inference.activeAIProvider == .localOnly)

            inference.setCloudModelsEnabled(true)
            #expect(inference.activeAIProvider == .anthropic)
        }
    }

    @MainActor
    @Test("provider-native search defaults stay enabled unless explicitly disabled")
    func providerNativeSearchDefaultsStayEnabledUnlessDisabled() async {
        await withResetInferenceDefaults {
            let fresh = InferenceState()
            #expect(fresh.openAIWebSearchEnabled)
            #expect(fresh.anthropicWebSearchEnabled)
            #expect(fresh.anthropicWebFetchEnabled)
            #expect(fresh.anthropicCodeExecutionEnabled)
            #expect(fresh.googleGroundingEnabled)

            fresh.setOpenAIWebSearchEnabled(false)
            fresh.setAnthropicWebSearchEnabled(false)
            fresh.setAnthropicWebFetchEnabled(false)
            fresh.setAnthropicCodeExecutionEnabled(false)
            fresh.setGoogleGroundingEnabled(false)

            let reloaded = InferenceState()
            #expect(!reloaded.openAIWebSearchEnabled)
            #expect(!reloaded.anthropicWebSearchEnabled)
            #expect(!reloaded.anthropicWebFetchEnabled)
            #expect(!reloaded.anthropicCodeExecutionEnabled)
            #expect(!reloaded.googleGroundingEnabled)
        }
    }

    @MainActor
    @Test("provider runtime controls and Firecrawl key persist through inference state")
    func providerRuntimeControlsAndFirecrawlKeyPersistThroughInferenceState() async {
        await withResetInferenceDefaults {
            let store = TestKeychainStore()
            let inference = InferenceState(
                keychainLoad: store.load(_:),
                keychainSave: store.save(_:_:),
                keychainDelete: store.delete(_:)
            )

            #expect(inference.openAIWebSearchEnabled)
            #expect(!inference.openAICodeInterpreterEnabled)
            #expect(!inference.anthropicAdaptiveThinkingEnabled)
            #expect(inference.anthropicWebSearchEnabled)
            #expect(inference.anthropicWebFetchEnabled)
            #expect(inference.anthropicCodeExecutionEnabled)
            #expect(inference.googleGroundingEnabled)
            #expect(inference.firecrawlAPIKey() == nil)

            inference.setOpenAIWebSearchEnabled(false)
            inference.setOpenAIWebSearchEnabled(true)
            inference.setOpenAICodeInterpreterEnabled(true)
            inference.setAnthropicAdaptiveThinkingEnabled(true)
            inference.setAnthropicWebSearchEnabled(false)
            inference.setAnthropicWebSearchEnabled(true)
            inference.setAnthropicWebFetchEnabled(false)
            inference.setAnthropicWebFetchEnabled(true)
            inference.setAnthropicCodeExecutionEnabled(false)
            inference.setAnthropicCodeExecutionEnabled(true)
            inference.setGoogleGroundingEnabled(false)
            inference.setGoogleGroundingEnabled(true)
            _ = inference.setFirecrawlAPIKey("fc-test-key")

            #expect(inference.openAIWebSearchEnabled)
            #expect(inference.openAICodeInterpreterEnabled)
            #expect(inference.anthropicAdaptiveThinkingEnabled)
            #expect(inference.anthropicWebSearchEnabled)
            #expect(inference.anthropicWebFetchEnabled)
            #expect(inference.anthropicCodeExecutionEnabled)
            #expect(inference.googleGroundingEnabled)
            #expect(inference.firecrawlAPIKey() == "fc-test-key")

            _ = inference.setFirecrawlAPIKey("")
            #expect(inference.firecrawlAPIKey() == nil)
        }
    }

    @MainActor
    @Test("cloud setup hint shows once and stays dismissed after first-use guidance")
    func cloudSetupHintShowsOnceAndPersistsDismissal() async {
        await withResetInferenceDefaults {
            let store = TestKeychainStore()
            let inference = InferenceState(
                keychainLoad: store.load(_:),
                keychainSave: store.save(_:_:),
                keychainDelete: store.delete(_:)
            )

            #expect(inference.shouldShowCloudSetupHint)
            inference.markCloudSetupHintShown()
            #expect(!inference.shouldShowCloudSetupHint)

            let reloaded = InferenceState(
                keychainLoad: store.load(_:),
                keychainSave: store.save(_:_:),
                keychainDelete: store.delete(_:)
            )
            #expect(!reloaded.shouldShowCloudSetupHint)
        }
    }

    @Test("inference settings keep openai first cloud controls advanced mode and remind-later hints")
    func inferenceSettingsKeepOpenAIFirstCloudControlsAndHints() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )

        #expect(settings.contains("Settings Mode"))
        #expect(settings.contains("Regular"))
        #expect(settings.contains("Advanced"))
        #expect(settings.contains("Enable Cloud Models"))
        #expect(settings.contains("Active Cloud"))
        #expect(settings.contains("Cloud Access Health"))
        #expect(settings.contains("CloudProviderAccessHealthRow"))
        #expect(settings.contains("inference.apiKey(for: provider)"))
        #expect(settings.contains("inference.oauthCredential(for: provider)"))
        #expect(settings.contains("Other Cloud Providers"))
        #expect(settings.contains("OpenAI Recommended"))
        #expect(settings.contains("Remind Me Later"))
        #expect(settings.contains("API Key (manual)"))
        #expect(settings.contains("showCloudSetupHint"))
        #expect(settings.contains("cloudSetupHintPopover"))
        #expect(settings.contains("CloudHintPopover"))
        #expect(inference.contains("cloudSetupHintShownDefaultsKey"))
        #expect(inference.contains("shouldShowCloudSetupHint"))
        #expect(inference.contains("markCloudSetupHintShown"))
        #expect(inference.contains("setCloudModelsEnabled"))
        #expect(inference.contains("lastNonLocalAIProviderDefaultsKey"))
    }

    @Test("OpenAI OAuth checking has a hard timeout and explicit retry affordances")
    func openAIOAuthCheckingHasTimeoutAndRetryAffordances() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("openAISignInTimeout: Duration = .seconds(90)"))
        #expect(authService.contains("Task.sleep(for: timeout)"))
        #expect(authService.contains("throw CloudProviderAuthError.openAIDeviceCodeTimedOut"))
        #expect(settings.contains("Retry OpenAI Sign In"))
    }

    @Test("local model install errors include friendly corruption guidance")
    func localModelInstallErrorsIncludeFriendlyCorruptionGuidance() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        ).localizedLowercase

        #expect(settings.contains("incomplete or corrupted"))
        #expect(settings.contains("retry the install"))
        #expect(settings.contains("restage the snapshot"))
    }

    @Test("OpenAI Codex auth and validation routes carry the required client version")
    func openAICodexAuthAndValidationRoutesCarryTheRequiredClientVersion() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let llmService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/LLMService.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("enum OpenAICodexRuntimeMetadata"))
        #expect(authService.contains("static let clientVersion"))
        #expect(authService.contains("URLQueryItem(name: \"client_version\""))
        #expect(llmService.contains("OpenAICodexRuntimeMetadata.url(appendingClientVersionTo:"))
        #expect(llmService.contains("/backend-api/codex"))
    }

    @Test("Anthropic adaptive thinking stays aligned across runtime and settings")
    func anthropicAdaptiveThinkingStaysAlignedAcrossRuntimeAndSettings() throws {
        let llmService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/LLMService.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let rootView = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )

        #expect(llmService.contains("\"type\": \"adaptive\""))
        #expect(llmService.contains("\"effort\":"))
        #expect(!llmService.contains("\"budget_tokens\""))
        #expect(settings.contains("Enable Adaptive Thinking"))
        #expect(!settings.contains("Enable Extended Thinking"))
        #expect(!settings.contains("Thinking Budget"))
        #expect(rootView.contains("Enable Adaptive Thinking"))
        #expect(!rootView.contains("Enable Extended Thinking"))
    }

    @Test("Anthropic adaptive thinking naming stays consistent in inference state and UI call sites")
    func anthropicAdaptiveThinkingNamingStaysConsistentAcrossSymbols() throws {
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let rootView = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )
        let llmService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/LLMService.swift",
            testsFilePath: #filePath
        )

        #expect(inference.contains("anthropicAdaptiveThinkingEnabled"))
        #expect(inference.contains("setAnthropicAdaptiveThinkingEnabled"))
        #expect(!inference.contains("var anthropicExtendedThinkingEnabled"))
        #expect(!inference.contains("func setAnthropicExtendedThinkingEnabled"))
        #expect(settings.contains("anthropicAdaptiveThinkingEnabled"))
        #expect(rootView.contains("anthropicAdaptiveThinkingEnabled"))
        #expect(llmService.contains("anthropicAdaptiveThinkingEnabled"))
    }

    @Test("OpenAI OAuth shows the device code directly in the app")
    func openAIOAuthShowsTheDeviceCodeDirectlyInTheApp() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("onDeviceCodeReady"))
        #expect(inference.contains("onDeviceCodeReady"))
        #expect(settings.contains("@State private var openAIDeviceAuthorization"))
        #expect(settings.contains("OpenAIDeviceAuthorizationSheet"))
        #expect(sharedCard.contains("struct OpenAIDeviceAuthorizationSheet"))
        #expect(sharedCard.contains("Copy Code"))
        #expect(sharedCard.contains("Open Verification Page"))
    }

    @Test("Anthropic import surfaces account status, retry, and connected account details")
    func anthropicImportSurfacesAccountStatusRetryAndConnectedAccountDetails() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("AnthropicClaudeCodeImportResult"))
        #expect(authService.contains("func anthropicClaudeCodeCredential(from data: Data)"))
        #expect(authService.contains("accountLabel: Self.inferredAnthropicAccountLabel"))
        #expect(inference.contains("cloudProviderValidationStates[.anthropic] = .checking"))
        #expect(inference.contains("Connected as \\(accountLabel)."))
        #expect(inference.contains("No account session connected"))
        #expect(settings.contains("Retry Claude Code Import"))
        #expect(settings.contains("CloudProviderAccountConnectionRow"))
        #expect(sharedCard.contains("CloudProviderAccountConnectionRow"))
    }

    @Test("Google OAuth surfaces timeout, retry, and connected account confirmation")
    func googleOAuthSurfacesTimeoutRetryAndConnectedAccountConfirmation() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("googleSignInTimeout: Duration = .seconds(90)"))
        #expect(authService.contains("waitForAuthorizationResult(timeout: googleSignInTimeout)"))
        #expect(authService.contains("resolveFailureIfNeeded(CloudProviderAuthError.googleAuthorizationTimedOut)"))
        #expect(authService.contains("fetchGoogleAccountLabel"))
        #expect(authService.contains("func googleAccountLabel(fromUserInfoData data: Data)"))
        #expect(inference.contains("recordCloudProviderValidationFailure"))
        #expect(inference.contains("Connected as \\(accountLabel)."))
        #expect(settings.contains("Retry Google OAuth"))
        #expect(settings.contains("CloudProviderAccountConnectionRow"))
    }

    @Test("OAuth provider settings require verified access before activation")
    func oauthProviderSettingsRequireVerifiedAccessBeforeActivation() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("func openAIAccountLabel(fromAccessToken token: String) -> String?"))
        #expect(inference.contains("var isVerified: Bool"))
        #expect(inference.contains("\"Saved\""))
        #expect(inference.contains("\"Verified\""))
        #expect(inference.contains("This check times out after 90 seconds."))
        #expect(inference.contains("Run a live check before making this provider active."))
        #expect(inference.contains("CloudProviderAccountConnectionState"))
        #expect(inference.contains("If OpenAI asks you to enable access first"))
        #expect(inference.contains("Claude Code needs to be signed in first"))
        #expect(settings.contains(".disabled(!validationState.isVerified)"))
        #expect(settings.contains("Verify live access before making this provider active."))
        #expect(inference.contains("Connect Google OAuth first with the Desktop-app client JSON from Google Cloud Console and the matching Google Cloud project ID"))
    }

    @Test("legacy keys and Google draft auth inputs surface explicit validation feedback")
    func legacyKeysAndGoogleDraftAuthInputsSurfaceExplicitValidationFeedback() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("let projectID = (container[\"project_id\"] as? String)?"))
        #expect(!authService.contains("guard !projectID.isEmpty"))
        #expect(inference.contains("func resetCloudProviderValidationState(for provider: CloudModelProvider)"))
        #expect(inference.contains("No Codex account session was found in ~/.codex/auth.json."))
        #expect(inference.contains("cloudProviderValidationStates[.openAI] = .invalid"))
        #expect(inference.contains("Paste or type a non-empty"))
        #expect(inference.contains("Clipboard doesn't contain a non-empty"))
        #expect(settings.contains("Couldn't read the selected Google OAuth client JSON file."))
        #expect(settings.contains("Choose the Google OAuth client JSON you downloaded from Google Cloud Console for a Desktop app before connecting Google OAuth."))
        #expect(settings.contains("Enter the Google Cloud project ID for the same project where Gemini API is enabled before connecting Google OAuth."))
        #expect(settings.contains("Google OAuth client JSON verified."))
        #expect(settings.contains("Clear Google OAuth JSON"))
        #expect(settings.contains("CloudProviderSetupAutomation.loadGoogleOAuthClientConfigData()"))
        #expect(settings.contains("CloudProviderSetupAutomation.loadGoogleOAuthClientFilename()"))
        #expect(settings.contains("CloudProviderSetupAutomation.loadGoogleOAuthProjectIDDraft()"))
        #expect(settings.contains("CloudProviderSetupAutomation.persistGoogleOAuthProjectIDDraft(newValue)"))
        #expect(settings.contains("CloudProviderSetupAutomation.persistGoogleOAuthClientConfig("))
        #expect(settings.contains("Removed the saved Google OAuth client JSON."))
        #expect(inference.contains("Clipboard doesn't contain a non-empty"))
    }

    @Test("Google OAuth setup copy explains the exact JSON file and project ID")
    func googleOAuthSetupCopyExplainsTheExactJSONFileAndProjectID() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("installed.client_id"))
        #expect(authService.contains("installed.client_secret"))
        #expect(settings.contains("Choose Google OAuth JSON"))
        #expect(settings.contains("Google Cloud project ID (not project number)"))
        #expect(settings.contains("Choose the OAuth client JSON you downloaded from Google Cloud Console after creating an OAuth client ID for a Desktop app."))
        #expect(settings.contains("Enter the Google Cloud project ID for the same Gemini-enabled project."))
        #expect(inference.contains("create an OAuth client ID for a Desktop app"))
    }

    @Test("saved provider access exposes a visible top-level check action")
    func savedProviderAccessExposesAVisibleTopLevelCheckAction() throws {
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(inference.contains("Tap Check Access before making this provider active."))
        #expect(settings.contains("if hasOAuthSession || hasSavedAPIKey"))
        #expect(settings.contains("Button(validationState.isVerified ? \"Re-check Access\" : \"Check Access\")"))
        #expect(settings.contains("Task { _ = await inference.validateCloudAccess(for: provider) }"))
    }

    @Test("inference settings support regular and advanced presentation")
    func inferenceSettingsSupportRegularAndAdvancedPresentation() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(settings.contains("@AppStorage(\"epistemos.inferenceAdvancedSettingsEnabled\")"))
        #expect(settings.contains("Settings Mode"))
        #expect(settings.contains("Text(\"Regular\")"))
        #expect(settings.contains("Text(\"Advanced\")"))
        #expect(settings.contains("if showsAdvancedSettings"))
        #expect(settings.contains("Enable Cloud Models"))
        #expect(settings.contains("Active Cloud"))
        #expect(settings.contains("Other Cloud Providers"))
    }

    @Test("settings hints support native popovers and remind-later actions")
    func settingsHintsSupportNativePopoversAndRemindLaterActions() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(settings.contains("SettingsHelpHeader"))
        #expect(settings.contains("CloudHintPopover"))
        #expect(settings.contains("showSettingsModeHint"))
        #expect(settings.contains("showRoutingHint"))
        #expect(settings.contains("showLocalAIHint"))
        #expect(settings.contains("showOtherCloudProvidersHint"))
        #expect(settings.contains("showResponseTokensHint"))
        #expect(settings.contains("Button(\"Remind Me Later\")"))
        #expect(settings.contains("Button(\"Got It\")"))
        #expect(settings.contains("questionmark.circle"))
        #expect(settings.contains(".popover("))
    }

    @Test("runtime popover uses available operating modes instead of disabled all-cases")
    func runtimePopoverUsesAvailableOperatingModesInsteadOfDisabledAllCases() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("ForEach(displayedOperatingModes"))
        #expect(!source.contains("ForEach(EpistemosOperatingMode.allCases"))
        #expect(source.contains(".easeInOut(duration: 0.15)"))
    }

    @Test("runtime popover exposes explicit chat routing controls")
    func runtimePopoverExposesExplicitChatRoutingControls() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("Text(\"Fallback on failure\")"))
        #expect(source.contains("inference.setCloudAutoFallback($0)"))
        #expect(source.contains("routeSummaryCard(for:"))
        #expect(source.contains("inference.setPreferredCloudModel(model)"))
    }

    @Test("toolbar popovers share one local model disclosure implementation")
    func toolbarPopoversShareOneLocalModelDisclosureImplementation() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("private func localModelsDisclosure("))
        #expect(source.contains("private func localModelRows("))
        #expect(!source.contains("@State private var showsCloudModels = true"))
        #expect(source.contains("localModelsDisclosure(closeAction: {"))
    }

    @Test("inference settings keep cloud credential drafts scoped to the curated provider set")
    func inferenceSettingsKeepCloudCredentialDraftsScopedToCuratedProviderSet() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("@State private var cloudAPIKeyDrafts: [CloudModelProvider: String] = [:]"))
        #expect(source.contains("private func cloudAPIKeyDraftBinding(for provider: CloudModelProvider) -> Binding<String>"))
        #expect(source.contains("for provider in CloudModelProvider.preferredOrder"))
        #expect(!source.contains("@State private var openAIKey = \"\""))
        #expect(!source.contains("@State private var zaiKey = \"\""))
        #expect(!source.contains("zaiKey = inference.apiKey(for: .zai) ?? \"\""))
        #expect(!source.contains("case .zai:"))
    }

    // "local model picker uses curated display names outside the unified qwen row" removed
    // with cloud-only/Omega removal 2026-07-03 — LocalTextModelID / localRouteDisplayName /
    // the local display-name catalog ("Qwen 3", etc.) were deleted from InferenceState.

    @MainActor
    @Test("clearing the active cloud provider key sanitizes the selected chat model")
    func clearingActiveCloudProviderKeySanitizesSelectedChatModel() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("guard let activeCloudProvider = provider.cloudProvider else"))
        #expect(source.contains("guard hasConfiguredCloudAccess(for: activeCloudProvider) else"))
        // persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID)) assert removed
        // with cloud-only/Omega removal 2026-07-03 — preferredLocalTextModelID was deleted; the
        // sanitizer now persists a cloud fallback selection.
    }

    #if false
    @Test("agent runtime route supports account-backed cloud credentials")
    func agentRuntimeRouteSupportsAccountBackedCloudCredentials() throws {}
    #endif

    @Test("vault registry and session browser expose shared helpers for vault services")
    func vaultRegistryAndSessionBrowserExposeSharedHelpersForVaultServices() throws {
        let registry = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/VaultRegistry.swift",
            testsFilePath: #filePath
        )
        let browser = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/SessionBrowser.swift",
            testsFilePath: #filePath
        )

        #expect(registry.contains("static let shared = VaultRegistry()"))
        #expect(registry.contains("func resolveVaultPath(for identity: VaultIdentity) -> String?"))
        #expect(browser.contains("static let shared = SessionBrowser()"))
        #expect(browser.contains("var sessions: [SessionInfo]"))
        #expect(browser.contains("func refreshSessions(for vaultIdentity: VaultIdentity)"))
        #expect(browser.contains("var sessionId: String { id }"))
    }

    @Test("skill evolution uses dedicated trace models and live trace inputs")
    func skillEvolutionUsesDedicatedTraceModelsAndLiveTraceInputs() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/SkillEvolutionService.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("struct SkillTraceEvent"))
        #expect(!source.contains("struct TraceEvent"))
        #expect(source.contains("lastPathComponent == \"trace.json\""))
        #expect(source.contains("pathExtension == \"jsonl\""))
        #expect(source.contains("SkillMutationProposal(from: decodedProposal)"))
    }

    @Test("channel agent entry points keep reads human-approved")
    func channelAgentEntryPointsKeepReadsHumanApproved() throws {
        let iMessageDriver = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Omega/iMessageDriver/IMessageDriverService.swift",
            testsFilePath: #filePath
        )
        let iMessageDelegate = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift",
            testsFilePath: #filePath
        )

        #expect(iMessageDriver.contains("autoApproveReads: false"))
        #expect(iMessageDelegate.contains("case .localDataRead, .localDataWrite, .destructive:"))
        #expect(iMessageDelegate.contains("case .genericRead:"))
        #expect(!iMessageDriver.contains("autoApproveReads: true"))
    }

    @Test("channel safety copy reflects that vault writes stay gated even with auto approve enabled")
    func channelSafetyCopyReflectsThatVaultWritesStayGated() throws {
        let iMessageSettings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/IMessageDriverSettingsView.swift",
            testsFilePath: #filePath
        )
        let channelsSettings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/ChannelsSettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(iMessageSettings.contains("Sensitive local reads plus any vault or workspace writes still require on-device approval"))
        #expect(channelsSettings.contains("Sensitive local reads plus vault or workspace writes still require an on-device approval surface."))
        #expect(!iMessageSettings.contains("write to the vault without prompting"))
    }

    // "cloud fallback chains try the local runtime before Apple Intelligence" removed with
    // cloud-only/Omega removal 2026-07-03 — the local generate/stream fallbacks
    // (localGenerateOrFallback / localStreamOrFallback / lastDecision = .localMLX) were
    // deleted from TriageService; there is no local runtime to order before Apple Intelligence.

    @Test("streaming delegate and rust agent loop return native computer-use results")
    func streamingDelegateAndRustAgentLoopReturnNativeComputerUseResults() throws {
        let swift = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Bridge/StreamingDelegate.swift",
            testsFilePath: #filePath
        )
        let bridge = try loadRepoTextFileWithRetry(
            relativePath: "agent_core/src/bridge.rs",
            testsFilePath: #filePath
        )
        let loop = try loadRepoTextFileWithRetry(
            relativePath: "agent_core/src/agent_loop.rs",
            testsFilePath: #filePath
        )

        #expect(swift.contains("func executeComputerAction(actionJson: String) -> String"))
        // ComputerUseBridge.shared.execute dispatch removed with cloud-only/Omega removal
        // 2026-07-03 — the Swift executeComputerAction impl is now a cloud-only stub. The Rust
        // agent_core bridge/loop keep the execute_computer_action seam (verified present below).
        #expect(bridge.contains("fn execute_computer_action(&self, action_json: String) -> String;"))
        #expect(loop.contains("delegate.execute_computer_action(input_json.clone())"))
    }

    @Test("code editor strips embedded assistant surfaces and stays focused on editing")
    func codeEditorStripsEmbeddedAssistantSurfacesAndStaysFocusedOnEditing() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/CodeEditorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains(".onDisappear"))
        #expect(!source.contains("InlineSuggestionOverlay("))
        #expect(!source.contains("CodeAskBarService("))
        #expect(!source.contains("AIPartnerService("))
    }

    @Test("code editor semantic surfaces cancel background work when dismissed")
    func codeEditorSemanticSurfacesCancelBackgroundWorkWhenDismissed() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/CodeEditorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("bridge.cancelPendingWork()"))
        #expect(source.contains("insightGenerator.cancelGeneration()"))
        #expect(source.contains("generator.cancelGeneration()"))
    }

    @Test("code editor note creation persists to managed storage and marks vault sync")
    func codeEditorNoteCreationPersistsToManagedStorageAndMarksVaultSync() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/CodeEditorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("newPage.saveBody(noteContent)"))
        #expect(source.contains("newPage.needsVaultSync = true"))
        #expect(source.contains("BlockMirror.sync(pageId: newPage.id, body: noteContent, modelContext: context)"))
        #expect(source.contains("let failedPageId = newPage.id"))
        #expect(source.contains("context.delete(newPage)"))
        #expect(source.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))
        #expect(source.contains("AppBootstrap.shared?.graphState.needsRefresh = true"))
        #expect(!source.contains("try? context.save()"))
        #expect(!source.contains("newPage.body = noteContent"))
    }

    @Test("text capture note persistence cleans up transient bodies when save fails")
    func textCaptureNotePersistenceCleansUpTransientBodiesWhenSaveFails() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/TextCapturePipeline.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("let failedPageId = page.id"))
        #expect(source.contains("context.delete(page)"))
        #expect(source.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))
        #expect(source.contains("throw TextCaptureError.persistenceFailed"))
    }

    @Test("daily brief persistence invalidates graph structure after saving")
    func dailyBriefPersistenceInvalidatesGraphStructure() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/AppCoordinator.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("AppBootstrap.shared?.graphState.needsRefresh = true"))
        #expect(!source.contains("if let existing = try? context.fetch(folderDesc).first"))
        #expect(!source.contains("let alreadySaved = (try? context.fetch(dupDesc))?.isEmpty == false"))
        #expect(!source.contains("if let page = try? context.fetch(pageQuery).first"))
        #expect(source.contains("AppCoordinator: failed to fetch Daily Briefs folder"))
        #expect(source.contains("AppCoordinator: failed to check existing daily brief"))
    }

    @Test("diff restore and chat loading log fetch failures instead of silently no-oping")
    func diffRestoreAndChatLoadingLogFetchFailures() throws {
        let diffSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/DiffSheetView.swift",
            testsFilePath: #filePath
        )
        let coordinatorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/AppCoordinator.swift",
            testsFilePath: #filePath
        )
        let organizerSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/VaultOrganizerView.swift",
            testsFilePath: #filePath
        )

        #expect(!diffSource.contains("guard let page = try? modelContext.fetch(desc).first else { return }"))
        #expect(diffSource.contains("DiffSheetView: failed to fetch page for restore"))
        #expect(diffSource.contains("DiffSheetView: failed to fetch page for undo restore"))
        #expect(!coordinatorSource.contains("guard let sdChat = try? modelContainer.mainContext.fetch(descriptor).first else { return }"))
        #expect(coordinatorSource.contains("AppCoordinator: failed to fetch chat"))
        #expect(!organizerSource.contains("guard let page = try? modelContext.fetch(descriptor).first else { return }"))
        #expect(!organizerSource.contains("guard let page = try? modelContext.fetch(pageDescriptor).first,"))
        #expect(organizerSource.contains("VaultOrganizerView: failed to fetch page for tag suggestion"))
        #expect(organizerSource.contains("VaultOrganizerView: failed to fetch suggestion targets"))
    }

    @Test("graph entity fetch paths log failures instead of treating them as missing data")
    func graphEntityFetchPathsLogFailures() throws {
        let extractorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Graph/EntityExtractor.swift",
            testsFilePath: #filePath
        )
        let builderSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Graph/GraphBuilder.swift",
            testsFilePath: #filePath
        )

        #expect(!extractorSource.contains("return (try? context.fetch(descriptor))?.first"))
        #expect(!extractorSource.contains("if let existing = try? context.fetch(descriptor), !existing.isEmpty"))
        #expect(!extractorSource.contains("if let existing = (try? context.fetch(descriptor))?.first"))
        #expect(extractorSource.contains("EntityExtractor: failed to fetch graph node"))
        #expect(extractorSource.contains("EntityExtractor: failed to fetch existing graph node"))
        #expect(extractorSource.contains("EntityExtractor: failed to fetch existing graph edge"))
        #expect(!builderSource.contains("if let fetched = try? context.fetch(descriptor) {"))
        #expect(builderSource.contains("recordGraphBuilderFailure(\"Fetch referenced blocks batch\", error: error)"))
    }

    @Test("graph write surfaces roll back transient graph artifacts when persistence fails")
    func graphWriteSurfacesRollbackTransientArtifactsOnSaveFailure() throws {
        let textCaptureSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/TextCapturePipeline.swift",
            testsFilePath: #filePath
        )
        let extractorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Graph/EntityExtractor.swift",
            testsFilePath: #filePath
        )

        #expect(textCaptureSource.contains("var insertedNodes: [SDGraphNode] = []"))
        #expect(textCaptureSource.contains("var insertedEdges: [SDGraphEdge] = []"))
        #expect(textCaptureSource.contains("var updatedExistingNodes: [UpdatedExistingGraphNode] = []"))
        #expect(textCaptureSource.contains("context.delete(edge)"))
        #expect(textCaptureSource.contains("context.delete(node)"))
        #expect(textCaptureSource.contains("snapshot.node.label = snapshot.label"))
        #expect(textCaptureSource.contains("snapshot.node.updatedAt = snapshot.updatedAt"))

        #expect(extractorSource.contains("rollbackInsertedGraphArtifacts"))
        #expect(extractorSource.contains("var insertedEdges: [SDGraphEdge] = []"))
        #expect(extractorSource.contains("var insertedIdeaNodes: [SDGraphNode] = []"))
        #expect(extractorSource.contains("context.delete(edge)"))
        #expect(extractorSource.contains("context.delete(node)"))
    }

    @Test("graph builder persist restores mutated graph state when diff save fails")
    func graphBuilderPersistRestoresMutatedGraphStateWhenSaveFails() throws {
        let builderSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Graph/GraphBuilder.swift",
            testsFilePath: #filePath
        )

        #expect(builderSource.contains("struct NodeMutationSnapshot"))
        #expect(builderSource.contains("struct EdgeMutationSnapshot"))
        #expect(builderSource.contains("var updatedNodeSnapshots: [NodeMutationSnapshot] = []"))
        #expect(builderSource.contains("var deletedNodes: [SDGraphNode] = []"))
        #expect(builderSource.contains("var insertedEdges: [SDGraphEdge] = []"))
        #expect(builderSource.contains("snapshot.node.metadata = snapshot.metadata"))
        #expect(builderSource.contains("context.insert(node)"))
        #expect(builderSource.contains("context.insert(edge)"))
        #expect(builderSource.contains("context.delete(edge)"))
    }

    @Test("main-context version capture cleans up transient versions when save fails")
    func mainContextVersionCaptureCleansUpTransientVersionsWhenSaveFails() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Sync/VaultSyncService.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("let version = SDPageVersion("))
        #expect(source.contains("context.insert(version)"))
        #expect(source.contains("context.delete(version)"))
        #expect(source.contains("Failed to save captured version for page"))
    }

    @Test("live note and block mirror fetch paths log failures instead of mutating from empty fallbacks")
    func liveNoteAndBlockMirrorFetchPathsLogFailures() throws {
        let executorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/LiveNoteExecutor.swift",
            testsFilePath: #filePath
        )
        let scannerSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/LiveNoteScanner.swift",
            testsFilePath: #filePath
        )
        let mirrorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Sync/BlockMirror.swift",
            testsFilePath: #filePath
        )

        #expect(!executorSource.contains("return (try? context.fetch(descriptor))?.first"))
        #expect(executorSource.contains("LiveNoteExecutor: failed to fetch page"))
        #expect(!scannerSource.contains("let pages = (try? context.fetch(descriptor)) ?? []"))
        #expect(scannerSource.contains("LiveNoteScanner: failed to fetch active pages"))
        #expect(!mirrorSource.contains("let existing = (try? modelContext.fetch(descriptor)) ?? []"))
        #expect(mirrorSource.contains("BlockMirror: failed to fetch existing blocks"))
    }

    @Test("graph inspector and page mode fetch paths log failures instead of degrading into empty state")
    func graphInspectorAndPageModeFetchPathsLogFailures() throws {
        let inspectorStateSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Graph/NodeInspectorState.swift",
            testsFilePath: #filePath
        )
        let pinnedInspectorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Graph/PinnedInspector.swift",
            testsFilePath: #filePath
        )
        let graphStateSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Graph/GraphState.swift",
            testsFilePath: #filePath
        )
        let hologramInspectorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Graph/HologramNodeInspector.swift",
            testsFilePath: #filePath
        )

        #expect(!inspectorStateSource.contains("if let page = try? modelContext.fetch(descriptor).first, !page.summary.isEmpty"))
        #expect(!inspectorStateSource.contains("guard let folder = try? modelContext.fetch(descriptor).first else {"))
        #expect(!inspectorStateSource.contains("let allPages = (try? modelContext.fetch(pageDescriptor)) ?? []"))
        #expect(inspectorStateSource.contains(#""\(logPrefix): failed to fetch page summary"#))
        #expect(inspectorStateSource.contains("logPrefix: \"NodeInspectorState\""))
        #expect(inspectorStateSource.contains("NodeInspectorState: failed to fetch folder"))
        #expect(inspectorStateSource.contains("NodeInspectorState: failed to fetch folder pages"))

        #expect(!pinnedInspectorSource.contains("if let page = try? modelContext.fetch(descriptor).first, !page.summary.isEmpty"))
        #expect(!pinnedInspectorSource.contains("guard let folder = try? modelContext.fetch(descriptor).first else { return \"\" }"))
        #expect(!pinnedInspectorSource.contains("let allPages = (try? modelContext.fetch(pageDescriptor)) ?? []"))
        #expect(pinnedInspectorSource.contains(#""\(logPrefix): failed to fetch page summary"#))
        #expect(pinnedInspectorSource.contains("logPrefix: \"PinnedInspector\""))
        #expect(pinnedInspectorSource.contains("PinnedInspector: failed to fetch folder"))
        #expect(pinnedInspectorSource.contains("PinnedInspector: failed to fetch folder pages"))

        #expect(!graphStateSource.contains("guard let page = try? context.fetch(descriptor).first else { return }"))
        #expect(graphStateSource.contains("GraphState: failed to fetch page for page-mode subgraph"))
        #expect(!hologramInspectorSource.contains("guard let page = try? modelContext.fetch(desc).first,"))
        #expect(hologramInspectorSource.contains("HologramNodeInspector: failed to fetch page metadata"))
    }

    @Test("note surfaces and query helpers log fetch failures instead of pretending data is empty")
    func noteSurfacesAndQueryHelpersLogFetchFailures() throws {
        let backlinksSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/NoteBacklinksPanel.swift",
            testsFilePath: #filePath
        )
        let blockRefSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/BlockRefAutocomplete2.swift",
            testsFilePath: #filePath
        )
        let proseEditorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/ProseEditorRepresentable2.swift",
            testsFilePath: #filePath
        )
        let detailWorkspaceSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift",
            testsFilePath: #filePath
        )
        let diffSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/DiffSheetView.swift",
            testsFilePath: #filePath
        )
        let dataviewSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/DataviewService.swift",
            testsFilePath: #filePath
        )
        let knowledgeIndexSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/KnowledgeIndexBuilder.swift",
            testsFilePath: #filePath
        )
        let meaningAnchorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/MeaningAnchorService.swift",
            testsFilePath: #filePath
        )

        #expect(!backlinksSource.contains("guard let allPages = try? modelContext.fetch(descriptor) else { return }"))
        #expect(backlinksSource.contains("NoteBacklinksPopover: failed to fetch pages for backlink scan"))

        #expect(!blockRefSource.contains("let blocks = (try? modelContext.fetch(blockDescriptor)) ?? []"))
        #expect(!blockRefSource.contains("if let page = try? modelContext.fetch(desc).first {"))
        #expect(blockRefSource.contains("BlockRefAutocomplete2: failed to fetch candidate blocks"))
        #expect(blockRefSource.contains("BlockRefAutocomplete2: failed to fetch page title"))

        #expect(!proseEditorSource.contains("let existingBlocks = (try? mc.fetch(descriptor)) ?? []"))
        #expect(!proseEditorSource.contains("if let page = try? mc.fetch(pageDesc).first {"))
        #expect(!proseEditorSource.contains("let pageBlocks = (try? mc.fetch(pageBlocksDesc)) ?? [block]"))
        #expect(proseEditorSource.contains("ProseEditorRepresentable2: failed to fetch blocks for translator initialization"))
        #expect(proseEditorSource.contains("ProseEditorRepresentable2: failed to fetch source page for transclusion edit"))
        #expect(proseEditorSource.contains("ProseEditorRepresentable2: failed to fetch page blocks for transclusion edit"))

        #expect(!detailWorkspaceSource.contains("guard let allPages = try? modelContext.fetch(descriptor) else { return nil }"))
        #expect(!detailWorkspaceSource.contains("(try? modelContext.fetch(exactDesc))?.first"))
        #expect(!detailWorkspaceSource.contains("guard let pages = try? modelContext.fetch(allDesc) else { return nil }"))
        #expect(detailWorkspaceSource.contains("NoteDetailWorkspaceView: failed to fetch pages for missing-page recovery"))
        #expect(detailWorkspaceSource.contains("NoteDetailWorkspaceView: failed to fetch exact wikilink target"))
        #expect(detailWorkspaceSource.contains("NoteDetailWorkspaceView: failed to fetch wikilink target pages"))

        #expect(!diffSource.contains("versions = (try? modelContext.fetch(desc)) ?? []"))
        #expect(diffSource.contains("DiffSheetView: failed to fetch page versions"))

        #expect(!dataviewSource.contains("let pages = (try? context.fetch(descriptor)) ?? []"))
        #expect(dataviewSource.contains("DataviewService: failed to fetch pages"))

        #expect(!knowledgeIndexSource.contains("let nodes = (try? context.fetch(descriptor)) ?? []"))
        #expect(knowledgeIndexSource.contains("KnowledgeIndexBuilder: failed to fetch graph nodes"))

        #expect(!meaningAnchorSource.contains("guard let chat = try? context.fetch(descriptor).first else {"))
        #expect(!meaningAnchorSource.contains("guard let allChats = try? context.fetch(FetchDescriptor<SDChat>("))
        #expect(meaningAnchorSource.contains("MeaningAnchor: failed to fetch chat"))
        #expect(meaningAnchorSource.contains("MeaningAnchor: failed to fetch chats for backfill"))
    }

    @Test("app intents log fetch failures instead of quietly returning empty note and folder results")
    func appIntentsLogFetchFailures() throws {
        let noteEntitySource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Entities/NoteEntity.swift",
            testsFilePath: #filePath
        )
        let folderEntitySource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Entities/FolderEntity.swift",
            testsFilePath: #filePath
        )
        let noteActionsSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Custom/NoteActionIntents.swift",
            testsFilePath: #filePath
        )
        let analysisSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Custom/AnalysisIntents.swift",
            testsFilePath: #filePath
        )
        let dailyBriefSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Custom/DailyBriefingIntent.swift",
            testsFilePath: #filePath
        )
        let journalSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Schemas/JournalIntents.swift",
            testsFilePath: #filePath
        )

        #expect(!noteEntitySource.contains("let fallbackPages = (try? context.fetch(descriptor)) ?? []"))
        #expect(!noteEntitySource.contains("return (try? context.fetch(descriptor))?.first"))
        #expect(!noteEntitySource.contains("if let page = (try? context.fetch(descriptor))?.first"))
        #expect(!noteEntitySource.contains("let pages = (try? context.fetch(descriptor)) ?? []"))
        #expect(noteEntitySource.contains("AppIntentSearchSupport: failed to fetch fallback pages"))
        #expect(noteEntitySource.contains("AppIntentSearchSupport: failed to fetch page"))
        #expect(noteEntitySource.contains("NoteEntityQuery: failed to fetch note"))
        #expect(noteEntitySource.contains("NoteEntityQuery: failed to fetch suggested notes"))

        #expect(!folderEntitySource.contains("if let folder = (try? context.fetch(descriptor))?.first"))
        #expect(!folderEntitySource.contains("let folders = (try? context.fetch(descriptor)) ?? []"))
        #expect(folderEntitySource.contains("FolderEntityQuery: failed to fetch folder"))
        #expect(folderEntitySource.contains("FolderEntityQuery: failed to fetch folders"))

        #expect(!noteActionsSource.contains("guard let page = (try? context.fetch(descriptor))?.first else {"))
        #expect(!noteActionsSource.contains("guard let page = (try? context.fetch(pageDescriptor))?.first else {"))
        #expect(!noteActionsSource.contains("guard let folder = (try? context.fetch(folderDescriptor))?.first else {"))
        #expect(noteActionsSource.contains("SummarizeNoteIntent: failed to fetch active note"))
        #expect(noteActionsSource.contains("MoveNoteToFolderIntent: failed to fetch note"))
        #expect(noteActionsSource.contains("MoveNoteToFolderIntent: failed to fetch folder"))

        #expect(!analysisSource.contains("let recent = (try? context.fetch(SDPage.recentDescriptor(limit: 5))) ?? []"))
        #expect(analysisSource.contains("AskAboutNotesIntent: failed to fetch recent notes"))

        #expect(!dailyBriefSource.contains("let recentPages = (try? context.fetch(desc)) ?? []"))
        #expect(dailyBriefSource.contains("DailyBriefingIntent: failed to fetch recent pages"))

        #expect(!journalSource.contains("if let page = (try? context.fetch(descriptor))?.first"))
        #expect(journalSource.contains("JournalEntityQuery: failed to fetch journal entry"))
        #expect(journalSource.contains("CreateJournalIntent: failed to fetch created journal page"))
    }

    @Test("landing and remaining schema intents log fetch failures instead of degrading into empty UI")
    func landingAndSchemaFetchPathsLogFailures() throws {
        let aiPartnerSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/AIPartnerService.swift",
            testsFilePath: #filePath
        )
        let quitSavePanelSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Landing/QuitSavePanelController.swift",
            testsFilePath: #filePath
        )
        let wordProcessorSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Schemas/WordProcessorIntents.swift",
            testsFilePath: #filePath
        )
        let systemSearchSource = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Intents/Schemas/SystemSearchIntent.swift",
            testsFilePath: #filePath
        )

        #expect(!aiPartnerSource.contains("chat.linkedPageId = (try? ctx.fetch(descriptor).first)?.id"))
        #expect(aiPartnerSource.contains("AIPartnerService: failed to fetch linked page"))

        #expect(!quitSavePanelSource.contains("if let ws = try? AppBootstrap.shared?.modelContainer.mainContext.fetch("))
        #expect(!quitSavePanelSource.contains("AI Suggestion"))
        #expect(!quitSavePanelSource.contains("isLoadingAISuggestion"))
        #expect(quitSavePanelSource.contains("WorkspaceSynthesisBuilder.summary(for: snapshot)"))

        #expect(!wordProcessorSource.contains("if let page = (try? context.fetch(descriptor))?.first"))
        #expect(!wordProcessorSource.contains("let pages = (try? context.fetch(descriptor)) ?? []"))
        #expect(wordProcessorSource.contains("WordProcessorDocumentQuery: failed to fetch document"))
        #expect(wordProcessorSource.contains("WordProcessorDocumentQuery: failed to fetch documents"))

        #expect(!systemSearchSource.contains("let pages = (try? context.fetch(descriptor)) ?? []"))
        #expect(systemSearchSource.contains("SystemSearchIntent: failed to fetch search results"))
    }

    @Test("code editor inherits the note canvas and removes the old bottom chrome")
    func codeEditorInheritsNoteCanvasAndRemovesBottomChrome() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/CodeEditorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme)"))
        #expect(source.contains("MarkdownPreviewSurfaceStyle"))
        #expect(source.contains(".canvasNSColor(for: ui.theme)"))
        #expect(source.contains("useThemeBackground: true"))
        #expect(!source.contains("@State private var showAskBar"))
        #expect(!source.contains("@AppStorage(\"codeEditor.askBarResponseMode\")"))
        #expect(!source.contains("private var statusBar: some View"))
    }

    @Test("pipeline tool loop reports structured tool lifecycle events")
    func pipelineToolLoopReportsStructuredToolLifecycleEvents() throws {
        let pipeline = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/PipelineService.swift",
            testsFilePath: #filePath
        )
        let engineTypes = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Models/EngineTypes.swift",
            testsFilePath: #filePath
        )

        #expect(engineTypes.contains("enum PipelineToolEvent"))
        #expect(pipeline.contains("observedToolExecutor("))
        #expect(pipeline.contains("toolEventHandler?(.started("))
        #expect(pipeline.contains(".completed("))
    }

    @Test("Pipeline tool loop persists live AgentEvent tool provenance")
    func pipelineToolLoopPersistsLiveAgentEventToolProvenance() throws {
        let pipeline = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/PipelineService.swift",
            testsFilePath: #filePath
        )
        let recorder = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/AgentToolProvenanceRecorder.swift",
            testsFilePath: #filePath
        )

        #expect(recorder.contains("final class AgentToolProvenanceRecorder"))
        #expect(recorder.contains("saveAgentEvent(event)"))
        #expect(pipeline.contains("agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil"))
        #expect(pipeline.contains("let toolProvenanceRecorder = agentProvenanceRecorder ?? AgentToolProvenanceRecorder()"))
        #expect(pipeline.contains("runID: runID.uuidString"))
        #expect(pipeline.contains("kind: .toolCallRequested"))
        #expect(pipeline.contains("kind: .toolCallApproved"))
        #expect(pipeline.contains("kind: .toolCallDenied"))
        #expect(pipeline.contains("kind: result.isError ? .toolCallFailed : .toolCallCompleted"))
        #expect(!recorder.contains("MutationOpLog"))
        #expect(!recorder.contains("GraphEvent"))
        #expect(!recorder.contains("ReplayBundle"))
        #expect(!pipeline.contains("RustOpLogFFIClient"))
    }

    // "GGUF availability probe only runs for GGUF-capable model candidates" removed with
    // cloud-only/Omega removal 2026-07-03 — the GGUF runtime-kind probe (LocalModelCatalog /
    // resolvedRuntimeKind / probeRuntimeKind == .gguf) was deleted from AppBootstrap.

    @Test("outline navigator uses flattened native rows instead of recursive hover state")
    func outlineNavigatorUsesFlattenedNativeRows() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/OutlineNavigatorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("private struct FlattenedOutlineItem"))
        #expect(source.contains("@State private var flattenedItems: [FlattenedOutlineItem] = []"))
        #expect(source.contains("refreshFlattenedItems()"))
        #expect(source.contains("NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme)"))
        #expect(source.contains("ScrollView(.vertical)"))
        #expect(source.contains("LazyVStack(spacing: 0)"))
        #expect(!source.contains("@State private var hoveredItem"))
        #expect(!source.contains("struct OutlineItemRow"))
        #expect(!source.contains(".listStyle(.sidebar)"))
    }

    @Test("outline navigator preserves manual expansion state across refreshes")
    func outlineNavigatorPreservesManualExpansionStateAcrossRefreshes() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/OutlineNavigatorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("expandedItems.intersection(nextExpandableItems)"))
        #expect(source.contains("if preservedExpandedItems.isEmpty"))
    }

    @Test("model involvement sheet accepts both current and legacy model id aliases")
    func modelInvolvementSheetAcceptsCurrentAndLegacyModelIDAliases() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/ModelInvolvementSheet.swift",
            testsFilePath: #filePath
        )
        #expect(source.contains("acceptedModelIDs"))
        #expect(source.contains("loadContributions("))
        #expect(!source.contains("#Predicate<SDMessage> { $0.authoredByModelID == modelID }"))
    }

}
