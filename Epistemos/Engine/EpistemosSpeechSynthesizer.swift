import AVFoundation
import Foundation
import OSLog

// MARK: - EpistemosSpeechSynthesizer
//
// Wave 9.1 — Apple-native TTS via AVSpeechSynthesizer.
//
// Per the W9 verdict (docs/WAVE_9_POLISH_AND_NATIVE.md): of the eight
// Apple-native frameworks Epistemos already integrates (Foundation
// Models, Speech for STT, NaturalLanguage, AppIntents, Vision,
// ScreenCaptureKit, BackgroundTasks, NLEmbedding), AVSpeechSynthesizer
// was the lone holdout. This is the canonical wrapper that lets any
// view emit "read aloud" / "speak this response" affordances without
// each call site re-instantiating an AVSpeechSynthesizer (which leaks
// on the audio session if you do that).
//
// ## Why a singleton actor
//
// AVSpeechSynthesizer is documented thread-safe but speak/pause/stop
// must be serialized — concurrent speak() calls without an explicit
// stopSpeaking can lead to overlapped utterances on macOS. A single
// process-wide actor makes the contract obvious and lets the delegate
// callback safely mutate the published `state`.
//
// ## What this does NOT do
//
// - Does NOT request audio session activation; AVSpeechSynthesizer on
//   macOS does not require AVAudioSession setup (that's iOS-only).
// - Does NOT chunk long text — the synthesizer handles arbitrarily
//   long utterances internally and emits per-range progress through
//   the delegate.
// - Does NOT block. Every call is non-blocking; observers should
//   subscribe to `state` (Observation) for UI updates.

@MainActor
@Observable
public final class EpistemosSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - Public observable state

    public enum SpeakingState: Sendable, Hashable {
        case idle
        case speaking(utteranceId: String, charactersTotal: Int, charactersSpoken: Int)
        case paused(utteranceId: String)
    }

    public private(set) var state: SpeakingState = .idle

    // MARK: - Process-wide singleton

    public static let shared = EpistemosSpeechSynthesizer()

    // MARK: - Internals

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "Speech.Synthesizer"
    )
    private let synthesizer = AVSpeechSynthesizer()
    private var inflight: [String: AVSpeechUtterance] = [:]

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - API

    /// Speak `text` using the user's preferred voice. If a previous
    /// utterance is still in flight it is interrupted at the current
    /// word boundary (per Apple's `.word` boundary contract).
    @discardableResult
    public func speak(
        _ text: String,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        voice: AVSpeechSynthesisVoice? = nil
    ) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = rate
        utterance.voice = voice ?? Self.preferredVoice()
        let id = UUID().uuidString
        inflight[id] = utterance
        state = .speaking(
            utteranceId: id,
            charactersTotal: cleaned.count,
            charactersSpoken: 0
        )
        synthesizer.speak(utterance)
        Self.log.info("Speak \(cleaned.count, privacy: .public) chars id=\(id, privacy: .public)")
        return id
    }

    public func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
    }

    public func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }

    public func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        state = .idle
        inflight.removeAll()
    }

    public var isSpeaking: Bool { synthesizer.isSpeaking }

    /// Pick the user's preferred macOS voice. Apple ships with
    /// "com.apple.voice.compact.en-US.Samantha" as the universal
    /// default; modern builds also have a higher-quality "Premium"
    /// voice that auto-downloads on first use. We prefer Premium when
    /// available, fall back to the user's configured default voice.
    public static func preferredVoice() -> AVSpeechSynthesisVoice? {
        if let premium = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix("en") && $0.quality == .premium
        }) {
            return premium
        }
        if let enhanced = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix("en") && $0.quality == .enhanced
        }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {}

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let total = utterance.speechString.count
        let spoken = characterRange.upperBound
        Task { @MainActor [weak self] in
            guard let self,
                  case let .speaking(utteranceId, _, _) = self.state else { return }
            self.state = .speaking(
                utteranceId: utteranceId,
                charactersTotal: total,
                charactersSpoken: spoken
            )
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.state = .idle
            self?.inflight.removeAll()
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.state = .idle
            self?.inflight.removeAll()
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self,
                  case let .speaking(utteranceId, _, _) = self.state else { return }
            self.state = .paused(utteranceId: utteranceId)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self,
                  case let .paused(utteranceId) = self.state,
                  let inflight = self.inflight[utteranceId] else { return }
            self.state = .speaking(
                utteranceId: utteranceId,
                charactersTotal: inflight.speechString.count,
                charactersSpoken: 0
            )
        }
    }
}
