import Foundation
import os

// MARK: - Hermes Setup Service
//
// First-launch setup coordinator for the agent runtime.
// Discovers Python 3.11+, creates a virtual environment at ~/.hermes/.venv/,
// installs hermes-agent dependencies, and verifies the runtime is functional.
//
// Used by SetupAssistantView during onboarding and by Settings for repair.

/// Observable setup state for UI binding.
enum HermesSetupState: Sendable, Equatable {
    case idle
    case checkingPython
    case creatingVenv
    case installingDeps
    case verifying
    case ready
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .ready, .failed: return true
        default: return false
        }
    }

    var displayMessage: String {
        switch self {
        case .idle: return "Waiting to start..."
        case .checkingPython: return "Looking for Python 3.11+..."
        case .creatingVenv: return "Creating virtual environment..."
        case .installingDeps: return "Installing agent dependencies..."
        case .verifying: return "Verifying agent runtime..."
        case .ready: return "Agent runtime is ready."
        case .failed(let reason): return "Setup failed: \(reason)"
        }
    }
}

/// Setup coordinator for the Hermes agent Python runtime.
/// Call `runSetup()` to perform the full installation sequence,
/// or `checkOnly()` to quickly verify without installing.
@MainActor @Observable
final class HermesSetupService {
    private static let log = Logger(subsystem: "com.epistemos", category: "HermesSetup")

    /// Current setup state — drives the UI.
    private(set) var state: HermesSetupState = .idle

    /// Detail message for current phase (e.g., package names being installed).
    private(set) var detailMessage: String = ""

    /// Discovered Python path (set during checkingPython phase).
    private(set) var pythonPath: String?

    /// Discovered Python version string.
    private(set) var pythonVersion: String?

    /// Whether the agent runtime was already set up (venv exists and healthy).
    private(set) var wasAlreadySetUp: Bool = false

