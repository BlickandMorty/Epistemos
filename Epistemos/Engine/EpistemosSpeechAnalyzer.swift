@preconcurrency import AVFoundation
import Foundation
import OSLog
import Speech
import Synchronization

// MARK: - EpistemosSpeechAnalyzer
//
// Phase 11 of the master plan / Wave 13 §"Phase 11" Swift surface
// for live transcription via the macOS 26 `SpeechAnalyzer` /
// `SpeechTranscriber` modules. Replaces the 2019-era `SFSpeechRecognizer`
// path used by `AudioTranscriber` for new capture sites (brain dumps,
// voice notes, dictate-into-chat) — the legacy path stays for
// backwards compatibility.
//
// Why SpeechAnalyzer:
//   - 2.2× faster than WhisperKit large-v3-turbo on Apple Silicon
//     (MacStories Yap benchmark, 7 GB / 34-min video)
//   - Models live OUTSIDE the app sandbox in the OS asset catalog
//     (zero binary cost, shared across apps, auto-updated)
//   - DictationTranscriber doesn't require Settings → Siri/Keyboard
//     dictation enable (UX win over SFSpeechRecognizer)
//
// API drift caught vs Wave 13 doc:
//   - Wave 13 quoted `.conversational` preset; the actual SDK
//     (Speech.framework arm64e-apple-macos.swiftinterface line 339-343)
//     ships `.transcription`, `.transcriptionWithAlternatives`,
//     `.timeIndexedTranscriptionWithAlternatives`,
//     `.progressiveTranscription`,
//     `.timeIndexedProgressiveTranscription`. We use
//     `.progressiveTranscription` for live capture — it surfaces
//     partial results as the user speaks AND emits a final result
//     when the user pauses, matching the brain-dump UX.
//   - SpeechAnalyzer takes an `AsyncSequence<AnalyzerInput>`, not raw
//     `AVAudioPCMBuffer`. We adapt via an AsyncStream that wraps the
//     audio engine's `installTap` callback in `AnalyzerInput(buffer:)`.

@available(macOS 26.0, *)
@MainActor
public final class EpistemosSpeechAnalyzer {

    public enum LiveResult: Sendable {
        /// Partial transcription — text may change in subsequent
        /// snapshots until a `.final` arrives. Use for live UI
        /// rendering, NOT persistence.
        case partial(text: String)

        /// Stable transcription — text is final for this segment.
        /// Persist this; do not append a `.partial` of the same
        /// segment afterwards.
        case final(text: String)
    }

    public enum Readiness: Sendable, Equatable {
        case available
        case sdkUnavailable           // SpeechAnalyzer needs macOS 26+
        case microphonePermissionDenied
        case modelDownloadRequired    // assetInstallationRequest returned non-nil
    }

    public enum SpeechError: Error {
        case notAvailable(Readiness)
        case audioFormatUnavailable
        case audioEngineFailed(String)
        case downloadFailed(String)
        case streamCancelled
    }

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "EpistemosSpeechAnalyzer"
    )

    public static let shared = EpistemosSpeechAnalyzer()

    private var engine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var resultsTask: Task<Void, Never>?
    private var analyzeTask: Task<Void, Never>?
    private var didInstallInputTap = false
    // Retained so the mic tap can be re-armed against a NEW input format when the
    // audio route changes mid-capture (AirPods connect/disconnect).
    private var bufferConverter: SpeechAnalyzerAudioBufferConverter?
    private var analyzerFormat: AVAudioFormat?
    private var configChangeObserver: NSObjectProtocol?
    private var permissionMonitorTask: Task<Void, Never>?
    private var activeSessionID: UUID?
    // MED-7 (audit 2026-07-03): counts audio buffers the input stream's bounded
    // buffer drops under backpressure so silently-lost audio → transcript gaps can be
    // surfaced. Lock-free (the real-time tap must never block); drained off-thread.
    private var audioDropTracker: AudioDropTracker?

    private final class AudioDropTracker: @unchecked Sendable {
        private let dropped = Atomic<Int>(0)
        func recordDrop() { dropped.wrappingAdd(1, ordering: .relaxed) }
        func drain() -> Int { dropped.exchange(0, ordering: .relaxed) }
    }

#if DEBUG
    var hasAllocatedAudioEngineForTesting: Bool {
        engine != nil
    }
