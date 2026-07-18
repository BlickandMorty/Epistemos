import AVFoundation
import SwiftUI

// MARK: - ReadAloudButton
//
// Wave 9.1 — drop-in SwiftUI control any view can use to expose
// Kokoro-only read-aloud control for a piece of text.
// Interactive playback supports pause, resume, stop, and live progress.
//
// Usage examples:
//   - Note body: `ReadAloudButton(text: note.body)` in the note toolbar
//   - Selection in the Tiptap editor: bubble menu adds a "Speak"
//     command that materialises the selection text and pipes it
//     through here.
//
// The control is stateful — it flips between speaker glyph (idle),
// pause glyph (speaking), play glyph (paused), with a live progress
// halo showing how much of the utterance has been spoken. All
// playback state lives in `EpistemosSpeechSynthesizer.shared` so
// switching focus between two read-aloud buttons interrupts cleanly.

@MainActor
public struct ReadAloudButton: View {

    public enum Style: Sendable, Equatable {
        /// Compact icon-only button, matches toolbar density.
        case icon
        /// Icon + "Speak" / "Pause" / "Resume" label, matches menu rows.
        case labeled
        /// Compact icon + thin progress halo around the icon.
        case iconWithProgress
    }

    public let text: String
    public let voiceIdentifier: String?
    public let rate: Float
    public let pitch: Float
    public let style: Style
    public let surface: EpistemosVisibleReadAloudSurface?

    @State private var synth = EpistemosSpeechSynthesizer.shared
    @State private var prefs = VoicePreferences.shared
    @State private var downloader = KokoroModelDownloadService.shared
    @State private var isShowingKokoroInstallPrompt = false
    @Environment(UIState.self) private var ui

    public init(
        text: String,
        voiceIdentifier: String? = nil,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0,
        style: Style = .icon,
        surface: EpistemosVisibleReadAloudSurface? = nil
    ) {
        self.text = text
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
        self.style = style
        self.surface = surface
    }

    public var body: some View {
        HStack(spacing: style == .labeled ? 6 : 2) {
            nativeButton
                .disabled(disabled)
            voiceEffectMenu
        }
        .contextMenu { contextActions }
        .sheet(isPresented: $isShowingKokoroInstallPrompt) {
            KokoroVoiceInstallPrompt()
                .environment(ui)
        }
        .onChange(of: downloader.phase) { _, newPhase in
            if case .installed = newPhase, isTextToSpeechAvailable {
                isShowingKokoroInstallPrompt = false
            }
        }
    }

    @ViewBuilder
    private var nativeButton: some View {
        switch style {
        case .icon, .labeled:
            toolbarButton
        case .iconWithProgress:
            ZStack {
                progressRing
                toolbarButton
            }
            .frame(width: 32, height: 32)
        }
    }

