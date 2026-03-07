import SwiftUI

// MARK: - Agent Settings View
// Per-agent configuration: trust level, voice, notifications.
// Accessed from Agent Panel → card tap → settings gear.

struct AgentSettingsView: View {
    let agentId: AgentID
    @Environment(AgentEngine.self) private var engine
    @Environment(VoiceEngine.self) private var voiceEngine
    @Environment(AgentNotificationService.self) private var notifications
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                agentHeader
                Divider().opacity(0.3)
                trustSection
                Divider().opacity(0.3)
                voiceSection
                Divider().opacity(0.3)
                notificationSection
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Header

    private var agentHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: agentId.iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(agentId.displayName)
                    .font(.epHeading)
                    .foregroundStyle(theme.foreground)

                Text(engine.status(for: agentId).label)
                    .font(.epCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - Trust

    private var trustSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Trust Level")
                .font(.epBody)
                .foregroundStyle(theme.foreground)

            if let agent = engine.agents[agentId] {
                trustRow(agent.trustLevel)
            }

            Text("Controls what file and system operations this agent can perform.")
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func trustRow(_ level: TrustLevel) -> some View {
        HStack(spacing: Spacing.sm) {
            ForEach([TrustLevel.sandbox, .standard, .elevated], id: \.self) { trust in
                Button {
                    // Trust level changes require Pro for elevated
                } label: {
                    Text(trustLabel(trust))
                        .font(.epCaption)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(level == trust ? theme.accent.opacity(0.2) : theme.background.opacity(0.5))
                        }
                        .foregroundStyle(level == trust ? theme.accent : theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    nonisolated private func trustLabel(_ level: TrustLevel) -> String {
        switch level {
        case .sandbox: "Sandbox"
        case .standard: "Standard"
        case .elevated: "Elevated"
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Voice")
                .font(.epBody)
                .foregroundStyle(theme.foreground)

            let voiceEnabled = voiceEngine.voiceConfigs[agentId]?.enabled ?? false
            Toggle("Enable voice for \(agentId.displayName)", isOn: Binding(
                get: { voiceEnabled },
                set: { voiceEngine.setVoiceEnabled($0, for: agentId) }
            ))
            .font(.epCaption)

            if let refPath = voiceEngine.voiceConfigs[agentId]?.referenceAudioPath {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(theme.accent)
                    Text(refPath.split(separator: "/").last.map(String.init) ?? refPath)
                        .font(.epCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Notifications")
                .font(.epBody)
                .foregroundStyle(theme.foreground)

            let config = notifications.configs[agentId] ?? AgentNotificationService.NotificationConfig()

            Toggle("macOS Notifications", isOn: Binding(
                get: { config.macOSEnabled },
                set: { notifications.setMacOSEnabled($0, for: agentId) }
            ))
            .font(.epCaption)

            Toggle("In-App Badges", isOn: Binding(
                get: { config.inAppEnabled },
                set: { notifications.setInAppEnabled($0, for: agentId) }
            ))
            .font(.epCaption)

            Toggle("Voice Announcements", isOn: Binding(
                get: { config.voiceEnabled },
                set: { notifications.setVoiceEnabled($0, for: agentId) }
            ))
            .font(.epCaption)
        }
    }
}
