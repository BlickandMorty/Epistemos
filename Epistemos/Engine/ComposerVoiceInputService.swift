import AVFoundation
import Foundation
import os
import Speech

protocol ComposerVoiceAudioRecording: AnyObject {
    @discardableResult
    func prepareToRecord() -> Bool
    @discardableResult
    func record() -> Bool
    func stop()
}

extension AVAudioRecorder: ComposerVoiceAudioRecording {}

/// Mic-to-text capture for the chat composer. Records short utterances
/// with AVAudioRecorder and transcribes them via the shared
/// `AudioTranscriber` (Apple Speech primary). Meant for utterances a
/// few seconds long — longer dictation can use the existing file-
/// import flow through `AudioTranscriber.transcribe(audioURL:)`.
@MainActor
@Observable
final class ComposerVoiceInputService {
    static let shared = ComposerVoiceInputService()

    enum State: Equatable {
        case idle
        case requestingPermission
        case recording(startedAt: Date)
        case transcribing
        case error(String)
    }

    private(set) var state: State = .idle
    /// Latest recorded-then-transcribed text. UI binds this to insert
    /// into the composer on completion.
    private(set) var latestTranscript: String = ""

    private let log = Logger(subsystem: "com.epistemos", category: "ComposerVoiceInput")
    private let tempDirectory: URL
    private let permissionProvider: @Sendable () async -> Bool
    private let recorderFactory: @MainActor (URL, [String: Any]) throws -> ComposerVoiceAudioRecording
    private let transcribeAudio: @Sendable (URL) async throws -> TranscribedAudio

    private var recorder: ComposerVoiceAudioRecording?
    private var outputURL: URL?

    private convenience init() {
        let transcriber = AudioTranscriber()
        self.init(
            tempDirectory: FileManager.default.temporaryDirectory,
            permissionProvider: { await Self.requestMicrophonePermissionIfNeeded() },
            recorderFactory: { url, settings in
                try AVAudioRecorder(url: url, settings: settings)
            },
            transcribeAudio: { url in
                try await transcriber.transcribe(audioURL: url)
            }
        )
    }

    init(
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        permissionProvider: @escaping @Sendable () async -> Bool,
        recorderFactory: @escaping @MainActor (URL, [String: Any]) throws -> ComposerVoiceAudioRecording,
        transcribeAudio: @escaping @Sendable (URL) async throws -> TranscribedAudio
    ) {
        self.tempDirectory = tempDirectory
        self.permissionProvider = permissionProvider
        self.recorderFactory = recorderFactory
        self.transcribeAudio = transcribeAudio
    }

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
        let granted = await permissionProvider()
        guard granted else {
            state = .error("Microphone permission denied. Grant access in System Settings → Privacy & Security → Microphone.")
            return
        }

        cleanupOutputFileIfNeeded()
        let tempURL = tempDirectory
            .appendingPathComponent("composer-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let recorder = try recorderFactory(tempURL, settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                cleanupRecording(at: tempURL)
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

        defer {
            cleanupRecording(at: outputURL)
            if self.outputURL == outputURL {
                self.outputURL = nil
            }
        }

        do {
            let result = try await transcribeAudio(outputURL)
            let cleaned = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            latestTranscript = cleaned
            state = .idle
        } catch {
            log.error("transcription failed: \(error.localizedDescription, privacy: .public)")
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
    }

    /// Cancel an active recording without transcribing. Discards the
    /// partial file.
    func cancel() {
        recorder?.stop()
        recorder = nil
        cleanupOutputFileIfNeeded()
        state = .idle
    }

    /// Tear down an in-flight composer recording when its owning UI disappears.
    func tearDown() {
        cancel()
        latestTranscript = ""
    }

    /// Consume the latest transcript — clears `latestTranscript` so the
    /// same value doesn't fire twice on a SwiftUI `onChange`.
    func consumeTranscript() -> String? {
        let text = latestTranscript
        latestTranscript = ""
        return text.isEmpty ? nil : text
    }

    // MARK: - Permission

    private static func requestMicrophonePermissionIfNeeded() async -> Bool {
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

    private func cleanupOutputFileIfNeeded() {
        guard let outputURL else { return }
        cleanupRecording(at: outputURL)
        self.outputURL = nil
    }

    private func cleanupRecording(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            log.error("Failed to delete composer temp audio: \(error.localizedDescription, privacy: .public)")
        }
    }
}
