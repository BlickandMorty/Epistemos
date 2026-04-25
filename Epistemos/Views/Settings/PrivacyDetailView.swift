import SwiftUI

/// Phase S.6 transparency pane. Surfaces the same privacy posture
/// declared in `Epistemos/Resources/PrivacyInfo.xcprivacy` so a user
/// running either the MAS build or the Pro/Developer-ID build can read
/// what stays on the Mac, what leaves it, and the App Privacy fields
/// without having to inspect the bundle. Drift between the manifest and
/// this pane is guarded by `EpistemosTests/AppStoreHardeningTests`'s
/// PrivacyInfo.xcprivacy regression set.
struct PrivacyDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                staysOnThisMacCard
                whatLeavesThisMacCard
                neverCollectedCard
                appPrivacyManifestCard
                deploymentProfileCard
                relatedControlsCard
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Privacy")
                .font(.title2.weight(.semibold))
            Text("What this app does and does not do with your data, summarized from the App Privacy manifest at Epistemos/Resources/PrivacyInfo.xcprivacy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cards

    private var staysOnThisMacCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("What stays on this Mac")
                bullets([
                    "Notes, vault contents, and any file you attach.",
                    "Embeddings, search indexes, knowledge graph, and per-model memory folders.",
                    "Local model weights (e.g. MLX) and their KV caches.",
                    "Settings, preferences, and chat history."
                ])
            }
        }
    }

    private var whatLeavesThisMacCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("What leaves this Mac")
                bullets([
                    "Cloud-model API requests, only when you pick a cloud model. Endpoints today: Anthropic Claude, OpenAI, Google Gemini, Perplexity Sonar.",
                    "API keys you enter for those providers travel only to the matching provider endpoint.",
                    "Nothing is sent to any Epistemos-operated server. There is no telemetry server."
                ])
            }
        }
    }

    private var neverCollectedCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("Never collected")
                bullets([
                    "Tracking identifiers (the App Privacy manifest declares NSPrivacyTracking = false).",
                    "Advertising SDKs, attribution SDKs, and third-party analytics SDKs.",
                    "No in-app telemetry or analytics is sent off the Mac. Apple's standard system-level reports (e.g. crash logs) are governed by your macOS Privacy & Analytics settings, not by this app."
                ])
            }
        }
    }

    private var appPrivacyManifestCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("App Privacy manifest")
                Text("Summary of `Epistemos/Resources/PrivacyInfo.xcprivacy`. App Store review reads the same source manifest.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                manifestRow(label: "NSPrivacyTracking", value: "false")
                manifestRow(label: "NSPrivacyTrackingDomains", value: "(empty)")
                manifestRow(label: "NSPrivacyCollectedDataTypes", value: "(empty)")

                Divider().opacity(0.3)

                Text("Required-reason API declarations")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                manifestRow(label: "FileTimestamp", value: "C617.1: display timestamps to the user")
                manifestRow(label: "SystemBootTime", value: "35F9.1: measure elapsed time for a user interaction")
                manifestRow(label: "DiskSpace", value: "E174.1: show storage info to the user")
                manifestRow(label: "UserDefaults", value: "CA92.1: read and write app-local defaults")
            }
        }
    }

    private var deploymentProfileCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("Deployment profile")
                #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                bullets([
                    "Mac App Store build. App Sandbox is on; file access is limited to user-selected files and folders, persisted via security-scoped bookmarks.",
                    "Subprocess tools (shell, Docker, system automation) are gated out at compile time."
                ])
                #else
                bullets([
                    "Pro / Developer-ID build. App Sandbox is intentionally off; the app uses Apple-events and file-access at the user's discretion.",
                    "Subprocess tools (shell, Docker, system automation) are available behind the existing tool-permission system."
                ])
                #endif
            }
        }
    }

    private var relatedControlsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("Related controls")
                bullets([
                    "Cloud API keys live in Settings > Inference. They are stored in the macOS Keychain.",
                    "Vault path and sync state live in Settings > Vault.",
                    "Per-tool permission policy lives in Settings > Agent."
                ])
            }
        }
    }

    // MARK: - Helpers

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func bullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Text("-")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Two-column manifest field row with a horizontal compact layout
    /// and a stacked vertical fallback. Mirrors the slice-1 LocalModelRow
    /// pattern: at default Dynamic Type the label sits left of the value;
    /// at large sizes (or narrow widths) the label moves above the value
    /// instead of clipping.
    private func manifestRow(label: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                manifestLabel(label)
                manifestValue(value)
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 2) {
                manifestLabel(label)
                manifestValue(value)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func manifestLabel(_ label: String) -> some View {
        Text(label)
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func manifestValue(_ value: String) -> some View {
        Text(value)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Privacy") {
    PrivacyDetailView()
        .frame(width: 720, height: 800)
}
