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
        let constrained = try await withTimedMainActorBridge { [weak self] in
            guard let self, let cd = self.constrainedDecoding, cd.isAvailable else {
                return nil as String?
            }

            do {
                let system = systemPrompt ?? "You are a precise task planner. Output ONLY valid JSON array."
                let prompt = Self.buildPlanningPrompt(taskDescription: taskDescription)
                return try await cd.generateConstrainedPlan(
                    prompt: prompt,
                    systemPrompt: system,
                    toolSchemas: self.parsedToolSchemas,
                    maxTokens: 1024
                )
            } catch {
                // Constrained decoding failed — fall through to unconstrained
                return nil as String?
            }
        }

        if let constrained { return constrained }

        // Unconstrained fallback: generate raw text, then parse
        let prompt = Self.buildPlanningPrompt(taskDescription: taskDescription)
        let system = systemPrompt ?? "You are a precise task planner. Output ONLY valid JSON array. No explanation, no markdown, no code fences."

        let raw = try await withTimedMainActorBridge { [self] in
            try await self.triageService.generateRawLocal(
                prompt: prompt,
                systemPrompt: system,
                maxTokens: 1024
            )
        }

        return Self.stripThinkTags(raw)
    }

    // MARK: - Prompt Construction

    private nonisolated static func buildPlanningPrompt(taskDescription: String) -> String {
        let researchBlock = ResearchOrchestrator.isResearchTask(taskDescription)
            ? Self.researchPlanningBlock
            : ""

        return """
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
        \(researchBlock)

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

    /// Additional planning instructions injected when the task is a research task.
    private nonisolated static let researchPlanningBlock = """

    RESEARCH TASK RULES:
    1. Decompose the research question into 2-5 sub-questions that together answer the main question.
    2. For each sub-question, plan this sequence: search_web -> readpagecontent -> collectsnippet.
    3. For academic topics, use searchpapers instead of search_web for at least one sub-question.
    4. After collecting snippets from 2+ sources, use scoreevidence for each source URL.
    5. If two snippets appear to conflict, use analyzecontradiction to compare them.
    6. End with createresearchnote to synthesize all findings.
    7. Total steps: minimum 6, maximum 20. Never plan more than 3 consecutive web reads without a collectsnippet.
    8. Use savecitation for any source that contributes to the final note.
    9. Use "dependsOn" array to chain steps (e.g. readpagecontent depends on search_web step index).

    Research example:
    Request: "research: transformer attention vs Mamba-2"
    [{"description":"Search for transformer attention papers","agent":"safari","tool":"search_web","arguments":{"query":"transformer attention mechanisms 2024 2025"},"risk":"low"},{"description":"Extract page content","agent":"safari","tool":"readpagecontent","arguments":{"maxLength":4000},"risk":"low","dependsOn":[0]},{"description":"Collect key findings on attention","agent":"notes","tool":"collectsnippet","arguments":{"text":"[extracted text]","sourceUrl":"[url]","sourceTitle":"[title]"},"risk":"low","dependsOn":[1]},{"description":"Search for Mamba-2 papers","agent":"safari","tool":"searchpapers","arguments":{"query":"Mamba-2 selective scan state space model","yearMin":2024},"risk":"low"},{"description":"Score evidence quality","agent":"notes","tool":"scoreevidence","arguments":{"url":"https://arxiv.org/abs/2405.21060"},"risk":"low","dependsOn":[3]},{"description":"Create research note","agent":"notes","tool":"createresearchnote","arguments":{"question":"Transformer attention vs Mamba-2","findings":"Summary of comparison...","evidence":["Finding 1","Finding 2"],"citations":["Author et al. (2024). Paper Title. https://..."]},"risk":"low","dependsOn":[2,4]}]
    """

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