    /// The venv location.
    private let venvDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".hermes/.venv")
    }()

    // MARK: - Quick Check

    /// Fast health check — returns true if the agent runtime is ready.
    /// Does NOT install anything.
    func checkOnly() async -> Bool {
        let result = await HermesSubprocessManager.healthCheck(forceRefresh: true)
        return result.isHealthy
    }

    // MARK: - Full Setup

    /// Run the complete setup sequence: discover Python, create venv, install deps, verify.
    /// Updates `state` at each phase for UI observation.
    func runSetup() async {
        Self.log.info("Starting Hermes agent runtime setup")

        // Quick check — maybe everything is already fine
        state = .verifying
        detailMessage = "Checking existing installation..."
        let existingHealth = await HermesSubprocessManager.healthCheck(forceRefresh: true)
        if existingHealth.isHealthy {
            Self.log.info("Agent runtime already healthy, skipping setup")
            wasAlreadySetUp = true
            pythonVersion = existingHealth.pythonVersion
            state = .ready
            return
        }

        // Phase 1: Find Python 3.11+
        state = .checkingPython
        detailMessage = ""

        guard let python = await discoverPython() else {
            state = .failed("Python 3.11 or later not found. Install Python via Homebrew: brew install python@3.12")
            return
        }
        pythonPath = python

        // Phase 2: Create venv
        state = .creatingVenv
        detailMessage = venvDir.path

        let venvOk = await createVenv(pythonPath: python)
        guard venvOk else {
            state = .failed("Failed to create virtual environment at \(venvDir.path)")
            return
        }

        // Phase 3: Install dependencies
        state = .installingDeps
        detailMessage = "This may take a minute..."

        let depsOk = await installDependencies()
        guard depsOk else {
            state = .failed("Failed to install Python dependencies. Check your internet connection.")
            return
        }

        // Phase 4: Verify
        state = .verifying
        detailMessage = "Running health check..."

        // Clear cached health result and re-check
        let health = await HermesSubprocessManager.healthCheck(forceRefresh: true)
        if health.isHealthy {
            pythonVersion = health.pythonVersion
            state = .ready
            Self.log.info("Hermes agent runtime setup complete")
        } else {
            let reason = health.errorDetail ?? "Unknown verification failure"
            state = .failed(reason)
            Self.log.error("Setup verification failed: \(reason)")
        }
    }

    // MARK: - Python Discovery

    /// Find a suitable Python 3.11+ on the system.
    /// Returns the path to the Python executable, or nil if none found.
    private func discoverPython() async -> String? {
        // System Python candidates (same order as HermesSubprocessManager)
        let candidates = [
            "/opt/homebrew/bin/python3.13",
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/bin/python3.11",
            "/usr/local/bin/python3.13",
            "/usr/local/bin/python3.12",
            "/usr/local/bin/python3.11",
        ]

        let fm = FileManager.default
        for candidate in candidates {
            guard fm.isExecutableFile(atPath: candidate) else { continue }

            // Verify it's actually 3.11+
            let version = await runProcess(candidate, arguments: ["--version"])
            guard let versionStr = version?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }

            detailMessage = "Found: \(versionStr) at \(candidate)"
            Self.log.info("Found Python: \(versionStr) at \(candidate)")
            pythonVersion = versionStr
            return candidate
        }

        // Last resort: system python — check if it's 3.11+
        let systemPython = "/usr/bin/python3"
        if fm.isExecutableFile(atPath: systemPython) {
            let version = await runProcess(systemPython, arguments: ["--version"])
            if let versionStr = version?.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
               isVersion311OrLater(versionStr) {
                detailMessage = "Found: \(versionStr) (system)"
                pythonVersion = versionStr
                return systemPython
            }
        }

        return nil
    }

    private nonisolated func isVersion311OrLater(_ versionString: String) -> Bool {
        // Parse "Python 3.X.Y"
        let components = versionString.replacingOccurrences(of: "Python ", with: "").split(separator: ".")
        guard components.count >= 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else { return false }
        return major > 3 || (major == 3 && minor >= 11)
    }

    // MARK: - Venv Creation

    private func createVenv(pythonPath: String) async -> Bool {
        // Create parent directory
        let parentDir = venvDir.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        } catch {
            Self.log.error("Failed to create .hermes directory: \(error.localizedDescription)")
            return false
        }

        // Remove existing broken venv if present
        if FileManager.default.fileExists(atPath: venvDir.path) {
            do {
                try FileManager.default.removeItem(at: venvDir)
            } catch {
                Self.log.error("Failed to remove existing venv: \(error.localizedDescription)")
                return false
            }
        }

        let result = await runProcess(pythonPath, arguments: ["-m", "venv", venvDir.path])
        guard let result, result.exitCode == 0 else {
            if result?.timedOut == true {
                Self.log.error("venv creation timed out")
                detailMessage = "venv creation timed out"
                return false
            }
            let stderr = result?.stderr ?? "unknown error"
            Self.log.error("venv creation failed: \(stderr)")
            detailMessage = "venv creation failed"
            return false
        }

        // Upgrade pip
        let pipPath = venvDir.appendingPathComponent("bin/pip").path
        let upgradeResult = await runProcess(pipPath, arguments: ["install", "--upgrade", "pip"])
        if upgradeResult?.exitCode != 0 {
            Self.log.warning("pip upgrade failed (non-fatal)")
        }

        detailMessage = "Virtual environment created"
        return true
    }

    // MARK: - Dependency Installation

    private func installDependencies() async -> Bool {
        let pipPath = venvDir.appendingPathComponent("bin/pip").path
        guard FileManager.default.isExecutableFile(atPath: pipPath) else {
            Self.log.error("pip not found at \(pipPath)")
            return false
        }

        // Find requirements.txt — check hermes-agent directory first, then bundle
        guard let requirementsPath = findRequirementsFile() else {
            Self.log.error("requirements.txt not found")
            detailMessage = "requirements.txt not found"
            return false
        }

        Self.log.info("Installing from \(requirementsPath)")
        detailMessage = "Installing packages..."

        let result = await runProcess(
            pipPath,
            arguments: ["install", "-r", requirementsPath],
            timeout: 300 // 5 minutes for slow connections
        )

        guard let result else {
            detailMessage = "Installation timed out"
            return false
        }
        guard !result.timedOut else {
            detailMessage = "Installation timed out"
            return false
        }

        if result.exitCode == 0 {
            // Count installed packages
            let lines = result.stdout.components(separatedBy: "\n")
            let installed = lines.filter { $0.contains("Successfully installed") }
            detailMessage = installed.first ?? "Dependencies installed"
            return true
        } else {
            let lastLines = result.stderr.components(separatedBy: "\n").suffix(3).joined(separator: "\n")
            Self.log.error("pip install failed: \(lastLines)")
            detailMessage = "Installation error"
            return false
        }
    }

    /// Search for requirements.txt in known locations.
    private func findRequirementsFile() -> String? {
        let fm = FileManager.default

        // 1. hermes-agent directory resolved by HermesSubprocessManager
        let config = HermesConfig.resolve()
        let hermesReqs = config.hermesAgentDir.appendingPathComponent("requirements.txt").path
        if fm.fileExists(atPath: hermesReqs) { return hermesReqs }

        // 2. Bundled in app resources
        if let bundled = Bundle.main.path(forResource: "requirements", ofType: "txt") {
            return bundled
        }

        // 3. Bundle resources subdirectory
        if let resourceURL = Bundle.main.resourceURL {
            let agentRuntime = resourceURL.appendingPathComponent("AgentRuntime/hermes-agent/requirements.txt")
            if fm.fileExists(atPath: agentRuntime.path) { return agentRuntime.path }
        }

        return nil
    }

    // MARK: - Process Runner

    private struct SimpleProcessResult: Sendable {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let timedOut: Bool
    }

    private final class ProcessOutputCapture: Sendable {
        private let lock = NSLock()
        nonisolated(unsafe) private var data = Data()

        nonisolated func append(_ chunk: Data) {
            guard !chunk.isEmpty else { return }
            lock.lock()
            defer { lock.unlock() }
            data.append(chunk)
        }

        nonisolated func consumeRemainder(from handle: FileHandle) {
            append(handle.readDataToEndOfFile())
        }

        nonisolated func stringValue() -> String {
            lock.lock()
            let snapshot = data
            lock.unlock()
            return String(data: snapshot, encoding: .utf8) ?? ""
        }
    }

    private final class ProcessTimeoutState: Sendable {
        private let lock = NSLock()
        nonisolated(unsafe) private var timedOut = false

        nonisolated func markTimedOut() {
            lock.lock()
            defer { lock.unlock() }
            timedOut = true
        }

        nonisolated func load() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return timedOut
        }
    }

    private nonisolated func runProcess(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval = 120
    ) async -> SimpleProcessResult? {
        let state = ProcessContinuationState<SimpleProcessResult?>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let process = Process.init()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    let stdoutCapture = ProcessOutputCapture()
                    let stderrCapture = ProcessOutputCapture()
                    let timeoutState = ProcessTimeoutState()
                    let stdoutHandle = stdoutPipe.fileHandleForReading
                    let stderrHandle = stderrPipe.fileHandleForReading

                    guard state.store(process: process, continuation: continuation) else {
                        continuation.resume(returning: nil)
                        return
                    }

                    stdoutHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty else {
                            handle.readabilityHandler = nil
                            return
                        }
                        stdoutCapture.append(data)
                    }
                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty else {
                            handle.readabilityHandler = nil
                            return
                        }
                        stderrCapture.append(data)
                    }

                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + timeout)
                    timer.setEventHandler {
                        timeoutState.markTimedOut()
                        process.terminate()
                    }
                    timer.resume()

                    process.terminationHandler = { proc in
                        stdoutHandle.readabilityHandler = nil
                        stderrHandle.readabilityHandler = nil
                        stdoutCapture.consumeRemainder(from: stdoutHandle)
                        stderrCapture.consumeRemainder(from: stderrHandle)
                        timer.cancel()

                        state.resume(returning: SimpleProcessResult(
                            exitCode: proc.terminationStatus,
                            stdout: stdoutCapture.stringValue(),
                            stderr: stderrCapture.stringValue(),
                            timedOut: timeoutState.load()
                        ))
                    }

                    do {
                        try process.run()
                    } catch {
                        stdoutHandle.readabilityHandler = nil
                        stderrHandle.readabilityHandler = nil
                        timer.cancel()
                        state.resume(returning: nil)
                    }
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(returning: nil)
        }
    }
}
