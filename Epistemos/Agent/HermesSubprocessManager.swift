import Foundation
import os

// MARK: - Hermes Subprocess Manager
// Manages the hermes-agent Python subprocess lifecycle.
// Communication uses newline-delimited JSON over stdio pipes via the
// Epistemos bridge script, which wraps the real Hermes `AIAgent`.

private nonisolated let log = Logger(subsystem: "com.epistemos", category: "HermesSubprocess")

// MARK: - Configuration

struct HermesConfig: Sendable {
    static let canonicalDefaultModel = "anthropic/claude-opus-4.6"

    var pythonPath: String
    var hermesAgentDir: URL
    var model: String
    var maxTurns: Int
    var environment: [String: String]

    var hermesHomeURL: URL {
        if let rawPath = environment["HERMES_HOME"],
           !rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: rawPath).standardizedFileURL
        }
        return Self.defaultHermesHomeURL()
    }

    var bridgeScriptURL: URL {
        hermesAgentDir.appendingPathComponent("epistemos_bridge.py")
    }

    var launchArguments: [String] {
        [
            "-u",
            bridgeScriptURL.path,
            "--model", model,
            "--max-turns", String(maxTurns),
        ]
    }

    /// Resolve default config from environment and project layout.
    static func resolve(
        projectRoot: URL? = nil,
        bundleURL: URL = Bundle.main.bundleURL,
        currentDirectoryURL: URL? = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        fileManager: FileManager = .default
    ) -> HermesConfig {
        var env = ProcessInfo.processInfo.environment
        let homePath = normalizedHomeDirectoryPath(fileManager: fileManager)
        env["HOME"] = homePath
        if env["USERPROFILE"] == nil || env["USERPROFILE"]?.isEmpty == true {
            env["USERPROFILE"] = homePath
        }
        env["PATH"] = normalizedExecutablePath(existingPath: env["PATH"])
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        env["PYTHONHASHSEED"] = "0"
        env["HERMES_QUIET"] = "1"
        env["HERMES_INTERACTIVE"] = "1"

        // Ensure Hermes has an app-scoped home with persistent learning state.
        if env["HERMES_HOME"] == nil {
            env["HERMES_HOME"] = defaultHermesHomeURL(fileManager: fileManager).path
        }

        // ── Tool gate environment ──────────────────────────────────────
        // The hermes-agent tool registry silently drops tools whose
        // check_fn() returns False.  Ensure the critical gates pass:
        //
        //   TERMINAL_ENV=local  → gates terminal, file, and delegate tools
        //   TAVILY_API_KEY      → gates web_search, web_extract
        //   EXA_API_KEY         → gates web_search, web_extract (fallback)
        //
        // Cascade: explicit env var → Keychain → skip.
        if env["HERMES_ENV_TYPE"] == nil {
            env["HERMES_ENV_TYPE"] = "local"
        }
        if env["TERMINAL_ENV"] == nil {
            env["TERMINAL_ENV"] = env["HERMES_ENV_TYPE"] ?? "local"
        }
        // Set the agent's working directory to the user's home so file
        // tools can access Documents, Desktop, Downloads, etc.
        if env["TERMINAL_CWD"] == nil {
            env["TERMINAL_CWD"] = homePath
        }
        // Ensure ~/.hermes/ exists — session_search check_fn requires it.
        let dotHermes = URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent(".hermes", isDirectory: true)
        try? fileManager.createDirectory(
            at: dotHermes, withIntermediateDirectories: true, attributes: nil
        )
        for keychainMapping in Self.toolGateKeychainMappings {
            if env[keychainMapping.envVar] == nil || env[keychainMapping.envVar]?.isEmpty == true {
                if let value = Keychain.load(for: keychainMapping.keychainKey)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !value.isEmpty {
                    env[keychainMapping.envVar] = value
                }
            }
        }

        let hermesHomeURL = URL(
            fileURLWithPath: env["HERMES_HOME"] ?? defaultHermesHomeURL(fileManager: fileManager).path
        )
            .standardizedFileURL
        let pythonPath = env["HERMES_PYTHON_PATH"]
            ?? preferredPythonPath(hermesHomeURL: hermesHomeURL)
        let hermesDir = resolveHermesAgentDirectory(
            projectRoot: projectRoot,
            bundleURL: bundleURL,
            currentDirectoryURL: currentDirectoryURL,
            fileManager: fileManager
        )

        return HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: hermesDir,
            model: Self.canonicalDefaultModel,
            maxTurns: 30,
            environment: env
        )
    }

    // Maps hermes-agent env var names to macOS Keychain keys so tool
    // check_fn gates pass when the user has stored credentials.
    struct ToolGateKeychainMapping {
        let envVar: String
        let keychainKey: String
    }

    static let toolGateKeychainMappings: [ToolGateKeychainMapping] = [
        .init(envVar: "TAVILY_API_KEY", keychainKey: "epistemos.tavily.apiKey"),
        .init(envVar: "EXA_API_KEY", keychainKey: "epistemos.exa.apiKey"),
        .init(envVar: "FIRECRAWL_API_KEY", keychainKey: "epistemos.firecrawl.apiKey"),
        .init(envVar: "BROWSERBASE_API_KEY", keychainKey: "epistemos.browserbase.apiKey"),
        .init(envVar: "BROWSERBASE_PROJECT_ID", keychainKey: "epistemos.browserbase.projectID"),
        // Cloud provider keys — Hermes uses these for inference routing.
        // The HermesRuntimeRoute clears all provider keys and sets only the
        // active one, but we need them in the base environment so Hermes
        // can self-configure when launched without an explicit route.
        .init(envVar: "OPENROUTER_API_KEY", keychainKey: "epistemos.openrouter.apiKey"),
        .init(envVar: "ANTHROPIC_API_KEY", keychainKey: "epistemos.anthropic.apiKey"),
        .init(envVar: "OPENAI_API_KEY", keychainKey: "epistemos.openai.apiKey"),
        .init(envVar: "GOOGLE_API_KEY", keychainKey: "epistemos.google.apiKey"),
    ]

    static func defaultHermesHomeURL(fileManager: FileManager = .default) -> URL {
        FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("Hermes", isDirectory: true)
    }

    static func normalizedHomeDirectoryPath(fileManager: FileManager = .default) -> String {
        fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
    }

    static func normalizedExecutablePath(existingPath: String?) -> String {
        let preferred = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]

        var components: [String] = []
        for component in preferred {
            if !components.contains(component) {
                components.append(component)
            }
        }

        if let existingPath {
            for rawComponent in existingPath.split(separator: ":") {
                let component = String(rawComponent)
                guard !component.isEmpty, !components.contains(component) else { continue }
                components.append(component)
            }
        }

        return components.joined(separator: ":")
    }

    static func resolveHermesAgentDirectory(
        projectRoot: URL? = nil,
        bundleURL: URL = Bundle.main.bundleURL,
        currentDirectoryURL: URL? = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        fileManager: FileManager = .default
    ) -> URL {
        let environment = ProcessInfo.processInfo.environment
        var candidates: [URL] = []

        if let explicitPath = environment["HERMES_AGENT_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitPath.isEmpty {
            let explicitURL = URL(fileURLWithPath: explicitPath, isDirectory: true).standardizedFileURL
            candidates.append(explicitURL)
        }

        if let projectRoot {
            candidates.append(projectRoot.appendingPathComponent("hermes-agent", isDirectory: true))
        }

        for resourceRoot in bundleResourceDirectories(for: bundleURL) {
            candidates.append(resourceRoot.appendingPathComponent("AgentRuntime/hermes-agent", isDirectory: true))
            candidates.append(resourceRoot.appendingPathComponent("hermes-agent", isDirectory: true))
        }

        if let currentDirectoryURL {
            candidates.append(contentsOf: hermesDirectoryCandidates(around: currentDirectoryURL))
        }

        candidates.append(contentsOf: hermesDirectoryCandidates(around: bundleURL))

        for candidate in candidates {
            let standardized = candidate.standardizedFileURL
            if isHermesRuntimeDirectory(standardized, fileManager: fileManager) {
                return standardized
            }
        }

        let fallbackRoot = projectRoot
            ?? bundleURL.deletingLastPathComponent()
                .deletingLastPathComponent()
        return fallbackRoot.appendingPathComponent("hermes-agent", isDirectory: true).standardizedFileURL
    }

    static func preferredPythonPath(
        hermesHomeURL: URL? = nil,
        fileManager: FileManager = .default
    ) -> String {
        let resolvedHermesHomeURL = hermesHomeURL ?? {
            if let rawPath = ProcessInfo.processInfo.environment["HERMES_HOME"],
               !rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return URL(fileURLWithPath: rawPath).standardizedFileURL
            }
            return defaultHermesHomeURL(fileManager: fileManager)
        }()

        let candidates = [
            resolvedHermesHomeURL.appendingPathComponent(".venv/bin/python").path,
            resolvedHermesHomeURL.appendingPathComponent(".venv/bin/python3").path,
            "/opt/homebrew/bin/python3.13",
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/bin/python3.11",
            "/usr/local/bin/python3.13",
            "/usr/local/bin/python3.12",
            "/usr/local/bin/python3.11",
            "/usr/bin/python3",
        ]

        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0) })
            ?? "/usr/bin/python3"
    }

    private static func bundleResourceDirectories(for bundleURL: URL) -> [URL] {
        let standardized = bundleURL.standardizedFileURL
        if standardized.lastPathComponent == "Resources" {
            return [standardized]
        }
        if standardized.lastPathComponent == "Contents" {
            return [standardized.appendingPathComponent("Resources", isDirectory: true)]
        }
        if standardized.pathExtension == "app" {
            return [standardized.appendingPathComponent("Contents/Resources", isDirectory: true)]
        }
        return []
    }

    private static func hermesDirectoryCandidates(around start: URL, maxDepth: Int = 8) -> [URL] {
        var results: [URL] = []
        var current = start.standardizedFileURL

        if current.lastPathComponent == "hermes-agent" {
            results.append(current)
        }

        for _ in 0..<maxDepth {
            results.append(current.appendingPathComponent("hermes-agent", isDirectory: true))
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return results
    }

    private static func isHermesRuntimeDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        let runAgent = url.appendingPathComponent("run_agent.py")
        let bridge = url.appendingPathComponent("epistemos_bridge.py")
        return fileManager.fileExists(atPath: runAgent.path)
            && fileManager.fileExists(atPath: bridge.path)
    }

    static func defaultBootstrapConfig() -> String {
        bootstrapConfig(defaultModel: canonicalDefaultModel)
    }

    private static func bootstrapConfig(defaultModel: String) -> String {
        """
        model:
          default: "\(defaultModel)"
          provider: "auto"

        terminal:
          backend: "local"
          cwd: "."
          timeout: 120
          lifetime_seconds: 600

        memory:
          memory_enabled: true
          user_profile_enabled: true
          memory_char_limit: 3000
          user_char_limit: 1800
          nudge_interval: 8
          flush_min_turns: 4

        skills:
          creation_nudge_interval: 15

        session_reset:
          mode: both
          idle_minutes: 1440
          at_hour: 4
        """
    }

    private static func legacyBootstrapConfigs() -> [String] {
        [
            bootstrapConfig(defaultModel: "anthropic/claude-sonnet-4-6"),
            // Previous default with lower memory limits / slower terminal timeout.
            """
            model:
              default: "anthropic/claude-opus-4.6"
              provider: "auto"

            terminal:
              backend: "local"
              cwd: "."
              timeout: 180
              lifetime_seconds: 300

            memory:
              memory_enabled: true
              user_profile_enabled: true
              memory_char_limit: 2200
              user_char_limit: 1375
              nudge_interval: 10
              flush_min_turns: 6

            skills:
              creation_nudge_interval: 15

            session_reset:
              mode: both
              idle_minutes: 1440
              at_hour: 4
            """,
        ]
    }

    private static func looksLikeLegacyBootstrapConfig(_ contents: String) -> Bool {
        let normalized = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        if legacyBootstrapConfigs().contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == normalized
        }) {
            return true
        }

        let markers = [
            #"default: "anthropic/claude-sonnet-4-6""#,
            "timeout: 180",
            "lifetime_seconds: 300",
            "memory_char_limit: 2200",
            "user_char_limit: 1375",
            "nudge_interval: 10",
            "flush_min_turns: 6",
        ]

        return markers.allSatisfy { normalized.contains($0) }
    }

    func ensureHermesHomeScaffold(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: hermesHomeURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let skillsDir = hermesHomeURL.appendingPathComponent("skills", isDirectory: true)
        let memoriesDir = hermesHomeURL.appendingPathComponent("memories", isDirectory: true)
        try fileManager.createDirectory(at: skillsDir, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: memoriesDir, withIntermediateDirectories: true, attributes: nil)

        let configURL = hermesHomeURL.appendingPathComponent("config.yaml")
        let desiredContents = Self.defaultBootstrapConfig()
        if !fileManager.fileExists(atPath: configURL.path) {
            try Data(desiredContents.utf8).write(to: configURL, options: .atomic)
            return
        }

        let currentContents = try String(contentsOf: configURL, encoding: .utf8)
        let shouldUpgrade = Self.looksLikeLegacyBootstrapConfig(currentContents)
        if shouldUpgrade {
            try Data(desiredContents.utf8).write(to: configURL, options: .atomic)
        }
    }
}

