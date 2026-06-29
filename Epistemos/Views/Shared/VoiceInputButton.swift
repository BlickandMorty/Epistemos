import SwiftUI

// MARK: - VoiceInputButton (W15.X — Apple-native STT wiring)
//
// Drop-in mirror of `ReadAloudButton` (W9.1) for the speech-to-text direction.
// Uses LiveVoiceInputService so views can offer "tap to dictate" without
// owning the audio lifecycle.
//
// Per the W11.4 Auto/Manual Mode contract: this reusable control treats
// dictation as a manual operation. Surfaces that support automatic
// silence-stop own that policy at their capture-service boundary.
//
// Lifecycle:
//   tap (idle) → recorder starts
//   tap (recording) → recorder stops → transcriber produces final text
//   final result → calls onFinal(text) so the host commits the text into its
//                  model (text field, note body, etc.)
//
// The control is stateful — flips between mic / mic.fill /
// stop.circle.fill depending on phase. Uses the system accent color
// for the "actively recording" pip so it matches Apple's own
// dictation UI in TextEdit / Notes.

@MainActor
public struct VoiceInputButton: View {

    public enum Style: Sendable {
        /// Compact icon-only button; matches toolbar density.
        case icon
        /// Icon + "Dictate" / "Stop" label; matches menu rows.
        case labeled
        /// Icon with a pulsating ring while recording — matches the
        /// system Notes app dictation affordance.
        case iconWithPulse
    }

    public let style: Style
    public let onPartial: (String) -> Void
    public let onFinal: (String) -> Void

    @State private var phase: Phase = .idle
    @State private var streamTask: Task<Void, Never>?
    @State private var service = LiveVoiceInputService.shared
    @State private var ownsCapture = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    public init(
        style: Style = .icon,
        onPartial: @escaping (String) -> Void = { _ in },
        onFinal: @escaping (String) -> Void
    ) {
        self.style = style
        self.onPartial = onPartial
        self.onFinal = onFinal
    }

    private enum Phase: Sendable, Equatable {
        case idle
        case requesting     // model download / mic permission in flight
        case recording
        case error(String)
    }

    public var body: some View {
        Button(action: toggle) {
            switch style {
            case .icon:
                iconLabel.frame(width: 22, height: 22)
            case .labeled:
                Label(label, systemImage: glyph)
            case .iconWithPulse:
                ZStack {
                    if phase == .recording {
                        recordingPulseRing
                    }
                    iconLabel
                }
            }
        }
        .buttonStyle(.borderless)
        .help(help)
        .disabled(phase == .requesting || service.isUnavailable)
        .onChange(of: service.partialTranscript) { _, newValue in
            guard ownsCapture, !newValue.isEmpty else { return }
            onPartial(newValue)
        }
        .onChange(of: service.finalTranscript) { _, newValue in
            guard ownsCapture, !newValue.isEmpty else { return }
            if let transcript = service.consumeTranscript() {
                onFinal(transcript)
                syncPhaseFromService()
            }
        }
        .onChange(of: service.state) { _, _ in
            syncPhaseFromService()
        }
        .onDisappear { stopInternal() }
    }

    @ViewBuilder
    private var iconLabel: some View {
        Image(systemName: glyph)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(phase == .recording ? Color.accentColor : Color.primary)
    }

    private var glyph: String {
        switch phase {
        case .idle:       return "mic"
        case .requesting: return "mic.badge.plus"
        case .recording:  return "stop.circle.fill"
        case .error:      return "mic.slash"
        }
    }

    private var label: String {
        switch phase {
        case .idle:       return "Dictate"
        case .requesting: return "Preparing…"
        case .recording:  return "Stop"
        case .error:      return "Unavailable"
        }
    }

    private var help: String {
        switch phase {
        case .idle:                    return "Dictate"
        case .requesting:              return "Preparing voice capture…"
        case .recording:               return "Stop dictation"
        case .error(let msg):          return msg
        }
    }

    @ViewBuilder
    private var recordingPulseRing: some View {
        if reduceMotion || ui.windowOccluded {
            Circle()
                .stroke(Color.accentColor.opacity(0.28), lineWidth: 1.5)
                .frame(width: 26, height: 26)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let progress = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.0)
                Circle()
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                    .scaleEffect(1.0 + progress)
                    .opacity(1.0 - progress)
            }
        }
    }

    // MARK: - Toggle

    private func toggle() {
        switch phase {
        case .idle, .error:
            startInternal()
        case .recording:
            finishInternal()
        case .requesting:
            break
        }
    }

    private func startInternal() {
        ownsCapture = true
        phase = .requesting
        streamTask?.cancel()
        streamTask = Task {
            await service.toggle()
            syncPhaseFromService()
        }
    }

    private func finishInternal() {
        phase = .requesting
        streamTask?.cancel()
        streamTask = Task {
            await service.toggle()
            syncPhaseFromService()
        }
    }

    private func stopInternal() {
        streamTask?.cancel()
        streamTask = nil
        if ownsCapture {
            service.tearDown()
            ownsCapture = false
        }
        phase = .idle
    }

    private func syncPhaseFromService() {
        switch service.state {
        case .idle:
            phase = .idle
            ownsCapture = false
        case .preparing:
            phase = .requesting
        case .recording:
            phase = .recording
        case .unavailable(let message), .error(let message):
            phase = .error(message)
            ownsCapture = false
        }
    }
}

#if DEBUG
@available(macOS 26.0, *)
#Preview("VoiceInputButton — three styles") {
    VStack(spacing: 16) {
        VoiceInputButton(onFinal: { print("FINAL: \($0)") })
        VoiceInputButton(style: .labeled,
                         onFinal: { print("FINAL: \($0)") })
        VoiceInputButton(style: .iconWithPulse,
                         onPartial: { print("partial: \($0)") },
                         onFinal: { print("FINAL: \($0)") })
    }
    .padding(20)
    .environment(UIState())
}
#endif
