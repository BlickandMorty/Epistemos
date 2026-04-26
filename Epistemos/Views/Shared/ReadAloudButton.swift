import SwiftUI

// MARK: - ReadAloudButton
//
// Wave 9.1 — drop-in SwiftUI control any view can use to expose
// AVSpeechSynthesizer-backed read-aloud for a piece of text.
//
// Usage examples (covered by W9 verdict §"For what specifically"):
//   - Agent chat response: `ReadAloudButton(text: message.content)`
//     in the assistant message bubble.
//   - Note body: `ReadAloudButton(text: note.body)` in the note
//     toolbar / context menu.
//   - Selection in the Tiptap editor: bubble menu adds a "Speak"
//     command that materialises the selection text and pipes it
//     through here.
//
// The button is stateful — it flips between speaker glyph (idle) and
// stop glyph (speaking), and disables itself for empty text. All
// playback state lives in `EpistemosSpeechSynthesizer.shared` so
// switching focus between two read-aloud buttons interrupts cleanly.

@MainActor
public struct ReadAloudButton: View {

    public enum Style: Sendable {
        /// Compact icon-only button, matches toolbar density.
        case icon
        /// Icon + "Speak" / "Stop" label, matches menu rows.
        case labeled
    }

    public let text: String
    public let style: Style

    @State private var synth = EpistemosSpeechSynthesizer.shared

    public init(text: String, style: Style = .icon) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Button(action: toggle) {
            switch style {
            case .icon:
                Image(systemName: glyph)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22, height: 22)
            case .labeled:
                Label(label, systemImage: glyph)
            }
        }
        .buttonStyle(.borderless)
        .help(help)
        .disabled(disabled)
        .keyboardShortcut(.init("\u{2013}"), modifiers: [])  // dummy to participate in shortcuts
    }

    // MARK: - Derived

    private var disabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isActive: Bool {
        switch synth.state {
        case .idle: return false
        case .speaking, .paused: return true
        }
    }

    private var glyph: String {
        isActive ? "stop.circle" : "speaker.wave.2"
    }

    private var label: String {
        isActive ? "Stop" : "Speak"
    }

    private var help: String {
        isActive ? "Stop reading aloud" : "Read aloud"
    }

    // MARK: - Action

    private func toggle() {
        if isActive {
            synth.stop()
        } else {
            synth.speak(text)
        }
    }
}

#if DEBUG
#Preview("ReadAloudButton — icon") {
    ReadAloudButton(text: "Wave 9 lands AVSpeechSynthesizer.")
        .padding(20)
}

#Preview("ReadAloudButton — labeled") {
    ReadAloudButton(
        text: "Wave 9 lands AVSpeechSynthesizer with a Material 3 button.",
        style: .labeled
    )
    .padding(20)
}
#endif
