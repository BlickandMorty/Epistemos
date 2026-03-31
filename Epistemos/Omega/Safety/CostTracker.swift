import Foundation
import Observation

/// Tracks API costs in integer micro-dollars (1 micro-dollar = $0.000001)
/// to avoid floating-point precision loss. Per-model, per-session breakdown.
@MainActor @Observable
final class CostTracker {

    // MARK: - Types

    struct ModelPricing {
        /// Cost per 1M input tokens in micro-dollars
        let inputPerMillion: Int64
        /// Cost per 1M output tokens in micro-dollars
        let outputPerMillion: Int64
        /// Discount factor for cached input tokens (0.9 = 90% off)
        let cacheDiscount: Double
    }

    // MARK: - Pricing Table (March 2026)

    static let pricing: [String: ModelPricing] = [
        // Claude Sonnet 4.6: $3/$15 per M
        "claude_sonnet": ModelPricing(inputPerMillion: 3_000_000, outputPerMillion: 15_000_000, cacheDiscount: 0.9),
        "claude-sonnet-4-6": ModelPricing(inputPerMillion: 3_000_000, outputPerMillion: 15_000_000, cacheDiscount: 0.9),
        // Claude Opus 4.6: $15/$75 per M
        "claude_opus": ModelPricing(inputPerMillion: 15_000_000, outputPerMillion: 75_000_000, cacheDiscount: 0.9),
        "claude-opus-4-6": ModelPricing(inputPerMillion: 15_000_000, outputPerMillion: 75_000_000, cacheDiscount: 0.9),
        // Claude Haiku 4.5: $0.80/$4 per M
        "claude_haiku": ModelPricing(inputPerMillion: 800_000, outputPerMillion: 4_000_000, cacheDiscount: 0.9),
        "claude-haiku-4-5": ModelPricing(inputPerMillion: 800_000, outputPerMillion: 4_000_000, cacheDiscount: 0.9),
        // Perplexity Sonar Pro: $1/$5 per M (estimated)
        "perplexity": ModelPricing(inputPerMillion: 1_000_000, outputPerMillion: 5_000_000, cacheDiscount: 0.0),
        "sonar-pro": ModelPricing(inputPerMillion: 1_000_000, outputPerMillion: 5_000_000, cacheDiscount: 0.0),
    ]

    // MARK: - State

    /// Cumulative session cost in micro-dollars
    private(set) var sessionCostMicro: Int64 = 0
    /// Per-model breakdown
    private(set) var costByModel: [String: Int64] = [:]
    /// Number of API calls tracked
    private(set) var turnCount: Int = 0

    // MARK: - Public API

    /// Record a completed API turn with token counts.
    /// - Parameters:
    ///   - model: The model identifier (e.g., "claude_sonnet")
    ///   - inputTokens: Total input tokens (including cached)
    ///   - outputTokens: Output tokens generated
    ///   - cachedInputTokens: How many of the input tokens were cache hits
    func recordTurn(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cachedInputTokens: Int = 0
    ) {
        let fallback = ModelPricing(inputPerMillion: 3_000_000, outputPerMillion: 15_000_000, cacheDiscount: 0.9)
        let pricing = Self.pricing[model] ?? fallback
        let freshInput = max(0, inputTokens - cachedInputTokens)
        let cachedInput = max(0, cachedInputTokens)

        // Fresh input tokens at full price
        let freshCost = Int64(freshInput) * pricing.inputPerMillion / 1_000_000
        // Cached input tokens at discounted price
        let cachedCost = Int64(Double(cachedInput) * Double(pricing.inputPerMillion) * (1.0 - pricing.cacheDiscount)) / 1_000_000
        // Output tokens
        let outputCost = Int64(outputTokens) * pricing.outputPerMillion / 1_000_000

        let turnCost = freshCost + cachedCost + outputCost
        sessionCostMicro += turnCost
        costByModel[model, default: 0] += turnCost
        turnCount += 1
    }

    /// Reset session cost tracking (e.g., on new session).
    func reset() {
        sessionCostMicro = 0
        costByModel = [:]
        turnCount = 0
    }

    // MARK: - Display

    /// Session cost as a formatted dollar string (e.g., "$0.47").
    var formattedCost: String {
        let dollars = Double(sessionCostMicro) / 1_000_000.0
        if dollars < 0.01 {
            return String(format: "$%.4f", dollars)
        }
        return String(format: "$%.2f", dollars)
    }

    /// Per-model cost summary.
    var modelSummary: [(model: String, cost: String)] {
        costByModel.sorted(by: { $0.value > $1.value }).map { model, micro in
            let dollars = Double(micro) / 1_000_000.0
            return (model: model, cost: String(format: "$%.4f", dollars))
        }
    }
}
