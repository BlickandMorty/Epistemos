import Foundation
import SwiftData
import Testing

@testable import Epistemos

@Suite("Plan 3 Meeting note capture service")
@MainActor
struct MeetingNoteCaptureServiceTests {
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("final transcript segments stay ordered and partial is not duplicated")
    func transcriptBufferKeepsOrderAndDeduplicatesPartial() {
        let service = MeetingNoteCaptureService(voiceInput: FakeMeetingVoiceInput())

        service.recordFinal("First decision")
        service.recordPartial("Second decision")
        #expect(service.transcriptText == "First decision\n\nSecond decision")

        service.recordFinal("Second decision")
        #expect(service.transcriptText == "First decision\n\nSecond decision")

        service.recordPartial("Third decision")
        #expect(service.transcriptText == "First decision\n\nSecond decision\n\nThird decision")
    }

    @Test("cumulative final transcripts replace prior buffered prefixes")
    func cumulativeFinalTranscriptsReplacePriorPrefixes() {
        let service = MeetingNoteCaptureService(voiceInput: FakeMeetingVoiceInput())

        service.recordFinal("Discuss launch")
        service.recordFinal("Discuss launch and risk")
        #expect(service.transcriptText == "Discuss launch and risk")

        service.recordFinal("Discuss launch and risk\n\nAssign follow-up")
        #expect(service.transcriptText == "Discuss launch and risk\n\nAssign follow-up")

        service.recordPartial("Discuss launch and risk\n\nAssign follow-up.")
        service.recordFinal("Discuss launch and risk\n\nAssign follow-up.")
        #expect(service.transcriptText == "Discuss launch and risk\n\nAssign follow-up.")
    }

    @Test("cumulative final transcripts clear covered tail partials")
    func cumulativeFinalTranscriptsClearCoveredTailPartials() {
        let service = MeetingNoteCaptureService(voiceInput: FakeMeetingVoiceInput())

        service.recordFinal("First decision")
        service.recordPartial("Second decision")
        service.recordFinal("First decision\n\nSecond decision")

        #expect(service.transcriptText == "First decision\n\nSecond decision")
    }

    // MEET-1 fix (2026-07-03): the transcript bound was 10k, aliased from the
    // per-capture cleaned-SUMMARY bound, which silently dropped the second half of
    // any meeting past ~12 min. It is now a 2M-char safety cap (~30+ hrs) and any
    // truncation at that cap is surfaced visibly. These two tests replace the old
    // "capped to the capture pipeline envelope" test, which asserted the bug.
    @Test("MEET-1: a long meeting transcript past the old 10k bound is preserved in full")
    func longTranscriptIsNotSilentlyTruncated() {
        let service = MeetingNoteCaptureService(voiceInput: FakeMeetingVoiceInput())
        let firstHalf = String(repeating: "a", count: 12_000)   // past the old 10k cap
        let secondHalf = String(repeating: "b", count: 12_000)
        service.recordFinal(firstHalf)
        service.recordFinal(secondHalf)
        #expect(service.transcriptText.contains(firstHalf))
        #expect(service.transcriptText.contains(secondHalf))
        #expect(service.transcriptText.count >= 24_000)
    }

    @Test("MEET-1: at the safety cap the transcript is truncated visibly, not silently")
    func transcriptTruncationAtCapIsVisible() {
        let service = MeetingNoteCaptureService(voiceInput: FakeMeetingVoiceInput())
        service.recordFinal(String(repeating: "a", count: MeetingNoteCaptureService.maxTranscriptCharacters + 5_000))
        #expect(service.transcriptText.count <= MeetingNoteCaptureService.maxTranscriptCharacters)
        #expect(service.transcriptText.contains("Transcript truncated"))
    }

