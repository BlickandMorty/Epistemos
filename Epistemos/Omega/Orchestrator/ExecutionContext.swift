import Foundation

// MARK: - Execution Context (Ω-HAS)

/// Tracks cross-step execution state: working directory, environment variables, and file paths.
///
/// Updated after each step completes. Injected into subsequent steps via `_execution_context`
/// in the arguments JSON, enabling multi-step workflows where later steps depend on
/// state changes from earlier steps (e.g., `cd` in terminal → file ops in the new directory).
@MainActor @Observable
final class ExecutionContext {

    /// Current working directory (updated by terminal/PTY steps).
    var workingDir: String = FileManager.default.homeDirectoryForCurrentUser.path

    /// Environment variable overrides accumulated during execution.
    var envOverrides: [String: String] = [:]

    /// File paths produced by previous steps (for resolution in subsequent steps).
    var producedFilePaths: [String] = []

    /// Update context from a completed step's output.
    func update(from result: AgentStepResult, step: AgentStep) {
        guard result.success,
              let data = result.outputJson.data(using: .utf8),
              let output = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Track working directory changes (from PTY output).
        if let wd = output["working_dir"] as? String, !wd.isEmpty {
            workingDir = wd
        }

        // Track file paths from file/notes operations.
        if let path = output["path"] as? String, !path.isEmpty {
            producedFilePaths.append(path)
        }
        if let filePath = output["file_path"] as? String, !filePath.isEmpty {
            producedFilePaths.append(filePath)
        }

        // Track explicit env overrides from terminal output.
        if let env = output["env"] as? [String: String] {
            envOverrides.merge(env) { _, new in new }
        }
    }

    /// Serialize context for injection into step arguments.
    func toJson() -> [String: Any] {
        [
            "working_dir": workingDir,
            "env_overrides": envOverrides,
            "produced_files": producedFilePaths,
        ]
    }

    /// Reset all tracked state (called on task reset).
    func reset() {
        workingDir = FileManager.default.homeDirectoryForCurrentUser.path
        envOverrides.removeAll()
        producedFilePaths.removeAll()
    }
}