struct HermesRuntimeRoute: Sendable, Equatable {
    let model: String
    let requestedProvider: String
    let baseURL: String?
    let apiMode: String?
    let environmentOverrides: [String: String]

    /// Resolve a route for a local agent-capable model via the bridge's local
    /// inference server. Returns nil if the model lacks agent capability.
    static func resolveLocal(
        modelID: String,
        inferencePort: Int
    ) -> HermesRuntimeRoute? {
        guard let model = LocalTextModelID(rawValue: modelID),
              model.canActAsAgent,
              inferencePort > 0 else {
            return nil
        }

        return HermesRuntimeRoute(
            model: "local-mlx",
            requestedProvider: "custom",
            baseURL: "http://127.0.0.1:\(inferencePort)/v1",
            apiMode: "chat_completions",
            environmentOverrides: [
                "HERMES_INFERENCE_PROVIDER": "custom",
                "OPENAI_API_KEY": "local-epistemos",
                "OPENAI_BASE_URL": "http://127.0.0.1:\(inferencePort)/v1",
            ]
        )
    }

    static func resolve(
        for selection: ChatModelSelection,
        apiKeyLookup: (CloudModelProvider) -> String?
    ) -> HermesRuntimeRoute? {
        guard case .cloud(let model) = selection,
              let apiKey = apiKeyLookup(model.provider)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            return nil
        }

