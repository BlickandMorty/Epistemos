import Foundation
import Observation
import SwiftData

@MainActor
protocol MeetingVoiceInputProviding: AnyObject {
    var state: LiveVoiceInputService.State { get }
    var partialTranscript: String { get }
    var modelDownloadProgress: Double? { get }
    var microphoneAccessDenied: Bool { get }

    func isOwner(_ owner: VoiceCaptureLease) -> Bool
    func start(owner: VoiceCaptureLease) async -> VoiceCaptureStartResult
    func stop(owner: VoiceCaptureLease)
    func tearDown(owner: VoiceCaptureLease)
    func consumeTranscript(owner: VoiceCaptureLease) -> String?
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
    /// Full meeting transcripts routinely run for the length of a meeting, so this
    /// is only a safety cap against pathological / runaway input — NOT a per-meeting
    /// budget. Previously this aliased `TextCapturePipeline.maxCleanedTextCharacters`
    /// (10k, meant for a per-capture cleaned SUMMARY), which silently dropped the
    /// second half of any meeting past ~12 minutes while the UI still showed
    /// "Recording" (MEET-1). 2,000,000 chars is ~30+ hours of continuous speech;
    /// hitting it is surfaced visibly via `boundedTranscript`, never silently.
    nonisolated static let maxTranscriptCharacters = 2_000_000

    enum State: Equatable, Sendable {
        case idle
        case preparing
        case recording
        case finalizing
        case saved(pageID: String, title: String)
        case error(String)
    }

