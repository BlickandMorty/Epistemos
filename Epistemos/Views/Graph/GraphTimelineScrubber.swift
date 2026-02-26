import SwiftUI

// MARK: - GraphTimelineScrubber
// Timeline slider overlay for filtering graph nodes by creation date.
// Positioned at the bottom of the graph canvas.

struct GraphTimelineScrubber: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    @State private var isExpanded = false
    @State private var scrubDate: Date = .now

    private var theme: EpistemosTheme { ui.theme }

    /// Earliest node creation date in the store (or a reasonable default).
    private var earliestDate: Date {
        graphState.store.nodes.values.map(\.createdAt).min() ?? Calendar.current.date(
            byAdding: .year, value: -1, to: .now
        )!
    }

    private var latestDate: Date { Date.now }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                scrubberContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            toggleButton
        }
        .animation(Motion.quick, value: isExpanded)
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button {
            withAnimation(Motion.quick) {
                isExpanded.toggle()
                if !isExpanded {
                    // Clear timeline filter when collapsing
                    graphState.filter.setTimelineDate(nil)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "clock.fill" : "clock")
                    .font(.system(size: 12, weight: .medium))
                Text("Timeline")
                    .font(.epCaption)
            }
            .foregroundStyle(isExpanded ? theme.accent : theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isExpanded ? theme.accent.opacity(0.3) : theme.glassBorder,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scrubber Content

    private var scrubberContent: some View {
        VStack(spacing: Spacing.sm) {
            // Date labels
            HStack {
                Text(earliestDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text(scrubDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.epCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text("Now")
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary)
            }

            // Slider
            Slider(
                value: Binding(
                    get: { scrubDate.timeIntervalSince1970 },
                    set: { newValue in
                        scrubDate = Date(timeIntervalSince1970: newValue)
                        graphState.filter.setTimelineDate(scrubDate)
                    }
                ),
                in: earliestDate.timeIntervalSince1970...latestDate.timeIntervalSince1970
            )
            .tint(theme.accent)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
        .padding(.bottom, Spacing.sm)
    }
}
