import SwiftUI

struct SettingsSurfaceCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ChannelStatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - DiagnosticsRow accessibility modifier
//
// Standardizes VoiceOver discipline across the ~12 Settings Diagnostics
// health-row views that all share the same Image+Text+status-icon HStack
// pattern but had no explicit `.accessibilityElement` / `.accessibilityLabel`
// / `.accessibilityValue` modifiers. Per the iter-3 + iter-12 audit
// docs (docs/audits/UI_UX_Settings_Diagnostics_2026-05-17.md +
// UI_UX_Settings_SubtreeSweep_2026-05-17.md), VoiceOver users sweeping
// Settings → Diagnostics heard the rows announce inconsistently —
// `APIKeysHealthRow` + `CognitiveDagHealthRow` already used
// `.accessibilityElement(children: .combine)` with a polished label;
// every other health row fell back to SwiftUI's auto-merge of
// Image + Text + Image (status icon).
//
// Apply this modifier to the outermost HStack/VStack of each health-row
// surface. It collapses the row into one a11y element, announces the
// label, and exposes the detail string + healthy/needs-attention status
// as the accessibility value — so VoiceOver reads e.g.
//   "Shadow backend. Operational. healthy."
// instead of
//   "Magnifying Glass Circle Fill Image. Shadow backend. Operational.
//    Checkmark Circle Fill Image."
//
// Strictly additive — no visual or behavioral change.
extension View {
    func diagnosticsRowAccessibility(
        label: String,
        detail: String,
        isHealthy: Bool
    ) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue("\(detail). Status: \(isHealthy ? "healthy" : "needs attention").")
    }
}
