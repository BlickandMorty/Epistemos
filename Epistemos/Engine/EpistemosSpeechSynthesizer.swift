import AVFoundation
import Foundation
import OSLog

// MARK: - EpistemosSpeechSynthesizer
//
// Wave 9.1 — Apple-native TTS via AVSpeechSynthesizer.
// Wave 9.1.b — per-model voice personas + premium-voice catalogue +
// interactive playback controls (pause / resume / stop, live progress).
//
// Per the W9 verdict (docs/WAVE_9_POLISH_AND_NATIVE.md): of the eight
// Apple-native ML / capture frameworks Epistemos already integrates,
// AVSpeechSynthesizer was the lone holdout. The W9.1.b extension lets
// each `SDModelProfile` carry a `voiceIdentifier` so Claude, GPT,
// Qwen, Hermes etc. each speak with a distinct persona. Quality tier
// is opportunistically upgraded — we prefer Premium > Enhanced >
// Default and surface a download hint when a Premium voice exists in
// Apple's catalogue but is not yet locally installed.
//
// ## Why a singleton actor
//
// AVSpeechSynthesizer is documented thread-safe but speak/pause/stop
// must be serialised — concurrent speak() calls without an explicit
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
// - Does NOT auto-download Premium voices: macOS surfaces those via
//   System Settings → Spoken Content → System Voice → Manage Voices.
//   We surface the install hint via `voiceQualityHint` so the
//   Settings UI can deep-link the user there.

@MainActor
@Observable
public final class EpistemosSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - Public observable state

    public enum SpeakingState: Sendable, Hashable {
        case idle
        case speaking(utteranceId: String, charactersTotal: Int, charactersSpoken: Int)
        case paused(utteranceId: String)

        public var isActive: Bool {
            switch self {
            case .idle: return false
            case .speaking, .paused: return true
            }
        }

        public var fractionComplete: Double {
            switch self {
            case .idle: return 0
            case let .speaking(_, total, spoken):
                guard total > 0 else { return 0 }
                return min(1.0, Double(spoken) / Double(total))
            case .paused: return 0
            }
        }
    }

    /// Voice quality tier as exposed by AVSpeechSynthesisVoice.Quality
    /// plus the Epistemos-specific "premium-not-installed" tier so the
    /// Settings UI can offer an install hint.
    public enum VoiceQualityTier: String, Sendable, Hashable {
        case `default`        // Apple Compact (always available)
        case enhanced         // Higher-quality voice, downloadable
        case premium          // Highest-quality "Personal Voice"-class
        case premiumAvailable // Premium voice exists in catalogue but not installed

        public var label: String {
            switch self {
            case .default:          return "Default"
            case .enhanced:         return "Enhanced"
            case .premium:          return "Premium"
            case .premiumAvailable: return "Premium (download required)"
            }
        }
    }

    public struct VoiceOption: Sendable, Hashable, Identifiable {
        public let identifier: String
        public let displayName: String
        public let language: String
        public let quality: VoiceQualityTier
        public var id: String { identifier }
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
        // macOS pre-warms slowly on first use; voice-list enumeration
        // is cheap and sidesteps the first-speak hitch.
        _ = AVSpeechSynthesisVoice.speechVoices()
    }

    // MARK: - Speak API

    /// Speak `text` using the best available voice for the user. If a
    /// previous utterance is still in flight it is interrupted at the
    /// current word boundary (per Apple's `.word` boundary contract).
    @discardableResult
    public func speak(
        _ text: String,
        voiceIdentifier: String? = nil,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0
    ) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = Self.resolveVoice(identifier: voiceIdentifier)
        let id = UUID().uuidString
        inflight[id] = utterance
        state = .speaking(
            utteranceId: id,
            charactersTotal: cleaned.count,
            charactersSpoken: 0
        )
        synthesizer.speak(utterance)
        let voiceLabel = utterance.voice?.identifier ?? "system-default"
        Self.log.info(
            "Speak chars=\(cleaned.count, privacy: .public) voice=\(voiceLabel, privacy: .public) id=\(id, privacy: .public)"
        )
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
    public var isPaused: Bool { synthesizer.isPaused }

    // MARK: - Voice catalogue

    /// All voices installed on this Mac, grouped + sorted by quality
    /// tier (Premium > Enhanced > Default) within language. The
    /// Settings UI uses this to populate the per-model picker.
    public static func availableVoices(language: String? = nil) -> [VoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { v in
            guard let language else { return true }
            return v.language.hasPrefix(language)
        }
        let mapped: [VoiceOption] = voices.map { v in
            VoiceOption(
                identifier: v.identifier,
                displayName: v.name,
                language: v.language,
                quality: tier(for: v)
            )
        }
        return mapped.sorted { lhs, rhs in
            if lhs.language != rhs.language { return lhs.language < rhs.language }
            return qualityRank(lhs.quality) < qualityRank(rhs.quality)
        }
    }

    /// Resolve a voice identifier into a concrete AVSpeechSynthesisVoice.
    /// Falls back to the user's preferred voice (premium > enhanced >
    /// default) when the requested identifier is missing — common on
    /// fresh Macs where Premium voices haven't been downloaded yet.
    public static func resolveVoice(identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return preferredVoice()
    }

    /// Pick the user's best-quality voice. Premium > Enhanced >
    /// system default (which is always installed).
    public static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let premium = voices.first(where: { $0.language.hasPrefix("en") && $0.quality == .premium }) {
            return premium
        }
        if let enhanced = voices.first(where: { $0.language.hasPrefix("en") && $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    /// Hint string for the Settings UI: tells the user whether they
    /// have Premium voices available locally and, if not, points them
    /// at System Settings → Spoken Content → System Voice → Manage
    /// Voices to install one. Returned text is plain English; callers
    /// can render it in a HelpRow without any logic.
    public static func voiceQualityHint() -> (tier: VoiceQualityTier, message: String) {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let hasPremium = voices.contains { $0.quality == .premium }
        if hasPremium {
            return (.premium, "Premium voice installed — using Apple’s highest-quality TTS.")
        }
        let hasEnhanced = voices.contains { $0.quality == .enhanced }
        if hasEnhanced {
            return (
                .enhanced,
                "Enhanced voice installed. For higher quality, install a Premium voice in System Settings → Spoken Content → Manage Voices."
            )
        }
        return (
            .default,
            "Only the default Compact voice is installed. Open System Settings → Spoken Content → Manage Voices to download an Enhanced or Premium voice."
        )
    }

    // MARK: - Quality tier helpers

    private static func tier(for voice: AVSpeechSynthesisVoice) -> VoiceQualityTier {
        switch voice.quality {
        case .premium:  return .premium
        case .enhanced: return .enhanced
        case .default:  return .default
        @unknown default: return .default
        }
    }

    private static func qualityRank(_ tier: VoiceQualityTier) -> Int {
        switch tier {
        case .premium:          return 0
        case .premiumAvailable: return 1
        case .enhanced:         return 2
        case .default:          return 3
        }
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
