import Foundation
import os

// MARK: - CostTracker
// Tracks API token usage and estimates cost per provider/model.
// Daily rolling totals persisted to UserDefaults.
// Optional budget guard: blocks API calls when daily spend exceeds threshold.

@MainActor @Observable
final class CostTracker {
    static let shared = CostTracker()

    // MARK: - Public State

    /// Today's accumulated usage across all providers.
    private(set) var todayUsage = DailyUsage()

    /// Per-provider breakdown for today.
    private(set) var providerBreakdown: [LLMProviderType: DailyUsage] = [:]

    /// User-configurable daily budget in USD. 0 = unlimited.
    var dailyBudgetUSD: Double {
        didSet { UserDefaults.standard.set(dailyBudgetUSD, forKey: Keys.budget) }
    }

    /// Whether we've exceeded the daily budget.
    var budgetExceeded: Bool { dailyBudgetUSD > 0 && todayUsage.estimatedCostUSD >= dailyBudgetUSD }

    // MARK: - Types

    struct DailyUsage: Codable, Sendable {
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var callCount: Int = 0
        var estimatedCostUSD: Double = 0.0
        var date: String = ""

        static func todayKey() -> String {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: Date())
        }
    }

    /// Token counts extracted from an API response.
    nonisolated struct TokenUsage: Sendable {
        let inputTokens: Int
        let outputTokens: Int
        let provider: LLMProviderType
        let model: String
    }

    // MARK: - Init

    private init() {
        dailyBudgetUSD = UserDefaults.standard.double(forKey: Keys.budget)
        loadToday()
    }

    // MARK: - Recording

    /// Record token usage from an API call. Thread-safe via MainActor.
    func record(_ usage: TokenUsage) {
        let cost = estimateCost(usage)

        todayUsage.inputTokens += usage.inputTokens
        todayUsage.outputTokens += usage.outputTokens
        todayUsage.callCount += 1
        todayUsage.estimatedCostUSD += cost

        var providerUsage = providerBreakdown[usage.provider] ?? DailyUsage()
        providerUsage.inputTokens += usage.inputTokens
        providerUsage.outputTokens += usage.outputTokens
        providerUsage.callCount += 1
        providerUsage.estimatedCostUSD += cost
        providerBreakdown[usage.provider] = providerUsage

        persist()

        let dailyTotal = todayUsage.estimatedCostUSD
        Log.pipeline.info(
            "💰 Cost: +\(usage.inputTokens)in/\(usage.outputTokens)out (\(usage.provider.rawValue)/\(usage.model.prefix(20))) ≈ $\(String(format: "%.4f", cost)) — daily total $\(String(format: "%.4f", dailyTotal))"
        )
    }

    /// Record usage from a nonisolated context (enrichment tasks).
    /// Use `CostTracker.recordFromBackground(_:)` instead of `shared.recordAsync()`.
    nonisolated static func recordFromBackground(_ usage: TokenUsage) {
        Task { @MainActor in
            CostTracker.shared.record(usage)
        }
    }

    /// Reset today's counters.
    func resetToday() {
        todayUsage = DailyUsage()
        todayUsage.date = DailyUsage.todayKey()
        providerBreakdown = [:]
        persist()
    }

    // MARK: - Cost Estimation

    /// Per-1M-token pricing (input, output) in USD.
    /// Updated Feb 2026. Rates are approximate; actual billing may differ.
    nonisolated static let pricing: [String: (input: Double, output: Double)] = [
        // Anthropic
        "claude-opus-4-6":     (15.0, 75.0),
        "claude-sonnet-4-6":   (3.0, 15.0),
        "claude-haiku-4-5":    (0.80, 4.0),
        // OpenAI
        "gpt-5.3":             (5.0, 15.0),
        "gpt-5.2":             (5.0, 15.0),
        "gpt-4.1":             (2.0, 8.0),
        "gpt-4.1-mini":        (0.40, 1.60),
        "o1-pro":              (150.0, 600.0),
        "o3":                  (10.0, 40.0),
        "o4-mini":             (1.10, 4.40),
        // Google
        "gemini-2.5-pro":      (1.25, 10.0),
        "gemini-2.5-flash":    (0.15, 0.60),
        // Kimi
        "kimi-k2.5":           (1.0, 4.0),
        // Ollama (local, free)
    ]

    private nonisolated func estimateCost(_ usage: TokenUsage) -> Double {
        guard let rates = Self.pricing[usage.model] else { return 0.0 }
        let inputCost = Double(usage.inputTokens) * rates.input / 1_000_000.0
        let outputCost = Double(usage.outputTokens) * rates.output / 1_000_000.0
        return inputCost + outputCost
    }

    // MARK: - Persistence

    private enum Keys {
        static let daily = "CostTracker.daily"
        static let providers = "CostTracker.providers"
        static let budget = "CostTracker.dailyBudget"
    }

    private func loadToday() {
        let today = DailyUsage.todayKey()
        if let data = UserDefaults.standard.data(forKey: Keys.daily),
           var saved = try? JSONDecoder().decode(DailyUsage.self, from: data),
           saved.date == today {
            todayUsage = saved
        } else {
            todayUsage = DailyUsage()
            todayUsage.date = today
        }

        if let pData = UserDefaults.standard.data(forKey: Keys.providers),
           let saved = try? JSONDecoder().decode([String: DailyUsage].self, from: pData) {
            // Reconstruct with LLMProviderType keys
            for (key, value) in saved where value.date == today {
                if let provider = LLMProviderType(rawValue: key) {
                    providerBreakdown[provider] = value
                }
            }
        }
    }

    private func persist() {
        todayUsage.date = DailyUsage.todayKey()
        if let data = try? JSONEncoder().encode(todayUsage) {
            UserDefaults.standard.set(data, forKey: Keys.daily)
        }
        // Persist provider breakdown with string keys
        var stringKeyed: [String: DailyUsage] = [:]
        for (provider, usage) in providerBreakdown {
            var u = usage
            u.date = todayUsage.date
            stringKeyed[provider.rawValue] = u
        }
        if let data = try? JSONEncoder().encode(stringKeyed) {
            UserDefaults.standard.set(data, forKey: Keys.providers)
        }
    }
}
