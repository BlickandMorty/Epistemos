import Foundation
import OSLog

// MARK: - PythonEnvironmentManager

/// Manages an isolated Python virtual environment for Knowledge Fusion training.
/// On first use, creates a venv in Application Support and installs mlx dependencies.
/// v1 uses an existing local Python toolchain; it never bootstraps package managers
/// or downloads executable installers from inside the app.
@MainActor @Observable
final class PythonEnvironmentManager {

    static let shared = PythonEnvironmentManager()
    private static let log = Logger(subsystem: "com.epistemos", category: "PythonEnvironment")

    // MARK: - State

    enum SetupState: Equatable {
        case unknown
        case ready
        case settingUp(phase: String, progress: Double)
        case failed(error: String)
    }

    var state: SetupState = .unknown

    /// Path to the venv's python3 binary. Use this for all subprocess invocations.
    var pythonPath: String {
        venvBinDir.appendingPathComponent("python3").path
    }

    /// Path to the venv's pip binary.
    var pipPath: String {
        venvBinDir.appendingPathComponent("pip3").path
    }

    /// Whether the environment is ready for training.
    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    // MARK: - Paths

    private var baseDir: URL {
        FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos/python-env")
    }

    private var venvDir: URL { baseDir.appendingPathComponent("venv") }
    private var venvBinDir: URL { venvDir.appendingPathComponent("bin") }
    private var markerFile: URL { baseDir.appendingPathComponent(".setup-complete") }

    /// Directory containing deployed training scripts.
    var scriptsDirectory: URL {
        FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos/training-scripts")
    }

    /// Required packages for Knowledge Fusion training.
    private let requiredPackages = ["mlx", "mlx-lm"]
    /// Optional packages (installed if possible, won't fail setup).
    private let optionalPackages = ["mlx-whisper"]

    // MARK: - Public API

    /// Check if the environment is already set up. Fast — just checks marker file.
    func checkExisting() {
        let fm = FileManager.default
        if fm.fileExists(atPath: markerFile.path),
           fm.isExecutableFile(atPath: pythonPath) {
            // Verify mlx is importable
            state = .ready
        } else {
            state = .unknown
        }
    }

