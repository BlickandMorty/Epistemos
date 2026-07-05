import AVFoundation
import Foundation
import OSLog

// MARK: - EpistemosSpeechSynthesizer
//
// Wave 9.1 - AVSpeech catalogue and preference compatibility.
// Wave 9.1.b - premium-voice catalogue + interactive playback controls.
// Plan 3 owner update 2026-06-30: shipped TTS is Kokoro-only. A checked
// Pro Kokoro package renders through the native CoreML playback path; absent
// that package, speak() refuses playback instead of falling back to AVSpeech.
//
// Earlier W9 builds used AVSpeechSynthesizer for read-aloud. The helpers below
// remain so existing voice preferences and Personal Voice authorization state
// can migrate cleanly, but they are not the shipped read-aloud engine.
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
//   `voiceQualityHint` reports legacy catalogue quality without advertising
//   AVSpeech as a runtime fallback.

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

    nonisolated static let maxTextToSpeechInputCharacters = KokoroCoreMLSynthesizer.maxInputCharacters

    nonisolated static let kokoroOnlyUnavailableMessage =
        "Kokoro text-to-speech requires a checked Pro Kokoro CoreML package. Apple AVSpeech is not used as a fallback."

    nonisolated static let kokoroAppStoreUnavailableMessage =
        "Read-aloud is unavailable in this App Store build. Apple AVSpeech is not used as a fallback."

    private nonisolated static var nativeKokoroSynthesisEngineLinked: Bool {
        KokoroCoreMLRuntimeLoader.isLinked
    }

    nonisolated static func isTextToSpeechAvailable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) -> Bool {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return false
        #else
        nativeKokoroSynthesisEngineLinked
            && KokoroVoiceGateStatus.status(
                environment: environment,
                modelRoot: modelRoot,
                fileManager: fileManager
            ).isReady
        #endif
    }

    nonisolated static func textToSpeechStatusMessage(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) -> String {
        let status = KokoroVoiceGateStatus.status(
            environment: environment,
            modelRoot: modelRoot,
            fileManager: fileManager
        )
        guard nativeKokoroSynthesisEngineLinked else {
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            return kokoroAppStoreUnavailableMessage
            #else
            return kokoroOnlyUnavailableMessage
            #endif
        }
        guard status.isReady else {
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            return kokoroAppStoreUnavailableMessage
            #else
            // Engine is linked; only the voice model is missing. Point the user to the install flow
            // instead of the technical package message, so a disabled read-aloud button reads as
            // "install me" rather than "broken". (#52)
            return "Read-aloud needs the Kokoro voice \u{2014} install it in Settings \u{2192} Voice."
            #endif
        }
        return status.headline
    }

    nonisolated static func isTextToSpeechInputSupported(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty && cleaned.count <= maxTextToSpeechInputCharacters
    }

    nonisolated static func textToSpeechStatusMessage(
        for text: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return "Nothing to read aloud."
        }
        guard isTextToSpeechAvailable(
            environment: environment,
            modelRoot: modelRoot,
            fileManager: fileManager
        ) else {
            return textToSpeechStatusMessage(
                environment: environment,
                modelRoot: modelRoot,
                fileManager: fileManager
            )
        }
        guard cleaned.count <= maxTextToSpeechInputCharacters else {
            return "Kokoro text-to-speech is limited to \(maxTextToSpeechInputCharacters) characters. Select a shorter passage."
        }
        return textToSpeechStatusMessage(
            environment: environment,
            modelRoot: modelRoot,
            fileManager: fileManager
        )
    }

    // MARK: - Internals

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "Speech.Synthesizer"
    )
    private let synthesizer = AVSpeechSynthesizer()
    private var inflight: [String: AVSpeechUtterance] = [:]
    private let kokoroEngine = AVAudioEngine()
    private let kokoroPlayer = AVAudioPlayerNode()
    private var kokoroPlaybackTask: Task<Void, Never>?
    private var kokoroProgressTask: Task<Void, Never>?
    private var activeKokoroUtteranceID: String?
    private var activeKokoroCharactersTotal = 0

    private override init() {
        super.init()
        synthesizer.delegate = self
        kokoroEngine.attach(kokoroPlayer)
        if let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(KokoroVoiceGateStatus.sampleRateHz),
            channels: 1,
            interleaved: false
        ) {
            kokoroEngine.connect(kokoroPlayer, to: kokoroEngine.mainMixerNode, format: format)
        }
        // macOS pre-warms slowly on first use; voice-list enumeration
        // is cheap and sidesteps the first-speak hitch.
        _ = AVSpeechSynthesisVoice.speechVoices()
    }

    // MARK: - Speak API

    /// Speak `text` only when the Kokoro synthesis path is live. The legacy
    /// AVSpeech helpers remain for catalogue/picker compatibility, but they
    /// are not used as the shipped voice fallback.
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
        guard cleaned.count <= Self.maxTextToSpeechInputCharacters else {
            Self.log.info(
                "TTS unavailable chars=\(cleaned.count, privacy: .public); text exceeds Kokoro input cap"
            )
            return nil
        }

        guard Self.isTextToSpeechAvailable() else {
            Self.log.info(
                "TTS unavailable chars=\(cleaned.count, privacy: .public); Kokoro package is not ready and AVSpeech fallback is disabled"
            )
            return nil
        }

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        stopKokoroPlayback()
        inflight.removeAll()
        state = .idle

        // Voice SELECTION: passed to Kokoro (renderRawText loads the matching voice pack, or
        // falls back to the starter voice for nil/unknown). Was previously ignored.
        let selectedVoice = voiceIdentifier
        _ = pitch
        let utteranceID = UUID().uuidString
        activeKokoroUtteranceID = utteranceID
        activeKokoroCharactersTotal = cleaned.count
        state = .speaking(
            utteranceId: utteranceID,
            charactersTotal: cleaned.count,
            charactersSpoken: 0
        )
        let speed = Self.kokoroSpeedMultiplier(rate: prosody?.rate ?? rate)
        kokoroPlaybackTask = Task { [weak self] in
            guard let self else { return }
            do {
                let rendered = try await Task.detached(priority: .userInitiated) {
                    try KokoroCoreMLSynthesizer.renderRawText(cleaned, speed: speed, voiceIdentifier: selectedVoice)
                }.value
                try Task.checkCancellation()
                try self.playKokoroAudio(
                    rendered,
                    utteranceID: utteranceID,
                    charactersTotal: cleaned.count
                )
            } catch is CancellationError {
                return
            } catch {
                self.failKokoroPlayback(utteranceID: utteranceID, error: error)
            }
        }
        Self.log.info(
            "Kokoro TTS queued chars=\(cleaned.count, privacy: .public)"
        )
        return utteranceID
    }

    public func pause() {
        if kokoroPlayer.isPlaying, let activeKokoroUtteranceID {
            kokoroPlayer.pause()
            state = .paused(utteranceId: activeKokoroUtteranceID)
            return
        }
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
    }

    public func resume() {
        if let activeKokoroUtteranceID,
           case let .paused(pausedID) = state,
           pausedID == activeKokoroUtteranceID {
            kokoroPlayer.play()
            state = .speaking(
                utteranceId: activeKokoroUtteranceID,
                charactersTotal: activeKokoroCharactersTotal,
                charactersSpoken: 0
            )
            return
        }
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }

    public func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        stopKokoroPlayback()
        state = .idle
        inflight.removeAll()
    }

    public var isSpeaking: Bool {
        synthesizer.isSpeaking || kokoroPlayer.isPlaying || activeKokoroUtteranceID != nil
    }

    public var isPaused: Bool {
        if case .paused = state, activeKokoroUtteranceID != nil {
            return true
        }
        return synthesizer.isPaused
    }

    private enum KokoroPlaybackError: Error {
        case invalidAudioFormat
        case bufferAllocationFailed
        case audioTooLong
    }

    private func playKokoroAudio(
        _ rendered: KokoroCoreMLSynthesizer.RenderedAudio,
        utteranceID: String,
        charactersTotal: Int
    ) throws {
        guard activeKokoroUtteranceID == utteranceID else { return }
        let buffer = try pcmBuffer(for: rendered)
        if !kokoroEngine.isRunning {
            try kokoroEngine.start()
        }
        let durationSeconds = Double(rendered.samples.count) / Double(max(1, rendered.sampleRateHz))
        kokoroPlayer.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor in
                self?.completeKokoroPlayback(utteranceID: utteranceID)
            }
        }
        kokoroPlayer.play()
        activeKokoroCharactersTotal = charactersTotal
        state = .speaking(
            utteranceId: utteranceID,
            charactersTotal: charactersTotal,
            charactersSpoken: 0
        )
        startKokoroProgressUpdates(
            utteranceID: utteranceID,
            charactersTotal: charactersTotal,
            durationSeconds: durationSeconds
        )
    }

    private func pcmBuffer(for rendered: KokoroCoreMLSynthesizer.RenderedAudio) throws -> AVAudioPCMBuffer {
        guard !rendered.samples.isEmpty,
              rendered.samples.count <= Int(UInt32.max),
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(rendered.sampleRateHz),
                channels: 1,
                interleaved: false
              ) else {
            throw KokoroPlaybackError.invalidAudioFormat
        }
        let frameCount = AVAudioFrameCount(rendered.samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else {
            throw KokoroPlaybackError.bufferAllocationFailed
        }
        buffer.frameLength = frameCount
        rendered.samples.withUnsafeBufferPointer { samples in
            if let baseAddress = samples.baseAddress {
                channel.update(from: baseAddress, count: samples.count)
            }
        }
        return buffer
    }

    private func failKokoroPlayback(utteranceID: String, error: Error) {
        guard activeKokoroUtteranceID == utteranceID else { return }
        let nsError = error as NSError
        Self.log.error(
            "Kokoro TTS failed domain=\(VoiceCaptureDiagnostics.safeDomain(nsError.domain), privacy: .public) code=\(nsError.code, privacy: .public)"
        )
        kokoroPlayer.stop()
        kokoroEngine.pause()
        kokoroProgressTask?.cancel()
        kokoroProgressTask = nil
        activeKokoroUtteranceID = nil
        activeKokoroCharactersTotal = 0
        kokoroPlaybackTask = nil
        state = .idle
    }

    private func completeKokoroPlayback(utteranceID: String) {
        guard activeKokoroUtteranceID == utteranceID else { return }
        kokoroProgressTask?.cancel()
        kokoroProgressTask = nil
        activeKokoroUtteranceID = nil
        activeKokoroCharactersTotal = 0
        kokoroPlaybackTask = nil
        state = .idle
        kokoroEngine.pause()
    }

    private func stopKokoroPlayback() {
        kokoroPlaybackTask?.cancel()
        kokoroPlaybackTask = nil
        kokoroProgressTask?.cancel()
        kokoroProgressTask = nil
        if activeKokoroUtteranceID != nil || kokoroPlayer.isPlaying {
            kokoroPlayer.stop()
        }
        if kokoroEngine.isRunning {
            kokoroEngine.pause()
        }
        activeKokoroUtteranceID = nil
        activeKokoroCharactersTotal = 0
    }

    private func startKokoroProgressUpdates(
        utteranceID: String,
        charactersTotal: Int,
        durationSeconds: Double
    ) {
        kokoroProgressTask?.cancel()
        guard charactersTotal > 0, durationSeconds.isFinite, durationSeconds > 0 else { return }
        kokoroProgressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled,
                      let self,
                      self.activeKokoroUtteranceID == utteranceID else { return }
                self.updateKokoroPlaybackProgress(
                    utteranceID: utteranceID,
                    charactersTotal: charactersTotal,
                    durationSeconds: durationSeconds
                )
            }
        }
    }

    private func updateKokoroPlaybackProgress(
        utteranceID: String,
        charactersTotal: Int,
        durationSeconds: Double
    ) {
        guard kokoroPlayer.isPlaying,
              activeKokoroUtteranceID == utteranceID,
              case let .speaking(currentID, _, currentSpoken) = state,
              currentID == utteranceID,
              let renderTime = kokoroPlayer.lastRenderTime,
              let playerTime = kokoroPlayer.playerTime(forNodeTime: renderTime),
              playerTime.sampleRate > 0 else {
            return
        }

        let elapsedFrames = max(AVAudioFramePosition(0), playerTime.sampleTime)
        let elapsedSeconds = Double(elapsedFrames) / playerTime.sampleRate
        let fraction = min(0.99, max(0, elapsedSeconds / durationSeconds))
        let spoken = min(
            charactersTotal,
            max(currentSpoken, Int((Double(charactersTotal) * fraction).rounded(.down)))
        )
        guard spoken != currentSpoken else { return }
        state = .speaking(
            utteranceId: utteranceID,
            charactersTotal: charactersTotal,
            charactersSpoken: spoken
        )
    }

    private nonisolated static func kokoroSpeedMultiplier(rate: Float) -> Float {
        let defaultRate = AVSpeechUtteranceDefaultSpeechRate
        guard rate.isFinite, defaultRate.isFinite, defaultRate > 0 else {
            return 1.0
        }
        return min(1.6, max(0.6, rate / defaultRate))
    }

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

    /// Installed Kokoro voice packs (voices/*.bin in the model dir) as pickable options — the
    /// SHIPPED TTS voices. (availableVoices returns legacy AVSpeech voices for compat only.)
    /// Empty when Kokoro isn't installed. Display name + language are derived from the Kokoro
    /// naming convention <lang><gender>_<label> (e.g. af_heart = American English · Female · "Heart").
    nonisolated static func installedKokoroVoices(
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) -> [VoiceOption] {
        guard let modelRoot else { return [] }
        let voicesDir = modelRoot
            .appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
            .appendingPathComponent("voices", isDirectory: true)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: voicesDir,
            includingPropertiesForKeys: nil
        ) else { return [] }
        let names = entries
            .filter { $0.pathExtension == "bin" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter(isSafeKokoroVoiceName)
            .sorted()
        return names.map { name in
            let meta = kokoroVoiceMetadata(for: name)
            return VoiceOption(
                identifier: name,
                displayName: meta.displayName,
                language: meta.language,
                quality: .premium
            )
        }
    }

    private nonisolated static func isSafeKokoroVoiceName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 64
            && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }

    private nonisolated static func kokoroVoiceMetadata(for name: String) -> (displayName: String, language: String) {
        let parts = name.split(separator: "_", maxSplits: 1)
        let prefix = String(parts.first ?? "")
        let label = parts.count > 1 ? String(parts[1]) : name
        let displayName = label.isEmpty ? name : label.prefix(1).uppercased() + label.dropFirst()
        let language: String
        switch prefix.first {
        case "a": language = "American English"
        case "b": language = "British English"
        case "e": language = "Spanish"
        case "f": language = "French"
        case "h": language = "Hindi"
        case "i": language = "Italian"
        case "j": language = "Japanese"
        case "p": language = "Portuguese"
        case "z": language = "Chinese"
        default:  language = "Kokoro"
        }
        let gender: String
        switch prefix.dropFirst().first {
        case "f": gender = " · Female"
        case "m": gender = " · Male"
        default:  gender = ""
        }
        return (String(displayName), language + gender)
    }

    /// Strip Markdown syntax so read-aloud speaks the CONTENT, not the symbols
    /// ("# Section" → "Section", not "hashtag Section"; "**bold**" → "bold"). Conservative:
    /// only paired/line-anchored markers, so prose like "5 * 3" or `snake_case` is left alone.
    nonisolated static func plainTextForSpeech(fromMarkdown markdown: String) -> String {
        var text = markdown
        let rules: [(String, String)] = [
            ("```[\\s\\S]*?```", " "),                    // fenced code blocks
            ("(?m)^\\s{0,3}#{1,6}\\s+", ""),               // ATX headings
            ("(?m)^\\s{0,3}>\\s?", ""),                    // blockquotes
            ("(?m)^\\s{0,3}[-*+]\\s+", ""),                // unordered list markers
            ("(?m)^\\s{0,3}\\d+\\.\\s+", ""),              // ordered list markers
            ("(?m)^\\s{0,3}([-*_])\\1{2,}\\s*$", ""),      // horizontal rules
            ("!\\[[^\\]]*\\]\\([^)]*\\)", ""),             // images
            ("\\[\\[([^\\]]+)\\]\\]", "$1"),               // wikilinks → text
            ("\\[([^\\]]+)\\]\\([^)]*\\)", "$1"),          // links → text
            ("\\*\\*([^*]+)\\*\\*", "$1"),                 // bold **
            ("__([^_]+)__", "$1"),                         // bold __
            ("\\*([^*\\n]+)\\*", "$1"),                    // italic *
            ("(?<!\\w)_([^_\\n]+)_(?!\\w)", "$1"),         // italic _ (word-boundaried)
            ("`([^`]+)`", "$1"),                           // inline code
        ]
        for (pattern, replacement) in rules {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return text
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

    /// Hint string for legacy voice-catalogue surfaces. It reports local Apple
    /// catalogue quality without presenting AVSpeech as the shipped TTS runtime.
    public static func voiceQualityHint() -> (tier: VoiceQualityTier, message: String) {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let hasPremium = voices.contains { $0.quality == .premium }
        if hasPremium {
            return (
                .premium,
                "Premium Apple voice catalogue is installed for legacy selection only. Shipped text-to-speech remains Kokoro-only; AVSpeech is not used as a fallback."
            )
        }
        let hasEnhanced = voices.contains { $0.quality == .enhanced }
        if hasEnhanced {
            return (
                .enhanced,
                "Enhanced Apple voice catalogue is installed for legacy selection only. Shipped text-to-speech remains Kokoro-only; AVSpeech is not used as a fallback."
            )
        }
        return (
            .default,
            "Only the default Apple voice catalogue entry is installed for legacy selection. Shipped text-to-speech remains Kokoro-only; AVSpeech is not used as a fallback."
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
