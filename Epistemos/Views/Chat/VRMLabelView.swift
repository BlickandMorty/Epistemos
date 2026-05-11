import SwiftUI

// MARK: - HELIOS V5 W3 — VRM UI Label View
//
// HELIOS-W3 guard
//
// **SCAFFOLD ONLY (RCA13 P2-001).** This view ships the SwiftUI
// pill + glossary mapping per the HELIOS V5 W3 doctrine, but the
// chat-row integration is NOT wired. No production caller renders
// VRMLabelView — only the `#Preview` block at the bottom does.
// Chat emits raw text today; AnswerPacket / VRMLabel are not
// emitted by any chat response path. Settings → HELIOS V5 already
// surfaces "Deferred: no chat-path AnswerPacket emission is wired
// in v1," so the doctrine status is honest at the visible-UI level.
//
// Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W3 +
// `docs/fusion/helios v5 first.md` DOC 1 §1.5 +
// `docs/HELIOS_V5_DOC_0_INDEX.md` §0.6 (glossary):
//
//   "VRM UI labels: Verified | Plausible but unverified |
//    Speculative | Blocked — surfaced in MAS UI per DOC 1 §1.5;
//    mirrored in Pro UI per DOC 2."
//
// Tier 1 (MAS-safe): strictly additive UI element. Renders one of
// four labels for an emitted [`AnswerPacket`]. The chat row wires
// this view in a follow-up slice (the schema + view land here; the
// integration into `MessageBubble` follows).
//
// Cross-references:
// - Epistemos/Models/AnswerPacket.swift (Swift mirror types,
//   companion W1 / W2 / W3 file)
// - docs/HELIOS_V5_DOC_0_INDEX.md §0.4 (lane summary: Tier 1)
// - HELIOSInvariantSourceGuardTests.swift (B5 source-text guard)

/// SwiftUI view that renders a [`VRMLabel`] as a compact chip suitable
/// for a chat-row trailing accessory. Color encodes verification
/// posture; iconography uses SF Symbols available on macOS 14+.
public struct VRMLabelView: View {
    public let label: VRMLabel
    public var compact: Bool = false

    public init(_ label: VRMLabel, compact: Bool = false) {
        self.label = label
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
            if !compact {
                Text(label.shortLabel)
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(background)
                .overlay(
                    Capsule()
                        .strokeBorder(stroke, lineWidth: 0.5)
                )
        )
        .accessibilityLabel(label.accessibilityLabel)
        .help(label.accessibilityLabel)
    }

    private var iconName: String {
        switch label {
        case .verified: return "checkmark.seal.fill"
        case .plausibleButUnverified: return "questionmark.circle"
        case .speculative: return "sparkles"
        case .blocked: return "exclamationmark.octagon.fill"
        }
    }

    private var foreground: Color {
        switch label {
        case .verified: return .green
        case .plausibleButUnverified: return .secondary
        case .speculative: return .purple
        case .blocked: return .red
        }
    }

    private var background: Color {
        switch label {
        case .verified: return Color.green.opacity(0.10)
        case .plausibleButUnverified: return Color.gray.opacity(0.10)
        case .speculative: return Color.purple.opacity(0.10)
        case .blocked: return Color.red.opacity(0.10)
        }
    }

    private var stroke: Color {
        switch label {
        case .verified: return Color.green.opacity(0.30)
        case .plausibleButUnverified: return Color.gray.opacity(0.30)
        case .speculative: return Color.purple.opacity(0.30)
        case .blocked: return Color.red.opacity(0.40)
        }
    }
}

#if DEBUG
#Preview("VRMLabelView — all four states") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(VRMLabel.allCases, id: \.self) { label in
            HStack(spacing: 12) {
                VRMLabelView(label)
                VRMLabelView(label, compact: true)
                Text(label.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .frame(width: 320)
}
#endif
