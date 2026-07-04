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

    private let engine = AVAudioEngine()
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
    // MED-7 (audit 2026-07-03): counts audio buffers the input stream's bounded
    // buffer drops under backpressure so silently-lost audio → transcript gaps can be
    // surfaced. Lock-free (the real-time tap must never block); drained off-thread.
    private let audioDropTracker = AudioDropTracker()

    private final class AudioDropTracker: @unchecked Sendable {
        private let dropped = Atomic<Int>(0)
        func recordDrop() { dropped.wrappingAdd(1, ordering: .relaxed) }
        func drain() -> Int { dropped.exchange(0, ordering: .relaxed) }
    }

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
            let message = VoiceCaptureDiagnostics.externalErrorDescription(
                error,
                fallback: "asset inventory check failed"
            )
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
        onModelDownload: ((Double) -> Void)? = nil
    ) async throws -> AsyncStream<LiveResult> {
        stopInternal()

        // Ensure microphone permission (synchronous request via
        // AVCaptureDevice; the SpeechAnalyzer-side asset request is
        // separate).
        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        if permission == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                throw SpeechError.notAvailable(.microphonePermissionDenied)
            }
        } else if permission == .denied || permission == .restricted {
            throw SpeechError.notAvailable(.microphonePermissionDenied)
        }

        // Build the transcriber + ensure the model is installed.
        let transcriber = SpeechTranscriber(
            locale: .current,
            preset: .progressiveTranscription
        )
        if let request = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) {
            // Surface the download. AssetInstallationRequest exposes
            // a Progress object; downstream UI can observe it via the
            // callback.
            onModelDownload?(0.0)
            // RES-1 (audit 2026-07-03): observe the request's Progress so the UI shows a
            // MOVING bar during the (potentially slow) first-run model download instead of
            // a frozen 0% that reads as a hang. Poll on the MainActor (this class is
            // @MainActor); the task is cancelled the moment the download resolves.
            let downloadProgress = request.progress
            let progressTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { break }
                    onModelDownload?(downloadProgress.fractionCompleted)
                }
            }
            do {
                try await request.downloadAndInstall()
                progressTask.cancel()
                onModelDownload?(1.0)
            } catch {
                progressTask.cancel()
                throw SpeechError.downloadFailed(
                    VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "model download failed")
                )
            }
        }
        self.transcriber = transcriber

        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: inputFormat
        ) else {
            throw SpeechError.audioFormatUnavailable
        }
        guard let bufferConverter = SpeechAnalyzerAudioBufferConverter(
            inputFormat: inputFormat,
            outputFormat: analyzerFormat
        ) else {
            throw SpeechError.audioFormatUnavailable
        }

        // Wire the analyzer input stream. SpeechAnalyzer expects buffers
        // in its best available format; raw mic tap buffers can SIGTRAP
        // inside Speech.framework on macOS 26 if forwarded directly.
        let (inputStream, inputCont) = AsyncStream<AnalyzerInput>
            .makeStream(bufferingPolicy: .bufferingNewest(64))
        self.inputContinuation = inputCont

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        self.analyzer = analyzer

        // Drain transcriber.results into the public LiveResult stream.
        let (resultsStream, resultsCont) = AsyncStream<LiveResult>
            .makeStream(bufferingPolicy: .bufferingNewest(256))
        // CONC-5 (hardening 2026-07-02): honor the documented "stop by cancelling
        // the consuming Task" contract. Without this, a consumer that stops
        // iterating leaves the mic tap + AVAudioEngine + analyzer running — the
        // system mic indicator stays lit and the meeting keeps recording until an
        // explicit stop(). onTermination fires on consumer-cancel AND on natural
        // finish; stopInternal() is @MainActor and idempotent, so the redundant
        // call on the normal stop() path is a safe no-op.
        resultsCont.onTermination = { [weak self] _ in
            Task { @MainActor in self?.stopInternal() }
        }
        self.resultsTask = Task {
            do {
                for try await r in transcriber.results {
                    let text = String(r.text.characters)
                    if r.isFinal {
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
                Self.log.warning(
                    "\(message, privacy: .public)"
                )
            }
            resultsCont.finish()
        }

        // Kick off the analyze task. SpeechAnalyzer drains the input
        // sequence on its own queue; analyzeSequence returns when the
        // input stream is finished.
        self.analyzeTask = Task {
            do {
                try await analyzer.start(inputSequence: inputStream)
            } catch {
                let message = VoiceCaptureDiagnostics.externalErrorDescription(
                    error,
                    fallback: "speech analysis failed"
                )
                Self.log.warning(
                    "\(message, privacy: .public)"
                )
            }
        }

        // Retain the analyzer format + converter so the input tap can be re-armed
        // against a NEW input format after an audio route change.
        self.analyzerFormat = analyzerFormat
        self.bufferConverter = bufferConverter

        // Audio engine: installTap on input bus, push each buffer
        // into the AsyncStream wrapped as AnalyzerInput.
        installInputTap(converter: bufferConverter, continuation: inputCont, inputFormat: inputFormat)
        do {
            try engine.start()
        } catch {
            stopInternal()
            throw SpeechError.audioEngineFailed(
                VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "audio engine failed")
            )
        }

        // HIGH (audit 2026-07-03): re-arm the input tap when the audio route
        // changes (AirPods connect/disconnect, device switch). Without this the
        // engine stops, the tap dies, and transcription silently ends while the UI
        // still shows "recording" — a lost meeting. The analyzer + accumulated
        // transcript stay alive; only the audio input is rebuilt for the new format.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rearmInputTapAfterConfigurationChange() }
        }

        // MED-5 (audit 2026-07-03): mic permission can be revoked mid-meeting; the
        // engine keeps "running" but the tap goes silent, so the UI keeps showing
        // "recording" with no audio captured. Poll authorization while capturing and
        // stop (ending the results stream) if it's revoked, so the stall isn't silent —
        // the meeting ends and the user can re-grant permission and restart.
        permissionMonitorTask = Task { @MainActor [weak self] in
            var rearmAttempts = 0  // RES-4: give up after several consecutive failed rearms
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                let status = AVCaptureDevice.authorizationStatus(for: .audio)
                if status == .denied || status == .restricted {
                    Self.log.warning("microphone permission revoked mid-capture; stopping")
                    self?.stopInternal()
                    return
                }
                // MED-6 (audit 2026-07-03): an interruption (Siri, a screen-share audio
                // grab) can stop the engine WITHOUT posting an AVAudioEngineConfiguration
                // Change, so the #28 observer wouldn't fire and transcription would die
                // silently. If we're still meant to be capturing but the engine stopped,
                // re-arm it (rearm handles its own errors, so a permanently-gone device
                // just retries every few seconds rather than looping tightly).
                if let self, self.didInstallInputTap, !self.engine.isRunning {
                    rearmAttempts += 1
                    if rearmAttempts >= 3 {
                        // RES-4 (audit 2026-07-03): audio input couldn't be restored after
                        // several attempts (device physically removed?) — stop instead of
                        // looping forever behind a "Recording" indicator that's lying. Ending
                        // the stream stops the meeting so the user can restart.
                        Self.log.error("audio engine could not be restarted after \(rearmAttempts) attempts; stopping capture")
                        self.stopInternal()
                        return
                    }
                    Self.log.warning("audio engine stopped unexpectedly (interruption?); re-arming (attempt \(rearmAttempts))")
                    self.rearmInputTapAfterConfigurationChange()
                } else {
                    rearmAttempts = 0  // engine healthy again → reset the give-up counter
                }
                // MED-7: surface any audio dropped by backpressure since the last tick
                // (off the render thread) so a resulting transcript gap isn't invisible.
                if let dropped = self?.audioDropTracker.drain(), dropped > 0 {
                    Self.log.warning("\(dropped) audio buffer(s) dropped under backpressure — possible transcript gap")
                }
            }
        }

        Self.log.info("live transcription started")
        return resultsStream
    }

    /// Stop the live transcription and tear down the audio engine +
    /// analyzer. Safe to call multiple times; subsequent calls no-op.
    public func stop() {
        stopInternal()
    }

    private func stopInternal() {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }
        permissionMonitorTask?.cancel()
        permissionMonitorTask = nil
        if engine.isRunning {
            engine.stop()
        }
        if didInstallInputTap {
            engine.inputNode.removeTap(onBus: 0)
            didInstallInputTap = false
        }
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
        Self.log.info("live transcription stopped")
    }

    /// Install the mic tap for the CURRENT input format, forwarding converted
    /// buffers into the analyzer input stream. Extracted so the tap can be
    /// re-armed against a new format after an audio route change. The tap closure
    /// captures only the (Sendable) converter + continuation — never `self` — so
    /// it adds no retain cycle with the engine.
    private func installInputTap(
        converter: SpeechAnalyzerAudioBufferConverter,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        inputFormat: AVAudioFormat
    ) {
        // Bound to a local so the render-thread tap captures only Sendable values
        // (converter, continuation, tracker) — never `self`.
        let dropTracker = audioDropTracker
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
    /// keeping the analyzer + accumulated transcript alive. Degrades to a logged
    /// error (never a crash) if the new format can't be converted.
    private func rearmInputTapAfterConfigurationChange() {
        guard didInstallInputTap,
              let analyzerFormat,
              let continuation = inputContinuation else { return }
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
            return
        }
        bufferConverter = converter
        installInputTap(converter: converter, continuation: continuation, inputFormat: inputFormat)
        do {
            try engine.start()
            Self.log.info("audio input re-armed after configuration change")
        } catch {
            Self.log.error("failed to restart audio engine after configuration change: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Route-change handling
    //
    // Wave 13 §"Phase 11" gotcha: AirPods connect/disconnect mid-
    // stream changes the input format. The audio engine emits
    // `configurationChangeNotification`; the public surface re-opens
    // the stream automatically. Callers can subscribe to know they
    // should drop their accumulated partial text.

    public func observeRouteChanges(_ handler: @escaping @Sendable () -> Void) {
        let routeChangeLog = Self.log
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { _ in
            routeChangeLog.info("audio route changed; caller should restart capture")
            handler()
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
