import Foundation
import Observation
import SwiftData

@MainActor
protocol MeetingVoiceInputProviding: AnyObject {
    var state: LiveVoiceInputService.State { get }
    var partialTranscript: String { get }
    var modelDownloadProgress: Double? { get }

    func start() async
    func stop()
    func tearDown()
    func consumeTranscript() -> String?
}

extension LiveVoiceInputService: MeetingVoiceInputProviding {}

nonisolated enum MeetingCaptureDiagnostics {
    static func statusMessage(for error: Error) -> String {
        let message: String
        if let captureError = error as? TextCaptureError {
            switch captureError {
            case .emptyCapture:
                message = "Meeting note needs a transcript before saving."
            case .persistenceFailed:
                message = "Meeting note persistence failed."
            case .graphUnavailable:
                message = "Meeting note graph write unavailable."
            }
        } else {
            let nsError = error as NSError
            let domain = VoiceCaptureDiagnostics.safeDomain(nsError.domain)
            message = "Meeting note save failed (domain=\(domain) code=\(nsError.code))."
        }
        return VoiceCapturePresentationBounds.statusMessage(message)
    }
}

// MARK: - MeetingNoteCaptureService
//
// Meeting/lecture capture owns transcript buffering and note finalization.
// LiveVoiceInputService remains the only STT dependency; TextCapturePipeline
// remains the only note/graph/provenance writer.

@MainActor
@Observable
final class MeetingNoteCaptureService {
    nonisolated static let maxTranscriptCharacters = TextCapturePipeline.maxCleanedTextCharacters

    enum State: Equatable, Sendable {
        case idle
        case preparing
        case recording
        case finalizing
        case saved(pageID: String, title: String)
        case error(String)
    }

    private typealias PipelineFactory = @MainActor () -> TextCapturePipeline
    private typealias PipelineRunner = @MainActor (
        _ transcription: String,
        _ modelContext: ModelContext,
        _ sourceMetadata: CaptureSourceMetadata
    ) async throws -> CaptureResult
    private typealias DateProvider = @MainActor () -> Date
    private typealias AutoStopPreference = @MainActor () -> Bool
    private typealias SleepProvider = @MainActor (Duration) async throws -> Void

    @ObservationIgnored
    private let voiceInput: any MeetingVoiceInputProviding
    @ObservationIgnored
    private let pipelineFactory: PipelineFactory
    @ObservationIgnored
    private let pipelineRunner: PipelineRunner?
    @ObservationIgnored
    private let now: DateProvider
    @ObservationIgnored
    private let isAutoStopOnSilenceEnabled: AutoStopPreference
    @ObservationIgnored
    private let autoStopSilenceDelay: Duration
    @ObservationIgnored
    private let sleep: SleepProvider

    private var finalSegments: [String] = []
    private var startedAt: Date?
    private var stoppedAt: Date?
    @ObservationIgnored
    private var autoStopSilenceTask: Task<Void, Never>?
    private var autoStopSilenceID = UUID()
    private var captureGeneration = UUID()
    @ObservationIgnored
    private var savedResult: CaptureResult?

    private(set) var state: State = .idle
    private(set) var partialTranscript = ""
    private(set) var modelDownloadProgress: Double?

    init(
        voiceInput: (any MeetingVoiceInputProviding)? = nil,
        pipelineFactory: @escaping @MainActor () -> TextCapturePipeline = { TextCapturePipeline() },
        pipelineRunner: PipelineRunner? = nil,
        now: @escaping @MainActor () -> Date = { Date() },
        isAutoStopOnSilenceEnabled: @escaping @MainActor () -> Bool = {
            VoicePreferences.shared.dictationAutoStop == .auto
        },
        autoStopSilenceDelay: Duration = .seconds(2),
        sleep: @escaping @MainActor (Duration) async throws -> Void = { delay in
            try await Task.sleep(for: delay)
        }
    ) {
        self.voiceInput = voiceInput ?? LiveVoiceInputService.shared
        self.pipelineFactory = pipelineFactory
        self.pipelineRunner = pipelineRunner
        self.now = now
        self.isAutoStopOnSilenceEnabled = isAutoStopOnSilenceEnabled
        self.autoStopSilenceDelay = autoStopSilenceDelay
        self.sleep = sleep
    }

    var transcriptText: String {
        Self.boundedTranscript(Self.renderTranscript(finalSegments: finalSegments, partial: partialTranscript))
    }

    var durationSeconds: Int {
        guard let startedAt else { return 0 }
        let endedAt = stoppedAt ?? now()
        return max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
    }

