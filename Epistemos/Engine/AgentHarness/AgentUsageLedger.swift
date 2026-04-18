import Foundation

/// Per-model token usage breakdown. Ported from Multica's TaskUsageEntry —
/// we keep both input / output counts plus prompt-cache read / write counts
/// so the UI can show real "would this be cheaper with caching?" numbers.
nonisolated struct TokenUsage: Codable, Hashable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheReadTokens: Int
    var cacheWriteTokens: Int
    var costUSD: Double

    init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        costUSD: Double = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.costUSD = costUSD
    }

    static let zero = TokenUsage()

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }
}

/// Multi-model token ledger. Keyed by model ID (e.g., "claude-opus-4-7",
/// "qwen3.5-4b-4bit"). When a session resumes or two providers cooperate on
/// the same turn (planner + executor), mergeUsage combines both without
/// losing the per-model breakdown.
nonisolated struct UsageLedger: Codable, Equatable, Sendable {
    private(set) var byModel: [String: TokenUsage]

    init(byModel: [String: TokenUsage] = [:]) {
        self.byModel = byModel
    }

    static let empty = UsageLedger()

    var totalCostUSD: Double {
        byModel.values.reduce(0) { $0 + $1.costUSD }
    }

    var totalTokens: Int {
        byModel.values.reduce(0) { $0 + $1.totalTokens }
    }

    mutating func add(model: String, usage: TokenUsage) {
        var current = byModel[model, default: .zero]
        current.inputTokens += usage.inputTokens
        current.outputTokens += usage.outputTokens
        current.cacheReadTokens += usage.cacheReadTokens
        current.cacheWriteTokens += usage.cacheWriteTokens
        current.costUSD += usage.costUSD
        byModel[model] = current
    }

    mutating func mergeUsage(_ other: UsageLedger) {
        for (model, usage) in other.byModel {
            add(model: model, usage: usage)
        }
    }
}
