import SwiftUI

// MARK: - Cognitive Settings Section
// Single settings section for all cognitive substrate feature toggles.

struct CognitiveSettingsSection: View {
    @Environment(EpistemosConfig.self) private var config

    var body: some View {
        @Bindable var config = config
        Form {
            Section("Cross-App Capture") {
                Toggle("Enable Cross-App Capture", isOn: $config.captureEnabled)
                if config.captureEnabled {
                    Toggle("OCR Fallback (when AX tree is sparse)", isOn: $config.ocrFallbackEnabled)
                    Text("Captures selective text artifacts when switching apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Writing Friction Insights") {
                Toggle("Enable Friction Detection", isOn: $config.frictionEnabled)
                Text("Measures writing fluency from edit patterns. No keystrokes are logged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Night Brain") {
                Toggle("Enable Night Brain", isOn: $config.nightBrainEnabled)
                if config.nightBrainEnabled {
                    Toggle("Require AC Power", isOn: $config.nightBrainRequiresAC)
                    Text("Runs maintenance jobs when idle: WAL checkpoint, artifact dedup, snapshot compaction.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
