import AVFoundation
import Foundation
import OSLog

// MARK: - EpistemosSpeechSynthesizer
//
// Wave 9.1 — Apple-native TTS via AVSpeechSynthesizer.
// Wave 9.1.b — premium-voice catalogue + interactive playback controls
// (pause / resume / stop, live progress).
//
// Per the W9 verdict (docs/WAVE_9_POLISH_AND_NATIVE.md): of the eight
// Apple-native ML / capture frameworks Epistemos already integrates,
// AVSpeechSynthesizer was the lone holdout. Quality tier is opportunistically
// upgraded — we prefer Premium > Enhanced > Default and surface a download hint
// when a Premium voice exists in Apple's catalogue but is not yet locally installed.
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

    public enum PersonalVoiceAuthorization: String, Sendable, Hashable {
        case notDetermined
        case denied
        case unsupported
        case authorized

        public var label: String {
            switch self {
            case .notDetermined: return "Personal Voice access not requested"
            case .denied: return "Personal Voice access denied"
            case .unsupported: return "Personal Voice unsupported"
            case .authorized: return "Personal Voice allowed"
            }
        }
    }

    public struct SpeechProsody: Sendable, Hashable {
        public let rate: Float
        public let pitch: Float

        public init(
            rate: Float = AVSpeechUtteranceDefaultSpeechRate,
            pitch: Float = 1.0
        ) {
            self.rate = rate
            self.pitch = pitch
        }
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
        pitch: Float = 1.0,
        prosody: SpeechProsody? = nil
    ) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = Self.makeUtterance(
            text: cleaned,
            rate: rate,
            pitch: pitch,
            prosody: prosody
        )
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

    /// Group a voice list by quality tier (Premium > Enhanced > Default), dropping empty tiers.
    /// Shared by the Settings picker (ModelVoicePickerSection) and the Quick Capture point-of-use
    /// picker so there's ONE grouping rule, not duplicated logic. Pure → headless-testable.
    nonisolated public static func voicesGroupedByTier(
        _ voices: [VoiceOption]
    ) -> [(VoiceQualityTier, [VoiceOption])] {
        let order: [VoiceQualityTier] = [.premium, .enhanced, .default]
        return order.compactMap { tier in
            let entries = voices.filter { $0.quality == tier }
            return entries.isEmpty ? nil : (tier, entries)
        }
    }

    /// Resolve a voice identifier into a concrete AVSpeechSynthesisVoice.
    /// Falls back to the user's preferred voice (premium > enhanced >
    /// default) when the requested identifier is missing — common on
    /// fresh Macs where Premium voices haven't been downloaded yet.
    public static func resolveVoice(identifier: String?) -> AVSpeechSynthesisVoice? {
        // SS-QC (owner 2026-06-20): an explicit per-call voice wins; else the user's chosen GLOBAL
        // default voice (set in the voice picker) applies across EVERY TTS surface; else the best
        // installed voice (premium > enhanced > default). Picking a voice once makes it the default
        // for chat read-aloud, note read-aloud, and Quick Capture read-back alike.
        if let resolved = effectiveVoiceIdentifier(
            explicit: identifier,
            globalDefault: globalDefaultVoiceIdentifier()
        ), let voice = AVSpeechSynthesisVoice(identifier: resolved) {
            return voice
        }
        return preferredVoice()
    }

    /// Pure: which voice identifier to use — an explicit per-call pick wins; else the global
    /// default; else nil → `preferredVoice()` picks the best installed voice. Side-effect-free and
    /// isolation-free so it (and the global-default round-trip) is headless-testable.
    nonisolated public static func effectiveVoiceIdentifier(explicit: String?, globalDefault: String?) -> String? {
        explicit ?? globalDefault
    }

    /// UserDefaults key for the SS-QC global default voice.
    nonisolated public static let globalDefaultVoiceKey = "com.epistemos.voice.globalDefaultVoiceIdentifier"

    /// The user's chosen global default voice identifier (SS-QC voice picker), or nil if unset.
    /// Persisted so it applies across launches + every TTS surface.
    nonisolated public static func globalDefaultVoiceIdentifier(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: globalDefaultVoiceKey)
    }

    /// Set the global default voice identifier (nil clears it).
    nonisolated public static func setGlobalDefaultVoiceIdentifier(_ identifier: String?, defaults: UserDefaults = .standard) {
        if let identifier {
            defaults.set(identifier, forKey: globalDefaultVoiceKey)
        } else {
            defaults.removeObject(forKey: globalDefaultVoiceKey)
        }
    }

    /// Pick the user's best-quality voice. Premium > Enhanced >
    /// Default across the installed catalogue, using the current
    /// locale only as a tie-breaker.
    public static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let options = voices.map { voice in
            VoiceOption(
                identifier: voice.identifier,
                displayName: voice.name,
                language: voice.language,
                quality: tier(for: voice)
            )
        }
        guard let identifier = preferredVoiceIdentifier(
            from: options,
            currentLanguageCode: AVSpeechSynthesisVoice.currentLanguageCode()
        ) else {
            return voices.first
        }
        return AVSpeechSynthesisVoice(identifier: identifier) ?? voices.first
    }

    nonisolated public static func preferredVoiceIdentifier(
        from voices: [VoiceOption],
        currentLanguageCode: String
    ) -> String? {
        voices.sorted { lhs, rhs in
            let lhsQuality = qualityRank(lhs.quality)
            let rhsQuality = qualityRank(rhs.quality)
            if lhsQuality != rhsQuality { return lhsQuality < rhsQuality }

            let lhsLocale = localeTieBreakRank(lhs.language, currentLanguageCode: currentLanguageCode)
            let rhsLocale = localeTieBreakRank(rhs.language, currentLanguageCode: currentLanguageCode)
            if lhsLocale != rhsLocale { return lhsLocale < rhsLocale }

            if lhs.language != rhs.language { return lhs.language < rhs.language }
            if lhs.displayName != rhs.displayName { return lhs.displayName < rhs.displayName }
            return lhs.identifier < rhs.identifier
        }.first?.identifier
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

    @MainActor
    public static func personalVoiceAuthorization() -> PersonalVoiceAuthorization {
        if #available(macOS 14.0, *) {
            return personalVoiceAuthorization(from: AVSpeechSynthesizer.personalVoiceAuthorizationStatus)
        }
        return .unsupported
    }

    @MainActor
    public static func requestPersonalVoiceAuthorization() async -> PersonalVoiceAuthorization {
        guard #available(macOS 14.0, *) else {
            return .unsupported
        }

        return await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                continuation.resume(returning: personalVoiceAuthorization(from: status))
            }
        }
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

    @available(macOS 14.0, *)
    private nonisolated static func personalVoiceAuthorization(
        from status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus
    ) -> PersonalVoiceAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .unsupported: return .unsupported
        case .authorized: return .authorized
        @unknown default: return .unsupported
        }
    }

    private nonisolated static func qualityRank(_ tier: VoiceQualityTier) -> Int {
        switch tier {
        case .premium:          return 0
        case .premiumAvailable: return 1
        case .enhanced:         return 2
        case .default:          return 3
        }
    }

    private nonisolated static func localeTieBreakRank(
        _ language: String,
        currentLanguageCode: String
    ) -> Int {
        if language == currentLanguageCode {
            return 0
        }
        let currentBase = currentLanguageCode.split(separator: "-").first.map(String.init) ?? currentLanguageCode
        if language == currentBase || language.hasPrefix("\(currentBase)-") {
            return 1
        }
        return 2
    }

    private static func makeUtterance(
        text: String,
        rate: Float,
        pitch: Float,
        prosody: SpeechProsody?
    ) -> AVSpeechUtterance {
        let resolvedRate = Self.clampedRate(prosody?.rate ?? rate)
        let resolvedPitch = Self.clampedPitch(prosody?.pitch ?? pitch)

        if prosody != nil {
            let ssml = ssmlRepresentation(
                text: text,
                rate: resolvedRate,
                pitch: resolvedPitch
            )
            if let utterance = AVSpeechUtterance(ssmlRepresentation: ssml) {
                return utterance
            }
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = resolvedRate
        utterance.pitchMultiplier = resolvedPitch
        return utterance
    }

    private static func ssmlRepresentation(
        text: String,
        rate: Float,
        pitch: Float
    ) -> String {
        let ratePercent = Int(
            min(
                200,
                max(50, (rate / AVSpeechUtteranceDefaultSpeechRate) * 100)
            ).rounded()
        )
        let pitchPercent = Int(
            min(
                50,
                max(-50, (pitch - 1.0) * 50)
            ).rounded()
        )
        let pitchValue = pitchPercent >= 0 ? "+\(pitchPercent)%" : "\(pitchPercent)%"
        return """
        <speak><prosody rate="\(ratePercent)%" pitch="\(pitchValue)">\(escapedSSMLText(text))</prosody></speak>
        """
    }

    private static func escapedSSMLText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func clampedRate(_ value: Float) -> Float {
        guard value.isFinite else { return AVSpeechUtteranceDefaultSpeechRate }
        return min(max(value, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }

    static func clampedPitch(_ value: Float) -> Float {
        guard value.isFinite else { return 1.0 }
        return min(max(value, 0.5), 2.0)
    }

    nonisolated static func stateAfterCompletingUtterance(
        utteranceId completedID: String,
        currentState: SpeakingState
    ) -> SpeakingState {
        switch currentState {
        case .speaking(let currentID, _, _) where currentID == completedID:
            return .idle
        case .paused(let currentID) where currentID == completedID:
            return .idle
        case .idle, .speaking, .paused:
            return currentState
        }
    }

    private func utteranceID(forObjectID objectID: ObjectIdentifier) -> String? {
        inflight.first { _, candidate in
            ObjectIdentifier(candidate) == objectID
        }?.key
    }

    private func completeUtterance(id completedID: String) {
        let nextState = Self.stateAfterCompletingUtterance(
            utteranceId: completedID,
            currentState: state
        )
        if nextState.isActive {
            inflight.removeValue(forKey: completedID)
        } else {
            inflight.removeAll()
        }
        state = nextState
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
        let utteranceObjectID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let utteranceId = self.utteranceID(forObjectID: utteranceObjectID),
                  case let .speaking(currentID, _, _) = self.state,
                  currentID == utteranceId else { return }
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
        let utteranceObjectID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let utteranceId = self.utteranceID(forObjectID: utteranceObjectID) else { return }
            self.completeUtterance(id: utteranceId)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let utteranceObjectID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let utteranceId = self.utteranceID(forObjectID: utteranceObjectID) else { return }
            self.completeUtterance(id: utteranceId)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        let utteranceObjectID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let utteranceId = self.utteranceID(forObjectID: utteranceObjectID),
                  case let .speaking(currentID, _, _) = self.state,
                  currentID == utteranceId else { return }
            self.state = .paused(utteranceId: utteranceId)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        let utteranceObjectID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  case let .paused(utteranceId) = self.state,
                  let currentUtterance = self.inflight[utteranceId],
                  ObjectIdentifier(currentUtterance) == utteranceObjectID else { return }
            self.state = .speaking(
                utteranceId: utteranceId,
                charactersTotal: currentUtterance.speechString.count,
                charactersSpoken: 0
            )
        }
    }
}
