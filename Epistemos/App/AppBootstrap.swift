import AppIntents
import AppKit
import Foundation
import Metal
import os
import QuartzCore
import SQLite3
import SwiftData
enum PersistenceMode: Equatable, Sendable {
    case durable(url: URL)
    case testInMemory
    case inMemoryRecovery(reason: String)

    var isDurable: Bool {
        if case .durable = self { return true }
        return false
    }
}

// MARK: - App Bootstrap
// Creates state objects, services, and the dependency graph.

struct StartupIntegrityReport: Sendable {
    let sampledPageIds: [String]
    let corruptedPageIds: [String]
    let unrecoverablePageIds: [String]
    let eventStoreAvailable: Bool
    let vaultBookmarkExists: Bool
    let vaultBookmarkReadyForAutomaticRestore: Bool
    let vaultBookmarkFailureReason: String?
    let vaultBookmarkBlocksAutomaticRestore: Bool

    var shouldBlockAutomaticVaultRestore: Bool {
        vaultBookmarkBlocksAutomaticRestore
            || (!vaultBookmarkExists && !corruptedPageIds.isEmpty)
    }

    var vaultBookmarkValidation: VaultBookmarkStartupValidation {
        VaultBookmarkStartupValidation(
            bookmarkExists: vaultBookmarkExists,
            isReadyForAutomaticRestore: vaultBookmarkReadyForAutomaticRestore,
            failureReason: vaultBookmarkFailureReason
        )
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
    #if !EPISTEMOS_FREE_V1
    private nonisolated static var agentCoreManagedOAuthEnvironmentVars: Set<String> {
        var vars: Set<String> = [
            "ANTHROPIC_ACCESS_TOKEN",
            "ANTHROPIC_AUTH_MODE",
            "GOOGLE_ACCESS_TOKEN",
            "GOOGLE_AUTH_MODE",
            "GOOGLE_PROJECT_ID",
        ]
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        vars.formUnion([
            "OPENAI_ACCESS_TOKEN",
            "OPENAI_AUTH_MODE",
            "OPENAI_CLIENT_VERSION",
        ])
        #endif
        return vars
    }
    private nonisolated static let agentCoreEnvironmentKeyMappings: [(envVar: String, keychainKey: String)] = {
        var mappings = [
            (envVar: "ANTHROPIC_API_KEY", keychainKey: "epistemos.anthropic.apiKey"),
            (envVar: "OPENAI_API_KEY", keychainKey: "epistemos.openai.apiKey"),
        ]
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        mappings.append(contentsOf: [
            (envVar: "GOOGLE_API_KEY", keychainKey: "epistemos.google.apiKey"),
            (envVar: "PERPLEXITY_API_KEY", keychainKey: "epistemos.perplexity.apiKey"),
            (envVar: "OPENROUTER_API_KEY", keychainKey: "epistemos.openrouter.apiKey"),
            (envVar: "GLM_API_KEY", keychainKey: "epistemos.zai.apiKey"),
            (envVar: "ZHIPU_API_KEY", keychainKey: "epistemos.zai.apiKey"),
            (envVar: "ZAI_API_KEY", keychainKey: "epistemos.zai.apiKey"),
            (envVar: "KIMI_API_KEY", keychainKey: "epistemos.kimi.apiKey"),
            (envVar: "MOONSHOT_API_KEY", keychainKey: "epistemos.kimi.apiKey"),
            (envVar: "DEEPSEEK_API_KEY", keychainKey: "epistemos.deepseek.apiKey"),
            (envVar: "MINIMAX_API_KEY", keychainKey: "epistemos.minimax.apiKey"),
            (envVar: "XAI_API_KEY", keychainKey: "epistemos.xai.apiKey"),
            (envVar: "MISTRAL_API_KEY", keychainKey: "epistemos.mistral.apiKey"),
            (envVar: "GROQ_API_KEY", keychainKey: "epistemos.groq.apiKey"),
            (envVar: "HF_TOKEN", keychainKey: "epistemos.huggingface.apiKey"),
            (envVar: "HUGGINGFACE_API_KEY", keychainKey: "epistemos.huggingface.apiKey"),
        ])
        #endif
        return mappings
    }()

    private nonisolated static let agentCoreEnvironmentScopeGate = AgentCoreEnvironmentScopeGate()

    private nonisolated static var agentCoreManagedEnvironmentVars: Set<String> {
        Set(agentCoreEnvironmentKeyMappings.map(\.envVar))
            .union(agentCoreManagedOAuthEnvironmentVars)
    }

    /// Clears Epistemos-managed provider env vars from the parent process. Stored
    /// credentials are scoped only around the Rust agent runtime call.
    nonisolated static func populateAgentCoreEnvironment(
        keychainLoad _: @Sendable (String) -> String? = { Keychain.load(for: $0) }
    ) {
        clearAgentCoreEnvironment()
    }

    nonisolated static func clearAgentCoreEnvironment() {
        for envVar in agentCoreManagedEnvironmentVars {
            unsetenv(envVar)
        }
    }

    nonisolated static func withScopedAgentCoreEnvironment<T>(
        keychainLoad: @Sendable (String) -> String? = { Keychain.load(for: $0) },
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let overrides = agentCoreEnvironmentOverrides(keychainLoad: keychainLoad)
        let managedVars = agentCoreManagedEnvironmentVars

        await agentCoreEnvironmentScopeGate.acquire()

        let previous = snapshotEnvironmentVars(managedVars)
        applyAgentCoreEnvironmentOverrides(overrides, managedVars: managedVars)

        do {
            let result = try await operation()
            restoreEnvironmentVars(previous)
            await agentCoreEnvironmentScopeGate.release()
            return result
        } catch {
            restoreEnvironmentVars(previous)
            await agentCoreEnvironmentScopeGate.release()
            throw error
        }
    }

    private nonisolated static func snapshotEnvironmentVars(_ vars: Set<String>) -> [String: String?] {
        vars.reduce(into: [String: String?]()) { result, envVar in
            if let rawValue = getenv(envVar) {
                result.updateValue(String(cString: rawValue), forKey: envVar)
            } else {
                result.updateValue(nil, forKey: envVar)
            }
        }
    }

    private nonisolated static func applyAgentCoreEnvironmentOverrides(
        _ overrides: [String: String],
        managedVars: Set<String>
    ) {
        for envVar in managedVars {
            if let value = overrides[envVar], !value.isEmpty {
                setenv(envVar, value, 1)
            } else {
                unsetenv(envVar)
            }
        }
    }

    private nonisolated static func restoreEnvironmentVars(_ snapshot: [String: String?]) {
        for (envVar, value) in snapshot {
            if let value {
                setenv(envVar, value, 1)
            } else {
                unsetenv(envVar)
            }
        }
    }

    nonisolated static func agentCoreEnvironmentOverrides(
        keychainLoad: @Sendable (String) -> String? = { Keychain.load(for: $0) }
    ) -> [String: String] {
        var overrides: [String: String] = [:]
        for mapping in agentCoreEnvironmentKeyMappings {
            if let value = normalizedAgentCoreEnvironmentValue(keychainLoad(mapping.keychainKey)) {
                overrides[mapping.envVar] = value
            }
        }

        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        if let credential = storedOAuthCredential(
            for: .openAI,
            authMode: .openAICodex,
            keychainLoad: keychainLoad
        ) {
            overrides["OPENAI_ACCESS_TOKEN"] = credential.accessToken
            overrides["OPENAI_AUTH_MODE"] = "codex"
            overrides["OPENAI_CLIENT_VERSION"] = OpenAICodexRuntimeMetadata.clientVersion
        }

        if let credential = storedOAuthCredential(
            for: .anthropic,
            authMode: .anthropicClaudeCode,
            keychainLoad: keychainLoad
        ) {
            overrides["ANTHROPIC_ACCESS_TOKEN"] = credential.accessToken
            overrides["ANTHROPIC_AUTH_MODE"] = "oauth"
        }

        if let credential = storedOAuthCredential(
            for: .google,
            authMode: .googleGemini,
            keychainLoad: keychainLoad
        ),
           let projectID = normalizedAgentCoreEnvironmentValue(credential.projectID) {
            overrides["GOOGLE_ACCESS_TOKEN"] = credential.accessToken
            overrides["GOOGLE_AUTH_MODE"] = "oauth"
            overrides["GOOGLE_PROJECT_ID"] = projectID
        }
        #endif

        return overrides
    }

    nonisolated static func agentCoreKeychainKey(forEnvironmentKey envVar: String) -> String? {
        agentCoreEnvironmentKeyMappings.first { $0.envVar == envVar }?.keychainKey
    }

    private nonisolated static func storedOAuthCredential(
        for provider: CloudModelProvider,
        authMode: CloudProviderOAuthMode,
        keychainLoad: @Sendable (String) -> String?
    ) -> CloudProviderOAuthCredential? {
        guard let rawCredential = normalizedAgentCoreEnvironmentValue(
            keychainLoad(provider.oauthKeychainKey)
        ),
        let credential = CloudProviderOAuthCredential.decode(from: rawCredential),
        credential.authMode == authMode,
        normalizedAgentCoreEnvironmentValue(credential.accessToken) != nil else {
            return nil
        }
        return credential
    }

    private nonisolated static func normalizedAgentCoreEnvironmentValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
    #endif

    #if DEBUG
    private nonisolated static let isDebugBuild = true
    #else
    private nonisolated static let isDebugBuild = false
    #endif


    nonisolated static func shouldScheduleMetalShaderWarmupAtLaunch(
        isRunningTests: Bool = AppBootstrap.isRunningTests,
        isDebugBuild: Bool = AppBootstrap.isDebugBuild,
        fileManager: FileManager = .default,
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard !isRunningTests, !isDebugBuild else { return false }
        switch FoundationSafety.auditRuntimeIsolationRequestState(
            fileManager: fileManager,
            processInfoEnvironment: processInfoEnvironment
        ) {
        case .notRequested:
            return true
        case .active:
            return false
        case .requestedButInvalid:
            preconditionFailure("Runtime-audit Metal warmup isolation is incomplete or invalid")
        }
    }

    private static func requireInitialized<Value>(_ value: Value?, name: StaticString) -> Value {
        guard let value else {
            preconditionFailure("AppBootstrap.\(name.description) accessed before initialization")
        }
        return value
    }

    private nonisolated static func makeFallbackSearchIndexService() -> SearchIndexService? {
        do {
            return try SearchIndexService()
        } catch {
            Log.app.error(
                "AppBootstrap: failed to create fallback search index service: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    // MARK: - Model Container
    let modelContainer: ModelContainer
    let persistenceMode: PersistenceMode
    /// Non-nil when the on-disk database failed to load and the app is in
    /// recovery-only in-memory mode. RootView blocks normal workspace editing.
    var databaseError: Error?

    // MARK: - State
    let eventBus = EventBus()
    let pipelineState = PipelineState()
    let uiState = UIState()
    let notesUI = NotesUIState()
    #if !EPISTEMOS_FREE_V1
    let runtimeState: ProductRuntimeState
    #endif
    let threadState = ThreadState()
    let graphState = GraphState()
    let queryEngine = QueryEngine()
    let physicsCoordinator = PhysicsCoordinator()
    /// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — Contextual Shadows V0
    /// state container (recall hits + panel visibility). Hidden behind
    /// `EPISTEMOS_AMBIENT_RECALL_V0` env flag; UI hides itself when
    /// `state.isEnabled == false`.
    let contextualShadowsState = ContextualShadowsState()
    let ambientFrequencyPlaybackState = AmbientFrequencyPlaybackState()
    let sovereignGate = SovereignGate()
    private let sovereignGateLifecycleObserver = SovereignGateLifecycleObserver()
    var isSovereignGateLifecycleObserverStarted: Bool {
        sovereignGateLifecycleObserver.isStarted
    }
    private var commandCenterLocalHotkeyMonitor: Any?
    private var commandCenterGlobalHotkeyMonitor: Any?
    // Computer-use (screen capture / AX automation / device agent) removed — cloud-only build.
    let instantRecallService = InstantRecallService()
    private var _textCapturePipeline: TextCapturePipeline?
    var textCapturePipeline: TextCapturePipeline { Self.requireInitialized(_textCapturePipeline, name: "textCapturePipeline") }
    private var _mutationOpLogProjectionWorker: MutationOpLogProjectionWorker?
    var mutationOpLogProjectionWorker: MutationOpLogProjectionWorker? { _mutationOpLogProjectionWorker }
    private var _workspaceService: WorkspaceService?
    var workspaceService: WorkspaceService { Self.requireInitialized(_workspaceService, name: "workspaceService") }
    let activityTracker = ActivityTracker()
    #if !EPISTEMOS_FREE_V1
    private var _workspaceSummaryService: WorkspaceSummaryService?
    var workspaceSummaryService: WorkspaceSummaryService { Self.requireInitialized(_workspaceSummaryService, name: "workspaceSummaryService") }
    #endif
    private var _timeMachineService: TimeMachineService?
    var timeMachineService: TimeMachineService { Self.requireInitialized(_timeMachineService, name: "timeMachineService") }

    // MARK: - Infrastructure
    let supervisor = AppSupervisor()

    // MARK: - Cognitive Substrates
    let epistemosConfig = EpistemosConfig()
    private var _frictionMonitor: FrictionMonitorService?
    var frictionMonitor: FrictionMonitorService { Self.requireInitialized(_frictionMonitor, name: "frictionMonitor") }

    // MARK: - Ambient Vault Manifest
    /// Always-available vault manifest — built eagerly on vault attach, refreshed on changes.
    /// Nil when no vault is attached. Shared across agent, editor, and graph surfaces.
    var ambientManifest: VaultManifest?

    // MARK: - Active Query Task
    var queryTask: Task<Void, Never>?
    private var healthyVaultBodyCleanupTask: Task<Void, Never>?

    #if !EPISTEMOS_FREE_V1
    private var preparedRetrievalRefreshTask: Task<Void, Never>?
    private var didStartDeferredRuntimeServices = false
    #endif
    private var startupIntegrityReport: StartupIntegrityReport?
    private var didStartPrimaryLaunchInitialization = false
    private var didCompletePrimaryLaunchInitialization = false

    private nonisolated static let primaryLaunchInitializationWaitTimeout: Duration = .seconds(6)
    private nonisolated static let primaryLaunchInitializationPollInterval: Duration = .milliseconds(50)
    private nonisolated static let deferredRuntimeServicesDelay: Duration = .milliseconds(250)

    private struct InstantRecallSeed: Sendable {
        let id: String
        let filePath: String?
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

    private func removeItemIfPresent(
        at url: URL,
        fileManager: FileManager,
        failureMessage: String
    ) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            recordPersistenceIssue("\(failureMessage) (\(url.lastPathComponent))", error: error)
        }
    }

    private nonisolated static let legacyMessageColumns: [(name: String, declaration: String)] = [
        ("ZTHINKINGTRACE", "TEXT"),
        ("ZTHINKINGDURATIONSECONDS", "DOUBLE"),
        // Pass 8 — per-model authorship memory. Optional strings, no
        // default needed; SwiftData lightweight migration handles new
        // stores automatically but legacy SQLite stores adopted via
        // `preparePersistentModelStoreIfNeeded` still need the columns
        // explicitly added.
        ("ZAUTHOREDBYPROVIDERID", "TEXT"),
        ("ZAUTHOREDBYMODELID", "TEXT"),
    ]

    private nonisolated static let legacyPageColumns: [(name: String, declaration: String)] = [
        ("ZWIKILINKREFERENCES", "BLOB"),
        ("ZWIKILINKREFERENCESCANSIGNATURE", "VARCHAR"),
    ]

    nonisolated static func legacyRootModelStoreURL(
        applicationSupportDirectory: URL
    ) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("default.store", isDirectory: false)
            .standardizedFileURL
    }

    nonisolated static func persistentModelStoreURL(
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let directory = applicationSupportDirectory
            .appendingPathComponent("Epistemos", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent("default.store", isDirectory: false)
            .standardizedFileURL
    }

    nonisolated static func preparePersistentModelStoreIfNeeded(
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destinationURL = persistentModelStoreURL(
            applicationSupportDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        let legacyURL = legacyRootModelStoreURL(applicationSupportDirectory: applicationSupportDirectory)

        // Two scenarios diverge here:
        //
        // (a) **Dual stores** — legacy AND destination both exist
        // independently. Both need column-repair in place so that
        // any tool that still reads the legacy path sees the same
        // schema. The `bootstrapRepairsLegacyRootAndAppScopedStores
        // WhenBothExist` test pins this contract.
        //
        // (b) **Adoption** — only legacy exists. We copy it to the
        // destination, then repair the destination. Repairing legacy
        // ALSO in this branch would place the `default.store.pre-
        // column-repair.backup` at the legacy parent (the user's
        // Application Support root) rather than next to the
        // destination — recovery tooling would then be pointed at the
        // wrong path. The `bootstrapAdoptsLegacyRootStoresIntoTheApp
        // ScopedPathAndRepairsMessageColumns` test pins backup
        // placement at the destination parent.
        //
        // Branch the logic so the dual-store case still repairs legacy
        // but the adoption case lets the destination repair create the
        // single, co-located backup.
        let legacyExists = fileManager.fileExists(atPath: legacyURL.path)
        let destinationExists = fileManager.fileExists(atPath: destinationURL.path)

        if legacyExists && destinationExists {
            try repairLegacyStoreColumnsIfNeeded(at: legacyURL)
        }

        if !destinationExists, legacyExists {
            try VaultSyncService.backupSQLiteDatabaseIfPresent(at: legacyURL, to: destinationURL)
        }

        try repairLegacyStoreColumnsIfNeeded(at: destinationURL)
        try verifyRequiredLegacyStoreColumns(at: destinationURL)
        return destinationURL
    }

    private nonisolated static func repairLegacyStoreColumnsIfNeeded(
        at storeURL: URL
    ) throws {
        try repairLegacyMessageColumnsIfNeeded(at: storeURL)
        try repairLegacyPageColumnsIfNeeded(at: storeURL)
    }

    private nonisolated static func repairLegacyMessageColumnsIfNeeded(
        at storeURL: URL
    ) throws {
        try repairLegacyColumnsIfNeeded(
            at: storeURL,
            tableName: "ZSDMESSAGE",
            columns: legacyMessageColumns,
            alterDomain: "Message"
        )
    }

    private nonisolated static func repairLegacyPageColumnsIfNeeded(
        at storeURL: URL
    ) throws {
        try repairLegacyColumnsIfNeeded(
            at: storeURL,
            tableName: "ZSDPAGE",
            columns: legacyPageColumns,
            alterDomain: "Page"
        )
    }

    private nonisolated static func repairLegacyColumnsIfNeeded(
        at storeURL: URL,
        tableName: String,
        columns: [(name: String, declaration: String)],
        alterDomain: String
    ) throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(
            storeURL.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let db else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.Open",
                code: -1,
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 1_000)

        let columnNames = try sqliteColumnNames(in: tableName, db: db, storeURL: storeURL)
        guard !columnNames.isEmpty else { return }
        let missingColumns = columns.filter { !columnNames.contains($0.name) }
        guard !missingColumns.isEmpty else { return }

        try backupModelStoreBeforeLegacyColumnRepairIfNeeded(at: storeURL)

        for column in missingColumns {
            let sql = "ALTER TABLE \(tableName) ADD COLUMN \(column.name) \(column.declaration);"
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw sqliteStoreError(
                    domain: "AppBootstrap.ModelStore.Alter\(alterDomain)",
                    code: Int(sqlite3_errcode(db)),
                    storeURL: storeURL,
                    db: db
                )
            }
        }
    }

    private nonisolated static func verifyRequiredLegacyStoreColumns(
        at storeURL: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(
            storeURL.path,
            &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let db else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.VerifyOpen",
                code: -1,
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_close(db) }

        try verifyRequiredColumns(
            in: "ZSDMESSAGE",
            requiredColumns: legacyMessageColumns.map(\.name),
            db: db,
            storeURL: storeURL
        )
        try verifyRequiredColumns(
            in: "ZSDPAGE",
            requiredColumns: legacyPageColumns.map(\.name),
            db: db,
            storeURL: storeURL
        )
    }

    private nonisolated static func verifyRequiredColumns(
        in tableName: String,
        requiredColumns: [String],
        db: OpaquePointer,
        storeURL: URL
    ) throws {
        let columnNames = try sqliteColumnNames(in: tableName, db: db, storeURL: storeURL)
        guard !columnNames.isEmpty else { return }

        let missingColumns = requiredColumns.filter { !columnNames.contains($0) }
        guard missingColumns.isEmpty else {
            throw NSError(
                domain: "AppBootstrap.ModelStore.VerifyColumns",
                code: 1,
                userInfo: [
                    NSFilePathErrorKey: storeURL.path,
                    NSLocalizedDescriptionKey:
                        "\(tableName) missing required columns: \(missingColumns.joined(separator: ", "))",
                ]
            )
        }
    }

    private nonisolated static func backupModelStoreBeforeLegacyColumnRepairIfNeeded(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let backupURL = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("default.store.pre-column-repair.backup", isDirectory: false)
        if fileManager.fileExists(atPath: backupURL.path) {
            guard !legacyColumnRepairBackupIsUsable(at: backupURL) else { return }
            try fileManager.removeItem(at: backupURL)
        }
        try VaultSyncService.backupSQLiteDatabaseIfPresent(at: storeURL, to: backupURL)
    }

    private nonisolated static func legacyColumnRepairBackupIsUsable(at backupURL: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            backupURL.path,
            &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let db else {
            return false
        }
        defer { sqlite3_close(db) }

        guard let tableCount = try? sqliteUserTableCount(db: db, storeURL: backupURL) else {
            return false
        }
        return tableCount > 0
    }

    private nonisolated static func sqliteUserTableCount(
        db: OpaquePointer,
        storeURL: URL
    ) throws -> Int {
        var statement: OpaquePointer?
        let query = "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.TableCount",
                code: Int(sqlite3_errcode(db)),
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.TableCountStep",
                code: Int(sqlite3_errcode(db)),
                storeURL: storeURL,
                db: db
            )
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private nonisolated static func sqliteColumnNames(
        in tableName: String,
        db: OpaquePointer,
        storeURL: URL
    ) throws -> Set<String> {
        var statement: OpaquePointer?
        let query = "PRAGMA table_info(\(tableName));"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.TableInfo",
                code: Int(sqlite3_errcode(db)),
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_finalize(statement) }

        var columnNames = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let rawName = sqlite3_column_text(statement, 1) else { continue }
            columnNames.insert(String(cString: rawName))
        }
        return columnNames
    }