    /// Deploy training scripts to Application Support so they're available at runtime.
    /// Copies from the source tree (for dev builds) or bundle resources.
    func deployScripts() throws {
        let fm = FileManager.default
        let destDir = scriptsDirectory
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Source locations to try (dev source tree first, then bundle)
        let sourceLocations: [URL] = [
            // Dev: source tree relative to project root
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // KnowledgeFusion/
                .appendingPathComponent("Training/scripts"),
            // Bundle: copied resources
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/KnowledgeFusion/Training/scripts"),
            Bundle.main.resourceURL?
                .appendingPathComponent("training-scripts") ?? destDir
        ]

        var foundSource: URL?
        for source in sourceLocations {
            if fm.fileExists(atPath: source.appendingPathComponent("train_knowledge.py").path) {
                foundSource = source
                break
            }
        }

        guard let source = foundSource else { return }

        // Copy each .py script
        let scripts: [URL]
        do {
            scripts = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        } catch {
            Self.log.error(
                "Failed to read training scripts at \(source.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
        for script in scripts where script.pathExtension == "py" {
            let dest = destDir.appendingPathComponent(script.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: script, to: dest)
        }
    }

    /// Full setup: create venv, install dependencies. Shows progress via `state`.
    /// Safe to call if already set up — will skip quickly.
    func ensureReady() async {
        if case .ready = state { return }

        let fm = FileManager.default

        // Quick check: already done?
        if fm.fileExists(atPath: markerFile.path),
           fm.isExecutableFile(atPath: pythonPath) {
            // Verify mlx actually imports
            if await verifyMLXImport() {
                state = .ready
                return
            }
            // Marker exists but broken — nuke and redo setup
            try? fm.removeItem(at: venvDir)
            try? fm.removeItem(at: markerFile)
        }

        do {
            // Step 1: Ensure Python 3.10+ is available (mlx requires it)
            state = .settingUp(phase: "Checking local Python 3.10+ toolchain...", progress: 0.08)
            let systemPython = try await ensureModernPython()

            #if !EPISTEMOS_APP_STORE
            // Step 2: Create isolated virtual environment
            state = .settingUp(phase: "Creating isolated training environment...", progress: 0.15)
            try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
            try await runProcess(
                executable: systemPython,
                arguments: ["-m", "venv", venvDir.path, "--clear"]
            )

            guard fm.isExecutableFile(atPath: pythonPath) else {
                state = .failed(error: "Failed to create Python virtual environment.")
                return
            }

            // Step 3: Upgrade pip (package installer)
            state = .settingUp(phase: "Upgrading pip (package installer)...", progress: 0.22)
            try await runProcess(
                executable: pythonPath,
                arguments: [
                    "-m",
                    "pip",
                    "install",
                    "--disable-pip-version-check",
                    "--no-input",
                    "--upgrade",
                    "pip"
                ]
            )

            // Step 4: Install required ML packages
            let descriptions: [String: String] = [
                "mlx": "Apple's ML framework for Apple Silicon",
                "mlx-lm": "Language model training and inference on MLX",
                "mlx-whisper": "On-device speech transcription (optional)"
            ]

            let totalPackages = Double(requiredPackages.count + optionalPackages.count)
            for (index, package) in requiredPackages.enumerated() {
                let progress = 0.30 + (Double(index) / totalPackages) * 0.55
                let desc = descriptions[package] ?? package
                state = .settingUp(phase: "Installing \(package) — \(desc)...", progress: progress)
                try await runProcess(
                    executable: pipPath,
                    arguments: ["install", "--disable-pip-version-check", "--no-input", package]
                )
            }

            // Step 5: Install optional packages (don't fail on these)
            for (index, package) in optionalPackages.enumerated() {
                let progress = 0.30 + (Double(requiredPackages.count + index) / totalPackages) * 0.55
                let desc = descriptions[package] ?? package
                state = .settingUp(phase: "Installing \(package) — \(desc)...", progress: progress)
                do {
                    try await runProcess(
                        executable: pipPath,
                        arguments: ["install", "--disable-pip-version-check", "--no-input", package]
                    )
                } catch {
                    // Optional — continue without it
                }
            }

            // Step 6: Deploy training scripts
            state = .settingUp(phase: "Deploying training scripts...", progress: 0.90)
            try deployScripts()

            // Step 7: Verify everything works
            state = .settingUp(phase: "Verifying ML framework...", progress: 0.95)
            guard await verifyMLXImport() else {
                state = .failed(error: "mlx installed but failed to import. Your Mac may need Python 3.10+ with Apple Silicon support.")
                return
            }

            // Write marker
            try Data("ok".utf8).write(to: markerFile, options: .atomic)
            state = .ready
            #else
            // The App Store sandbox cannot create venvs, run pip,
            // install ML packages, deploy training scripts, or run
            // mlx import verification. The Python probe above already
            // throws PythonEnvError.noPythonFound under MAS, so this branch
            // is defense-in-depth: it removes the pip/venv install
            // launch argv strings (`-m venv`, `-m pip install
            // --upgrade pip`, `install <package>`) from MAS-visible
            // source so review tooling that scans for them does not
            // flag the binary. Script deploy, verification, and marker
            // writes are also gated so MAS has no compiled code after
            // this `return`.
            _ = systemPython
            _ = fm
            state = .failed(error: "Python environment management is not available in the App Store sandbox build.")
            return
            #endif

        } catch {
            state = .failed(error: error.localizedDescription)
        }
    }

    /// Remove the entire venv (for reset or re-setup).
    func tearDown() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: baseDir.path) {
            try fm.removeItem(at: baseDir)
        }
        state = .unknown
    }

    // MARK: - Internals

