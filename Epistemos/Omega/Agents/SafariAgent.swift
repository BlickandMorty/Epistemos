import Foundation

// MARK: - Safari Agent

/// Specialist agent for web browsing.
/// All tool execution goes through the Rust Tool Layer (omega-mcp osascript.rs)
/// per Anti-Drift Anchor 1 and Anchor 5.
@MainActor
final class SafariAgent: OmegaAgent, @unchecked Sendable {
    let name = "safari"
    let description = "Web browsing: open URLs, get page content, search the web via Safari"
    let toolNames = ["open_url", "get_page_url", "get_page_title", "search_web"]

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now

        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any] else {
            return .fail("Invalid arguments JSON", stepId: step.id, durationMs: 0)
        }

        // All execution goes through Rust Tool Layer via UniFFI
        let resultJson: String
        switch step.toolName {
        case "open_url":
            guard let url = args["url"] as? String else {
                return .fail("Missing 'url' argument", stepId: step.id, durationMs: 0)
            }
            resultJson = toolOpenUrl(url: url)

        case "get_page_url":
            resultJson = toolGetPageUrl()

        case "get_page_title":
            resultJson = toolGetPageTitle()

        case "search_web":
            guard let query = args["query"] as? String else {
                return .fail("Missing 'query' argument", stepId: step.id, durationMs: 0)
            }
            resultJson = toolSearchWeb(query: query)

        default:
            return .fail("Unknown tool: \(step.toolName)", stepId: step.id, durationMs: 0)
        }

        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

        // Parse the Rust ToolResult JSON
        let confidence = parseToolResultConfidence(resultJson)
        if let parsed = try? JSONSerialization.jsonObject(with: Data(resultJson.utf8)) as? [String: Any],
           let success = parsed["success"] as? Bool, success {
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: confidence)
        } else {
            let errorMsg = extractError(from: resultJson)
            return .fail(errorMsg, stepId: step.id, durationMs: elapsed)
        }
    }

    /// Parse confidence from ToolResult (1.0 for success, 0.5 for partial, 0.0 for failure).
    private func parseToolResultConfidence(_ json: String) -> Double {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = result["success"] as? Bool else {
            return 0.0
        }
        return success ? 0.95 : 0.0
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
