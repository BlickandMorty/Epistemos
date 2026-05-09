import SwiftUI

// MARK: - W9.6 — Cost dashboard
//
// Surfaces tracked session token/cache telemetry and, when available, tracked
// cost estimates. Missing cost/provider data is rendered as unavailable rather
// than as a synthetic $0.00 row.

@MainActor
@Observable
public final class BudgetPreferences {
    public static let shared = BudgetPreferences()

    private let key = "epistemos.budget.perSessionUSD"
    public var perSessionCapUSD: Double {
        didSet {
            UserDefaults.standard.set(perSessionCapUSD, forKey: key)
        }
    }

    private init() {
        let stored = UserDefaults.standard.double(forKey: key)
        self.perSessionCapUSD = stored > 0 ? stored : 0.50
    }
}

public struct CostDashboardEntry: Identifiable, Sendable, Hashable {
    public let id: String          // session id
    public let title: String
    public let provider: String?   // claude / perplexity / local, when tracked
    public let inputTokens: Int
    public let outputTokens: Int
    public let estimatedCostUSD: Double?
    public let startedAt: Date

    // N1 Phase 1 — Anthropic prompt-cache telemetry (default 0
    // for non-Anthropic providers; sourced from
    // agent_core/src/session_insights.rs SessionMetrics fields).
    public let cacheReadInputTokens: Int
    public let cacheCreationInputTokens: Int

    /// Computed: fraction of input tokens served from the prompt cache.
    /// Mirrors `SessionMetrics::cached_tokens_share` on the Rust side.
    /// Returns 0.0 when total billed input is 0.
    public var cachedTokensShare: Double {
        let total = inputTokens + cacheReadInputTokens
        guard total > 0 else { return 0.0 }
        return min(max(Double(cacheReadInputTokens) / Double(total), 0.0), 1.0)
    }

    public init(
        id: String,
        title: String,
        provider: String? = nil,
        inputTokens: Int,
        outputTokens: Int,
        estimatedCostUSD: Double? = nil,
        startedAt: Date,
        cacheReadInputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.startedAt = startedAt
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }
}

public struct CostDashboardView: View {

    let entries: [CostDashboardEntry]
    @Bindable private var prefs = BudgetPreferences.shared

