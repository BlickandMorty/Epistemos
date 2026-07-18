import Foundation
import SwiftData
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("Free V1 voice-capture behavior tests must compile with the Mac App Store sandbox lane.")
#endif

private actor DeferredMeetingStartGate {
    private var isSuspended = false
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
    private var startContinuation: CheckedContinuation<Void, Never>?

    func suspendStart() async {
        isSuspended = true
        let waiters = suspensionWaiters
        suspensionWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { startContinuation = $0 }
    }

    func waitUntilSuspended() async {
        guard !isSuspended else { return }
        await withCheckedContinuation { suspensionWaiters.append($0) }
    }

    func resumeStart() {
        startContinuation?.resume()
        startContinuation = nil
    }
}

@MainActor
private final class DeferredMeetingFinalizeGate {
    private var isSuspended = false
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    func suspendAndReturn(_ result: CaptureResult) async -> CaptureResult {
        isSuspended = true
        let waiters = suspensionWaiters
        suspensionWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { resumeContinuation = $0 }
        return result
    }

    func waitUntilSuspended() async {
        guard !isSuspended else { return }
        await withCheckedContinuation { suspensionWaiters.append($0) }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}

@MainActor
private final class AppStoreMeetingVoiceFake: MeetingVoiceInputProviding {
    var state: LiveVoiceInputService.State = .idle
    var partialTranscript = ""
    var modelDownloadProgress: Double?
    var microphoneAccessDenied = false
    var finalTranscripts: [String] = []
    var nextStartResult: VoiceCaptureStartResult?
    var onStart: (@MainActor () async -> Void)?
    private(set) var stopCallCount = 0
    private(set) var tearDownCallCount = 0

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
        let promotedPartial = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !promotedPartial.isEmpty, finalTranscripts.last != promotedPartial {
            finalTranscripts.append(promotedPartial)
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
        finalTranscripts.removeAll()
        modelDownloadProgress = nil
        microphoneAccessDenied = false
    }

    func consumeTranscript(owner: VoiceCaptureLease) -> String? {
        guard leaseRegistry.owns(owner), !finalTranscripts.isEmpty else { return nil }
        return finalTranscripts.removeFirst()
    }
}

private final class FreeV1VoiceCaptureSourceBundleToken {}

@Suite("Free V1 Voice Capture Behavior", .serialized)
@MainActor
struct FreeV1VoiceCaptureBehaviorTests {
    private func makeModelContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SDPage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func successfulCaptureResult(rawText: String) -> CaptureResult {
        CaptureResult(
            rawText: rawText,
            cleanedText: rawText,
            title: "Saved meeting",
            summary: "",
            entities: [],
            tasks: [],
            sourceSpans: [],
            createdNoteID: "saved-meeting-note",
            draftNoteID: nil,
            graphWriteSummary: GraphWriteSummary(
                noteNodeCreated: true,
                entityNodesCreated: 0,
                edgesCreated: 0,
                skippedReason: nil
            ),
            mutationEnvelope: nil,
            mutationEnvelopePersisted: false,
            traceID: "meeting-finalize-race"
        )
    }

    private func loadSourceFixture(_ relativePath: String) throws -> String {
        let bundle = Bundle(for: FreeV1VoiceCaptureSourceBundleToken.self)
        guard let candidate = bundle.resourceURL?
            .appendingPathComponent("RepositorySourceFixtures", isDirectory: true)
            .appendingPathComponent(relativePath),
              FileManager.default.fileExists(atPath: candidate.path) else {
            throw CocoaError(
                .fileNoSuchFile,
                userInfo: [NSFilePathErrorKey: relativePath]
            )
        }
        return try String(contentsOf: candidate, encoding: .utf8)
    }

    private func sourceSection(
        in source: String,
        startingAt start: String,
        endingBefore end: String
    ) throws -> Substring {
        let startRange = try #require(source.range(of: start))
        let endRange = try #require(source.range(of: end, range: startRange.upperBound..<source.endIndex))
        return source[startRange.lowerBound..<endRange.lowerBound]
    }

