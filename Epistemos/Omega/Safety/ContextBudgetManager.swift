import Foundation
import os

private let budgetLog = Logger(subsystem: "com.epistemos", category: "ContextBudgetManager")

// MARK: - Context Budget Manager
// Tracks cumulative token usage across multi-step agent plans.
// Triggers compaction when usage exceeds configurable thresholds.
// Prevents context-window exhaustion and truncation-based hallucinations.
//
// Ported from OpenClaw's context budgeting pattern + LocalAgent 5-phase compaction trigger logic.

@MainActor
final class ContextBudgetManager {

    // MARK: - Configuration

    struct Config: Sendable {
        /// Max context tokens before triggering compaction.
        var maxContextTokens: Int = 128_000
        /// Trigger compaction at this fraction of maxContextTokens (0.0–1.0).
        var compactionThreshold: Double = 0.70
        /// Reserve this many tokens for the system prompt (never compacted).
        var systemPromptReserve: Int = 4_000
        /// Reserve this many tokens for tool definitions.
        var toolDefinitionReserve: Int = 2_000
        /// Max tokens for a single tool result before truncation.
        var maxToolResultTokens: Int = 4_096
    }

    enum BudgetStatus: Sendable, Equatable {
        case ok(usedFraction: Double)
        case warning(usedFraction: Double)
        case critical(usedFraction: Double)
        case exceeded(usedFraction: Double)
    }

    // MARK: - State

    private(set) var cumulativeInputTokens: Int = 0
    private(set) var cumulativeOutputTokens: Int = 0
    private(set) var turnCount: Int = 0
    private(set) var compactionCount: Int = 0
    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    func reset() {
        cumulativeInputTokens = 0
        cumulativeOutputTokens = 0
        turnCount = 0
        compactionCount = 0
    }

    // MARK: - Token Tracking

    /// Record token usage from a completed turn.
    func recordTurn(inputTokens: Int, outputTokens: Int) {
        cumulativeInputTokens += inputTokens
        cumulativeOutputTokens += outputTokens
        turnCount += 1
    }

    /// Estimated current context size (input tokens is the proxy).
    var estimatedContextTokens: Int {
        cumulativeInputTokens
    }

    /// Available tokens remaining before hitting the max.
    var availableTokens: Int {
        let used = estimatedContextTokens + config.systemPromptReserve + config.toolDefinitionReserve
        return max(0, config.maxContextTokens - used)
    }

    /// Current budget status.
    var status: BudgetStatus {
        let fraction = Double(estimatedContextTokens) / Double(config.maxContextTokens)
        switch fraction {
        case ..<0.5:
            return .ok(usedFraction: fraction)
        case 0.5..<config.compactionThreshold:
            return .warning(usedFraction: fraction)
        case config.compactionThreshold..<1.0:
            return .critical(usedFraction: fraction)
        default:
            return .exceeded(usedFraction: fraction)
        }
    }

    /// Whether compaction should be triggered now.
    var shouldCompact: Bool {
        let fraction = Double(estimatedContextTokens) / Double(config.maxContextTokens)
        return fraction >= config.compactionThreshold
    }

    /// Record that compaction occurred. Adjusts token estimate.
    func recordCompaction(newInputTokenEstimate: Int) {
        compactionCount += 1
        cumulativeInputTokens = newInputTokenEstimate
        budgetLog.info("Context compacted (\(self.compactionCount)x). New estimate: \(newInputTokenEstimate) tokens")
    }

    // MARK: - Tool Result Budgeting

    /// Truncate a tool result string to fit within the per-result token budget.
    func truncateToolResult(_ result: String) -> String {
        let estimatedTokens = result.count / 4
        guard estimatedTokens > config.maxToolResultTokens else { return result }

        let maxChars = config.maxToolResultTokens * 4
        let half = maxChars / 2
        let truncated = result.count - maxChars
        return String(result.prefix(half))
            + "\n\n[... \(truncated) chars truncated by context budget ...]\n\n"
            + String(result.suffix(half))
    }

    // MARK: - Thinking Budget by Turn

    /// Adaptive thinking token budget: deep planning on turn 1, lighter on later turns.
    func thinkingBudget(forTurn turn: Int) -> Int {
        switch turn {
        case 1: return 8_000
        case 2...5: return 2_000
        default: return 500
        }
    }

    // MARK: - Summary

    var summary: String {
        let fraction = config.maxContextTokens > 0 ? Double(estimatedContextTokens) / Double(config.maxContextTokens) : 0.0
        return "Context: \(estimatedContextTokens)/\(config.maxContextTokens) tokens (\(fraction.isFinite ? Int(fraction * 100) : 0)%), "
            + "\(turnCount) turns, \(compactionCount) compactions"
    }
}