    public init(entries: [CostDashboardEntry]) {
        self.entries = entries
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            cacheHitRateRow
            Divider()
            budgetEditor
            Divider()
            list
        }
        .padding(20)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent spend")
                    .font(.title3.weight(.semibold))
                Text("Token usage and tracked spend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(totalCostString)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .help(totalCostHelp)
        }
    }

    /// N1 Phase 1 — aggregate prompt-cache hit rate across all
    /// sessions in this dashboard. Sourced from
    /// `agent_core/src/session_insights.rs::AggregatedStats::aggregate_cached_tokens_share`
    /// (mirrored client-side here so the dashboard works
    /// identically when the FFI bridge isn't yet plumbed). The
    /// metric is the load-bearing N1 success signal per
    /// `docs/PROMPT_AS_DATA_SPEC.md §3` — Anthropic charges 90 %
    /// less for cached prefix tokens, so this ratio directly
    /// reflects the Relocation Trick's cost savings.
    @ViewBuilder
    private var cacheHitRateRow: some View {
        if aggregateBilledInput > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "bolt.shield")
                    .foregroundStyle(cacheTint)
                    .font(.caption)
                Text("Cache hit rate")
                    .font(.callout.weight(.medium))
                Spacer()
                Text(aggregateCachedShare, format: .percent.precision(.fractionLength(1)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(cacheTint)
                Text("\(totalCacheReadTokens.formatted(.number)) / \(aggregateBilledInput.formatted(.number)) tokens")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(cacheTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .help(cacheHelpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cacheAccessibilityLabel)
        } else {
            // Empty / Anthropic-cache-untouched session set.
            // Honest "no signal yet" placeholder per
            // PLAN_V2.md §3.4 — show that the metric exists but
            // hasn't accumulated data, instead of hiding it.
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("Cache hit rate")
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text("—")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(emptyCacheCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .help(cacheHelpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cache hit rate not yet measured. \(emptyCacheCaption).")
        }
    }

    private var budgetEditor: some View {
        HStack {
            Label("Per-session cap", systemImage: "lock.shield")
                .font(.callout)
            Spacer()
            TextField(
                "USD",
                value: $prefs.perSessionCapUSD,
                format: .currency(code: "USD")
            )
            .frame(width: 100)
            .textFieldStyle(.roundedBorder)
        }
        .help("When a session crosses this cap, the agent pauses and asks for approval.")
    }

    @ViewBuilder
    private var list: some View {
        if entries.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(entries) { entry in
                        row(for: entry)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No agent runs yet")
                .font(.callout.weight(.medium))
            Text("Completed sessions appear here with their token usage and estimated cost.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No agent runs yet. Completed sessions appear here.")
    }

    @ViewBuilder
    private func row(for entry: CostDashboardEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.callout)
                    .lineLimit(1)
                Text(rowSubtitle(for: entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(costString(for: entry))
                .font(.callout.monospacedDigit())
                .foregroundStyle(costTint(for: entry))
                .help(costHelp(for: entry))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }

    private var totalCostString: String {
        guard hasTrackedCosts else { return "—" }
        let total = entries.reduce(0.0) { $0 + ($1.estimatedCostUSD ?? 0) }
        return total.formatted(.currency(code: "USD"))
    }

    private var totalCostHelp: String {
        hasTrackedCosts
            ? "Total of tracked per-session cost estimates."
            : "Session metrics do not yet include provider cost estimates."
    }

    private var hasTrackedCosts: Bool {
        entries.contains { $0.estimatedCostUSD != nil }
    }

    private func rowSubtitle(for entry: CostDashboardEntry) -> String {
        let tokenSummary = "\(entry.inputTokens) in / \(entry.outputTokens) out"
        guard let provider = entry.provider?.trimmingCharacters(in: .whitespacesAndNewlines),
              !provider.isEmpty
        else {
            return tokenSummary
        }
        return "\(provider) · \(tokenSummary)"
    }

    private func costString(for entry: CostDashboardEntry) -> String {
        guard let estimatedCostUSD = entry.estimatedCostUSD else { return "Not tracked" }
        return estimatedCostUSD.formatted(.currency(code: "USD"))
    }

    private func costTint(for entry: CostDashboardEntry) -> Color {
        guard let estimatedCostUSD = entry.estimatedCostUSD else { return .secondary }
        return estimatedCostUSD >= prefs.perSessionCapUSD ? .red : .primary
    }

    private func costHelp(for entry: CostDashboardEntry) -> String {
        entry.estimatedCostUSD == nil
            ? "This session record has token telemetry but no provider cost estimate."
            : "Tracked per-session cost estimate."
    }

    // MARK: - Cache hit rate aggregation (N1 Phase 1)

    private var totalInputTokens: Int {
        entries.reduce(0) { $0 + $1.inputTokens }
    }

    private var totalCacheReadTokens: Int {
        entries.reduce(0) { $0 + $1.cacheReadInputTokens }
    }

    private var aggregateBilledInput: Int {
        totalInputTokens + totalCacheReadTokens
    }

    private var aggregateCachedShare: Double {
        guard aggregateBilledInput > 0 else { return 0.0 }
        return min(max(Double(totalCacheReadTokens) / Double(aggregateBilledInput), 0.0), 1.0)
    }

    /// Color the metric green when ≥30 % cached (the bake-in
    /// threshold from PROMPT_AS_DATA_SPEC.md §6 — N1's success
    /// criterion), orange when 0 < x < 30 % (signal but below the
    /// promised win), gray when 0 % (no Anthropic activity yet).
    private var cacheTint: Color {
        if aggregateCachedShare >= 0.30 { return .green }
        if aggregateCachedShare > 0 { return .orange }
        return .secondary
    }

    private var emptyCacheCaption: String {
        entries.isEmpty
            ? "Awaiting first agent run"
            : "No Anthropic prompt-cache activity yet"
    }

    private var cacheHelpText: String {
        "Anthropic charges 90% less for input tokens served from the prompt cache. Sustained ≥30% means the prompt tree is shaped efficiently."
    }

    private var cacheAccessibilityLabel: String {
        let pct = aggregateCachedShare.formatted(.percent.precision(.fractionLength(1)))
        let cached = totalCacheReadTokens.formatted(.number)
        let billed = aggregateBilledInput.formatted(.number)
        return "Cache hit rate \(pct), \(cached) of \(billed) input tokens served from cache."
    }
}

#if DEBUG
#Preview {
    CostDashboardView(entries: [
        .init(id: "s1", title: "Refactor TextStorage layer", provider: "claude-opus-4-7",
              inputTokens: 2_400, outputTokens: 3_200, estimatedCostUSD: 0.42,
              startedAt: Date().addingTimeInterval(-3600),
              cacheReadInputTokens: 10_000,           // 80 % cache hit
              cacheCreationInputTokens: 0),
        .init(id: "s2", title: "Daily brief", provider: "claude-haiku-4-5",
              inputTokens: 800, outputTokens: 220, estimatedCostUSD: 0.01,
              startedAt: Date().addingTimeInterval(-7200),
              cacheReadInputTokens: 0,                 // pre-N1 / cold session
              cacheCreationInputTokens: 0),
    ])
}
#endif
