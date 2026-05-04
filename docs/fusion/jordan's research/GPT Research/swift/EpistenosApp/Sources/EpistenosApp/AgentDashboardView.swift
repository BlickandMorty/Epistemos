import SwiftUI

struct AgentDashboardView: View {
    private let rows = [
        ("CodeAgent", "idle", 0.20),
        ("ResearchAgent", "gated", 0.05),
        ("VerifyAgent", "ready", 0.40),
        ("AnalysisAgent", "ready", 0.65)
    ]

    var body: some View {
        VStack(alignment: .leading) {
            Text("VaultGatedSwarm").font(.headline)
            ForEach(rows, id: \.0) { name, state, budget in
                HStack {
                    Text(name).monospaced()
                    Spacer()
                    Text(state)
                    ProgressView(value: budget)
                        .frame(width: 120)
                }
            }
        }
    }
}
