import SwiftUI

// MARK: - TimeSliderOverlay
// Horizontal time-travel slider overlaid above the graph floating controls.
// Dragging filters graph nodes by creation date via Rust time filter.
// Nodes created after the cutoff become invisible; nodes without timestamps stay visible.

struct TimeSliderOverlay: View {
    @Environment(GraphState.self) private var graphState

    @State private var sliderValue: Double = 1.0 // 0..1 normalized

    private var startEpoch: Double { graphState.timeRangeStart.timeIntervalSince1970 }
    private var endEpoch: Double { graphState.timeRangeEnd.timeIntervalSince1970 }

    /// Current cutoff date computed from slider position.
    private var cutoffDate: Date {
        let epoch = startEpoch + sliderValue * (endEpoch - startEpoch)
        return Date(timeIntervalSince1970: epoch)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 6) {
            // Date label
            Text(Self.dateFormatter.string(from: cutoffDate))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            // Slider
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))

                Slider(value: $sliderValue, in: 0...1) { editing in
                    if !editing {
                        graphState.applyTimeFilter(cutoffDate)
                    }
                }
                .controlSize(.small)
                .frame(width: 240)

                Button {
                    sliderValue = 1.0
                    graphState.clearTimeFilter()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Clear time filter")
                .accessibilityLabel("Clear time filter")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            // Initialize slider to the end (showing all nodes)
            sliderValue = 1.0
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
