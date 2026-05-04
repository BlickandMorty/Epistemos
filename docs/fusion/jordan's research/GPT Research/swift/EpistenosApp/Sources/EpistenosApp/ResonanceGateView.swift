import SwiftUI

struct ResonanceGateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resonance Gate").font(.headline)
            Grid(alignment: .leading) {
                GridRow { Text("Token"); Text("Tier"); Text("Claim"); Text("Decision") }.bold()
                GridRow { Text("#1024"); Text("L0"); Text("Prime"); Text("AcceptLocal") }
                GridRow { Text("#1025"); Text("L4"); Text("Composite"); Text("RequireEvidence") }
            }
            .font(.caption.monospaced())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Resonance Gate token classification table")
    }
}
