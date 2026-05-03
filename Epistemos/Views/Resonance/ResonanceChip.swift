import SwiftUI

// MARK: - Resonance Chip
//
// Compact glanceable view of the τ + π + λ Σ-core signature per
// doctrine §4.1. Renders the three Core fields as a horizontal pip strip:
//
//   ┌─────────────┐
//   │ T · P · L1  │  ← truth · class · residency
//   └─────────────┘
//
// **Preview-only for now.** No production view mounts this chip yet —
// production wiring is a separate slice once the Resonance Gate FFI
// emits signatures into the chat / editor / Halo surfaces.
//
// Sister view: `ResonanceLegendView` (the explanation surface).

struct ResonanceChip: View {
    let signature: ResonanceSignatureCore

    var body: some View {
        HStack(spacing: 4) {
            pip(label: signature.truth.label, color: truthColor, accessibility: truthAccessibility)
            divider
            pip(label: signature.class_.label, color: classColor, accessibility: classAccessibility)
            divider
            pip(label: signature.residency.label, color: residencyColor, accessibility: residencyAccessibility)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Resonance signature: \(truthAccessibility), \(classAccessibility), \(residencyAccessibility)")
    }

    @ViewBuilder
    private func pip(label: String, color: Color, accessibility: String) -> some View {
        Text(label)
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .foregroundStyle(color)
            .frame(minWidth: 18)
            .accessibilityHidden(true) // combined into chip-level label
    }

    private var divider: some View {
        Text("·")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    // MARK: - Color mapping

    private var truthColor: Color {
        switch signature.truth {
        case .true_: .green
        case .unknown: .secondary
        case .false_: .red
        }
    }

    private var classColor: Color {
        switch signature.class_ {
        case .prime: .blue
        case .composite: .purple
        case .gap: .orange
        }
    }

    private var residencyColor: Color {
        switch signature.residency {
        case .l0Working: .red       // hottest
        case .l1Recent: .orange
        case .l2Warm: .yellow
        case .l3Cold: .gray
        case .l4Engram, .l5Adapter, .l6Forbidden: .pink // tier-leakage warning
        case .l7Quarantine: .secondary
        }
    }

    private var borderColor: Color {
        signature.passesTruthInvariant ? .secondary.opacity(0.3) : .red.opacity(0.7)
    }

    // MARK: - Accessibility text

    private var truthAccessibility: String {
        switch signature.truth {
        case .true_: "truth supported"
        case .unknown: "truth unknown"
        case .false_: "truth contradicted, blocked from display"
        }
    }

    private var classAccessibility: String {
        switch signature.class_ {
        case .prime: "prime claim, foundational"
        case .composite: "composite claim, derived"
        case .gap: "gap, needs more evidence"
        }
    }

    private var residencyAccessibility: String {
        switch signature.residency {
        case .l0Working: "working memory, hot"
        case .l1Recent: "recent context"
        case .l2Warm: "warm cache"
        case .l3Cold: "cold cache"
        case .l4Engram: "Engram tier, requires Pro"
        case .l5Adapter: "adapter cache, requires Pro"
        case .l6Forbidden: "forbidden tier, requires Research"
        case .l7Quarantine: "quarantined"
        }
    }
}

// MARK: - Previews

#Preview("Definition (Prime, L2 warm, True)") {
    ResonanceChip(
        signature: ResonanceSignatureCore(
            truth: .true_,
            class_: .prime,
            residency: .l2Warm
        )
    )
    .padding()
}

#Preview("Empirical with strong evidence (Prime, L1 recent, True)") {
    ResonanceChip(
        signature: ResonanceSignatureCore(
            truth: .true_,
            class_: .prime,
            residency: .l1Recent
        )
    )
    .padding()
}

#Preview("Empirical no evidence (Gap, L3 cold, Unknown)") {
    ResonanceChip(
        signature: ResonanceSignatureCore(
            truth: .unknown,
            class_: .gap,
            residency: .l3Cold
        )
    )
    .padding()
}

#Preview("Composite with deps (Composite, L0 working, Unknown)") {
    ResonanceChip(
        signature: ResonanceSignatureCore(
            truth: .unknown,
            class_: .composite,
            residency: .l0Working
        )
    )
    .padding()
}

#Preview("Structurally invalid (Composite no deps → Quarantined, False)") {
    ResonanceChip(
        signature: ResonanceSignatureCore(
            truth: .false_,
            class_: .composite,
            residency: .l7Quarantine
        )
    )
    .padding()
}

#Preview("Pro/Research tier-leakage warning (L4 Engram, never valid in Core)") {
    ResonanceChip(
        signature: ResonanceSignatureCore(
            truth: .true_,
            class_: .prime,
            residency: .l4Engram
        )
    )
    .padding()
}

#Preview("Strip of all 9 claim types (Service-driven)") {
    let service = ResonanceService()
    return VStack(alignment: .leading, spacing: 6) {
        ForEach(ResonanceClaimType.allCases, id: \.self) { kind in
            HStack(spacing: 8) {
                Text(kind.displayName)
                    .font(.caption.monospaced())
                    .frame(width: 110, alignment: .leading)
                ResonanceChip(
                    signature: service.computeSignatureCore(
                        for: ResonanceClaim(
                            kind: kind,
                            statement: "preview",
                            dependencyCount: kind == .composite ? 2 : 0,
                            evidenceCount: 3
                        )
                    )
                )
            }
        }
    }
    .padding()
}