        let clearedProviderEnvironment: [String: String] = [
            "OPENAI_API_KEY": "",
            "OPENAI_BASE_URL": "",
            "OPENROUTER_API_KEY": "",
            "ANTHROPIC_API_KEY": "",
            "ANTHROPIC_TOKEN": "",
            "CLAUDE_CODE_OAUTH_TOKEN": "",
            "GOOGLE_API_KEY": "",
        ]

        switch model.provider {
        case .openAI:
            return HermesRuntimeRoute(
                model: model.vendorModelID,
                requestedProvider: "custom",
                baseURL: "https://api.openai.com/v1",
                apiMode: "codex_responses",
                environmentOverrides: clearedProviderEnvironment.merging(
                    [
                        "HERMES_INFERENCE_PROVIDER": "custom",
                        "OPENAI_API_KEY": apiKey,
                        "OPENAI_BASE_URL": "https://api.openai.com/v1",
                    ],
                    uniquingKeysWith: { _, new in new }
                )
            )
        case .anthropic:
            return HermesRuntimeRoute(
                model: model.vendorModelID,
                requestedProvider: "anthropic",
                baseURL: "https://api.anthropic.com",
                apiMode: "anthropic_messages",
                environmentOverrides: clearedProviderEnvironment.merging(
                    [
                        "HERMES_INFERENCE_PROVIDER": "anthropic",
                        "ANTHROPIC_API_KEY": apiKey,
                    ],
                    uniquingKeysWith: { _, new in new }
                )
            )
        case .google:
            return HermesRuntimeRoute(
                model: model.vendorModelID,
                requestedProvider: "custom",
                baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/",
                apiMode: "chat_completions",
                environmentOverrides: clearedProviderEnvironment.merging(
                    [
                        "HERMES_INFERENCE_PROVIDER": "custom",
                        "OPENAI_API_KEY": apiKey,
                        "OPENAI_BASE_URL": "https://generativelanguage.googleapis.com/v1beta/openai/",
                        "GOOGLE_API_KEY": apiKey,
                    ],
                    uniquingKeysWith: { _, new in new }
                )
            )
        }
    }
}

