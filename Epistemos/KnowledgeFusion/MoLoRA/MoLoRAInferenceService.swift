import Foundation

// MARK: - Types

struct MoLoRAAdapterConfig: Codable, Sendable {
    let path: String
    let type: String       // "knowledge", "style", "tool"
    let rank: Int
    let alpha: Int
}

struct MoLoRAGenerationResult: Sendable {
    let tokensGenerated: Int
    let tokensPerSecond: Double
    let routeUsed: String
}

private final class MoLoRAReadBufferState: Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var value = ""

    nonisolated init() {}

    nonisolated func reset() {
        lock.lock()
        defer { lock.unlock() }
        value = ""
    }

    nonisolated func popLine() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let newlineIndex = value.firstIndex(of: "\n") else { return nil }
        let line = String(value[value.startIndex..<newlineIndex])
        value = String(value[value.index(after: newlineIndex)...])
        return line
    }

    nonisolated func appendAndPopLine(_ chunk: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        value += chunk
        guard let newlineIndex = value.firstIndex(of: "\n") else { return nil }
        let line = String(value[value.startIndex..<newlineIndex])
        value = String(value[value.index(after: newlineIndex)...])
        return line
    }
}

// MARK: - MoLoRA Inference Service

/// Manages a long-lived Python subprocess running molora_inference.py.
/// Communicates via stdin/stdout JSON lines (same pattern as QLoRATrainer).
///
/// CRITICAL: Adapters are NEVER fused into base weights.
/// The Python side loads adapters separately and routes per-token.
@MainActor @Observable
final class MoLoRAInferenceService {

    enum State: Equatable {
        case idle
        case loading
        case ready
        case generating
        case error(String)
    }

    private(set) var state: State = .idle
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let readBufferState = MoLoRAReadBufferState()

    // MARK: - Lifecycle