#endif

    private init() {}

    // MARK: - Readiness

    public func readiness() async -> Readiness {
        // SDK guard handled by the @available; this method is only
        // reachable on macOS 26+ since the type itself is gated.
        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        if permission == .denied || permission == .restricted {
            return .microphonePermissionDenied
        }
        let transcriber = SpeechTranscriber(
            locale: .current,
            preset: .progressiveTranscription
        )
        do {
            if try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) != nil {
                return .modelDownloadRequired
            }
        } catch {
            let message = VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "asset inventory check failed")
            Self.log.warning(
                "\(message, privacy: .public)"
            )
        }
        return .available
    }

    // MARK: - Live transcription

    /// Begin live transcription. Returns an AsyncStream of `LiveResult`
    /// events the caller iterates with `for await`. Stop by calling
    /// `stop()` or by cancelling the consuming Task.
    ///
    /// The stream auto-installs the speech model if it isn't already
    /// downloaded — first call may take seconds while the OS streams
    /// the asset (a SwiftUI progress affordance can be wired via the
    /// `onModelDownload` callback).
    public func startLive(
        sessionID: UUID,
        onModelDownload: ((Double) -> Void)? = nil
    ) async throws -> AsyncStream<LiveResult> {
        beginSession(sessionID)
        var shouldTearDownOnExit = true
        defer {
            if shouldTearDownOnExit {
                stopInternal(sessionID: sessionID)
            }
        }
        try requireCurrentSession(sessionID)

        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        if permission == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            try requireCurrentSession(sessionID)
            if !granted {
                throw SpeechError.notAvailable(.microphonePermissionDenied)
            }
        } else if permission == .denied || permission == .restricted {
            throw SpeechError.notAvailable(.microphonePermissionDenied)
        }

        let transcriber = SpeechTranscriber(
            locale: .current,
            preset: .progressiveTranscription
        )
        let installationRequest = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        )
        try requireCurrentSession(sessionID)
        if let request = installationRequest {
            onModelDownload?(0.0)
            let downloadProgress = request.progress
            let progressTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled,
                          self?.activeSessionID == sessionID else { return }
                    onModelDownload?(downloadProgress.fractionCompleted)
                }
            }
            do {
                try await request.downloadAndInstall()
                progressTask.cancel()
                try requireCurrentSession(sessionID)
                onModelDownload?(1.0)
            } catch is CancellationError {
                progressTask.cancel()
                throw SpeechError.streamCancelled
            } catch {
                progressTask.cancel()
                try requireCurrentSession(sessionID)
                throw SpeechError.downloadFailed(
                    VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "model download failed")
                )
            }
        }
        try requireCurrentSession(sessionID)

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: inputFormat
        ) else {
            try requireCurrentSession(sessionID)
            throw SpeechError.audioFormatUnavailable
        }
        try requireCurrentSession(sessionID)
        guard let bufferConverter = SpeechAnalyzerAudioBufferConverter(
            inputFormat: inputFormat,
            outputFormat: analyzerFormat
        ) else {
            throw SpeechError.audioFormatUnavailable
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try requireCurrentSession(sessionID)

        let (inputStream, inputCont) = AsyncStream<AnalyzerInput>
            .makeStream(bufferingPolicy: .bufferingNewest(64))
        let (resultsStream, resultsCont) = AsyncStream<LiveResult>
            .makeStream(bufferingPolicy: .bufferingNewest(256))
        let dropTracker = AudioDropTracker()

        self.transcriber = transcriber
        self.engine = engine
        self.inputContinuation = inputCont
        self.analyzer = analyzer
        self.analyzerFormat = analyzerFormat
        self.bufferConverter = bufferConverter
        self.audioDropTracker = dropTracker

        resultsCont.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.stopInternal(sessionID: sessionID)
            }
        }
        self.resultsTask = Task { @MainActor [weak self] in
            do {
                for try await result in transcriber.results {
                    guard self?.activeSessionID == sessionID, !Task.isCancelled else { break }
                    let text = String(result.text.characters)
                    if result.isFinal {
                        resultsCont.yield(.final(text: text))
                    } else {
                        resultsCont.yield(.partial(text: text))
                    }
                }
            } catch {
                let message = VoiceCaptureDiagnostics.externalErrorDescription(
                    error,
                    fallback: "transcriber results failed"
                )
                Self.log.warning("\(message, privacy: .public)")
            }
            resultsCont.finish()
        }

        self.analyzeTask = Task { @MainActor [weak self] in
            guard self?.activeSessionID == sessionID, !Task.isCancelled else { return }
            do {
                try await analyzer.start(inputSequence: inputStream)
            } catch {
                let message = VoiceCaptureDiagnostics.externalErrorDescription(
                    error,
                    fallback: "speech analysis failed"
                )
                Self.log.warning("\(message, privacy: .public)")
            }
        }

        installInputTap(
            on: engine,
            converter: bufferConverter,
            continuation: inputCont,
            inputFormat: inputFormat,
            dropTracker: dropTracker
        )
        do {
            try engine.start()
        } catch {
            stopInternal(sessionID: sessionID)
            throw SpeechError.audioEngineFailed(
                VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "audio engine failed")
            )
        }

        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard self?.activeSessionID == sessionID else { return }
                self?.rearmInputTapAfterConfigurationChange(sessionID: sessionID)
            }
        }

        permissionMonitorTask = Task { @MainActor [weak self] in
            var rearmAttempts = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled,
                      let self,
                      self.activeSessionID == sessionID else { return }
                let status = AVCaptureDevice.authorizationStatus(for: .audio)
                if status == .denied || status == .restricted {
                    Self.log.warning("microphone permission revoked mid-capture; stopping")
                    self.stopInternal(sessionID: sessionID)
                    return
                }
                if let engine = self.engine,
                   self.didInstallInputTap,
                   !engine.isRunning {
                    rearmAttempts += 1
                    if rearmAttempts >= 3 {
                        Self.log.error("audio engine could not be restarted after \(rearmAttempts) attempts; stopping capture")
                        self.stopInternal(sessionID: sessionID)
                        return
                    }
                    Self.log.warning("audio engine stopped unexpectedly (interruption?); re-arming (attempt \(rearmAttempts))")
                    self.rearmInputTapAfterConfigurationChange(sessionID: sessionID)
                } else {
                    rearmAttempts = 0
                }
                let dropped = dropTracker.drain()
                if dropped > 0 {
                    Self.log.warning("\(dropped) audio buffer(s) dropped under backpressure — possible transcript gap")
                }
            }
        }

        try requireCurrentSession(sessionID)
        Self.log.info("live transcription started")
        shouldTearDownOnExit = false
        return resultsStream
    }

    /// Stop the live transcription and tear down the audio engine +
    /// analyzer. Safe to call multiple times; subsequent calls no-op.
    public func stop(sessionID: UUID) {
        stopInternal(sessionID: sessionID)
    }

    private func beginSession(_ sessionID: UUID) {
        if let activeSessionID {
            stopInternal(sessionID: activeSessionID)
        }
        activeSessionID = sessionID
    }

    private func requireCurrentSession(_ sessionID: UUID) throws {
        guard activeSessionID == sessionID, !Task.isCancelled else {
            throw SpeechError.streamCancelled
        }
    }

    private func stopInternal(sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        tearDownCurrentResources()
    }

    private func tearDownCurrentResources() {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }
        permissionMonitorTask?.cancel()
        permissionMonitorTask = nil
        if let engine, engine.isRunning {
            engine.stop()
        }
        if didInstallInputTap {
            engine?.inputNode.removeTap(onBus: 0)
            didInstallInputTap = false
        }
        engine = nil
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        analyzeTask?.cancel()
        analyzeTask = nil
        analyzer = nil
        transcriber = nil
        bufferConverter = nil
        analyzerFormat = nil
        audioDropTracker = nil
        Self.log.info("live transcription stopped")
    }

    /// Install the mic tap for the CURRENT input format, forwarding converted
    /// buffers into the analyzer input stream. Extracted so the tap can be
    /// re-armed against a new format after an audio route change. The tap closure
    /// captures only the (Sendable) converter + continuation — never `self` — so
    /// it adds no retain cycle with the engine.
    private func installInputTap(
        on engine: AVAudioEngine,
        converter: SpeechAnalyzerAudioBufferConverter,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        inputFormat: AVAudioFormat,
        dropTracker: AudioDropTracker
    ) {
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            guard let input = converter.makeAnalyzerInput(from: buffer) else { return }
            // MED-7: if the bounded input buffer drops this frame (backpressure), count
            // it (lock-free) so the resulting transcript gap isn't silent.
            if case .dropped = continuation.yield(input) {
                dropTracker.recordDrop()
            }
        }
        didInstallInputTap = true
    }

    /// Re-arm the mic tap after `.AVAudioEngineConfigurationChange` (route change).
    /// Rebuilds the converter for the NEW input format and restarts the engine,
    /// keeping the analyzer + accumulated transcript alive. Stops the scoped
    /// capture if the new format cannot be converted, so the UI cannot remain in
    /// a false recording state with no installed input tap.
    private func rearmInputTapAfterConfigurationChange(sessionID: UUID) {
        guard activeSessionID == sessionID,
              didInstallInputTap,
              let engine,
              let analyzerFormat,
              let continuation = inputContinuation,
              let dropTracker = audioDropTracker else { return }
        Self.log.info("audio configuration changed; re-arming input tap")
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        didInstallInputTap = false
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard let converter = SpeechAnalyzerAudioBufferConverter(
            inputFormat: inputFormat,
            outputFormat: analyzerFormat
        ) else {
            Self.log.error("could not rebuild audio converter after configuration change")
            stopInternal(sessionID: sessionID)
            return
        }
        bufferConverter = converter
        installInputTap(
            on: engine,
            converter: converter,
            continuation: continuation,
            inputFormat: inputFormat,
            dropTracker: dropTracker
        )
        do {
            try engine.start()
            Self.log.info("audio input re-armed after configuration change")
        } catch {
            let message = VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "audio engine failed")
            Self.log.error("\(message, privacy: .public)")
        }
    }
}

