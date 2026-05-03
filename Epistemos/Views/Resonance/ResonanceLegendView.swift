import SwiftUI

// MARK: - Resonance Legend View
//
// Explanation surface for the τ + π + λ chip per doctrine §4.1. Shown in
// Settings → "About the Resonance Gate" or as a popover when the user
// hovers / taps the chip for the first time.
//
// Preview-only for now. Production wiring is a separate slice once the
// chip itself is mounted.

struct ResonanceLegendView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                section(
                    title: "τ — Truth (Kleene K3)",
                    rows: [
                        LegendRow(label: "T", color: .green, text: "Supported by evidence; passes the Resonance Gate."),
                        LegendRow(label: "?", color: .secondary, text: "Unknown — not yet decidable from current evidence."),
                        LegendRow(label: "F", color: .red, text: "Contradicted. Doctrine §4.1 invariant 1: never reaches you.")
                    ]
                )

                section(
                    title: "π — Class (Prime / Composite / Gap)",
                    rows: [
                        LegendRow(label: "P", color: .blue, text: "Prime — foundational, no upstream dependencies."),
                        LegendRow(label: "C", color: .purple, text: "Composite — built from two or more prime claims."),
                        LegendRow(label: "G", color: .orange, text: "Gap — needs more evidence or a missing dependency.")
                    ]
                )

                section(
                    title: "λ — Residency",
                    rows: [
                        LegendRow(label: "L0", color: .red, text: "Working memory — current attention, hottest."),
                        LegendRow(label: "L1", color: .orange, text: "Recent context — likely to be referenced again."),
                        LegendRow(label: "L2", color: .yellow, text: "Warm cache — moderate access."),
                        LegendRow(label: "L3", color: .gray, text: "Cold cache — infrequent reference."),
                        LegendRow(label: "L4", color: .pink, text: "Engram tier — Pro only (would never appear in Core)."),
                        LegendRow(label: "L5", color: .pink, text: "Adapter cache — Pro only."),
                        LegendRow(label: "L6", color: .pink, text: "Forbidden tier — Research only."),
                        LegendRow(label: "L7", color: .secondary, text: "Quarantine — safe sink for rejected claims.")
                    ]
                )

                tierFootnote
            }
            .padding()
        }
        .frame(minWidth: 360, minHeight: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resonance Gate")
                .font(.title2.bold())
            Text("Every claim is filtered through three Core questions: is it true, what kind of claim is it, and how often will you reach for it?")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func section(title: String, rows: [LegendRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.label)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(row.color)
                            .frame(width: 28, alignment: .leading)
                        Text(row.text)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var tierFootnote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tier scope")
                .font(.subheadline.weight(.semibold))
            Text(
                "This Core build computes τ + π + λ on CPU. Pro tier adds δ (direction) and ρ (resonance). Research tier adds κ (KAM stability) and η (evidence)."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private struct LegendRow: Identifiable {
        let label: String
        let color: Color
        let text: String
        var id: String { label }
    }
}

// MARK: - Previews

#Preview("Resonance Legend") {
    ResonanceLegendView()
}