    func start() async {
        cancelAutoStopSilence()
        let generation = UUID()
        captureGeneration = generation
        savedResult = nil
        resetTranscript()
        startedAt = now()
        stoppedAt = nil
        state = .preparing
        await voiceInput.start()
        guard isCurrentCapture(generation) else {
            voiceInput.stop()
            if captureGeneration == generation {
                state = .idle
            }
            return
        }
        refreshFromVoiceInput()
        syncStateFromVoiceInput()
    }

    func stop() {
        captureGeneration = UUID()
        cancelAutoStopSilence()
        refreshFromVoiceInput(scheduleAutoStopOnFinal: false)
        voiceInput.stop()
        freezeCaptureClock()
        if case .recording = state {
            state = .idle
        } else if case .preparing = state {
            state = .idle
        }
    }

    func tearDownCapture() {
        captureGeneration = UUID()
        cancelAutoStopSilence()
        refreshFromVoiceInput(scheduleAutoStopOnFinal: false)
        voiceInput.tearDown()
        freezeCaptureClock()
        modelDownloadProgress = nil
        if case .recording = state {
            state = .idle
        } else if case .preparing = state {
            state = .idle
        }
    }

    func discard() {
        captureGeneration = UUID()
        cancelAutoStopSilence()
        voiceInput.tearDown()
        resetTranscript()
        savedResult = nil
        startedAt = nil
        stoppedAt = nil
        state = .idle
    }

    func refreshFromVoiceInput() {
        refreshFromVoiceInput(scheduleAutoStopOnFinal: true)
    }

    private func refreshFromVoiceInput(scheduleAutoStopOnFinal: Bool) {
        modelDownloadProgress = VoiceCapturePresentationBounds.modelDownloadProgress(voiceInput.modelDownloadProgress)
        let incomingPartial = Self.cleanedSegment(voiceInput.partialTranscript)
        if !incomingPartial.isEmpty {
            cancelAutoStopSilence()
        }
        recordPartial(incomingPartial)
        var consumedFinal = false
        if let final = voiceInput.consumeTranscript() {
            recordFinal(final)
            consumedFinal = true
        }
        syncStateFromVoiceInput()
        if consumedFinal, scheduleAutoStopOnFinal {
            scheduleAutoStopAfterSilence()
        }
    }

    func recordPartial(_ text: String) {
        partialTranscript = Self.cleanedSegment(text)
    }

    func recordFinal(_ text: String) {
        let cleaned = Self.cleanedSegment(text)
        guard !cleaned.isEmpty else { return }
        let existingTranscript = Self.renderTranscript(finalSegments: finalSegments, partial: "")
        if Self.segment(cleaned, extends: existingTranscript) {
            finalSegments = [cleaned]
        } else if Self.segment(existingTranscript, extends: cleaned) {
            // Already covered by a previously delivered cumulative final.
        } else if let last = finalSegments.last, Self.segment(cleaned, extends: last) {
            finalSegments[finalSegments.index(before: finalSegments.endIndex)] = cleaned
        } else if let last = finalSegments.last, Self.segment(last, extends: cleaned) {
            // Already covered by the last final segment.
        } else if finalSegments.last != cleaned {
            finalSegments.append(cleaned)
        }
        boundFinalSegments()
        if Self.finalSegment(cleaned, coversPartial: partialTranscript) {
            partialTranscript = ""
        }
    }

    @discardableResult
    func finalize(modelContext: ModelContext) async throws -> CaptureResult {
        if let savedResult {
            return savedResult
        }
        if case .finalizing = state {
            throw TextCaptureError.persistenceFailed("meeting note is already saving")
        }

        let finalizeGeneration = UUID()
        captureGeneration = finalizeGeneration
        refreshFromVoiceInput(scheduleAutoStopOnFinal: false)
        cancelAutoStopSilence()
        voiceInput.stop()
        freezeCaptureClock()
        let transcript = transcriptText
        guard !transcript.isEmpty else {
            let message = "Meeting note needs a transcript before saving."
            state = .error(message)
            throw TextCaptureError.emptyCapture
        }

        let capturedAt = startedAt ?? now()
        let metadata = CaptureSourceMetadata.meetingSTT(
            capturedAt: capturedAt,
            durationSeconds: durationSeconds
        )

        state = .finalizing
        do {
            let result: CaptureResult
            if let pipelineRunner {
                result = try await pipelineRunner(transcript, modelContext, metadata)
            } else {
                result = try await pipelineFactory().runFromAudio(
                    transcription: transcript,
                    modelContext: modelContext,
                    sourceMetadata: metadata
                )
            }
            guard isCurrentCapture(finalizeGeneration) else {
                return result
            }
            savedResult = result
            state = .saved(
                pageID: result.createdNoteID ?? "",
                title: result.title
            )
            return result
        } catch {
            if isCurrentCapture(finalizeGeneration) {
                state = .error(MeetingCaptureDiagnostics.statusMessage(for: error))
            }
            throw error
        }
    }

