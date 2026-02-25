import SwiftUI

// MARK: - Concept Mini-Map
// Canvas-based radial visualization of active concepts during pipeline processing.
// Shows the current concept constellation — concepts orbiting a central "focus" node.
// Ported from web v2 brainiac's thought-visualizer / concept mini-map.
// Data source: PipelineState.activeConcepts (updated per SignalUpdate).
// Appears inline during processing.

struct ConceptMiniMap: View {
    let concepts: [String]
    let chordProduct: Double
    let harmony: Double

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    /// Golden angle in radians — produces evenly distributed radial layout.
    private let goldenAngle = 2.399_963_229_7 // π × (3 − √5)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent.opacity(0.6))
                Text("CONCEPT MAP")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent.opacity(0.5))
                    .tracking(0.4)

                Spacer()

                // Harmony indicator
                if harmony > 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(harmonyColor)
                            .frame(width: 5, height: 5)
                        Text(String(format: "%.0f%%", harmony * 100))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.mutedForeground.opacity(0.5))
                    }
                }
            }

            if concepts.isEmpty {
                Text("No active concepts")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.md)
            } else {
                // Canvas radial map
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 28

                    // Center dot — "focus" node
                    context.fill(
                        Circle().path(in: CGRect(
                            x: center.x - 4, y: center.y - 4,
                            width: 8, height: 8
                        )),
                        with: .color(theme.accent)
                    )

                    // Concept nodes arranged radially
                    for (i, concept) in concepts.prefix(12).enumerated() {
                        let angle = Double(i) * goldenAngle - .pi / 2
                        let dist = radius * (0.5 + 0.5 * Double(i % 3 + 1) / 3.0)
                        let x = center.x + cos(angle) * dist
                        let y = center.y + sin(angle) * dist

                        let nodeCenter = CGPoint(x: x, y: y)

                        // Connection line to center
                        var linePath = Path()
                        linePath.move(to: center)
                        linePath.addLine(to: nodeCenter)
                        context.stroke(
                            linePath,
                            with: .color(theme.accent.opacity(0.15)),
                            lineWidth: 0.5
                        )

                        // Node circle
                        let nodeSize: CGFloat = 6
                        context.fill(
                            Circle().path(in: CGRect(
                                x: nodeCenter.x - nodeSize / 2,
                                y: nodeCenter.y - nodeSize / 2,
                                width: nodeSize, height: nodeSize
                            )),
                            with: .color(nodeColor(for: i))
                        )

                        // Label
                        let label = context.resolve(
                            Text(truncated(concept))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(theme.foreground.opacity(0.65))
                        )
                        let labelSize = label.measure(in: size)
                        context.draw(label, at: CGPoint(
                            x: nodeCenter.x,
                            y: nodeCenter.y + nodeSize / 2 + labelSize.height / 2 + 2
                        ))
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Concept map with \(concepts.count) concepts")

                // Concept list (compact pills)
                conceptPillRow
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.glassBg.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Concept Pills

    private var conceptPillRow: some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(concepts.prefix(12).enumerated()), id: \.offset) { i, concept in
                Text(concept)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(nodeColor(for: i))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(nodeColor(for: i).opacity(0.08), in: Capsule())
            }
        }
    }

    // MARK: - Helpers

    private func nodeColor(for index: Int) -> Color {
        let colors: [Color] = [
            theme.accent,
            EpistemicTag.data.color,
            EpistemicTag.model.color,
            theme.info,
            EpistemicTag.uncertain.color,
            theme.success,
        ]
        return colors[index % colors.count]
    }

    private var harmonyColor: Color {
        if harmony > 0.7 { return theme.success }
        if harmony > 0.4 { return Color(hex: 0xD4A843) }
        return theme.error
    }

    private func truncated(_ text: String) -> String {
        text.count > 14 ? String(text.prefix(12)) + "..." : text
    }
}

// FlowLayout is defined in PageShell.swift and reused here for concept pills.
