import SwiftUI

@MainActor
struct ProvenanceConsoleView: View {
    @State private var snapshot: ProvenanceConsoleSnapshot
    /// UI/UX audit 2026-05-17 P2-2 (iter 4): the initial 40-entry cap
    /// was silently chopping the ledger for long debugging sessions.
    /// Track the current limit so the user can grow the window with
    /// the "Load 40 more" affordance below.
    @State private var currentLimit: Int = 40

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
                loadMoreButton
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .onAppear { refresh() }
    }

    func refresh() {
        snapshot = ProvenanceConsoleProjectionService().snapshot(limit: currentLimit)
    }

    private var loadMoreButton: some View {
        HStack {
            Spacer()
            Button {
                currentLimit += 40
                refresh()
            } label: {
                Label("Load 40 more", systemImage: "arrow.down.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Grow the window by another 40 entries per plane")
            .accessibilityLabel("Load 40 more provenance entries")
            Text("Showing up to \(currentLimit) per plane")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Provenance Console")
                    .font(.title3.weight(.semibold))
                Spacer()
                // UI/UX audit 2026-05-17 P2-1 (iter 4):
                // ProvenanceConsoleView previously read its snapshot only
                // on .onAppear, so new ledger / agent / graph events that
                // landed while Settings was open never surfaced — the
                // freshness model was silently stale. A user-controlled
                // refresh closes the gap without introducing background
                // poll cost.
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Re-read the latest projection from the EventStore + ledger")
                .accessibilityLabel("Refresh provenance projection")
            }
            Text("Read-only projection of committed RunEventLog, MutationEnvelope, ClaimLedger retractions, AgentEvent, and GraphEvent planes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
