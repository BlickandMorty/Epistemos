import AppIntents
import AppKit
import Foundation
import Metal
import os
import QuartzCore
import SwiftData

// MARK: - Ship Gate
// Release builds ship the same linked agent dylibs as debug builds, so
// Swift-side agent services stay available unless a future dedicated build
// variant intentionally removes them.
enum ShipGate {
    static let agentsEnabled = true
}

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

nonisolated struct StartupAutoDiscoveryKeyMapping: Sendable, Hashable {
    let envVar: String
    let keychainKey: String
}

nonisolated enum StartupAutoDiscoveryCredentialSource: String, Sendable, Equatable {
    case environment
    case keychain
    case configFile
    case missing
}

nonisolated struct StartupAutoDiscoveryCredentialStatus: Sendable, Equatable {
    let envVar: String
    let keychainKey: String
    let source: StartupAutoDiscoveryCredentialSource
    let origin: String?

    var isAvailable: Bool {
        source != .missing
    }

    var sourceDescription: String {
        switch source {
        case .environment:
            return "env"
        case .keychain:
            return "keychain"
        case .configFile:
            return "config:\(origin ?? "unknown")"
        case .missing:
            return "missing"
        }
    }
}

nonisolated struct StartupAutoDiscoveryReport: Sendable, Equatable {
    let credentialStatuses: [StartupAutoDiscoveryCredentialStatus]
    let browserToolAvailable: Bool
    let localModelDirectories: [URL]
    let huggingFaceModelDirectories: [URL]

    var availableCredentialLabels: [String] {
        credentialStatuses
            .filter(\.isAvailable)
            .map { "\($0.envVar)=\($0.sourceDescription)" }
            .sorted()
    }

    var missingCredentialEnvVars: [String] {
        credentialStatuses
            .filter { !$0.isAvailable }
            .map(\.envVar)
            .sorted()
    }
}

@MainActor
enum StartupAutoDiscovery {
    private static let browserbaseKeychainMappings: [StartupAutoDiscoveryKeyMapping] = [
        .init(envVar: "BROWSERBASE_API_KEY", keychainKey: "epistemos.browserbase.apiKey"),
        .init(envVar: "BROWSERBASE_PROJECT_ID", keychainKey: "epistemos.browserbase.projectID"),
    ]

    static var keyMappings: [StartupAutoDiscoveryKeyMapping] {
        var seen = Set<StartupAutoDiscoveryKeyMapping>()
        return browserbaseKeychainMappings.filter { seen.insert($0).inserted }
    }

    private static let configAliases: [String: [String]] = [
        "OPENROUTER_API_KEY": [
            "OPENROUTER_API_KEY",
            "openrouter_api_key",
            "providers.openrouter.api_key",
            "provider.openrouter.api_key",
            "openrouter.api_key",
        ],
        "ANTHROPIC_API_KEY": [
            "ANTHROPIC_API_KEY",
            "anthropic_api_key",
            "providers.anthropic.api_key",
            "provider.anthropic.api_key",
            "anthropic.api_key",
        ],
        "OPENAI_API_KEY": [
            "OPENAI_API_KEY",
            "openai_api_key",
            "providers.openai.api_key",
            "provider.openai.api_key",
            "openai.api_key",
        ],
        "GOOGLE_API_KEY": [
            "GOOGLE_API_KEY",
            "google_api_key",
            "providers.google.api_key",
            "provider.google.api_key",
            "google.api_key",
        ],
        "TAVILY_API_KEY": [
            "TAVILY_API_KEY",
            "tavily_api_key",
            "tools.tavily.api_key",
            "tool.tavily.api_key",
            "services.tavily.api_key",
            "service.tavily.api_key",
            "tavily.api_key",
        ],
        "EXA_API_KEY": [
            "EXA_API_KEY",
            "exa_api_key",
            "tools.exa.api_key",
            "tool.exa.api_key",
            "services.exa.api_key",
            "service.exa.api_key",
            "exa.api_key",
        ],
        "FIRECRAWL_API_KEY": [
            "FIRECRAWL_API_KEY",
            "firecrawl_api_key",
            "tools.firecrawl.api_key",
            "tool.firecrawl.api_key",
            "services.firecrawl.api_key",
            "service.firecrawl.api_key",
            "firecrawl.api_key",
        ],
        "BROWSERBASE_API_KEY": [
            "BROWSERBASE_API_KEY",
            "browserbase_api_key",
            "tools.browserbase.api_key",
            "tool.browserbase.api_key",
            "services.browserbase.api_key",
            "service.browserbase.api_key",
            "browserbase.api_key",
        ],
        "BROWSERBASE_PROJECT_ID": [
            "BROWSERBASE_PROJECT_ID",
            "browserbase_project_id",
            "tools.browserbase.project_id",
            "tool.browserbase.project_id",
            "services.browserbase.project_id",
            "service.browserbase.project_id",
            "browserbase.project_id",
        ],
    ]

