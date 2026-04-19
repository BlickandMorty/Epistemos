import SwiftUI

/// Inline compact context-usage badge for the composer control row.
/// Complements the thin progress bar above the input — the bar gives a
/// visual fill, this badge gives a concrete number ("2.3K / 128K · 2%")
/// so the user can see attachments and context injections raise the
/// number live, not just nudge a thin bar a pixel. Color-coded by the
/// same thresholds as the bar so the full row reads as one status.
struct ContextWindowCompactBadge: View {
    let usageFraction: Double
    let usedTokens: Int
    let maxTokens: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.compress.vertical")
                .font(.system(size: 9, weight: .semibold))
            Text(shortUsed)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
            Text("·")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(percentText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.10), in: Capsule())
        .help("Context used: \(shortUsed) of \(shortMax) (\(percentText))")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Context used \(percentText)")
    }

    // MARK: - Derived

    private var color: Color {
        switch usageFraction {
        case ..<0.5: .green
        case 0.5..<0.75: .yellow
        case 0.75..<0.9: .orange
        default: .red
        }
    }

    private var percentText: String {
        guard usageFraction.isFinite else { return "0%" }
        let percent = Int((usageFraction * 100).rounded())
        return "\(max(0, min(percent, 999)))%"
    }

    private var shortUsed: String { Self.format(usedTokens) }
    private var shortMax: String { Self.format(maxTokens) }

    private static func format(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}
