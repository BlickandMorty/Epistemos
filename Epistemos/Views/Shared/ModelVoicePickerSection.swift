import AppKit
import SwiftUI

// MARK: - ModelVoicePickerSection
//
// Wave 9.1.b — voice picker. Plan 3 now ships TTS as Kokoro-only, so this
// surface lists checked installed Kokoro voices when ready and renders an
// honest unavailable state otherwise instead of presenting Apple voices as a fallback runtime.
//
// The picker lists checked Kokoro voice packs only. It must not enumerate Apple
// voice catalogues or Personal Voice while MAS read-aloud is Kokoro-only.
//
// Bindings are deliberately primitive (String? + Double) so callers can wire
// persistent or preview-only state without this view owning storage.

@MainActor
public struct ModelVoicePickerSection: View {

    @Environment(UIState.self) private var ui
    @Binding public var voiceIdentifier: String?
    @Binding public var rate: Double
    @Binding public var pitch: Double
    public let previewText: String

    @State private var voices: [EpistemosSpeechSynthesizer.VoiceOption] = []
    @State private var qualityHint: (tier: EpistemosSpeechSynthesizer.VoiceQualityTier, message: String) = (.default, "")
    @State private var synth = EpistemosSpeechSynthesizer.shared

    public init(
        voiceIdentifier: Binding<String?>,
        rate: Binding<Double>,
        pitch: Binding<Double>,
        previewText: String = "Kokoro is ready."
    ) {
        self._voiceIdentifier = voiceIdentifier
        self._rate = rate
        self._pitch = pitch
        self.previewText = previewText
    }

    public var body: some View {
        Section("Voice") {
            inlineBody
        }
    }

    /// Same controls without the outer `Section("Voice")` chrome —
    /// for callers that already supply their own container (GroupBox,
    /// .inset Section, custom HStack). Callers in `Form` contexts
    /// should prefer the default `body`.
    @ViewBuilder
    public var inlineBody: some View {
        if isTextToSpeechAvailable {
            picker
            ratePitchSliders
            previewControls
            qualityHintView
            Color.clear.frame(height: 0).task {
                refreshVoicesAndHints()
            }
        } else {
            unavailableTextToSpeechView
        }
    }

    private var isTextToSpeechAvailable: Bool {
        EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
    }

    private var unavailableTextToSpeechView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(mutedTint)
                .font(.system(size: 12, weight: .semibold))
                .padding(.top, 2)
            Text(EpistemosSpeechSynthesizer.textToSpeechStatusMessage())
                .font(.system(size: 11))
                .foregroundStyle(mutedTint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Picker

    @ViewBuilder
    private var picker: some View {
        Picker("Voice", selection: $voiceIdentifier) {
            Text("English default")
                .tag(nil as String?)
            ForEach(groupedByTier, id: \.0) { tier, options in
                Section(tier.label) {
                    ForEach(options) { option in
                        Text("\(option.displayName) — \(option.language)")
                            .tag(Optional(option.identifier))
                    }
                }
            }
        }
        .pickerStyle(.menu)
    }

    private var groupedByTier: [(EpistemosSpeechSynthesizer.VoiceQualityTier, [EpistemosSpeechSynthesizer.VoiceOption])] {
        // Shared grouping (no duplicated tier logic) — see EpistemosSpeechSynthesizer.
        EpistemosSpeechSynthesizer.voicesGroupedByTier(voices)
    }

    private func refreshVoicesAndHints() {
        // Kokoro-only shipped TTS: MAS ships English read-aloud only. Do not
        // expose non-English Kokoro embeddings until the app has product UI for language selection.
        // These identifiers are bare Kokoro voice names that speak()/renderRawText honors.
        let englishVoices = EpistemosSpeechSynthesizer.installedEnglishKokoroVoices()
        voices = englishVoices
        normalizeBoundVoiceIdentifier(against: englishVoices)
        qualityHint = kokoroQualityHint(for: voices)
    }

    private func normalizeBoundVoiceIdentifier(
        against englishVoices: [EpistemosSpeechSynthesizer.VoiceOption]
    ) {
        let normalized = EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
            voiceIdentifier,
            installedVoices: englishVoices
        )
        if voiceIdentifier != normalized {
            voiceIdentifier = normalized
        }
    }

