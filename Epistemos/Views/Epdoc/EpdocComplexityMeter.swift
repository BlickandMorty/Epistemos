import SwiftUI

// MARK: - EpdocComplexityMeter
//
// Wave 7.17.b SwiftUI complexity meter — sits in the toolbar's right
// cluster, color-graded green→amber→red as the W7.12 complexity
// scalar climbs. Tooltip exposes the per-metric breakdown
// (`DocComplexityBreakdown`) so the writer can see why the doc is
// getting heavy.
//
// Per the user's 2026-04-26 direction: "the graph reflects the
// complexity of the documents." This is the editor-side counterpart
// — same scalar, surfaced inline so the writer notices BEFORE the
// graph shows it.
//
// Threshold band → "Consider splitting?" chip when complexity > 0.7
// (the writerly intelligence Alexandrie's static word-count badge
// can't fake).

@MainActor
public struct EpdocComplexityMeter: View {

    /// 0.0–1.0 complexity scalar (W7.12). Bind to the live value the
    /// editor controller computes on every save.
    public let complexity: Double
    /// Optional breakdown — when nil, the tooltip just shows the
    /// scalar; when set, breaks down which sub-metrics are pushing
    /// the score up.
    public let breakdown: DocComplexityBreakdown?
    /// Tooltip prefix (e.g. document title) so a row of meters in
    /// a list view stays self-identifying.
    public let label: String

    public init(
        complexity: Double,
        breakdown: DocComplexityBreakdown? = nil,
        label: String = "Complexity"
    ) {
        self.complexity = complexity
        self.breakdown = breakdown
        self.label = label
    }

    private var clamped: Double { max(0.0, min(1.0, complexity)) }

    /// Color band: < 0.4 green, 0.4...0.7 amber, > 0.7 red.
    private var color: Color {
        switch clamped {
        case ..<0.4:  return .green
        case ..<0.7:  return .yellow
        default:      return .red
        }
    }

    /// True when complexity crosses into the "Consider splitting?" band.
    public var shouldNudgeSplit: Bool { clamped > 0.7 }

    public var body: some View {
        HStack(spacing: 6) {
            // Bar visual — slim 4-pt height with rounded caps so it
            // sits cleanly next to the stats badge.
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 60, height: 4)
                Capsule()
                    .fill(color)
                    .frame(width: 60 * clamped, height: 4)
            }
            Text("\(Int(clamped * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
                .monospacedDigit()
            if shouldNudgeSplit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.yellow)
                    .font(.system(size: 10))
            }
        }
        .help(tooltipText)
        .accessibilityLabel("\(label): \(Int(clamped * 100)) percent")
        .accessibilityValue(shouldNudgeSplit ? "Consider splitting" : "")
    }

    private var tooltipText: String {
        var lines: [String] = ["\(label): \(Int(clamped * 100))%"]
        if let b = breakdown {
            lines.append("Words \(b.wordCount) · Headings depth \(b.maxHeadingDepth)")
            lines.append("Code \(b.codeBlockCount) · Math \(b.mathCount) · Mermaid \(b.mermaidCount)")
            lines.append("Links \(b.linkCount) · Embeds \(b.embedCount)")
        }
        if shouldNudgeSplit {
            lines.append("⚠︎ Consider splitting into multiple docs")
        }
        return lines.joined(separator: "\n")
    }
}

#if DEBUG
#Preview("EpdocComplexityMeter — full spectrum") {
    VStack(alignment: .leading, spacing: 12) {
        EpdocComplexityMeter(complexity: 0.05, label: "Quick note")
        EpdocComplexityMeter(complexity: 0.20, label: "Short article")
        EpdocComplexityMeter(complexity: 0.45, label: "Mid-size doc")
        EpdocComplexityMeter(complexity: 0.65, label: "Substantial")
        EpdocComplexityMeter(complexity: 0.80, label: "Heavy")
        EpdocComplexityMeter(complexity: 0.95, label: "Saturated")
    }
    .padding()
}
#endif
