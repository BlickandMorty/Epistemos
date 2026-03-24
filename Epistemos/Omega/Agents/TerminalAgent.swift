import Foundation

// MARK: - Terminal Agent

/// Specialist agent for shell command execution with configurable allow-list.
@MainActor
final class TerminalAgent: OmegaAgent, @unchecked Sendable {
    let name = "terminal"
    let description = "Execute shell commands with allow-list restrictions"
    let toolNames = ["run_command"]

    /// Commands allowed to run. Empty = all commands allowed (dangerous).
    private let allowedCommands: Set<String>

    init(allowedCommands: Set<String> = ["ls", "cat", "head", "tail", "grep", "find", "wc", "echo", "date", "pwd", "which"]) {
        self.allowedCommands = allowedCommands
    }

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now

        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any],
              let command = args["command"] as? String else {
            return .fail("Missing 'command' argument", stepId: step.id, durationMs: 0)
        }

        // Extract the base command name for allow-list check
        let baseCommand = command.split(separator: " ").first.map(String.init) ?? command
        if !allowedCommands.isEmpty && !allowedCommands.contains(baseCommand) {
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .fail("Command '\(baseCommand)' not in allow-list", stepId: step.id, durationMs: elapsed)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let outStr = String(data: outData, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""

            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

            if process.terminationStatus == 0 {
                return .ok(
                    "{\"exit_code\":0,\"stdout\":\(jsonEscape(outStr)),\"stderr\":\(jsonEscape(errStr))}",
                    stepId: step.id,
                    durationMs: elapsed
                )
            } else {
                return .fail(
                    "Exit code \(process.terminationStatus): \(errStr)",
                    stepId: step.id,
                    durationMs: elapsed
                )
            }
        } catch {
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .fail(error.localizedDescription, stepId: step.id, durationMs: elapsed)
        }
    }

    private func jsonEscape(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: s),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\"\(s)\""
    }
}
