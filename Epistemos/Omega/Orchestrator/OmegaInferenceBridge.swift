import Foundation

// MARK: - Omega Inference Bridge

/// Bridges the existing TriageService to the Omega agent system.
/// Uses local model for planning (fast, private), with tool schemas injected
/// into the system prompt so the model knows exactly what tools are available.
@MainActor
final class OmegaInferenceBridge {
    private let triageService: TriageService

    /// Tool schemas JSON for injection into planning prompts.
    var toolSchemasJson: String = "[]"

    init(triageService: TriageService) {
        self.triageService = triageService
    }

    /// Set the available tool schemas (called after MCPBridge registers tools).
    func setToolSchemas(_ json: String) {
        toolSchemasJson = json
    }

    /// Generate a planning response from the local model.
    /// Includes full tool schemas so the model can generate valid tool calls.
    nonisolated func generatePlan(
        taskDescription: String,
        availableAgents: [String],
        systemPrompt: String? = nil
    ) async throws -> String {
        let prompt = Self.buildPlanningPrompt(taskDescription: taskDescription)

        let system = systemPrompt ?? "You are a precise task planner. Output ONLY valid JSON array. No explanation, no markdown, no code fences."

        let raw: String = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor [triageService] in
                do {
                    let result = try await triageService.generateRawLocal(
                        prompt: prompt,
                        systemPrompt: system,
                        maxTokens: 1024
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return Self.stripThinkTags(raw)
    }

    // MARK: - Prompt Construction

    private nonisolated static func buildPlanningPrompt(taskDescription: String) -> String {
        """
        You are a task planner for Epistemos Omega, a macOS automation system.

        Available agents and their tools:

        SAFARI agent:
        - open_url: Open a URL. Args: {"url": "https://..."}
        - search_web: Web search. Args: {"query": "search terms"}
        - get_page_url: Get current Safari page URL. Args: {}
        - get_page_title: Get current Safari page title. Args: {}

        FILE agent (vault-scoped):
        - list_files: List files in a directory. Args: {"path": "."}
        - read_file: Read file contents. Args: {"path": "relative/path.md"}
        - write_file: Write to a file. Args: {"path": "relative/path.md", "content": "..."}
        - move_file: Move/rename a file. Args: {"path": "old.md", "destination": "new.md"}
        - delete_file: Delete a file. Args: {"path": "relative/path.md"}

        NOTES agent (Epistemos knowledge base):
        - create_note: Create a new note. Args: {"title": "...", "body": "..."}
        - search_notes: Full-text search notes. Args: {"query": "search terms"}
        - list_notes: List recent notes. Args: {}
        - edit_note: Edit an existing note. Args: {"id": "page-uuid", "body": "new content"}

        TERMINAL agent:
        - run_command: Run a shell command. Args: {"command": "ls -la"}

        AUTOMATION agent (macOS UI):
        - get_ui_tree: Read accessibility tree. Args: {"app": "AppName"}
        - click_element: Click a UI element. Args: {"app": "AppName", "element": "Button Name"}
        - type_text: Type text into focused field. Args: {"text": "..."}
        - run_shortcut: Run a Shortcuts.app shortcut. Args: {"name": "shortcut-name"}

        User request: \(taskDescription)

        Respond with ONLY a JSON array of steps. Each step:
        {"description":"what this step does","agent":"agent_name","tool":"tool_name","arguments":{...},"risk":"low|medium|high|critical"}

        Rules:
        - Use the MINIMUM steps needed. Single-step tasks should be one step.
        - For multi-step tasks, order steps logically (search before read, read before summarize).
        - Mark file deletion as "high" risk, system changes as "critical". Everything else "low".
        - For note creation, always include both "title" and "body" in arguments.
        - For search, extract the actual search query from the user's request.

        Examples:

        Request: "search the web for MLX benchmarks"
        [{"description":"Search for MLX benchmarks","agent":"safari","tool":"search_web","arguments":{"query":"MLX benchmarks 2026"},"risk":"low"}]

        Request: "create a note called Meeting Notes with today's agenda"
        [{"description":"Create Meeting Notes","agent":"notes","tool":"create_note","arguments":{"title":"Meeting Notes","body":"# Meeting Notes\\n\\n## Agenda\\n\\n- "},"risk":"low"}]

        Request: "list files in my vault"
        [{"description":"List vault root files","agent":"file","tool":"list_files","arguments":{"path":"."},"risk":"low"}]

        Request: "summarize my note about quantum computing"
        [{"description":"Search for quantum computing notes","agent":"notes","tool":"search_notes","arguments":{"query":"quantum computing"},"risk":"low"},{"description":"List matching notes for context","agent":"notes","tool":"list_notes","arguments":{},"risk":"low"}]

        Request: "open apple.com in Safari"
        [{"description":"Open apple.com","agent":"safari","tool":"open_url","arguments":{"url":"https://www.apple.com"},"risk":"low"}]

        Request: "find my notes about machine learning and create a summary note"
        [{"description":"Search for ML notes","agent":"notes","tool":"search_notes","arguments":{"query":"machine learning"},"risk":"low"},{"description":"Create summary note","agent":"notes","tool":"create_note","arguments":{"title":"Machine Learning Summary","body":"# Machine Learning Summary\\n\\nCompiled from vault notes.\\n\\n"},"risk":"low"}]

        Now plan for: \(taskDescription)
        """
    }

    /// Remove `<think>...</think>` blocks from reasoning model output.
    private nonisolated static func stripThinkTags(_ text: String) -> String {
        var result = text
        while let thinkStart = result.range(of: "<think>", options: .caseInsensitive),
              let thinkEnd = result.range(of: "</think>", options: .caseInsensitive, range: thinkStart.upperBound..<result.endIndex) {
            result.removeSubrange(thinkStart.lowerBound..<thinkEnd.upperBound)
        }
        if let thinkStart = result.range(of: "<think>", options: .caseInsensitive) {
            if result.range(of: "</think>", options: .caseInsensitive) == nil {
                result.removeSubrange(thinkStart.lowerBound..<result.endIndex)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