// MARK: - Health Result

struct HermesHealthResult: Sendable {
    let pythonAvailable: Bool
    let pythonVersion: String?
    let hermesAgentFound: Bool
    let hermesImportable: Bool
    let bridgeResponsive: Bool
    let errorDetail: String?

    var isHealthy: Bool {
        pythonAvailable && hermesAgentFound && hermesImportable && bridgeResponsive
    }
}

// MARK: - Process State

enum HermesProcessState: Sendable {
    case idle
    case starting
    case running
    case crashed(exitCode: Int32, lastStderr: String)
    case stopped
}

// MARK: - Errors

enum HermesSubprocessError: LocalizedError {
    case pythonNotFound(String)
    case hermesAgentNotFound(URL)
    case bridgeScriptNotFound(URL)
    case alreadyRunning
    case launchFailed(String)
    case notRunning
    case terminationTimeout

    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path): "Python not found at: \(path)"
        case .hermesAgentNotFound(let url): "hermes-agent not found at: \(url.path)"
        case .bridgeScriptNotFound(let url): "Hermes bridge script not found at: \(url.path)"
        case .alreadyRunning: "Hermes subprocess is already running"
        case .launchFailed(let msg): "Failed to launch hermes-agent: \(msg)"
        case .notRunning: "Hermes subprocess is not running"
        case .terminationTimeout: "Hermes subprocess did not terminate within timeout"
        }
    }
}

// MARK: - Subprocess Manager

@MainActor @Observable
final class HermesSubprocessManager {
    private(set) var processState: HermesProcessState = .idle
    private(set) var pid: Int32?

    /// Set when Hermes reports an authentication failure (HTTP 401, missing API key).
    /// UI observes this to show an inline setup prompt.
    private(set) var authFailureMessage: String?

    /// Cooldown to prevent rapid relaunch after crash.
    private var lastCrashDate: Date?
    private let crashCooldown: TimeInterval = 5.0
    private var intentionalTerminationInFlight = false

    // Process internals (access from main actor only)
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    // Thread-safe write handle for nonisolated writeLine()
    private let writeHandleLock = NSLock()
    @ObservationIgnored
    private nonisolated(unsafe) var _writeHandle: FileHandle?

    // Stderr buffer for crash diagnostics
    private var stderrBuffer: String = ""
    private let stderrBufferMaxLength = 8192
    private let stderrBufferLock = NSLock()
    @ObservationIgnored
    private nonisolated(unsafe) var stderrBufferSnapshot: String = ""

    // Monitoring
    private var stderrDrainTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private let watchdogPingLock = NSLock()
    @ObservationIgnored
    private nonisolated(unsafe) var pendingWatchdogPingIDs: Set<Int> = []
    private var nextWatchdogPingID: Int = -1
    private let requestHandlerLock = NSLock()
    @ObservationIgnored
    private nonisolated(unsafe) var onRequestReceived: (@Sendable (_ jsonLine: String) -> Void)?
    private let disconnectHandlerLock = NSLock()
    @ObservationIgnored
    private nonisolated(unsafe) var onDisconnect: (@Sendable () -> Void)?

    // Pipe framing — reassembles Content-Length frames and resolves SHM references
    private let frameAccumulator = ChunkedMCPFrameAccumulator()

    // Configuration
    private let config: HermesConfig
    private let orphanCleanupProvider: @MainActor @Sendable () -> OrphanSubprocessCleanup?

    init(
        config: HermesConfig,
        orphanCleanupProvider: @escaping @MainActor @Sendable () -> OrphanSubprocessCleanup? = { AppBootstrap.shared?.orphanCleanup }
    ) {
        self.config = config
        self.orphanCleanupProvider = orphanCleanupProvider
    }