    static func perform(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        homeDirectoryURL: URL? = nil,
        localModelRootURL: URL? = nil,
        configFileURLs: [URL]? = nil,
        readFile: (URL) -> String? = { url in
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                if FileManager.default.fileExists(atPath: url.path) {
                    Log.app.error(
                        "AppBootstrap: failed to read auto-discovery config \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
                return nil
            }
        },
        keychainLoad: (String) -> String? = { Keychain.load(for: $0) },
        keychainSave: (String, String) -> Bool = { value, key in
            Keychain.save(value, for: key)
        }
    ) -> StartupAutoDiscoveryReport {
        let resolvedHomeURL = (homeDirectoryURL ?? fileManager.homeDirectoryForCurrentUser)
            .standardizedFileURL
        let resolvedConfigURLs = configFileURLs
            ?? defaultConfigFileURLs(fileManager: fileManager, homeDirectoryURL: resolvedHomeURL)

        let parsedConfigs = resolvedConfigURLs.compactMap { url -> (URL, [String: String])? in
            guard let contents = readFile(url) else { return nil }
            return (url, parseConfigValues(contents))
        }

        let statuses = keyMappings.map { mapping in
            if let envValue = normalizedCredential(environment[mapping.envVar]) {
                if normalizedCredential(keychainLoad(mapping.keychainKey)) == nil {
                    _ = keychainSave(envValue, mapping.keychainKey)
                }
                return StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .environment,
                    origin: nil
                )
            }

            if normalizedCredential(keychainLoad(mapping.keychainKey)) != nil {
                return StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .keychain,
                    origin: nil
                )
            }

            if let configMatch = configMatch(for: mapping.envVar, parsedConfigs: parsedConfigs) {
                _ = keychainSave(configMatch.value, mapping.keychainKey)
                return StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .configFile,
                    origin: configMatch.url.lastPathComponent
                )
            }