    @Test("typed permission denial releases the Meeting lease")
    func permissionDeniedAdmissionIsTypedAndReleasesLease() async {
        let voice = AppStoreMeetingVoiceFake()
        let denial = "Microphone access is denied in System Settings."
        voice.nextStartResult = .permissionDenied(denial)
        let service = MeetingNoteCaptureService(voiceInput: voice)

        await service.start()

        #expect(service.state == .error(denial))
        #expect(service.microphoneAccessDenied)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 0)
        #expect(voice.tearDownCallCount == 1)
    }

    @Test("cancelled Meeting admission releases its lease")
    func cancelledAdmissionReleasesLease() async {
        let voice = AppStoreMeetingVoiceFake()
        voice.nextStartResult = .cancelled
        let service = MeetingNoteCaptureService(voiceInput: voice)

        await service.start()

        #expect(service.state == .idle)
        #expect(!service.microphoneAccessDenied)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 0)
        #expect(voice.tearDownCallCount == 1)
    }

    @Test("teardown during preparation prevents a late Meeting start")
    func tearDownDuringPreparingPreventsLateRecording() async {
        let gate = DeferredMeetingStartGate()
        let voice = AppStoreMeetingVoiceFake()
        voice.onStart = { await gate.suspendStart() }
        let service = MeetingNoteCaptureService(voiceInput: voice)
        let startTask = Task { @MainActor in await service.start() }

        await gate.waitUntilSuspended()
        #expect(service.state == .preparing)

        service.tearDownCapture()
        #expect(service.state == .idle)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 1)
        #expect(voice.tearDownCallCount == 1)

        await gate.resumeStart()
        await startTask.value

        #expect(service.state == .idle)
        #expect(voice.state == .idle)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 1)
        #expect(voice.tearDownCallCount == 1)
    }

    @Test("an active Quick Capture lease cannot be preempted or torn down by Meeting")
    func quickCaptureLeaseCannotBePreemptedOrTornDownByMeeting() async {
        let voice = AppStoreMeetingVoiceFake()
        let quickCapture = VoiceCaptureLease(purpose: .quickCapture)
        #expect(await voice.start(owner: quickCapture) == .started)
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

    @Test("an active Meeting rejects Quick Capture and non-owner lifecycle calls")
    func meetingLeaseRejectsQuickCaptureAndNonOwnerLifecycle() async {
        let voice = AppStoreMeetingVoiceFake()
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

    @Test("Meeting teardown drains final and partial text before releasing the lease")
    func tearDownDrainsFinalAndPartialBeforeRelease() async {
        let voice = AppStoreMeetingVoiceFake()
        let service = MeetingNoteCaptureService(voiceInput: voice)
        await service.start()
        voice.partialTranscript = "Live partial"
        voice.finalTranscripts = ["Final decision"]
        voice.modelDownloadProgress = 0.5

        service.tearDownCapture()

        #expect(service.transcriptText == "Final decision\n\nLive partial")
        #expect(service.modelDownloadProgress == nil)
        #expect(service.state == .idle)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 1)
        #expect(voice.tearDownCallCount == 1)
        #expect(voice.partialTranscript.isEmpty)
        #expect(voice.finalTranscripts.isEmpty)
    }

    @Test("a naturally-ended Meeting stream drains and releases its lease")
    func naturalMeetingStreamEndDrainsAndReleasesLease() async {
        let voice = AppStoreMeetingVoiceFake()
        let service = MeetingNoteCaptureService(voiceInput: voice)
        await service.start()
        voice.partialTranscript = "Terminal partial"
        voice.finalTranscripts = ["Terminal final"]
        voice.state = .idle

        service.refreshFromVoiceInput()

        #expect(service.transcriptText == "Terminal final\n\nTerminal partial")
        #expect(service.state == .idle)
        #expect(voice.activePurpose == nil)
        #expect(voice.stopCallCount == 1)
        #expect(voice.tearDownCallCount == 1)
        #expect(voice.partialTranscript.isEmpty)
        #expect(voice.finalTranscripts.isEmpty)

        let quickCapture = VoiceCaptureLease(purpose: .quickCapture)
        #expect(await voice.start(owner: quickCapture) == .started)
        #expect(voice.isOwner(quickCapture))
    }

    @Test("closing a Meeting view while save is in flight cannot strand a saved note or recovery draft")
    func tearDownDuringFinalizeStillCommitsSavedStateAndRetiresDraft() async throws {
        let draftDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-store-meeting-finalize-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: draftDirectory, withIntermediateDirectories: true)
        defer {
            MeetingDraftStore.waitForPendingOperations()
            try? FileManager.default.removeItem(at: draftDirectory)
        }

        let gate = DeferredMeetingFinalizeGate()
        let voice = AppStoreMeetingVoiceFake()
        let expectedResult = successfulCaptureResult(
            rawText: "A decision that must not be offered twice."
        )
        let modelContext = try makeModelContext()
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            pipelineRunner: { _, _, _ in
                await gate.suspendAndReturn(expectedResult)
            },
            draftBaseDirectory: draftDirectory
        )
        await service.start()
        service.recordFinal("A decision that must not be offered twice.")
        let finalizeTask = Task { @MainActor in
            try await service.finalize(modelContext: modelContext)
        }

        await gate.waitUntilSuspended()
        #expect(service.state == .finalizing)
        service.tearDownCapture()
        #expect(service.state == .finalizing)
        MeetingDraftStore.waitForPendingOperations()
        #expect(
            MeetingDraftStore.latestRecoverable(
                excluding: nil,
                baseDirectory: draftDirectory
            )?.transcript == "A decision that must not be offered twice."
        )

