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
    @State private var kokoroDownloader = KokoroModelDownloadService.shared
    @State private var showingKokoroInstallPrompt = false

    public init() {}

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

    public var body: some View {
        Group {
            Section("Voice — Auto / Manual mode") {
                row(
                    title: "Read long notes aloud on open",
                    key: VoicePreferenceKeys.noteReadAloud,
                    binding: $prefs.noteReadAloud,
                    preview: "Kokoro is ready."
                )
                row(
                    title: "Auto-stop dictation on silence",
                    key: VoicePreferenceKeys.dictationAutoStop,
                    binding: $prefs.dictationAutoStop,
                    preview: nil
                )
                row(
                    title: "Read each sentence aloud in Quick Capture",
                    key: VoicePreferenceKeys.quickCaptureReadBack,
                    binding: $prefs.quickCaptureReadBack,
                    preview: "Quick Capture read-back."
                )
            }

            if VoicePreferences.allowsReadAloudEffects {
                Section("Read-aloud filter") {
                    HStack {
                        Label("Voice filter", systemImage: prefs.readAloudEffect.systemImage)
                        Spacer()
                        Picker("Read-aloud filter", selection: $prefs.readAloudEffect) {
                            ForEach(VoiceEffect.allCases) { effect in
                                Text(effect.label).tag(effect)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }
            }

            // Plan 3 owner update 2026-06-30: shipped TTS is Kokoro-only. This section shows the
            // checked local Kokoro runtime when ready and an honest install state otherwise; it
            // does not surface Apple's basic AVSpeech voice as a fallback.
            ModelVoicePickerSection(
                voiceIdentifier: $globalVoiceIdentifier,
                rate: $voicePreviewRate,
                pitch: $voicePreviewPitch
            )
            .onChange(of: globalVoiceIdentifier) { _, newValue in
                EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier(newValue)
            }
        }
        .sheet(isPresented: $showingKokoroInstallPrompt) {
            KokoroVoiceInstallPrompt()
                .environment(ui)
        }
        .onChange(of: kokoroDownloader.phase) { _, newPhase in
            if case .installed = newPhase,
               EpistemosSpeechSynthesizer.isTextToSpeechAvailable() {
                showingKokoroInstallPrompt = false
            }
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
                    Button {
                        previewVoice(preview)
                    } label: {
                        Label(voicePreviewButtonTitle, systemImage: voicePreviewSystemImage)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .controlSize(.regular)
                    .help(voicePreviewHelpText)
                    .accessibilityLabel(voicePreviewHelpText)
                    .accessibilityIdentifier("settings.voice.preview.\(key)")
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
        if EpistemosSpeechSynthesizer.isTextToSpeechAvailable() {
            return "Preview voice behavior"
        }
        return KokoroVoiceInstallPresentation.installHelp(
            statusMessage: EpistemosSpeechSynthesizer.textToSpeechStatusMessage()
        )
    }

    private var voicePreviewButtonTitle: String {
        EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
            ? "Preview"
            : KokoroVoiceInstallPresentation.unavailableLabel
    }

    private var voicePreviewSystemImage: String {
        EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
            ? "play.circle"
            : KokoroVoiceInstallPresentation.installSystemImage
    }

    private func previewVoice(_ preview: String) {
        EpistemosSpeechSynthesizer.logTextToSpeechReadiness(context: "settings-voice-preview")
        guard EpistemosSpeechSynthesizer.isTextToSpeechAvailable() else {
            EpistemosReadAloudDiagnostics.showUnavailableToast()
            showingKokoroInstallPrompt = true
            return
        }
        let utteranceID = EpistemosReadAloud.speak(preview)
        if utteranceID == nil {
            EpistemosReadAloudDiagnostics.showFailureToast("Kokoro voice preview could not start. Check Settings > Voice.")
        }
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
