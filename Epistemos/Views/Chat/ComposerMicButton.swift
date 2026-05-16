import SwiftUI

/// Mic button for the chat composer. Tap to toggle recording;
/// record-in-progress shows a pulsing red dot + timer; busy states
/// (permission request / transcribing) show a spinner. On transcript
/// completion the bound `onTranscript` closure fires with the text so
/// the composer can insert it at the cursor / append to existing draft.
struct ComposerMicButton: View {
    let onTranscript: (String) -> Void
    @State private var service = ComposerVoiceInputService.shared

    var body: some View {
        Button {
            Task { await service.toggle() }
        } label: {
            label
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: service.latestTranscript) { _, newValue in
            guard !newValue.isEmpty else { return }
            if let transcript = service.consumeTranscript() {
                onTranscript(transcript)
            }
        }
        .onDisappear {
            service.tearDown()
        }
    }

    @ViewBuilder
    private var label: some View {
        switch service.state {
        case .idle, .error:
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        case .requestingPermission, .transcribing:
            ProgressView()
                .controlSize(.mini)
        case .recording(let startedAt):
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .breathe(amplitude: 0.35, period: 0.85)
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text(duration(startedAt, now: context.date))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var help: String {
        switch service.state {
        case .idle: "Record voice (transcribe into composer)"
        case .requestingPermission: "Checking microphone permission…"
        case .recording: "Tap to stop + transcribe"
        case .transcribing: "Transcribing…"
        case .error(let message): message
        }
    }

    private var accessibilityLabel: String {
        switch service.state {
        case .recording: "Stop recording"
        default: "Start voice recording"
        }
    }

    private func duration(_ start: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%d:%02d", m, s)
    }
}
