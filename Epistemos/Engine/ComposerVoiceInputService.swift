import AVFoundation
import Foundation
import os
import Speech

/// Mic-to-text capture for the chat composer. Records short utterances
/// with AVAudioRecorder and transcribes them via the shared
/// `AudioTranscriber` (Apple Speech primary). Meant for utterances a
/// few seconds long — longer dictation can use the existing file-
/// import flow through `AudioTranscriber.transcribe(audioURL:)`.
@MainActor
final class ComposerVoiceInputService: ObservableObject {
    static let shared = ComposerVoiceInputService()

    enum State: Equatable {
        case idle
        case requestingPermission
        case recording(startedAt: Date)
        case transcribing
        case error(String)
    }

    @Published private(set) var state: State = .idle
    /// Latest recorded-then-transcribed text. UI binds this to insert
    /// into the composer on completion.
    @Published private(set) var latestTranscript: String = ""

    private let log = Logger(subsystem: "com.epistemos", category: "ComposerVoiceInput")
    private let transcriber = AudioTranscriber()
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?

    private init() {}

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var isBusy: Bool {
        switch state {
        case .idle, .error: return false
        case .requestingPermission, .recording, .transcribing: return true
        }
    }

    /// Toggle: starts recording if idle, stops + transcribes if already
    /// recording. Called from the composer mic button.
    func toggle() async {
        if case .recording = state {
            await stopAndTranscribe()
        } else {
            await start()
        }
    }

    // MARK: - Start

    private func start() async {
        state = .requestingPermission
        let granted = await requestMicrophonePermissionIfNeeded()
        guard granted else {
            state = .error("Microphone permission denied. Grant access in System Settings → Privacy & Security → Microphone.")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("composer-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                state = .error("Couldn't start recording. Try again or check mic permissions.")
                return
            }
            self.recorder = recorder
            self.outputURL = tempURL
            state = .recording(startedAt: Date())
        } catch {
            log.error("failed to start recorder: \(error.localizedDescription, privacy: .public)")
            state = .error("Couldn't start recording: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop + transcribe

    private func stopAndTranscribe() async {
        guard let recorder, let outputURL else {
            state = .idle
            return
        }
        recorder.stop()
        self.recorder = nil
        state = .transcribing

        do {
            let result = try await transcriber.transcribe(audioURL: outputURL)
            let cleaned = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            latestTranscript = cleaned
            state = .idle
        } catch {
            log.error("transcription failed: \(error.localizedDescription, privacy: .public)")
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
        self.outputURL = nil
    }

    /// Cancel an active recording without transcribing. Discards the
    /// partial file.
    func cancel() {
        recorder?.stop()
        recorder = nil
        if let outputURL { try? FileManager.default.removeItem(at: outputURL) }
        outputURL = nil
        state = .idle
    }

    /// Consume the latest transcript — clears `latestTranscript` so the
    /// same value doesn't fire twice on a SwiftUI `onChange`.
    func consumeTranscript() -> String? {
        let text = latestTranscript
        latestTranscript = ""
        return text.isEmpty ? nil : text
    }

    // MARK: - Permission

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        @unknown default:
            return false
        }
    }
}