    private typealias PipelineFactory = @MainActor () -> TextCapturePipeline
    typealias PipelineRunner = @MainActor (
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
    @ObservationIgnored
    private let draftBaseDirectory: URL?

    private var finalSegments: [String] = []
    private var startedAt: Date?
    private var stoppedAt: Date?
    @ObservationIgnored
    private var autoStopSilenceTask: Task<Void, Never>?
    private var autoStopSilenceID = UUID()
    private var captureGeneration = UUID()
    private var voiceLease: VoiceCaptureLease?
    @ObservationIgnored
    private var savedResult: CaptureResult?
    // #30 durable persistence (audit 2026-07-03): the active session's transcript is
    // written to a draft file as segments finalize, and deleted on save, so a crash
    // mid-meeting doesn't lose the recording.
    @ObservationIgnored
    private var draftSessionId: String?
    @ObservationIgnored
    private var draftWriteTask: Task<Void, Never>?
    @ObservationIgnored
    private var draftRevision: UInt64 = 0
    @ObservationIgnored
    private var recoveryScanTask: Task<Void, Never>?
    /// Hard cap on how long a live meeting can go unwritten. The 2s debounce coalesces rapid
    /// final segments, but a non-stop talker (segments < 2s apart) would STARVE it and a crash
    /// could lose minutes — so force a write at least this often. (Meeting data-integrity.)
    @ObservationIgnored
    private let draftClock = ContinuousClock()
    @ObservationIgnored
    private var lastDraftWriteAt: ContinuousClock.Instant?
    private static let maxDraftWriteInterval: Duration = .seconds(10)

    private(set) var state: State = .idle
    private(set) var partialTranscript = ""
    private(set) var modelDownloadProgress: Double?
    private(set) var microphoneAccessDenied = false
    /// A previous session's unsaved transcript recovered from disk (crash recovery),
    /// surfaced so the user can restore it instead of losing it.
    private(set) var recoverableDraft: MeetingDraftStore.RecoverableDraft?

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
        },
        draftBaseDirectory: URL? = nil
    ) {
        self.voiceInput = voiceInput ?? LiveVoiceInputService.shared
        self.pipelineFactory = pipelineFactory
        self.pipelineRunner = pipelineRunner
        self.now = now
        self.isAutoStopOnSilenceEnabled = isAutoStopOnSilenceEnabled
        self.autoStopSilenceDelay = autoStopSilenceDelay
        self.sleep = sleep
        self.draftBaseDirectory = draftBaseDirectory
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
        recoveryScanTask?.cancel()
        recoveryScanTask = nil
        if let voiceLease {
            voiceInput.tearDown(owner: voiceLease)
        }
        let owner = VoiceCaptureLease(purpose: .meeting)
        voiceLease = owner
        let generation = UUID()
        captureGeneration = generation
        savedResult = nil
        draftSessionId = UUID().uuidString
        draftRevision = 0
        lastDraftWriteAt = draftClock.now  // start the max-write-interval clock at meeting start
        recoverableDraft = nil
        resetTranscript()
        startedAt = now()
        stoppedAt = nil
        state = .preparing
        let startResult = await voiceInput.start(owner: owner)
        guard isCurrentCapture(generation), voiceLease == owner else {
            voiceInput.tearDown(owner: owner)
            if captureGeneration == generation {
                state = .idle
            }
            return
        }
        switch startResult {
        case .started:
            refreshFromVoiceInput()
            syncStateFromVoiceInput()
        case .busy(let activePurpose):
            voiceLease = nil
            state = .error("Voice capture is already in use by \(activePurpose.displayName).")
        case .permissionDenied(let message):
            microphoneAccessDenied = true
            voiceInput.tearDown(owner: owner)
            voiceLease = nil
            state = .error(VoiceCapturePresentationBounds.statusMessage(message))
        case .unavailable(let message), .failed(let message):
            voiceInput.tearDown(owner: owner)
            voiceLease = nil
            state = .error(VoiceCapturePresentationBounds.statusMessage(message))
        case .cancelled:
            voiceInput.tearDown(owner: owner)
            voiceLease = nil
            state = .idle
        }
    }

    func stop() {
        captureGeneration = UUID()
        cancelAutoStopSilence()
        if let owner = voiceLease, voiceInput.isOwner(owner) {
            refreshFromVoiceInput(scheduleAutoStopOnFinal: false)
            voiceInput.stop(owner: owner)
            if let final = voiceInput.consumeTranscript(owner: owner) {
                recordFinal(final)
            }
            flushDraft()
            voiceInput.tearDown(owner: owner)
        }
        voiceLease = nil
        freezeCaptureClock()
        if case .recording = state {
            state = .idle
        } else if case .preparing = state {
            state = .idle
        }
    }

    func tearDownCapture() {
        if case .finalizing = state {
            // The pipeline may already have persisted the note. View teardown
            // must not invalidate the bookkeeping that publishes the saved
            // state and retires this session's recovery draft.
        } else {
            captureGeneration = UUID()
        }
        cancelAutoStopSilence()
        if let owner = voiceLease, voiceInput.isOwner(owner) {
            refreshFromVoiceInput(scheduleAutoStopOnFinal: false)
            voiceInput.stop(owner: owner)
            if let final = voiceInput.consumeTranscript(owner: owner) {
                recordFinal(final)
            }
        }
        // #30: flush the crash-recovery draft immediately so a close-without-save
        // keeps the last few seconds the 2s debounce may not have written yet.
        flushDraft()
        if let owner = voiceLease {
            voiceInput.tearDown(owner: owner)
        }
        voiceLease = nil
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
        recoveryScanTask?.cancel()
        recoveryScanTask = nil
        if let owner = voiceLease {
            voiceInput.tearDown(owner: owner)
        }
        voiceLease = nil
        draftWriteTask?.cancel()
        draftWriteTask = nil
        if let sessionId = draftSessionId {
            MeetingDraftStore.delete(
                sessionId: sessionId,
                revision: nextDraftRevision(),
                baseDirectory: draftBaseDirectory
            )
        }
        draftSessionId = nil
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
        guard let owner = voiceLease, voiceInput.isOwner(owner) else { return }
        modelDownloadProgress = VoiceCapturePresentationBounds.modelDownloadProgress(voiceInput.modelDownloadProgress)
        let incomingPartial = Self.cleanedSegment(voiceInput.partialTranscript)
        if !incomingPartial.isEmpty {
            cancelAutoStopSilence()
        }
        recordPartial(incomingPartial)
        var consumedFinal = false
        if let final = voiceInput.consumeTranscript(owner: owner) {
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
        scheduleDraftWrite()
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
        if let owner = voiceLease, voiceInput.isOwner(owner) {
            voiceInput.stop(owner: owner)
            if let final = voiceInput.consumeTranscript(owner: owner) {
                recordFinal(final)
            }
            voiceInput.tearDown(owner: owner)
        }
        voiceLease = nil
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
            guard captureGeneration == finalizeGeneration else {
                return result
            }
            // MEET-2 (hardening 2026-07-02): finalize always requests persistence
            // (a ModelContext is always passed through), so a nil/empty
            // createdNoteID means persistNote failed and TextCapturePipeline.run
            // swallowed the throw. Surface it as an error and KEEP the transcript
            // so the user can retry, instead of reporting a phantom "Saved" and
            // silently destroying the meeting note.
            guard let noteID = result.createdNoteID, !noteID.isEmpty else {
                let message = "Meeting note could not be saved. Your transcript is kept — tap Save to try again."
                state = .error(VoiceCapturePresentationBounds.statusMessage(message))
                throw TextCaptureError.persistenceFailed("meeting note was not persisted")
            }
            savedResult = result
            // #30: the meeting is durably saved — drop the crash-recovery draft.
            draftWriteTask?.cancel()
            if let sessionId = draftSessionId {
                MeetingDraftStore.delete(
                    sessionId: sessionId,
                    revision: nextDraftRevision(),
                    baseDirectory: draftBaseDirectory
                )
            }
            draftSessionId = nil
            recoverableDraft = nil
            state = .saved(
                pageID: noteID,
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

    // MARK: - #30 Draft persistence (crash recovery)

    /// Debounced write of the current durable transcript to disk so a crash /
    /// force-quit / power loss can't lose the meeting. Snapshots on the main actor,
    /// writes off-main (a 2 MB transcript would hitch the UI if written inline).
    private func scheduleDraftWrite() {
        guard draftSessionId != nil else { return }
        // If the debounce has been starved past the hard cap (a non-stop meeting whose final
        // segments land < 2s apart), write NOW instead of resetting the timer yet again —
        // bounds worst-case crash loss to ~maxDraftWriteInterval instead of the whole meeting.
        if let last = lastDraftWriteAt, draftClock.now - last >= Self.maxDraftWriteInterval {
            flushDraft()
            return
        }
        draftWriteTask?.cancel()
        draftWriteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled, let sessionId = self.draftSessionId else { return }
            let snapshot = Self.renderTranscript(finalSegments: self.finalSegments, partial: "")
            self.lastDraftWriteAt = self.draftClock.now
            MeetingDraftStore.write(
                sessionId: sessionId,
                transcript: snapshot,
                revision: self.nextDraftRevision(),
                baseDirectory: self.draftBaseDirectory
            )
            self.draftWriteTask = nil
        }
    }

    /// Write the current transcript immediately (bypassing the debounce) so a
    /// close-without-save doesn't drop the last few seconds from the draft.
    private func flushDraft() {
        draftWriteTask?.cancel()
        guard let sessionId = draftSessionId else { return }
        let snapshot = Self.renderTranscript(finalSegments: finalSegments, partial: "")
        lastDraftWriteAt = draftClock.now
        MeetingDraftStore.write(
            sessionId: sessionId,
            transcript: snapshot,
            revision: nextDraftRevision(),
            baseDirectory: draftBaseDirectory
        )
    }

    /// Look for an unsaved transcript left by a previous (crashed) session and, if
    /// found while idle with no live transcript, surface it for recovery. Call on
    /// the meeting view's appear.
    func refreshRecoverableDraft() {
        recoveryScanTask?.cancel()
        guard case .idle = state, transcriptText.isEmpty else {
            recoverableDraft = nil
            recoveryScanTask = nil
            return
        }
        let excludedSessionId = draftSessionId
        let generation = captureGeneration
        let baseDirectory = draftBaseDirectory
        recoveryScanTask = Task { @MainActor [weak self] in
            let draft = await Task.detached(priority: .utility) {
                MeetingDraftStore.latestRecoverable(
                    excluding: excludedSessionId,
                    baseDirectory: baseDirectory
                )
            }.value
            guard let self,
                  !Task.isCancelled,
                  self.captureGeneration == generation,
                  self.transcriptText.isEmpty,
                  self.state == .idle else { return }
            self.recoverableDraft = draft
            self.recoveryScanTask = nil
        }
    }

    /// Restore a recovered draft into the live transcript so the user can save it.
    func restoreRecoverableDraft() {
        guard let draft = recoverableDraft else { return }
        recoveryScanTask?.cancel()
        recoveryScanTask = nil
        finalSegments = [draft.transcript]
        partialTranscript = ""
        // Adopt the recovered session's id so saving deletes the right draft file.
        draftSessionId = draft.sessionId
        draftRevision = 0
        recoverableDraft = nil
        state = .idle
    }

    /// Discard a recovered draft the user doesn't want.
    func discardRecoverableDraft() {
        guard let draft = recoverableDraft else { return }
        recoveryScanTask?.cancel()
        recoveryScanTask = nil
        let sessionId = draft.sessionId
        MeetingDraftStore.delete(
            sessionId: sessionId,
            revision: nextDraftRevision(),
            baseDirectory: draftBaseDirectory
        )
        recoverableDraft = nil
    }

    private func syncStateFromVoiceInput() {
        guard let owner = voiceLease, voiceInput.isOwner(owner) else { return }
        switch voiceInput.state {
        case .idle:
            drainAndReleaseTerminalVoiceCapture(owner: owner)
            state = .idle
        case .preparing:
            state = .preparing
        case .recording:
            state = .recording
        case .unavailable(let message), .error(let message):
            drainAndReleaseTerminalVoiceCapture(owner: owner)
            state = .error(VoiceCapturePresentationBounds.statusMessage(message))
        }
    }

    private func drainAndReleaseTerminalVoiceCapture(owner: VoiceCaptureLease) {
        cancelAutoStopSilence()
        voiceInput.stop(owner: owner)
        if let final = voiceInput.consumeTranscript(owner: owner) {
            recordFinal(final)
        }
        flushDraft()
        voiceInput.tearDown(owner: owner)
        if voiceLease == owner {
            voiceLease = nil
        }
        freezeCaptureClock()
        modelDownloadProgress = nil
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
        guard let owner = voiceLease, voiceInput.isOwner(owner) else { return }
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
        microphoneAccessDenied = false
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

    private func nextDraftRevision() -> UInt64 {
        if draftRevision < .max {
            draftRevision += 1
        }
        return draftRevision
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
        // Never drop content silently (MEET-1): keep as much as the cap allows and
        // append a visible marker so the user knows the transcript was truncated.
        let marker = "\n\n[Transcript truncated — this capture exceeded the "
            + "\(maxTranscriptCharacters)-character limit. Content above is preserved.]"
        let keep = max(0, maxTranscriptCharacters - marker.count)
        return String(text.prefix(keep)) + marker
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
