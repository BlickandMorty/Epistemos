import Foundation

// MARK: - File Agent

/// Specialist agent for file system operations scoped to the vault directory.
@MainActor
final class FileAgent: OmegaAgent, @unchecked Sendable {
    let name = "file"
    let description = "File system operations: read, write, list, move, delete files within the vault"
    let toolNames = ["read_file", "write_file", "list_files", "move_file", "delete_file"]

    private let vaultURL: URL?

    init(vaultURL: URL?) {
        self.vaultURL = vaultURL
    }

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now
        guard let vault = vaultURL else {
            return .fail("No vault attached", stepId: step.id, durationMs: 0)
        }

        do {
            let result = try await executeInternal(step: step, vault: vault)
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .ok(result, stepId: step.id, durationMs: elapsed)
        } catch {
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .fail(error.localizedDescription, stepId: step.id, durationMs: elapsed)
        }
    }

    private func executeInternal(step: AgentStep, vault: URL) async throws -> String {
        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any],
              let path = args["path"] as? String else {
            throw FileAgentError.invalidArguments
        }

        // Validate path is within vault (security boundary)
        let targetURL = vault.appendingPathComponent(path)
        guard targetURL.path.hasPrefix(vault.path) else {
            throw FileAgentError.pathOutsideVault
        }

        switch step.toolName {
        case "read_file":
            let content = try String(contentsOf: targetURL, encoding: .utf8)
            return "{\"content\":\(jsonEscape(content))}"

        case "write_file":
            let content = args["content"] as? String ?? ""
            try content.write(to: targetURL, atomically: true, encoding: .utf8)
            return "{\"written\":true,\"path\":\(jsonEscape(path))}"

        case "list_files":
            let fm = FileManager.default
            let items = try fm.contentsOfDirectory(atPath: targetURL.path)
            let json = try JSONSerialization.data(withJSONObject: items)
            return String(data: json, encoding: .utf8) ?? "[]"

        case "move_file":
            guard let dest = args["destination"] as? String else {
                throw FileAgentError.invalidArguments
            }
            let destURL = vault.appendingPathComponent(dest)
            guard destURL.path.hasPrefix(vault.path) else {
                throw FileAgentError.pathOutsideVault
            }
            try FileManager.default.moveItem(at: targetURL, to: destURL)
            return "{\"moved\":true}"

        case "delete_file":
            try FileManager.default.removeItem(at: targetURL)
            return "{\"deleted\":true}"

        default:
            throw FileAgentError.unknownTool(step.toolName)
        }
    }

    private func jsonEscape(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [s]),
           let arr = String(data: data, encoding: .utf8) {
            return String(arr.dropFirst().dropLast())
        }
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
                       .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

enum FileAgentError: LocalizedError {
    case invalidArguments
    case pathOutsideVault
    case unknownTool(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments: "Invalid arguments for file operation"
        case .pathOutsideVault: "Path is outside the vault directory"
        case .unknownTool(let name): "Unknown tool: \(name)"
        }
    }
}
