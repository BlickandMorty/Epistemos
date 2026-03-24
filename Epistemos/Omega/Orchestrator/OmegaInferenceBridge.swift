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
        let toolSchemas = await MainActor.run { self.toolSchemasJson }

        let prompt = """
        You are a task planner for Epistemos Omega, a macOS automation system.

        Available agents and their tools:
        - safari: open_url, get_page_url, get_page_title, search_web
        - file: read_file, write_file, list_files, move_file, delete_file
        - notes: create_note, edit_note, search_notes, list_notes
        - terminal: run_command (shell commands, allow-listed)
        - automation: get_ui_tree, click_element, type_text, run_shortcut

        User request: \(taskDescription)

        Respond with ONLY a JSON array of steps. Each step must have:
        - "description": what this step accomplishes
        - "agent": one of [safari, file, notes, terminal, automation]
        - "tool": the specific tool to call
        - "arguments": object with the tool's required parameters
        - "risk": "low", "medium", "high", or "critical"

        Rules:
        - Use the minimum number of steps needed
        - Mark file deletion as "high" risk, system changes as "critical"
        - For web searches, use safari agent with search_web tool
        - For file operations, use file agent
        - Default to terminal agent for general tasks

        Example response:
        [{"description":"Search for topic","agent":"safari","tool":"search_web","arguments":{"query":"MLX benchmarks"},"risk":"low"}]
        """

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
