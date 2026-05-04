import SwiftUI

struct SimulationLandingFarmView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var companions: [String] = ["Atlas", "Lyra", "Hermes"]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Landing Farm").font(.largeTitle.bold())
            Text("Deterministic companion surface. Reduce-motion uses state badges instead of animation.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))]) {
                ForEach(companions, id: \.self) { name in
                    VStack {
                        Circle().frame(width: 64, height: 64)
                            .scaleEffect(reduceMotion ? 1.0 : 1.04)
                        Text(name).bold()
                        Text(reduceMotion ? "state: idle" : "idle breathing")
                            .font(.caption)
                    }
                    .contextMenu {
                        Button("Archive", role: .destructive) { archive(name) }
                    }
                }
            }
        }
        .padding()
    }

    private func archive(_ name: String) {
        BiometricGate.authenticate(reason: "Archive companion \(name)") { ok in
            if ok { Task { @MainActor in companions.removeAll { $0 == name } } }
        }
    }
}

struct CompanionManagerView: View {
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Companions").font(.title)
            TextField("New companion name", text: $newName)
            Button("Create New") { newName = "" }
            Text("Every cosmetic choice must map to config or be labeled cosmetic.")
                .font(.caption)
        }
        .padding()
        .frame(width: 420)
    }
}
