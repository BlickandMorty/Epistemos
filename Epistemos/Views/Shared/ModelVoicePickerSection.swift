import AVFoundation
import AppKit
import SwiftUI

// MARK: - ModelVoicePickerSection
//
// Wave 9.1.b — per-model voice picker. Drop into any model-profile
// detail view to let the user pick the AVSpeechSynthesisVoice that
// will be used when this profile's responses are read aloud, plus
// rate / pitch sliders + a "Hear preview" button.
//
// The picker is grouped by quality tier (Premium > Enhanced >
// Default) and language, so the user can see at a glance which
// voices are highest fidelity. A help row links the user to System
// Settings → Spoken Content → Manage Voices when no Premium voice is
// installed yet — Apple gates Premium voice downloads behind that
// pane and there is no programmatic install API.
//
// Bindings are deliberately untyped (String? + Double) so the
// SwiftData @Model objects can pass field bindings directly without
// the wrapper view caring about the underlying SDModelProfile shape.

@MainActor
public struct ModelVoicePickerSection: View {

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
        previewText: String = "This is the voice this model will use when reading responses aloud."
    ) {
        self._voiceIdentifier = voiceIdentifier
        self._rate = rate
        self._pitch = pitch
        self.previewText = previewText
    }

    public var body: some View {
        Section("Voice") {
            picker
            ratePitchSliders
            previewControls
            qualityHintView
        }
        .task {
            voices = EpistemosSpeechSynthesizer.availableVoices(language: "en")
            qualityHint = EpistemosSpeechSynthesizer.voiceQualityHint()
        }
    }

    // MARK: - Picker

    @ViewBuilder
    private var picker: some View {
        Picker("Voice", selection: $voiceIdentifier) {
            Text("System default")
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
        var bucket: [EpistemosSpeechSynthesizer.VoiceQualityTier: [EpistemosSpeechSynthesizer.VoiceOption]] = [:]
        for v in voices { bucket[v.quality, default: []].append(v) }
        let order: [EpistemosSpeechSynthesizer.VoiceQualityTier] = [.premium, .enhanced, .default]
        return order.compactMap { tier in
            guard let entries = bucket[tier], !entries.isEmpty else { return nil }
            return (tier, entries)
        }
    }

    // MARK: - Rate / pitch sliders

    @ViewBuilder
    private var ratePitchSliders: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Rate")
                    .frame(width: 60, alignment: .leading)
                Slider(value: $rate, in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate))
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
                synth.speak(
                    previewText,
                    voiceIdentifier: voiceIdentifier,
                    rate: Float(rate),
                    pitch: Float(pitch)
                )
            } label: {
                Label(synth.state.isActive ? "Stop preview" : "Hear preview",
                      systemImage: synth.state.isActive ? "stop.circle" : "play.circle")
            }
            .buttonStyle(.bordered)

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
                    .foregroundStyle(hintColor)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(qualityHint.message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if qualityHint.tier != .premium {
                        Button("Open Manage Voices…") {
                            openManageVoices()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }
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

    private var hintColor: Color {
        switch qualityHint.tier {
        case .premium:          return .green
        case .premiumAvailable: return .accentColor
        case .enhanced:         return .yellow
        case .default:          return .secondary
        }
    }

    private func openManageVoices() {
        // The "Spoken Content" pane in System Settings hosts the
        // Manage Voices download UI. macOS 13+ stable URL.
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpokenContent") else { return }
        NSWorkspace.shared.open(url)
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