    /// Launch the MoLoRA inference subprocess.
    /// Waits for the "ready" signal before returning.
    func start(
        modelPath: URL,
        adapterConfigs: [MoLoRAAdapterConfig],
        centroidsPath: URL?
    ) async throws {
        guard state == .idle || state == .error("") || true else { return }

        // Stop any existing process
        stop()

        state = .loading

        let pyEnv = PythonEnvironmentManager.shared
        let pythonPath = pyEnv.isReady ? pyEnv.pythonPath : "/usr/bin/python3"

        // Find the inference script
        let scriptPath = Self.findScript("molora_inference.py")
        guard let scriptPath else {
            state = .error("molora_inference.py not found")
            return
        }

        // Build adapter configs JSON
        let encoder = JSONEncoder()
        let adaptersData = try encoder.encode(adapterConfigs)
        let adaptersJson = String(data: adaptersData, encoding: .utf8) ?? "[]"

        var arguments = [
            scriptPath.path,
            "--model_path", modelPath.path,
            "--adapters_json", adaptersJson,
        ]
        if let centroids = centroidsPath, FileManager.default.fileExists(atPath: centroids.path) {
            arguments.append(contentsOf: ["--centroids_path", centroids.path])
        }

        #if !EPISTEMOS_APP_STORE
        let proc = Process.init()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = arguments

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr

        do {
            try proc.run()
        } catch {
            state = .error("Failed to launch: \(error.localizedDescription)")
            return
        }

        // Wait for "ready" signal (with timeout)
        let ready = await waitForReady(timeout: 60)
        if ready {
            state = .ready
        } else {
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: stderrData, encoding: .utf8)?.prefix(500) ?? "Timeout waiting for model load"
            state = .error(String(errorMsg))
            stop()
        }
        #else
        // The App Store sandbox cannot spawn /usr/bin/python3 to run
        // the MoLoRA inference script. Pro/direct release keeps the
        // routing path; AppBootstrap and SettingsView already gate
        // the KnowledgeFusion entry points out of MAS, so this
        // surgical body gate is defense-in-depth. The state machine
        // settles into .error so any caller that bypasses the entry-
        // point gates fails honestly without spawning a process.
        _ = arguments
        _ = pythonPath
        state = .error("MoLoRA inference is not available in the App Store sandbox build.")
        #endif
    }

    /// Stop the inference subprocess.
    func stop() {
        if let proc = process, proc.isRunning {
            sendCommand(["type": "shutdown"])
            // Give it a moment to exit gracefully
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if proc.isRunning { proc.terminate() }
            }
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        readBufferState.reset()
        state = .idle
    }

    // MARK: - Generation

    /// Generate text with per-token MoLoRA routing.
    /// Calls onToken for each generated token (for streaming UI).
    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 512,
        onToken: @Sendable (String) -> Void
    ) async throws -> MoLoRAGenerationResult {
        guard state == .ready else {
            throw MoLoRAError.notReady
        }

        state = .generating

        var cmd: [String: Any] = [
            "type": "generate",
            "prompt": prompt,
            "max_tokens": maxTokens,
        ]
        if let sys = systemPrompt {
            cmd["system_prompt"] = sys
        }

        sendCommand(cmd)

        // Read token-by-token from stdout
        var tokensGenerated = 0
        var tokensPerSecond = 0.0
        var routeUsed = "base"

        while let line = await readLine() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                continue
            }

            switch type {
            case "token":
                if let text = json["text"] as? String {
                    onToken(text)
                    tokensGenerated += 1
                }
            case "done":
                tokensGenerated = json["tokens_generated"] as? Int ?? tokensGenerated
                tokensPerSecond = json["tok_per_sec"] as? Double ?? 0
                routeUsed = json["route"] as? String ?? "base"
                state = .ready
                return MoLoRAGenerationResult(
                    tokensGenerated: tokensGenerated,
                    tokensPerSecond: tokensPerSecond,
                    routeUsed: routeUsed
                )
            case "error":
                let msg = json["message"] as? String ?? "Unknown error"
                state = .ready
                throw MoLoRAError.generationFailed(msg)
            default:
                break
            }
        }

        state = .ready
        return MoLoRAGenerationResult(
            tokensGenerated: tokensGenerated,
            tokensPerSecond: tokensPerSecond,
            routeUsed: routeUsed
        )
    }

    /// Reload adapters without restarting the base model.
    func reloadAdapters(_ configs: [MoLoRAAdapterConfig]) async throws {
        guard state == .ready else { throw MoLoRAError.notReady }

        let encoder = JSONEncoder()
        let adaptersData = try encoder.encode(configs)
        let adaptersArray = try JSONSerialization.jsonObject(with: adaptersData)

        sendCommand([
            "type": "reload_adapters",
            "adapters": adaptersArray,
        ])

        let ready = await waitForReady(timeout: 30)
        if !ready {
            throw MoLoRAError.reloadFailed
        }
    }

    // MARK: - Internal

    private func sendCommand(_ dict: [String: Any]) {
        guard let stdin = stdinPipe?.fileHandleForWriting else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              var str = String(data: data, encoding: .utf8) else { return }
        str += "\n"
        stdin.write(Data(str.utf8))
    }

    private func readLine() async -> String? {
        guard let stdout = stdoutPipe?.fileHandleForReading else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                // Check if we have a complete line in the buffer
                if let line = self.readBufferState.popLine() {
                    continuation.resume(returning: line)
                    return
                }

                // Read more data
                let data = stdout.availableData
                guard !data.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let chunk = String(data: data, encoding: .utf8) ?? ""
                if let line = self.readBufferState.appendAndPopLine(chunk) {
                    continuation.resume(returning: line)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func waitForReady(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let line = await readLine() {
                if line.contains("\"ready\"") {
                    return true
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private static func findScript(_ name: String) -> URL? {
        // Dev: source tree
        let sourceTree = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: sourceTree.path) {
            return sourceTree
        }

        // Deployed scripts directory
        let deployed = PythonEnvironmentManager.shared.scriptsDirectory
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: deployed.path) {
            return deployed
        }

        // Bundle
        let bundle = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/KnowledgeFusion/MoLoRA/\(name)")
        if FileManager.default.fileExists(atPath: bundle.path) {
            return bundle
        }

        return nil
    }
}

// MARK: - Errors

enum MoLoRAError: Error, LocalizedError {
    case notReady
    case generationFailed(String)
    case reloadFailed

    var errorDescription: String? {
        switch self {
        case .notReady: return "MoLoRA inference service not ready"
        case .generationFailed(let msg): return "MoLoRA generation failed: \(msg)"
        case .reloadFailed: return "Failed to reload adapters"
        }
    }
}