    private func kokoroQualityHint(
        for voices: [EpistemosSpeechSynthesizer.VoiceOption]
    ) -> (tier: EpistemosSpeechSynthesizer.VoiceQualityTier, message: String) {
        if voices.isEmpty {
            return (
                .default,
                "Kokoro is ready. The bundled starter voice will be used until another checked Kokoro voice is installed."
            )
        }
        return (
            .premium,
            "Kokoro is ready with \(voices.count) checked local voice\(voices.count == 1 ? "" : "s"). Apple AVSpeech is not used as a fallback."
        )
    }

    // MARK: - Rate / pitch sliders

    @ViewBuilder
    private var ratePitchSliders: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Rate")
                    .frame(width: 60, alignment: .leading)
                Slider(value: $rate, in: 0.1...0.8)
                Text(String(format: "%.2f", rate))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            HStack {
                Text("Pitch")
                    .frame(width: 60, alignment: .leading)
                Slider(value: $pitch, in: 0.5...2.0)
                Text(String(format: "%.2f", pitch))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewControls: some View {
        HStack(spacing: 12) {
            Button {
                if synth.state.isActive { synth.stop() }
                else {
                    EpistemosSpeechSynthesizer.logTextToSpeechReadiness(context: "settings-voice-model-preview")
                    let utteranceID = synth.speak(
                        previewText,
                        voiceIdentifier: voiceIdentifier,
                        rate: Float(rate),
                        pitch: Float(pitch)
                    )
                    if utteranceID == nil {
                        EpistemosReadAloudDiagnostics.showFailureToast("Kokoro voice preview could not start. Check Settings > Voice.")
                    }
                }
            } label: {
                Label(
                    synth.state.isActive ? "Stop" : "Preview",
                    systemImage: synth.state.isActive ? "stop.circle" : "play.circle"
                )
                .font(.system(size: 12, weight: .semibold))
            }
            .controlSize(.regular)
            .help(synth.state.isActive ? "Stop voice preview" : "Hear voice preview")
            .accessibilityLabel(synth.state.isActive ? "Stop voice preview" : "Hear voice preview")
            .accessibilityIdentifier("settings.voice.modelPreview")

            if case let .speaking(_, total, spoken) = synth.state, total > 0 {
                ProgressView(value: Double(spoken), total: Double(total))
                    .frame(maxWidth: 160)
            }
        }
    }

    // MARK: - Quality hint

    @ViewBuilder
    private var qualityHintView: some View {
        if !qualityHint.message.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: hintGlyph)
                    .foregroundStyle(hintTint)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(qualityHint.message)
                        .font(.system(size: 11))
                        .foregroundStyle(mutedTint)
                }
            }
        }
    }

    private var hintGlyph: String {
        switch qualityHint.tier {
        case .premium:          return "checkmark.seal.fill"
        case .premiumAvailable: return "arrow.down.circle"
        case .enhanced:         return "star.circle"
        case .default:          return "info.circle"
        }
    }

    private var hintTint: Color {
        switch qualityHint.tier {
        case .premium:          return ui.theme.resolved.headingAccent.color
        case .premiumAvailable: return ui.theme.resolved.accent.color
        case .enhanced:         return ui.theme.resolved.foreground.color.opacity(0.78)
        case .default:          return mutedTint
        }
    }

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }
}

#if DEBUG
#Preview("ModelVoicePickerSection") {
    @Previewable @State var voice: String? = nil
    @Previewable @State var rate: Double = 0.5
    @Previewable @State var pitch: Double = 1.0
    return Form {
        ModelVoicePickerSection(
            voiceIdentifier: $voice,
            rate: $rate,
            pitch: $pitch
        )
    }
    .frame(width: 480, height: 400)
}
#endif
