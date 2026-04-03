import Foundation

// MARK: - MLXInferenceBridge

/// Bridges the existing TriageService to the KFInferenceProvider protocol,
/// enabling the Knowledge Fusion pipeline to use the app's live inference engine.
///
/// Uses `generateRawLocal` to bypass the `UserFacingModelOutput.finalVisibleText`
/// stripping that removes structured content needed for synthetic data generation.
@MainActor
final class MLXInferenceBridge: KFInferenceProvider {
    private let triageService: TriageService

    init(triageService: TriageService) {
        self.triageService = triageService
    }

    nonisolated func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        let raw = try await withTimedMainActorBridge { [self] in
            try await self.triageService.generateRawLocal(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        }

        // Strip <think>...</think> tags but preserve the actual content outside them
        return Self.stripThinkTags(raw)
    }

    /// Removes `<think>...</think>` blocks that Qwen/reasoning models emit,
    /// preserving only the actual answer content.
    private nonisolated static func stripThinkTags(_ text: String) -> String {
        var result = text

        // Remove complete <think>...</think> blocks
        while let thinkStart = result.range(of: "<think>", options: .caseInsensitive),
              let thinkEnd = result.range(of: "</think>", options: .caseInsensitive, range: thinkStart.upperBound..<result.endIndex) {
            result.removeSubrange(thinkStart.lowerBound..<thinkEnd.upperBound)
        }

        // Remove orphan opening <think> at the start (incomplete thinking)
        if let thinkStart = result.range(of: "<think>", options: .caseInsensitive) {
            if result.range(of: "</think>", options: .caseInsensitive) == nil {
                result.removeSubrange(thinkStart.lowerBound..<result.endIndex)
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
