import SwiftUI

// MARK: - ConfidenceOverlay
// Displays enrichment-derived confidence indicators above the note editor.
// Shows evidence grade badge and weakness count when enrichment data exists.
// Zero cost for plain notes — only renders when enrichment data is present.

struct ConfidenceOverlay: View {
    let evidenceGrade: String?
    let weaknesses: [String]
    let truthLikelihood: Double?

    @State private var showWeaknesses = false

    var body: some View {
        if evidenceGrade != nil || !weaknesses.isEmpty {
            HStack(spacing: 8) {
                // Evidence grade badge
                if let grade = evidenceGrade {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(gradeColor(grade))
                            .frame(width: 6, height: 6)
                            .breathe(amplitude: 0.025, period: 3.0)
                        Text("Grade \(grade)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Truth likelihood
                if let truth = truthLikelihood, truth > 0 {
                    Text("\(Int(truth * 100))% likely")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(truth < 0.5 ? .orange : .secondary)
                }

                // Weakness count — tap to expand
                if !weaknesses.isEmpty {
                    Button {
                        withAnimation(.smooth(duration: 0.2)) { showWeaknesses.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 9))
                            Text("\(weaknesses.count) weakness\(weaknesses.count == 1 ? "" : "es")")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.orange.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))

            // Expanded weaknesses list
            if showWeaknesses {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(weaknesses, id: \.self) { weakness in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(.orange.opacity(0.6))
                                .padding(.top, 4)
                            Text(weakness)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.uppercased() {
        case "A": .green
        case "B": .blue
        case "C": .yellow
        case "D": .orange
        case "F": .red
        default: .gray
        }
    }
}
