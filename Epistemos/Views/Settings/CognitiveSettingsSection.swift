import SwiftUI

// MARK: - Cognitive Settings Section
// Single settings section for all cognitive substrate feature toggles.

struct CognitiveSettingsSection: View {
    @Environment(EpistemosConfig.self) private var config

    var body: some View {
        @Bindable var config = config
        Form {
            SettingsDescriptionCard(
                title: "Cognitive Substrate",
                systemImage: "brain",
                text: "These settings control the background context systems that help Epistemos remember recent work. Stores compact activity artifacts so the app can recover context and patterns later. No keystroke logging and no hidden cloud sync are involved here."
            )

            Section("Cross-App Capture") {
                SettingsDescriptionText(
                    text: "Cross-app capture stores compact activity artifacts when you switch between apps so recall, timelines, and note context can reflect what you were doing."
                )
                Toggle("Enable Cross-App Capture", isOn: $config.captureEnabled)
                if config.captureEnabled {
                    Toggle("OCR Fallback (when AX tree is sparse)", isOn: $config.ocrFallbackEnabled)
                    SettingsDescriptionText(
                        text: "OCR fallback only runs when macOS accessibility data is too sparse to recover enough readable structure from the active app."
                    )
                }
            }

            Section("Writing Friction Insights") {
                SettingsDescriptionText(
                    text: "Friction detection watches editing patterns like hesitation, rewrites, and bursts so Epistemos can estimate where writing felt smooth or effortful. No keystroke logging is stored."
                )
                Toggle("Enable Friction Detection", isOn: $config.frictionEnabled)
            }

            Section("Night Brain") {
                SettingsDescriptionText(
                    text: "Night Brain runs low-priority maintenance jobs while the app is idle so databases, artifacts, and background context stores stay compact and healthy."
                )
                Toggle("Enable Night Brain", isOn: $config.nightBrainEnabled)
                if config.nightBrainEnabled {
                    Toggle("Require AC Power", isOn: $config.nightBrainRequiresAC)
                    Toggle("Keep Running in Menu Bar", isOn: $config.nightBrainMenuBarAgent)
                    SettingsDescriptionText(
                        text: "Current jobs include WAL checkpointing, artifact deduplication, and snapshot compaction. Requiring AC power keeps those jobs from draining the battery. Menu bar mode keeps the app alive so background jobs can fire even when all windows are closed."
                    )
                }
            }

            Section("SSM State Persistence") {
                SettingsDescriptionText(
                    text: "SSM state persistence stores tiny hidden-state snapshots for supported local SSM sessions so long conversations can resume without replaying the entire prompt history."
                )
                Toggle("Enable SSM State Persistence", isOn: $config.ssmStatePersistenceEnabled)
                if config.ssmStatePersistenceEnabled {
                    Toggle("Save After Each Turn", isOn: $config.ssmAutoSaveOnTurnEnd)
                    Stepper(value: $config.ssmMaxSnapshotsPerModel, in: 1...20) {
                        Text("Keep \(config.ssmMaxSnapshotsPerModel) snapshots per model")
                    }
                    SettingsDescriptionText(
                        text: "Snapshots stay local on disk. Saving after each turn favors fast resume; limiting retained snapshots keeps storage tidy."
                    )
                }
            }

            // W11.4 + W15 — Apple-native voice surfaces with the
            // Auto/Manual mode contract. Read aloud / dictation /
            // brain-dump hotkey / per-model voice persona — each row
            // exposes a Picker(Auto/Manual) + a "Why?" rationale +
            // an inline Preview button so the user can hear what each
            // mode does before committing.
            VoicePreferencesSection()
        }
        .formStyle(.grouped)
        .onChange(of: config.ssmStatePersistenceEnabled) { _, enabled in
            AppBootstrap.shared?.ssmStateService.activate(enabled: enabled)
        }
    }
}