    private var toolbarButton: some View {
        ToolbarCapsuleButton(
            title: style == .labeled ? label : nil,
            systemImage: glyph,
            role: isActive ? .primaryAction : .toolbarUtility,
            isActive: isActive,
            chromePolicy: chromePolicy,
            helpText: help,
            accessibilityLabel: label
        ) {
            toggle()
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(progressTrackColor, lineWidth: 1.5)
                .frame(width: 26, height: 26)
            Circle()
                .trim(from: 0, to: synth.state.fractionComplete)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 26, height: 26)
                .animation(.linear(duration: 0.2), value: synth.state.fractionComplete)
        }
    }

    @ViewBuilder
    private var contextActions: some View {
        if VoicePreferences.allowsReadAloudEffects {
            Button("Effect: \(prefs.readAloudEffect.label)", systemImage: prefs.readAloudEffect.systemImage) {}
                .disabled(true)
            ForEach(VoiceEffect.allCases) { effect in
                Button(effect.label, systemImage: effect == prefs.readAloudEffect ? "checkmark" : effect.systemImage) {
                    prefs.readAloudEffect = effect
                }
            }
            Divider()
        }

        if !isTextToSpeechInputSupported {
            Text(EpistemosSpeechSynthesizer.textToSpeechStatusMessage(for: text))
        } else if !isTextToSpeechAvailable {
            Text(EpistemosSpeechSynthesizer.textToSpeechStatusMessage())
            Button(
                KokoroVoiceInstallPresentation.sheetTitle,
                systemImage: KokoroVoiceInstallPresentation.installSystemImage
            ) {
                isShowingKokoroInstallPrompt = true
            }
        } else if synth.state.isActive {
            Button("Stop", systemImage: "stop.fill") { synth.stop() }
            switch synth.state {
            case .speaking:
                Button("Pause", systemImage: "pause.fill") { synth.pause() }
            case .paused:
                Button("Resume", systemImage: "play.fill") { synth.resume() }
            case .idle:
                EmptyView()
            }
        } else {
            Button("Speak", systemImage: "speaker.wave.2") {
                speakCurrentText()
            }
        }
    }

    @ViewBuilder
    private var voiceEffectMenu: some View {
        if VoicePreferences.allowsReadAloudEffects {
            Menu {
                ForEach(VoiceEffect.allCases) { effect in
                    Button(effect.label, systemImage: effect == prefs.readAloudEffect ? "checkmark" : effect.systemImage) {
                        prefs.readAloudEffect = effect
                    }
                }
            } label: {
                Image(systemName: prefs.readAloudEffect.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ui.theme.resolved.mutedForeground.color)
                    .frame(width: 28, height: 28)
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .help("Read-aloud filter: \(prefs.readAloudEffect.label)")
            .accessibilityLabel("Read-aloud filter: \(prefs.readAloudEffect.label)")
        }
    }

    // MARK: - Derived

    private var disabled: Bool {
        false
    }

    private var isActive: Bool { synth.state.isActive }

    private var isTextToSpeechAvailable: Bool {
        EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
    }

    private var isTextToSpeechInputSupported: Bool {
        EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(text)
    }

    private var chromePolicy: NativeControlChromePolicy {
        switch style {
        case .labeled:
            return .alwaysSurface
        case .icon, .iconWithProgress:
            return isActive ? .alwaysSurface : .bareUntilPressed
        }
    }

    private var progressTrackColor: Color {
        ui.theme.resolved.foreground.color.opacity(ui.theme.isDark ? 0.14 : 0.10)
    }

    private var progressColor: Color {
        ui.theme.resolved.accent.color
    }

    private var glyph: String {
        guard isTextToSpeechAvailable else { return KokoroVoiceInstallPresentation.installSystemImage }
        switch synth.state {
        case .idle:    return "speaker.wave.2"
        case .speaking: return "pause.circle.fill"
        case .paused:   return "play.circle.fill"
        }
    }

    private var label: String {
        guard isTextToSpeechAvailable else { return KokoroVoiceInstallPresentation.unavailableLabel }
        switch synth.state {
        case .idle:     return "Speak"
        case .speaking: return "Pause"
        case .paused:   return "Resume"
        }
    }

    private var help: String {
        guard isTextToSpeechAvailable else {
            return KokoroVoiceInstallPresentation.installHelp(
                statusMessage: EpistemosSpeechSynthesizer.textToSpeechStatusMessage()
            )
        }
        guard isTextToSpeechInputSupported else {
            return "Read aloud the first supported passage"
        }
        switch synth.state {
        case .idle:     return "Read aloud"
        case .speaking: return "Pause read-aloud"
        case .paused:   return "Resume read-aloud"
        }
    }

    // MARK: - Action

    private func toggle() {
        switch synth.state {
        case .idle:
            speakCurrentText()
        case .speaking:
            synth.pause()
        case .paused:
            synth.resume()
        }
    }

    private func speakCurrentText() {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            EpistemosReadAloudDiagnostics.showNoVisibleTextToast(surface: surface)
            return
        }
        EpistemosSpeechSynthesizer.logTextToSpeechReadiness(
            context: surface?.rawValue ?? "read-aloud-button"
        )
        guard EpistemosSpeechSynthesizer.isTextToSpeechAvailable() else {
            EpistemosReadAloudDiagnostics.showUnavailableToast()
            isShowingKokoroInstallPrompt = true
            return
        }

        var speechText = cleaned
        if !EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(cleaned) {
            let prepared = EpistemosReadAloud.responsiveReadVisibleText(
                cleaned,
                surface: surface
            )
            speechText = prepared.text
            if let surface {
                EpistemosReadAloudDiagnostics.showExcerptToast(surface: surface)
            } else {
                EpistemosReadAloudDiagnostics.showInputExcerptToast()
            }
        }

        guard EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(speechText) else {
            EpistemosReadAloudDiagnostics.showUnavailableToast(
                EpistemosSpeechSynthesizer.textToSpeechStatusMessage(for: speechText)
            )
            return
        }
        let utteranceID = synth.speak(
            speechText,
            voiceIdentifier: voiceIdentifier,
            rate: rate,
            pitch: pitch,
            effect: prefs.readAloudEffect
        )
        if utteranceID != nil {
            EpistemosReadAloudDiagnostics.showQueuedToast(surface: surface)
        } else {
            EpistemosReadAloudDiagnostics.showFailureToast("Kokoro read-aloud could not start. Check Settings > Voice.")
        }
    }
}

#if DEBUG
#Preview("ReadAloudButton — three styles") {
    VStack(spacing: 12) {
        ReadAloudButton(text: "Kokoro read-aloud is installable from this button.")
        ReadAloudButton(
            text: "Kokoro read-aloud stays local and model-gated.",
            style: .labeled
        )
        ReadAloudButton(
            text: "Live progress halo around the icon.",
            style: .iconWithProgress
        )
    }
    .padding(20)
    .environment(UIState())
}
#endif
