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

        // Extract URL from task text
        if lower.contains("open") && (lower.contains("safari") || lower.contains(".com") || lower.contains(".org") || lower.contains("http") || lower.contains("url") || lower.contains("website")) {
            let url = extractURL(from: task) ?? "https://www.apple.com"
            return [AgentStep(
                description: "Open \(url) in Safari",
                assignedAgent: "safari",
                toolName: "open_url",
                argumentsJson: "{\"url\":\(jsonEscape(url))}"
            )]
        }

        // Web search — extract the actual query
        if lower.contains("search") && (lower.contains("web") || lower.contains("google") || lower.contains("for")) {
            let query = extractSearchQuery(from: task)
            return [AgentStep(
                description: "Search the web for \(query)",
                assignedAgent: "safari",
                toolName: "search_web",
                argumentsJson: "{\"query\":\(jsonEscape(query))}"
            )]
        }

        // Note search
        if lower.contains("search") && lower.contains("note") {
            let query = extractSearchQuery(from: task)
            return [AgentStep(
                description: "Search notes for \(query)",
                assignedAgent: "notes",
                toolName: "search_notes",
                argumentsJson: "{\"query\":\(jsonEscape(query))}"
            )]
        }

        // Note creation — extract title from common patterns
        if lower.contains("create") && lower.contains("note") {
            let title = extractNoteTitle(from: task)
            return [AgentStep(
                description: "Create note: \(title)",
                assignedAgent: "notes",
                toolName: "create_note",
                argumentsJson: "{\"title\":\(jsonEscape(title)),\"body\":\"\"}"
            )]
        }

        // List notes
        if lower.contains("list") && lower.contains("note") {
            return [AgentStep(
                description: "List recent notes",
                assignedAgent: "notes",
                toolName: "list_notes",
                argumentsJson: "{}"
            )]
        }

        // File listing
        if lower.contains("list") && (lower.contains("file") || lower.contains("vault")) {
            return [AgentStep(
                description: "List vault files",
                assignedAgent: "file",
                toolName: "list_files",
                argumentsJson: "{\"path\":\".\"}"
            )]
        }

        // File read
        if lower.contains("read") && lower.contains("file") {
            return [AgentStep(
                description: "List files to find target",
                assignedAgent: "file",
                toolName: "list_files",
                argumentsJson: "{\"path\":\".\"}"
            )]
        }

        // Default: echo via terminal
        return [AgentStep(
            description: task,
            assignedAgent: "terminal",
            toolName: "run_command",
            argumentsJson: "{\"command\":\"echo 'Task received: \(task.replacingOccurrences(of: "'", with: ""))'}\"}"
        )]
    }

    // MARK: - Heuristic Helpers

    private func extractURL(from text: String) -> String? {
        // Try to find a URL-like pattern
        let patterns = [
            try? NSRegularExpression(pattern: "https?://[^\\s]+", options: []),
            try? NSRegularExpression(pattern: "([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}(/[^\\s]*)?", options: [])
        ].compactMap { $0 }

        for pattern in patterns {
            if let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range, in: text) {
                    var url = String(text[range])
                    if !url.hasPrefix("http") { url = "https://\(url)" }
                    return url
                }
            }
        }

        // Match "go to X" pattern
        let lower = text.lowercased()
        if let goToRange = lower.range(of: "go to ") {
            let afterGoTo = String(text[goToRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let site = afterGoTo.split(separator: " ").first.map(String.init) ?? afterGoTo
            if !site.isEmpty {
                return site.contains(".") ? "https://\(site)" : "https://www.\(site).com"
            }
        }

        return nil
    }

    private func extractSearchQuery(from text: String) -> String {
        let lower = text.lowercased()
        // Strip common prefixes
        let prefixes = ["search the web for ", "search for ", "search notes for ", "search my notes for ",
                        "look up ", "find ", "google "]
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let range = lower.range(of: prefix) {
                return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }

    private func extractNoteTitle(from text: String) -> String {
        let lower = text.lowercased()
        // "create a note called X", "create note titled X", "new note X"
        let patterns = ["called ", "titled ", "named "]
        guard let noteRange = lower.range(of: "note") else { return "New Note" }
        let searchStart = noteRange.upperBound
        for pattern in patterns {
            if let range = lower.range(of: pattern, range: searchStart..<lower.endIndex) {
                let after = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !after.isEmpty { return after }
            }
        }
        // Fallback: everything after "note" as title
        let afterNote = String(text[searchStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return afterNote.isEmpty ? "New Note" : afterNote
    }

    private func jsonEscape(_ s: String) -> String {
        // JSONSerialization requires Array/Dictionary as top-level object, not bare String.
        // Wrap in array, serialize, then extract the quoted string element.
        if let data = try? JSONSerialization.data(withJSONObject: [s]),
           let arr = String(data: data, encoding: .utf8) {
            // arr is like ["the string"] — strip the [ and ]
            let inner = arr.dropFirst().dropLast()
            return String(inner)
        }
        // Manual fallback: escape quotes and backslashes
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
                       .replacingOccurrences(of: "\n", with: "\\n")
                       .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}
