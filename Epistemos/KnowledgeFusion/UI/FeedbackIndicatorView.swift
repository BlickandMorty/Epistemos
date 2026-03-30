import SwiftUI

// MARK: - FeedbackIndicatorView

/// Subtle status indicator showing when feedback data is being collected.
/// Small badge in the sidebar footer area. Non-intrusive.
/// Disappears when no adapter is active.
struct FeedbackIndicatorView: View {
    @Environment(KnowledgeFusionViewModel.self) private var vm

    @State private var showingPopover = false

    var body: some View {
        if vm.activeAdapter != nil {
            Button {
                showingPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Learning")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover) {
                feedbackPopover
            }
        }
    }

    @ViewBuilder
    private var feedbackPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feedback Collection")
                .font(.callout.weight(.medium))

            Text("Accepts and rejects are lightweight preference signals collected from adapter-assisted output. They help you see whether personalization is improving and can feed optional overnight training if you enable it.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let stats = vm.feedbackStats {
                HStack(spacing: 16) {
                    statItem(
                        icon: "hand.thumbsup.fill",
                        color: .green,
                        count: stats.totalAccepts,
                        label: "Accepts"
                    )
                    statItem(
                        icon: "hand.thumbsdown.fill",
                        color: .red,
                        count: stats.totalRejects,
                        label: "Rejects"
                    )
                }

                Text("\(stats.totalThisWeek) signals this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No feedback data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Preference training is optional and only runs overnight if you enable it in Agent Runtime settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 220)
    }

    private func statItem(icon: String, color: Color, count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.callout.monospaced().weight(.medium))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