    /// Ensure Python 3.10+ is available from a local, already-installed toolchain.
    private func ensureModernPython() async throws -> String {
        #if EPISTEMOS_APP_STORE
        throw PythonEnvError.noPythonFound
        #else
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/opt/python@3.12/bin/python3.12",
            "/opt/homebrew/opt/python@3.13/bin/python3.13",
            "/opt/homebrew/opt/python@3.11/bin/python3.11",
            "/usr/local/opt/python@3.12/bin/python3.12",
            "/usr/local/opt/python@3.13/bin/python3.13",
            "/usr/local/opt/python@3.11/bin/python3.11",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
            "/usr/bin/python3"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                // Verify version is 3.10+
                if let version = try? await runProcessCapture(executable: path, arguments: ["--version"]) {
                    // "Python 3.12.13" → extract minor version
                    let parts = version.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "Python ", with: "")
                        .split(separator: ".")
                    if parts.count >= 2, let minor = Int(parts[1]), minor >= 10 {
                        return path
                    }
                }
            }
        }

        throw PythonEnvError.noPythonFound
        #endif
    }

    private func findSystemPython() async throws -> String {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/bin/python3.11",
            "/opt/homebrew/bin/python3.13",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Last resort — system python3 (may be Xcode's 3.9, will warn)
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") {
            return "/usr/bin/python3"
        }

        throw PythonEnvError.noPythonFound
    }

    private func verifyMLXImport() async -> Bool {
        do {
            let output = try await runProcessCapture(
                executable: pythonPath,
                arguments: ["-c", "import mlx; import mlx_lm; print('OK')"]
            )
            return output.contains("OK")
        } catch {
            return false
        }
    }

    @discardableResult
    private func runProcess(executable: String, arguments: [String]) async throws -> Int32 {
        let execution = try await executeProcess(
            executable: executable,
            arguments: arguments,
            captureStdout: false,
            captureStderr: true
        )

        guard execution.terminationStatus == 0 else {
            let stderrText = execution.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let cmd = ([executable] + arguments).joined(separator: " ")
            let detail = stderrText.isEmpty ? cmd : "\(cmd)\n\(stderrText.prefix(500))"
            throw PythonEnvError.processExitCode(execution.terminationStatus, detail: detail)
        }

        return execution.terminationStatus
    }

    private func runProcessCapture(executable: String, arguments: [String]) async throws -> String {
        let execution = try await executeProcess(
            executable: executable,
            arguments: arguments,
            captureStdout: true,
            captureStderr: false
        )
        guard execution.terminationStatus == 0 else {
            let cmd = ([executable] + arguments).joined(separator: " ")
            throw PythonEnvError.processExitCode(execution.terminationStatus, detail: cmd)
        }
        return execution.stdout
    }

    private nonisolated func executeProcess(
        executable: String,
        arguments: [String],
        captureStdout: Bool,
        captureStderr: Bool
    ) async throws -> PythonProcessExecution {
        #if !EPISTEMOS_APP_STORE
        let timeoutSeconds = 120.0
        let state = ThrowingProcessContinuationState<PythonProcessExecution>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let process = Process.init()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    process.environment = Self.pythonToolEnvironment(executable: executable)

                    let stdoutPipe = captureStdout ? Pipe() : nil
                    let stderrPipe = captureStderr ? Pipe() : nil
                    process.standardOutput = stdoutPipe ?? FileHandle.nullDevice
                    process.standardError = stderrPipe ?? FileHandle.nullDevice

                    let stdoutCapture = KnowledgeFusionProcessOutputCapture()
                    let stderrCapture = KnowledgeFusionProcessOutputCapture()
                    let stdoutHandle = stdoutPipe?.fileHandleForReading
                    let stderrHandle = stderrPipe?.fileHandleForReading

                    stdoutHandle?.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty else {
                            handle.readabilityHandler = nil
                            return
                        }
                        stdoutCapture.append(data)
                    }
                    stderrHandle?.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty else {
                            handle.readabilityHandler = nil
                            return
                        }
                        stderrCapture.append(data)
                    }

                    guard state.store(process: process, continuation: continuation) else {
                        stdoutHandle?.readabilityHandler = nil
                        stderrHandle?.readabilityHandler = nil
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    let timeoutTask = Task.detached(priority: .utility) {
                        do {
                            try await Task.sleep(for: .seconds(timeoutSeconds))
                        } catch is CancellationError {
                            return
                        } catch {
                            return
                        }
                        state.terminate()
                        state.resume(throwing: TimeoutError(seconds: timeoutSeconds))
                    }

                    process.terminationHandler = { proc in
                        timeoutTask.cancel()
                        stdoutHandle?.readabilityHandler = nil
                        stderrHandle?.readabilityHandler = nil
                        if let stdoutHandle {
                            stdoutCapture.consumeRemainder(from: stdoutHandle)
                        }
                        if let stderrHandle {
                            stderrCapture.consumeRemainder(from: stderrHandle)
                        }

                        state.resume(returning: PythonProcessExecution(
                            terminationStatus: proc.terminationStatus,
                            stdout: stdoutCapture.stringValue(),
                            stderr: stderrCapture.stringValue()
                        ))
                    }

                    do {
                        try process.run()
                    } catch {
                        timeoutTask.cancel()
                        stdoutHandle?.readabilityHandler = nil
                        stderrHandle?.readabilityHandler = nil
                        state.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(throwing: CancellationError())
        }
        #else
        // The App Store sandbox cannot spawn arbitrary executables
        // (python, pip, etc.). Pro/direct
        // release keeps the full Python environment bootstrapper;
        // AppBootstrap and SettingsView already gate the
        // KnowledgeFusion entry points out of MAS, so this surgical
        // body gate is defense-in-depth. Throwing an unavailable
        // error keeps any bypassing caller honest -- they will see
        // a clean failure instead of a sandbox-blocked partial spawn.
        _ = executable
        _ = arguments
        _ = captureStdout
        _ = captureStderr
        throw PythonEnvError.processExitCode(
            -1,
            detail: "Python environment management is not available in the App Store sandbox build."
        )
        #endif
    }

    nonisolated static func boundedToolEnvironment(executable: String) -> [String: String] {
        let executableURL = URL(fileURLWithPath: executable)
        let executableDirectory = executableURL.deletingLastPathComponent().path
        let basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let resolvedPath = executableDirectory.isEmpty
            ? basePath
            : "\(executableDirectory):\(basePath)"

        return [
            "PATH": resolvedPath,
            "LANG": "en_US.UTF-8",
            "LC_ALL": "en_US.UTF-8",
            "HOME": NSHomeDirectory(),
            "TMPDIR": NSTemporaryDirectory()
        ]
    }

    nonisolated static func pythonToolEnvironment(executable: String) -> [String: String] {
        let executableURL = URL(fileURLWithPath: executable)
        var environment = boundedToolEnvironment(executable: executable)
        environment["PYTHONNOUSERSITE"] = "1"
        environment["PIP_DISABLE_PIP_VERSION_CHECK"] = "1"
        environment["PIP_NO_INPUT"] = "1"

        let maybeVenv = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if executableURL.deletingLastPathComponent().lastPathComponent == "bin",
           FileManager.default.fileExists(atPath: maybeVenv.appendingPathComponent("pyvenv.cfg").path) {
            environment["VIRTUAL_ENV"] = maybeVenv.path
        }

        return environment
    }

    nonisolated static func sanitizedProcessOutput(_ output: String, maxCharacters: Int = 4_000) -> String {
        let sensitiveNeedles = [
            "api_key",
            "apikey",
            "authorization",
            "bearer ",
            "password",
            "secret",
            "token"
        ]
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let lower = line.lowercased()
            if sensitiveNeedles.contains(where: { lower.contains($0) }) {
                return "[redacted sensitive diagnostic line]"
            }
            return String(line)
        }
        var sanitized = lines.joined(separator: "\n")
        if sanitized.count > maxCharacters {
            sanitized = String(sanitized.prefix(maxCharacters)) + "\n[diagnostic output truncated]"
        }
        return sanitized.isEmpty ? "No diagnostic output." : sanitized
    }
}

