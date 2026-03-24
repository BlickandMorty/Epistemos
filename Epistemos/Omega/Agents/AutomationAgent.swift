import Foundation

// MARK: - Automation Agent

/// Generic macOS automation agent using AX tree and input simulation.
/// For apps that don't have specific agent support.
@MainActor
final class AutomationAgent: OmegaAgent, @unchecked Sendable {
    let name = "automation"
    let description = "Generic macOS app automation via accessibility tree and input simulation"
    let toolNames = ["get_ui_tree", "click_element", "type_text", "press_key", "run_shortcut"]

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
        case "get_ui_tree":
            guard let pid = args["pid"] as? Int else {
                throw AutomationError.missingArgument("pid")
            }
            // Call omega-ax via UniFFI
            let json = walkAxTreeJson(pid: Int64(pid))
            return json

        case "click_element":
            guard let x = args["x"] as? Double, let y = args["y"] as? Double else {
                throw AutomationError.missingArgument("x, y")
            }
            let result = simulateClick(x: x, y: y)
            return result

        case "type_text":
            guard let text = args["text"] as? String else {
                throw AutomationError.missingArgument("text")
            }
            let result = simulateTypeText(text: text)
            return result

        case "press_key":
            // Key press requires key_code — complex for general use
            return "{\"error\":\"press_key requires key_code — use type_text for text input\"}"

        case "run_shortcut":
            guard let name = args["name"] as? String else {
                throw AutomationError.missingArgument("name")
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]

            let stdout = Pipe()
            process.standardOutput = stdout
            try process.run()
            process.waitUntilExit()

            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData, encoding: .utf8) ?? ""
            return "{\"shortcut\":\(jsonEscape(name)),\"output\":\(jsonEscape(output))}"

        default:
            throw AutomationError.unknownTool(step.toolName)
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

enum AutomationError: LocalizedError {
    case missingArgument(String)
    case unknownTool(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name): "Missing required argument: \(name)"
        case .unknownTool(let name): "Unknown tool: \(name)"
        }
    }
}
