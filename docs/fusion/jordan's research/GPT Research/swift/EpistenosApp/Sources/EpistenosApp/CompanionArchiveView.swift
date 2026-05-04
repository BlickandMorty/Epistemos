import SwiftUI

struct CompanionArchiveView: View {
    @State private var archived = ["Orion", "Mira"]

    var body: some View {
        List {
            ForEach(archived, id: \.self) { companion in
                HStack {
                    Text(companion)
                    Spacer()
                    Button("Restore") { restore(companion) }
                }
            }
        }
    }

    private func restore(_ companion: String) {
        BiometricGate.authenticate(reason: "Restore companion \(companion)") { ok in
            if ok { Task { @MainActor in archived.removeAll { $0 == companion } } }
        }
    }
}
