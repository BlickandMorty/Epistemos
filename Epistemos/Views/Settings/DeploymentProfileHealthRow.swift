import SwiftUI

// MARK: - DeploymentProfileHealthRow
//
// RCA13 P1-021: surface the active deployment profile (App Store /
// Pro) inside Settings → Diagnostics so the user + auditors can
// see at a glance which features are present in this build. Without
// it the MAS-gated sections (`#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`)
// silently drop from the sidebar and the user has no way to tell
// whether a missing feature is "I'm on MAS" or "I'm on Pro and it
// crashed."
//
// Visible in both builds so the answer is symmetric. Lists the
// features that DIFFER between the two profiles so the audit
// claim "MAS UI does not advertise Pro-only or sandbox-stripped
// capabilities" has a concrete reference point.

@MainActor
public struct DeploymentProfileHealthRow: View {

    public init() {}

    private var profileLabel: String {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return "App Store (MAS sandbox)"
        #else
        return "Pro (Developer ID)"
        #endif
    }

    private var profileSymbol: String {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return "shield.fill"
        #else
        return "wrench.adjustable.fill"
        #endif
    }

    /// Capabilities that differ between profiles. Each entry says
    /// what's on in Pro and off in MAS. MAS sandbox blocks
    /// subprocess execution + AX scraping + LaunchAgent + iMessage
    /// scripting, so those surfaces are Pro-only.
    private static let proOnlyFeatures: [String] = [
        "CLI passthrough (claude / codex / gemini / kimi)",
        "Channels (Slack / iMessage inbound)",
        "Knowledge Fusion (Experimental)",
        "iMessage Driver",
        "Skills",
        "NightBrain LaunchAgent (background consolidation)",
        "AX / AXorcist screen reading (computer-use)",
        "Bash / MultiEdit / WebFetch local tools",
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: profileSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Deployment profile")
                        .font(.system(size: 13, weight: .medium))
                    Text(profileLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            // UI/UX audit 2026-05-17 iter-12 CC-1 remainder: apply a11y
            // modifier to the deployment-profile HStack only. The Pro-only
            // feature list below stays a separately-traversable element.
            // "isHealthy = true" here because the deployment profile is
            // informational, not a pass/fail signal.
            .diagnosticsRowAccessibility(
                label: "Deployment profile",
                detail: profileLabel,
                isHealthy: true
            )

            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            VStack(alignment: .leading, spacing: 4) {
                Text("Not available in this build:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(Self.proOnlyFeatures, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            #else
            VStack(alignment: .leading, spacing: 4) {
                Text("Enabled by this profile:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(Self.proOnlyFeatures, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.green.opacity(0.7))
                        Text(name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            #endif
        }
    }
}

#if DEBUG
struct DeploymentProfileHealthRow_Previews: PreviewProvider {
    static var previews: some View {
        DeploymentProfileHealthRow()
            .padding()
            .frame(width: 420)
    }
}
#endif
