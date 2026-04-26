import AVFoundation
import SwiftUI

// MARK: - ReadAloudButton
//
// Wave 9.1 — drop-in SwiftUI control any view can use to expose
// AVSpeechSynthesizer-backed read-aloud for a piece of text.
// Wave 9.1.b — per-model voice + interactive playback (pause /
// resume / stop, live progress).
//
// Usage examples:
//   - Agent chat response: `ReadAloudButton(text: m.content, voiceIdentifier: profile.voiceIdentifier)`
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

    public enum Style: Sendable {
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

    @State private var synth = EpistemosSpeechSynthesizer.shared

    public init(
        text: String,
        voiceIdentifier: String? = nil,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0,
        style: Style = .icon
    ) {
        self.text = text
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
        self.style = style
    }

    public var body: some View {
        Button(action: toggle) {
            switch style {
            case .icon:
                iconLabel.frame(width: 22, height: 22)
            case .labeled:
                Label(label, systemImage: glyph)
            case .iconWithProgress:
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    Circle()
                        .trim(from: 0, to: synth.state.fractionComplete)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 22, height: 22)
                        .animation(.linear(duration: 0.2), value: synth.state.fractionComplete)
                    iconLabel
                }
            }
        }
        .buttonStyle(.borderless)
        .help(help)
        .disabled(disabled)
        .contextMenu { contextActions }
    }

    @ViewBuilder
    private var iconLabel: some View {
        Image(systemName: glyph)
            .font(.system(size: 13, weight: .semibold))
    }

    @ViewBuilder
    private var contextActions: some View {
        if synth.state.isActive {
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
                synth.speak(text, voiceIdentifier: voiceIdentifier, rate: rate, pitch: pitch)
            }
        }
    }

    // MARK: - Derived

    private var disabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isActive: Bool { synth.state.isActive }

    private var glyph: String {
        switch synth.state {
        case .idle:    return "speaker.wave.2"
        case .speaking: return "pause.circle.fill"
        case .paused:   return "play.circle.fill"
        }
    }

    private var label: String {
        switch synth.state {
        case .idle:     return "Speak"
        case .speaking: return "Pause"
        case .paused:   return "Resume"
        }
    }

    private var help: String {
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
            synth.speak(text, voiceIdentifier: voiceIdentifier, rate: rate, pitch: pitch)
        case .speaking:
            synth.pause()
        case .paused:
            synth.resume()
        }
    }
}

#if DEBUG
#Preview("ReadAloudButton — three styles") {
    VStack(spacing: 12) {
        ReadAloudButton(text: "Wave 9 lands AVSpeechSynthesizer.")
        ReadAloudButton(
            text: "Wave 9 lands AVSpeechSynthesizer with per-model voices.",
            style: .labeled
        )
        ReadAloudButton(
            text: "Live progress halo around the icon.",
            style: .iconWithProgress
        )
    }
    .padding(20)
}
#endif
