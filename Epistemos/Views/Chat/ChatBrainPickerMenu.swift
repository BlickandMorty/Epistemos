import SwiftUI

// MARK: - Chat Brain Picker Menu
// Compact inline model picker for Main Chat + Landing Chat popover.
// Mirrors the agent page's `BrainPickerMenu` but binds to
// `InferenceState.preferredChatModelSelection` so the user always sees which
// model is powering the next chat turn, and can switch without leaving the
// composer.

struct ChatBrainPickerMenu: View {
    @Environment(InferenceState.self) private var inference
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    private var installedLocalIDs: [String] {
        Array(inference.installedLocalTextModelIDs)
            .sorted()
            .filter { LocalTextModelID(rawValue: $0) != nil }
    }

    private var currentLabel: String {
        inference.preferredChatModelSelection.compactDisplayName
    }

    private var currentIcon: String {
        switch inference.preferredChatModelSelection {
        case .appleIntelligence: "apple.logo"
        case .localMLX: "cpu"
        case .cloud: "cloud"
        }
    }

    var body: some View {
        Menu {
            Section("Apple") {
                Button {
                    inference.setPreferredChatModelSelection(.appleIntelligence)
                } label: {
                    Label("Apple Intelligence", systemImage: "apple.logo")
                }
            }

            if !installedLocalIDs.isEmpty {
                Section("Local (on-device)") {
                    ForEach(installedLocalIDs, id: \.self) { modelID in
                        let local = LocalTextModelID(rawValue: modelID)
                        Button {
                            inference.setPreferredChatModelSelection(.localMLX(modelID))
                        } label: {
                            Label(local?.displayName ?? modelID, systemImage: "cpu")
                        }
                    }
                }
            }

            Section("Cloud") {
                ForEach(CloudTextModelID.allCases, id: \.self) { model in
                    Button {
                        inference.setPreferredChatModelSelection(.cloud(model))
                    } label: {
                        Label(model.displayName, systemImage: "cloud")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: currentIcon)
                    .font(.system(size: 11, weight: .medium))
                Text(currentLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(theme.textPrimary)
            .background(
                theme.muted.opacity(theme.isDark ? 0.75 : 0.4),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.6), lineWidth: 0.6)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