            return StartupAutoDiscoveryCredentialStatus(
                envVar: mapping.envVar,
                keychainKey: mapping.keychainKey,
                source: .missing,
                origin: nil
            )
        }

        let browserToolAvailable = isExecutableAvailable(
            named: "agent-browser",
            path: environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin",
            fileManager: fileManager
        )

        let modelRootURL = localModelRootURL
            ?? LocalModelPaths.defaultRootDirectory(fileManager: fileManager)

        return StartupAutoDiscoveryReport(
            credentialStatuses: statuses,
            browserToolAvailable: browserToolAvailable,
            localModelDirectories: discoverLocalModelDirectories(
                rootDirectory: modelRootURL,
                fileManager: fileManager
            ),
            huggingFaceModelDirectories: discoverHuggingFaceModelDirectories(
                homeDirectoryURL: resolvedHomeURL,
                fileManager: fileManager
            )
        )
    }

    static func testHostReport(
        temporaryRootURL: URL = FileManager.default.temporaryDirectory
    ) -> StartupAutoDiscoveryReport {
        return StartupAutoDiscoveryReport(
            credentialStatuses: keyMappings.map { mapping in
                StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .missing,
                    origin: nil
                )
            },
            browserToolAvailable: false,
            localModelDirectories: [],
            huggingFaceModelDirectories: []
        )
    }

    static func defaultConfigFileURLs(
        fileManager: FileManager = .default,
        homeDirectoryURL: URL? = nil
    ) -> [URL] {
        let resolvedHomeURL = (homeDirectoryURL ?? fileManager.homeDirectoryForCurrentUser)
            .standardizedFileURL
        return [
            resolvedHomeURL
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("epistemos", isDirectory: true)
                .appendingPathComponent("config.toml", isDirectory: false),
            resolvedHomeURL
                .appendingPathComponent(".epistemos", isDirectory: true)
                .appendingPathComponent("config.toml", isDirectory: false),
        ]
    }

    static func parseConfigValues(_ contents: String) -> [String: String] {
        var values: [String: String] = [:]
        var sectionPath: [String] = []

        for rawLine in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let strippedLine = stripComment(from: String(rawLine))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !strippedLine.isEmpty else { continue }

            if strippedLine.hasPrefix("[") && strippedLine.hasSuffix("]") {
                let rawSection = strippedLine
                    .dropFirst()
                    .dropLast()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sectionPath = rawSection
                    .split(separator: ".")
                    .map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                            .lowercased()
                    }
                continue
            }

            guard let equalsIndex = strippedLine.firstIndex(of: "=") else { continue }

            let rawKey = strippedLine[..<equalsIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !rawKey.isEmpty else { continue }

            let rawValue = strippedLine[strippedLine.index(after: equalsIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsedValue = parseScalarValue(rawValue) else { continue }

            let loweredKey = rawKey.lowercased()
            values[rawKey] = parsedValue
            values[loweredKey] = parsedValue

            if !sectionPath.isEmpty {
                values[(sectionPath + [loweredKey]).joined(separator: ".")] = parsedValue
            }
        }

        return values
    }

    static func discoverLocalModelDirectories(
        rootDirectory: URL = LocalModelPaths.defaultRootDirectory(),
        fileManager: FileManager = .default
    ) -> [URL] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return []
        }
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            Log.app.error(
                "AppBootstrap: failed to enumerate local model directory root \(rootDirectory.path, privacy: .public)"
            )
            return []
        }

        let knownSlugs = Set(LocalModelCatalog.allDescriptors.map(\.slug))
        var discovered: Set<URL> = []

        for case let url as URL in enumerator {
            let resourceValues: URLResourceValues
            do {
                resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            } catch {
                Log.app.error(
                    "AppBootstrap: failed to inspect local model candidate \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                continue
            }

            guard resourceValues.isDirectory == true else {
                continue
            }

            let standardizedURL = url.standardizedFileURL
            let lastPathComponent = standardizedURL.lastPathComponent
            if lastPathComponent.hasSuffix(".mlx") || knownSlugs.contains(lastPathComponent) {
                discovered.insert(standardizedURL)
                enumerator.skipDescendants()
            }
        }

        return discovered.sorted { $0.path < $1.path }
    }

    static func discoverHuggingFaceModelDirectories(
        homeDirectoryURL: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        let hubURL = homeDirectoryURL
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)

        guard fileManager.fileExists(atPath: hubURL.path) else {
            return []
        }
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: hubURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            Log.app.error(
                "AppBootstrap: failed to enumerate Hugging Face cache \(hubURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return []
        }

        return contents.compactMap { url in
            let resourceValues: URLResourceValues
            do {
                resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            } catch {
                Log.app.error(
                    "AppBootstrap: failed to inspect Hugging Face model candidate \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }

            guard resourceValues.isDirectory == true,
                  url.lastPathComponent.hasPrefix("models--") else {
                return nil
            }
            return url.standardizedFileURL
        }
        .sorted { $0.path < $1.path }
    }

    static func isExecutableAvailable(
        named executableName: String,
        path: String,
        fileManager: FileManager = .default
    ) -> Bool {
        path
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }
            .contains { directory in
                fileManager.isExecutableFile(
                    atPath: URL(fileURLWithPath: directory, isDirectory: true)
                        .appendingPathComponent(executableName, isDirectory: false)
                        .path
                )
            }
    }

    static func log(_ report: StartupAutoDiscoveryReport) {
        let available = report.availableCredentialLabels.joined(separator: ", ")
        let missing = report.missingCredentialEnvVars.joined(separator: ", ")
        Log.app.info(
            """
            AppBootstrap: auto-discovery available [\(available, privacy: .public)] \
            missing [\(missing, privacy: .public)] \
            agent-browser=\(report.browserToolAvailable, privacy: .public) \
            local-model-dirs=\(report.localModelDirectories.count, privacy: .public) \
            hf-model-dirs=\(report.huggingFaceModelDirectories.count, privacy: .public)
            """
        )
    }

    private static func normalizedCredential(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func configMatch(
        for envVar: String,
        parsedConfigs: [(url: URL, values: [String: String])]
    ) -> (url: URL, value: String)? {
        let aliases = configAliases[envVar] ?? [envVar]
        for parsedConfig in parsedConfigs {
            for alias in aliases {
                if let value = normalizedCredential(parsedConfig.values[alias]) {
                    return (parsedConfig.url, value)
                }
            }
        }
        return nil
    }

    private static func parseScalarValue(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.count >= 2,
           let first = trimmed.first,
           let last = trimmed.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            let inner = trimmed.dropFirst().dropLast()
            return String(inner)
                .replacingOccurrences(of: #"\""#, with: "\"")
                .replacingOccurrences(of: #"\\\\"#, with: #"\"#)
        }

        return trimmed
    }

    private static func stripComment(from line: String) -> String {
        var result = ""
        var insideSingleQuote = false
        var insideDoubleQuote = false

        for character in line {
            switch character {
            case "'" where !insideDoubleQuote:
                insideSingleQuote.toggle()
            case "\"" where !insideSingleQuote:
                insideDoubleQuote.toggle()
            case "#" where !insideSingleQuote && !insideDoubleQuote:
                return result
            default:
                break
            }
            result.append(character)
        }

        return result
    }
}

@MainActor
final class AppBootstrap {
    /// Shared instance for App Intent access. Set during init.
    static var shared: AppBootstrap?
    private nonisolated static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// Populates process env vars from Keychain so the in-process Rust agent_core
    /// providers (Claude, OpenAI, Perplexity, Gemini) can read API keys via std::env::var.
    /// Called once at launch before any agent session can start.
    private static func populateAgentCoreEnvironment() {
        let mappings: [(envVar: String, keychainKey: String)] = [
            // Core providers
            ("ANTHROPIC_API_KEY", "epistemos.anthropic.apiKey"),
            ("OPENAI_API_KEY", "epistemos.openai.apiKey"),
            ("GOOGLE_API_KEY", "epistemos.google.apiKey"),
            ("PERPLEXITY_API_KEY", "epistemos.perplexity.apiKey"),
            // Universal gateway
            ("OPENROUTER_API_KEY", "epistemos.openrouter.apiKey"),
            // Chinese providers
            ("GLM_API_KEY", "epistemos.zai.apiKey"),
            ("KIMI_API_KEY", "epistemos.kimi.apiKey"),
            ("DEEPSEEK_API_KEY", "epistemos.deepseek.apiKey"),
            ("MINIMAX_API_KEY", "epistemos.minimax.apiKey"),
            // Western providers
            ("XAI_API_KEY", "epistemos.xai.apiKey"),
            ("MISTRAL_API_KEY", "epistemos.mistral.apiKey"),
            ("GROQ_API_KEY", "epistemos.groq.apiKey"),
            // HuggingFace
            ("HF_TOKEN", "epistemos.huggingface.apiKey"),
        ]
        for mapping in mappings {
            if let value = Keychain.load(for: mapping.keychainKey), !value.isEmpty {
                setenv(mapping.envVar, value, 1)
            }
        }
    }
    #if DEBUG
    private nonisolated static let isDebugBuild = true
    #else
    private nonisolated static let isDebugBuild = false
    #endif

    static func startupAutoDiscoveryReportForTesting(
        isRunningTests: Bool,
        discover: () -> StartupAutoDiscoveryReport = { StartupAutoDiscovery.perform() }
    ) -> StartupAutoDiscoveryReport {
        guard !isRunningTests else {
            return StartupAutoDiscovery.testHostReport()
        }
        return discover()
    }


    nonisolated static func shouldScheduleMetalShaderWarmupAtLaunch(
        isRunningTests: Bool = AppBootstrap.isRunningTests,
        isDebugBuild: Bool = AppBootstrap.isDebugBuild
    ) -> Bool {
        !isRunningTests && !isDebugBuild
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
    let constrainedDecoding = ConstrainedDecodingService()
    let hardwareTierManager = HardwareTierManager()
    private var _iMessageDriver: IMessageDriverService?
    var iMessageDriver: IMessageDriverService { Self.requireInitialized(_iMessageDriver, name: "iMessageDriver") }
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
    let ssmStateService: SSMStateService
    let noteInsightService: NoteInsightService
    let cloudKnowledgeDistillationService: CloudKnowledgeDistillationService
    private(set) var meaningAnchorService: MeaningAnchorService?

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

        let autoDiscoveryReport = Self.startupAutoDiscoveryReportForTesting(
            isRunningTests: Self.isRunningTests
        )
        StartupAutoDiscovery.log(autoDiscoveryReport)

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

        // Start centralized power authority — must be before any subsystem that
        // checks PowerGuard.shared.currentMode during init.
        PowerGuard.shared.start()

        // Start main thread watchdog to detect UI hangs (skipped in eco/lowPower).
        if !Self.isRunningTests && !PowerGuard.shared.shouldDisableBackground {
            MainThreadWatchdog.install()
        }

        // Start centralized thermal authority before any inference work.
        Task { await ThermalGuard.shared.start() }

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

        // SSMStateService — Mamba/SSM hidden state persistence for vault memory
        let ssmStateRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Epistemos", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let ssmStateService = SSMStateService(stateRoot: ssmStateRoot)
        ssmStateService.activate(enabled: epistemosConfig.ssmStatePersistenceEnabled)
        self.ssmStateService = ssmStateService

        // Wire SSM state service into the local inference engine
        Task {
            await localInferenceService.setSsmStateService(ssmStateService)
            await localInferenceService.setOnSSMStateSaved { sessionID, statePath in
                Log.app.info("SSM state saved for session=\(sessionID) at \(statePath)")
                guard let sessionUUID = UUID(uuidString: sessionID) else {
                    Log.app.warning("Ignoring SSM state bind for non-UUID session id \(sessionID)")
                    return
                }
                Task {
                    await ConversationPersistence.shared.bindSSMStatePath(
                        sessionID: sessionUUID,
                        statePath: statePath
                    )
                }
            }
        }

        // NoteInsightService — on-device ML analysis for all notes
        self.noteInsightService = NoteInsightService(modelContainer: container)

        // Cloud Knowledge Distillation — compiles per-model vault documents from local notes
        self.cloudKnowledgeDistillationService = CloudKnowledgeDistillationService(modelContainer: container)

        // Meaning Anchor Service — generates structured chat snapshots for graph intelligence
        self.meaningAnchorService = MeaningAnchorService(
            triageService: triage,
            graphState: graphState,
            modelContainer: container
        )

        // PipelineService — direct local answer streaming + tool-enabled loop
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llm,
            triageService: triage,
            inference: inference,
            eventBus: eventBus,
            localModelClient: localMLXClient,
            constrainedDecoding: constrainedDecoding,
            vaultPathProvider: { [weak vaultSync] in
                vaultSync?.vaultURL?.path
            }
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

        // Initialize iMessage driver (starts disabled — user toggles via Settings).
        // Local-model contacts route through `LocalAgentLoop` via the
        // localModelClientProvider; cloud contacts continue to use
        // `runAgentSession` against agent_core.
        self._iMessageDriver = IMessageDriverService(
            vaultPathProvider: { [weak vaultSync] in
                vaultSync?.vaultURL?.path
            },
            localModelClientProvider: { [weak self] in
                self?.localMLXClient
            },
            constrainedDecodingProvider: { [weak self] in
                self?.constrainedDecoding
            }
        )

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
        // Agent services: gated by ShipGate.agentsEnabled. When false,
        // NightBrain never starts — no background agent work. Zero runtime overhead.
        if ShipGate.agentsEnabled {
            self._nightBrain = NightBrainService(
                config: epistemosConfig,
                searchIndexProvider: { @MainActor [weak vaultSync] in
                    vaultSync?.searchService
                },
                graphMemoryProvider: { @MainActor [weak self] in
                    self?._agentGraphMemory
                },
                cloudKnowledgeJob: { [cloudKnowledgeDistillationService] in
                    _ = try await cloudKnowledgeDistillationService.rebuildAllModelVaults()
                },
                vaultPathProvider: { @MainActor [weak vaultSync] in
                    vaultSync?.vaultURL?.path
                },
                ssmStateServiceProvider: { @MainActor [weak self] in
                    self?.ssmStateService
                }
            )
        }

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

        // Instant recall now hydrates on first real recall use instead of
        // rebuilding its vault index during idle launch.
        instantRecallService.configureInitialSnapshotProvider { [self] in
            snapshotInstantRecallNotes()
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
        queryEngine.configure(
            graphStore: graphState.store,
            graphState: graphState,
            searchIndexProvider: { [vaultSync] in
                vaultSync.searchService ?? Self.makeFallbackSearchIndexService()
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

        // Populate process environment with API keys from Keychain so the
        // in-process Rust agent_core providers can read them via std::env::var.
        Self.populateAgentCoreEnvironment()

        activityTracker.loadFlushedEvents()
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

        // One-time meaning anchor backfill for existing chats
        if !UserDefaults.standard.bool(forKey: "epistemos.anchorBackfillComplete") {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                await self?.meaningAnchorService?.backfillExistingChats()
                UserDefaults.standard.set(true, forKey: "epistemos.anchorBackfillComplete")
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

            await self.nightBrain.start()
            KnowledgeFusionViewModel.shared.prepareBackgroundSchedulingIfNeeded()

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
        let appSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: fm)

        // SwiftData default.store lives at the Application Support root (no subdirectory)
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            removeItemIfPresent(
                at: appSupport.appendingPathComponent(name),
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
                inlineBody: $0.body,
                liveBody: NoteWindowManager.shared.editorBody(for: $0.id)
            )
        }
    }

    private func snapshotInstantRecallNotes() -> [(id: String, text: String)] {
        snapshotInstantRecallSeeds().map { seed in
            let diskBody = NoteFileStorage.readBody(pageId: seed.id, mapped: true)
            let text = seed.liveBody ?? (diskBody.isEmpty ? seed.inlineBody : diskBody)
            return (id: seed.id, text: text)
        }
    }

    // MARK: - Full Reset

    func resetAllData() async {
        queryTask?.cancel()
        queryTask = nil
        ambientManifest = nil
        vaultSync.ambientManifest = nil
        _ = await vaultSync.stopWatchingAsync(preserveData: false)
        vaultSync.clearPersistedVaultSelection()
        NoteWindowManager.shared.resetForVaultRebuild()

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
            .localMLX(inferenceState.hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue)
        )

        uiState.setActivePanel(.home)
        uiState.needsSetup = true

        Log.pipeline.info("Reset: All data cleared. Setup screen shown.")
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