    convenience init() {
        self.init(config: .resolve())
    }

    var isRunning: Bool {
        if case .running = processState { return true }
        return false
    }

    // MARK: - Stdin/Stdout Access

    /// Write a newline-terminated JSON line to the subprocess stdin.
    /// Thread-safe — can be called from any actor.
    nonisolated func writeLine(_ json: String) throws {
        writeHandleLock.lock()
        let handle = _writeHandle
        writeHandleLock.unlock()
        guard let handle else { throw HermesSubprocessError.notRunning }
        guard let data = (json + "\n").data(using: .utf8) else { return }
        // Use the throwing write(contentsOf:) API to avoid NSException on broken pipe.
        try handle.write(contentsOf: data)
    }

    /// Register a callback invoked for each JSON line received on stdout.
    /// The callback fires on a background queue — dispatch to main if needed.
    func setRequestHandler(_ handler: @escaping @Sendable (_ jsonLine: String) -> Void) {
        requestHandlerLock.lock()
        onRequestReceived = handler
        requestHandlerLock.unlock()
    }

    /// Register a callback invoked whenever the subprocess disconnects or is terminated.
    /// Use this to fail pending requests immediately instead of waiting for timeouts.
    func setDisconnectHandler(_ handler: @escaping @Sendable () -> Void) {
        disconnectHandlerLock.lock()
        onDisconnect = handler
        disconnectHandlerLock.unlock()
    }

    // MARK: - Lifecycle

    func launch() async throws {
        guard !isRunning, process == nil else { throw HermesSubprocessError.alreadyRunning }

        // Prevent rapid relaunch after a crash
        if let lastCrash = lastCrashDate,
           Date().timeIntervalSince(lastCrash) < crashCooldown {
            throw HermesSubprocessError.launchFailed(
                "Hermes crashed recently. Waiting \(Int(crashCooldown))s before retry."
            )
        }

        // Validate paths
        guard FileManager.default.isExecutableFile(atPath: config.pythonPath) else {
            throw HermesSubprocessError.pythonNotFound(config.pythonPath)
        }
        let runAgentPath = config.hermesAgentDir.appendingPathComponent("run_agent.py")
        guard FileManager.default.fileExists(atPath: runAgentPath.path) else {
            throw HermesSubprocessError.hermesAgentNotFound(config.hermesAgentDir)
        }
        guard FileManager.default.fileExists(atPath: config.bridgeScriptURL.path) else {
            throw HermesSubprocessError.bridgeScriptNotFound(config.bridgeScriptURL)
        }

        do {
            try config.ensureHermesHomeScaffold()
        } catch {
            throw HermesSubprocessError.launchFailed(
                "Failed to scaffold Hermes home at \(config.hermesHomeURL.path): \(error.localizedDescription)"
            )
        }

        processState = .starting
        intentionalTerminationInFlight = false
        stderrBuffer = ""
        setStderrBufferSnapshot("")
        authFailureMessage = nil

        let proc = Process.init()
        proc.executableURL = URL(fileURLWithPath: config.pythonPath)
        proc.arguments = config.launchArguments
        proc.currentDirectoryURL = config.hermesAgentDir
        proc.environment = config.environment

        // Foundation.Process doesn't create a dedicated process group here.
        // Descendant cleanup is handled by OrphanSubprocessCleanup when needed.
        proc.qualityOfService = .userInitiated

        // Create pipes
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        // Termination handler — fires on background queue, dispatch to main
        proc.terminationHandler = { [weak self] terminatedProcess in
            let exitCode = terminatedProcess.terminationStatus
            DispatchQueue.main.async {
                guard let self else { return }
                AppBootstrap.shared?.orphanCleanup.untrack(pid_t(terminatedProcess.processIdentifier))
                self.pid = nil
                self.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                let stderr = self.captureTerminationStderr()
                if self.intentionalTerminationInFlight {
                    self.intentionalTerminationInFlight = false
                    self.processState = .stopped
                    self.stderrBuffer = stderr
                    self.cleanupPipes()
                    return
                }
                self.processState = .crashed(exitCode: exitCode, lastStderr: stderr)
                self.lastCrashDate = Date()
                log.error("hermes-agent exited with code \(exitCode)")
                self.cleanupPipes()
            }
        }

        do {
            try proc.run()
        } catch {
            processState = .idle
            throw HermesSubprocessError.launchFailed(error.localizedDescription)
        }

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        self.pid = proc.processIdentifier
        self.processState = .running
        AppBootstrap.shared?.orphanCleanup.track(proc)

        // Publish write handle for thread-safe access
        publishWriteHandle(stdin.fileHandleForWriting)

        log.info("hermes-agent launched, pid=\(proc.processIdentifier)")

        startStdoutReader()
        startStderrDrain()
    }

