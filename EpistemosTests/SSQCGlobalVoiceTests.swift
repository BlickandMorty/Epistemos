import Testing
import Foundation

@testable import Epistemos

// SS-QC (owner 2026-06-20) originally added Apple voice selection. Plan 3 owner update
// 2026-06-30 makes shipped TTS Kokoro-only, so the old resolution helpers are retained
// for compatibility but the visible picker and playback path must route through the Kokoro gate.
@Suite("SS-QC — global default voice")
struct SSQCGlobalVoiceTests {

    @Test("effectiveVoiceIdentifier: explicit wins, else the global default, else nil (→ preferredVoice)")
    func effectiveVoiceResolution() {
        // An explicit per-call pick always wins.
        #expect(EpistemosSpeechSynthesizer.effectiveVoiceIdentifier(
            explicit: "com.apple.x", globalDefault: "com.apple.y") == "com.apple.x")
        // No explicit pick → the global default applies (the SS-QC behavior: pick once, used everywhere).
        #expect(EpistemosSpeechSynthesizer.effectiveVoiceIdentifier(
            explicit: nil, globalDefault: "com.apple.y") == "com.apple.y")
        // Neither → nil, so resolveVoice falls back to preferredVoice() (best installed).
        #expect(EpistemosSpeechSynthesizer.effectiveVoiceIdentifier(
            explicit: nil, globalDefault: nil) == nil)
    }

    @Test("the global default voice round-trips through a fresh UserDefaults (persisted, clearable)")
    func globalDefaultRoundTrip() throws {
        let suiteName = "ss-qc-voice-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier(defaults: defaults) == nil)
        EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier("com.apple.voice.test", defaults: defaults)
        #expect(EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier(defaults: defaults) == "com.apple.voice.test")
        EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier(nil, defaults: defaults)
        #expect(EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier(defaults: defaults) == nil)
    }

    @Test("Settings mounts a Kokoro gate instead of Apple voice fallback")
    func wiring() throws {
        let synth = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        #expect(synth.contains("kokoroOnlyUnavailableMessage"))
        #expect(synth.contains("nativeKokoroSynthesisEngineLinked"))
        #expect(synth.contains("KokoroVoiceGateStatus.status("))
        #expect(!synth.contains("synthesizer.speak(utterance)"))

        let section = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")
        #expect(section.contains("ModelVoicePickerSection("))
        #expect(section.contains("EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier(newValue)"))
        #expect(section.contains("preview: \"Kokoro is ready.\""))

        let picker = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ModelVoicePickerSection.swift")
        #expect(picker.contains("unavailableTextToSpeechView"))
        #expect(picker.contains("EpistemosSpeechSynthesizer.isTextToSpeechAvailable()"))
        #expect(picker.contains("EpistemosSpeechSynthesizer.textToSpeechStatusMessage()"))
        #expect(picker.contains("EpistemosSpeechSynthesizer.installedEnglishKokoroVoices()"))
        #expect(picker.contains("normalizeBoundVoiceIdentifier(against: englishVoices)"))
        #expect(picker.contains("normalizedEnglishKokoroVoiceIdentifier("))
        #expect(!picker.contains("voiceQualityHint()"))
        #expect(!picker.contains("personalVoiceAuthorization"))
        #expect(picker.contains("accessibilityIdentifier(\"settings.voice.modelPreview\")"))
        #expect(picker.contains("previewText: String = \"Kokoro is ready.\""))
    }

    @Test("voicesGroupedByTier orders Premium > Enhanced > Default and drops empty tiers")
    func voicesGroupedByTierOrdersAndDropsEmpty() {
        func opt(_ q: EpistemosSpeechSynthesizer.VoiceQualityTier, _ id: String) -> EpistemosSpeechSynthesizer.VoiceOption {
            EpistemosSpeechSynthesizer.VoiceOption(identifier: id, displayName: id, language: "en-US", quality: q)
        }
        let grouped = EpistemosSpeechSynthesizer.voicesGroupedByTier(
            [opt(.default, "d1"), opt(.premium, "p1"), opt(.enhanced, "e1"), opt(.premium, "p2")])
        #expect(grouped.map(\.0) == [.premium, .enhanced, .default])
        #expect(grouped.first?.1.count == 2)  // both premium voices grouped together
        // Empty tiers are dropped (only Default present → only Default returned).
        #expect(EpistemosSpeechSynthesizer.voicesGroupedByTier([opt(.default, "d1")]).map(\.0) == [.default])
    }

    @Test("preferredVoiceIdentifier chooses quality before locale and uses locale only as tie-breaker")
    func preferredVoiceIdentifierQualityFirst() {
        func opt(
            _ q: EpistemosSpeechSynthesizer.VoiceQualityTier,
            _ id: String,
            language: String,
            name: String? = nil
        ) -> EpistemosSpeechSynthesizer.VoiceOption {
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: id,
                displayName: name ?? id,
                language: language,
                quality: q
            )
        }

        let voices = [
            opt(.enhanced, "enhanced-current", language: "en-US"),
            opt(.premium, "premium-other", language: "fr-FR"),
            opt(.default, "default-current", language: "en-US")
        ]
        #expect(
            EpistemosSpeechSynthesizer.preferredVoiceIdentifier(
                from: voices,
                currentLanguageCode: "en-US"
            ) == "premium-other"
        )

        let tiedPremium = [
            opt(.premium, "premium-other", language: "fr-FR"),
            opt(.premium, "premium-current", language: "en-GB")
        ]
        #expect(
            EpistemosSpeechSynthesizer.preferredVoiceIdentifier(
                from: tiedPremium,
                currentLanguageCode: "en-US"
            ) == "premium-current"
        )
    }

    @Test("preferredVoice avoids language-constructor floor and SSML falls back to plain utterance")
    func preferredVoiceAndProsodySourceGuard() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")

        #expect(!src.contains("AVSpeechSynthesisVoice(language:"))
        #expect(src.contains("preferredVoiceIdentifier("))
        #expect(src.contains("locale only as a tie-breaker"))
        #expect(src.contains("AVSpeechUtterance(ssmlRepresentation: ssml)"))
        #expect(src.contains("AVSpeechUtterance(string: text)"))
        #expect(src.contains("clampedRate(prosody?.rate ?? rate)"))
        #expect(src.contains("clampedPitch(prosody?.pitch ?? pitch)"))
        #expect(!src.contains("_ = AVSpeechSynthesisVoice.speechVoices()"))
    }

    @Test("stale utterance completion cannot clear a newer speech state")
    func staleUtteranceCompletionDoesNotClearNewerState() {
        let active = EpistemosSpeechSynthesizer.SpeakingState.speaking(
            utteranceId: "new",
            charactersTotal: 20,
            charactersSpoken: 5
        )
        #expect(
            EpistemosSpeechSynthesizer.stateAfterCompletingUtterance(
                utteranceId: "old",
                currentState: active
            ) == active
        )
        #expect(
            EpistemosSpeechSynthesizer.stateAfterCompletingUtterance(
                utteranceId: "new",
                currentState: active
            ) == .idle
        )
        #expect(
            EpistemosSpeechSynthesizer.stateAfterCompletingUtterance(
                utteranceId: "old",
                currentState: .paused(utteranceId: "new")
            ) == .paused(utteranceId: "new")
        )
    }

    @Test("Quick Capture no longer surfaces the Apple voice picker")
    func quickCaptureMountsVoicePicker() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        #expect(!src.contains("captureVoices"))
        #expect(!src.contains("EpistemosSpeechSynthesizer.voicesGroupedByTier(captureVoices)"))
        #expect(!src.contains("EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier(newValue)"))
        #expect(src.contains("EpistemosSpeechSynthesizer.isTextToSpeechAvailable()"))
    }
}
