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

    @Test("transcript buffer is capped to the capture pipeline envelope")
    func transcriptBufferIsCappedToCapturePipelineEnvelope() {
        let service = MeetingNoteCaptureService(voiceInput: FakeMeetingVoiceInput())
        let prefix = String(repeating: "a", count: MeetingNoteCaptureService.maxTranscriptCharacters - 2)

        service.recordFinal(prefix)
        service.recordFinal("tail segment that should not extend the saved transcript")
        service.recordPartial("live partial that should also stay outside the capped display")

        #expect(service.transcriptText.count == MeetingNoteCaptureService.maxTranscriptCharacters)
        #expect(service.transcriptText.hasPrefix(prefix))
        #expect(!service.transcriptText.contains("tail segment"))
        #expect(!service.transcriptText.contains("live partial"))
    }

    @Test("refresh consumes LiveVoiceInputService-shaped final transcript")
    func refreshConsumesVoiceInput() {
        let voice = FakeMeetingVoiceInput()
        voice.state = .recording
        voice.partialTranscript = "partial sentence"
        voice.finalTranscripts = ["final sentence"]
        let service = MeetingNoteCaptureService(voiceInput: voice)

        service.refreshFromVoiceInput()

        #expect(service.transcriptText == "final sentence\n\npartial sentence")
        #expect(service.state == .recording)
        #expect(voice.finalTranscripts.isEmpty)
    }

    @Test("refresh bounds progress and voice error display state")
    func refreshBoundsProgressAndVoiceErrorDisplayState() {
        let voice = FakeMeetingVoiceInput()
        let service = MeetingNoteCaptureService(voiceInput: voice)

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

    @Test("service source stays off direct SpeechAnalyzer and hidden runtime paths")
    func sourceBoundaries() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/MeetingNoteCaptureService.swift")

        #expect(source.contains("LiveVoiceInputService.shared"))
        #expect(source.contains("MeetingVoiceInputProviding"))
        #expect(source.contains("VoicePreferences.shared.dictationAutoStop == .auto"))
        #expect(source.contains("runFromAudio("))
        #expect(source.contains("CaptureSourceMetadata.meetingSTT"))
        #expect(source.contains("segment(_ candidate: String, extends existing: String)"))
        #expect(source.contains("maxTranscriptCharacters"))
        #expect(source.contains("TextCapturePipeline.maxCleanedTextCharacters"))
        #expect(source.contains("boundFinalSegments"))
        #expect(source.contains("VoiceCapturePresentationBounds.modelDownloadProgress(voiceInput.modelDownloadProgress)"))
        #expect(source.contains("VoiceCapturePresentationBounds.statusMessage"))
        #expect(source.contains("MeetingCaptureDiagnostics"))
        #expect(source.contains("statusMessage(for error: Error)"))
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
    var finalTranscripts: [String] = []
    var stopCallCount = 0
    var onStart: (@MainActor () async -> Void)?

    func start() async {
        if let onStart {
            await onStart()
            return
        }
        state = .recording
    }

    func stop() {
        stopCallCount += 1
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
