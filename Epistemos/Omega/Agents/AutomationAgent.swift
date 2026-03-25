import Foundation
import AppKit

// MARK: - Automation Agent

/// Generic macOS automation agent using AX tree and input simulation.
/// AX tree + input calls go through omega-ax UniFFI (Rust Layer 1).
/// Shortcuts go through omega-ax shortcuts (Rust Layer 1).
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
            let pid = resolvePID(from: args)
            guard pid > 0 else {
                return .fail("Could not resolve app PID — provide 'pid' or 'app' name", stepId: step.id, durationMs: 0)
            }
            // omega-ax Rust Layer 1: AX tree walker
            resultJson = walkAxTreeJson(pid: pid)

        case "click_element":
            resultJson = try await executeClick(args: args)

        case "type_text":
            guard let text = args["text"] as? String else {
                return .fail("Missing 'text' argument", stepId: step.id, durationMs: 0)
            }
            // omega-ax Rust Layer 1: CGEvent keyboard simulation
            resultJson = simulateTypeText(text: text)

        case "press_key":
            guard let keyCode = args["key_code"] as? Int else {
                return .fail("press_key requires 'key_code' (macOS virtual key code, e.g. 36=Return, 49=Space)", stepId: step.id, durationMs: 0)
            }
            let modifiers = (args["modifiers"] as? UInt64) ?? 0
            // omega-ax Rust Layer 1: CGEvent key press simulation
            resultJson = simulateKeyPress(keyCode: UInt16(keyCode), modifiers: modifiers)

        case "run_shortcut":
            guard let name = args["name"] as? String, !name.isEmpty else {
                return .fail("Missing 'name' argument for shortcut", stepId: step.id, durationMs: 0)
            }
            // omega-ax Rust Layer 1: /usr/bin/shortcuts wrapper
            resultJson = runShortcutByName(name: name)

        default:
            return .fail("Unknown tool: \(step.toolName)", stepId: step.id, durationMs: 0)
        }

        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

        // Parse result for success/failure
        if let parsed = try? JSONSerialization.jsonObject(with: Data(resultJson.utf8)) as? [String: Any],
           let success = parsed["success"] as? Bool, success {
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: 0.9)
        } else {
            if resultJson.contains("\"error\"") {
                let error = extractError(from: resultJson)
                return .fail(error, stepId: step.id, durationMs: elapsed)
            }
            // AX tree JSON doesn't have success/error — it's the tree itself
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: 0.85)
        }
    }

    // MARK: - Click Implementation

    /// Supports three click modes:
    /// 1. By element name + app: `{"app": "Safari", "element": "Downloads"}` — finds in AX tree, clicks center
    /// 2. By element name + pid: `{"pid": 1234, "element": "Downloads"}`
    /// 3. By raw coordinates: `{"x": 500, "y": 300}`
    private func executeClick(args: [String: Any]) async throws -> String {
        // Mode 1 & 2: Semantic click by element name
        if let elementName = args["element"] as? String {
            let pid = resolvePID(from: args)
            guard pid > 0 else {
                return "{\"success\":false,\"error\":\"Could not resolve app PID — provide 'pid' or 'app' name\"}"
            }
            return clickElementByName(pid: pid, elementName: elementName)
        }

        // Mode 3: Raw coordinate click
        if let x = args["x"] as? Double, let y = args["y"] as? Double {
            return simulateClick(x: x, y: y)
        }

        return "{\"success\":false,\"error\":\"click_element requires either {'element':'name', 'app':'AppName'} or {'x':num, 'y':num}\"}"
    }

    // MARK: - PID Resolution

    /// Resolve a PID from args — supports `pid` (direct) or `app` (by name lookup).
    private func resolvePID(from args: [String: Any]) -> Int64 {
        if let pid = args["pid"] as? Int {
            return Int64(pid)
        }
        if let pid = args["pid"] as? Int64 {
            return pid
        }
        if let appName = args["app"] as? String {
            return pidForApp(named: appName)
        }
        return -1
    }

    /// Find a running app's PID by name (case-insensitive partial match).
    private func pidForApp(named name: String) -> Int64 {
        let lower = name.lowercased()
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName?.lowercased() == lower }) {
            return Int64(app.processIdentifier)
        }
        // Partial match fallback
        if let app = apps.first(where: { $0.localizedName?.lowercased().contains(lower) == true }) {
            return Int64(app.processIdentifier)
        }
        return -1
    }

    // MARK: - Helpers

    private func extractError(from json: String) -> String {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = result["error"] as? String else {
            return "Automation error"
        }
        return error
    }
}
