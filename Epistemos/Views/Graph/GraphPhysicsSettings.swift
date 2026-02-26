import SwiftUI

/// Obsidian-style physics settings popover for the graph view.
/// Each slider maps to a ForceConfig parameter in the Rust physics engine.
struct GraphPhysicsSettings: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        @Bindable var gs = graphState

        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Image(systemName: "atom")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.accent)
                Text("Forces")
                    .font(.epHeading)
                    .foregroundStyle(theme.foreground)
                Spacer()
                Button {
                    resetToDefaults()
                } label: {
                    Text("Reset")
                        .font(.epSmall)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)

            // Center Force
            physicsSlider(
                label: "Center Force",
                value: $gs.physCenterForce,
                range: 0...0.05,
                icon: "circle.dotted"
            )

            // Repel Force
            physicsSlider(
                label: "Repel Force",
                value: $gs.physRepelForce,
                range: 0...2000,
                icon: "arrow.up.left.and.arrow.down.right"
            )

            // Link Force
            physicsSlider(
                label: "Link Force",
                value: $gs.physLinkForce,
                range: 0...0.05,
                icon: "link"
            )

            // Link Distance
            physicsSlider(
                label: "Link Distance",
                value: $gs.physLinkDistance,
                range: 30...300,
                icon: "ruler"
            )

            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)

            // Velocity Decay (inverse = "Drift")
            physicsSlider(
                label: "Drift",
                value: $gs.physVelocityDecay,
                range: 0.1...0.95,
                icon: "wind"
            )

            // Alpha Decay (inverse = "Duration")
            physicsSlider(
                label: "Settle Speed",
                value: $gs.physAlphaDecay,
                range: 0.001...0.1,
                icon: "hourglass"
            )
        }
        .padding(Spacing.lg)
        .frame(width: 260)
    }

    // MARK: - Slider Row

    @ViewBuilder
    private func physicsSlider(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 14)
                Text(label)
                    .font(.epSmall)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(formatValue(value.wrappedValue, range: range))
                    .font(.epMono)
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 50, alignment: .trailing)
            }

            Slider(value: value, in: range)
                .controlSize(.small)
                .tint(theme.accent)
                .onChange(of: value.wrappedValue) { _, _ in
                    graphState.pushPhysicsChange()
                }
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Float, range: ClosedRange<Float>) -> String {
        let span = range.upperBound - range.lowerBound
        if span > 100 {
            return String(format: "%.0f", value)
        } else if span > 1 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.3f", value)
        }
    }

    private func resetToDefaults() {
        graphState.physCenterForce = 0.01
        graphState.physRepelForce = 600.0
        graphState.physLinkForce = 0.008
        graphState.physLinkDistance = 120.0
        graphState.physVelocityDecay = 0.55
        graphState.physAlphaDecay = 0.015
        graphState.pushPhysicsChange()
    }
}
