import Foundation

// MARK: - Omega Inference Bridge

/// Bridges the existing TriageService to the Omega agent system.
/// Follows the MLXInferenceBridge pattern: wraps generateRawLocal()
/// for agent reasoning, adds tool-call parsing on top.
///
/// Phase 4 (ToolCallParser) will enhance this with structured tool-call extraction.
@MainActor
final class OmegaInferenceBridge {
    private let triageService: TriageService

    init(triageService: TriageService) {
        self.triageService = triageService
    }

    /// Generate a planning response from the local model.
    nonisolated func generatePlan(
        taskDescription: String,
        availableAgents: [String],
        systemPrompt: String? = nil
    ) async throws -> String {
        let prompt = """
        You are a task planner for a macOS automation system.
        Available agents: \(availableAgents.joined(separator: ", "))

        User task: \(taskDescription)

        Respond with a JSON array of steps, each with:
        - "description": what this step does
        - "agent": which agent to use
        - "tool": which tool to call
        - "arguments": arguments object
        - "risk": "low", "medium", "high", or "critical"
        """

        let raw: String = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor [triageService] in
                do {
                    let result = try await triageService.generateRawLocal(
                        prompt: prompt,
                        systemPrompt: systemPrompt ?? "You are a task planning assistant. Output valid JSON only.",
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
