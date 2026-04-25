import SwiftUI

/// Sticky card that surfaces the agent's current plan (from the Rust
/// `todo_write` tool) above the chat composer. Gives the user a live
/// view of what the model is working through — items flip to "in
/// progress" as the agent executes them and strike through on
/// completion, Claude-Code-style.
///
/// Collapsible to keep the composer area compact once the plan is
/// understood; the header always shows "X of Y complete" even when
/// folded so the progress stays glanceable.
struct TodoSnapshotCard: View {
    let snapshot: TodoSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                Divider().opacity(0.15)
                items
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let inProgress = snapshot.inProgressItem {
                        Text(inProgress.activeForm)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(progressSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(progressBadge)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(snapshot.items) { item in
                HStack(alignment: .top, spacing: 8) {
                    statusIcon(for: item.status)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 14, alignment: .center)
                        .foregroundStyle(color(for: item.status))

                    Text(item.content)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .strikethrough(
                            item.status == .completed || item.status == .cancelled,
                            color: .secondary
                        )
                        .opacity(item.status == .cancelled ? 0.55 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Derived

    private var progressSummary: String {
        let total = snapshot.items.count
        let done = snapshot.completedCount
        return "\(done) of \(total) complete"
    }

    private var progressBadge: String {
        "\(snapshot.completedCount)/\(snapshot.items.count)"
    }

    private func statusIcon(for status: TodoStatus) -> Image {
        switch status {
        case .pending: Image(systemName: "circle")
        case .inProgress: Image(systemName: "circle.dotted")
        case .completed: Image(systemName: "checkmark.circle.fill")
        case .cancelled: Image(systemName: "xmark.circle")
        }
    }

    private func color(for status: TodoStatus) -> Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .orange
        case .completed: .green
        case .cancelled: .secondary.opacity(0.55)
        }
    }
}