@available(macOS 26.0, *)
private final class SpeechAnalyzerAudioBufferConverter: @unchecked Sendable {
    private let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter?
    private let lock = NSLock()

    init?(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) {
        self.outputFormat = outputFormat
        if Self.formatsMatch(inputFormat, outputFormat) {
            self.converter = nil
        } else {
            guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                return nil
            }
            self.converter = converter
        }
    }

    func makeAnalyzerInput(from buffer: AVAudioPCMBuffer) -> AnalyzerInput? {
        guard buffer.frameLength > 0 else { return nil }
        guard let converter else {
            return AnalyzerInput(buffer: buffer)
        }

        lock.lock()
        defer { lock.unlock() }

        let capacity = Self.outputFrameCapacity(for: buffer, outputFormat: outputFormat)
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: capacity
        ) else {
            return nil
        }

        let input = SpeechAnalyzerConverterInput(buffer: buffer)
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, inputStatus in
            input.next(inputStatus)
        }

        guard conversionError == nil else { return nil }
        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            guard convertedBuffer.frameLength > 0 else { return nil }
            return AnalyzerInput(buffer: convertedBuffer)
        case .error:
            return nil
        @unknown default:
            return nil
        }
    }

    private static func outputFrameCapacity(
        for buffer: AVAudioPCMBuffer,
        outputFormat: AVAudioFormat
    ) -> AVAudioFrameCount {
        let inputRate = buffer.format.sampleRate
        let outputRate = outputFormat.sampleRate
        guard inputRate.isFinite,
              outputRate.isFinite,
              inputRate > 0,
              outputRate > 0
        else {
            return max(1, buffer.frameLength)
        }

        let scaled = (Double(buffer.frameLength) * outputRate / inputRate)
            .rounded(.up)
        return max(1, AVAudioFrameCount(scaled) + 16)
    }

    private static func formatsMatch(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.sampleRate == rhs.sampleRate &&
        lhs.channelCount == rhs.channelCount &&
        lhs.commonFormat == rhs.commonFormat &&
        lhs.isInterleaved == rhs.isInterleaved
    }
}

private nonisolated final class SpeechAnalyzerConverterInput: @unchecked Sendable {
    private let lock = NSLock()
    private let buffer: AVAudioPCMBuffer
    private var didProvideInput = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(_ inputStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        lock.lock()
        defer { lock.unlock() }

        guard !didProvideInput else {
            inputStatus.pointee = .noDataNow
            return nil
        }

        didProvideInput = true
        inputStatus.pointee = .haveData
        return buffer
    }
}