    private nonisolated static func sqliteStoreError(
        domain: String,
        code: Int,
        storeURL: URL,
        db: OpaquePointer?
    ) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite store error"
        return NSError(
            domain: domain,
            code: code,
            userInfo: [
                NSFilePathErrorKey: storeURL.path,
                NSLocalizedDescriptionKey: "\(message) (\(storeURL.lastPathComponent))",
            ]
        )
    }

    private nonisolated static func modelStoreArtifactURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm", isDirectory: false),
            URL(fileURLWithPath: storeURL.path + "-wal", isDirectory: false),
        ]
    }

    private nonisolated static func removeModelStoreArtifacts(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws {
        for url in modelStoreArtifactURLs(for: storeURL) where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Services
    #if !EPISTEMOS_FREE_V1
    private var _llmService: LLMService?
    var llmService: LLMService { Self.requireInitialized(_llmService, name: "llmService") }
    let localRuntimeControlPlane: BackendRuntimeControlPlane
    private var _cloudLLMClient: CloudLLMClient?
    var cloudLLMClient: CloudLLMClient { Self.requireInitialized(_cloudLLMClient, name: "cloudLLMClient") }
    private var _triageService: TriageService?
    var triageService: TriageService { Self.requireInitialized(_triageService, name: "triageService") }
    #endif
    #if !EPISTEMOS_FREE_V1
    let preparedModelRegistryState: PreparedModelRegistryState
    let preparedModelRegistry: PreparedModelRegistry
    #endif
    let vaultSync: VaultSyncService
#if !EPISTEMOS_FREE_V1
    let vaultChatMutator: VaultChatMutator
    let liveNoteScheduler = LiveNoteSchedulerService()
#endif
    init() {
        let interval = Log.appPerf.beginInterval("bootstrapInit")
        defer { Log.appPerf.endInterval("bootstrapInit", interval) }

        // USER REPORT 2026-05-12 (ISSUE-12-011 diagnostics): per-step
        // wall-clock logging so the runtime trace shows exactly which
        // bootstrap sub-step is responsible for the startup hang. The
        // overhead is one Date() per step (microseconds) — strictly
        // diagnostic, can be removed once ISSUE-12-011 is fully closed.
        let bootstrapStart = Date()
        func logStep(_ name: String, since: Date) -> Date {
            let now = Date()
            let elapsedMs = now.timeIntervalSince(since) * 1000.0
            if elapsedMs > 50 {
                Log.app.info("bootstrap step '\(name, privacy: .public)' took \(elapsedMs, format: .fixed(precision: 1)) ms")
            }
            return now
        }
        var stepClock = bootstrapStart

        // Cut the default `URLCache.shared` (4 MB memory + 20 MB disk).
        // Almost every URLSession in this app explicitly opts out of
        // caching (LLM streams, HF downloads, MCP) or uses ephemeral
        // configurations. The shared cache table is dead weight that
        // counts toward resident memory at idle.
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)
        stepClock = logStep("urlCache_disable", since: stepClock)

        // Register custom fonts (display, pixel, mono, etc.)
        EpistemosFont.registerFonts()
        stepClock = logStep("registerFonts", since: stepClock)

        // Create the SwiftData container against an explicit app-scoped store path.
        // Legacy root-level default.store files are adopted once into the app
        // directory, and known message-column gaps are repaired before opening.
        // Falls back to in-memory only under tests or if container creation fails.
        let schema = Schema(EpistemosSchema.models)
        stepClock = logStep("schemaLoad", since: stepClock)
        let container: ModelContainer
        let dbError: Error?
        let resolvedPersistenceMode: PersistenceMode
        let fileManager = FileManager.default
        let applicationSupportDirectory = FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
        Self.prepareSharedSubstrateContainer(AppGroupContainer.shared)
        let usesInMemoryModelStore = Self.isRunningTests
        let modelStoreURL = Self.persistentModelStoreURL(
            applicationSupportDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        let modelConfiguration: ModelConfiguration
        if usesInMemoryModelStore {
            modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            do {
                _ = try Self.preparePersistentModelStoreIfNeeded(
                    applicationSupportDirectory: applicationSupportDirectory,
                    fileManager: fileManager
                )
            } catch {
                Log.persistence.error(
                    "Persistent model store preparation failed: \(error.localizedDescription, privacy: .public)"
                )
                RuntimeDiagnostics.record(
                    .error,
                    category: "Persistence",
                    message: "Persistent model store preparation failed",
                    metadata: [
                        "error": error.localizedDescription,
                        "storePath": modelStoreURL.path,
                    ]
                )
            }
            modelConfiguration = ModelConfiguration(url: modelStoreURL)
        }
        stepClock = logStep("modelStorePrepare", since: stepClock)
        do {
            container = try ModelContainer(
                for: schema,
                configurations: modelConfiguration
            )
            stepClock = logStep("modelContainerInit", since: stepClock)
            dbError = nil
            resolvedPersistenceMode = usesInMemoryModelStore
                ? .testInMemory
                : .durable(url: modelStoreURL)
        } catch {
            Log.persistence.error(
                "Database failed to load; entering recovery-only in-memory mode: \(error.localizedDescription, privacy: .public)"
            )
            RuntimeDiagnostics.record(
                .fault,
                category: "Persistence",
                message: "Database failed to load; entering recovery-only in-memory mode",
                metadata: ["error": error.localizedDescription]
            )
            container = Self.makeFallbackModelContainer(schema: schema)
            dbError = error
            resolvedPersistenceMode = .inMemoryRecovery(reason: error.localizedDescription)
        }
        self.modelContainer = container
        self.persistenceMode = resolvedPersistenceMode
        self.databaseError = dbError

        #if !EPISTEMOS_FREE_V1
        // Product runtime state owns edition-appropriate model availability.
        let inference = ProductRuntimeState()
        self.runtimeState = inference
        let embeddingService = graphState.embeddingService
        let localRuntimeControlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [],
                primaryGenerationRuntimeKind: .remote,
                allowMLXGenerationFallback: false
            ),
            embeddingResolver: { request in
                embeddingService.queryEmbedding(
                    for: request.text,
                    expectedDimension: request.expectedDimension
                )
            }
        )
        self.localRuntimeControlPlane = localRuntimeControlPlane
        #endif

        #if !EPISTEMOS_FREE_V1
        let preparedModelRegistryState = PreparedModelRegistryState()
        self.preparedModelRegistryState = preparedModelRegistryState

        let preparedModelRegistry = PreparedModelRegistry()
        self.preparedModelRegistry = preparedModelRegistry

        // Defer the prepared-model manifest load off the synchronous init path.
        // Reading the manifest + parsing it previously blocked the first
        // foreground tap on launch (the "app feels frozen when I click on it"
        // symptom). The state starts empty; downstream clients are wired with
        // `nil` generation-runtime configuration and will fall back to
        // baseline defaults. `refreshPreparedRetrievalRuntimeConfigurationIfNeeded`
        // is scheduled from `didStartPrimaryLaunchInitialization` / activation
        // notifications and will apply the real snapshot once loaded.
        graphState.applyPreparedRetrievalRuntimeConfiguration(nil)
        #endif

        // Start centralized power authority — must be before any subsystem that
        // checks PowerGuard.shared.currentMode during init.
        PowerGuard.shared.start()

        // Start main thread watchdog to detect UI hangs (skipped in eco/lowPower).
        if !Self.isRunningTests && !PowerGuard.shared.shouldDisableBackground {
            MainThreadWatchdog.install()
        }

        // Start centralized thermal authority before any inference work.
        Task { await ThermalGuard.shared.start() }

        // Persist FSRS spaced-repetition enrollments across launches (opt-in feature; the store is
        // in-memory until this points it at its dedicated Application Support database).
        Task { await FSRSDecayStore.shared.configureDefaultPersistence() }

        supervisor.start()

        // VaultSyncService — hybrid persistence bridge
        self.vaultSync = VaultSyncService(modelContainer: container)

        #if !EPISTEMOS_FREE_V1
        let cloudLLMClient = CloudLLMClient(inference: inference)
        self._cloudLLMClient = cloudLLMClient

        let llm = LLMService(
            inference: inference,
            cloudLLMClient: cloudLLMClient
        )
        self._llmService = llm

        let triage = TriageService(
            inference: inference,
            cloudLLMService: cloudLLMClient,
            prepareForRouting: {}
        )
        self._triageService = triage

        self.vaultChatMutator = VaultChatMutator(
            vaultResolver: { _ in
                guard let root = await AppBootstrap.shared?.vaultSync.vaultURL else {
                    throw VaultChatMutatorError.vaultUnavailable
                }
                return root
            },
            autoCommitInAgentMode: false
        )

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llm,
            triageService: triage,
            inference: inference,
            eventBus: eventBus,
            vaultPathProvider: { [weak vaultSync] in
                vaultSync?.vaultURL?.path
            },
            skillNamesProvider: {
                SkillDiscoveryCatalog.discoverSkillEntries().map(\.title).sorted()
            }
        )

        #endif

        AppBootstrap.shared = self

        // NOTE-4 (audit 2026-07-03): recover any note crash-drafts left by an unclean
        // shutdown, before editors load. Enumerates draft files off-main, but routes every
        // recovery write through the canonical vault writer so `.md` remains source of truth.
        Task.detached(priority: .userInitiated) {
            await NoteDraftStore.reconcileOrphanedDrafts { pageId, body, draftDate in
                await AppBootstrap.shared?.vaultSync.recoverDraftIfNewer(
                    pageId: pageId,
                    body: body,
                    draftModificationDate: draftDate
                ) == true
            }
        }
        if !Self.isRunningTests {
            VaultCrashRecorder.install(vaultURL: vaultSync.vaultURL)
        }
        sovereignGateLifecycleObserver.start(gate: sovereignGate)

        // ISSUE-2026-05-12-008: amortize BlockMirror first-parse for the 5
        // most-recently-modified pages so the first-open hang (~10-200ms per
        // note) moves from click-time to launch-time. Uses the canonical
        // R.3 fallback chain so disk-only pages (production majority) are
        // covered alongside inline-body pages.
        Task.detached(priority: .userInitiated) {
            await AppBootstrap.prewarmRecentBlockMirrors(
                modelContainer: container,
                limit: 5
            )
        }

        self._workspaceService = WorkspaceService(modelContainer: container)
        #if !EPISTEMOS_FREE_V1
        self._workspaceSummaryService = WorkspaceSummaryService(
            triageService: triage, activityTracker: activityTracker, modelContainer: container
        )
        // Initialize the persistent event store (separate SQLite database with WAL mode).
        EventStore.shared = EventStore()
        #endif
        self._timeMachineService = TimeMachineService(modelContainer: container)
        self.workspaceService.timeMachineService = timeMachineService

        // FrictionMonitor stays eager — read by RootView at startup.
        // (AmbientCapture and the rest of the Omega ambient/cognitive chain were removed.)
        self._frictionMonitor = FrictionMonitorService(config: epistemosConfig)

        // Phase 6.5: Text capture pipeline — capture → structure → memory → evidence → trace
        self._textCapturePipeline = TextCapturePipeline()
        FrictionMonitorService.shared = frictionMonitor

        // Evict old disk style cache entries in background (filesystem I/O).
        Task(priority: .utility) { DiskStyleCache.shared.evictIfNeeded() }

        // Give VaultSyncService access to EventBus for change notifications
        vaultSync.setEventBus(eventBus)

        #if !EPISTEMOS_FREE_V1
        // Phase R.3 — initialize the canonical Rust `VaultResourceService`
        // resource-service initialization as
        // soon as we know the vault URL. This is scaffolding for the
        // planned R.3 migrations (NoteFileStorage / VaultIndexActor /
        // NotesSidebar read paths → unified gateway). Until those call
        // sites migrate, this init is a no-op at the user level — but
        // `resourceServiceIsReady()` now flips to true, which is the
        // prerequisite for every subsequent R.3 work.
        //
        // Errors are logged and swallowed: we do NOT want the gateway
        // init to crash app launch in the unlikely case of a
        // SQLite/filesystem failure. The legacy note I/O paths
        // continue to work regardless.
        initializeRustResourceServiceIfReady()

        // Phase R.5 persistence — migrate the in-memory permission
        // store to an on-disk SQLite file at a container-safe path.
        // Without this, R.5 grants disappear on app quit, so the
        // user has to re-say "you have my permission" every launch.
        // With this, a grant recorded once survives future launches
        // until the user explicitly revokes (or until the scope
        // expires).
        //
        // We call this BEFORE any chat UI can take a user turn, so
        // the very first grant of the session lands in the on-disk
        // store — not in the in-memory fallback that would be
        // replaced by the subsequent init and thus lose the row.
        initializeRustPermissionStoreIfReady()
        verifyAgentCorePolicyProfile()
        #endif

        // Instant recall has a warm idle path so the first typed sentence does
        // not pay vault hydration. The actual rebuild still runs off-main.
        instantRecallService.configureInitialSnapshotProvider { [self] in
            snapshotInstantRecallNotes()
        }
        if !Self.isRunningTests {
            Task { @MainActor [instantRecallService, contextualShadowsState] in
                try? await Task.sleep(for: .milliseconds(1_600))
                guard contextualShadowsState.isEnabled else { return }
                instantRecallService.prewarmForAmbientRecall()
            }
        }

        // Body-file migration runs off-main to avoid launch hitching.
        // Orphan cleanup now waits for a confirmed healthy vault attach/import.
        Task(priority: .utility) {
            await migrateBodiesToFileStorage()
        }

        // Keep the graph fully lazy at launch so normal idle use does not pay the
        // graph-store residency cost until the graph is actually opened.
        graphState.modelContext = container.mainContext

        scheduleMetalShaderWarmupIfNeeded()

        // Configure query engine with live dependencies (used by graph sidebar search).
        // The search index resolves lazily on first query so launch does not pay
        // the FTS/database setup cost unless the user actually opens search.
        let searchIndexProvider: QueryEngine.SearchIndexProvider = { [vaultSync] in
            vaultSync.searchService ?? Self.makeFallbackSearchIndexService()
        }
        #if EPISTEMOS_FREE_V1
        queryEngine.configure(
            graphStore: graphState.store,
            graphState: graphState,
            searchIndexProvider: searchIndexProvider
        )
        #else
        queryEngine.configure(
            graphStore: graphState.store,
            graphState: graphState,
            searchIndexProvider: searchIndexProvider,
            preparedRetrievalRuntimeConfiguration: preparedModelRegistryState.retrievalRuntimeConfiguration
        )
        #endif

        // App Shortcuts metadata is static and Settings exposes an explicit
        // refresh action. Do not touch external Shortcuts services during
        // passive launch; that path has triggered privacy/TCC diagnostics.

        commandCenterLocalHotkeyMonitor = nil
        commandCenterGlobalHotkeyMonitor = nil

        Log.app.info("AppBootstrap: initialized — foundation services ready")
    }

    private static func prepareSharedSubstrateContainer(
        _ appGroupContainer: AppGroupContainer = .shared
    ) {
        do {
            try appGroupContainer.ensureLayout()
            try appGroupContainer.migrateLegacyDatabasesIfNeeded()
            Log.app.info(
                "AppBootstrap: shared substrate container ready at \(appGroupContainer.rootURL.path, privacy: .public)"
            )
        } catch {
            Log.app.error(
                "AppBootstrap: shared substrate container init failed: \(error.localizedDescription, privacy: .public)"
            )
            RuntimeDiagnostics.record(
                .error,
                category: "AppGroup",
                message: "Shared substrate container init failed",
                metadata: [
                    "error": error.localizedDescription,
                    "group": AppGroupContainer.canonicalGroupIdentifier,
                ]
            )
        }
    }

    nonisolated static func startupIntegritySamplePageIdsForTesting(_ pageIds: [String]) -> [String] {
        let normalized = Array(Set(pageIds.filter { NoteFileStorage.isValidPageId($0) })).sorted()
        guard !normalized.isEmpty else { return [] }

        let sampleSize = min(normalized.count, max(1, normalized.count / 10), 64)
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
        let vaultBookmarkBlocksAutomaticRestore = vaultBookmarkValidation.shouldBlockAutomaticRestore
        let shouldDeferVaultSourcePreflight = vaultBookmarkValidation.bookmarkExists
        let unrecoverablePageIds =
            if shouldDeferVaultSourcePreflight {
                [String]()
            } else {
                startupUnrecoverablePageIdsForTesting(
                    pageSnapshots,
                    bodyFileExists: bodyFileExists,
                    filePathReadable: filePathReadable
                )
            }
        return StartupIntegrityReport(
            sampledPageIds: samplePageIds,
            corruptedPageIds: corruptedPageIds,
            unrecoverablePageIds: unrecoverablePageIds,
            eventStoreAvailable: eventStoreAvailable,
            vaultBookmarkExists: vaultBookmarkValidation.bookmarkExists,
            vaultBookmarkReadyForAutomaticRestore: vaultBookmarkValidation.isReadyForAutomaticRestore,
            vaultBookmarkFailureReason: vaultBookmarkValidation.failureReason,
            vaultBookmarkBlocksAutomaticRestore: vaultBookmarkBlocksAutomaticRestore
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

        if report.vaultBookmarkBlocksAutomaticRestore,
           let vaultBookmarkFailureReason = report.vaultBookmarkFailureReason {
            segments.append("\(vaultBookmarkFailureReason) Automatic vault restore was paused.")
            type = .error
        }

        let corruptedCount = report.corruptedPageIds.count
        if corruptedCount > 0,
           (!report.vaultBookmarkExists || report.vaultBookmarkBlocksAutomaticRestore) {
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
        let pages: [SDPage]
        do {
            pages = try context.fetch(FetchDescriptor<SDPage>())
        } catch {
            recordPersistenceIssue("Startup integrity snapshot failed", error: error)
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

    private nonisolated static func shouldScheduleInitialGraphLoad(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        false
    }

    private nonisolated static func shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestore(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldDeferLaunchVaultPreloads(vaultBookmarkValidation: vaultBookmarkValidation)
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
        let vaultBookmarkValidation = await vaultSync.startupBookmarkValidationWithTimeout()
        let pageSnapshots = startupIntegrityPageSnapshots()
        let report = await Task.detached(priority: .utility) {
            Self.startupIntegrityReportForTesting(
                samplePageIds: Self.startupIntegritySamplePageIdsForTesting(
                    NoteFileStorage.managedBodyPageIds()
                ),
                readBodyData: { pageId in
                    NoteFileStorage.readBodyData(pageId: pageId, fast: true)
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

        activityTracker.loadFlushedEvents()
        workspaceService.autoRestore()
        activityTracker.startTracking()
        workspaceService.startAutoSave()
        refreshLiveNoteScheduler()
        didCompletePrimaryLaunchInitialization = true

    }

    func runAutomaticVaultRestoreAfterLaunchIfNeeded() async {
        let report = await performStartupIntegrityCheck()
        let vaultBookmarkValidation = report.vaultBookmarkValidation
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
        refreshLiveNoteScheduler()
    }

    private func refreshWelcomeBackSummary() async {
        #if EPISTEMOS_FREE_V1
        applyStoredWelcomeBackSummary()
        #else
        guard FoundationSafety.runtimeUserDefaults.bool(forKey: "epistemos.enableLaunchWelcomeBackModelRefresh") else {
            applyStoredWelcomeBackSummary()
            return
        }

        await workspaceSummaryService.generateSummaryNow()
        applyStoredWelcomeBackSummary()
        #endif
    }

    private func applyStoredWelcomeBackSummary() {
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        do {
            if let ws = try modelContainer.mainContext.fetch(
                FetchDescriptor(predicate: predicate)
            ).first, !ws.summary.isEmpty {
                workspaceService.welcomeBack?.intentSummary = WelcomeBackInfo.cleanedSummaryText(from: ws.summary)
            }
        } catch {
            recordPersistenceIssue("Welcome-back summary fetch failed", error: error)
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
            do {
                try await Task.sleep(for: Self.primaryLaunchInitializationPollInterval)
            } catch is CancellationError {
                return
            } catch {
                Log.app.error("Primary launch initialization wait failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    // MARK: - Forwarding (for external callers that reference AppBootstrap directly)

    func refreshAmbientManifest() {
        Task { [weak self, vaultSync = self.vaultSync] in
            let manifest = await vaultSync.buildAmbientManifest()
            guard let self else { return }
            vaultSync.ambientManifest = manifest
            self.ambientManifest = manifest
        }
    }

    func refreshLiveNoteScheduler() {}

    // MARK: - On-Demand Memory Unload (ISSUE-2026-05-12-006)

    /// Result of a manual on-demand idle-unload, reported back to the
    /// diagnostic UI so the user can see what was actually released
    /// without spinning up Instruments.
    public struct IdleUnloadReport: Sendable, Equatable {
        public let residentMBBefore: Int
        public let residentMBAfter: Int
        public let mbFreed: Int
        public let rustSegmentsEvicted: UInt32
        public let rustSegmentBytesFreedMB: UInt64
        public let rustSessionsPruned: UInt32
        public let mlxUnloaded: Bool
        public let searchCachesReleased: Bool
        public let durationMs: Int
    }

    /// Run the same unload sequence the critical memory-pressure
    /// handler runs, but on demand and synchronous so the diagnostic
    /// row can report the actual delta.
    ///
    /// This is the in-app substitute for "open Instruments and profile."
    /// Users can click the Force Idle Unload button, see the RSS drop,
    /// and report which subsystem actually contributed.
    @MainActor
    public func forceIdleUnload() async -> IdleUnloadReport {
        let start = Date()
        let before = Self.currentResidentMB()

        let rustSegmentsEvicted: UInt32
        let rustSegmentBytesFreedMB: UInt64
        let rustSessionsPruned: UInt32
        rustSegmentsEvicted = 0
        rustSegmentBytesFreedMB = 0
        rustSessionsPruned = 0

        // Swift-side: search caches
        let searchService = vaultSync.searchService
        if let searchService {
            searchService.releaseMemoryPressureCaches()
        }

        let mlxUnloaded = false

        let after = Self.currentResidentMB()
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)

        Log.app.info(
            "ForceIdleUnload: \(before, privacy: .public) MB → \(after, privacy: .public) MB, freed \(before - after, privacy: .public) MB in \(durationMs, privacy: .public) ms"
        )

        return IdleUnloadReport(
            residentMBBefore: before,
            residentMBAfter: after,
            mbFreed: max(0, before - after),
            rustSegmentsEvicted: rustSegmentsEvicted,
            rustSegmentBytesFreedMB: rustSegmentBytesFreedMB,
            rustSessionsPruned: rustSessionsPruned,
            mlxUnloaded: mlxUnloaded,
            searchCachesReleased: searchService != nil,
            durationMs: durationMs
        )
    }

    #if !EPISTEMOS_FREE_V1
    private func startDeferredRuntimeServicesIfNeeded() {
        guard !Self.isRunningTests else { return }
        guard !didStartDeferredRuntimeServices else { return }
        didStartDeferredRuntimeServices = true

        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.deferredRuntimeServicesDelay)
            } catch is CancellationError {
                return
            } catch {
                Log.app.error("Deferred runtime services launch failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let self else { return }

            self.mutationOpLogProjectionWorker?.scheduleDrain(reason: "deferred_runtime_services")

        }
    }
    #endif

    /// On-demand support bundle probe for the derived search index. The
    /// SQLite index is a recoverable cache, so this reports health only; it
    /// never makes the index authoritative over vault files.
    func searchIndexSupportDiagnostics() async -> SearchIndexIntegrityDiagnostics? {
        guard let searchService = vaultSync.searchService else { return nil }
        return await Task.detached(priority: .utility) {
            try? searchService.supportDiagnostics()
        }.value
    }

    /// Helper for ForceIdleUnload diagnostics. Mirrors the existing
    /// `EpistemosApp.currentMemoryUsageMB()` private helper so the
    /// before/after measurements use the same accounting basis as
    /// the rest of the app.
    private static func currentResidentMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rawPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size / (1024 * 1024))
    }

    // MARK: - Database Recovery

    func resetDatabaseAndRelaunch() {
        guard !Self.isRunningTests else {
            Log.app.info("Skipping database reset relaunch under tests")
            return
        }

        let fm = FileManager.default
        let appSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: fm)
        let legacyStoreURL = Self.legacyRootModelStoreURL(applicationSupportDirectory: appSupport)
        let appScopedStoreURL = Self.persistentModelStoreURL(
            applicationSupportDirectory: appSupport,
            fileManager: fm
        )

        for url in Self.modelStoreArtifactURLs(for: legacyStoreURL) + Self.modelStoreArtifactURLs(for: appScopedStoreURL) {
            removeItemIfPresent(
                at: url,
                fileManager: fm,
                failureMessage: "Database reset cleanup failed"
            )
        }

        // Also clean Epistemos subdirectory (search index, etc.)
        let epistemosDirectory = appSupport.appendingPathComponent("Epistemos")
        do {
            let contents = try fm.contentsOfDirectory(at: epistemosDirectory, includingPropertiesForKeys: nil)
            for file in contents where file.pathExtension == "sqlite"
                || file.lastPathComponent.contains("default.store") {
                removeItemIfPresent(
                    at: file,
                    fileManager: fm,
                    failureMessage: "Database reset cleanup failed"
                )
            }
        } catch {
            recordPersistenceIssue("Failed to enumerate Epistemos directory during reset", error: error)
        }
        Log.app.info("Database reset complete — relaunching")
        relaunchApp()
    }

    func relaunchSkippingRestoreAndDiscardSession() {
        guard !Self.isRunningTests else {
            Log.app.info("Skipping skip-restore relaunch under tests")
            return
        }

        workspaceService.prepareSkipRestoreRelaunch()
        SavedApplicationStatePurger.purgeIfNeeded()
        Log.app.info("Skip-restore relaunch requested — relaunching into Home")
        relaunchApp()
    }

    private func snapshotInstantRecallSeeds() -> [InstantRecallSeed] {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
        )
        let pages: [SDPage]
        do {
            pages = try modelContainer.mainContext.fetch(descriptor)
        } catch {
            recordPersistenceIssue("Instant Recall seed snapshot failed", error: error)
            return []
        }
        return pages.map {
            InstantRecallSeed(
                id: $0.id,
                filePath: $0.filePath,
                inlineBody: $0.body,
                liveBody: NoteWindowManager.shared.editorBody(for: $0.id)
            )
        }
    }

    private func snapshotInstantRecallNotes() -> [(id: String, text: String)] {
        snapshotInstantRecallSeeds().map { seed in
            let vaultBody: String? = {
                guard let filePath = seed.filePath,
                      !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return VaultIndexActor.decodedBodyFromReadableVaultFile(at: URL(fileURLWithPath: filePath))
            }()
            let text = seed.liveBody ?? vaultBody ?? SDPage.legacyManagedOrInlineBody(
                pageId: seed.id,
                inlineBody: seed.inlineBody,
                mapped: true,
                fast: true
            )
            return (id: seed.id, text: text)
        }
    }

    // MARK: - Full Reset

    func clearVaultLifecycleRuntimeState(reason: String, clearWorkspaceRestore: Bool = false) {
        queryTask?.cancel()
        queryTask = nil
        #if !EPISTEMOS_FREE_V1
        preparedRetrievalRefreshTask?.cancel()
        preparedRetrievalRefreshTask = nil
        #endif
        healthyVaultBodyCleanupTask?.cancel()
        healthyVaultBodyCleanupTask = nil

        ambientManifest = nil
        vaultSync.ambientManifest = nil
        queryEngine.resetForVaultLifecycle()
        queryEngine.invalidateRuntime()
        contextualShadowsState.resetForVaultLifecycle()
        instantRecallService.clearIndex()
        graphState.resetForVaultLifecycle()
        if case .document = uiState.homeContent {
            uiState.homeContent = .greeting
        }
        if clearWorkspaceRestore {
            workspaceService.stopAutoSave()
            workspaceService.clearAutoSavedWorkspace()
            workspaceService.welcomeBack = nil
        }
        Log.pipeline.info("Vault lifecycle: cleared runtime state (\(reason, privacy: .public))")
    }

    func resetAllData() async {
        clearVaultLifecycleRuntimeState(
            reason: "Reset Everything started",
            clearWorkspaceRestore: true
        )
        let didClear = await vaultSync.stopWatchingAsync(preserveData: false)
        if !didClear {
            await vaultSync.forceClearDerivedLocalStateForFullReset()
        }
        vaultSync.clearPersistedVaultSelection()
        NoteWindowManager.shared.resetForVaultRebuild()

        let context = modelContainer.mainContext
        do {
            try context.delete(model: SDMessage.self)
            try context.delete(model: SDChat.self)
            try context.delete(model: SDPageVersion.self)
            try context.delete(model: SDNoteInsight.self)
            try context.delete(model: SDGraphEdge.self)
            try context.delete(model: SDGraphNode.self)
            try context.delete(model: SDBlock.self)
            try context.delete(model: SDPage.self)
            try context.delete(model: SDFolder.self)
            try context.delete(model: SDWorkspace.self)
            try context.save()
            _ = NoteFileStorage.removeAllManagedBodies()
        } catch {
            Log.pipeline.error("Reset: SwiftData wipe failed: \(error.localizedDescription, privacy: .public)")
        }

        let defaults = FoundationSafety.runtimeUserDefaults
        let keysToRemove = [
            "epistemos.localRoutingMode",
            "epistemos.preferredLocalTextModelID",
            "epistemos.preferredChatModelSelection",
        ]
        #if EPISTEMOS_FREE_V1
        LegacyRemoteConfiguration.purge(defaults: defaults)
        #else
        ProductRuntimeState.purgeLegacyRemoteConfiguration(defaults: defaults)
        #endif
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        notesUI.resetForVaultSwitch()
        pipelineState.reset()
        clearVaultLifecycleRuntimeState(
            reason: "Reset Everything completed",
            clearWorkspaceRestore: true
        )

        uiState.setActivePanel(.home)
        uiState.needsSetup = false
        FoundationSafety.runtimeUserDefaults.set(false, forKey: "epistemos.setupComplete")

        Log.pipeline.info("Reset: All data cleared. Setup assistant re-armed.")
    }

    private func clearVisualCaches() {
        DiskStyleCache.shared.clearAll()
    }

    private func scheduleMetalShaderWarmupIfNeeded() {
        guard Self.shouldScheduleMetalShaderWarmupAtLaunch() else { return }

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
        if !FoundationSafety.runtimeUserDefaults.bool(forKey: migrationKey) {
            do {
                let migrated = try await actor.migrateInlineBodiesToFiles()
                FoundationSafety.runtimeUserDefaults.set(true, forKey: migrationKey)
                if migrated > 0 {
                    Log.persistence.info("Body file storage migration moved \(migrated) bodies to disk")
                }
            } catch {
                recordPersistenceIssue("Body migration failed", error: error)
            }
        }

        // 2. Block reference migration (for graph performance)
        if !FoundationSafety.runtimeUserDefaults.bool(forKey: blockMigrationKey) {
            do {
                let migrated = try await actor.migrateBlockReferences()
                FoundationSafety.runtimeUserDefaults.set(true, forKey: blockMigrationKey)
                if migrated > 0 {
                    Log.persistence.info("Block reference migration cached \(migrated) pages")
                }
            } catch {
                recordPersistenceIssue("Block reference migration failed", error: error)
            }
        }

        // 3. RCA-P0-003 — strip hidden capture-provenance / audio-source
        // HTML comments from any pre-2026-05-09 managed bodies still on
        // disk. New captures already sanitize at write time; this is
        // the export-share-migration runtime piece of RCA-P0-003 (the
        // remaining manual smoke item there is the export pipeline
        // inspection itself). Idempotent + one-shot via the
        // `v2_hidden_capture_metadata_migration_complete` flag.
        let hiddenMetadataKey = "v2_hidden_capture_metadata_migration_complete"
        if !FoundationSafety.runtimeUserDefaults.bool(forKey: hiddenMetadataKey) {
            // Detached so the I/O walk doesn't block bootstrap.
            // Sequential per pageId — `NoteFileStorage` serializes
            // writes through its own mutation queue.
            let migrated = await Task.detached(priority: .utility) {
                TextCapturePipeline.migrateLegacyCaptureMetadataInManagedBodies()
            }.value
            FoundationSafety.runtimeUserDefaults.set(true, forKey: hiddenMetadataKey)
            if migrated > 0 {
                Log.persistence.info(
                    "Hidden capture metadata migration stripped legacy comments from \(migrated) bodies"
                )
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



    func teardownRuntimeObservers() {
        sovereignGateLifecycleObserver.stop()

        if let monitor = commandCenterLocalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            commandCenterLocalHotkeyMonitor = nil
        }

        if let monitor = commandCenterGlobalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            commandCenterGlobalHotkeyMonitor = nil
        }

    }
}

@ModelActor
private actor BodyMigrationActor {
    func migrateInlineBodiesToFiles() async throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        var migrated = 0
        for page in pages where !page.body.isEmpty {
            guard let filePath = page.filePath?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !filePath.isEmpty else {
                continue
            }
            let fileURL = URL(fileURLWithPath: filePath)
            let output = VaultIndexActor.shouldWriteMarkdownFrontMatter(to: fileURL)
                ? VaultIndexActor.buildMarkdownSource(
                    pageId: page.id,
                    title: page.title,
                    tags: page.tags,
                    emoji: page.emoji,
                    isJournal: page.isJournal,
                    journalDate: page.journalDate,
                    parentPageId: page.parentPageId,
                    templateId: page.templateId,
                    frontMatter: page.frontMatter,
                    body: page.body
                )
                : page.body
            try await AtomicVaultWriter.shared.write(output, to: fileURL)
            page.updateBodyDerivedState(from: page.body)
            page.body = ""
            migrated += 1
        }
        if migrated > 0 {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                modelContext.processPendingChanges()
                throw error
            }
        }
        return migrated
    }

    func migrateBlockReferences() async throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        var migrated = 0
        let pattern = /\(\(([^)]+)\)\)/

        for page in pages where page.blockReferences.isEmpty {
            // Phase R.3: managed-sidecar-first body read via the
            // Sendable-primitive helper, with gateway fallback.
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: page.id,
                filePath: page.filePath,
                inlineBody: page.body,
                mapped: true
            )
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