    @Test("refresh consumes LiveVoiceInputService-shaped final transcript")
    func refreshConsumesVoiceInput() async {
        let voice = FakeMeetingVoiceInput()
        let service = MeetingNoteCaptureService(voiceInput: voice)
        await service.start()
        voice.partialTranscript = "partial sentence"
        voice.finalTranscripts = ["final sentence"]

        service.refreshFromVoiceInput()

        #expect(service.transcriptText == "final sentence\n\npartial sentence")
        #expect(service.state == .recording)
        #expect(voice.finalTranscripts.isEmpty)
    }

    @Test("refresh bounds progress and voice error display state")
    func refreshBoundsProgressAndVoiceErrorDisplayState() async {
        let voice = FakeMeetingVoiceInput()
        let service = MeetingNoteCaptureService(voiceInput: voice)
        await service.start()

        voice.state = .recording
        voice.modelDownloadProgress = -0.5
        service.refreshFromVoiceInput()
        #expect(service.modelDownloadProgress == 0)

        voice.modelDownloadProgress = 1.25
        service.refreshFromVoiceInput()
        #expect(service.modelDownloadProgress == 1)

        voice.modelDownloadProgress = .nan
        service.refreshFromVoiceInput()
        #expect(service.modelDownloadProgress == nil)

        let oversizedMessage = String(
            repeating: "x",
            count: VoiceCapturePresentationBounds.maxStatusMessageCharacters + 40
        )
        voice.state = .error(oversizedMessage)
        service.refreshFromVoiceInput()

        guard case .error(let message) = service.state else {
            Issue.record("Expected bounded error state, got \(service.state)")
            return
        }
        #expect(message.count == VoiceCapturePresentationBounds.maxStatusMessageCharacters)
    }

    @Test("permission-denied admission is typed and releases the meeting lease")
    func permissionDeniedAdmissionReleasesMeetingLease() async {
        let voice = FakeMeetingVoiceInput()
        let denialMessage = "Microphone access is denied in System Settings."
        voice.nextStartResult = .permissionDenied(denialMessage)
        let service = MeetingNoteCaptureService(voiceInput: voice)

        await service.start()

        #expect(service.state == .error(denialMessage))
        #expect(service.microphoneAccessDenied)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 0)
        #expect(voice.tearDownCallCount == 1)
    }

    @Test("cancelled admission returns idle and releases the meeting lease")
    func cancelledAdmissionReleasesMeetingLease() async {
        let voice = FakeMeetingVoiceInput()
        voice.nextStartResult = .cancelled
        let service = MeetingNoteCaptureService(voiceInput: voice)

        await service.start()

        #expect(service.state == .idle)
        #expect(!service.microphoneAccessDenied)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 0)
        #expect(voice.tearDownCallCount == 1)
    }

    @Test("finalize diagnostics redact external error descriptions")
    func finalizeDiagnosticsRedactExternalErrorDescriptions() {
        let privatePath = "/Users/example/private-vault/meeting.sqlite"
        let external = NSError(
            domain: "MeetingPathLeak",
            code: 19,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )
        let pathDomain = NSError(
            domain: privatePath,
            code: 20,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )

        let externalMessage = MeetingCaptureDiagnostics.statusMessage(for: external)
        let pathDomainMessage = MeetingCaptureDiagnostics.statusMessage(for: pathDomain)
        let persistenceMessage = MeetingCaptureDiagnostics.statusMessage(
            for: TextCaptureError.persistenceFailed("failed to write \(privatePath)")
        )

        #expect(externalMessage.contains("domain=MeetingPathLeak"))
        #expect(externalMessage.contains("code=19"))
        #expect(externalMessage.contains(privatePath) == false)
        #expect(externalMessage.count <= VoiceCapturePresentationBounds.maxStatusMessageCharacters)
        #expect(pathDomainMessage.contains("domain=Error"))
        #expect(pathDomainMessage.contains("code=20"))
        #expect(pathDomainMessage.contains(privatePath) == false)
        #expect(pathDomainMessage.contains("failed to open") == false)
        #expect(persistenceMessage == "Meeting note persistence failed.")
        #expect(persistenceMessage.contains(privatePath) == false)
    }

