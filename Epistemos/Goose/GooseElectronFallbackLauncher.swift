import Foundation

#if !EPISTEMOS_APP_STORE
import AppKit

struct GooseElectronFallbackWorkspace: Equatable, Sendable {
    let repoRoot: URL
    let uiRoot: URL
    let pnpm: URL
}

@MainActor
final class GooseElectronFallbackLauncher {
    enum Status: Equatable, Sendable {
        case idle
        case unavailable(String)
        case starting
        case running(pid: Int32)
        case failed(String)
        case stopped
    }

    static let shared = GooseElectronFallbackLauncher()

    nonisolated static let uiRootEnvironmentKey = "EPISTEMOS_GOOSE_ELECTRON_UI_ROOT"
    nonisolated static let pnpmEnvironmentKey = "EPISTEMOS_GOOSE_ELECTRON_PNPM"
    nonisolated static let debugPortEnvironmentKey = "EPISTEMOS_GOOSE_ELECTRON_DEBUG_PORT"
    nonisolated static let maxStatusMessageCharacters = 512
    nonisolated private static let environmentAllowlist: Set<String> = [
        "PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TERM", "TZ", "SHELL",
    ]
    nonisolated private static let environmentDenylist: Set<String> = [
        "LD_PRELOAD",
        "LD_LIBRARY_PATH",
        "LD_AUDIT",
        "DYLD_INSERT_LIBRARIES",
        "DYLD_LIBRARY_PATH",
        "DYLD_FALLBACK_LIBRARY_PATH",
        "DYLD_FRAMEWORK_PATH",
        "DYLD_FALLBACK_FRAMEWORK_PATH",
        "NODE_OPTIONS",
        "NODE_PATH",
        "NODE_DEBUG",
        "PYTHONPATH",
        "PYTHONHOME",
        "OPENAI_API_KEY",
        "OPENAI_ACCESS_TOKEN",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_ACCESS_TOKEN",
        "GOOGLE_API_KEY",
        "GEMINI_API_KEY",
        "GLM_API_KEY",
        "ZHIPU_API_KEY",
        "ZAI_API_KEY",
        "MOONSHOT_API_KEY",
        "KIMI_API_KEY",
        "DEEPSEEK_API_KEY",
        "MINIMAX_API_KEY",
        "XAI_API_KEY",
        "MISTRAL_API_KEY",
        "GROQ_API_KEY",
        "HF_TOKEN",
        "HUGGINGFACE_API_KEY",
    ]

    private(set) var status: Status = .idle
    private(set) var lastDiagnostic: String?

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputTask: Task<Void, Never>?
    private lazy var cleanup = AppBootstrap.shared?.orphanCleanup ?? OrphanSubprocessCleanup()

    func launchFromMenu() {
        guard launch() else {
            presentCurrentFailure()
            return
        }
    }

    @discardableResult
    func launch(
        workspace: GooseElectronFallbackWorkspace? = nil,
        debugPort: Int? = nil
    ) -> Bool {
        switch status {
        case .starting, .running:
            return true
        default:
            break
        }

        guard let workspace = workspace ?? Self.resolveWorkspace() else {
            status = .unavailable("Real Goose Electron fallback checkout is not available.")
            return false
        }
        status = .starting
        return run(workspace: workspace, debugPort: debugPort ?? Self.debugPortFromEnvironment())
    }

    func stop() {
        outputTask?.cancel()
        outputTask = nil
        closeInputPipe()
        if let process {
            terminateTrackedProcess(process)
        }
        process = nil
        switch status {
        case .starting, .running:
            status = .stopped
        default:
            break
        }
    }

