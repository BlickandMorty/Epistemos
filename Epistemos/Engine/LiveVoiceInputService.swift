import Foundation

nonisolated enum VoiceCapturePresentationBounds {
    static let maxStatusMessageCharacters = 512

    static func modelDownloadProgress(_ progress: Double?) -> Double? {
        guard let progress, progress.isFinite else { return nil }
        return min(1, max(0, progress))
    }

    static func statusMessage(_ message: String, fallback: String = "Voice input failed.") -> String {
        rawBoundedDiagnostic(message, maxCharacters: maxStatusMessageCharacters, fallback: fallback)
    }

    private static func rawBoundedDiagnostic(
        _ value: String,
        maxCharacters: Int,
        fallback: String
    ) -> String {
        let limit = max(0, maxCharacters)
        let bounded = String(value.prefix(limit + 1))
        let clipped: String
        if bounded.count > limit {
            clipped = limit > 3 ? String(bounded.prefix(limit - 3)) + "..." : String(bounded.prefix(limit))
        } else {
            clipped = bounded
        }
        let trimmed = normalizedDisplayText(clipped).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    static func normalizedDisplayText(_ value: String) -> String {
        var normalized = ""
        normalized.reserveCapacity(value.count)
        var previousWasSeparator = false
        for scalar in value.unicodeScalars {
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            if isSeparator {
                if !previousWasSeparator {
                    normalized.append(" ")
                    previousWasSeparator = true
                }
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            }
        }
        return normalized
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
        let bounded = String(domain.prefix(maxDomainCharacters))
        let trimmed = VoiceCapturePresentationBounds.normalizedDisplayText(bounded)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

public enum VoiceCapturePurpose: String, Sendable, Equatable {
    case quickCapture
    case meeting
    case editor

    var displayName: String {
        switch self {
        case .quickCapture:
            return "Quick Capture"
        case .meeting:
            return "Meeting"
        case .editor:
            return "the editor"
        }
    }
}

public struct VoiceCaptureLease: Sendable, Hashable {
    public let id: UUID
    public let purpose: VoiceCapturePurpose

    public init(id: UUID = UUID(), purpose: VoiceCapturePurpose) {
        self.id = id
        self.purpose = purpose
    }
}

enum VoiceCaptureLeaseAdmission: Sendable, Equatable {
    case acquired
    case alreadyOwned
    case busy(VoiceCapturePurpose)
}

struct VoiceCaptureLeaseRegistry: Sendable {
    private(set) var activeLease: VoiceCaptureLease?

    mutating func reserve(_ lease: VoiceCaptureLease) -> VoiceCaptureLeaseAdmission {
        guard let activeLease else {
            self.activeLease = lease
            return .acquired
        }
        guard activeLease != lease else {
            return .alreadyOwned
        }
        return .busy(activeLease.purpose)
    }

    func owns(_ lease: VoiceCaptureLease) -> Bool {
        activeLease == lease
    }

    @discardableResult
    mutating func release(_ lease: VoiceCaptureLease) -> Bool {
        guard activeLease == lease else { return false }
        activeLease = nil
        return true
    }
}

public enum VoiceCaptureStartResult: Sendable, Equatable {
    case started
    case busy(VoiceCapturePurpose)
    case permissionDenied(String)
    case unavailable(String)
    case failed(String)
    case cancelled
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
    public private(set) var microphoneAccessDenied = false

    private var streamTask: Task<Void, Never>?
    private var finalTranscriptBuffer: [String] = []
    private var leaseRegistry = VoiceCaptureLeaseRegistry()
    private var activeSessionID: UUID?

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

    public func isOwner(_ owner: VoiceCaptureLease) -> Bool {
        leaseRegistry.owns(owner)
    }

    public func start(owner: VoiceCaptureLease) async -> VoiceCaptureStartResult {
        switch leaseRegistry.reserve(owner) {
        case .busy(let activePurpose):
            return .busy(activePurpose)
        case .alreadyOwned:
            switch state {
            case .recording, .preparing:
                return .started
            case .unavailable(let message):
                return .unavailable(message)
            case .error(let message):
                return .failed(message)
            case .idle:
                return .cancelled
            }
        case .acquired:
            break
        }

        let sessionID = UUID()
        activeSessionID = sessionID
        partialTranscript = ""
        finalTranscript = ""
        finalTranscriptBuffer.removeAll()
        modelDownloadProgress = nil
        microphoneAccessDenied = false
        state = .preparing

        guard #available(macOS 26.0, *) else {
            let message = "Voice input requires macOS 26 SpeechAnalyzer."
            state = .unavailable(message)
            return .unavailable(message)
        }

        do {
            let readiness = await EpistemosSpeechAnalyzer.shared.readiness()
            guard isCurrentStart(sessionID: sessionID, owner: owner) else {
                finishCancelledStartIfCurrent(sessionID: sessionID, owner: owner)
                return .cancelled
            }
            guard readiness == .available || readiness == .modelDownloadRequired else {
                microphoneAccessDenied = readiness == .microphonePermissionDenied
                let message = Self.message(for: readiness)
                state = .unavailable(message)
                if readiness == .microphonePermissionDenied {
                    return .permissionDenied(message)
                }
                return .unavailable(message)
            }

            let stream = try await EpistemosSpeechAnalyzer.shared.startLive(sessionID: sessionID) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard self?.isCurrentStart(sessionID: sessionID, owner: owner) == true,
                          self?.state == .preparing else { return }
                    self?.modelDownloadProgress = VoiceCapturePresentationBounds.modelDownloadProgress(progress)
                }
            }
            guard isCurrentStart(sessionID: sessionID, owner: owner) else {
                EpistemosSpeechAnalyzer.shared.stop(sessionID: sessionID)
                finishCancelledStartIfCurrent(sessionID: sessionID, owner: owner)
                return .cancelled
            }
            modelDownloadProgress = nil
            state = .recording
            streamTask = Task { @MainActor [weak self] in
                defer {
                    if let self,
                       self.activeSessionID == sessionID,
                       self.leaseRegistry.owns(owner) {
                        if case .recording = self.state {
                            self.state = .idle
                        }
                        self.streamTask = nil
                    }
                }
                for await result in stream {
                    guard self?.isCurrentStart(sessionID: sessionID, owner: owner) == true else { break }
                    self?.handle(result)
                }
            }
            return .started
        } catch {
            EpistemosSpeechAnalyzer.shared.stop(sessionID: sessionID)
            guard isCurrentStart(sessionID: sessionID, owner: owner) else {
                finishCancelledStartIfCurrent(sessionID: sessionID, owner: owner)
                return .cancelled
            }
            let denied = Self.isMicrophonePermissionDenied(error)
            streamTask?.cancel()
            streamTask = nil
            activeSessionID = nil
            modelDownloadProgress = nil
            microphoneAccessDenied = denied
            let message = Self.message(for: error)
            state = .error(message)
            if denied {
                return .permissionDenied(message)
            }
            return .failed(message)
        }
    }

    public func stop(owner: VoiceCaptureLease) {
        guard leaseRegistry.owns(owner) else { return }
        promotePartialTranscriptForStop()
        let sessionID = activeSessionID
        activeSessionID = nil
        streamTask?.cancel()
        streamTask = nil
        if #available(macOS 26.0, *), let sessionID {
            EpistemosSpeechAnalyzer.shared.stop(sessionID: sessionID)
        }
        modelDownloadProgress = nil
        switch state {
        case .preparing, .recording, .unavailable, .error:
            state = .idle
        case .idle:
            break
        }
    }

    public func tearDown(owner: VoiceCaptureLease) {
        guard leaseRegistry.owns(owner) else { return }
        stop(owner: owner)
        partialTranscript = ""
        finalTranscript = ""
        finalTranscriptBuffer.removeAll()
        microphoneAccessDenied = false
        state = .idle
        leaseRegistry.release(owner)
    }

    public func consumeTranscript(owner: VoiceCaptureLease) -> String? {
        guard leaseRegistry.owns(owner) else { return nil }
        let pending = finalTranscriptBuffer
            .map(Self.cleanedFinalTranscript)
            .filter { !$0.isEmpty }
        finalTranscriptBuffer.removeAll()
        finalTranscript = ""
        guard !pending.isEmpty else { return nil }
        return Self.boundedTranscript(pending.joined(separator: "\n\n"))
    }

    private func isCurrentStart(sessionID: UUID, owner: VoiceCaptureLease) -> Bool {
        activeSessionID == sessionID && leaseRegistry.owns(owner) && !Task.isCancelled
    }

    private func finishCancelledStartIfCurrent(sessionID: UUID, owner: VoiceCaptureLease) {
        guard activeSessionID == sessionID, leaseRegistry.owns(owner) else { return }
        if #available(macOS 26.0, *) {
            EpistemosSpeechAnalyzer.shared.stop(sessionID: sessionID)
        }
        activeSessionID = nil
        modelDownloadProgress = nil
        if case .preparing = state {
            state = .idle
        }
    }

    private func promotePartialTranscriptForStop() {
        let cleaned = Self.cleanedFinalTranscript(partialTranscript)
        guard !cleaned.isEmpty else { return }
        if finalTranscriptBuffer.last != cleaned {
            finalTranscriptBuffer.append(cleaned)
            compactFinalTranscriptBuffer()
        }
        finalTranscript = cleaned
        partialTranscript = ""
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

    private static func isMicrophonePermissionDenied(_ error: Error) -> Bool {
        if #available(macOS 26.0, *),
           let speechError = error as? EpistemosSpeechAnalyzer.SpeechError,
           case .notAvailable(.microphonePermissionDenied) = speechError {
            return true
        }
        return false
    }
}