    func terminate() {
        guard let proc = process, proc.isRunning else {
            intentionalTerminationInFlight = false
            processState = .stopped
            cleanupPipes()
            return
        }

        intentionalTerminationInFlight = true
        log.info("Terminating hermes-agent pid=\(proc.processIdentifier)")

        if let orphanCleanup = orphanCleanupProvider() {
            orphanCleanup.cleanupProcessTree(rootPID: pid_t(proc.processIdentifier))
            log.info("Sent termination to Hermes process tree rooted at \(proc.processIdentifier)")
            return
        }

        // Graceful: SIGTERM
        proc.terminate()

        // Force kill after timeout (background)
        let capturedPid = proc.processIdentifier
        Task.detached(priority: .utility) {
            try? await Task.sleep(for: .seconds(5))
            // Check if still running by trying SIGCONT (signal 0 equivalent)
            let result = kill(capturedPid, 0)
            if result == 0 {
                // Still alive — force kill
                log.warning("hermes-agent pid=\(capturedPid) did not exit after SIGTERM, sending SIGKILL")
                kill(capturedPid, SIGKILL)
            }
        }
    }

    func restart() async throws {
        terminate()
        try await waitForProcessExit()
        try await launch()
    }

    // MARK: - Supervised Lifecycle

    /// Long-running method for OTP-style supervision.
    /// Launches the subprocess if not running, then suspends until the process exits.
    /// Throws on abnormal termination so the supervisor can apply restart policy.
    func runSupervised() async throws {
        if !isRunning {
            try await launch()
        }

        // Wait for process exit by polling state. The terminationHandler
        // sets processState to .crashed or .stopped on the main actor.
        while isRunning {
            try await Task.sleep(for: .seconds(1))
        }

        // Check exit reason
        if case .crashed(let exitCode, let stderr) = processState {
            throw HermesSubprocessError.launchFailed(
                "hermes-agent exited with code \(exitCode): \(stderr.prefix(512))"
            )
        }
        // .stopped = graceful exit, return normally (transient policy won't restart)
    }

    // MARK: - Watchdog Heartbeat

    func startWatchdog(interval: Duration = .seconds(30), timeout: Duration = .seconds(10)) {
        watchdogTask?.cancel()
        clearAllWatchdogPings()
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                guard let self else { return }

                let running = await MainActor.run { self.isRunning }
                guard running else { continue }

                let pingID = await MainActor.run { self.makeNextWatchdogPingID() }
                self.registerWatchdogPing(id: pingID)
                let pingRequest = """
                {"jsonrpc":"2.0","method":"ping","params":{},"id":\(pingID)}
                """
                do {
                    try self.writeLine(pingRequest)
                } catch {
                    self.clearWatchdogPing(id: pingID)
                    log.warning("Watchdog: failed to send ping — \(error.localizedDescription)")
                    await MainActor.run { self.terminate() }
                    break
                }

                let deadline = ContinuousClock.now + timeout
                while self.hasPendingWatchdogPing(id: pingID) {
                    guard !Task.isCancelled else {
                        self.clearWatchdogPing(id: pingID)
                        return
                    }
                    if ContinuousClock.now >= deadline {
                        self.clearWatchdogPing(id: pingID)
                        log.warning("Watchdog: ping response timed out; terminating Hermes")
                        await MainActor.run { self.terminate() }
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        }
    }

    func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
        clearAllWatchdogPings()
    }

    // MARK: - Pre-warm

    /// Launch the Hermes subprocess early so the agent panel opens instantly.
    /// Call from a background task during app init when the user's preferred model is cloud.
    func preWarm() async {
        guard !isRunning else { return }
        guard !PowerGuard.shared.shouldDisableBackground else { return }
        do {
            try await launch()
        } catch {
            log.info("Hermes pre-warm skipped: \(error.localizedDescription)")
        }
    }

    // MARK: - Health Check

    private static var cachedHealthResult: HermesHealthResult?

    static func healthCheck(config: HermesConfig? = nil, forceRefresh: Bool = false) async -> HermesHealthResult {
        if !forceRefresh, let cached = cachedHealthResult {
            return cached
        }
        let cfg = config ?? .resolve()

        // Check Python
        let pythonAvailable = FileManager.default.isExecutableFile(atPath: cfg.pythonPath)
        var pythonVersion: String?

        if pythonAvailable {
            pythonVersion = await Self.runQuickCommand(
                cfg.pythonPath,
                arguments: ["--version"]
            )
        }

        // Check hermes-agent directory
        let runAgentPath = cfg.hermesAgentDir.appendingPathComponent("run_agent.py")
        let bridgeScriptPath = cfg.bridgeScriptURL
        let hermesFound = FileManager.default.fileExists(atPath: runAgentPath.path)
            && FileManager.default.fileExists(atPath: bridgeScriptPath.path)

        // Check hermes-agent importability
        var hermesImportable = false
        var bridgeResponsive = false
        var errorDetail: String?
        if pythonAvailable && hermesFound {
            let result = await Self.runQuickCommand(
                cfg.pythonPath,
                arguments: [
                    "-c",
                    """
                    import sys
                    sys.path.insert(0, \(String(reflecting: cfg.hermesAgentDir.path)))
                    import run_agent
                    import acp_adapter.session
                    print("OK")
                    """
                ]
            )
            hermesImportable = result?.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
            if hermesImportable {
                if let bridgeProbeFailure = await Self.probeBridgeResponsiveness(config: cfg) {
                    errorDetail = "Hermes bridge probe failed: \(bridgeProbeFailure)"
                } else {
                    bridgeResponsive = true
                }
            } else {
                errorDetail = result ?? "import check produced no output"
            }
        } else if !pythonAvailable {
            errorDetail = "Python not found at \(cfg.pythonPath)"
        } else {
            errorDetail = "Hermes runtime files not found at \(cfg.hermesAgentDir.path)"
        }

        let result = HermesHealthResult(
            pythonAvailable: pythonAvailable,
            pythonVersion: pythonVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
            hermesAgentFound: hermesFound,
            hermesImportable: hermesImportable,
            bridgeResponsive: bridgeResponsive,
            errorDetail: errorDetail
        )
        cachedHealthResult = result
        return result
    }