private struct PythonProcessExecution: Sendable {
    let terminationStatus: Int32
    let stdout: String
    let stderr: String
}

final class KnowledgeFusionProcessOutputCapture: Sendable {
    private let lock = NSLock()
    private let maxBytes: Int
    nonisolated(unsafe) private var data = Data()
    nonisolated(unsafe) private var truncated = false

    nonisolated init(maxBytes: Int = 64 * 1024) {
        self.maxBytes = max(1, maxBytes)
    }

    nonisolated func reset() {
        lock.lock()
        defer { lock.unlock() }
        data.removeAll(keepingCapacity: true)
        truncated = false
    }

    nonisolated func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        let remaining = maxBytes - data.count
        guard remaining > 0 else {
            truncated = true
            return
        }
        if chunk.count > remaining {
            data.append(contentsOf: chunk.prefix(remaining))
            truncated = true
        } else {
            data.append(chunk)
        }
    }

    nonisolated func consumeRemainder(from handle: FileHandle) {
        append(handle.readDataToEndOfFile())
    }

    nonisolated func stringValue() -> String {
        lock.lock()
        let snapshot = data
        let wasTruncated = truncated
        lock.unlock()
        var output = String(data: snapshot, encoding: .utf8) ?? ""
        if wasTruncated {
            output += "\n[diagnostic output truncated]"
        }
        return PythonEnvironmentManager.sanitizedProcessOutput(output)
    }
}

// MARK: - Errors

enum PythonEnvError: LocalizedError {
    case noPythonFound
    case processExitCode(Int32, detail: String)

    var errorDescription: String? {
        switch self {
        case .noPythonFound:
            return "Python 3.10 or newer not found. Install Python from python.org or Homebrew, then retry Knowledge Fusion setup."
        case .processExitCode(let code, let detail):
            return "Process exited with code \(code).\n\(detail)"
        }
    }
}
