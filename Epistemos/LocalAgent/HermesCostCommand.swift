import Foundation

/// Native cost-dashboard surface for `/cost` per
/// `HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` — Session row.
///
/// Reports cumulative and per-provider cost. **Core-safe**: pure value
/// composition. Caller injects current values from the existing
/// `AgentUsageLedger` in `Epistemos/Engine/AgentHarness/`.
nonisolated struct HermesCostCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> HermesCostCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/cost" else { return nil }
        return HermesCostCommand()
    }

    func snapshot(from input: HermesCostStatsInput) -> HermesCostStats {
        let cumulative = input.perProviderUSD.values.reduce(0, +) + input.localOnlyExtraUSD
        let mostExpensive = input.perProviderUSD.max { $0.value < $1.value }
        return HermesCostStats(
            sessionCostUSD: input.sessionCostUSD,
            cumulativeCostUSD: cumulative,
            perProviderUSD: input.perProviderUSD,
            mostExpensiveProvider: mostExpensive?.key,
            mostExpensiveProviderUSD: mostExpensive?.value ?? 0,
            localOnlyExtraUSD: input.localOnlyExtraUSD,
            generatedAt: input.generatedAt ?? Date()
        )
    }
}

nonisolated struct HermesCostStatsInput: Equatable, Sendable {
    /// Cost incurred in the current session only.
    var sessionCostUSD: Double = 0
    /// Cumulative cost broken down per provider name (e.g. "openai", "anthropic").
    var perProviderUSD: [String: Double] = [:]
    /// Any cost-equivalent for local-model wear-and-tear (energy / wear), if tracked.
    var localOnlyExtraUSD: Double = 0
    var generatedAt: Date? = nil
}

nonisolated struct HermesCostStats: Equatable, Sendable {
    let sessionCostUSD: Double
    let cumulativeCostUSD: Double
    let perProviderUSD: [String: Double]
    let mostExpensiveProvider: String?
    let mostExpensiveProviderUSD: Double
    let localOnlyExtraUSD: Double
    let generatedAt: Date

    func renderText() -> String {
        var lines: [String] = []
        lines.append("API cost:")
        lines.append("  This session:       $\(String(format: "%.4f", sessionCostUSD))")
        lines.append("  Cumulative total:   $\(String(format: "%.4f", cumulativeCostUSD))")
        if !perProviderUSD.isEmpty {
            lines.append("  By provider:")
            for (provider, cost) in perProviderUSD.sorted(by: { $0.value > $1.value }) {
                lines.append("    \(provider):           $\(String(format: "%.4f", cost))")
            }
        }
        if let top = mostExpensiveProvider, mostExpensiveProviderUSD > 0 {
            lines.append("  Top provider:       \(top) ($\(String(format: "%.4f", mostExpensiveProviderUSD)))")
        }
        if localOnlyExtraUSD > 0 {
            lines.append("  Local extra:        $\(String(format: "%.4f", localOnlyExtraUSD))")
        }
        return lines.joined(separator: "\n")
    }
}
