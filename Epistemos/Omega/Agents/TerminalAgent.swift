import Foundation

// MARK: - Terminal Agent

/// Specialist agent for shell command execution.
///
/// Provides two execution modes:
/// - `run_command`: Ephemeral, restrictive allow-list. Goes through Rust Tool Layer
///   (omega-mcp osascript.rs tool_run_command) per Anti-Drift Anchor 1 and Anchor 5.
/// - `run_persistent`: Persistent PTY session via agent_core. Working directory,
///   env vars, and shell state persist between calls. Broader allow-list for
///   git/npm/cargo/xcodebuild workflows.
@MainActor
final class TerminalAgent: OmegaAgent, Sendable {
    let name = "terminal"
    let description = "Execute shell commands with allow-list restrictions (ephemeral or persistent PTY)"
    let toolNames = ["run_command", "run_persistent"]

    /// Comma-separated allow-list passed to Rust for ephemeral enforcement.
    private let defaultAllowedCommandsCsv: String

    /// PTY session ID for persistent mode, lazily spawned.
    private var ptyId: String?

    /// Broader allow-list for persistent PTY sessions.
    private let persistentAllowedCommands: Set<String> = [
        // Basic UNIX
        "ls", "cat", "head", "tail", "grep", "find", "wc", "echo", "date", "pwd", "which",
        "cd", "mkdir", "touch", "cp", "mv", "rm", "chmod", "chown",
        // Build tools
        "git", "npm", "npx", "yarn", "pnpm", "cargo", "rustc", "rustup",
        "swift", "swiftc", "xcodebuild", "xcrun", "xcodegen",
        "python3", "pip3", "pip", "python",
        "make", "cmake", "ninja",
        // Package managers
        "brew", "pod", "bundler", "ruby", "gem",
        // Utilities
        "curl", "wget", "tar", "unzip", "zip", "gzip",
        "diff", "sort", "uniq", "awk", "sed", "jq", "tr", "cut",
        "env", "export", "source", "which", "type", "file",
        "open", "pbcopy", "pbpaste", "defaults",
    ]

    init(allowedCommands: Set<String> = ["ls", "cat", "head", "tail", "grep", "find", "wc", "echo", "date", "pwd", "which"]) {
        self.defaultAllowedCommandsCsv = allowedCommands.sorted().joined(separator: ",")
    }

    /// Resolve the effective allow-list: Settings → Omega override, or init default.
    private var effectiveAllowedCommandsCsv: String {
        if let settingValue = UserDefaults.standard.string(forKey: "omega.terminalAllowList"),
           !settingValue.isEmpty {
            return settingValue
        }
        return defaultAllowedCommandsCsv
    }

    func resolvedAllowedCommandsCsv() -> String {
        effectiveAllowedCommandsCsv
    }

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now

        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any],
              let command = args["command"] as? String else {
            return .fail("Missing 'command' argument", stepId: step.id, durationMs: 0)
        }

        switch step.toolName {
        case "run_command":
            return executeEphemeral(command: command, step: step, start: start)

        case "run_persistent":
            return await executePersistent(command: command, args: args, step: step, start: start)

        default:
            return .fail("Unknown tool: \(step.toolName)", stepId: step.id, durationMs: 0)
        }
    }

    // MARK: - Ephemeral Execution

    /// Execute via Rust Tool Layer — Rust handles allow-list, timeout, result wrapping.
    private func executeEphemeral(command: String, step: AgentStep, start: ContinuousClock.Instant) -> AgentStepResult {
        let resultJson = toolRunCommand(command: command, allowedCommandsCsv: resolvedAllowedCommandsCsv())
        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

        if let parsed = try? JSONSerialization.jsonObject(with: Data(resultJson.utf8)) as? [String: Any],
           let success = parsed["success"] as? Bool, success {
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: 0.95)
        } else {
            let error = extractError(from: resultJson)
            return .fail(error, stepId: step.id, durationMs: elapsed)
        }
    }

    // MARK: - Persistent PTY Execution

    /// Execute in a persistent PTY session where shell state persists between calls.
    /// Uses omega-mcp's PTY pool via `ptySpawnSession` / `ptyExecuteCommand` UniFFI exports.
    private func executePersistent(command: String, args: [String: Any], step: AgentStep, start: ContinuousClock.Instant) async -> AgentStepResult {
        // Validate base command against persistent allow-list.
        let base = command.trimmingCharacters(in: .whitespaces)
            .split(separator: " ").first.map(String.init) ?? command
        guard persistentAllowedCommands.contains(base) else {
            return .fail(
                "Command '\(base)' not in persistent allow-list",
                stepId: step.id, durationMs: 0
            )
        }

        // Block destructive patterns.
        let blocked = ["rm -rf /", "rm -rf ~", "sudo rm", "mkfs", "dd if=", "diskutil eraseDisk",
                       "git push --force", "git reset --hard"]
        if blocked.contains(where: { command.contains($0) }) {
            return .fail(
                "Blocked destructive command pattern in persistent mode",
                stepId: step.id, durationMs: 0
            )
        }

        let id = ensurePty()
        let timeoutMs = (args["timeout_ms"] as? UInt64) ?? 30_000

        let resultJson = ptyExecuteCommand(ptyId: id, command: command, timeoutMs: timeoutMs)
        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

        // Parse the PTY result JSON.
        guard let data = resultJson.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .fail("Failed to parse PTY output JSON", stepId: step.id, durationMs: elapsed)
        }

        if let error = parsed["error"] as? String {
            return .fail("PTY error: \(error)", stepId: step.id, durationMs: elapsed)
        }

        let stdout = parsed["stdout"] as? String ?? ""
        let exitHint = parsed["exit_hint"] as? String ?? "unknown"
        let isError = exitHint.hasPrefix("error")

        if isError {
            return .fail(stdout.prefix(500).description, stepId: step.id, durationMs: elapsed)
        }

        // Return the raw JSON from PTY (already contains stdout, working_dir, etc.)
        // Wrap with "success" key for consistency with ephemeral mode.
        var enriched = parsed
        enriched["success"] = true
        guard let enrichedData = try? JSONSerialization.data(withJSONObject: enriched),
              let enrichedJson = String(data: enrichedData, encoding: .utf8) else {
            return .fail("Failed to serialize PTY output", stepId: step.id, durationMs: elapsed)
        }

        return .ok(enrichedJson, stepId: step.id, durationMs: elapsed, confidence: 0.95)
    }

    // MARK: - PTY Lifecycle

    /// Spawn or return the existing PTY session ID.
    /// Uses omega-mcp's `ptySpawnSession` UniFFI export (synchronous).
    private func ensurePty() -> String {
        if let existing = ptyId { return existing }

        let resultJson = ptySpawnSession(
            sessionId: UUID().uuidString,
            shell: "/bin/zsh",
            initialDir: ""
        )

        // Parse {"pty_id": "..."} from result.
        if let data = resultJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = parsed["pty_id"] as? String {
            ptyId = id
            return id
        }

        // Fallback: generate a placeholder (will fail on execute, but won't crash).
        let fallbackId = "pty-error-\(UUID().uuidString)"
        ptyId = fallbackId
        return fallbackId
    }

    // MARK: - Helpers

    private func extractError(from json: String) -> String {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = result["error"] as? String else {
            return "Unknown error"
        }
        return error
    }
}