    private func run(workspace: GooseElectronFallbackWorkspace, debugPort: Int?) -> Bool {
        let proc = Process()
        proc.executableURL = workspace.pnpm
        proc.arguments = Self.launchArguments()
        proc.currentDirectoryURL = workspace.uiRoot
        proc.environment = Self.processEnvironment(workspace: workspace, debugPort: debugPort)

        let inputPipe = Pipe()
        let pipe = Pipe()
        proc.standardInput = inputPipe
        proc.standardOutput = pipe
        proc.standardError = pipe
        process = proc
        self.inputPipe = inputPipe
        proc.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleProcessExit(statusCode: process.terminationStatus)
            }
        }

        do {
            try proc.run()
            cleanup.track(proc)
            startReading(pipe.fileHandleForReading)
            status = .running(pid: proc.processIdentifier)
            return true
        } catch {
            status = .failed(Self.boundedStatusMessage(
                "Failed to launch real Goose Electron fallback: \(error.localizedDescription)"
            ))
            process = nil
            closeInputPipe()
            return false
        }
    }

    private func startReading(_ handle: FileHandle) {
        outputTask?.cancel()
        outputTask = Task.detached { [weak self] in
            await GooseProcessDiagnostics.consume(from: handle) { diagnostic in
                await self?.recordDiagnostic(diagnostic)
            }
        }
    }

    private func recordDiagnostic(_ message: String) {
        lastDiagnostic = message
    }

    private func handleProcessExit(statusCode: Int32) {
        if let process {
            cleanup.untrack(pid_t(process.processIdentifier))
        }
        process = nil
        closeInputPipe()
        outputTask?.cancel()
        outputTask = nil
        switch status {
        case .starting, .running:
            status = statusCode == 0 ? .stopped : .failed("Real Goose Electron fallback exited with status \(statusCode).")
        default:
            break
        }
    }

    private func terminateTrackedProcess(_ process: Process) {
        let pid = pid_t(process.processIdentifier)
        if pid > 0 {
            cleanup.cleanupProcessTree(rootPID: pid)
        }
        if process.isRunning {
            process.terminate()
        }
        if pid > 0 {
            cleanup.untrack(pid)
        }
    }

    private func presentCurrentFailure() {
        let message: String
        switch status {
        case .unavailable(let detail), .failed(let detail):
            message = detail
        default:
            return
        }
        let alert = NSAlert()
        alert.messageText = "Real Goose Electron fallback unavailable"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func closeInputPipe() {
        guard let inputPipe else { return }
        try? inputPipe.fileHandleForWriting.close()
        self.inputPipe = nil
    }

    nonisolated static func launchArguments() -> [String] {
        ["--filter", "goose-app", "run", "start-gui"]
    }

    nonisolated static func boundedStatusMessage(
        _ message: String,
        fallback: String = "Real Goose Electron fallback failed."
    ) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxStatusMessageCharacters else { return value }
        return String(value.prefix(maxStatusMessageCharacters))
    }

    nonisolated static func resolveWorkspace(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        homeDirectory: String = NSHomeDirectory()
    ) -> GooseElectronFallbackWorkspace? {
        if let explicitUIRoot = nonEmptyPath(environment[uiRootEnvironmentKey]) {
            let uiRoot = URL(fileURLWithPath: explicitUIRoot, isDirectory: true)
            let repoRoot = uiRoot.deletingLastPathComponent()
            let pnpm = explicitPNPM(environment: environment, repoRoot: repoRoot)
            return validWorkspace(repoRoot: repoRoot, uiRoot: uiRoot, pnpm: pnpm)
        }

        // review HIGH-1 (code-execution-from-cwd): the CWD-relative + dev-checkout candidates below
        // resolve a `bin/pnpm` that run() then EXECUTES. An attacker-influenced working directory
        // containing `.research-clones/work/goose/{ui,desktop,bin/pnpm}` would otherwise make a
        // shipped (non-DEBUG) Developer-ID/Pro build exec the attacker's pnpm in Epistemos's TCC
        // context. Gate them to DEBUG only — mirroring GooseRuntimeSupervisor.gooseBinaryCandidates
        // and GooseWebUIResolver.candidateIndexURLs. The explicit EPISTEMOS_GOOSE_ELECTRON_UI_ROOT
        // override (handled above) stays available in every configuration for opt-in dev use.
        #if DEBUG
        let currentRoot = URL(fileURLWithPath: currentDirectory, isDirectory: true)
        let candidates = [
            currentRoot.appendingPathComponent(".research-clones/work/goose", isDirectory: true),
            URL(fileURLWithPath: homeDirectory, isDirectory: true)
                .appendingPathComponent("Downloads/Epistemos/.research-clones/work/goose", isDirectory: true),
        ]
        #else
        let candidates: [URL] = []
        #endif
        for repoRoot in candidates {
            let uiRoot = repoRoot.appendingPathComponent("ui", isDirectory: true)
            let pnpm = explicitPNPM(environment: environment, repoRoot: repoRoot)
            if let workspace = validWorkspace(repoRoot: repoRoot, uiRoot: uiRoot, pnpm: pnpm) {
                return workspace
            }
        }
        return nil
    }

    nonisolated static func processEnvironment(
        workspace: GooseElectronFallbackWorkspace,
        debugPort: Int? = nil,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env = base.filter { key, _ in
            environmentAllowlist.contains(key) && !environmentDenylist.contains(key)
        }
        env["ELECTRON_IS_DEV"] = "1"
        env["NODE_ENV"] = "development"
        // No GOOSE_ALLOWLIST_BYPASS. Goose fetches its command allowlist from the URL
        // in GOOSE_ALLOWLIST, which is NOT in environmentAllowlist and is therefore
        // never forwarded to the child — so the launched Goose enforces no allowlist
        // and a bypass flag would be a misleading no-op (it reads as "security guard
        // disabled" while disabling nothing). Omitting it also means that if
        // GOOSE_ALLOWLIST is ever forwarded, the child enforces it (the secure default).
        env["RUST_LOG"] = "info"
        env["HERMIT_ENV"] = workspace.repoRoot.path
        if let debugPort, isValidDebugPort(debugPort) {
            env["ENABLE_PLAYWRIGHT"] = "true"
            env["PLAYWRIGHT_DEBUG_PORT"] = String(debugPort)
        }

        let binDir = workspace.pnpm.deletingLastPathComponent().path
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = existingPath.isEmpty ? binDir : "\(binDir):\(existingPath)"
        return env
    }

    nonisolated static func debugPortFromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Int? {
        guard let raw = environment[debugPortEnvironmentKey],
              let port = Int(raw),
              isValidDebugPort(port) else {
            return nil
        }
        return port
    }

    nonisolated static func isValidDebugPort(_ port: Int) -> Bool {
        port > 1024 && port <= 65535
    }

    nonisolated private static func explicitPNPM(
        environment: [String: String],
        repoRoot: URL
    ) -> URL {
        if let explicit = nonEmptyPath(environment[pnpmEnvironmentKey]) {
            return URL(fileURLWithPath: explicit)
        }
        return repoRoot.appendingPathComponent("bin/pnpm")
    }

    nonisolated private static func validWorkspace(
        repoRoot: URL,
        uiRoot: URL,
        pnpm: URL
    ) -> GooseElectronFallbackWorkspace? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: uiRoot.appendingPathComponent("package.json").path),
              fm.fileExists(atPath: uiRoot.appendingPathComponent("desktop/package.json").path),
              fm.isExecutableFile(atPath: pnpm.path) else {
            return nil
        }
        return GooseElectronFallbackWorkspace(repoRoot: repoRoot, uiRoot: uiRoot, pnpm: pnpm)
    }

    nonisolated private static func nonEmptyPath(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
#else
@MainActor
final class GooseElectronFallbackLauncher {
    static let shared = GooseElectronFallbackLauncher()

    func launchFromMenu() {}
}
#endif