    @Test("finalize saves through TextCapturePipeline with meeting frontmatter")
    func finalizePersistsMeetingNote() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let voice = FakeMeetingVoiceInput()
        var currentDate = Date(timeIntervalSince1970: 0)
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            now: { currentDate }
        )

        await service.start()
        service.recordFinal(
            """
            Launch review

            - [ ] Send recap to the team
            """
        )
        currentDate = Date(timeIntervalSince1970: 61)

        let result = try await service.finalize(modelContext: context)
        let page = try #require(try context.fetch(FetchDescriptor<SDPage>()).first)

        #expect(result.createdNoteID == page.id)
        #expect(page.frontMatter["source"] == "meeting_stt")
        #expect(page.frontMatter["source_kind"] == "audio_transcript")
        #expect(page.frontMatter["captured_at"] == "1970-01-01T00:00:00Z")
        #expect(page.frontMatter["duration_seconds"] == "61")
        #expect(page.frontMatter["stt_engine"] == "apple_speechanalyzer")
        #expect(page.frontMatter["audio_source"] == nil)

        let body = page.loadBody()
        #expect(body.contains("Launch review"))
        #expect(body.contains("- [ ] Send recap to the team"))
        #expect(!body.contains("audio-source"))
        #expect(!body.contains("<!--"))
        #expect(voice.stopCallCount == 1)

        guard case .saved(let pageID, let title) = service.state else {
            Issue.record("Expected saved state, got \(service.state)")
            return
        }
        #expect(pageID == page.id)
        #expect(title == result.title)
    }

    @Test("finalize surfaces persistence failure and keeps the transcript recoverable")
    func finalizeSurfacesPersistenceFailureWithoutLosingTranscript() async throws {
        // MEET-2 regression guard: if TextCapturePipeline.run swallows a
        // persistence error (returns a structured result with no createdNoteID),
        // finalize must report .error and KEEP the transcript — never a phantom
        // .saved that discards the meeting note.
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let voice = FakeMeetingVoiceInput()
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            pipelineRunner: { transcription, _, _ in
                CaptureResult(
                    rawText: transcription,
                    cleanedText: transcription,
                    title: "Untitled",
                    summary: "",
                    entities: [],
                    tasks: [],
                    sourceSpans: [],
                    createdNoteID: nil,
                    draftNoteID: nil,
                    graphWriteSummary: GraphWriteSummary(
                        noteNodeCreated: false,
                        entityNodesCreated: 0,
                        edgesCreated: 0,
                        skippedReason: "note not persisted"
                    ),
                    mutationEnvelope: nil,
                    mutationEnvelopePersisted: false,
                    traceID: "test-trace"
                )
            }
        )

        await service.start()
        service.recordFinal("Important meeting decisions that must not be lost.")

        await #expect(throws: TextCaptureError.self) {
            _ = try await service.finalize(modelContext: context)
        }

        guard case .error = service.state else {
            Issue.record("Expected error state on persistence failure, got \(service.state)")
            return
        }
        // The transcript must survive so the user can retry Save.
        #expect(service.transcriptText == "Important meeting decisions that must not be lost.")
    }

    @Test("stopping freezes meeting duration before delayed save")
    func stoppingFreezesDurationBeforeDelayedSave() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let voice = FakeMeetingVoiceInput()
        var currentDate = Date(timeIntervalSince1970: 0)
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            now: { currentDate }
        )

        await service.start()
        service.recordFinal("Review the launch checklist.")
        currentDate = Date(timeIntervalSince1970: 12)
        service.stop()

        #expect(service.durationSeconds == 12)

        currentDate = Date(timeIntervalSince1970: 95)
        #expect(service.durationSeconds == 12)

        _ = try await service.finalize(modelContext: context)
        let page = try #require(try context.fetch(FetchDescriptor<SDPage>()).first)

        #expect(page.frontMatter["duration_seconds"] == "12")
    }

    @Test("finalize drains final transcript without scheduling auto stop")
    func finalizeDoesNotScheduleAutoStopWhileSaving() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let voice = FakeMeetingVoiceInput()
        var sleepCallCount = 0
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            isAutoStopOnSilenceEnabled: { true },
            sleep: { _ in
                sleepCallCount += 1
            }
        )

        await service.start()
        voice.partialTranscript = ""
        voice.finalTranscripts = ["Finalize the meeting note."]

        _ = try await service.finalize(modelContext: context)
        for _ in 0..<5 where sleepCallCount == 0 {
            await Task.yield()
        }

        #expect(sleepCallCount == 0)
        #expect(voice.stopCallCount == 1)
        #expect(service.transcriptText == "Finalize the meeting note.")
    }

    @Test("finalize returns the saved result instead of duplicating the meeting note")
    func finalizeIsIdempotentAfterSave() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let voice = FakeMeetingVoiceInput()
        let service = MeetingNoteCaptureService(voiceInput: voice)

        await service.start()
        service.recordFinal("Do not save this meeting twice.")

        let first = try await service.finalize(modelContext: context)
        let second = try await service.finalize(modelContext: context)
        let pages = try context.fetch(FetchDescriptor<SDPage>())

        #expect(pages.count == 1)
        #expect(second.createdNoteID == first.createdNoteID)
        #expect(second.title == first.title)
        #expect(second.traceID == first.traceID)
        #expect(voice.stopCallCount == 1)

        guard case .saved(let pageID, let title) = service.state else {
            Issue.record("Expected saved state, got \(service.state)")
            return
        }
        #expect(pageID == first.createdNoteID)
        #expect(title == first.title)
    }

    @Test("discard during finalization does not revive saved state")
    func discardDuringFinalizationDoesNotReviveSavedState() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let voice = FakeMeetingVoiceInput()
        var resumePipeline: (() -> Void)?
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            pipelineRunner: { transcription, modelContext, metadata in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    resumePipeline = {
                        continuation.resume()
                    }
                }
                return try await TextCapturePipeline().runFromAudio(
                    transcription: transcription,
                    modelContext: modelContext,
                    sourceMetadata: metadata
                )
            }
        )

        await service.start()
        service.recordFinal("Save after discard should not revive the UI state.")

        let saveTask = Task { @MainActor in
            try await service.finalize(modelContext: context)
        }
        for _ in 0..<50 where resumePipeline == nil {
            await Task.yield()
        }
        guard let resume = resumePipeline else {
            Issue.record("Expected meeting save pipeline to suspend")
            saveTask.cancel()
            return
        }
        #expect(service.state == .finalizing)

        service.discard()
        #expect(service.state == .idle)
        #expect(service.transcriptText.isEmpty)

        resume()
        _ = try await saveTask.value

        #expect(service.state == .idle)
        #expect(service.transcriptText.isEmpty)
        #expect(voice.stopCallCount == 1)
        let pages = try context.fetch(FetchDescriptor<SDPage>())
        #expect(pages.count == 1)
    }

    @Test("auto dictation preference stops meeting capture after final silence")
    func autoStopPreferenceStopsAfterFinalSilence() async {
        let voice = FakeMeetingVoiceInput()
        var resumeSilenceWindow: (() -> Void)?
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            isAutoStopOnSilenceEnabled: { true },
            sleep: { _ in
                await withCheckedContinuation { continuation in
                    resumeSilenceWindow = {
                        continuation.resume()
                    }
                }
            }
        )

        await service.start()
        voice.partialTranscript = ""
        voice.finalTranscripts = ["We have a decision."]
        service.refreshFromVoiceInput()

        #expect(service.transcriptText == "We have a decision.")
        #expect(voice.stopCallCount == 0)

        for _ in 0..<5 where resumeSilenceWindow == nil {
            await Task.yield()
        }
        #expect(resumeSilenceWindow != nil)
        resumeSilenceWindow?()
        for _ in 0..<5 where voice.stopCallCount == 0 {
            await Task.yield()
        }

        #expect(voice.stopCallCount == 1)
        #expect(service.state == .idle)
    }

    @Test("rescheduled auto stop ignores stale silence windows")
    func rescheduledAutoStopIgnoresStaleSilenceWindows() async {
        let voice = FakeMeetingVoiceInput()
        var resumeSilenceWindows: [() -> Void] = []
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            isAutoStopOnSilenceEnabled: { true },
            sleep: { _ in
                await withCheckedContinuation { continuation in
                    resumeSilenceWindows.append {
                        continuation.resume()
                    }
                }
            }
        )

        await service.start()
        voice.partialTranscript = ""
        voice.finalTranscripts = ["First final."]
        service.refreshFromVoiceInput()

        for _ in 0..<5 where resumeSilenceWindows.count < 1 {
            await Task.yield()
        }
        let staleResume = resumeSilenceWindows.first

        voice.partialTranscript = "Speaker resumed"
        service.refreshFromVoiceInput()
        voice.partialTranscript = ""
        voice.finalTranscripts = ["Second final."]
        service.refreshFromVoiceInput()

        for _ in 0..<5 where resumeSilenceWindows.count < 2 {
            await Task.yield()
        }
        let currentResume = resumeSilenceWindows.dropFirst().first

        staleResume?()
        for _ in 0..<5 {
            await Task.yield()
        }

        #expect(service.state == .recording)
        #expect(voice.stopCallCount == 0)

        currentResume?()
        for _ in 0..<5 where voice.stopCallCount == 0 {
            await Task.yield()
        }

        #expect(voice.stopCallCount == 1)
        #expect(service.state == .idle)
    }

    @Test("stale auto stop cannot stop a newer capture")
    func staleAutoStopCannotStopNewerCapture() async {
        let voice = FakeMeetingVoiceInput()
        var resumeSilenceWindow: (() -> Void)?
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            isAutoStopOnSilenceEnabled: { true },
            sleep: { _ in
                await withCheckedContinuation { continuation in
                    resumeSilenceWindow = {
                        continuation.resume()
                    }
                }
            }
        )

        await service.start()
        voice.partialTranscript = ""
        voice.finalTranscripts = ["First capture final."]
        service.refreshFromVoiceInput()

        for _ in 0..<5 where resumeSilenceWindow == nil {
            await Task.yield()
        }
        let staleResume = resumeSilenceWindow

        service.stop()
        #expect(voice.stopCallCount == 1)
        await service.start()
        #expect(service.state == .recording)

        staleResume?()
        for _ in 0..<5 {
            await Task.yield()
        }

        #expect(service.state == .recording)
        #expect(voice.stopCallCount == 1)
    }

    @Test("stop during preparing prevents a late mic start from reviving recording")
    func stopDuringPreparingCancelsLateStart() async {
        let voice = FakeMeetingVoiceInput()
        var resumeStart: (() -> Void)?
        voice.onStart = {
            await withCheckedContinuation { continuation in
                resumeStart = {
                    voice.state = .recording
                    continuation.resume()
                }
            }
        }
        let service = MeetingNoteCaptureService(voiceInput: voice)

        let startTask = Task { @MainActor in
            await service.start()
        }
        for _ in 0..<5 where resumeStart == nil {
            await Task.yield()
        }

        #expect(service.state == .preparing)
        service.stop()
        #expect(service.state == .idle)

        resumeStart?()
        await startTask.value

        #expect(service.state == .idle)
        #expect(voice.stopCallCount >= 1)
    }

    @Test("teardown during preparing prevents a late mic start from reviving capture")
    func tearDownDuringPreparingCancelsLateStart() async {
        let voice = FakeMeetingVoiceInput()
        var resumeStart: (() -> Void)?
        voice.onStart = {
            await withCheckedContinuation { continuation in
                resumeStart = {
                    voice.state = .recording
                    continuation.resume()
                }
            }
        }
        let service = MeetingNoteCaptureService(voiceInput: voice)

        let startTask = Task { @MainActor in
            await service.start()
        }
        for _ in 0..<5 where resumeStart == nil {
            await Task.yield()
        }

        #expect(service.state == .preparing)
        service.tearDownCapture()
        #expect(service.state == .idle)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 1)
        #expect(voice.tearDownCallCount == 1)

        resumeStart?()
        await startTask.value

        #expect(service.state == .idle)
        #expect(voice.state == .idle)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 1)
        #expect(voice.tearDownCallCount == 1)
    }

    @Test("active Quick Capture cannot be preempted or torn down by Meeting")
    func activeQuickCaptureCannotBePreemptedByMeeting() async {
        let voice = FakeMeetingVoiceInput()
        let quickCapture = VoiceCaptureLease(purpose: .quickCapture)
        let quickStart = await voice.start(owner: quickCapture)
        #expect(quickStart == .started)
        voice.partialTranscript = "Quick Capture draft in progress"
        voice.finalTranscripts = ["Quick Capture final pending"]
        let service = MeetingNoteCaptureService(voiceInput: voice)

        await service.start()

        guard case .error(let message) = service.state else {
            Issue.record("Expected busy Meeting admission, got \(service.state)")
            return
        }
        #expect(message.contains("Quick Capture"))
        #expect(voice.isOwner(quickCapture))
        #expect(voice.activePurpose == .quickCapture)
        #expect(voice.state == .recording)
        #expect(voice.partialTranscript == "Quick Capture draft in progress")
        #expect(voice.finalTranscripts == ["Quick Capture final pending"])
        #expect(voice.stopCallCount == 0)
        #expect(voice.tearDownCallCount == 0)

        service.tearDownCapture()

        #expect(voice.isOwner(quickCapture))
        #expect(voice.state == .recording)
        #expect(voice.partialTranscript == "Quick Capture draft in progress")
        #expect(voice.finalTranscripts == ["Quick Capture final pending"])
        #expect(voice.stopCallCount == 0)
        #expect(voice.tearDownCallCount == 0)
    }

    @Test("active Meeting rejects Quick Capture and ignores non-owner lifecycle calls")
    func activeMeetingRejectsQuickCaptureAndNonOwnerLifecycleCalls() async {
        let voice = FakeMeetingVoiceInput()
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            isAutoStopOnSilenceEnabled: { false }
        )
        await service.start()
        voice.partialTranscript = "Meeting transcript remains owned"
        voice.finalTranscripts = ["Owned meeting final"]
        let quickCapture = VoiceCaptureLease(purpose: .quickCapture)

        let quickStart = await voice.start(owner: quickCapture)
        voice.stop(owner: quickCapture)
        let stolenTranscript = voice.consumeTranscript(owner: quickCapture)
        voice.tearDown(owner: quickCapture)

        #expect(quickStart == .busy(.meeting))
        #expect(stolenTranscript == nil)
        #expect(voice.activePurpose == .meeting)
        #expect(voice.state == .recording)
        #expect(voice.partialTranscript == "Meeting transcript remains owned")
        #expect(voice.finalTranscripts == ["Owned meeting final"])
        #expect(voice.stopCallCount == 0)
        #expect(voice.tearDownCallCount == 0)

        service.refreshFromVoiceInput()

        #expect(service.state == .recording)
        #expect(service.transcriptText == "Owned meeting final\n\nMeeting transcript remains owned")
        #expect(voice.finalTranscripts.isEmpty)
    }

    @Test("teardown drains pending transcript and clears shared voice state")
    func tearDownCaptureDrainsPendingTranscriptAndClearsVoiceState() async {
        let voice = FakeMeetingVoiceInput()
        let service = MeetingNoteCaptureService(voiceInput: voice)
        await service.start()
        voice.partialTranscript = "Live partial"
        voice.finalTranscripts = ["Final decision"]
        voice.modelDownloadProgress = 0.5

        service.tearDownCapture()

        #expect(service.transcriptText == "Final decision\n\nLive partial")
        #expect(service.modelDownloadProgress == nil)
        #expect(service.state == .idle)
        #expect(voice.tearDownCallCount == 1)
        #expect(voice.partialTranscript.isEmpty)
        #expect(voice.finalTranscripts.isEmpty)
    }

    @Test("service source stays off direct SpeechAnalyzer and hidden runtime paths")
    func sourceBoundaries() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/MeetingNoteCaptureService.swift")

        #expect(source.contains("LiveVoiceInputService.shared"))
        #expect(source.contains("MeetingVoiceInputProviding"))
        #expect(source.contains("VoicePreferences.shared.dictationAutoStop == .auto"))
        #expect(source.contains("runFromAudio("))
        #expect(source.contains("CaptureSourceMetadata.meetingSTT"))
        #expect(source.contains("segment(_ candidate: String, extends existing: String)"))
        #expect(source.contains("finalSegment(_ final: String, coversPartial partial: String)"))
        #expect(source.contains("maxTranscriptCharacters"))
        #expect(source.contains("TextCapturePipeline.maxCleanedTextCharacters"))
        #expect(source.contains("private var autoStopSilenceID = UUID()"))
        #expect(source.contains("self.captureGeneration == generation"))
        #expect(source.contains("autoStopSilenceID == silenceID"))
        #expect(source.contains("boundFinalSegments"))
        #expect(source.contains("VoiceCapturePresentationBounds.modelDownloadProgress(voiceInput.modelDownloadProgress)"))
        #expect(source.contains("VoiceCapturePresentationBounds.statusMessage"))
        #expect(source.contains("MeetingCaptureDiagnostics"))
        #expect(source.contains("statusMessage(for error: Error)"))
        #expect(source.contains("func tearDownCapture()"))
        #expect(source.contains("voiceInput.tearDown(owner:"))
        let tearDownStart = try #require(source.range(of: "func tearDownCapture()")?.lowerBound)
        let discardStart = try #require(source.range(of: "func discard()", range: tearDownStart..<source.endIndex)?.lowerBound)
        let tearDownBody = source[tearDownStart..<discardStart]
        let scopedStop = try #require(tearDownBody.range(of: "voiceInput.stop(owner: owner)")?.lowerBound)
        let promotedDrain = try #require(tearDownBody.range(of: "voiceInput.consumeTranscript(owner: owner)")?.lowerBound)
        let draftFlush = try #require(tearDownBody.range(of: "flushDraft()")?.lowerBound)
        let scopedTearDown = try #require(tearDownBody.range(of: "voiceInput.tearDown(owner: owner)")?.lowerBound)
        #expect(scopedStop < promotedDrain)
        #expect(promotedDrain < draftFlush)
        #expect(draftFlush < scopedTearDown)
        #expect(source.contains("let finalizeGeneration = UUID()"))
        #expect(source.contains("guard isCurrentCapture(finalizeGeneration) else"))
        #expect(source.contains("if isCurrentCapture(finalizeGeneration)"))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("EpistemosSpeechAnalyzer"))
        #expect(!source.contains("Whisper"))
        #expect(!source.contains("Python"))
        #expect(!source.contains("subprocess"))
        #expect(!source.contains("Kokoro"))
        #expect(!source.contains("Chromium"))
    }

    @Test("meeting note UI is hosted by Plan 3 window and landing routes")
    func uiRoutesStayInPlan3Surfaces() throws {
        let view = try loadMirroredSourceTextFile("Epistemos/Views/Meeting/MeetingNoteView.swift")
        let windows = try loadMirroredSourceTextFile("Epistemos/App/UtilityWindowManager.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let buttons = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")

        #expect(view.contains("MeetingNoteCaptureService"))
        #expect(view.contains("voiceInput: LiveVoiceInputService = .shared"))
        #expect(view.contains("service.finalize(modelContext: modelContext)"))
        #expect(view.contains("guard canSave else { return }"))
        #expect(view.contains(".disabled(!canSave)"))
        #expect(view.contains("private var isSaved: Bool"))
        #expect(view.contains("case .saved(_, let title):"))
        #expect(view.contains("VoiceCapturePresentationBounds.statusMessage(\"Saved note:"))
        #expect(view.contains(".onDisappear {\n            service.tearDownCapture()\n        }"))
        #expect(view.contains("showingDiscardConfirmation = true"))
        #expect(view.contains(".confirmationDialog("))
        #expect(view.contains("Button(\"Discard Transcript\", role: .destructive)"))
        #expect(!view.contains("EpistemosSpeechAnalyzer"))
        #expect(!view.contains("NoteWindowManager.shared.open"))

        #expect(windows.contains("case meetingNote"))
        #expect(windows.contains("MeetingNoteView()"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.meetingNote)"))
        #expect(buttons.contains("case meetingNote"))
        #expect(buttons.contains("case .meetingNote: \"meeting\""))

        #expect(!landing.contains("GooseSurfaceWindowController"))
        #expect(!buttons.contains("GooseSurfaceWindowController"))
    }
}

