import SwiftUI

// MARK: - Context Window Indicator
// Thin progress bar showing real-time context usage in chat.

struct ContextWindowIndicator: View {
    let usageFraction: Double
    let usedTokens: Int
    let maxTokens: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))

                Capsule()
                    .fill(barColor)
                    .frame(width: max(0, geo.size.width * CGFloat(usageFraction)))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: usageFraction)
            }
        }
        .frame(height: 3)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isHovering, arrowEdge: .top) {
            contextTooltip
                .padding(8)
        }
    }

    private var barColor: Color {
        switch usageFraction {
        case ..<0.5: .green.opacity(0.7)
        case 0.5..<0.75: .yellow.opacity(0.8)
        case 0.75..<0.9: .orange.opacity(0.85)
        default: .red.opacity(0.9)
        }
    }

    private var contextTooltip: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.word.spacing")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(formatTokens(usedTokens)) / \(formatTokens(maxTokens))")
                .font(.caption.monospaced())
            Text("(\(usageFraction.isFinite ? Int(usageFraction * 100) : 0)%)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}
