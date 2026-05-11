import AVFoundation
import Speech
import SwiftUI

// MARK: - VoiceInputButton (W15.X — Apple-native STT wiring)
//
// Drop-in mirror of `ReadAloudButton` (W9.1) for the speech-to-text
// direction. Wraps `EpistemosSpeechAnalyzer` (W10.11, macOS 26
// SpeechAnalyzer) so any view can offer "tap to dictate" without
// owning the audio engine + transcriber lifecycle.
//
// Per the W11.4 Auto/Manual Mode contract: this control treats
// dictation as a Manual-mode operation by default — the user has to
// tap to start AND tap to stop. Auto-stop on silence is opt-in via
// the `autoStopOnSilence` parameter; when enabled it stops after
// 2 s of no `partial` updates.
//
// Lifecycle:
//   tap (idle) → startLive → stream begins
//   partial result → calls onPartial(text) so the host UI can show a
//                    "..." indicator + live transcript
//   final result → calls onFinal(text) so the host commits the text
//                  into its model (text field, note body, etc.)
//   tap (recording) → stop → analyzer + audio engine torn down
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
    public let autoStopOnSilence: Bool
    public let onPartial: (String) -> Void
    public let onFinal: (String) -> Void

    @State private var phase: Phase = .idle
    @State private var streamTask: Task<Void, Never>?
    @State private var lastPartial: String = ""
    @State private var lastUpdate: Date = .distantPast
    // RCA13 RCA6-P2-002: every speech partial used to spawn a fresh
    // 2.1s `Task.sleep` check, producing task buildup under rapid
    // dictation. Coalesce by holding a single in-flight silence
    // task and cancelling/replacing it on each partial.
    @State private var silenceTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    public init(
        style: Style = .icon,
        autoStopOnSilence: Bool = false,
        onPartial: @escaping (String) -> Void = { _ in },
        onFinal: @escaping (String) -> Void
    ) {
        self.style = style
        self.autoStopOnSilence = autoStopOnSilence
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
        .disabled(phase == .requesting)
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
        case .idle:                    return "Dictate (macOS 26 on-device speech)"
        case .requesting:              return "Preparing speech model…"
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
            stopInternal()
        case .requesting:
            break
        }
    }

    private func startInternal() {
        phase = .requesting
        streamTask = Task {
            do {
                if #available(macOS 26.0, *) {
                    let stream = try await EpistemosSpeechAnalyzer.shared.startLive()
                    await MainActor.run {
                        phase = .recording
                        lastUpdate = Date()
                    }
                    for await result in stream {
                        switch result {
                        case .partial(let text):
                            await MainActor.run {
                                lastPartial = text
                                lastUpdate = Date()
                            }
                            onPartial(text)
                            if autoStopOnSilence {
                                await scheduleSilenceCheck()
                            }
                        case .final(let text):
                            onFinal(text)
                            await MainActor.run { lastPartial = "" }
                        }
                    }
                    await MainActor.run { phase = .idle }
                } else {
                    await MainActor.run {
                        phase = .error("Live dictation requires macOS 26.")
                    }
                }
            } catch let err as EpistemosSpeechAnalyzer.SpeechError {
                await MainActor.run {
                    switch err {
                    case .notAvailable(.microphonePermissionDenied):
                        phase = .error("Microphone access denied — open System Settings → Privacy → Microphone.")
                    case .notAvailable:
                        phase = .error("Speech recognition unavailable.")
                    case .audioEngineFailed(let m):
                        phase = .error("Audio engine: \(m)")
                    case .audioFormatUnavailable:
                        phase = .error("Speech audio format unavailable.")
                    case .downloadFailed(let m):
                        phase = .error("Model download: \(m)")
                    case .streamCancelled:
                        phase = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .error(error.localizedDescription)
                }
            }
        }
    }

    private func stopInternal() {
        if #available(macOS 26.0, *) {
            EpistemosSpeechAnalyzer.shared.stop()
        }
        streamTask?.cancel()
        streamTask = nil
        silenceTask?.cancel()
        silenceTask = nil
        phase = .idle
    }

    /// Auto-stop after 2 s of no `partial` updates. Coalesces under
    /// rapid partials — cancels the previous in-flight check and
    /// installs a single new 2.1 s sleep. Per RCA13 RCA6-P2-002:
    /// without coalescing, every partial spawned a fresh task that
    /// slept for 2.1 s, producing task buildup proportional to
    /// dictation speed.
    @MainActor
    private func scheduleSilenceCheck() async {
        silenceTask?.cancel()
        silenceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_100_000_000)  // 2.1 s
            if Task.isCancelled { return }
            if phase == .recording, Date().timeIntervalSince(lastUpdate) > 2.0 {
                stopInternal()
            }
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
                         autoStopOnSilence: true,
                         onPartial: { print("partial: \($0)") },
                         onFinal: { print("FINAL: \($0)") })
    }
    .padding(20)
    .environment(UIState())
}
#endif
