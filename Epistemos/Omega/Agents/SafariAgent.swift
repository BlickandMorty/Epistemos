import Foundation

// MARK: - Safari Agent

/// Specialist agent for web browsing via AppleScript + AX tree automation.
@MainActor
final class SafariAgent: OmegaAgent, @unchecked Sendable {
    let name = "safari"
    let description = "Web browsing: open URLs, get page content, search the web via Safari"
    let toolNames = ["open_url", "get_page_url", "get_page_title", "search_web"]

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now

        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any] else {
            return .fail("Invalid arguments", stepId: step.id, durationMs: 0)
        }

        do {
            let result = try await executeInternal(step: step, args: args)
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .ok(result, stepId: step.id, durationMs: elapsed)
        } catch {
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return .fail(error.localizedDescription, stepId: step.id, durationMs: elapsed)
        }
    }

    private func executeInternal(step: AgentStep, args: [String: Any]) async throws -> String {
        switch step.toolName {
        case "open_url":
            guard let url = args["url"] as? String else {
                throw SafariAgentError.missingArgument("url")
            }
            let script = "tell application \"Safari\" to open location \"\(url.replacingOccurrences(of: "\"", with: "\\\""))\""
            let output = try await runOsascript(script)
            return "{\"opened\":true,\"url\":\(jsonEscape(url))}"

        case "get_page_url":
            let script = "tell application \"Safari\" to get URL of current tab of front window"
            let url = try await runOsascript(script)
            return "{\"url\":\(jsonEscape(url))}"

        case "get_page_title":
            let script = "tell application \"Safari\" to get name of current tab of front window"
            let title = try await runOsascript(script)
            return "{\"title\":\(jsonEscape(title))}"

        case "search_web":
            guard let query = args["query"] as? String else {
                throw SafariAgentError.missingArgument("query")
            }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let url = "https://www.google.com/search?q=\(encoded)"
            let script = "tell application \"Safari\" to open location \"\(url)\""
            _ = try await runOsascript(script)
            return "{\"searched\":true,\"query\":\(jsonEscape(query))}"

        default:
            throw SafariAgentError.unknownTool(step.toolName)
        }
    }

    /// Run an AppleScript via osascript Process.
    private func runOsascript(_ script: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? "osascript failed"
            throw SafariAgentError.scriptFailed(errStr)
        }

        return output
    }

    private func jsonEscape(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: s),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\"\(s)\""
    }
}

enum SafariAgentError: LocalizedError {
    case missingArgument(String)
    case unknownTool(String)
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name): "Missing required argument: \(name)"
        case .unknownTool(let name): "Unknown tool: \(name)"
        case .scriptFailed(let msg): "AppleScript failed: \(msg)"
        }
    }
}
