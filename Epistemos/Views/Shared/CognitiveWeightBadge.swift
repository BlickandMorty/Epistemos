// CognitiveWeightBadge.swift
//
// Master Fusion Plan §B.6 W1 — 4-tier Cognitive Weight badge.
//
// Renders a compact chip showing the document's Cognitive Weight
// class (Soft / Preferred / Strong / Policy-grade) for every loaded
// resource in Halo + composer attachment surfaces.
//
// **W1 acceptance §6 (silent downgrade)**: the badge displays the
// `class` field as-is — including `.policyGrade` — but does NOT
// indicate ENFORCED policy authority anywhere. The
// `CognitiveWeight.policyAuthority` field is always false on the
// Swift side under W1 (see `Epistemos/Models/CognitiveWeight.swift`)
// so any UI surface that wanted to render a "POLICY ACTIVE" indicator
// has nothing to read. The badge's PolicyGrade variant shows "Policy"
// + the explicit-in-tooltip "advisory in W1 (policy authority lands
// in W2)" line so users understand the visual is informational.

import SwiftUI

/// Compact chip showing the 4-tier Cognitive Weight class of a
/// resource. Use in Halo result rows, composer attachment chips,
/// Provenance Console rows — anywhere a loaded resource needs its
/// Semantic Gravity surfaced.
///
/// Visual treatment:
///   - Soft         · grey,   filled lightly (low salience)
///   - Preferred    · blue,   filled medium (inline context)
///   - StrongAnchor · purple, filled strong  (above-fold)
///   - PolicyGrade  · amber,  filled strong + outline (immutable)
///
/// All four variants use `Capsule` shape with consistent vertical
/// rhythm so they line up cleanly in row layouts.
public struct CognitiveWeightBadge: View {
    let weight: CognitiveWeight

    public init(weight: CognitiveWeight) {
        self.weight = weight
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .semibold))
            Text(weight.class.shortLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .help(weight.class.accessibilityDescription)
        .accessibilityLabel(weight.class.accessibilityDescription)
        .accessibilityValue("raw score \(String(format: "%.2f", weight.rawScore))")
    }

    // MARK: - Visual mapping per class

    private var iconName: String {
        switch weight.class {
        case .soft:         return "circle.dotted"
        case .preferred:    return "circle.fill"
        case .strongAnchor: return "shield.lefthalf.filled"
        case .policyGrade:  return "shield.fill"
        }
    }

    private var foregroundStyle: Color {
        switch weight.class {
        case .soft:         return .secondary
        case .preferred:    return .blue
        case .strongAnchor: return .purple
        case .policyGrade:  return .orange
        }
    }

    private var backgroundFill: Color {
        switch weight.class {
        case .soft:         return Color.primary.opacity(0.04)
        case .preferred:    return Color.blue.opacity(0.08)
        case .strongAnchor: return Color.purple.opacity(0.10)
        case .policyGrade:  return Color.orange.opacity(0.12)
        }
    }

    private var strokeColor: Color {
        switch weight.class {
        case .soft:         return Color.primary.opacity(0.08)
        case .preferred:    return Color.blue.opacity(0.20)
        case .strongAnchor: return Color.purple.opacity(0.30)
        case .policyGrade:  return Color.orange.opacity(0.40)
        }
    }

    /// PolicyGrade gets a slightly thicker outline because it's the
    /// visually-loudest class — but the outline is the ONLY extra
    /// emphasis under W1. No "ENFORCED" label, no lock icon, nothing
    /// that would imply real policy authority before W2 ships the
    /// 5-gate enforcement loop.
    private var strokeWidth: CGFloat {
        switch weight.class {
        case .policyGrade: return 1.0
        default:           return 0.5
        }
    }
}

// MARK: - Previews

#Preview("All four tiers") {
    VStack(alignment: .leading, spacing: 10) {
        ForEach(
            [
                CognitiveWeight(rawScore: 0.15),  // soft
                CognitiveWeight(rawScore: 0.50),  // preferred
                CognitiveWeight(rawScore: 0.75),  // strong anchor
                CognitiveWeight(rawScore: 0.95),  // policy grade
            ],
            id: \.rawScore
        ) { weight in
            HStack(spacing: 12) {
                CognitiveWeightBadge(weight: weight)
                Text("raw=\(String(format: "%.2f", weight.rawScore))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    .padding(20)
    .background(.ultraThinMaterial)
}
