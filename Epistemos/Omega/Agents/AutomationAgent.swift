import Foundation

// MARK: - Automation Agent

/// Generic macOS automation agent using AX tree and input simulation.
/// AX tree + input calls go through omega-ax UniFFI (Rust Layer 1).
/// Shortcuts go through omega-mcp osascript.rs (Rust Layer 2).
/// Per Anti-Drift Anchors 1 and 5.
@MainActor
final class AutomationAgent: OmegaAgent, @unchecked Sendable {
    let name = "automation"
    let description = "Generic macOS app automation via accessibility tree and input simulation"
    let toolNames = ["get_ui_tree", "click_element", "type_text", "press_key", "run_shortcut"]

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now

        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any] else {
            return .fail("Invalid arguments JSON", stepId: step.id, durationMs: 0)
        }

        // All calls go through Rust FFI layers
        let resultJson: String
        switch step.toolName {
        case "get_ui_tree":
            guard let pid = args["pid"] as? Int else {
                return .fail("Missing 'pid' argument", stepId: step.id, durationMs: 0)
            }
            // omega-ax Rust Layer 1: AX tree walker
            resultJson = walkAxTreeJson(pid: Int64(pid))

        case "click_element":
            guard let x = args["x"] as? Double, let y = args["y"] as? Double else {
                return .fail("Missing 'x'/'y' arguments", stepId: step.id, durationMs: 0)
            }
            // omega-ax Rust Layer 1: CGEvent input simulation
            resultJson = simulateClick(x: x, y: y)

        case "type_text":
            guard let text = args["text"] as? String else {
                return .fail("Missing 'text' argument", stepId: step.id, durationMs: 0)
            }
            // omega-ax Rust Layer 1: CGEvent keyboard simulation
            resultJson = simulateTypeText(text: text)

        case "press_key":
            return .fail("press_key requires key_code — use type_text for text input", stepId: step.id, durationMs: 0)

        case "run_shortcut":
            guard let name = args["name"] as? String, !name.isEmpty else {
                return .fail("Missing 'name' argument for shortcut", stepId: step.id, durationMs: 0)
            }
            // omega-mcp Rust Layer 2: osascript wrapper for shortcuts
            let script = "do shell script \"/usr/bin/shortcuts run '\\(name)'\""
            resultJson = toolOpenUrl(url: "") // Placeholder — should use dedicated shortcut tool
            // TODO: Add tool_run_shortcut to osascript.rs

        default:
            return .fail("Unknown tool: \(step.toolName)", stepId: step.id, durationMs: 0)
        }

        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

        // Parse result for success/failure
        if let parsed = try? JSONSerialization.jsonObject(with: Data(resultJson.utf8)) as? [String: Any],
           let success = parsed["success"] as? Bool, success {
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: 0.9)
        } else {
            // AX tree and input simulation return different formats — check for error field
            if resultJson.contains("\"error\"") {
                let error = extractError(from: resultJson)
                return .fail(error, stepId: step.id, durationMs: elapsed)
            }
            // AX tree JSON doesn't have success/error — it's the tree itself
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: 0.85)
        }
    }

    private func extractError(from json: String) -> String {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = result["error"] as? String else {
            return "Automation error"
        }
        return error
    }
}
