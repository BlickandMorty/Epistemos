import SwiftUI

extension Notification.Name {
    static let selectSettingsSection = Notification.Name("epistemos.selectSettingsSection")
}

/// Preferences owned by the base app. Product-specific settings belong on
/// their product surfaces rather than in this window.
struct SettingsView: View {
    static let sectionUserInfoKey = "settingsSection"

    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @State private var selection: SettingsSection
    @State private var isConfirmingVaultDisconnect = false

    init(initialSelection: SettingsSection? = .general) {
        _selection = State(initialValue: initialSelection ?? .general)
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case vault = "Vault"
        case workspace = "Workspace"
        case voice = "Voice"
        case accessibility = "Accessibility"
        case privacy = "Privacy"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .appearance: "paintpalette"
            case .vault: "folder"
            case .workspace: "rectangle.3.group"
            case .voice: "waveform"
            case .accessibility: "accessibility"
            case .privacy: "hand.raised.fill"
            }
        }
    }

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        HStack(spacing: 0) {
            navigation
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: .selectSettingsSection)) { notification in
            guard let rawValue = notification.userInfo?[Self.sectionUserInfoKey] as? String,
                  let section = SettingsSection(rawValue: rawValue) else { return }
            selection = section
        }
        .confirmationDialog(
            "Disconnect this vault?",
            isPresented: $isConfirmingVaultDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect Vault", role: .destructive) {
                VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)
            }
        } message: {
            Text("Epistemos will release access to this folder and clear its local derived index. Your vault files stay in place.")
        }
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Settings", systemImage: "gearshape")
                .font(.headline)
                .padding(14)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.rawValue, systemImage: section.icon)
                            .font(.system(size: 12, weight: selection == section ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                selection == section ? theme.resolved.accent.color.opacity(0.14) : .clear,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .frame(minWidth: 184, idealWidth: 204, maxWidth: 220, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            SettingsDetailContainer(
                title: "General",
                message: "Local preferences for the base Epistemos app."
            ) {
                Toggle(
                    "Animate the greeting as it types",
                    isOn: Binding(
                        get: { ui.landingGreetingTypewriterEnabled },
                        set: { ui.landingGreetingTypewriterEnabled = $0 }
                    )
                )
                Text("The animation pauses when the app is occluded or macOS requests reduced motion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .appearance:
            SettingsDetailContainer(
                title: "Appearance",
                message: "Follow macOS or choose an Epistemos theme for this Mac."
            ) {
                Picker(
                    "Appearance",
                    selection: Binding(
                        get: { ui.themeMode },
                        set: { ui.setThemeMode($0) }
                    )
                ) {
                    Text("Follow macOS").tag(ThemeMode.systemDefault)
                    Text("Choose Epistemos theme").tag(ThemeMode.custom)
                }

                if ui.themeMode == .custom {
                    Picker(
                        "Theme",
                        selection: Binding(
                            get: { ui.activePair },
                            set: { ui.setPair($0) }
                        )
                    ) {
                        ForEach(ThemePair.allCases, id: \.self) { pair in
                            Text(pair.displayName).tag(pair)
                        }
                    }
                }
            }
        case .vault:
            SettingsDetailContainer(title: "Vault", message: vaultMessage) {
                Button(vaultSync.vaultURL == nil ? "Choose Vault Folder…" : "Change Vault Folder…") {
                    VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                }
                if vaultSync.vaultURL != nil {
                    Button("Disconnect Vault…", role: .destructive) {
                        isConfirmingVaultDisconnect = true
                    }
                }
            }
        case .workspace:
            SettingsDetailContainer(
                title: "Workspace",
                message: "Save and restore window arrangements stored locally on this Mac."
            ) {
                Button("Open Workspace Switcher") {
                    NotificationCenter.default.post(name: .toggleWorkspaceSwitcher, object: nil)
                }
                Button("Save Current Workspace…") {
                    NotificationCenter.default.post(name: .showSaveWorkspacePanel, object: nil)
                }
                Button("Open Time Machine") {
                    NotificationCenter.default.post(name: .toggleTimeMachine, object: nil)
                }
            }
        case .voice:
            VoiceSettingsDetailView()
        case .accessibility:
            AccessibilitySettingsDetailView()
        case .privacy:
            PrivacyDetailView()
        }
    }

    private var vaultMessage: String {
        guard let vaultURL = vaultSync.vaultURL else {
            return "Choose a folder you control. Epistemos stores a security-scoped bookmark so it can reopen that vault."
        }
        return "Connected to \(vaultURL.lastPathComponent). The folder remains under your control."
    }
}

private struct SettingsDetailContainer<Content: View>: View {
    let title: String
    let message: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct AccessibilitySettingsDetailView: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SettingsDetailContainer(
            title: "Accessibility",
            message: "Epistemos respects macOS motion preferences and keeps readability choices local to this Mac."
        ) {
            Toggle(
                "Use readable system text",
                isOn: Binding(
                    get: { ui.readableFontsEnabled },
                    set: { ui.setReadableFontsEnabled($0) }
                )
            )
            LabeledContent("Reduce Motion") {
                Text(reduceMotion ? "On in macOS" : "Off in macOS")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
