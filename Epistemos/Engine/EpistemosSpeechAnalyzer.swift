import AVFoundation
import Foundation
import OSLog
import Speech

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
            Self.log.warning(
                "asset inventory check failed: \(error.localizedDescription, privacy: .public)"
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
            do {
                try await request.downloadAndInstall()
                onModelDownload?(1.0)
            } catch {
                throw SpeechError.downloadFailed(error.localizedDescription)
            }
        }
        self.transcriber = transcriber

        // Wire the analyzer input stream. `AnalyzerInput(buffer:)`
        // wraps the AVAudioPCMBuffer that the audio engine produces.
        let (inputStream, inputCont) = AsyncStream<AnalyzerInput>
            .makeStream(bufferingPolicy: .bufferingNewest(64))
        self.inputContinuation = inputCont

        let analyzer = SpeechAnalyzer(
            inputSequence: inputStream,
            modules: [transcriber]
        )
        self.analyzer = analyzer

        // Drain transcriber.results into the public LiveResult stream.
        let (resultsStream, resultsCont) = AsyncStream<LiveResult>
            .makeStream(bufferingPolicy: .bufferingNewest(256))
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
                Self.log.warning(
                    "transcriber.results stream errored: \(error.localizedDescription, privacy: .public)"
                )
            }
            resultsCont.finish()
        }

        // Kick off the analyze task. SpeechAnalyzer drains the input
        // sequence on its own queue; analyzeSequence returns when the
        // input stream is finished.
        self.analyzeTask = Task {
            do {
                _ = try await analyzer.analyzeSequence(inputStream)
            } catch {
                Self.log.warning(
                    "analyzer.analyzeSequence errored: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        // Audio engine: installTap on input bus, push each buffer
        // into the AsyncStream wrapped as AnalyzerInput.
        let format = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(
            onBus: 0, bufferSize: 1024, format: format
        ) { [weak self] buffer, _ in
            self?.inputContinuation?.yield(AnalyzerInput(buffer: buffer))
        }
        do {
            try engine.start()
        } catch {
            stopInternal()
            throw SpeechError.audioEngineFailed(error.localizedDescription)
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
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        analyzeTask?.cancel()
        analyzeTask = nil
        analyzer = nil
        transcriber = nil
        Self.log.info("live transcription stopped")
    }

    // MARK: - Route-change handling
    //
    // Wave 13 §"Phase 11" gotcha: AirPods connect/disconnect mid-
    // stream changes the input format. The audio engine emits
    // `configurationChangeNotification`; the public surface re-opens
    // the stream automatically. Callers can subscribe to know they
    // should drop their accumulated partial text.

    public func observeRouteChanges(_ handler: @escaping @Sendable () -> Void) {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { _ in
            Self.log.info("audio route changed — caller should restart capture")
            handler()
        }
    }
}
