import Foundation

// MARK: - Omega Planning Service

/// High-level planning service that generates execution plans from task descriptions.
/// Uses OmegaInferenceBridge for LLM-based plan generation, ToolCallParser for extraction.
@MainActor
final class OmegaPlanningService {
    private let inferenceBridge: OmegaInferenceBridge
    private let availableAgents: [String]

    init(inferenceBridge: OmegaInferenceBridge, availableAgents: [String]) {
        self.inferenceBridge = inferenceBridge
        self.availableAgents = availableAgents
    }

    /// Generate a plan (list of AgentSteps) from a task description.
    /// Falls back to a simple single-step plan if LLM planning fails.
    func generatePlan(for taskDescription: String) async -> [AgentStep] {
        // Try LLM-based planning
        do {
            let response = try await inferenceBridge.generatePlan(
                taskDescription: taskDescription,
                availableAgents: availableAgents
            )
            let steps = parsePlanResponse(response, taskDescription: taskDescription)
            if !steps.isEmpty {
                return steps
            }
        } catch {
            // LLM planning failed — fall through to heuristic
        }

        // Fallback: simple heuristic routing
        return heuristicPlan(for: taskDescription)
    }

    /// Parse the LLM's JSON plan response into AgentSteps.
    private func parsePlanResponse(_ response: String, taskDescription: String) -> [AgentStep] {
        // Try parsing as tool calls
        let toolCalls = ToolCallParser.parse(response)
        if !toolCalls.isEmpty {
            return toolCalls.map { call in
                let agent = resolveAgent(for: call.name)
                return AgentStep(
                    description: "\(call.name)",
                    assignedAgent: agent,
                    toolName: call.name,
                    argumentsJson: call.argumentsJson
                )
            }
        }

        // Try parsing as a JSON array of step objects
        guard let data = response.data(using: .utf8),
              let steps = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return steps.compactMap { stepDict -> AgentStep? in
            guard let description = stepDict["description"] as? String,
                  let agent = stepDict["agent"] as? String,
                  let tool = stepDict["tool"] as? String else {
                return nil
            }
            let args = stepDict["arguments"] as? [String: Any] ?? [:]
            let argsJson = (try? JSONSerialization.data(withJSONObject: args))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let riskStr = stepDict["risk"] as? String ?? "low"
            let risk = RiskLevel(rawValue: riskStr) ?? .low

            return AgentStep(
                description: description,
                assignedAgent: agent,
                toolName: tool,
                argumentsJson: argsJson,
                riskLevel: risk
            )
        }
    }

    /// Resolve which agent should handle a given tool name.
    private func resolveAgent(for toolName: String) -> String {
        let toolToAgent: [String: String] = [
            "open_url": "safari", "get_page_url": "safari", "get_page_title": "safari", "search_web": "safari",
            "read_file": "file", "write_file": "file", "list_files": "file", "move_file": "file", "delete_file": "file",
            "create_note": "notes", "edit_note": "notes", "search_notes": "notes", "list_notes": "notes",
            "run_command": "terminal",
            "get_ui_tree": "automation", "click_element": "automation", "type_text": "automation",
            "press_key": "automation", "run_shortcut": "automation",
        ]
        return toolToAgent[toolName] ?? "automation"
    }

    /// Simple heuristic-based planning when LLM is unavailable.
    private func heuristicPlan(for task: String) -> [AgentStep] {
        let lower = task.lowercased()

        if lower.contains("open") && (lower.contains("safari") || lower.contains("http") || lower.contains("url") || lower.contains("website")) {
            return [AgentStep(
                description: "Open URL in Safari",
                assignedAgent: "safari",
                toolName: "open_url",
                argumentsJson: "{\"url\":\"https://www.apple.com\"}"
            )]
        }

        if lower.contains("search") && (lower.contains("web") || lower.contains("google")) {
            let query = task.replacingOccurrences(of: "search for ", with: "").replacingOccurrences(of: "search the web for ", with: "")
            return [AgentStep(
                description: "Search the web",
                assignedAgent: "safari",
                toolName: "search_web",
                argumentsJson: "{\"query\":\"\(query)\"}"
            )]
        }

        if lower.contains("file") || lower.contains("read") || lower.contains("write") {
            return [AgentStep(
                description: "File operation",
                assignedAgent: "file",
                toolName: "list_files",
                argumentsJson: "{\"path\":\".\"}"
            )]
        }

        if lower.contains("note") || lower.contains("create note") {
            return [AgentStep(
                description: "Note operation",
                assignedAgent: "notes",
                toolName: "create_note",
                argumentsJson: "{\"title\":\"New Note\",\"body\":\"\"}"
            )]
        }

        // Default: echo via terminal
        return [AgentStep(
            description: task,
            assignedAgent: "terminal",
            toolName: "run_command",
            argumentsJson: "{\"command\":\"echo 'Task received'\"}"
        )]
    }
}
