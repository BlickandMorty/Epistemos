import Foundation

// MARK: - Terminal Agent

/// Specialist agent for shell command execution.
/// All execution goes through the Rust Tool Layer (omega-mcp osascript.rs tool_run_command)
/// per Anti-Drift Anchor 1 and Anchor 5.
@MainActor
final class TerminalAgent: OmegaAgent, Sendable {
    let name = "terminal"
    let description = "Execute shell commands with allow-list restrictions"
    let toolNames = ["run_command"]

    /// Comma-separated allow-list passed to Rust for enforcement.
    /// Falls back to init default if the setting is unset.
    private let defaultAllowedCommandsCsv: String

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

        // Execute via Rust Tool Layer — Rust handles allow-list, timeout, result wrapping
        let resultJson = toolRunCommand(command: command, allowedCommandsCsv: resolvedAllowedCommandsCsv())

        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

        // Parse the Rust ToolResult JSON
        if let parsed = try? JSONSerialization.jsonObject(with: Data(resultJson.utf8)) as? [String: Any],
           let success = parsed["success"] as? Bool, success {
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: 0.95)
        } else {
            let error = extractError(from: resultJson)
            return .fail(error, stepId: step.id, durationMs: elapsed)
        }
    }

    private func extractError(from json: String) -> String {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = result["error"] as? String else {
            return "Unknown error"
        }
        return error
    }
}
