import Foundation

nonisolated enum VoiceCapturePresentationBounds {
    static let maxStatusMessageCharacters = 512

    static func modelDownloadProgress(_ progress: Double?) -> Double? {
        guard let progress, progress.isFinite else { return nil }
        return min(1, max(0, progress))
    }

    static func statusMessage(_ message: String, fallback: String = "Voice input failed.") -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxStatusMessageCharacters else { return value }
        return String(value.prefix(maxStatusMessageCharacters))
    }
}

nonisolated enum VoiceCaptureDiagnostics {
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func externalErrorDescription(_ error: Error, fallback: String) -> String {
        let nsError = error as NSError
        let domain = safeDomain(nsError.domain)
        return VoiceCapturePresentationBounds.statusMessage(
            "\(fallback) (domain=\(domain) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func externalStatusMessage(_ prefix: String, error: Error) -> String {
        VoiceCapturePresentationBounds.statusMessage(
            "\(prefix): \(externalErrorDescription(error, fallback: "external failure"))",
            fallback: prefix
        )
    }

    static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let clamped = String(value.prefix(maxDomainCharacters))
        return clamped.isEmpty ? "Error" : clamped
    }
}

// MARK: - LiveVoiceInputService
//
// Small UI-facing facade over EpistemosSpeechAnalyzer. Views get a stable
// start/stop/state contract and never own AVAudioEngine or SpeechAnalyzer
// details directly.

@MainActor
@Observable
public final class LiveVoiceInputService {
    nonisolated static let maxTranscriptCharacters = TextCapturePipeline.maxCleanedTextCharacters

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
    private var finalTranscriptBuffer: [String] = []
    private var startGeneration = UUID()

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
        let generation = UUID()
        startGeneration = generation
        partialTranscript = ""
        finalTranscript = ""
        finalTranscriptBuffer.removeAll()
        modelDownloadProgress = nil
        state = .preparing

        guard #available(macOS 26.0, *) else {
            state = .unavailable("Voice input requires macOS 26 SpeechAnalyzer.")
            return
        }

        do {
            let readiness = await EpistemosSpeechAnalyzer.shared.readiness()
            guard isCurrentStart(generation) else {
                finishCancelledStartIfCurrent(generation)
                return
            }
            guard readiness == .available || readiness == .modelDownloadRequired else {
                state = .unavailable(Self.message(for: readiness))
                return
            }

            let stream = try await EpistemosSpeechAnalyzer.shared.startLive { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard self?.isCurrentStart(generation) == true else { return }
                    self?.modelDownloadProgress = VoiceCapturePresentationBounds.modelDownloadProgress(progress)
                }
            }
            guard isCurrentStart(generation) else {
                EpistemosSpeechAnalyzer.shared.stop()
                finishCancelledStartIfCurrent(generation)
                return
            }
            state = .recording
            streamTask = Task { @MainActor [weak self] in
                defer {
                    if let self, self.startGeneration == generation {
                        if case .recording = self.state {
                            self.state = .idle
                        }
                        self.streamTask = nil
                    }
                }
                for await result in stream {
                    guard self?.isCurrentStart(generation) == true else { break }
                    self?.handle(result)
                }
            }
        } catch {
            EpistemosSpeechAnalyzer.shared.stop()
            guard isCurrentStart(generation) else {
                finishCancelledStartIfCurrent(generation)
                return
            }
            stop()
            state = .error(Self.message(for: error))
        }
    }

    public func stop() {
        startGeneration = UUID()
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
        finalTranscriptBuffer.removeAll()
        state = .idle
    }

    public func consumeTranscript() -> String? {
        let pending = finalTranscriptBuffer
            .map(Self.cleanedFinalTranscript)
            .filter { !$0.isEmpty }
        finalTranscriptBuffer.removeAll()
        finalTranscript = ""
        guard !pending.isEmpty else { return nil }
        return Self.boundedTranscript(pending.joined(separator: "\n\n"))
    }

    private func isCurrentStart(_ generation: UUID) -> Bool {
        startGeneration == generation && !Task.isCancelled
    }

    private func finishCancelledStartIfCurrent(_ generation: UUID) {
        guard startGeneration == generation else { return }
        modelDownloadProgress = nil
        if case .preparing = state {
            state = .idle
        }
    }

    @available(macOS 26.0, *)
    private func handle(_ result: EpistemosSpeechAnalyzer.LiveResult) {
        switch result {
        case .partial(let text):
            partialTranscript = Self.boundedTranscript(text)
        case .final(let text):
            let cleaned = Self.cleanedFinalTranscript(text)
            guard !cleaned.isEmpty else { return }
            finalTranscriptBuffer.append(cleaned)
            compactFinalTranscriptBuffer()
            finalTranscript = cleaned
            partialTranscript = ""
        }
    }

    nonisolated static func boundedTranscript(_ text: String) -> String {
        guard text.count > maxTranscriptCharacters else { return text }
        return String(text.prefix(maxTranscriptCharacters))
    }

    nonisolated static func cleanedFinalTranscript(_ text: String) -> String {
        boundedTranscript(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func compactFinalTranscriptBuffer() {
        let pending = finalTranscriptBuffer.joined(separator: "\n\n")
        guard pending.count > Self.maxTranscriptCharacters else { return }
        let bounded = Self.boundedTranscript(pending)
        finalTranscriptBuffer = bounded.isEmpty ? [] : [bounded]
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
                return VoiceCapturePresentationBounds.statusMessage("Voice input could not start: \(detail)")
            case .downloadFailed(let detail):
                return VoiceCapturePresentationBounds.statusMessage("Speech model download failed: \(detail)")
            case .streamCancelled:
                return "Voice input was cancelled."
            }
        }
        return VoiceCaptureDiagnostics.externalStatusMessage("Voice input failed", error: error)
    }
}
