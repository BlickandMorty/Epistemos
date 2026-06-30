import Foundation
import SwiftData

nonisolated enum VoiceDecisionMode: Sendable {
    case auto
    case manual
}

@MainActor
final class VoicePreferences {
    static let shared = VoicePreferences()
    var dictationAutoStop: VoiceDecisionMode = .manual
}

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

    static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\:")) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let bounded = String(value.prefix(maxDomainCharacters))
        return bounded.isEmpty ? "Error" : bounded
    }
}

@MainActor
final class LiveVoiceInputService {
    enum State: Equatable, Sendable {
        case idle
        case preparing
        case recording
        case unavailable(String)
        case error(String)
    }

    static let shared = LiveVoiceInputService()

    var state: State = .idle
    var partialTranscript = ""
    var modelDownloadProgress: Double?
    var finalTranscripts: [String] = []

    func start() async {
        state = .recording
    }

    func stop() {
        state = .idle
    }

    func tearDown() {
        state = .idle
        partialTranscript = ""
        finalTranscripts.removeAll()
    }

    func consumeTranscript() -> String? {
        guard !finalTranscripts.isEmpty else { return nil }
        return finalTranscripts.removeFirst()
    }
}

enum TextCaptureError: Error, Equatable {
    case emptyCapture
    case persistenceFailed(String)
    case graphUnavailable(String)
}

struct CaptureSourceMetadata: Sendable, Equatable {
    let source: String
    let sourceKind: String
    let capturedAt: Date
    let durationSeconds: Int?
    let sttEngine: String?
    let audioSource: String?

    static func meetingSTT(
        capturedAt: Date = Date(),
        durationSeconds: Int,
        audioSource: String? = nil
    ) -> CaptureSourceMetadata {
        CaptureSourceMetadata(
            source: "meeting_stt",
            sourceKind: "audio_transcript",
            capturedAt: capturedAt,
            durationSeconds: durationSeconds,
            sttEngine: "apple_speechanalyzer",
            audioSource: audioSource
        )
    }
}

struct CaptureResult: Sendable {
    let createdNoteID: String?
    let title: String
    let transcription: String
    let sourceMetadata: CaptureSourceMetadata?
}

@MainActor
final class TextCapturePipeline {
    struct Call: Sendable {
        let transcription: String
        let sourceMetadata: CaptureSourceMetadata?
    }

    nonisolated static let maxCleanedTextCharacters = 10_000
    static var calls: [Call] = []

    func runFromAudio(
        transcription: String,
        modelContext: ModelContext,
        sourceMetadata: CaptureSourceMetadata? = nil
    ) async throws -> CaptureResult {
        Self.calls.append(Call(transcription: transcription, sourceMetadata: sourceMetadata))
        return CaptureResult(
            createdNoteID: "meeting-smoke-page",
            title: "Launch review",
            transcription: transcription,
            sourceMetadata: sourceMetadata
        )
    }
}

@Model
final class MeetingSTTSmokeModel {
    var id: String

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}
