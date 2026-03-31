import Foundation

// MARK: - Fallback Chain Resolver (Ω-HAS)

/// Maps failed tool executions to fallback alternatives on the opposite execution arm.
///
/// When a GUI action fails (element not found, app not responding), the resolver
/// suggests a CLI equivalent. When a CLI command fails (tool unavailable),
/// it suggests a GUI path.
///
/// Fallback mappings are static and deterministic — no LLM call required.
@MainActor
final class FallbackChainResolver {

    struct FallbackOption: Sendable {
        let agent: String
        let toolName: String
        let argumentsJson: String
        let reasoning: String
    }

    // MARK: - Fallback Map

    /// Static mapping: tool_name → [(fallback_agent, fallback_tool)].
    /// Order matters — first viable fallback is used.
    private static let fallbackMap: [String: [(agent: String, tool: String)]] = [
        // GUI → CLI fallbacks
        "click":         [("terminal", "run_persistent")],
        "type":          [("terminal", "run_persistent")],
        "see":           [("terminal", "run_command")],
        "scroll":        [("terminal", "run_persistent")],

        // CLI → GUI fallbacks
        "run_command":    [("computer", "keys")],
        "run_persistent": [("computer", "keys")],

        // Automation ↔ Computer cross-fallbacks (same domain, different impl)
        "click_element":  [("computer", "click")],
        "get_ui_tree":    [("computer", "see")],
        "type_text":      [("computer", "type")],
        "press_key":      [("computer", "keys")],
    ]

    // MARK: - Resolution

    /// Given a failed step, suggest a fallback on the alternate execution arm.
    /// Returns `nil` if no fallback mapping exists for the failed tool.
    func resolveFallback(
        failedStep: AgentStep,
        failedResult: AgentStepResult
    ) -> FallbackOption? {
        guard let fallbacks = Self.fallbackMap[failedStep.toolName],
              let first = fallbacks.first else {
            return nil
        }

        let transformedArgs = transformArguments(
            from: failedStep,
            toAgent: first.agent,
            toTool: first.tool
        )

        return FallbackOption(
            agent: first.agent,
            toolName: first.tool,
            argumentsJson: transformedArgs,
            reasoning: "Primary \(failedStep.assignedAgent)/\(failedStep.toolName) failed: \(failedResult.error ?? "unknown"). Falling back to \(first.agent)/\(first.tool)."
        )
    }

    // MARK: - Argument Transformation

    /// Best-effort transformation of arguments from one tool format to another.
    /// Conservative: only transforms when the mapping is unambiguous.
    private func transformArguments(
        from step: AgentStep,
        toAgent: String,
        toTool: String
    ) -> String {
        guard let data = step.argumentsJson.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return step.argumentsJson
        }

        // GUI click → CLI: attempt app activation via `open` command.
        if step.toolName == "click" && toTool == "run_persistent" {
            if let element = args["element"] as? String {
                let cmd = "open -a \"\(Self.safeShellEscape(element))\""
                return Self.jsonObject(["command": cmd])
            }
            return Self.jsonObject(["command": "echo 'fallback: no element to open'"])
        }

        // GUI type → CLI: write text via echo/pbcopy.
        if step.toolName == "type" && toTool == "run_persistent" {
            if let text = args["text"] as? String {
                let cmd = "echo \"\(Self.safeShellEscape(text))\" | pbcopy"
                return Self.jsonObject(["command": cmd])
            }
        }

        // CLI → GUI keys: type the command into the frontmost app.
        if (step.toolName == "run_command" || step.toolName == "run_persistent")
            && toTool == "keys" {
            if let command = args["command"] as? String {
                return Self.jsonObject(["keys": command, "modifiers": []])
            }
        }

        // Automation → Computer: pass through element targeting.
        if step.toolName == "click_element" && toTool == "click" {
            if let element = args["element"] as? String {
                return Self.jsonObject(["element": element])
            }
        }

        if step.toolName == "type_text" && toTool == "type" {
            if let text = args["text"] as? String {
                return Self.jsonObject(["text": text])
            }
        }

        // Default: pass through original arguments.
        return step.argumentsJson
    }

    // MARK: - Helpers

    private static func safeShellEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "$", with: "\\$")
         .replacingOccurrences(of: "`", with: "\\`")
    }

    private static func safeJsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func jsonObject(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
