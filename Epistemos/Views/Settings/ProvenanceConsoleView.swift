import SwiftUI

@MainActor
struct ProvenanceConsoleView: View {
    @Environment(UIState.self) private var ui

    @State private var snapshot: ProvenanceConsoleSnapshot
    @State private var refreshRequestID = UUID()
    @State private var refreshTask: Task<Void, Never>?

    init() {
        _snapshot = State(initialValue: .empty)
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
        .onDisappear { cancelRefresh() }
    }

    func refresh() {
        refreshTask?.cancel()
        let requestID = UUID()
        refreshRequestID = requestID
        let service = ProvenanceConsoleProjectionService()
        refreshTask = Task { @MainActor in
            let nextSnapshot = await Task.detached(priority: .utility) {
                service.snapshot(limit: 40)
            }.value
            guard !Task.isCancelled, refreshRequestID == requestID else { return }
            snapshot = nextSnapshot
            refreshTask = nil
        }
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshRequestID = UUID()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            IntegrationBrandMarkView(brand: .provenance, size: 28)
                .foregroundStyle(ui.theme.resolved.accent.color)
            VStack(alignment: .leading, spacing: 4) {
                Text("Provenance Console")
                    .font(.title3.weight(.semibold))
                Text("Read-only projection of committed RunEventLog, MutationEnvelope, ClaimLedger retractions, AgentEvent, and GraphEvent planes.")
                    .font(.caption)
                    .foregroundStyle(ui.theme.resolved.mutedForeground.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
