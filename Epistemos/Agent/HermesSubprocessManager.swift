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
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        env["PYTHONHASHSEED"] = "0"
        env["HERMES_QUIET"] = "1"
        env["HERMES_INTERACTIVE"] = "1"

        // Ensure Hermes has an app-scoped home with persistent learning state.
        if env["HERMES_HOME"] == nil {
            env["HERMES_HOME"] = defaultHermesHomeURL().path
        }

        let hermesHomeURL = URL(fileURLWithPath: env["HERMES_HOME"] ?? defaultHermesHomeURL().path)
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

    static func defaultHermesHomeURL(fileManager: FileManager = .default) -> URL {
        FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("Hermes", isDirectory: true)
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
        let normalizedCurrent = currentContents.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldUpgrade = Self.legacyBootstrapConfigs().contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedCurrent
        }
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
    let errorDetail: String?

    var isHealthy: Bool { pythonAvailable && hermesAgentFound && hermesImportable }
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

    // Monitoring
    private var stderrDrainTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var onRequestReceived: (@Sendable (_ jsonLine: String) -> Void)?

    // Configuration
    private let config: HermesConfig

    init(config: HermesConfig) {
        self.config = config
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
        handle.write(data)
    }

    /// Register a callback invoked for each JSON line received on stdout.
    /// The callback fires on a background queue — dispatch to main if needed.
    func setRequestHandler(_ handler: @escaping @Sendable (_ jsonLine: String) -> Void) {
        self.onRequestReceived = handler
    }

    // MARK: - Lifecycle

    func launch() async throws {
        guard !isRunning else { throw HermesSubprocessError.alreadyRunning }

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
        stderrBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.pythonPath)
        proc.arguments = config.launchArguments
        proc.currentDirectoryURL = config.hermesAgentDir
        proc.environment = config.environment

        // Set process group so we can kill the entire group on shutdown
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
                self.pid = nil
                if case .stopped = self.processState {
                    // Graceful stop — do nothing, already in correct state
                    return
                }
                let stderr = self.stderrBuffer
                self.processState = .crashed(exitCode: exitCode, lastStderr: stderr)
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

        // Publish write handle for thread-safe access
        publishWriteHandle(stdin.fileHandleForWriting)

        log.info("hermes-agent launched, pid=\(proc.processIdentifier)")

        startStdoutReader()
        startStderrDrain()
    }

    func terminate() {
        guard let proc = process, proc.isRunning else {
            processState = .stopped
            cleanupPipes()
            return
        }

        processState = .stopped
        log.info("Terminating hermes-agent pid=\(proc.processIdentifier)")

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

        cleanupPipes()
    }

    /// Terminate the entire process group (kills child processes too).
    func terminateProcessGroup() {
        guard let proc = process else { return }
        let pgid = proc.processIdentifier
        processState = .stopped
        // Send SIGTERM to the process group (negative PID)
        kill(-pgid, SIGTERM)
        log.info("Sent SIGTERM to process group \(pgid)")

        Task.detached(priority: .utility) {
            try? await Task.sleep(for: .seconds(5))
            // Force-kill process group if still alive
            kill(-pgid, SIGKILL)
        }

        cleanupPipes()
    }

    func restart() async throws {
        terminate()
        // Give process time to exit
        try await Task.sleep(for: .milliseconds(500))
        try await launch()
    }

    // MARK: - Watchdog Heartbeat

    func startWatchdog(interval: Duration = .seconds(30), timeout: Duration = .seconds(10)) {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                guard let self else { return }

                let running = await MainActor.run { self.isRunning }
                guard running else { continue }

                // Send MCP ping
                let pingRequest = """
                {"jsonrpc":"2.0","method":"ping","params":{},"id":"watchdog_\(Int.random(in: 1000...9999))"}
                """
                do {
                    try self.writeLine(pingRequest)
                } catch {
                    log.warning("Watchdog: failed to send ping — \(error.localizedDescription)")
                    await MainActor.run { self.terminate() }
                    break
                }
            }
        }
    }

    func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    // MARK: - Pre-warm

    /// Launch the Hermes subprocess early so the agent panel opens instantly.
    /// Call from a background task during app init when the user's preferred model is cloud.
    func preWarm() async {
        guard !isRunning else { return }
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
            if !hermesImportable {
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
            errorDetail: errorDetail
        )
        cachedHealthResult = result
        return result
    }

    // MARK: - Private

    private func startStdoutReader() {
        guard let handle = stdoutPipe?.fileHandleForReading else { return }
        let handler: (@Sendable (String) -> Void)? = onRequestReceived
        handle.readabilityHandler = { @Sendable fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else {
                // EOF — process likely exited
                fileHandle.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            // Split on newlines — each line is a separate Hermes bridge event.
            let lines = text.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                handler?(trimmed)
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
            guard let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.stderrBuffer.append(text)
                // Cap buffer size
                if self.stderrBuffer.count > self.stderrBufferMaxLength {
                    let dropCount = self.stderrBuffer.count - self.stderrBufferMaxLength
                    self.stderrBuffer = String(self.stderrBuffer.dropFirst(dropCount))
                }
            }
            // Log stderr lines for diagnostics
            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                log.debug("hermes-stderr: \(line)")
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

        watchdogTask?.cancel()
        watchdogTask = nil
        stderrDrainTask?.cancel()
        stderrDrainTask = nil

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        // Close pipe handles
        try? stdinPipe?.fileHandleForWriting.close()
        try? stdoutPipe?.fileHandleForReading.close()
        try? stderrPipe?.fileHandleForReading.close()

        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
    }

    private static func runQuickCommand(_ executable: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: executable)
            proc.arguments = arguments
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe() // discard stderr

            proc.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                continuation.resume(returning: output)
            }

            do {
                try proc.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