        gate.resume()
        let result = try await finalizeTask.value
        MeetingDraftStore.waitForPendingOperations()

        #expect(result.createdNoteID == "saved-meeting-note")
        #expect(service.state == .saved(pageID: "saved-meeting-note", title: "Saved meeting"))
        #expect(MeetingDraftStore.latestRecoverable(excluding: nil, baseDirectory: draftDirectory) == nil)
    }

    @Test("Meeting draft revisions reject stale writes after a delete tombstone")
    func meetingDraftRevisionsRejectStaleWritesAfterTombstone() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-store-meeting-drafts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer {
            MeetingDraftStore.waitForPendingOperations()
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let sessionID = "revision-order"
        MeetingDraftStore.write(
            sessionId: sessionID,
            transcript: "revision one",
            revision: 1,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.write(
            sessionId: sessionID,
            transcript: "revision three",
            revision: 3,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.write(
            sessionId: sessionID,
            transcript: "stale revision two",
            revision: 2,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.waitForPendingOperations()

        let newest = try #require(
            MeetingDraftStore.latestRecoverable(excluding: nil, baseDirectory: baseDirectory)
        )
        #expect(newest.sessionId == sessionID)
        #expect(newest.transcript == "revision three")

        MeetingDraftStore.delete(
            sessionId: sessionID,
            revision: 4,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.write(
            sessionId: sessionID,
            transcript: "stale resurrection",
            revision: 3,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.write(
            sessionId: sessionID,
            transcript: "equal-revision resurrection",
            revision: 4,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.write(
            sessionId: sessionID,
            transcript: "newer resurrection",
            revision: 5,
            baseDirectory: baseDirectory
        )

        let recoveredSessionID = "recovered-high-revision"
        MeetingDraftStore.write(
            sessionId: recoveredSessionID,
            transcript: "recovered revision ten",
            revision: 10,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.delete(
            sessionId: recoveredSessionID,
            revision: 1,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.write(
            sessionId: recoveredSessionID,
            transcript: "post-delete recovered resurrection",
            revision: 11,
            baseDirectory: baseDirectory
        )
        MeetingDraftStore.waitForPendingOperations()

        #expect(MeetingDraftStore.latestRecoverable(excluding: nil, baseDirectory: baseDirectory) == nil)
    }

    @Test("Quick Capture claims preserve recovery text and reject writes from a superseded window")
    func quickCaptureDraftSessionClaimRejectsSupersededOwner() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-store-quick-capture-session-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let firstSession = UUID()
        let secondSession = UUID()
        let initial = try #require(
            QuickCaptureDraftStore.claim(
                slot: .rootOverlay,
                sessionID: firstSession,
                baseDirectory: baseDirectory
            )
        )
        let firstText = QuickCaptureDraftStore.Draft(
            slot: .rootOverlay,
            sessionID: firstSession,
            committedText: "first window text",
            partialTranscript: "unfinished phrase",
            revision: initial.revision + 1
        )
        #expect(QuickCaptureDraftStore.write(firstText, baseDirectory: baseDirectory))

        let takeover = try #require(
            QuickCaptureDraftStore.claim(
                slot: .rootOverlay,
                sessionID: secondSession,
                baseDirectory: baseDirectory
            )
        )
        #expect(takeover.sessionID == secondSession)
        #expect(takeover.committedText == "first window text")
        #expect(takeover.partialTranscript == "unfinished phrase")
        #expect(takeover.revision > firstText.revision)

        let staleDisappearance = QuickCaptureDraftStore.Draft(
            slot: .rootOverlay,
            sessionID: firstSession,
            committedText: "stale disappearing window",
            partialTranscript: "",
            revision: takeover.revision + 1
        )
        #expect(!QuickCaptureDraftStore.write(staleDisappearance, baseDirectory: baseDirectory))
        #expect(QuickCaptureDraftStore.load(slot: .rootOverlay, baseDirectory: baseDirectory) == takeover)
    }

    @Test("Quick Capture allows only one live presentation owner")
    func quickCapturePresentationRegistryIsExactOwnerScoped() {
        let registry = QuickCapturePresentationRegistry()
        let first = UUID()
        let second = UUID()

        #expect(registry.acquire(first))
        #expect(registry.acquire(first))
        #expect(!registry.acquire(second))
        registry.release(second)
        #expect(registry.owns(first))
        registry.release(first)
        #expect(registry.acquire(second))
    }

    @Test("terminal voice state and Quick Capture restore paths release or preserve safely")
    func terminalVoiceStateAndQuickCaptureRestorePathsAreGuarded() throws {
        let voiceButton = try loadSourceFixture("Epistemos/Views/Shared/VoiceInputButton.swift")
        let meetingView = try loadSourceFixture("Epistemos/Views/Meeting/MeetingNoteView.swift")
        let liveVoice = try loadSourceFixture("Epistemos/Engine/LiveVoiceInputService.swift")
        let speechAnalyzer = try loadSourceFixture("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")
        let quickCapture = try loadSourceFixture("Epistemos/Views/Capture/QuickCaptureView.swift")

        let voiceSync = try sourceSection(
            in: voiceButton,
            startingAt: "private func syncPhaseFromService()",
            endingBefore: "private func drainAndRelease"
        )
        #expect(voiceSync.contains("case .idle:"))
        #expect(voiceSync.contains("drainAndRelease(activeLease, terminalPhase: .idle, interrupted: false)"))
        #expect(voiceSync.contains("case .unavailable(let message), .error(let message):"))
        #expect(voiceSync.contains("drainAndRelease(activeLease, terminalPhase: .error(message), interrupted: true)"))

        let drain = try sourceSection(
            in: voiceButton,
            startingAt: "private func drainAndRelease",
            endingBefore: "private func transition(to newPhase: Phase)"
        )
        let stop = try #require(drain.range(of: "service.stop(owner: owner)")?.lowerBound)
        let consume = try #require(drain.range(of: "service.consumeTranscript(owner: owner)")?.lowerBound)
        let interruptedCallback = try #require(drain.range(of: "onInterrupted(transcript)")?.lowerBound)
        let tearDown = try #require(drain.range(of: "service.tearDown(owner: owner)")?.lowerBound)
        let handleClear = try #require(drain.range(of: "sessionHandle?.clear(owner)")?.lowerBound)
        let release = try #require(drain.range(of: "activeLease = nil")?.lowerBound)
        #expect(stop < consume)
        #expect(consume < interruptedCallback)
        #expect(interruptedCallback < tearDown)
        #expect(consume < tearDown)
        #expect(tearDown < handleClear)
        #expect(handleClear < release)
        #expect(tearDown < release)

        #expect(meetingView.contains(".onChange(of: voiceInput.state) { _, _ in"))
        #expect(meetingView.contains(".onChange(of: voiceInput.modelDownloadProgress) { _, _ in"))
        #expect(meetingView.contains("service.refreshFromVoiceInput()"))

        let liveStart = try sourceSection(
            in: liveVoice,
            startingAt: "public func start(owner: VoiceCaptureLease) async -> VoiceCaptureStartResult",
            endingBefore: "    public func stop(owner: VoiceCaptureLease)"
        )
        #expect(liveStart.contains("self?.state == .preparing"))
        #expect(liveStart.contains("modelDownloadProgress = nil\n            state = .recording"))

        let rearm = try sourceSection(
            in: speechAnalyzer,
            startingAt: "private func rearmInputTapAfterConfigurationChange(sessionID: UUID)",
            endingBefore: "}\n\n@available(macOS 26.0, *)"
        )
        let converterFailure = try #require(
            rearm.range(of: "could not rebuild audio converter after configuration change")?.lowerBound
        )
        let converterFailureStop = try #require(
            rearm.range(of: "stopInternal(sessionID: sessionID)", range: converterFailure..<rearm.endIndex)?.lowerBound
        )
        #expect(converterFailure < converterFailureStop)

        let close = try sourceSection(
            in: quickCapture,
            startingAt: "private func close(restoreHomeFocus: Bool = true)",
            endingBefore: "private func finishDismissal"
        )
        #expect(close.contains("guard !isProcessing else"))
        #expect(close.contains("Wait for this capture to finish saving before closing."))
        #expect(close.contains("guard !isDictationActive else"))
        #expect(close.contains("guard !isDismissing else { return }"))
        #expect(close.contains("isDismissing = true"))

        let restore = try sourceSection(
            in: quickCapture,
            startingAt: "private func restoreQuickCaptureDraftIfNeeded()",
            endingBefore: "private func scheduleQuickCaptureDraftWrite()"
        )
        #expect(restore.contains("QuickCaptureDraftStore.claim(slot: slot, sessionID: sessionID)"))
        #expect(restore.contains("!Task.isCancelled"))
        #expect(restore.contains("!isDismissing"))
        #expect(restore.contains("ownsPresentation"))
        #expect(restore.contains("QuickCapturePresentationRegistry.shared.owns(sessionID)"))
        #expect(restore.contains("draftRevision = draft.revision"))
        #expect(restore.contains("captureText = QuickCaptureDraftStore.restoredCommittedText(from: draft)"))
        #expect(restore.contains("recoveredDictationFragment = QuickCaptureDraftStore.recoveredPartialTranscript(from: draft)"))
        #expect(restore.contains("draftSessionReady = true"))
        #expect(!restore.contains("max(draftRevision, draft.revision)"))
        #expect(!restore.contains("scheduleQuickCaptureDraftWrite()"))

        let schedule = try sourceSection(
            in: quickCapture,
            startingAt: "private func scheduleQuickCaptureDraftWrite()",
            endingBefore: "private func persistQuickCaptureDraftBeforeDismissal()"
        )
        #expect(schedule.contains("guard captureResult == nil,"))
        #expect(schedule.contains("!draftFlushedForDismissal"))
        #expect(schedule.contains("!isDismissing,"))
        #expect(schedule.contains("ownsPresentation,"))
        #expect(schedule.contains("draftSessionReady,"))
        #expect(schedule.contains("QuickCapturePresentationRegistry.shared.owns(presentationOwnerID) else { return }"))
    }
}
