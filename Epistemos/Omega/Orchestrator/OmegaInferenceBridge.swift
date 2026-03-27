import Foundation

// MARK: - Omega Inference Bridge

/// Bridges the existing TriageService to the Omega agent system.
/// Uses local model for planning (fast, private), with tool schemas injected
/// into the system prompt so the model knows exactly what tools are available.
///
/// When `constrainedDecoding` is available and truly constraining, attempts
/// grammar-guided generation first. Falls back to unconstrained + parse.
@MainActor
final class OmegaInferenceBridge {
    private let triageService: TriageService

    /// Tool schemas JSON for injection into planning prompts.
    var toolSchemasJson: String = OmegaToolRegistry.planningSchemasJson

    /// Optional constrained decoding service (Ω11).
    /// When available, generates structurally valid JSON via logit masking.
    var constrainedDecoding: ConstrainedDecodingService?

    /// Parsed tool schemas for grammar compilation.
    private var parsedToolSchemas: [[String: Any]] {
        guard let data = toolSchemasJson.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return OmegaToolRegistry.planningSchemas
        }
        return array
    }

    init(triageService: TriageService) {
        self.triageService = triageService
    }

    /// Set the available tool schemas (called after MCPBridge registers tools).
    func setToolSchemas(_ json: String) {
        toolSchemasJson = json
    }

    /// Generate a planning response from the local model.
    /// Tries constrained decoding first (if available), falls back to unconstrained.
    nonisolated func generatePlan(
        taskDescription: String,
        availableAgents: [String],
        systemPrompt: String? = nil
    ) async throws -> String {
        // Try constrained decoding path first (only when truly available)
        let constrained: String? = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor [weak self] in
                guard let self, let cd = self.constrainedDecoding, cd.isAvailable else {
                    continuation.resume(returning: nil as String?)
                    return
                }
                do {
                    let system = systemPrompt ?? "You are a precise task planner. Output ONLY valid JSON array."
                    let prompt = Self.buildPlanningPrompt(taskDescription: taskDescription)
                    let result = try await cd.generateConstrainedPlan(
                        prompt: prompt,
                        systemPrompt: system,
                        toolSchemas: self.parsedToolSchemas,
                        maxTokens: 1024
                    )
                    continuation.resume(returning: result)
                } catch {
                    // Constrained decoding failed — fall through to unconstrained
                    continuation.resume(returning: nil as String?)
                }
            }
        }

        if let constrained { return constrained }

        // Unconstrained fallback: generate raw text, then parse
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

        \(OmegaToolRegistry.planningPromptBlock())

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
