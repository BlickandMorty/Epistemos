import Foundation

// MARK: - Types

enum TrainingProfile: String, Sendable {
    case knowledge
    case style
    case mixed  // trains two separate adapters
}

struct TrainingProfileRecommendation: Sendable {
    let profile: TrainingProfile
    let knowledgePairCount: Int
    let stylePairCount: Int
    let toolPairCount: Int
    let totalPairs: Int
    let rationale: String
}

// MARK: - TrainingProfileManager

/// Analyzes the content distribution of JSONL training data and recommends
/// which training profile (knowledge, style, or mixed) to use.
///
/// Research paper hyperparameters (ANCHOR 2):
/// - Knowledge: rank=32, alpha=64, all 7 target modules, lr=2e-5
/// - Style: rank=8, alpha=16, attention-only, lr=1e-5
nonisolated struct TrainingProfileManager: Sendable {

    /// Analyze JSONL training data and recommend a profile.
    func recommend(
        knowledgePath: URL?,
        stylePath: URL?,
        toolPath: URL?
    ) throws -> TrainingProfileRecommendation {
        let knowledgeCount = try countLines(at: knowledgePath)
        let styleCount = try countLines(at: stylePath)
        let toolCount = try countLines(at: toolPath)
        let total = knowledgeCount + styleCount + toolCount

        guard total > 0 else {
            return TrainingProfileRecommendation(
                profile: .knowledge,
                knowledgePairCount: 0,
                stylePairCount: 0,
                toolPairCount: 0,
                totalPairs: 0,
                rationale: "No training data available"
            )
        }

        let styleRatio = Double(styleCount) / Double(total)
        let knowledgeRatio = Double(knowledgeCount + toolCount) / Double(total)

        let profile: TrainingProfile
        let rationale: String

        if styleRatio > 0.60 {
            profile = .style
            rationale = "Style pairs dominate (\(Int(styleRatio * 100))%); using style profile (rank=8, attention-only)"
        } else if knowledgeRatio > 0.60 {
            profile = .knowledge
            rationale = "Knowledge pairs dominate (\(Int(knowledgeRatio * 100))%); using knowledge profile (rank=32, attention+MLP)"
        } else {
            profile = .mixed
            rationale = "Mixed content distribution; training separate knowledge and style adapters"
        }

        return TrainingProfileRecommendation(
            profile: profile,
            knowledgePairCount: knowledgeCount,
            stylePairCount: styleCount,
            toolPairCount: toolCount,
            totalPairs: total,
            rationale: rationale
        )
    }

    // MARK: - Helpers

    private func countLines(at url: URL?) throws -> Int {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return 0 }
        let content = try String(contentsOf: url, encoding: .utf8)
        return content.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
    }
}
