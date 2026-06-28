import Foundation

// MARK: - LiveVoiceInputService
//
// Small UI-facing facade over EpistemosSpeechAnalyzer. Views get a stable
// start/stop/state contract and never own AVAudioEngine or SpeechAnalyzer
// details directly.

@MainActor
@Observable
public final class LiveVoiceInputService {
    public enum State: Equatable, Sendable {
        case idle
        case preparing
        case recording
        case unavailable(String)
        case error(String)
    }

    public static let shared = LiveVoiceInputService()

    public private(set) var state: State = .idle
    public private(set) var partialTranscript = ""
    public private(set) var finalTranscript = ""
    public private(set) var modelDownloadProgress: Double?

    private var streamTask: Task<Void, Never>?

    private init() {}

    public var isRecording: Bool {
        state == .recording
    }

    public var isBusy: Bool {
        switch state {
        case .preparing, .recording:
            return true
        case .idle, .unavailable, .error:
            return false
        }
    }

    public var isUnavailable: Bool {
        if case .unavailable = state {
            return true
        }
        return false
    }

    public func toggle() async {
        if isRecording {
            stop()
        } else {
            await start()
        }
    }

    public func start() async {
        stop()
        partialTranscript = ""
        finalTranscript = ""
        modelDownloadProgress = nil
        state = .preparing

        guard #available(macOS 26.0, *) else {
            state = .unavailable("Voice input requires macOS 26 SpeechAnalyzer.")
            return
        }

        do {
            let readiness = await EpistemosSpeechAnalyzer.shared.readiness()
            guard readiness == .available || readiness == .modelDownloadRequired else {
                state = .unavailable(Self.message(for: readiness))
                return
            }

            let stream = try await EpistemosSpeechAnalyzer.shared.startLive { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.modelDownloadProgress = progress
                }
            }
            state = .recording
            streamTask = Task { @MainActor [weak self] in
                defer {
                    if let self, case .recording = self.state {
                        self.state = .idle
                    }
                    self?.streamTask = nil
                }
                for await result in stream {
                    self?.handle(result)
                }
            }
        } catch {
            stop()
            state = .error(Self.message(for: error))
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
        if #available(macOS 26.0, *) {
            EpistemosSpeechAnalyzer.shared.stop()
        }
        modelDownloadProgress = nil
        if case .recording = state {
            state = .idle
        } else if case .preparing = state {
            state = .idle
        }
    }

    public func tearDown() {
        stop()
        partialTranscript = ""
        finalTranscript = ""
        state = .idle
    }

    public func consumeTranscript() -> String? {
        let text = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        finalTranscript = ""
        return text
    }

    @available(macOS 26.0, *)
    private func handle(_ result: EpistemosSpeechAnalyzer.LiveResult) {
        switch result {
        case .partial(let text):
            partialTranscript = text
        case .final(let text):
            finalTranscript = text
            partialTranscript = ""
        }
    }

    @available(macOS 26.0, *)
    private static func message(for readiness: EpistemosSpeechAnalyzer.Readiness) -> String {
        switch readiness {
        case .available:
            return ""
        case .sdkUnavailable:
            return "Voice input requires macOS 26 SpeechAnalyzer."
        case .microphonePermissionDenied:
            return "Microphone access is denied in System Settings."
        case .modelDownloadRequired:
            return "Speech transcription model download is required."
        }
    }

    private static func message(for error: Error) -> String {
        if #available(macOS 26.0, *),
           let speechError = error as? EpistemosSpeechAnalyzer.SpeechError {
            switch speechError {
            case .notAvailable(let readiness):
                return message(for: readiness)
            case .audioFormatUnavailable:
                return "No compatible microphone format is available for SpeechAnalyzer."
            case .audioEngineFailed(let detail):
                return "Voice input could not start: \(detail)"
            case .downloadFailed(let detail):
                return "Speech model download failed: \(detail)"
            case .streamCancelled:
                return "Voice input was cancelled."
            }
        }
        return "Voice input failed: \(String(describing: error))"
    }
}
