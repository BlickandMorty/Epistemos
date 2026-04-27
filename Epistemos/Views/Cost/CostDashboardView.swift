import SwiftUI

// MARK: - W9.6 — Cost dashboard
//
// Surfaces `estimated_cost_usd` from `agent_core/src/session_insights.rs`
// per session + a per-session budget gate. When a session crosses
// the user-configured cap, the agent fires
// `SessionState::PausedForApproval` (W9.8) with `tool_name="budget_gate"`
// and the user is prompted to continue.
//
// Today this view reads from a Swift-side projection of session
// insights; full Rust → Swift wiring will reuse the existing
// agent_core JSON projection that the agent UI already consumes.

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
    public let provider: String    // claude / perplexity / local
    public let inputTokens: Int
    public let outputTokens: Int
    public let estimatedCostUSD: Double
    public let startedAt: Date

    public init(
        id: String,
        title: String,
        provider: String,
        inputTokens: Int,
        outputTokens: Int,
        estimatedCostUSD: Double,
        startedAt: Date
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.startedAt = startedAt
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
                Text("Per-session estimated cost in USD")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(totalCostString)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
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

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(entries) { entry in
                    row(for: entry)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for entry: CostDashboardEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.callout)
                    .lineLimit(1)
                Text("\(entry.provider) · \(entry.inputTokens) in / \(entry.outputTokens) out")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.estimatedCostUSD, format: .currency(code: "USD"))
                .font(.callout.monospacedDigit())
                .foregroundStyle(entry.estimatedCostUSD >= prefs.perSessionCapUSD ? .red : .primary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }

    private var totalCostString: String {
        let total = entries.reduce(0.0) { $0 + $1.estimatedCostUSD }
        return total.formatted(.currency(code: "USD"))
    }
}

#if DEBUG
#Preview {
    CostDashboardView(entries: [
        .init(id: "s1", title: "Refactor TextStorage layer", provider: "claude-opus-4-7",
              inputTokens: 12_400, outputTokens: 3_200, estimatedCostUSD: 0.42,
              startedAt: Date().addingTimeInterval(-3600)),
        .init(id: "s2", title: "Daily brief", provider: "claude-haiku-4-5",
              inputTokens: 800, outputTokens: 220, estimatedCostUSD: 0.01,
              startedAt: Date().addingTimeInterval(-7200)),
    ])
}
#endif