    private func syncStateFromVoiceInput() {
        switch voiceInput.state {
        case .idle:
            if case .preparing = state {
                state = .idle
            } else if case .recording = state {
                state = .idle
            }
        case .preparing:
            state = .preparing
        case .recording:
            state = .recording
        case .unavailable(let message), .error(let message):
            state = .error(VoiceCapturePresentationBounds.statusMessage(message))
        }
    }

    private func scheduleAutoStopAfterSilence() {
        guard isAutoStopOnSilenceEnabled() else {
            cancelAutoStopSilence()
            return
        }
        guard case .recording = state else { return }

        cancelAutoStopSilence()
        let generation = captureGeneration
        let silenceID = UUID()
        autoStopSilenceID = silenceID
        let delay = autoStopSilenceDelay
        let sleep = sleep
        autoStopSilenceTask = Task { @MainActor [weak self] in
            do {
                try await sleep(delay)
            } catch is CancellationError {
                return
            } catch {
                return
            }
            self?.autoStopIfStillSilent(captureGeneration: generation, silenceID: silenceID)
        }
    }

    private func autoStopIfStillSilent(captureGeneration generation: UUID, silenceID: UUID) {
        guard self.captureGeneration == generation,
              autoStopSilenceID == silenceID,
              !Task.isCancelled else {
            return
        }
        autoStopSilenceTask = nil
        autoStopSilenceID = UUID()
        guard case .recording = state else { return }
        guard Self.cleanedSegment(voiceInput.partialTranscript).isEmpty else { return }
        stop()
    }

    private func cancelAutoStopSilence() {
        autoStopSilenceTask?.cancel()
        autoStopSilenceTask = nil
        autoStopSilenceID = UUID()
    }

    private func resetTranscript() {
        finalSegments.removeAll()
        partialTranscript = ""
        modelDownloadProgress = nil
    }

    private func boundFinalSegments() {
        let rendered = Self.renderTranscript(finalSegments: finalSegments, partial: "")
        guard rendered.count > Self.maxTranscriptCharacters else { return }
        finalSegments = [Self.boundedTranscript(rendered)]
    }

    private func freezeCaptureClock() {
        if startedAt != nil, stoppedAt == nil {
            stoppedAt = now()
        }
    }

    private func isCurrentCapture(_ generation: UUID) -> Bool {
        captureGeneration == generation && !Task.isCancelled
    }

    private static func renderTranscript(
        finalSegments: [String],
        partial: String
    ) -> String {
        var segments = finalSegments
        let cleanedPartial = cleanedSegment(partial)
        if !cleanedPartial.isEmpty && segments.last != cleanedPartial {
            segments.append(cleanedPartial)
        }
        return segments.joined(separator: "\n\n")
    }

    private static func cleanedSegment(_ text: String) -> String {
        boundedTranscript(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func boundedTranscript(_ text: String) -> String {
        guard text.count > maxTranscriptCharacters else { return text }
        return String(text.prefix(maxTranscriptCharacters))
    }

    private static func segment(_ candidate: String, extends existing: String) -> Bool {
        guard !existing.isEmpty,
              candidate.count > existing.count,
              candidate.hasPrefix(existing) else {
            return false
        }
        guard let firstExtraCharacter = candidate.dropFirst(existing.count).first else {
            return false
        }
        if firstExtraCharacter.isWhitespace {
            return true
        }
        return [".", ",", ";", ":", "!", "?"].contains(firstExtraCharacter)
    }

    private static func finalSegment(_ final: String, coversPartial partial: String) -> Bool {
        let cleanedPartial = cleanedSegment(partial)
        guard !cleanedPartial.isEmpty else { return false }
        if final == cleanedPartial || segment(final, extends: cleanedPartial) {
            return true
        }
        guard final.count > cleanedPartial.count,
              final.hasSuffix(cleanedPartial) else {
            return false
        }
        let boundaryIndex = final.index(final.endIndex, offsetBy: -cleanedPartial.count - 1)
        let boundary = final[boundaryIndex]
        return boundary.isWhitespace || [".", ",", ";", ":", "!", "?"].contains(boundary)
    }
}