    // MARK: - Private

    private func startStdoutReader() {
        guard let handle = stdoutPipe?.fileHandleForReading else { return }
        let accumulator = self.frameAccumulator
        handle.readabilityHandler = { @Sendable [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else {
                // EOF — process likely exited
                fileHandle.readabilityHandler = nil
                return
            }
            // Feed raw pipe bytes through the frame accumulator, which handles:
            // 1. Content-Length framed messages (reassembly across chunks)
            // 2. Line-delimited JSON-RPC (backward compat)
            // 3. SHM reference resolution (payloads >48KB via shm_open)
            Task { [weak self] in
                let messages = await accumulator.feedAndResolve(data)
                guard let self else { return }
                for message in messages {
                    self.recordWatchdogResponseIfNeeded(message)
                    self.currentRequestHandler()?(message)
                }
            }
        }
    }

    private func startStderrDrain() {
        guard let handle = stderrPipe?.fileHandleForReading else { return }
        handle.readabilityHandler = { @Sendable [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else {
                fileHandle.readabilityHandler = nil
                return
            }
            guard let self, let text = String(data: data, encoding: .utf8) else { return }
            self.appendToStderrBufferSnapshot(text)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.consumeStderrText(text)
            }
        }
    }

    private nonisolated func publishWriteHandle(_ handle: FileHandle?) {
        writeHandleLock.lock()
        _writeHandle = handle
        writeHandleLock.unlock()
    }

    private func cleanupPipes() {
        // Clear thread-safe write handle first
        publishWriteHandle(nil)
        intentionalTerminationInFlight = false

        watchdogTask?.cancel()
        watchdogTask = nil
        clearAllWatchdogPings()
        stderrDrainTask?.cancel()
        stderrDrainTask = nil

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        // Reset the frame accumulator so a restarted subprocess starts clean
        Task { await frameAccumulator.reset() }

        // Clean up any SHM segments created by the TCC Swift Proxy during this
        // session.  Without this, POSIX shared memory segments leak in the kernel
        // until app termination.
        // Note: Rust-side SHM segments (created by agent_core) are tracked in the
        // Rust ShmPool registry and cleaned via shm_cleanup_all on app exit.
        // Swift-side segments (created by ShmWriter for screenshots) are cleaned here.
        ShmWriter.cleanupTccProxySegments()

        // Close pipe handles
        try? stdinPipe?.fileHandleForWriting.close()
        try? stdoutPipe?.fileHandleForReading.close()
        try? stderrPipe?.fileHandleForReading.close()

        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
        notifyDisconnect()
    }

    private func waitForProcessExit(timeout: Duration = .seconds(6)) async throws {
        let deadline = ContinuousClock.now + timeout
        while process != nil {
            if ContinuousClock.now >= deadline {
                throw HermesSubprocessError.terminationTimeout
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func captureTerminationStderr() -> String {
        drainRemainingStderr()
        return currentStderrBufferSnapshot()
    }

    private func drainRemainingStderr() {
        guard let handle = stderrPipe?.fileHandleForReading else { return }
        while true {
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { continue }
            appendToStderrBufferSnapshot(text)
            consumeStderrText(text)
        }
    }

    private func consumeStderrText(_ text: String) {
        stderrBuffer.append(text)
        if stderrBuffer.count > stderrBufferMaxLength {
            let dropCount = stderrBuffer.count - stderrBufferMaxLength
            stderrBuffer = String(stderrBuffer.dropFirst(dropCount))
        }

        for line in text.components(separatedBy: "\n") where !line.isEmpty {
            log.debug("hermes-stderr: \(line)")
            if line.hasPrefix("[tool-gate]") {
                let parts = line.components(separatedBy: ": ")
                let toolName = parts.count > 1
                    ? parts[0].replacingOccurrences(of: "[tool-gate] ", with: "")
                    : "unknown"
                let reason = parts.count > 1 ? parts.dropFirst().joined(separator: ": ") : line
                log.warning("Tool gate failure: \(toolName) — \(reason)")
            }

            let lowered = line.lowercased()
            if lowered.contains("401")
                || lowered.contains("api_key not set")
                || lowered.contains("api key not set")
                || lowered.contains("authenticationerror")
                || lowered.contains("no cookie auth credentials")
                || lowered.contains("openrouter_api_key not set")
                || lowered.contains("anthropic_api_key not set")
                || lowered.contains("openai_api_key not set") {
                if authFailureMessage == nil {
                    authFailureMessage = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    log.warning("Auth failure detected — UI should prompt for API key setup")
                }
            }
        }
    }

    private nonisolated func currentRequestHandler() -> (@Sendable (_ jsonLine: String) -> Void)? {
        requestHandlerLock.lock()
        let handler = onRequestReceived
        requestHandlerLock.unlock()
        return handler
    }

    private nonisolated func currentDisconnectHandler() -> (@Sendable () -> Void)? {
        disconnectHandlerLock.lock()
        let handler = onDisconnect
        disconnectHandlerLock.unlock()
        return handler
    }

    private nonisolated func notifyDisconnect() {
        currentDisconnectHandler()?()
    }

    private func makeNextWatchdogPingID() -> Int {
        defer { nextWatchdogPingID -= 1 }
        return nextWatchdogPingID
    }

    private nonisolated func registerWatchdogPing(id: Int) {
        watchdogPingLock.lock()
        pendingWatchdogPingIDs.insert(id)
        watchdogPingLock.unlock()
    }

    @discardableResult
    private nonisolated func clearWatchdogPing(id: Int) -> Bool {
        watchdogPingLock.lock()
        let removed = pendingWatchdogPingIDs.remove(id) != nil
        watchdogPingLock.unlock()
        return removed
    }

    private nonisolated func hasPendingWatchdogPing(id: Int) -> Bool {
        watchdogPingLock.lock()
        let contains = pendingWatchdogPingIDs.contains(id)
        watchdogPingLock.unlock()
        return contains
    }

    private nonisolated func clearAllWatchdogPings() {
        watchdogPingLock.lock()
        pendingWatchdogPingIDs.removeAll(keepingCapacity: false)
        watchdogPingLock.unlock()
    }

    private nonisolated func recordWatchdogResponseIfNeeded(_ jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              payload["result"] != nil || payload["error"] != nil else {
            return
        }

        if let id = payload["id"] as? Int, id < 0 {
            clearWatchdogPing(id: id)
            return
        }
        if let idNumber = payload["id"] as? NSNumber {
            let id = idNumber.intValue
            if id < 0 {
                clearWatchdogPing(id: id)
            }
        }
    }

    private nonisolated func appendToStderrBufferSnapshot(_ text: String) {
        stderrBufferLock.lock()
        stderrBufferSnapshot.append(text)
        if stderrBufferSnapshot.count > stderrBufferMaxLength {
            let dropCount = stderrBufferSnapshot.count - stderrBufferMaxLength
            stderrBufferSnapshot = String(stderrBufferSnapshot.dropFirst(dropCount))
        }
        stderrBufferLock.unlock()
    }

    private nonisolated func currentStderrBufferSnapshot() -> String {
        stderrBufferLock.lock()
        let snapshot = stderrBufferSnapshot
        stderrBufferLock.unlock()
        return snapshot
    }

    private nonisolated func setStderrBufferSnapshot(_ value: String) {
        stderrBufferLock.lock()
        stderrBufferSnapshot = value
        stderrBufferLock.unlock()
    }

    private static func runQuickCommand(
        _ executable: String,
        arguments: [String],
        timeout: Duration = .seconds(5)
    ) async -> String? {
        final class QuickCommandState: @unchecked Sendable {
            private let lock = NSLock()
            nonisolated(unsafe) private var process: Process?
            nonisolated(unsafe) private var continuation: CheckedContinuation<String?, Never>?
            nonisolated(unsafe) private var resumed = false

            nonisolated func store(process: Process, continuation: CheckedContinuation<String?, Never>) -> Bool {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return false }
                self.process = process
                self.continuation = continuation
                return true
            }

            nonisolated func terminate() {
                lock.lock()
                let process = self.process
                lock.unlock()
                process?.terminate()
            }

            nonisolated func resume(with value: String?) {
                let continuation: CheckedContinuation<String?, Never>?
                lock.lock()
                guard !resumed else {
                    lock.unlock()
                    return
                }
                resumed = true
                continuation = self.continuation
                self.continuation = nil
                self.process = nil
                lock.unlock()
                continuation?.resume(returning: value)
            }
        }

        let state = QuickCommandState()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let proc = Process.init()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = arguments
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe() // discard stderr

                guard state.store(process: proc, continuation: continuation) else {
                    continuation.resume(returning: nil)
                    return
                }

                let timeoutTask = Task.detached(priority: .utility) {
                    try? await Task.sleep(for: timeout)
                    state.terminate()
                    state.resume(with: nil)
                }

                proc.terminationHandler = { _ in
                    timeoutTask.cancel()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)
                    state.resume(with: output)
                }

                do {
                    try proc.run()
                } catch {
                    timeoutTask.cancel()
                    state.resume(with: nil)
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(with: nil)
        }
    }

    private static func probeBridgeResponsiveness(
        config: HermesConfig,
        timeout: Duration = .seconds(5)
    ) async -> String? {
        let manager = await MainActor.run {
            HermesSubprocessManager(config: config)
        }
        let client = HermesMCPClient(
            subprocessManager: manager,
            defaultTimeout: timeout
        )

        do {
            try await manager.launch()
            await MainActor.run {
                client.attach()
            }
            _ = try await client.ping()
            await MainActor.run {
                manager.terminate()
            }
            return nil
        } catch {
            await MainActor.run {
                manager.terminate()
            }
            return error.localizedDescription
        }
    }
}
