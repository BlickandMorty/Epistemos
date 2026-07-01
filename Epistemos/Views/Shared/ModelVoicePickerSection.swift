import AVFoundation
import AppKit
import SwiftUI

// MARK: - ModelVoicePickerSection
//
// Wave 9.1.b — voice picker. Plan 3 now ships TTS as Kokoro-only, so this
// surface renders an honest unavailable state until native Kokoro synthesis
// exists instead of presenting Apple voices as a fallback runtime.
//
// The picker is grouped by quality tier (Premium > Enhanced >
// Default) and language, so the user can see at a glance which
// voices are highest fidelity. A help row links the user to System
// Settings → Spoken Content → Manage Voices when no Premium voice is
// installed yet — Apple gates Premium voice downloads behind that
// pane and there is no programmatic install API.
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
    @State private var personalVoiceAuthorization: EpistemosSpeechSynthesizer.PersonalVoiceAuthorization = .unsupported
    @State private var isRequestingPersonalVoice = false
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
            personalVoiceAccessView
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
        // Shared grouping (no duplicated tier logic) — see EpistemosSpeechSynthesizer.
        EpistemosSpeechSynthesizer.voicesGroupedByTier(voices)
    }

    private func refreshVoicesAndHints() {
        voices = EpistemosSpeechSynthesizer.availableVoices(language: "en")
        qualityHint = EpistemosSpeechSynthesizer.voiceQualityHint()
        personalVoiceAuthorization = EpistemosSpeechSynthesizer.personalVoiceAuthorization()
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
            ToolbarCapsuleButton(
                title: synth.state.isActive ? "Stop" : "Preview",
                systemImage: synth.state.isActive ? "stop.circle" : "play.circle",
                variant: .content,
                role: .toolbarUtility,
                chromePolicy: .alwaysSurface,
                helpText: synth.state.isActive ? "Stop voice preview" : "Hear voice preview",
                accessibilityLabel: synth.state.isActive ? "Stop voice preview" : "Hear voice preview"
            ) {
                if synth.state.isActive { synth.stop() }
                else {
                    synth.speak(
                        previewText,
                        voiceIdentifier: voiceIdentifier,
                        rate: Float(rate),
                        pitch: Float(pitch)
                    )
                }
            }

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
                    if qualityHint.tier != .premium {
                        ToolbarCapsuleButton(
                            title: "Manage Voices",
                            systemImage: "gearshape",
                            role: .secondaryGhost,
                            helpText: "Open Manage Voices",
                            accessibilityLabel: "Open Manage Voices"
                        ) {
                            openManageVoices()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var personalVoiceAccessView: some View {
        if showsPersonalVoiceAccess {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: personalVoiceGlyph)
                    .foregroundStyle(personalVoiceTint)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(personalVoiceMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(mutedTint)
                    if personalVoiceAuthorization == .notDetermined {
                        ToolbarCapsuleButton(
                            title: "Allow Personal Voice",
                            systemImage: "person.crop.circle",
                            role: .toolbarUtility,
                            isActive: isRequestingPersonalVoice,
                            chromePolicy: .alwaysSurface,
                            helpText: "Allow Epistemos to list Personal Voices",
                            accessibilityLabel: "Allow Epistemos to list Personal Voices"
                        ) {
                            requestPersonalVoiceAccess()
                        }
                        .disabled(isRequestingPersonalVoice)
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

    private var showsPersonalVoiceAccess: Bool {
        if #available(macOS 14.0, *) {
            return true
        }
        return false
    }

    private var personalVoiceGlyph: String {
        switch personalVoiceAuthorization {
        case .authorized: return "person.crop.circle.badge.checkmark"
        case .notDetermined: return "person.crop.circle.badge.questionmark"
        case .denied: return "person.crop.circle.badge.xmark"
        case .unsupported: return "person.crop.circle.badge.exclamationmark"
        }
    }

    private var personalVoiceTint: Color {
        switch personalVoiceAuthorization {
        case .authorized: return ui.theme.resolved.headingAccent.color
        case .notDetermined: return ui.theme.resolved.accent.color
        case .denied, .unsupported: return mutedTint
        }
    }

    private var personalVoiceMessage: String {
        switch personalVoiceAuthorization {
        case .authorized:
            return "Personal Voice access is allowed. Created Personal Voices can appear in the voice picker."
        case .notDetermined:
            return "Allow Personal Voice access to list voices you created in System Settings."
        case .denied:
            return "Personal Voice access is denied in System Settings. Kokoro remains the only shipped TTS lane."
        case .unsupported:
            return "Personal Voice is not supported on this Mac. Kokoro remains the only shipped TTS lane."
        }
    }

    private func requestPersonalVoiceAccess() {
        guard personalVoiceAuthorization == .notDetermined else { return }
        isRequestingPersonalVoice = true
        Task { @MainActor in
            let authorization = await EpistemosSpeechSynthesizer.requestPersonalVoiceAuthorization()
            personalVoiceAuthorization = authorization
            isRequestingPersonalVoice = false
            refreshVoicesAndHints()
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
