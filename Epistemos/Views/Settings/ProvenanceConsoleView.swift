import SwiftUI

@MainActor
struct ProvenanceConsoleView: View {
    @State private var snapshot: ProvenanceConsoleSnapshot

    init() {
        _snapshot = State(initialValue: ProvenanceConsoleProjectionService().snapshot(limit: 40))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(snapshot.payloads) { payload in
                    GenUIDispatcher.shared.render(payload)
                }
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .onAppear { refresh() }
    }

    func refresh() {
        snapshot = ProvenanceConsoleProjectionService().snapshot(limit: 40)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Provenance Console")
                .font(.title3.weight(.semibold))
            Text("Read-only projection of committed RunEventLog, MutationEnvelope, AgentEvent, and GraphEvent planes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
