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

    #if EPISTEMOS_APP_STORE || MAS_SANDBOX
    private static let activeMASBoundaries: [String] = [
        "June in-process agent (OpenAI / Anthropic API keys)",
        "Apple Intelligence / selected local GGUF chat lanes inside June",
        "Security-scoped, user-selected vault access",
        "No subprocess, CLI passthrough, local server, or terminal execution",
    ]
    #else
    private static let proOnlyFeatures: [String] = {
        let cliPassthroughLabel = "CLI passthrough (claude / codex / gemini / kimi)"
        return [
            cliPassthroughLabel,
            "Skills",
            "AX / AXorcist screen reading (computer-use)",
            "Bash / MultiEdit / WebFetch local tools",
        ]
    }()
    #endif

    private var profileTruth: String {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        "MAS Settings describes the active June product boundary only."
        #else
        "Compile-time Developer ID profile is visible in Settings."
        #endif
    }

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

            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: "build profile",
                productionWired: false,
                falsifierPassed: false,
                falsifier: "docs/audits/SETTINGS_TRUTH_FLOOR_2026_05_25.md",
                wiredToday: profileTruth,
                stillStub: "Build-profile visibility is not a substrate production PASS claim."
            )

            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            VStack(alignment: .leading, spacing: 4) {
                Text("Active MAS June boundaries:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(Self.activeMASBoundaries, id: \.self) { name in
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
