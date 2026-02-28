import SwiftData
import SwiftUI

// MARK: - VersionTimeline
// Horizontal timeline of version dots replacing the Picker dropdown in DiffSheetView.
// Dot size proportional to word count delta between versions.
// Color-coded: gray = minor edit, accent = major rewrite.
// Word count sparkline drawn above the dots.

struct VersionTimeline: View {
    let versions: [SDPageVersion]
    @Binding var selectedVersionId: String?

    /// Word count deltas between consecutive versions.
    private var deltas: [Int] {
        guard versions.count > 1 else { return versions.map { $0.wordCount } }
        var result: [Int] = []
        for i in 0..<versions.count {
            if i < versions.count - 1 {
                result.append(abs(versions[i].wordCount - versions[i + 1].wordCount))
            } else {
                result.append(0) // oldest version has no delta
            }
        }
        return result
    }

    /// Threshold: more than 20% word count change = major rewrite.
    private func isMajor(_ index: Int) -> Bool {
        guard index < deltas.count, index < versions.count else { return false }
        let wc = max(versions[index].wordCount, 1)
        return deltas[index] > wc / 5
    }

    var body: some View {
        if versions.isEmpty { EmptyView() }
        else {
            VStack(spacing: 4) {
                // Sparkline
                sparkline
                    .frame(height: 20)

                // Dots
                HStack(spacing: 0) {
                    ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                        let isSelected = version.id == selectedVersionId
                        let major = isMajor(index)

                        Button {
                            selectedVersionId = version.id
                        } label: {
                            Circle()
                                .fill(dotColor(isSelected: isSelected, isMajor: major))
                                .frame(width: dotSize(index), height: dotSize(index))
                                .overlay {
                                    if isSelected {
                                        Circle()
                                            .strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(versionTooltip(version))
                        .accessibilityLabel("Version from \(versionTooltip(version))")

                        if index < versions.count - 1 {
                            Rectangle()
                                .fill(.white.opacity(0.15))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 200)
        }
    }

    // MARK: - Sparkline

    private var sparkline: some View {
        GeometryReader { geo in
            let wordCounts = versions.map { Float($0.wordCount) }
            let maxWc = wordCounts.max() ?? 1.0
            let minWc = wordCounts.min() ?? 0.0
            let range = max(maxWc - minWc, 1.0)

            Path { path in
                guard wordCounts.count > 1 else { return }
                let step = geo.size.width / CGFloat(wordCounts.count - 1)
                for (i, wc) in wordCounts.enumerated() {
                    let x = CGFloat(i) * step
                    let normalized = CGFloat((wc - minWc) / range)
                    let y = geo.size.height * (1.0 - normalized)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(.white.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: - Helpers

    private func dotSize(_ index: Int) -> CGFloat {
        let delta = index < deltas.count ? deltas[index] : 0
        // Range: 6pt (tiny edit) to 12pt (large rewrite)
        let clamped = min(Float(delta), 500.0) / 500.0
        return CGFloat(6.0 + clamped * 6.0)
    }

    private func dotColor(isSelected: Bool, isMajor: Bool) -> Color {
        if isSelected { return .accentColor }
        return isMajor ? .accentColor.opacity(0.6) : .white.opacity(0.3)
    }

    private func versionTooltip(_ version: SDPageVersion) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "\(formatter.localizedString(for: version.createdAt, relativeTo: .now)) (\(version.wordCount) words)"
    }
}
