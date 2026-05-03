import Foundation

/// Native token-dashboard surface for `/tokens` per
/// `HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` — Session row.
///
/// Reports per-direction token usage with optional context-window
/// fraction. **Core-safe**: pure value composition over already-known
/// session counters. Caller injects current values.
nonisolated struct HermesTokensCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> HermesTokensCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/tokens" else { return nil }
        return HermesTokensCommand()
    }

    func snapshot(from input: HermesTokenStatsInput) -> HermesTokenStats {
        let total = input.inputTokens + input.outputTokens
        let cacheTotal = input.cacheReadTokens + input.cacheWriteTokens
        let pct: Double? = input.contextWindowSize.flatMap { window in
            guard window > 0 else { return nil }
            return Double(input.messagesInContextTokens) / Double(window) * 100.0
        }
        return HermesTokenStats(
            inputTokens: input.inputTokens,
            outputTokens: input.outputTokens,
            totalTokens: total,
            cacheReadTokens: input.cacheReadTokens,
            cacheWriteTokens: input.cacheWriteTokens,
            cacheTotalTokens: cacheTotal,
            contextWindowSize: input.contextWindowSize,
            messagesInContextTokens: input.messagesInContextTokens,
            contextUtilizationPercent: pct,
            generatedAt: input.generatedAt ?? Date()
        )
    }
}

nonisolated struct HermesTokenStatsInput: Equatable, Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0
    var contextWindowSize: Int? = nil
    var messagesInContextTokens: Int = 0
    var generatedAt: Date? = nil
}

nonisolated struct HermesTokenStats: Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int
    let cacheTotalTokens: Int
    let contextWindowSize: Int?
    let messagesInContextTokens: Int
    let contextUtilizationPercent: Double?
    let generatedAt: Date

    func renderText() -> String {
        var lines: [String] = []
        lines.append("Token usage:")
        lines.append("  Input:              \(inputTokens)")
        lines.append("  Output:             \(outputTokens)")
        lines.append("  Total:              \(totalTokens)")
        if cacheTotalTokens > 0 {
            lines.append("  Cache read:         \(cacheReadTokens)")
            lines.append("  Cache write:        \(cacheWriteTokens)")
        }
        if let window = contextWindowSize {
            let pctStr = contextUtilizationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("  Context:            \(messagesInContextTokens) / \(window) (\(pctStr))")
        }
        return lines.joined(separator: "\n")
    }
}