@MainActor
private final class FakeMeetingVoiceInput: MeetingVoiceInputProviding {
    var state: LiveVoiceInputService.State = .idle
    var partialTranscript = ""
    var modelDownloadProgress: Double?
    var microphoneAccessDenied = false
    var finalTranscripts: [String] = []
    var stopCallCount = 0
    var tearDownCallCount = 0
    var onStart: (@MainActor () async -> Void)?
    var nextStartResult: VoiceCaptureStartResult?
    private var leaseRegistry = VoiceCaptureLeaseRegistry()

    var activePurpose: VoiceCapturePurpose? {
        leaseRegistry.activeLease?.purpose
    }

    func isOwner(_ owner: VoiceCaptureLease) -> Bool {
        leaseRegistry.owns(owner)
    }

    func start(owner: VoiceCaptureLease) async -> VoiceCaptureStartResult {
        switch leaseRegistry.reserve(owner) {
        case .busy(let activePurpose):
            return .busy(activePurpose)
        case .acquired, .alreadyOwned:
            break
        }
        state = .preparing
        if let onStart {
            await onStart()
        }
        guard leaseRegistry.owns(owner) else {
            nextStartResult = nil
            state = .idle
            return .cancelled
        }
        let result = nextStartResult ?? .started
        nextStartResult = nil
        switch result {
        case .started:
            state = .recording
        case .busy(_):
            leaseRegistry.release(owner)
            state = .idle
        case .permissionDenied(let message):
            microphoneAccessDenied = true
            state = .unavailable(message)
        case .unavailable(let message):
            state = .unavailable(message)
        case .failed(let message):
            state = .error(message)
        case .cancelled:
            state = .idle
        }
        return result
    }

    func stop(owner: VoiceCaptureLease) {
        guard leaseRegistry.owns(owner) else { return }
        stopCallCount += 1
        let promoted = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !promoted.isEmpty, finalTranscripts.last != promoted {
            finalTranscripts.append(promoted)
        }
        partialTranscript = ""
        state = .idle
    }

    func tearDown(owner: VoiceCaptureLease) {
        guard leaseRegistry.owns(owner) else { return }
        tearDownCallCount += 1
        leaseRegistry.release(owner)
        state = .idle
        partialTranscript = ""
        modelDownloadProgress = nil
        microphoneAccessDenied = false
        finalTranscripts.removeAll()
    }

    func consumeTranscript(owner: VoiceCaptureLease) -> String? {
        guard leaseRegistry.owns(owner) else { return nil }
        guard !finalTranscripts.isEmpty else { return nil }
        return finalTranscripts.removeFirst()
    }
}
