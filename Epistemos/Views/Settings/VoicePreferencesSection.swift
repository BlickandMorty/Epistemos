import AVFoundation
import SwiftUI

// MARK: - VoicePreferencesSection (W11.4 + W15)
//
// Settings surface for the voice Auto/Manual preferences. Drop into
// the existing Settings stack. Each row exposes:
//   - The preference name + a Picker(Auto / Manual)
//   - A "Why?" disclosure that expands to the rationale string
//     pulled from `VoicePreferences.shared.rationale(for:)`
//   - A live preview button (where applicable) so the user can hear
//     what the chosen mode actually does
//
// Per the W11.4 contract, the rationale text is STABLE across
// sessions — same wording regardless of context — so the user can
// learn the system's reasoning over time.

@MainActor
public struct VoicePreferencesSection: View {

    @State private var prefs = VoicePreferences.shared
    @State private var expanded: Set<String> = []

    public init() {}

    public var body: some View {
        Section("Voice — Auto / Manual mode") {
            row(
                title: "Speak agent responses aloud",
                key: VoicePreferenceKeys.agentResponseTTS,
                binding: $prefs.agentResponseTTS,
                preview: "This is what an auto-spoken agent response sounds like."
            )
            row(
                title: "Read long notes aloud on open",
                key: VoicePreferenceKeys.noteReadAloud,
                binding: $prefs.noteReadAloud,
                preview: "This is what auto-read-aloud sounds like when you open a note."
            )
            row(
                title: "Auto-stop dictation on silence",
                key: VoicePreferenceKeys.dictationAutoStop,
                binding: $prefs.dictationAutoStop,
                preview: nil
            )
            row(
                title: "Brain-dump hotkey starts dictation",
                key: VoicePreferenceKeys.brainDumpHotkeyDictate,
                binding: $prefs.brainDumpHotkeyDictate,
                preview: nil
            )
            row(
                title: "Use per-model voice persona",
                key: VoicePreferenceKeys.perModelVoicePersona,
                binding: $prefs.perModelVoicePersona,
                preview: "This is how a model's bound voice persona sounds."
            )
        }
    }

    @ViewBuilder
    private func row(
        title: String,
        key: String,
        binding: Binding<VoiceDecisionMode>,
        preview: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Picker("", selection: binding) {
                    ForEach(VoiceDecisionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            HStack(spacing: 12) {
                Button(action: { toggleExpanded(key) }) {
                    HStack(spacing: 4) {
                        Image(systemName: expanded.contains(key)
                              ? "chevron.down.circle.fill"
                              : "chevron.right.circle")
                            .font(.system(size: 11))
                        Text("Why?").font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                if let preview {
                    Button {
                        EpistemosSpeechSynthesizer.shared.speak(preview)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle").font(.system(size: 11))
                            Text("Preview").font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if expanded.contains(key) {
                Text(prefs.rationale(for: key))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleExpanded(_ key: String) {
        if expanded.contains(key) {
            expanded.remove(key)
        } else {
            expanded.insert(key)
        }
    }
}

#if DEBUG
#Preview("VoicePreferencesSection") {
    Form {
        VoicePreferencesSection()
    }
    .frame(width: 540, height: 480)
}
#endif
