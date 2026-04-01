import Foundation
import Observation

/// Tracks API costs in integer micro-dollars (1 micro-dollar = $0.000001)
/// to avoid floating-point precision loss. Per-model, per-session, and per-agent breakdown.
///
/// Supports three budget tiers (Paperclip pattern):
///   1. **Session budget** — hard cap for the current interactive session.
///   2. **Per-agent budget** — individual caps per agent/provider identity.
///   3. **Rolling daily budget** — resets every 24h to bound cumulative spend.
///
/// **Pre-turn gating**: call `canAffordTurn(model:estimatedInputTokens:estimatedOutputTokens:)`
/// BEFORE dispatching a turn to avoid wasted API round-trips.
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

    /// Per-agent budget configuration.
    struct AgentBudget {
        /// Agent/provider identifier (e.g., "claude_sonnet", "github_reviewer").
        let agentId: String
        /// Maximum cost in micro-dollars for this agent. 0 = unlimited.
        var capMicro: Int64
        /// Accumulated cost in micro-dollars.
        private(set) var spentMicro: Int64 = 0

        var isExceeded: Bool { capMicro > 0 && spentMicro >= capMicro }
        var remainingMicro: Int64 { capMicro > 0 ? max(0, capMicro - spentMicro) : Int64.max }

        mutating func record(_ cost: Int64) { spentMicro += cost }
        mutating func reset() { spentMicro = 0 }

        var formatted: String {
            let spent = Double(spentMicro) / 1_000_000.0
            let cap = Double(capMicro) / 1_000_000.0
            return capMicro > 0
                ? String(format: "$%.2f / $%.2f", spent, cap)
                : String(format: "$%.2f (unlimited)", spent)
        }
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
        // Local models: free (no API cost)
        "local": ModelPricing(inputPerMillion: 0, outputPerMillion: 0, cacheDiscount: 0.0),
    ]

    // MARK: - Session Budget Enforcement (Paperclip pattern)

    /// Maximum session cost in micro-dollars before the agent is interrupted.
    /// Default: $5.00 = 5_000_000 micro-dollars. Set to 0 for unlimited.
    var budgetCapMicro: Int64 = 5_000_000

    /// True when the session cost has exceeded the budget cap.
    var isBudgetExceeded: Bool {
        budgetCapMicro > 0 && sessionCostMicro >= budgetCapMicro
    }

    /// Remaining budget in micro-dollars. Returns Int64.max if unlimited.
    var remainingBudgetMicro: Int64 {
        guard budgetCapMicro > 0 else { return Int64.max }
        return max(0, budgetCapMicro - sessionCostMicro)
    }

    /// Budget as formatted string (e.g., "$3.21 / $5.00").
    var formattedBudget: String {
        guard budgetCapMicro > 0 else { return formattedCost }
        let spent = Double(sessionCostMicro) / 1_000_000.0
        let cap = Double(budgetCapMicro) / 1_000_000.0
        return String(format: "$%.2f / $%.2f", spent, cap)
    }

    // MARK: - Per-Agent Budget Enforcement

    /// Per-agent budgets, keyed by agent identifier.
    var agentBudgets: [String: AgentBudget] = [:]

    /// Set a budget cap for a specific agent. Pass 0 to remove the cap.
    func setAgentBudget(agentId: String, capMicro: Int64) {
        if capMicro <= 0 {
            agentBudgets.removeValue(forKey: agentId)
        } else {
            if agentBudgets[agentId] != nil {
                agentBudgets[agentId]?.capMicro = capMicro
            } else {
                agentBudgets[agentId] = AgentBudget(agentId: agentId, capMicro: capMicro)
            }
        }
    }

    /// Check if a specific agent has exceeded its budget.
    func isAgentBudgetExceeded(agentId: String) -> Bool {
        agentBudgets[agentId]?.isExceeded ?? false
    }

    // MARK: - Rolling Daily Budget

    /// Maximum daily spend in micro-dollars. Default: $20.00. Set to 0 for unlimited.
    var dailyBudgetCapMicro: Int64 = 20_000_000

    /// Accumulated daily spend.
    private(set) var dailySpentMicro: Int64 = 0

    /// Date of the current daily budget window.
    private var dailyResetDate: Date = Calendar.current.startOfDay(for: Date())

    var isDailyBudgetExceeded: Bool {
        dailyBudgetCapMicro > 0 && dailySpentMicro >= dailyBudgetCapMicro
    }

    var formattedDailyBudget: String {
        guard dailyBudgetCapMicro > 0 else { return formattedCost }
        let spent = Double(dailySpentMicro) / 1_000_000.0
        let cap = Double(dailyBudgetCapMicro) / 1_000_000.0
        return String(format: "$%.2f / $%.2f today", spent, cap)
    }

    private func rollDailyBudgetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if today > dailyResetDate {
            dailySpentMicro = 0
            dailyResetDate = today
        }
    }

    // MARK: - State

    /// Cumulative session cost in micro-dollars
    private(set) var sessionCostMicro: Int64 = 0
    /// Per-model breakdown
    private(set) var costByModel: [String: Int64] = [:]
    /// Number of API calls tracked
    private(set) var turnCount: Int = 0

    // MARK: - Pre-Turn Budget Gating

    /// Estimate the cost of a turn and check all budget tiers BEFORE dispatching.
    /// Returns nil if the turn is affordable, or a human-readable reason if blocked.
    func canAffordTurn(
        model: String,
        estimatedInputTokens: Int = 4000,
        estimatedOutputTokens: Int = 1000,
        agentId: String? = nil
    ) -> String? {
        rollDailyBudgetIfNeeded()

        let pricing = Self.pricing[model] ?? ModelPricing(
            inputPerMillion: 3_000_000, outputPerMillion: 15_000_000, cacheDiscount: 0.9
        )
        let estimatedCost =
            Int64(estimatedInputTokens) * pricing.inputPerMillion / 1_000_000
            + Int64(estimatedOutputTokens) * pricing.outputPerMillion / 1_000_000

        // Check session budget
        if budgetCapMicro > 0, sessionCostMicro + estimatedCost > budgetCapMicro {
            return "Session budget would be exceeded (\(formattedBudget))"
        }

        // Check daily budget
        if dailyBudgetCapMicro > 0, dailySpentMicro + estimatedCost > dailyBudgetCapMicro {
            return "Daily budget would be exceeded (\(formattedDailyBudget))"
        }

        // Check per-agent budget
        if let agentId, let budget = agentBudgets[agentId] {
            if budget.capMicro > 0, budget.spentMicro + estimatedCost > budget.capMicro {
                return "Agent '\(agentId)' budget would be exceeded (\(budget.formatted))"
            }
        }

        return nil
    }

    // MARK: - Public API

    /// Record a completed API turn with token counts.
    /// - Parameters:
    ///   - model: The model identifier (e.g., "claude_sonnet")
    ///   - inputTokens: Total input tokens (including cached)
    ///   - outputTokens: Output tokens generated
    ///   - cachedInputTokens: How many of the input tokens were cache hits
    ///   - agentId: Optional agent identifier for per-agent budget tracking
    func recordTurn(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cachedInputTokens: Int = 0,
        agentId: String? = nil
    ) {
        rollDailyBudgetIfNeeded()

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
        dailySpentMicro += turnCost
        costByModel[model, default: 0] += turnCost
        turnCount += 1

        // Per-agent tracking
        if let agentId {
            agentBudgets[agentId]?.record(turnCost)
        }
    }

    /// Reset session cost tracking (e.g., on new session).
    /// Does NOT reset daily budget or per-agent budgets.
    func reset() {
        sessionCostMicro = 0
        costByModel = [:]
        turnCount = 0
    }

    /// Reset all budgets including daily and per-agent.
    func resetAll() {
        reset()
        dailySpentMicro = 0
        for key in agentBudgets.keys {
            agentBudgets[key]?.reset()
        }
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

    /// Per-agent budget summary for UI display.
    var agentBudgetSummary: [(agentId: String, status: String, exceeded: Bool)] {
        agentBudgets.values
            .sorted(by: { $0.agentId < $1.agentId })
            .map { ($0.agentId, $0.formatted, $0.isExceeded) }
    }
}
