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

    @Environment(UIState.self) private var ui
    @State private var prefs = VoicePreferences.shared
    @State private var expanded: Set<String> = []
    // Legacy Apple-voice picker state is kept inert while shipped TTS is Kokoro-only.
    // Preview rate/pitch remain parked here for the future native Kokoro control.
    @State private var globalVoiceIdentifier: String? = EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier()
    @State private var voicePreviewRate: Double = 0.5
    @State private var voicePreviewPitch: Double = 1.0

    public init() {}

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

    public var body: some View {
        Section("Voice — Auto / Manual mode") {
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
            // SS-QC / DONE-RE-AUDIT (owner 2026-06-21): agent-response TTS,
            // brain-dump dictation, and per-model voice persona controls are
            // hidden until they have a real behavior consumer. Per wire-OR-remove, a shown
            // do-nothing toggle is fake. agentResponseTTS has no assistant-stream completion
            // consumer yet; brainDumpHotkeyDictate has no dictation-start seam to gate;
            // perModelVoicePersona is superseded by the SS-QC global default voice.
            // The VoicePreferences keys/defaults remain (harmless) for any future wiring.
            row(
                title: "Read each sentence aloud in Quick Capture",
                key: VoicePreferenceKeys.quickCaptureReadBack,
                binding: $prefs.quickCaptureReadBack,
                preview: "This is what auto read-back sounds like as you finish a sentence."
            )
        }

        // Plan 3 owner update 2026-06-30: shipped TTS is Kokoro-only. This section now shows an
        // honest unavailable state until native Kokoro synthesis is wired; it does not surface
        // Apple's basic AVSpeech voice as a fallback.
        ModelVoicePickerSection(
            voiceIdentifier: $globalVoiceIdentifier,
            rate: $voicePreviewRate,
            pitch: $voicePreviewPitch
        )
        .onChange(of: globalVoiceIdentifier) { _, newValue in
            EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier(newValue)
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
                ToolbarCapsuleButton(
                    title: "Why",
                    systemImage: expanded.contains(key)
                        ? "chevron.down.circle.fill"
                        : "chevron.right.circle",
                    role: .disclosure,
                    isActive: expanded.contains(key),
                    helpText: "Show voice rationale",
                    accessibilityLabel: "Show voice rationale"
                ) {
                    toggleExpanded(key)
                }

                if let preview {
                    ToolbarCapsuleButton(
                        title: "Preview",
                        systemImage: "play.circle",
                        role: .toolbarUtility,
                        helpText: voicePreviewHelpText,
                        accessibilityLabel: voicePreviewHelpText
                    ) {
                        EpistemosSpeechSynthesizer.shared.speak(preview)
                    }
                    .disabled(!EpistemosSpeechSynthesizer.isTextToSpeechAvailable())
                }
                Spacer()
            }
            if expanded.contains(key) {
                Text(prefs.rationale(for: key))
                    .font(.system(size: 11))
                    .foregroundStyle(mutedTint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(rationaleBackground)
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

    private var voicePreviewHelpText: String {
        EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
            ? "Preview voice behavior"
            : EpistemosSpeechSynthesizer.textToSpeechStatusMessage()
    }

    private var rationaleBackground: Color {
        ui.theme.resolved.foreground.color.opacity(ui.theme.isDark ? 0.055 : 0.035)
    }
}

#if DEBUG
#Preview("VoicePreferencesSection") {
    Form {
        VoicePreferencesSection()
    }
    .frame(width: 540, height: 480)
    .environment(UIState())
}
#endif
